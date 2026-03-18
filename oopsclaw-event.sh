#!/bin/bash
#
# iFlow Oopsclaw - 事件驱动修复脚本
# 当 OpenClaw Gateway 失败时由 systemd OnFailure 触发
# 简化版：直接调用 iflow + guardian agent
#

set -euo pipefail

# 配置
OOPSCLAW_DIR="$HOME/.oopsclaw"
LOG_DIR="$OOPSCLAW_DIR/logs"
KNOWLEDGE_DIR="$OOPSCLAW_DIR/knowledge"
OPENCLAW_CONFIG="$HOME/.openclaw/openclaw.json"
GATEWAY_PORT=18789
SERVICE_NAME="openclaw-gateway.service"
FEISHU_USER_ID_FILE="$HOME/.oopsclaw/feishu_user_id.txt"

# 超时配置
IFLOW_TIMEOUT=300

# 单实例锁
LOCK_FILE="${XDG_RUNTIME_DIR:-/tmp}/oopsclaw-event.lock"
exec 9>"$LOCK_FILE"
flock -n 9 || { echo "Oopsclaw 已在运行中，退出."; exit 0; }

# 日志
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_DIR/oopsclaw-event.log"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$LOG_DIR/guardian-error.log"
}

# 发送飞书卡片消息
send_feishu() {
    local title="$1"
    local message="$2"
    local color="${3:-green}"  # green/red/blue/yellow
    
    if [ -f "$FEISHU_USER_ID_FILE" ]; then
        local user_id=$(cat "$FEISHU_USER_ID_FILE")
        source "$HOME/.bashrc" 2>/dev/null || true
        openclaw message send \
            --channel feishu \
            --target "$user_id" \
            --message "**$title**

$message" > /dev/null 2>&1 || true
    fi
}

# 读取知识库
read_knowledge() {
    local fingerprints=""
    local troubleshooting=""
    local learned_history=""
    
    # 读取故障指纹库
    if [ -f "$KNOWLEDGE_DIR/base/fingerprints.txt" ]; then
        fingerprints=$(cat "$KNOWLEDGE_DIR/base/fingerprints.txt")
    fi
    
    # 读取故障排查手册
    if [ -f "$KNOWLEDGE_DIR/base/troubleshooting.md" ]; then
        troubleshooting=$(cat "$KNOWLEDGE_DIR/base/troubleshooting.md")
    fi
    
    # 读取最近的经验（最近3条）
    if [ -d "$KNOWLEDGE_DIR/learned" ]; then
        learned_history=$(ls -t "$KNOWLEDGE_DIR/learned/"*.md 2>/dev/null | head -3 | xargs -I {} cat {} 2>/dev/null || echo "无历史经验")
    fi
    
    echo "=== 故障指纹库 ==="
    echo "$fingerprints"
    echo ""
    echo "=== 故障排查手册 ==="
    echo "$troubleshooting"
    echo ""
    echo "=== 历史经验 ==="
    echo "$learned_history"
}

# 收集故障信息
collect_error_info() {
    local error_info=""
    
    # 服务状态
    error_info="$error_info\n=== 服务状态 ==="
    error_info="$error_info\n$(systemctl --user status "$SERVICE_NAME" 2>&1 | tail -20)"
    
    # 最近日志
    error_info="$error_info\n\n=== 最近 OpenClaw 日志 ==="
    if [ -d "$HOME/.openclaw/logs" ]; then
        error_info="$error_info\n$(ls -t "$HOME/.openclaw/logs"/*.log 2>/dev/null | head -1 | xargs tail -30 2>/dev/null || echo "无日志")"
    fi
    
    # journal 日志
    error_info="$error_info\n\n=== Journal 日志 ==="
    error_info="$error_info\n$(journalctl --user -u "$SERVICE_NAME" -n 30 --no-pager 2>/dev/null || echo "无 journal")"
    
    echo "$error_info"
}

# 调用 iflow guardian 修复
call_iflow_guardian() {
    local error_context="$1"
    
    log "调用 iflow guardian agent 修复..."
    
    # 读取知识库
    local knowledge=$(read_knowledge)
    
    # 构建 prompt
    local prompt="你是 iFlow Oopsclaw 守护者，专门负责修复 OpenClaw Gateway 故障。

## 你的任务
1. 读取并理解故障信息
2. 参考知识库中的故障指纹和历史经验
3. 诊断问题根因
4. 执行修复（使用 CLI 命令）
5. 验证修复结果
6. 更新知识库（如果发现新的故障模式，添加到 fingerprints.txt；如果有重要经验，保存到 learned/ 目录）

## 知识库位置
- 故障指纹库: $KNOWLEDGE_DIR/base/fingerprints.txt
- 故障排查手册: $KNOWLEDGE_DIR/base/troubleshooting.md
- 经验目录: $KNOWLEDGE_DIR/learned/

## 故障信息
$error_context

## 知识库
$knowledge

## OpenClaw 配置
$OPENCLAW_CONFIG

## 要求
1. 首先验证 JSON 配置格式: python3 -m json.tool $OPENCLAW_CONFIG
2. 诊断问题根因
3. 执行最小必要修复
4. 重启服务验证: systemctl --user restart $SERVICE_NAME
5. 检查端口: nc -z 127.0.0.1 $GATEWAY_PORT
6. 如果需要更新知识库，直接写入文件

完成后，请：
- 总结修复步骤
- 如果知识库有更新，说明更新内容
- 判断是否修复成功"

    # 调用 iflow（使用 -a 让它读取 guardian agent）
    local iflow_result
    iflow_result=$(timeout "$IFLOW_TIMEOUT" iflow -p "$prompt" -y 2>&1) || true
    
    echo "$iflow_result" | tee -a "$LOG_DIR/guardian-iflow.log"
    
    # 检查是否包含成功关键词
    if echo "$iflow_result" | grep -qi "修复成功\|success\|已完成\|已修复\|已解决"; then
        return 0
    fi
    
    return 1
}

# 验证服务状态
verify_service() {
    log "验证服务状态..."
    
    # 检查进程
    if ! pgrep -f "openclaw.*gateway" > /dev/null 2>&1; then
        log_error "进程不存在"
        return 1
    fi
    
    # 检查端口
    if ! nc -z 127.0.0.1 $GATEWAY_PORT 2>/dev/null; then
        log_error "端口不可用"
        return 1
    fi
    
    # 检查服务状态
    if ! systemctl --user is-active "$SERVICE_NAME" > /dev/null 2>&1; then
        log_error "服务未运行"
        return 1
    fi
    
    log "服务验证通过"
    return 0
}

# 写入结果文件
write_result() {
    local status="$1"
    local message="$2"
    local out="${XDG_RUNTIME_DIR:-/tmp}/oopsclaw-event-result.json"
    cat > "$out" <<EOF
{"status":"$status","message":"$message","timestamp":"$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
EOF
    log "结果: $out"
}

# 主函数
main() {
    log "========== Oopsclaw 事件触发 =========="
    
    # 通知用户
    send_feishu "🔧 OpenClaw Gateway 故障" "正在调用 Oopsclaw AI 自动修复..." "yellow"
    
    # 收集故障信息
    local error_info=$(collect_error_info)
    
    # 调用 iflow guardian 修复
    if call_iflow_guardian "$error_info"; then
        # 验证服务
        sleep 5
        if verify_service; then
            log "修复成功 ✅"
            
            # 触发自我进化评估（后台运行，不阻塞）
            (
                bash "$OOPSCLAW_DIR/oopsclaw-evolve.sh" success 120 no yes "服务启动失败" >> "$LOG_DIR/evolution.log" 2>&1
            ) &
            
            send_feishu "✅ OpenClaw 已修复" "Oopsclaw AI 修复成功，服务已恢复正常\n自我进化评估已触发" "green"
            write_result "success" "Fixed by Oopsclaw AI"
            exit 0
        fi
    fi
    
    # 验证失败，再试一次
    log "首次修复未成功，再次尝试..."
    sleep 10
    
    if verify_service; then
        log "修复成功 ✅"
        send_feishu "✅ OpenClaw 已修复" "服务已恢复正常" "green"
        write_result "success" "Fixed on retry"
        exit 0
    fi
    
    # 修复失败
    log_error "修复失败"
    send_feishu "❌ OpenClaw 修复失败" "请手动检查服务状态\n运行: systemctl --user status $SERVICE_NAME" "red"
    write_result "failed" "Auto-fix failed"
    exit 1
}

main "$@"

#!/bin/bash
#
# iFlow Guardian - OpenClaw 监控脚本 v1.5
# 功能: 进程监控 + 端口检查 + 日志分析 + 自动修复 + 状态综合检查
#

set -e

# 配置
GUARDIAN_DIR="$HOME/.iflow/guardian"
LOG_DIR="$GUARDIAN_DIR/logs"
KNOWLEDGE_DIR="$GUARDIAN_DIR/knowledge"
BACKUP_DIR="$GUARDIAN_DIR"
OPENCLAW_CONFIG="$HOME/.openclaw/openclaw.json"
OPENCLAW_LOG="$HOME/.openclaw/logs"
GATEWAY_PORT=18789
MAX_RESTART_ATTEMPTS=3
RESTART_COOLDOWN=120

# NEWAPI 配置 (用于 AI 分析)
NEWAPI_BASE_URL="https://api.duanz.xin:1217/v1"
NEWAPI_KEY="sk-QqQgqwesxdxDmcLbAAenApKjuGM9VfRowI75l8R5YwkqsTpz"
AI_MODEL="qwen/qwen3.5-397b-a17b"

# 飞书配置
FEISHU_USER_ID_FILE="$GUARDIAN_DIR/feishu_user_id.txt"

# 使用 OpenClaw AI 生成守护者问题分析报告
guardian_analyze() {
    local issue_type="$1"
    local issue_detail="$2"
    local fix_action="$3"
    
    # 收集相关日志
    local recent_logs=""
    if [ -f "$LOG_DIR/monitor.log" ]; then
        recent_logs="$recent_logs\n=== 守护者监控日志 (最近 30 行) ===\n$(tail -30 "$LOG_DIR/monitor.log" 2>/dev/null)"
    fi
    if [ -f "$LOG_DIR/error.log" ]; then
        recent_logs="$recent_logs\n=== 错误日志 (最近 20 行) ===\n$(tail -20 "$LOG_DIR/error.log" 2>/dev/null)"
    fi
    
    # 构建 prompt
    local prompt="你是 OpenClaw/iFlow 守护者系统的 AI 分析专家。

守护者监控脚本检测到以下问题：

问题类型: $issue_type
问题详情: $issue_detail
已执行的修复操作: $fix_action

相关日志:
$recent_logs

请生成一份详细的分析报告，格式如下：

## 🔍 问题诊断
[详细分析问题原因，基于实际日志数据]

## 🛠️ 已应用的修复方案
[描述守护者已经执行的修复操作]

## 📋 后续建议
[给用户的建议，如果需要人工介入的话]

请用中文回复，报告要具体、清晰、有帮助。输出只包含报告内容，不要有任何前缀。"
    
    # 调用 OpenClaw 本地 Agent 进行分析
    local result=$(openclaw agent --local --message "$prompt" --timeout 120 2>/dev/null)
    
    if [ -n "$result" ]; then
        echo "$result"
        return 0
    else
        echo "## 🔍 问题诊断\n问题类型: $issue_type\n问题详情: $issue_detail\n\n## 🛠️ 已应用的修复方案\n$fix_action\n\n## 📋 后续建议\n暂无"
        return 1
    fi
}

# 调用 iFlow CLI 来分析和解决问题
iflow_fix() {
    local issue_type="$1"
    local issue_detail="$2"
    
    log "调用 iFlow CLI 进行问题分析和修复..."
    
    # 收集日志
    local logs=""
    logs="$logs\n守护者监控日志:\n$(tail -30 "$LOG_DIR/monitor.log" 2>/dev/null)"
    logs="$logs\n\n错误日志:\n$(tail -20 "$LOG_DIR/error.log" 2>/dev/null)"
    logs="$logs\n\nOpenClaw 日志:\n$(tail -50 /tmp/openclaw/openclaw-2026-03-02.log 2>/dev/null | head -30)"
    
    # 构建 prompt 请求 iFlow 分析并解决问题
    local prompt="你是 iFlow CLI 助手，精通 OpenClaw 运维。

守护者检测到以下问题，请分析并解决：

问题类型: $issue_type
问题详情: $issue_detail

相关日志:
$logs

请执行以下步骤：
1. 分析问题原因
2. 如果需要执行命令修复，请给出具体的命令（我会执行）
3. 给出最终的状态报告

重要：请在解决方案中用以下格式列出需要执行的命令，每行一个命令：
\`\`\`bash
# 这里写命令
\`\`\`

请用中文回复，格式如下：
## 🔍 问题分析
[分析原因]
## 🛠️ 解决方案
[列出需要执行的命令，使用 bash 代码块]
## 📊 状态报告
[修复后的状态]"

    # 调用 iFlow CLI
    local iflow_result=$(iflow -p "$prompt" 2>&1)
    
    if [ -n "$iflow_result" ]; then
        log "iFlow CLI 分析完成，尝试执行命令..."
        
        # 解析并执行命令
        local execute_result=$(execute_iflow_commands "$iflow_result")
        
        if [ -n "$execute_result" ]; then
            log "iFlow 命令执行完成"
            # 附加执行结果到报告
            echo "$iflow_result"
            echo ""
            echo "--- 命令执行结果 ---"
            echo "$execute_result"
        else
            echo "$iflow_result"
        fi
        return 0
    else
        log "iFlow CLI 调用失败，使用默认修复"
        return 1
    fi
}

# 解析并执行 iFlow 给出的命令
execute_iflow_commands() {
    local content="$1"
    local executed=""
    
    # 提取 bash 代码块中的命令
    local commands=$(echo "$content" | sed -n '/```bash/,/```/p' | grep -v '```' | grep -v '^#' | grep -v '^$' | sed 's/^[[:space:]]*//')
    
    if [ -z "$commands" ]; then
        log "iFlow 未提供需要执行的命令"
        return 0
    fi
    
    log "从 iFlow 解析到命令，准备执行..."
    
    # 逐行执行命令
    while IFS= read -r cmd; do
        # 跳过空行和注释
        [ -z "$cmd" ] && continue
        [[ "$cmd" =~ ^# ]] && continue
        
        # 检查命令是否安全（只允许特定命令）
        if echo "$cmd" | grep -qE '^(systemctl|openclaw|curl|wget|jq|sudo|chmod|chown|mkdir|rm|cp|mv|cat|grep|tail|head|ps|nc|kill|restart|start|stop|status|enable|disable|daemon-reload)'; then
            log "执行命令: $cmd"
            local result
            if result=$(eval "$cmd" 2>&1); then
                executed="$executed\n✅ $cmd\n$result"
                log "命令执行成功: $cmd"
            else
                executed="$executed\n❌ $cmd\n$result"
                log_error "命令执行失败: $cmd - $result"
            fi
        else
            log "跳过不安全命令: $cmd"
            executed="$executed\n⏭️ 跳过 (未允许): $cmd"
        fi
    done <<< "$commands"
    
    if [ -n "$executed" ]; then
        echo "$executed"
        return 0
    fi
    return 1
}

# 日志函数 (修复重复输出)
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_DIR/monitor.log"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$LOG_DIR/error.log"
}

log_warn() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARN: $1" >> "$LOG_DIR/warn.log"
}

# 加载故障指纹库
load_fingerprints() {
    if [ -f "$KNOWLEDGE_DIR/base/fingerprints.txt" ]; then
        grep -v "^#" "$KNOWLEDGE_DIR/base/fingerprints.txt" | grep -v "^$"
    fi
}

# 检查进程
check_process() {
    if pgrep -f "openclaw.*gateway" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# 检查端口
check_port() {
    if nc -z 127.0.0.1 $GATEWAY_PORT 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# 检查健康
check_health() {
    response=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:$GATEWAY_PORT/ 2>/dev/null)
    if [ "$response" = "200" ]; then
        return 0
    else
        return 1
    fi
}

# 基于指纹库的自动修复
auto_fix_by_fingerprint() {
    local error_log="$1"
    local errors=$(tail -20 "$error_log" 2>/dev/null | grep -iE "error|panic|exception|fail" | head -5)
    
    [ -z "$errors" ] && return 0
    
    log "分析错误日志进行智能修复..."
    
    while IFS='|' read -r fingerprint type fix; do
        # 跳过注释和空行
        [[ "$fingerprint" =~ ^# ]] && continue
        [ -z "$fingerprint" ] && continue
        
        if echo "$errors" | grep -qi "$fingerprint"; then
            log "匹配故障: $fingerprint → $type"
            
            case "$fix" in
                "检查并添加到 systemd service")
                    fix_jina_key
                    ;;
                "检查配置文件语法")
                    jq . "$OPENCLAW_CONFIG" > /dev/null 2>&1 || {
                        log "JSON 语法错误，尝试恢复备份..."
                        ls -t "$BACKUP_DIR"/openclaw.json.bak.* 2>/dev/null | head -1 | xargs -r cp {} "$OPENCLAW_CONFIG"
                    }
                    ;;
                "检查 API Key")
                    log "API Key 可能过期，请检查"
                    ;;
                "检查端口和服务状态")
                    log "端口可能被占用，尝试重启..."
                    systemctl --user restart openclaw-gateway
                    ;;
                "重启 gateway 服务")
                    systemctl --user restart openclaw-gateway
                    ;;
                *)
                    log "未知修复策略: $fix"
                    ;;
            esac
        fi
    done <<< "$(load_fingerprints)"
}

# 分析 OpenClaw 日志 (智能修复版)
analyze_logs() {
    local error_count=0
    local warnings=()
    
    # 检查最近的错误日志
    if [ -d "$OPENCLAW_LOG" ]; then
        # 查找最近的错误日志文件
        local latest_error_log=$(ls -t "$OPENCLAW_LOG"/error*.log 2>/dev/null | head -1)
        
        if [ -n "$latest_error_log" ] && [ -f "$latest_error_log" ]; then
            # 检查是否有新错误
            local recent_errors=$(tail -50 "$latest_error_log" 2>/dev/null | grep -iE "error|panic|exception|fail" | tail -5)
            
            if [ -n "$recent_errors" ]; then
                log_warn "发现错误日志: $recent_errors"
                
                # 匹配故障指纹并尝试修复
                auto_fix_by_fingerprint "$latest_error_log"
                
                # 匹配故障指纹
                while IFS='|' read -r fingerprint type fix; do
                    if echo "$recent_errors" | grep -qi "$fingerprint"; then
                        log_warn "匹配故障: $type - $fix"
                        warnings+=("$type: $fix")
                    fi
                done <<< "$(load_fingerprints)"
            fi
        fi
    fi
    
    # 返回警告数量
    echo ${#warnings[@]}
}

# 备份配置
backup_config() {
    timestamp=$(date '+%Y%m%d-%H%M%S')
    cp "$OPENCLAW_CONFIG" "$BACKUP_DIR/openclaw.json.bak.$timestamp"
    
    # 清理旧备份 (保留 5 个)
    ls -t "$BACKUP_DIR"/openclaw.json.bak.* 2>/dev/null | tail -n +6 | xargs -r rm
    
    log "配置已备份: openclaw.json.bak.$timestamp"
}

# 重启 Gateway
restart_gateway() {
    log "尝试重启 Gateway..."
    
    # 检查冷却时间
    if [ -f "$LOG_DIR/last_restart" ]; then
        last_restart=$(cat "$LOG_DIR/last_restart")
        now=$(date +%s)
        elapsed=$((now - last_restart))
        
        if [ $elapsed -lt $RESTART_COOLDOWN ]; then
            log "冷却期内 (${elapsed}s/$RESTART_COOLDOWNs)，跳过重启"
            return 1
        fi
    fi
    
    echo $(date +%s) > "$LOG_DIR/last_restart"
    
    # 重启
    systemctl --user restart openclaw-gateway
    sleep 3
    
    if check_port; then
        log "重启成功 ✅"
        return 0
    else
        log_error "重启失败"
        return 1
    fi
}

# 修复 JINA_API_KEY
fix_jina_key() {
    source "$HOME/.bashrc" 2>/dev/null
    
    local service_file="$HOME/.config/systemd/user/openclaw-gateway.service"
    
    # 检查 JINA_API_KEY 是否存在于 systemd service
    if grep -q "JINA_API_KEY" "$service_file"; then
        return 0
    fi
    
    log_warn "JINA_API_KEY 未在 systemd service 中配置"
    return 1
}

# 修复配置文件权限
fix_config_permissions() {
    local config_file="$HOME/.openclaw/openclaw.json"
    
    if [ -f "$config_file" ]; then
        local perms=$(stat -c "%a" "$config_file" 2>/dev/null)
        if [ "$perms" != "600" ]; then
            chmod 600 "$config_file"
            log "已修复配置文件权限: $perms -> 600"
        fi
    fi
}

# AI 分析函数 - 生成详细的问题原因和解决方案
ai_analyze() {
    local issue_type="$1"
    local issue_detail="$2"
    local context="$3"
    
    # 构建 prompt
    local prompt="你是一个专业的 OpenClaw/Gateway 系统运维助手。请分析以下问题并给出详细的原因分析和解决方案。

问题类型: $issue_type
问题详情: $issue_detail
上下文: $context

请用中文回复，格式如下：
## 🔍 问题原因
（详细分析可能的原因）

## 🛠️ 解决方案
（具体可操作的解决步骤）

## 📋 预防建议
（如何避免再次发生）

注意：只输出分析内容，不要添加任何前缀或问候语。"

    # 调用 NewAPI
    local response=$(curl -s -X POST "$NEWAPI_BASE_URL/chat/completions" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $NEWAPI_KEY" \
        -d "{
            \"model\": \"$AI_MODEL\",
            \"messages\": [
                {\"role\": \"system\", \"content\": \"你是一个专业的 OpenClaw 系统运维助手，擅长分析和解决各种技术问题。\"},
                {\"role\": \"user\", \"content\": \"$prompt\"}
            ],
            \"temperature\": 0.7,
            \"max_tokens\": 1000
        }" 2>/dev/null)
    
    # 提取 AI 回复
    local ai_result=$(echo "$response" | jq -r '.choices[0].message.content' 2>/dev/null)
    
    if [ -z "$ai_result" ] || [ "$ai_result" = "null" ]; then
        echo "AI 分析失败，请检查系统日志"
        return 1
    fi
    
    echo "$ai_result"
    return 0
}

# 发送通知 (启用飞书通知 + Guardian AI 分析)
send_notification() {
    local message="$1"
    local issue_type="$2"
    local issue_detail="$3"
    local fix_action="$4"
    
    log "NOTIFICATION: $message"
    
    # 调用 Guardian AI 进行深度分析
    local guardian_analysis=""
    if [ -n "$issue_detail" ]; then
        guardian_analysis=$(guardian_analyze "$issue_type" "$issue_detail" "$fix_action")
    fi
    
    # 构建完整的飞书消息
    local feishu_message="$message"
    if [ -n "$guardian_analysis" ]; then
        feishu_message="$message

---

$guardian_analysis"
    fi
    
    # 发送飞书通知
    local feishu_id="$FEISHU_USER_ID_FILE"
    if [ -f "$feishu_id" ]; then
        # 使用 openclaw 发送飞书消息
        source "$HOME/.bashrc" 2>/dev/null
        openclaw message send \
            --channel feishu \
            --target "$(cat "$feishu_id")" \
            --message "$feishu_message" \
            > /dev/null 2>&1 || true
        log "飞书通知已发送"
    fi
}

# 检查 systemd 重启次数 (检测反复重启循环)
check_restart_loop() {
    local nrestarts=$(systemctl --user show openclaw-gateway.service -p NRestarts --value 2>/dev/null || echo "0")
    local state=$(systemctl --user show openclaw-gateway.service -p ActiveState --value 2>/dev/null)
    
    if [ "$nrestarts" -gt 3 ]; then
        log_error "检测到重启循环: NRestarts=$nrestarts, ActiveState=$state"
        return 1
    fi
    return 0
}

# 记录修复历史 (学习功能)
learn_repair_result() {
    local result="$1"  # "success" or "failed"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "$timestamp|$result" >> "$LOG_DIR/repair_history.log"
    
    # 统计成功率
    if [ -f "$LOG_DIR/repair_history.log" ]; then
        local total=$(wc -l < "$LOG_DIR/repair_history.log")
        local success=$(grep -c "success" "$LOG_DIR/repair_history.log" || echo 0)
        local rate=$((success * 100 / total))
        log "修复成功率: $rate% ($success/$total)"
        
        # 如果成功率低于50%，发出警告并触发 AI 分析
        if [ "$rate" -lt 50 ] && [ "$total" -gt 5 ]; then
            log_warn "修复成功率过低，触发 AI 自我进化..."
            "$GUARDIAN_DIR/ai-evolve.sh" analyze "低成功率" "修复成功率: $rate%" "已尝试多种修复但效果不佳"
        fi
    fi
}

# 主函数
main() {
    log "========== 监控开始 =========="
    
    local status="OK"
    local issues=()
    
    # 0. 检查重启循环 (优先检查)
    if ! check_restart_loop; then
        status="ERROR"
        issues+=("重启循环: $(systemctl --user show openclaw-gateway.service -p NRestarts --value) 次重启")
        log_error "检测到重启循环，执行紧急修复"
    fi
    
    # 1. 进程检查
    if check_process; then
        log "进程: 存活 ✅"
    else
        status="ERROR"
        issues+=("进程未运行")
        log_error "进程: 未运行 ❌"
    fi
    
    # 2. 端口检查
    if check_port; then
        log "端口 $GATEWAY_PORT: 可连接 ✅"
    else
        status="ERROR"
        issues+=("端口不可连接")
        log_error "端口: 不可连接 ❌"
    fi
    
    # 3. 健康检查
    if check_health; then
        log "健康检查: 通过 ✅"
    else
        status="ERROR"
        issues+=("健康检查失败")
        log_error "健康检查: 失败 ❌"
    fi
    
    # 4. 日志分析
    local error_count=$(analyze_logs)
    if [ "$error_count" -gt 0 ]; then
        status="WARNING"
        issues+=("发现 $error_count 个错误")
    fi
    
    # 5. 配置权限检查
    fix_config_permissions
    
    # 综合判断
    if [ "$status" = "OK" ]; then
        log "状态: 正常 ✅"
        echo "OK" > "$LOG_DIR/status"
        # 正常时重置重启计数
        if [ -f "$LOG_DIR/restart_loop_detected" ]; then
            rm "$LOG_DIR/restart_loop_detected"
            send_notification "OpenClaw 已恢复正常，重启循环已解除 ✅" "系统恢复" "OpenClaw Gateway 已重新正常运行" "之前检测到重启循环，已自动修复"
        fi
    else
        # 检查是否是重启循环
        local is_restart_loop=$(echo "${issues[*]}" | grep -c "重启循环" || true)
        
        log "状态: 异常 ⚠️ ${issues[*]}"
        echo "ERROR: ${issues[*]}" > "$LOG_DIR/status"
        
        # 发送通知
        if [ "$is_restart_loop" -gt 0 ]; then
            echo "$(date)" > "$LOG_DIR/restart_loop_detected"
            send_notification "⚠️ OpenClaw 重启循环! ${issues[*]} - 正在修复..." "重启循环" "${issues[*]}" "检测到 Gateway 连续多次重启，可能存在配置错误或资源问题"
        else
            send_notification "OpenClaw 异常: ${issues[*]}" "系统异常" "${issues[*]}" "OpenClaw Gateway 检测到异常状态"
        fi
        
        # 备份配置
        backup_config
        
        # 调用 iFlow CLI 进行分析和修复
        local iflow_result=""
        if [ "$is_restart_loop" -gt 0 ]; then
            iflow_result=$(iflow_fix "重启循环" "${issues[*]}")
        fi
        
        # 传统修复步骤
        fix_jina_key
        restart_gateway
        
        # 最终验证
        sleep 2
        if check_port; then
            log "修复成功 ✅"
            learn_repair_result "success"
            
            # 发送修复成功通知，包含 iFlow 分析结果
            if [ -n "$iflow_result" ]; then
                send_notification "OpenClaw 已自动修复 ✅" "修复成功" "Gateway 已恢复正常运行" "$iflow_result"
            else
                send_notification "OpenClaw 已自动修复 ✅" "修复成功" "Gateway 已恢复正常运行" "已执行: 配置备份、密钥检查、服务重启"
            fi
        else
            log_error "修复失败，需要人工介入"
            learn_repair_result "failed"
            # 发送修复失败通知，包含 iFlow 分析结果
            if [ -n "$iflow_result" ]; then
                send_notification "OpenClaw 修复失败 ⚠️" "修复失败" "${issues[*]}" "$iflow_result"
            else
                send_notification "OpenClaw 修复失败 ⚠️" "修复失败" "${issues[*]}" "已尝试: 备份配置、iFlow分析、密钥检查、服务重启"
            fi
        fi
    fi
    
    log "========== 监控结束 =========="
}

main "$@"
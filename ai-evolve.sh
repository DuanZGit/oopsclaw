#!/bin/bash
#
# iFlow Oopsclaw - AI 自我进化模块 (Meta-Evolution)
# 功能: 调用 iFlow AI 分析故障，生成优化建议，自动应用到监控系统
# 版本: 支持多版本，通过评分系统选择最佳策略
#

set -e

# 配置
OOPSCLAW_DIR="$HOME/.oopsclaw"
EVOLUTIONS_DIR="$OOPSCLAW_DIR/evolutions"
LOG_DIR="$OOPSCLAW_DIR/evolutions/logs"
LEARNED_DIR="$OOPSCLAW_DIR/knowledge/learned"
OPENCLAW_CONFIG="$HOME/.openclaw/openclaw.json"
MONITOR_SCRIPT="$OOPSCLAW_DIR/monitor.sh"
FINGERPRINTS="$OOPSCLAW_DIR/knowledge/base/fingerprints.txt"
FEISHU_USER_ID_FILE="$OOPSCLAW_DIR/feishu_user_id.txt"

# 确保目录存在
mkdir -p "$LEARNED_DIR" "$LOG_DIR"

# 选择最佳进化版本
select_best_evolution() {
    local best=$(python3 "$OOPSCLAW_DIR/ai-evolve-meta.py" --best 2>/dev/null || echo "ai-evolve-v1.0")
    echo "$EVOLUTIONS_DIR/$best.py"
}

# 根据评分记录选择最优版本
EVOLUTION_SCRIPT=$(select_best_evolution)

# 飞书通知函数
send_feishu() {
    local title="$1"
    local message="$2"
    local user_id=""
    
    # 读取飞书用户ID
    if [ -f "$FEISHU_USER_ID_FILE" ]; then
        user_id=$(cat "$FEISHU_USER_ID_FILE")
    fi
    
    if [ -z "$user_id" ]; then
        log_ai "警告: 未配置飞书用户ID"
        return 1
    fi
    
    # 加载环境变量 (必须显式加载)
    source "$HOME/.bashrc" 2>/dev/null || true
    
    # 发送飞书消息
    openclaw message send \
        --channel feishu \
        --target "$user_id" \
        --message "🔔 $title

$message" > /dev/null 2>&1 || true
    
    log_ai "飞书通知已发送: $title"
}

# 飞书卡片消息 (更美观)
send_feishu_card() {
    local title="$1"
    local message="$2"
    local color="$3"  # green/red/yellow/blue
    local user_id=""
    
    if [ -f "$FEISHU_USER_ID_FILE" ]; then
        user_id=$(cat "$FEISHU_USER_ID_FILE")
    fi
    
    if [ -z "$user_id" ]; then
        return 1
    fi
    
    source "$HOME/.bashrc" 2>/dev/null || true
    
    # 构建卡片消息
    local card_json=$(cat <<EOF
{
  "config": {
    "wide_screen_mode": true
  },
  "header": {
    "title": {
      "tag": "plain_text",
      "content": "🔔 $title"
    },
    "template": "$color"
  },
  "elements": [
    {
      "tag": "markdown",
      "content": "$message"
    }
  ]
}
EOF
)
    
    openclaw message send \
        --channel feishu \
        --target "$user_id" \
        --message "$card_json" > /dev/null 2>&1 || true
}

# 日志
log_ai() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [AI] $1" >> "$LOG_DIR/ai-evolve.log"
}

# 加载环境变量
load_env_vars() {
    source "$HOME/.bashrc" 2>/dev/null || true
}

# 构建 LLM Prompt
build_prompt() {
    local error_type="$1"
    local error_message="$2"
    local fix_tried="$3"
    local repair_history="$4"
    local recent_logs="$5"
    
    cat << EOF
你是一个系统自愈专家。请分析以下 iFlow Oopsclaw 监控系统的故障：

## 【问题描述】
错误类型: $error_type
错误信息: $error_message

## 【已尝试的修复】
$fix_tried

## 【修复历史统计】
$repair_history

## 【最近日志】
$recent_logs

## 【当前 fingerprints.txt 内容】
$(cat "$FINGERPRINTS" 2>/dev/null | grep -v "^#" | grep -v "^$")

请生成：
1. 问题根因分析
2. 改进的修复策略（CLI命令形式）
3. 对 monitor.sh 的具体优化建议（如果要修改，输出完整的代码片段）
4. 是否需要更新 fingerprints.txt（如果要添加，输出完整格式）

输出格式必须严格遵守：
## 分析
{分析结果}

## 优化命令
\`\`\`bash
# 具体要执行的命令（如果有）
\`\`\`

## 建议
{对监控系统的改进建议}

## fingerprints更新
{如果要添加新指纹，格式: 错误关键词 | 故障类型 | 修复策略，否则输出 "无需更新"}
EOF
}

# 调用 iFlow AI 分析 (使用评分系统选择最佳版本)
call_llm() {
    local prompt="$1"
    local start_time=$(date +%s)
    
    log_ai "使用进化版本: $(basename $EVOLUTION_SCRIPT)"
    log_ai "调用 iFlow AI 分析..."
    
    # 调用选定的 Python 模块
    local response=$(python3 "$EVOLUTION_SCRIPT" "$prompt" 2>&1)
    
    local end_time=$(date +%s)
    local elapsed=$((end_time - start_time))
    
    # 记录评分
    local tokens_estimate=$(echo "$response" | wc -c | xargs -I {} echo "$(({} / 4))")
    local score_result=$(python3 "$OOPSCLAW_DIR/ai-evolve-meta.py" \
        --score "$(basename $EVOLUTION_SCRIPT .py)" \
        "$tokens_estimate" "$elapsed" "1" "0" "0" 2>/dev/null || true)
    
    log_ai "耗时: ${elapsed}s, Token消耗: ~$tokens_estimate"
    
    if echo "$response" | grep -q "错误:"; then
        log_ai "iFlow 调用失败: $response"
        return 1
    fi
    
    echo "$response"
}

# 解析 LLM 回复并执行
parse_and_apply() {
    local llm_response="$1"
    local timestamp=$(date '+%Y%m%d-%H%M%S')
    
    # 保存原始回复
    echo "$llm_response" > "$LEARNED_DIR/evolution-$timestamp.md"
    log_ai "已保存 AI 分析结果到 evolution-$timestamp.md"
    
    # 提取优化命令
    local commands=$(echo "$llm_response" | sed -n '/## 优化命令/,/## 建议/p' | sed '1d' | sed '/## 建议/d' | sed 's/```bash//g' | sed 's/```//g')
    
    if [ -n "$commands" ]; then
        log_ai "检测到优化命令，尝试执行..."
        echo "$commands" >> "$LOG_DIR/ai-commands.log"
        
        # 执行命令（需要确认）
        # 这里只记录，不自动执行以避免风险
        log_ai "优化命令已记录，需要手动确认执行"
    fi
    
    # 提取建议
    local suggestions=$(echo "$llm_response" | sed -n '/## 建议/,/## fingerprints/p' | sed '1d' | sed '/## fingerprints/d')
    if [ -n "$suggestions" ]; then
        log_ai "AI 建议: $suggestions"
    fi
    
    # 提取 fingerprints 更新
    local fingerprint_update=$(echo "$llm_response" | sed -n '/## fingerprints更新/,/$/p' | tail -n +2)
    if [ -n "$fingerprint_update" ] && [ "$fingerprint_update" != "无需更新" ]; then
        log_ai "更新故障指纹库: $fingerprint_update"
        echo "$fingerprint_update" >> "$FINGERPRINTS"
    fi
}

# 主入口 - 完整进化流程 (AI 分析 + 知识库更新 + 经验积累)
ai_analyze() {
    local error_type="$1"
    local error_message="$2"
    local fix_tried="$3"
    
    log_ai "========== 开始 Oopsclaw 自我进化 =========="
    log_ai "问题: $error_type"
    
    # ========== 节点1: 监控到问题 ==========
    send_feishu_card "⚠️ Oopsclaw 检测到问题" "**问题类型:** $error_type

**错误信息:** $error_message

**已尝试修复:** $fix_tried

🧠 正在调用 AI 分析..." "red"
    
    # 构建上下文
    local context="错误类型: $error_type
错误信息: $error_message
已尝试修复: $fix_tried
修复历史: $(tail -5 "$LOG_DIR/repair_history.log" 2>/dev/null || echo '无')
最近日志: $(ls -t "$HOME/.openclaw/logs"/error*.log 2>/dev/null | head -1 | xargs tail -5 2>/dev/null || echo '无')"
    
    # 调用 Python 模块进行完整进化
    log_ai "调用 iFlow AI 进行全面分析..."
    local start_time=$(date +%s)
    python3 "$OOPSCLAW_DIR/ai-evolve.py" --evolve "$error_type" "$context" > /tmp/ai-evolve-output.txt 2>&1
    local end_time=$(date +%s)
    local elapsed=$((end_time - start_time))
    
    # ========== 节点2: 解决问题 ==========
    local fix_result=$(cat /tmp/ai-evolve-output.txt | grep -A5 "## 分析" | head -10)
    send_feishu_card "✅ 问题已分析" "**问题:** $error_type

**AI 分析结果:**
$fix_result

⏱️ 耗时: ${elapsed}秒

🔄 正在进行修复..." "yellow"
    
    # 保存原始分析结果
    local timestamp=$(date '+%Y%m%d-%H%M%S')
    cat /tmp/ai-evolve-output.txt > "$LEARNED_DIR/evolution-$timestamp.md"
    
    # 检查是否有更新
    local updates=""
    if grep -q "添加了.*个新指纹" /tmp/ai-evolve-output.txt; then
        updates="📚 故障指纹库已更新
"
    fi
    if grep -q "已保存到:.*learned" /tmp/ai-evolve-output.txt; then
        updates="${updates}💾 经验已积累
"
    fi
    
    # ========== 节点3: 进化成功 ==========
    send_feishu_card "🎉 Oopsclaw 进化完成" "**问题:** $error_type

**进化结果:**

$updates

⏱️ 总耗时: ${elapsed}秒

📊 进化版本: $(basename $EVOLUTION_SCRIPT)

✅ 进化完成，监控系统已优化" "green"
    
    log_ai "========== 进化完成 =========="
}

# 主动学习模式 - 分析近期低成功率
ai_learn_from_history() {
    log_ai "开始主动学习模式..."
    
    if [ ! -f "$LOG_DIR/repair_history.log" ]; then
        log_ai "无修复历史，跳过"
        return 0
    fi
    
    # 统计成功率
    local total=$(wc -l < "$LOG_DIR/repair_history.log")
    local success=$(grep -c "success" "$LOG_DIR/repair_history.log" || echo 0)
    local failed=$(grep -c "failed" "$LOG_DIR/repair_history.log" || echo 0)
    
    if [ "$total" -lt 5 ]; then
        log_ai "样本不足 ($total 条)，跳过"
        return 0
    fi
    
    local rate=$((success * 100 / total))
    log_ai "修复成功率: $rate% ($success/$total)"
    
    if [ "$rate" -lt 70 ]; then
        log_ai "成功率过低，开始 AI 分析..."
        ai_analyze "低成功率" "修复成功率: $rate%" "已尝试多种修复策略但效果不佳"
    fi
}

# CLI 入口
main() {
    local action="${1:-analyze}"
    
    case "$action" in
        analyze)
            local error_type="${2:-unknown}"
            local error_message="${3:-no message}"
            local fix_tried="${4:-无}"
            ai_analyze "$error_type" "$error_message" "$fix_tried"
            ;;
        learn)
            ai_learn_from_history
            ;;
        test)
            echo "测试 AI 进化模块..."
            ai_analyze "测试" "这是一条测试消息" "无"
            ;;
        *)
            echo "用法: $0 {analyze|learn|test}"
            echo "  analyze <错误类型> <错误信息> <已尝试修复>"
            echo "  learn - 主动学习模式"
            echo "  test - 测试模式"
            ;;
    esac
}

main "$@"

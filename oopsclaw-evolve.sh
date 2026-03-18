#!/bin/bash
#
# Oopsclaw Prompt 进化模块
# 调用专门的 oopsclaw-evolve agent 进行评估和优化
#

set -euo pipefail

OOPSCLAW_DIR="$HOME/.oopsclaw"
LOG_DIR="$OOPSCLAW_DIR/logs"
KNOWLEDGE_DIR="$OOPSCLAW_DIR/knowledge"
PROMPT_FILE="$HOME/.iflow/agents/guardian.md"
EVOLVE_PROMPT_FILE="$HOME/.iflow/agents/oopsclaw-evolve.md"

# 评分权重
WEIGHT_RESULT=0.4
WEIGHT_TIME=0.2
WEIGHT_TYPE=0.2
WEIGHT_KNOWLEDGE=0.2

# 计算评分
calculate_score() {
    local result="$1"
    local duration="$2"
    local is_new="$3"
    local used_kb="$4"
    
    local score_result=0
    local score_time=0
    local score_type=0
    local score_knowledge=0
    
    # 1. 修复结果
    [ "$result" = "success" ] && score_result=1
    
    # 2. 时间评分
    if [ "$duration" -lt 60 ]; then score_time=1
    elif [ "$duration" -lt 120 ]; then score_time=0.7
    elif [ "$duration" -lt 300 ]; then score_time=0.4
    else score_time=0.2
    fi
    
    # 3. 问题类型
    [ "$is_new" = "yes" ] && score_type=1 || score_type=0.5
    
    # 4. 知识库利用
    [ "$used_kb" = "yes" ] && score_knowledge=1 || score_knowledge=0.3
    
    # 加权总分
    local total_score=$(echo "scale=2; $score_result*$WEIGHT_RESULT + $score_time*$WEIGHT_TIME + $score_type*$WEIGHT_TYPE + $score_knowledge*$WEIGHT_KNOWLEDGE" | bc)
    
    echo "$total_score"
}

# 获取历史成功率
get_success_rate() {
    local history_file="$LOG_DIR/repair_history.log"
    if [ ! -f "$history_file" ] || [ ! -s "$history_file" ]; then
        echo "100"
        return
    fi
    
    local total=$(wc -l < "$history_file")
    local success=$(grep -c "success" "$history_file" 2>/dev/null || echo "0")
    local rate=$(echo "scale=1; $success * 100 / $total" | bc)
    echo "$rate"
}

# 检查是否需要进化
should_evolve() {
    local score="$1"
    local success_rate="$2"
    
    local need_evolve=$(echo "$score < 0.6 || $success_rate < 70" | bc)
    [ "$need_evolve" -eq 1 ] && echo "yes" || echo "no"
}

# 构建进化 agent 的 prompt
build_evolve_prompt() {
    local score="$1"
    local success_rate="$2"
    local last_result="$3"
    local duration="$4"
    local is_new="$5"
    local used_kb="$6"
    local last_error="$7"
    
    # 各维度得分
    local score_result=0
    local score_time=0
    local score_type=0
    local score_knowledge=0
    
    [ "$last_result" = "success" ] && score_result=1
    
    if [ "$duration" -lt 60 ]; then score_time=1
    elif [ "$duration" -lt 120 ]; then score_time=0.7
    elif [ "$duration" -lt 300 ]; then score_time=0.4
    else score_time=0.2
    fi
    
    [ "$is_new" = "yes" ] && score_type=1 || score_type=0.5
    [ "$used_kb" = "yes" ] && score_knowledge=1 || score_knowledge=0.3
    
    cat <<EOF
你是 Oopsclaw 进化优化专家。请分析这次修复的表现并生成优化建议。

## 修复评估数据
- 修复结果: $last_result
- 修复耗时: ${duration}秒
- 问题类型: $([ "$is_new" = "yes" ] && echo "新问题" || echo "常见问题")
- 知识库利用: $([ "$used_kb" = "yes" ] && echo "是" || echo "否")
- 故障类型: $last_error

## 评分详情
- 综合评分: $score (满分1.0)
- 历史成功率: $success_rate%
- 各维度得分:
  - 修复结果: $score_result
  - 修复时间: $score_time
  - 问题类型: $score_type
  - 知识库利用: $score_knowledge

## 知识库文件
请读取以下文件进行分析:
- Oopsclaw Prompt: $PROMPT_FILE
- 修复历史: $LOG_DIR/repair_history.log
- 经验目录: $KNOWLEDGE_DIR/learned/

## 任务
1. 分析这次修复的表现
2. 诊断评分低或成功率低的原因
3. 如果需要优化，输出改进后的 guardian.md 完整内容

## 输出格式
```
## 📊 评估分析
[详细分析]

## 🔍 根因诊断
[具体原因]

## 💡 优化建议
[改进建议]

## 🔄 Prompt 更新
[仅当需要优化时，输出完整的 guardian.md 内容]
```
EOF
}

# 提取并应用新的 prompt
apply_new_prompt() {
    local content="$1"
    
    # 提取 Prompt 更新部分
    local new_prompt=$(echo "$content" | sed -n '/## 🔄 Prompt 更新/,/^##/p' | sed '1d;$d')
    
    if [ -n "$new_prompt" ]; then
        echo "$new_prompt" > "$PROMPT_FILE"
        echo "✅ Oopsclaw prompt 已更新"
        return 0
    fi
    return 1
}

# 记录进化日志
log_evolution() {
    local score="$1"
    local success_rate="$2"
    local evolved="$3"
    local details="$4"
    
    {
        echo "=== $(date '+%Y-%m-%d %H:%M:%S') ==="
        echo "评分: $score, 成功率: $success_rate%, 进化: $evolved"
        echo "$details"
        echo ""
    } >> "$LOG_DIR/evolution.log"
}

# 主函数
main() {
    local last_result="${1:-success}"
    local duration="${2:-60}"
    local is_new="${3:-no}"
    local used_kb="${4:-yes}"
    local last_error="${5:-未知}"
    
    echo "=== Oopsclaw Prompt 进化评估 ==="
    
    # 计算评分
    local score=$(calculate_score "$last_result" "$duration" "$is_new" "$used_kb")
    echo "综合评分: $score"
    
    # 获取成功率
    local success_rate=$(get_success_rate)
    echo "历史成功率: $success_rate%"
    
    # 检查是否需要进化
    local evolve=$(should_evolve "$score" "$success_rate")
    echo "需要进化: $evolve"
    
    if [ "$evolve" = "yes" ]; then
        echo "🚀 调用 Oopsclaw Evolve Agent..."
        
        # 构建 prompt
        local evolve_prompt=$(build_evolve_prompt "$score" "$success_rate" "$last_result" "$duration" "$is_new" "$used_kb" "$last_error")
        
        # 调用 iflow oopsclaw-evolve agent
        local evolution_result
        evolution_result=$(timeout 180 iflow -p "$evolve_prompt" -y 2>&1) || evolution_result="调用失败: $?"
        
        echo "$evolution_result"
        
        # 尝试应用新 prompt
        if apply_new_prompt "$evolution_result"; then
            log_evolution "$score" "$success_rate" "yes" "$evolution_result"
            echo "✅ 进化完成"
        else
            log_evolution "$score" "$success_rate" "no_prompt_change" "$evolution_result"
            echo "⚠️ 未生成新 prompt"
        fi
    else
        echo "✅ 评分良好，无需进化"
        log_evolution "$score" "$success_rate" "skipped" "评分良好"
    fi
}

main "$@"
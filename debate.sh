#!/usr/bin/env bash
set -euo pipefail

# ── 颜色 ──────────────────────────────────────────────
BLUE='\033[34m'
RED='\033[31m'
YELLOW='\033[33m'
GREEN='\033[1;32m'
BOLD='\033[1m'
RESET='\033[0m'

# ── 参数验证 ───────────────────────────────────────────
if [ $# -lt 2 ] || [ $# -gt 4 ]; then
    echo "用法：./debate.sh \"<辩题>\" <轮数> [正方规格] [反方规格]" >&2
    echo "" >&2
    echo "规格格式：cli:model" >&2
    echo "  支持的 CLI：claude, gemini" >&2
    echo "" >&2
    echo "示例：" >&2
    echo "  ./debate.sh \"AI 应该被赋予公民权利\" 3" >&2
    echo "  ./debate.sh \"AI rights\" 3 claude:claude-opus-4-7 gemini:gemini-3.1-pro-preview" >&2
    echo "  ./debate.sh \"AI rights\" 3 claude:claude-opus-4-7 claude:claude-sonnet-4-6" >&2
    echo "  ./debate.sh \"AI rights\" 3 gemini:gemini-2.5-pro gemini:gemini-3.1-pro-preview" >&2
    exit 1
fi

TOPIC="$1"
ROUNDS="$2"
PRO_SPEC="${3:-claude:claude-opus-4-7}"
CON_SPEC="${4:-gemini:gemini-3.1-pro-preview}"

if ! [[ "$ROUNDS" =~ ^[1-9][0-9]*$ ]]; then
    echo "错误：轮数必须为正整数（收到：${ROUNDS}）" >&2
    exit 1
fi

if (( ROUNDS > 20 )); then
    echo "错误：轮数不能超过 20（收到：${ROUNDS}）" >&2
    exit 1
fi

# ── 解析 cli:model 规格 ────────────────────────────────
parse_spec() {
    local spec="$1" field="$2"
    if [[ "$spec" != *:* ]]; then
        echo "错误：规格格式必须为 'cli:model'，收到：'${spec}'" >&2
        exit 1
    fi
    if [ "$field" = "cli" ]; then
        echo "${spec%%:*}"
    else
        echo "${spec#*:}"
    fi
}

PRO_CLI=$(parse_spec "$PRO_SPEC" cli)
PRO_MODEL=$(parse_spec "$PRO_SPEC" model)
CON_CLI=$(parse_spec "$CON_SPEC" cli)
CON_MODEL=$(parse_spec "$CON_SPEC" model)

# Display names shown in terminal and saved to file
PRO_NAME="${PRO_CLI}/${PRO_MODEL}"
CON_NAME="${CON_CLI}/${CON_MODEL}"

# ── 依赖检查 ───────────────────────────────────────────
check_deps() {
    local missing=0
    for cli in "$PRO_CLI" "$CON_CLI"; do
        if ! command -v "$cli" &>/dev/null; then
            echo "错误：未找到 '${cli}' 命令，请先安装对应 CLI" >&2
            missing=1
        fi
    done
    if [ "$missing" -eq 1 ]; then exit 1; fi
}

# ── 辅助：带颜色打印 ──────────────────────────────────
print_color() {
    local color="$1" text="$2"
    echo -e "${color}${text}${RESET}"
}

print_separator() {
    echo -e "${BOLD}══════════════════════════════════════════${RESET}"
}

# ── 辅助：统一调用入口 ────────────────────────────────
CALL_MAX_RETRIES=5
CALL_RETRY_DELAY=30

call_model() {
    local cli="$1" model="$2" prompt="$3"
    local response attempt

    if [ "$cli" != "claude" ] && [ "$cli" != "gemini" ]; then
        echo "[调用失败：不支持的 CLI '${cli}'，仅支持 claude 和 gemini]"
        return
    fi

    for ((attempt=1; attempt<=CALL_MAX_RETRIES; attempt++)); do
        if [ "$cli" = "claude" ]; then
            response=$(claude --model "$model" -p "$prompt" 2>/dev/null) && echo "$response" && return
        else
            response=$(gemini -m "$model" -p "$prompt" 2>/dev/null) && echo "$response" && return
        fi

        if [ "$attempt" -lt "$CALL_MAX_RETRIES" ]; then
            print_color "$YELLOW" "  ⚠ ${cli} call failed (attempt ${attempt}/${CALL_MAX_RETRIES}), retrying in ${CALL_RETRY_DELAY}s..." >&2
            sleep "$CALL_RETRY_DELAY"
        fi
    done

    echo "[调用失败：${cli}/${model} 在 ${CALL_MAX_RETRIES} 次尝试后仍返回错误]"
}

# ── Prompt 构建：辩手 ─────────────────────────────────
build_debater_prompt() {
    local role="$1"    # 正方 | 反方
    local stance="$2"  # 支持 | 反对
    local history="$3"

    local prompt="你是一场辩论赛的${role}。
辩题：${TOPIC}
你的立场：${stance}

"
    if [ -n "$history" ]; then
        prompt+="以下是目前的辩论记录：
${history}

请用 200 字以内给出你这一轮的论点或反驳。要有逻辑、有力度，直接针对对方论点。
不要重复已说过的内容。"
    else
        prompt+="这是第一轮，请给出你的开场陈述，200 字以内。"
    fi

    printf '%s' "$prompt"
}

# ── Prompt 构建：裁判 ─────────────────────────────────
build_judge_prompt() {
    local full_debate="$1"
    printf '%s' "你是一场辩论的独立裁判。
辩题：${TOPIC}
正方：${PRO_NAME}，反方：${CON_NAME}

以下是完整辩论记录：
${full_debate}

请从以下维度评分（各 1-10 分）：
1. 论点逻辑性
2. 反驳有效性
3. 表达清晰度

分别给出正方和反方的总分（满分 30），并宣布获胜者，说明理由（100 字以内）。

最后一行必须是以下格式之一，不得有其他内容：
WINNER: 正方
WINNER: 反方
WINNER: 平局"
}

# ── 解析裁判胜负 ──────────────────────────────────────
parse_winner() {
    local output="$1"
    # || true 防止 grep 无匹配时触发 set -e 退出
    echo "$output" | grep -o 'WINNER: .*' | tail -1 | sed 's/WINNER: //' || true
}

check_deps

# ── 初始化 ────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_FILE="${SCRIPT_DIR}/debate_${TIMESTAMP}.md"

{
    echo "# 辩论记录"
    echo ""
    echo "- **辩题：** ${TOPIC}"
    echo "- **时间：** $(date '+%Y-%m-%d %H:%M:%S')"
    echo "- **轮数：** ${ROUNDS}"
    echo "- **正方：** ${PRO_NAME} | **反方：** ${CON_NAME}"
    echo ""
    echo "---"
    echo ""
} > "$OUTPUT_FILE"

print_separator
print_color "$BOLD" "  LLM Arena 🏟️"
print_color "$BOLD" "  Topic / 辩题：${TOPIC}"
print_color "$BOLD" "  Pro (正方)：${PRO_NAME}"
print_color "$BOLD" "  Con (反方)：${CON_NAME}"
print_color "$BOLD" "  Rounds / 轮数：${ROUNDS}"
print_separator
echo ""

HISTORY=""
FULL_DEBATE=""

# ── 辩论主循环 ────────────────────────────────────────
for ((round=1; round<=ROUNDS; round++)); do
    print_color "$BOLD" "── Round ${round} / ${ROUNDS} (第${round}轮) ──────────────────"
    echo "## Round ${round}" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"

    # 正方
    PRO_PROMPT=$(build_debater_prompt "正方" "支持" "$HISTORY")
    print_color "$BLUE" "[Pro/正方] ${PRO_NAME} thinking..."
    PRO_RESPONSE=$(call_model "$PRO_CLI" "$PRO_MODEL" "$PRO_PROMPT")
    print_color "$BLUE" "[Pro/正方] ${PRO_NAME}"
    echo "$PRO_RESPONSE"
    echo ""
    HISTORY+="[正方] ${PRO_RESPONSE}
"
    FULL_DEBATE+="[正方] ${PRO_RESPONSE}
"
    {
        echo "**[正方] ${PRO_NAME}**"
        echo ""
        echo "$PRO_RESPONSE"
        echo ""
    } >> "$OUTPUT_FILE"

    # 反方
    CON_PROMPT=$(build_debater_prompt "反方" "反对" "$HISTORY")
    print_color "$RED" "[Con/反方] ${CON_NAME} thinking..."
    CON_RESPONSE=$(call_model "$CON_CLI" "$CON_MODEL" "$CON_PROMPT")
    print_color "$RED" "[Con/反方] ${CON_NAME}"
    echo "$CON_RESPONSE"
    echo ""
    HISTORY+="[反方] ${CON_RESPONSE}
"
    FULL_DEBATE+="[反方] ${CON_RESPONSE}
"
    {
        echo "**[反方] ${CON_NAME}**"
        echo ""
        echo "$CON_RESPONSE"
        echo ""
    } >> "$OUTPUT_FILE"
done

# ── 裁判评分 ──────────────────────────────────────────
echo "" >> "$OUTPUT_FILE"
echo "---" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "## 裁判评分" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

print_separator
print_color "$BOLD" "  Judging Phase / 裁判评分阶段"
print_separator
echo ""

JUDGE_PROMPT=$(build_judge_prompt "$FULL_DEBATE")

# 裁判一：正方模型
print_color "$YELLOW" "[Judge 1/裁判1] ${PRO_NAME} scoring..."
JUDGE1_VERDICT=$(call_model "$PRO_CLI" "$PRO_MODEL" "$JUDGE_PROMPT")
print_color "$YELLOW" "[Judge 1/裁判1] ${PRO_NAME}"
echo "$JUDGE1_VERDICT"
echo ""
JUDGE1_WINNER=$(parse_winner "$JUDGE1_VERDICT")

{
    echo "**[裁判-1] ${PRO_NAME}**"
    echo ""
    echo "$JUDGE1_VERDICT"
    echo ""
} >> "$OUTPUT_FILE"

# 裁判二：反方模型
print_color "$YELLOW" "[Judge 2/裁判2] ${CON_NAME} scoring..."
JUDGE2_VERDICT=$(call_model "$CON_CLI" "$CON_MODEL" "$JUDGE_PROMPT")
print_color "$YELLOW" "[Judge 2/裁判2] ${CON_NAME}"
echo "$JUDGE2_VERDICT"
echo ""
JUDGE2_WINNER=$(parse_winner "$JUDGE2_VERDICT")

{
    echo "**[裁判-2] ${CON_NAME}**"
    echo ""
    echo "$JUDGE2_VERDICT"
    echo ""
} >> "$OUTPUT_FILE"

# ── 最终结果 ──────────────────────────────────────────
echo "---" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

print_separator
print_color "$BOLD" "  Final Result / 最终结果"
print_separator

if [ -z "$JUDGE1_WINNER" ] && [ -z "$JUDGE2_WINNER" ]; then
    FINAL_MSG="无法自动判断（两位裁判格式均异常），请查看上方评语"
    print_color "$YELLOW" "⚠ 裁判格式异常，无法解析胜负"
elif [ -z "$JUDGE1_WINNER" ] || [ -z "$JUDGE2_WINNER" ]; then
    FINAL_MSG="无法自动判断（一方裁判格式异常：裁判1→${JUDGE1_WINNER}，裁判2→${JUDGE2_WINNER}），请查看上方评语"
    print_color "$YELLOW" "⚠ 一方裁判格式异常，无法解析胜负"
elif [ "$JUDGE1_WINNER" = "$JUDGE2_WINNER" ]; then
    FINAL_MSG="${JUDGE1_WINNER} 获胜"
    print_color "$GREEN" "最终结果：${FINAL_MSG}"
else
    FINAL_MSG="平局（裁判意见分歧：裁判1→${JUDGE1_WINNER}，裁判2→${JUDGE2_WINNER}）"
    print_color "$GREEN" "最终结果：${FINAL_MSG}"
fi

echo "## 最终结果：${FINAL_MSG}" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
print_separator
print_color "$BOLD" "Debate saved / 辩论记录已保存至：${OUTPUT_FILE}"

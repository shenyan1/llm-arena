#!/usr/bin/env bash
set -euo pipefail

# ── 常量 ──────────────────────────────────────────────
CLAUDE_MODEL="claude-opus-4-7"
GEMINI_MODEL="gemini-3.1-pro-preview"

# ── 颜色 ──────────────────────────────────────────────
BLUE='\033[34m'
RED='\033[31m'
YELLOW='\033[33m'
GREEN='\033[1;32m'
BOLD='\033[1m'
RESET='\033[0m'

# ── 参数验证 ───────────────────────────────────────────
if [ $# -ne 2 ]; then
    echo "用法：./debate.sh \"<辩题>\" <轮数>" >&2
    echo "示例：./debate.sh \"AI 应该被赋予公民权利\" 3" >&2
    exit 1
fi

TOPIC="$1"
ROUNDS="$2"

if ! [[ "$ROUNDS" =~ ^[1-9][0-9]*$ ]]; then
    echo "错误：轮数必须为正整数（收到：${ROUNDS}）" >&2
    exit 1
fi

if (( ROUNDS > 20 )); then
    echo "错误：轮数不能超过 20（收到：${ROUNDS}）" >&2
    exit 1
fi

# ── 依赖检查 ───────────────────────────────────────────
check_deps() {
    local missing=0
    if ! command -v claude &>/dev/null; then
        echo "错误：未找到 'claude' 命令，请安装 Claude CLI" >&2
        missing=1
    fi
    if ! command -v gemini &>/dev/null; then
        echo "错误：未找到 'gemini' 命令，请安装 Gemini CLI" >&2
        missing=1
    fi
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

# ── 辅助：调用 Claude ─────────────────────────────────
call_claude() {
    local prompt="$1"
    local response
    if response=$(claude --model "$CLAUDE_MODEL" -p "$prompt" 2>&1); then
        echo "$response"
    else
        echo "[调用失败：Claude CLI 返回错误]"
    fi
}

# ── 辅助：调用 Gemini ─────────────────────────────────
call_gemini() {
    local prompt="$1"
    local response
    if response=$(gemini -m "$GEMINI_MODEL" -p "$prompt" 2>&1); then
        echo "$response"
    else
        echo "[调用失败：Gemini CLI 返回错误]"
    fi
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
正方：Claude，反方：Gemini

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

# 写入 Markdown 文件头
{
    echo "# 辩论记录"
    echo ""
    echo "- **辩题：** ${TOPIC}"
    echo "- **时间：** $(date '+%Y-%m-%d %H:%M:%S')"
    echo "- **轮数：** ${ROUNDS}"
    echo "- **正方：** Claude (${CLAUDE_MODEL}) | **反方：** Gemini (${GEMINI_MODEL})"
    echo ""
    echo "---"
    echo ""
} > "$OUTPUT_FILE"

# 终端标题
print_separator
print_color "$BOLD" "  AI 辩论赛"
print_color "$BOLD" "  辩题：${TOPIC}"
print_color "$BOLD" "  轮数：${ROUNDS}  模型：${CLAUDE_MODEL} vs ${GEMINI_MODEL}"
print_separator
echo ""

# 初始化历史变量
HISTORY=""
FULL_DEBATE=""

# ── 辩论主循环 ────────────────────────────────────────
for ((round=1; round<=ROUNDS; round++)); do
    print_color "$BOLD" "── 第 ${round} 轮 ──────────────────────────────"
    echo "## 第 ${round} 轮" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"

    # 正方：Claude
    PRO_PROMPT=$(build_debater_prompt "正方" "支持" "$HISTORY")
    print_color "$BLUE" "[正方-Claude] 思考中..."
    PRO_RESPONSE=$(call_claude "$PRO_PROMPT")
    print_color "$BLUE" "[正方-Claude]"
    echo "$PRO_RESPONSE"
    echo ""
    HISTORY+="[正方] ${PRO_RESPONSE}
"
    FULL_DEBATE+="[正方-Claude] ${PRO_RESPONSE}
"
    {
        echo "**[正方-Claude]**"
        echo ""
        echo "$PRO_RESPONSE"
        echo ""
    } >> "$OUTPUT_FILE"

    # 反方：Gemini
    CON_PROMPT=$(build_debater_prompt "反方" "反对" "$HISTORY")
    print_color "$RED" "[反方-Gemini] 思考中..."
    CON_RESPONSE=$(call_gemini "$CON_PROMPT")
    print_color "$RED" "[反方-Gemini]"
    echo "$CON_RESPONSE"
    echo ""
    HISTORY+="[反方] ${CON_RESPONSE}
"
    FULL_DEBATE+="[反方-Gemini] ${CON_RESPONSE}
"
    {
        echo "**[反方-Gemini]**"
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
print_color "$BOLD" "  裁判评分阶段"
print_separator
echo ""

JUDGE_PROMPT=$(build_judge_prompt "$FULL_DEBATE")

# 裁判一：Claude
print_color "$YELLOW" "[裁判-Claude] 评分中..."
CLAUDE_VERDICT=$(call_claude "$JUDGE_PROMPT")
print_color "$YELLOW" "[裁判-Claude]"
echo "$CLAUDE_VERDICT"
echo ""
CLAUDE_WINNER=$(parse_winner "$CLAUDE_VERDICT")

{
    echo "**[裁判-Claude]**"
    echo ""
    echo "$CLAUDE_VERDICT"
    echo ""
} >> "$OUTPUT_FILE"

# 裁判二：Gemini
print_color "$YELLOW" "[裁判-Gemini] 评分中..."
GEMINI_VERDICT=$(call_gemini "$JUDGE_PROMPT")
print_color "$YELLOW" "[裁判-Gemini]"
echo "$GEMINI_VERDICT"
echo ""
GEMINI_WINNER=$(parse_winner "$GEMINI_VERDICT")

{
    echo "**[裁判-Gemini]**"
    echo ""
    echo "$GEMINI_VERDICT"
    echo ""
} >> "$OUTPUT_FILE"

# ── 最终结果 ──────────────────────────────────────────
echo "---" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

print_separator
print_color "$BOLD" "  最终结果"
print_separator

if [ -z "$CLAUDE_WINNER" ] && [ -z "$GEMINI_WINNER" ]; then
    FINAL_MSG="无法自动判断（两位裁判格式均异常），请查看上方评语"
    print_color "$YELLOW" "⚠ 裁判格式异常，无法解析胜负"
elif [ -z "$CLAUDE_WINNER" ] || [ -z "$GEMINI_WINNER" ]; then
    FINAL_MSG="无法自动判断（一方裁判格式异常：Claude裁判→${CLAUDE_WINNER}，Gemini裁判→${GEMINI_WINNER}），请查看上方评语"
    print_color "$YELLOW" "⚠ 一方裁判格式异常，无法解析胜负"
elif [ "$CLAUDE_WINNER" = "$GEMINI_WINNER" ]; then
    FINAL_MSG="${CLAUDE_WINNER} 获胜"
    print_color "$GREEN" "最终结果：${FINAL_MSG}"
else
    FINAL_MSG="平局（裁判意见分歧：Claude裁判→${CLAUDE_WINNER}，Gemini裁判→${GEMINI_WINNER}）"
    print_color "$GREEN" "最终结果：${FINAL_MSG}"
fi

echo "## 最终结果：${FINAL_MSG}" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
print_separator
print_color "$BOLD" "辩论记录已保存至：${OUTPUT_FILE}"

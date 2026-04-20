#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0; FAIL=0

assert_exit() {
    local desc="$1"; local expected="$2"; local actual="$3"
    if [ "$actual" -eq "$expected" ]; then
        echo "✓ $desc"; PASS=$((PASS + 1))
    else
        echo "✗ $desc (期望退出码 $expected，实际 $actual)"; FAIL=$((FAIL + 1))
    fi
}

# Setup mock CLIs so check_deps passes
mkdir -p /tmp/debate_mock
printf '#!/bin/bash\necho "mock-ok"\necho "WINNER: 正方"\n' > /tmp/debate_mock/claude
printf '#!/bin/bash\necho "mock-ok"\necho "WINNER: 正方"\n' > /tmp/debate_mock/gemini
chmod +x /tmp/debate_mock/claude /tmp/debate_mock/gemini
trap 'rm -rf /tmp/debate_mock' EXIT

# 无参数 → 退出码 1
PATH="/tmp/debate_mock:$PATH" bash "$SCRIPT_DIR/debate.sh" 2>/dev/null; EXIT=$?; assert_exit "无参数时退出" 1 $EXIT

# 只有一个参数 → 退出码 1
PATH="/tmp/debate_mock:$PATH" bash "$SCRIPT_DIR/debate.sh" "辩题" 2>/dev/null; EXIT=$?; assert_exit "只有一个参数时退出" 1 $EXIT

# 轮数为 0 → 退出码 1
PATH="/tmp/debate_mock:$PATH" bash "$SCRIPT_DIR/debate.sh" "辩题" 0 2>/dev/null; EXIT=$?; assert_exit "轮数为0时退出" 1 $EXIT

# 轮数为非数字 → 退出码 1
PATH="/tmp/debate_mock:$PATH" bash "$SCRIPT_DIR/debate.sh" "辩题" abc 2>/dev/null; EXIT=$?; assert_exit "轮数为字母时退出" 1 $EXIT

# 轮数超过20 → 退出码 1
PATH="/tmp/debate_mock:$PATH" bash "$SCRIPT_DIR/debate.sh" "辩题" 21 2>/dev/null; EXIT=$?; assert_exit "轮数超过20时退出" 1 $EXIT

# 规格格式错误（无冒号）→ 退出码 1
PATH="/tmp/debate_mock:$PATH" bash "$SCRIPT_DIR/debate.sh" "辩题" 2 "badspec" 2>/dev/null; EXIT=$?; assert_exit "规格格式错误时退出" 1 $EXIT

# 默认规格（不传正反方）→ 退出码 0
PATH="/tmp/debate_mock:$PATH" bash "$SCRIPT_DIR/debate.sh" "测试辩题" 1 >/dev/null 2>&1; EXIT=$?; assert_exit "默认规格成功退出" 0 $EXIT

# 自定义规格 claude vs claude → 退出码 0
PATH="/tmp/debate_mock:$PATH" bash "$SCRIPT_DIR/debate.sh" "测试辩题" 1 "claude:claude-opus-4-7" "claude:claude-sonnet-4-6" >/dev/null 2>&1; EXIT=$?; assert_exit "claude vs claude 成功退出" 0 $EXIT

# 自定义规格 gemini vs gemini → 退出码 0
PATH="/tmp/debate_mock:$PATH" bash "$SCRIPT_DIR/debate.sh" "测试辩题" 1 "gemini:gemini-2.5-pro" "gemini:gemini-3.1-pro-preview" >/dev/null 2>&1; EXIT=$?; assert_exit "gemini vs gemini 成功退出" 0 $EXIT

echo ""
echo "── 集成测试 ──"

# 运行完整辩论（默认规格）
output=$(PATH="/tmp/debate_mock:$PATH" bash "$SCRIPT_DIR/debate.sh" "集成测试辩题" 2 2>&1)
exit_code=$?

assert_exit "脚本正常退出（exit 0）" 0 $exit_code

echo "$output" | grep -q "Round 1" && echo "✓ 包含第1轮标题" || { echo "✗ 缺少第1轮标题"; FAIL=$((FAIL + 1)); }
echo "$output" | grep -q "Round 2" && echo "✓ 包含第2轮标题" || { echo "✗ 缺少第2轮标题"; FAIL=$((FAIL + 1)); }
echo "$output" | grep -q "裁判评分阶段" && echo "✓ 包含裁判阶段" || { echo "✗ 缺少裁判阶段"; FAIL=$((FAIL + 1)); }
echo "$output" | grep -q "正方 获胜" && echo "✓ 正确显示获胜方" || { echo "✗ 未显示获胜方"; FAIL=$((FAIL + 1)); }

# 验证输出文件存在且格式正确
md_file=$(ls "$SCRIPT_DIR"/debate_*.md 2>/dev/null | tail -1)
if [ -n "$md_file" ]; then
    echo "✓ 输出文件已创建：$(basename "$md_file")"
    grep -q "# 辩论记录" "$md_file" && echo "✓ 文件包含标题" || { echo "✗ 文件缺少标题"; FAIL=$((FAIL + 1)); }
    grep -q "## Round 1" "$md_file" && echo "✓ 文件包含第1轮" || { echo "✗ 文件缺少第1轮"; FAIL=$((FAIL + 1)); }
    grep -q "## 裁判评分" "$md_file" && echo "✓ 文件包含裁判评分" || { echo "✗ 文件缺少裁判评分"; FAIL=$((FAIL + 1)); }
    grep -q "## 最终结果" "$md_file" && echo "✓ 文件包含最终结果" || { echo "✗ 文件缺少最终结果"; FAIL=$((FAIL + 1)); }
    rm -f "$md_file"
else
    echo "✗ 未找到输出文件"
    FAIL=$((FAIL + 1))
fi

echo ""; echo "结果：${PASS} 通过，${FAIL} 失败"
[ "$FAIL" -eq 0 ]

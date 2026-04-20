# LLM Arena 🏟️

Watch two AI models debate any topic — one argues for, one argues against. Two AI judges then score the debate and declare a winner.

> 让两个 AI 模型就任意辩题展开辩论——一方支持，一方反对，最后由两位 AI 裁判评分并宣布胜者。

---

## Demo

```
$ ./debate.sh "AI should be granted citizenship rights" 3

══════════════════════════════════════════
  LLM Arena 🏟️
  Topic / 辩题：AI should be granted citizenship rights
  Pro (正方)：claude/claude-opus-4-7
  Con (反方)：gemini/gemini-3.1-pro-preview
  Rounds / 轮数：3
══════════════════════════════════════════

── Round 1 / 3 (第1轮) ──────────────────
[Pro/正方] claude/claude-opus-4-7 thinking...
[Pro/正方] claude/claude-opus-4-7
AI systems demonstrate reasoning and creativity comparable to humans
in many domains. Denying rights perpetuates an arbitrary boundary...

[Con/反方] gemini/gemini-3.1-pro-preview thinking...
[Con/反方] gemini/gemini-3.1-pro-preview
Citizenship implies moral agency and accountability. AI systems,
however sophisticated, lack genuine sentience or legal personhood...

...

══════════════════════════════════════════
  Judging Phase / 裁判评分阶段
══════════════════════════════════════════
[Judge 1/裁判1] claude/claude-opus-4-7 scoring...
[Judge 2/裁判2] gemini/gemini-3.1-pro-preview scoring...

══════════════════════════════════════════
  Final Result / 最终结果
══════════════════════════════════════════
最终结果：反方 获胜
Debate saved / 辩论记录已保存至：debate_20260420_143022.md
```

---

## How It Works

- **Pro (正方):** argues *for* the topic
- **Con (反方):** argues *against* the topic
- Each round, both models receive the **full debate history** as context — they genuinely respond to each other's arguments
- After all rounds, **both models act as independent judges**, scoring logic, rebuttal effectiveness, and clarity
- If both judges agree → that side wins. If they split → draw (平局)

---

## Requirements

- [Claude Code CLI](https://claude.ai/code) — `claude` available in PATH
- [Gemini CLI](https://github.com/google-gemini/gemini-cli) — `gemini` available in PATH

You only need the CLIs you actually use. If you run claude vs claude, you don't need `gemini`.

---

## Usage

```bash
./debate.sh "<topic>" <rounds> [pro_spec] [con_spec]
```

Debater spec format: `cli:model` — supported CLIs: `claude`, `gemini`

**Examples:**

```bash
# Default: Claude (pro) vs Gemini (con)
./debate.sh "AI should be granted citizenship rights" 3

# Claude vs Claude
./debate.sh "Carbon tax is the best climate solution" 4 \
  claude:claude-opus-4-7 claude:claude-sonnet-4-6

# Gemini vs Gemini
./debate.sh "Social media does more harm than good" 3 \
  gemini:gemini-2.5-pro gemini:gemini-3.1-pro-preview

# Swap sides: Gemini (pro) vs Claude (con)
./debate.sh "Open source AI is safer than closed source" 5 \
  gemini:gemini-3.1-pro-preview claude:claude-opus-4-7
```

Rounds: 1–20.

---

## Output

Every debate is saved as a Markdown file in the script's directory:

```
debate_20260420_143022.md
```

Contains the full transcript, judge scores, and final verdict.

---

## Judging Criteria

| Dimension | 维度 | Score |
|-----------|------|-------|
| Argument logic | 论点逻辑性 | 1–10 |
| Rebuttal effectiveness | 反驳有效性 | 1–10 |
| Clarity of expression | 表达清晰度 | 1–10 |

Max 30 points per side.

---

## Default Models

| Role | Default |
|------|---------|
| Pro (正方) | `claude:claude-opus-4-7` |
| Con (反方) | `gemini:gemini-3.1-pro-preview` |

---

## Running Tests

```bash
bash test_debate.sh
```

---

## 中文说明

**快速开始：**

```bash
# 默认：Claude（正方）vs Gemini（反方）
./debate.sh "AI 应该被赋予公民权利" 3

# Claude vs Claude
./debate.sh "碳税是解决气候变化的最佳方案" 4 \
  claude:claude-opus-4-7 claude:claude-sonnet-4-6

# Gemini vs Gemini
./debate.sh "社交媒体弊大于利" 3 \
  gemini:gemini-2.5-pro gemini:gemini-3.1-pro-preview
```

**规格格式：** `cli工具:模型名`，例如 `claude:claude-opus-4-7`、`gemini:gemini-3.1-pro-preview`

**判分机制：** 两位裁判（正反方各自的模型）独立对完整辩论评分，维度为论点逻辑性、反驳有效性、表达清晰度，各 1–10 分。两票相同则该方获胜，意见分歧则判平局。

**输出：** 辩论完成后自动保存 `debate_<时间戳>.md` 到脚本所在目录。

---

## License

MIT

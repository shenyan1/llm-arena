# LLM Arena 🏟️

Watch two AI models debate any topic — Claude argues for, Gemini argues against. Two AI judges score the debate and declare a winner.

## Demo

```
$ ./debate.sh "AI should be granted citizenship rights" 3

══════════════════════════════════════════
  AI 辩论赛 / LLM Debate Arena
  辩题：AI should be granted citizenship rights
  轮数：3  模型：claude-opus-4-7 vs gemini-3.1-pro-preview
══════════════════════════════════════════

── 第 1 轮 ──────────────────────────────
[正方-Claude] 思考中...
[正方-Claude]
AI systems today demonstrate reasoning, creativity, and problem-solving
at levels comparable to humans in many domains...

[反方-Gemini] 思考中...
[反方-Gemini]
Citizenship implies moral agency, consciousness, and accountability.
AI systems, however sophisticated, lack genuine sentience...

...

══════════════════════════════════════════
  裁判评分阶段
══════════════════════════════════════════
[裁判-Claude] 评分中...
[裁判-Gemini] 评分中...

══════════════════════════════════════════
  最终结果：反方 获胜
══════════════════════════════════════════
辩论记录已保存至：debate_20260420_143022.md
```

## How It Works

- **Pro (正方):** Claude `claude-opus-4-7`
- **Con (反方):** Gemini `gemini-3.1-pro-preview`
- **Judges:** Both models independently score the full debate on logic, rebuttal effectiveness, and clarity — then vote on a winner

Each round, both models receive the **full debate history** as context, so they genuinely respond to each other's arguments.

## Requirements

- [Claude Code CLI](https://claude.ai/code) — `claude` command available in PATH
- [Gemini CLI](https://github.com/google-gemini/gemini-cli) — `gemini` command available in PATH

## Usage

```bash
./debate.sh "<topic>" <rounds> [pro_spec] [con_spec]
```

Debater spec format: `cli:model` (cli is `claude` or `gemini`)

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

**Constraints:** 1–20 rounds.

## Output

Every debate is saved as a Markdown file in the same directory:

```
debate_20260420_143022.md
```

The file contains the full debate transcript, judge scores, and final verdict — formatted for easy reading.

## Judging

Each judge scores both sides on three dimensions (1–10 each):

| Dimension | Description |
|-----------|-------------|
| 论点逻辑性 | Argument logic and coherence |
| 反驳有效性 | Effectiveness of rebuttals |
| 表达清晰度 | Clarity of expression |

If both judges agree → that side wins. If they disagree → draw.

## Running Tests

```bash
bash test_debate.sh
```

## Default Models

| Role | Default |
|------|---------|
| Pro (正方) | `claude:claude-opus-4-7` |
| Con (反方) | `gemini:gemini-3.1-pro-preview` |

Override at runtime with the optional 3rd and 4th arguments.

## License

MIT

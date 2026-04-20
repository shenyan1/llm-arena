# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Run tests
bash test_debate.sh

# Syntax check
bash -n debate.sh

# Run a debate (requires claude and gemini CLIs)
./debate.sh "topic" <rounds> [pro_spec] [con_spec]
```

## Architecture

Single-file Bash script (`debate.sh`) with a linear execution flow:

1. **Arg parsing** — topic, rounds (1–20), optional `cli:model` specs for pro and con (defaults: `claude:claude-opus-4-7` vs `gemini:gemini-3.1-pro-preview`)
2. **`call_model cli model prompt`** — unified dispatcher; routes to `claude --model M -p` or `gemini -m M -p`; returns `[调用失败：...]` on error instead of exiting
3. **Debate loop** — N rounds of pro then con; each call receives the full `$HISTORY` string as context; `$FULL_DEBATE` accumulates labeled entries for judges
4. **Judging** — both models score the full debate independently; `parse_winner` greps for a required `WINNER: 正方/反方/平局` line; final result handles both-empty / one-empty / agree / disagree cases
5. **Output** — ANSI colors to terminal + Markdown file saved to script's own directory

## Debater spec format

`cli:model` — e.g. `claude:claude-opus-4-7`, `gemini:gemini-3.1-pro-preview`. Both pro and con can use the same CLI (claude vs claude, gemini vs gemini).

## Testing approach

`test_debate.sh` uses mock CLIs injected via `PATH="/tmp/debate_mock:$PATH"`. Mocks are created inline and cleaned up via `trap`. Tests cover arg validation, spec format errors, all model combinations, and a full integration run that checks both terminal output and the generated `.md` file.

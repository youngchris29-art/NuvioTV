---
name: codex-review
description: Run a Codex (OpenAI) code review from Claude Code on the highest model the Codex account can use, with a VERDICT line and exit code. Use for "codex review", "run codex on this", "second-model review", review→fix→re-review loops before a merge or cut, and whenever the Codex plugin's /codex:review is unavailable to the model. Resolves the model from ~/.codex/models_cache.json so a newer model is picked up the day the account gets it.
---

# Codex review

A second model family reads the change. The script picks the best model the account lists,
runs Codex read-only, and prints the answer with a `VERDICT:` line.

## Run it

```bash
.claude/skills/codex-review/tools/review.sh --repo NuvioMobile --base <prior-sha>   # landed commits <sha>..HEAD
.claude/skills/codex-review/tools/review.sh --repo NuvioMobile                      # working tree
.claude/skills/codex-review/tools/review.sh --commit <sha> --focus "<what to look hardest at>"
.claude/skills/codex-review/tools/review.sh --models                                # what the account can use, best first
```

Exit codes: `0` CLEAN, `3` findings, `2` no verdict (open the log named on the second line).

For anything beyond a two-file diff run it with `run_in_background: true` and `--out <scratchpad>/x.log`;
a round takes 2–8 minutes at `xhigh` and Codex runs its own greps and git probes during it.

## Model and effort

- Model: the first `visibility = "list"` entry by `priority` in `~/.codex/models_cache.json`
  (today `gpt-5.6-terra`; `gpt-6-*` slugs are rejected for a ChatGPT account, and the cache's
  "Older …" descriptions mean a newer tier exists but is not unlocked). Override with
  `--model` or `CODEX_REVIEW_MODEL`. `~/.codex/config.toml` is also pinned to the same slug so
  the plugin, `/codex:rescue`, and the slopmonster cleanse inherit it.
- Effort: `xhigh` by default. `max` is accepted on terra and roughly doubles the wall time;
  `ultra` adds automatic task delegation (Codex spawns its own sub-tasks) and is untested here.
  Override with `--effort` or `CODEX_REVIEW_EFFORT`.
- The cache refreshes whenever the Codex CLI or app runs. If `--models` shows a new slug at a
  lower priority number, the next review uses it with no edit.

## The loop

1. Review (`--base <sha-before-the-work>`), read every finding in full, decide P1/P2 fixes.
2. Fix in the main session or delegate per the agent-delegation playbook; commit.
3. Re-review the same `--base`. Repeat until `VERDICT: CLEAN`. Precedent: 15 rounds on the
   credential-sync port, 4–11 rounds per wave on beta.11; real findings surfaced every round.
4. Declines are documented in the batch record, never silently dropped.

## Rules the script enforces, and why

- The `codex` invocation is never piped. `| head` sent SIGPIPE to the parent and the job vanished.
- stdin is `/dev/null`, sandbox `read-only`, approvals `never`.
- Run from an unsandboxed shell. Sandboxed Bash makes the Codex CLI fail at init with
  "Operation not permitted", and the rescue agent silently substituted a non-Codex fallback.
- `--native` switches to Codex's own `codex review` subcommand (its built-in reviewer prompt,
  `--base` expects a branch name). The `exec` brief is the default because it is what the
  fork's review history ran on and it guarantees the `VERDICT:` line.

## When Codex is down

A usage-limit message names the reset time (hourly). "Reviewer failed to output a response"
was the usage limit, not a model fault. The stand-in that worked: an Opus read-only review
agent over the same `--base` range, recorded as "internal round" in the batch doc.

# Upstream port plan — 2026-09-03

## Upstream movement

`upstream/cmp-rewrite` (`github.com/NuvioMedia/NuvioMobile`) has **not moved**
since 2026-09-02 — still pinned at `9b09045f`, zero new commits
(`git log 9b09045f..upstream/cmp-rewrite --oneline` is empty after a fresh
`git fetch upstream cmp-rewrite`). This is the first no-movement day since the
09-01/09-02 pair of daily-mover days.

Also checked: `upstream/copilot/refactor-project-structure` still fetches
fine but remains the stale/abandoned ref noted previously (the fork's own
mirror branch was deleted 2026-08-21). `upstream/simkl` no longer exists as a
remote ref at all (`fatal: couldn't find remote ref simkl`) — consistent with
the 2026-08-19 note that it was fully merged into `cmp-rewrite` with zero
unique commits and has since been deleted upstream-side. Neither is an
action item.

## Fork state check

Re-verified (not trusted from CLAUDE.md) that the fork's own tree matches
what was logged as merged 2026-09-02:

- `NuvioMobile` submodule on `tvos-shared-extraction`, HEAD `3b140cc7`,
  matches the outer repo's pinned submodule pointer
  (`git submodule status` shows no drift, `tvos-v0.3.0-beta.16-27-g3b140cc7`).
- This is the same tip CLAUDE.md recorded for the upstream-batch8 merge
  (auto-play source-loading-scope fix), so no re-verification of that
  specific diff was needed today — just confirmed the pointer hasn't
  regressed.

## Action items for Claude Code

**None new.** Upstream produced zero commits today, so there is nothing to
port.

Carried, unchanged from prior runs (not re-actioned today, listed for
continuity only):

- **[Device pass owed]** Upstream batch 8 (`58864ec1` auto-play
  source-loading-scope) — merged into `tvos-shared-extraction` 2026-09-02,
  device pass still owed for the non-default auto-play-source-scope case
  specifically (default-scope behavior already covered by the 09-02 device
  pass of batch 7's items). This is a manual QA step, not a coding task.
- **[Unfiled upstream-report candidates, 4 total]** Simkl list-mutation
  precedence divergence, FNV size-prefixing hardening, `CatalogRepository`
  harder guard, TMDB `putIfAbsent`→`getOrPut` KMP-compat fix — all
  fork-found-it-first cases worth reporting back to
  `NuvioMedia/NuvioMobile`, still not filed as of this run.
- **[PARKED/DEFERRED by product decision]** Supporter perks v1, subtitle
  minimum font size — no action until re-raised.
- **[LOW, spot-check only]** Player pause-description staleness — verify
  next time the tvOS player/pause-overlay UI gets touched.

## Verification method

- `git fetch upstream cmp-rewrite` in `NuvioMobile/`; compared fetched
  `upstream/cmp-rewrite` HEAD (`9b09045f`) against the last-recorded pointer
  (`9b09045f` from the 2026-09-02 run) — identical, confirmed via
  `git log 9b09045f..upstream/cmp-rewrite --oneline` returning zero lines.
- `git fetch upstream copilot/refactor-project-structure` and
  `git fetch upstream simkl` to check the other two upstream refs for
  movement/existence.
- `git submodule status` in the outer repo + `git log -1` on
  `tvos-shared-extraction` in the submodule, to confirm no untracked drift
  between the outer pointer and the submodule's actual HEAD.

# Upstream port plan — 2026-09-30

## Upstream movement

`upstream/cmp-rewrite` (`github.com/NuvioMedia/NuvioMobile`) has **not moved**
since the 09-29 check — still pinned at `c1065d0a`, zero new commits
(`git fetch upstream cmp-rewrite` then `git log c1065d0a..upstream/cmp-rewrite
--oneline` returns nothing, verified fresh this run).

## Fork state check

The fork doesn't need anything from the 09-29 backlog report anymore — nearly
all of it was ported and merged **since** that report was written. Per the
`OUTCOME ADDENDUM` appended to `docs/upstream-port-plan-2026-09-29.md`: branch
`claude/upstream-batch10` (43 commits, `dd85a154`..`d694f65a`) was merged into
`tvos-shared-extraction` on 2026-09-30, fast-forwarding the submodule
`243da21b` (rc12) → `3449db86` (rc13) → `d694f65a` (batch 10), with the outer
repo's submodule pointer bumped to match (`188d240`).

Confirmed independently this run by reading the submodule directly (not just
trusting the addendum): `NuvioMobile` HEAD is `d694f65a`
(`tvos-v0.3.0-beta.18-rc5-128-gd694f65a` per `git describe`), matching the
addendum's stated batch-10 tip, with no drift between the outer pointer and
the submodule's actual checkout (`git submodule status` clean).

Device pass for the batch 10 items: **19/19 PASS** on 2026-09-30 (Living Room
Apple TV 4K, Debug build 129 of `d694f65a`) — covers all four Simkl sync bugs,
MDBList account/watchlist integration, custom poster URLs, episode shuffle,
IntroDB movie segments, TVDB anime-ID preference, and the anime/subtitle/TMDB
carried items from 09-15/09-16.

**Bottom line:** everything upstream shipped through `c1065d0a` is now in the
fork. There is nothing new to port today.

## Action items for Claude Code

None of these are upstream-porting work — they're loose ends from the 09-29
backlog run and the batch 10 merge that are still open:

1. **[housekeeping]** Local `main` was 1 commit ahead of `origin/main`,
   unpushed (`a309008` "docs: device pass covered batch 10 only; rc13 items
   still owe theirs"). **Pushed as part of this run**, along with this file
   and the CLAUDE.md update below.
2. **[owed, explicit TODO from the 09-29 addendum]** Cherry-pick `81da5470`
   (Reddit repoint, branch `claude/reddit-thread-repoint`) onto the next cut,
   before the build bump.
3. **[device QA, blocks the next cut]** rc13's Steven items — BUG-110/112/
   114/117/118, FEAT-38/40/42/44 — were **not** exercised in the 09-30 device
   pass (that pass covered batch 10 only, per the addendum's same-day
   correction). They still need their own device pass.
4. **[upstream contribution, 9 items queued, not yet filed]** File the
   "upstream-report candidates (new this batch)" list from the 09-29 addendum
   as GitHub issues on `NuvioMedia/NuvioMobile` — real bugs the fork found
   while porting that upstream still has (the fork has already worked around
   or fixed its own copy of each):
   - `db6c3128`'s Library collector compares `Unit` to `Unit` and never fires.
   - `fromKeys` maps an empty set to all screens.
   - `toLibraryItem` persists the custom poster URL (with the RPDB key) into
     synced library rows.
   - `withCustomPosterUrl` cannot restore a null original.
   - MDBList watched adapter has no whole-series guard (same bug class as
     `ba786215`, already fixed fork-side).
   - `6aa42153` breaks absolute-numbered packs (season > 1 on such a pack
     returns null).
   - `77ce8a73`'s tail heuristic holds up-next on most anime episodes.
   - `shouldApplyMoreLikeThisSource` ignores SIMKL.
   - `MdbListSettingsRepository`'s eager `combine` publishes asynchronously.
5. **[stale doc, this run's own finding]** `CLAUDE.md`'s upstream-check
   paragraph still described the pre-merge 09-29 backlog state (four
   "unported" bugs, MDBList "not confirmed," feature-sized items "needs a
   dedicated session," etc.) even though all of that landed in batch 10 on
   2026-09-30. **Updated as part of this run** to reflect the merged state —
   see the diff on `CLAUDE.md`.

## Maintenance-mode note

Upstream hasn't produced a single commit since `c1065d0a` (09-29), and the
fork just absorbed everything through that point. There's nothing to diff
until `NuvioMedia/NuvioMobile` pushes new commits to `cmp-rewrite`. The next
real port-scan should start from `c1065d0a`.

## Verification method

- `git fetch upstream cmp-rewrite` in `NuvioMobile/`; compared fetched
  `upstream/cmp-rewrite` (`c1065d0a`) against the last-recorded pointer
  (`c1065d0a` from the 09-29 run) — identical, `git log
  c1065d0a..upstream/cmp-rewrite --oneline` returned zero lines.
- `git rev-parse HEAD` + `git describe` in `NuvioMobile/` (`d694f65a`)
  cross-checked against the 09-29 addendum's stated batch-10 tip, and `git
  submodule status` in the outer repo (no drift).
- `git log origin/main..HEAD` / `HEAD..origin/main` in the outer repo to
  confirm what was pushed vs. not before this run.
- Read `docs/upstream-port-plan-2026-09-29.md` in full, including the
  `OUTCOME ADDENDUM`, to avoid re-reporting already-ported items as new
  findings.

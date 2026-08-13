# Upstream port check — 2026-08-08 (scheduled)

## Headline: zero new upstream commits. Nothing to port this run.

Fork state checked this run: outer repo `main` at `a6f7161` (submodule pointer bump only — clean tree otherwise). Submodule `NuvioMobile` HEAD `d8c06127` on `tvos-v0.3.0-beta.10-35-gd8c06127`.

`upstream/cmp-rewrite` (NuvioMedia/NuvioMobile) unchanged since 2026-08-07: still at `3ac0a14c`. Zero new commits (`git log 3ac0a14c..origin/cmp-rewrite` returns empty). Quietest window on record — beats the 1-commit day on 08-07.

`upstream/copilot/refactor-project-structure` still stale at `cbc9fc4f` (last upstream commit 2026-03-24) — no action, still abandoned. Confirmed via `git remote show origin`: upstream only has these two branches, `cmp-rewrite` is HEAD/default — no other branch is being missed by this check's scope.

---

## Confirmed landed since last check (no action needed)

- **Simkl library poster resolution fix (2026-08-07 action item)** — fully ported and verified this run. `shared/src/commonMain/kotlin/com/nuvio/app/features/simkl/SimklProjections.kt:337` now reads `_m.webp` (grep for `_ca.webp` in that file returns nothing). Landed via fork commit `a6f7161` "bump NuvioMobile: Simkl poster res port (upstream 3ac0a14c -> fork d8c06127)". No re-check needed on this item going forward.

---

## Action items this run

None. No new upstream commits since the last check to evaluate.

---

## Checked, not applicable

Nothing changed upstream this run — 0-commit window on both tracked branches. No new work to triage.

---

## Next scheduled check

Re-fetch `upstream/cmp-rewrite` and diff past `3ac0a14c` (still the tip as of this run). If still 0 commits, repeat with no report needed beyond a status line; if commits land, evaluate per the usual process (check tvOS relevance, composeApp-only vs shared/, file-existence verification before porting).

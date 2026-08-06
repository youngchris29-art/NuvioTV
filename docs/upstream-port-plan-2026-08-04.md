# Upstream port check — 2026-08-04 (scheduled)

## Headline: nothing new to port. `upstream/cmp-rewrite` has not moved since yesterday's check (still `ae5c8f74`), and everything flagged in the 08-03 report (Items D, E, F, G) already landed in the fork overnight.

Fork state checked this run: outer repo HEAD `6b9ea32` ("bump NuvioMobile: Simkl tracking provider on Apple TV"), submodule `NuvioMobile` HEAD `b20d7a33` on `tvos-shared-extraction`.

`upstream/cmp-rewrite` (NuvioMedia/NuvioMobile) tip is still `ae5c8f74` ("bump version", 2026-08-03T15:53:54+05:30) — zero new commits since the last scheduled check. `upstream/copilot/refactor-project-structure` remains stale/abandoned, no movement.

---

## Verified landed since 08-03 report

Commit `e8a4498` ("bump NuvioMobile: Trakt watched-state cluster + three player fixes") ported all four items from the 08-03 plan in one pass. Verified directly in the fork's working tree this run:

- **Item D (skip-outro clamp):** `MPVPlayerView.swift:1019-1020` now clamps the skip target against `state.durationSec - 0.5` before seeking. Landed.
- **Item E (AniSkip query bug):** `SkipIntroApi.kt:95` now builds repeated `types=op&types=ed&types=recap&types=mixed-op&types=mixed-ed` query params instead of a comma-joined value. Landed.
- **Item F (Kitsu/MAL skip-intro routing):** both `MPVPlayerView.swift:740` and `NativePlayerScreen.swift:133` now route `kitsu:`/`mal:`-prefixed video IDs to the anime skip-intro providers. Landed — this had been backlog/optional in the 08-03 report but got picked up anyway.
- **Item G (Trakt watched-state cluster):** `WatchedItemsStore.kt` and `TraktWatchedProjection.kt` both now exist under `shared/src/commonMain/.../features/watched/` and `.../watching/sync/` respectively. Landed.

Separately, Simkl tracking provider support (previously "Item C Phase 2, gated on product decision") was also implemented and shipped — outer commits `e8a4498`→`6b9ea32` on 2026-08-04, submodule tip `b20d7a33` ("feat(simkl): add the Apple TV Simkl settings surface (part 4 of 4)"). Confirmed the underlying upstream `simkl` branch work (e.g. `e4911b77`) is fully merged into `cmp-rewrite` — no divergence to reconcile.

---

## Confirmed no new upstream movement this run

- `cmp-rewrite` tip unchanged (`ae5c8f74`) since the 08-03 check — no new commits to triage.
- `copilot/refactor-project-structure` still stale/abandoned.
- No other active upstream branches with unmerged work (`simkl` branch fully merged, no longer distinct on remote).

## For Claude Code (this session)

Nothing actionable. No upstream changes pending port. Next scheduled check should just re-verify `cmp-rewrite` hasn't moved and re-scan for new commits — no follow-up work queued from this run.

## Next scheduled check

- Re-fetch `upstream/cmp-rewrite` and diff against `ae5c8f74`.
- If it has moved, triage new commits the same way as prior reports (check file relevance to tvOS's Swift/shared codebase, skip anything Android/Compose-only unless it touches `shared/commonMain`).

# Upstream port check — 2026-08-02 (scheduled)

## Headline: Items A/B/C-Phase1 from the 08-01 report all landed since yesterday. New upstream movement is small — one real bug worth a Swift-side port, one localization change that's N/A.

Fork state checked this run: outer repo HEAD `989efc1` (CFPrefs migration tracker docs, fork-only). Submodule `NuvioMobile` pinned `becb24b3` on `tvos-shared-extraction` (`tvos-v0.3.0-beta.9-4-gbecb24b3`).

`upstream/cmp-rewrite` (NuvioMedia/NuvioMobile) moved `3ba9cfd4` → `e203dc88` (5 commits, no version tag cut yet).

---

## Confirmed landed since 08-01 (no action needed — verified in this run)

- **Item A** — "mark as unwatched for whole series" fix. Verified: `WatchedRepository.kt:805` has `isFullyWatchedSeries()`, `WatchingActions.kt:35` calls it in the OR-check. Landed as fork commit `0c7f9e46`'s neighbor in the log (visible pre-`bf63a1a1`).
- **Item B** — realtime Supabase sync removal. Verified: `shared/src/commonMain/kotlin/com/nuvio/app/core/sync/` no longer contains `RealtimeSyncInvalidationService.kt`/`RealtimeSyncRetryPolicy.kt`/`RealtimeEndpointProbe.kt`, and `SyncManager.kt` has zero `realtime`/`Realtime` string matches. Landed as fork commit `b29500e3` ("refactor: remove the realtime Supabase sync stack (upstream db87075b)").
- **Item C, Phase 1** — provider-neutral tracking abstraction, Trakt-only. Verified: `shared/src/commonMain/kotlin/com/nuvio/app/features/tracking/` exists (`TrackingProvider.kt`, `TrackingReads.kt`, `TrackingWrites.kt`, `TrackingSources.kt`, `TrackingSettings.kt`, `TrackingAttribution.kt`, `TrackingLibraryMembership.kt`, `TrackingMedia.kt`, `TrackingScrobbleCoordinator.kt`), plus `core/tracking/TrackingProviderBootstrap.kt`, `features/trakt/TraktTrackingLibraryProvider.kt`, `features/trakt/TraktTrackingProgressProvider.kt`, and test coverage under `shared/src/commonTest/.../tracking/` and `.../trakt/TraktTracking*ProviderTest.kt`. Landed as fork commit `bf63a1a1` ("refactor: provider-neutral tracking abstraction, Phase 1 — Trakt-only (upstream Simkl merge, part 1 of 4)").

Good news: someone (Christian or a prior Claude Code session) already worked through the entire 08-01 punch list. **Item C is mid-flight** — Phase 1 done, Phases 2–4 (Simkl backend, combined registration, Settings UI) not started. `features/simkl/` still doesn't exist anywhere in the fork (`find shared/src -iname "*simkl*"` → empty).

No further action needed on A/B/C-Phase1 — just tracking that they're done, per the 08-01 doc's own instruction to stop re-reporting once landed.

---

## New this run — Item D: skip-outro seek isn't duration-clamped in tvOS's native Swift player (upstream fixed the equivalent Kotlin bug twice, most recently 2026-06-14)

Upstream commits `3236a7cc` (2026-06-13) and `31420a88` (2026-06-14), both by Aniket Tuli, PR #1339, merged into `cmp-rewrite` this run as `e203dc88`. Fixed file: `composeApp/src/commonMain/kotlin/com/nuvio/app/features/player/PlayerScreenRuntimeUi.kt` — but **that file is Compose Multiplatform UI for mobile (Android/iOS), not part of tvOS's build** (tvOS uses native SwiftUI + the `shared/` KMP module only, confirmed via `[[nuvio-tvos-port]]`). So this specific file is not aporting candidate. However, the underlying bug is architectural, not file-specific, and tvOS has its own independent Swift implementation of the exact same skip-outro seek that reproduces the same unclamped pattern upstream just fixed twice.

**What upstream fixed:** `onSkipInterval` originally did `playerController?.seekTo((interval.endTime * 1000).toLong())` with no bound. First fix (`3236a7cc`) clamped to `durationMs` after discovering a `Long` overflow when the last skip segment carries `Double.MAX_VALUE` as an end-time sentinel. Second fix (`31420a88`) tightened the clamp from `durationMs` to `durationMs - 1`, since seeking exactly to the duration boundary was still misbehaving (likely landing past the last frame / triggering an immediate EOF).

**tvOS's equivalent, unpatched:** `iosApp/NuvioTV/Screens/MPVPlayerView.swift`:
- Line 979-983, `updateSkipPrompt(position:)` — builds `SkipPrompt(label:, targetSec: $0.end)` from `skipSegments` (fetched via `SkipIntroRepository.shared.getSkipIntervals(...)`, shared Kotlin code, same source as upstream's `interval.endTime`).
- Line 1014-1016 — on remote down-arrow press: `seekAbsolute(prompt.targetSec)` with **no clamp against `state.durationSec`** before calling `seekAbsolute`.
- `seekAbsolute` (line 1095-1099) formats the raw `Double` seconds into an mpv `seek ... absolute` command string — no `Long` overflow risk here (this is libmpv via string command args, not a Kotlin `Long` cast), but an unbounded sentinel value (if `SkipIntroRepository` ever returns one, same as upstream's `Double.MAX_VALUE` case) would still send mpv a garbage seek target instead of a safe near-end-of-file seek.

**Fix (1 file, ~3 lines):** in `MPVPlayerView.swift`, clamp the skip target at the point of use — either where `SkipPrompt` is built (line 981) or right before `seekAbsolute` (line 1015). Mirroring upstream's final clamp value (`durationMs - 1` → `durationSec - epsilon`, e.g. `- 0.5` given `seekAbsolute` operates in seconds not ms):

```swift
} else if let prompt = state.skipPrompt {
    let duration = state.durationSec
    let target = duration > 0 ? min(prompt.targetSec, duration - 0.5) : prompt.targetSec
    seekAbsolute(target)
    state.skipPrompt = nil
    flashControls()
    handled = true
}
```

Low risk, isolated to one file, no dependency on Items A–C. Worth doing since the shared `SkipIntroRepository`/skip-interval data model is the same Kotlin source upstream found the sentinel-value bug in — if that sentinel can occur, it can reach tvOS's Swift code the same way. Verify by testing skip-outro on an episode where the outro segment runs to (or past) the actual video end.

---

## Confirmed N/A this run

- `e1811f0e`/`0b8c15c7` Greek (`values-el`) localization — tvOS uses its own `resourceString`/`StringKey` i18n system (`[[nuvio-tvos-port]]`), not upstream's Compose string resources. Same reasoning as the 08-01 Slovak N/A call.
- `e07798ec`/`e203dc88` merge-commit noise — no independent content beyond what's listed above.

## Other upstream branches — no change

`upstream/copilot/refactor-project-structure` still stale (no merge-base movement) — treat as abandoned unless it resurfaces.

## For Claude Code (this session)

1. Nothing to do for Items A/B/C-Phase1 — already shipped, verified above.
2. Apply **Item D** — trivial, isolated, one file. Test skip-outro near the true end of an episode after the change.
3. Item C Phase 2 (Simkl backend, 27 files) is still gated on Christian's product decision (does tvOS want anime-specific tracking via Simkl?) — no upstream movement on this since 08-01, nothing new to scope. When ready, `docs/upstream-port-plan-2026-08-01.md` has the full file inventory/architecture map for Phase 2-4.

## Next scheduled check

- Verify Item D landed (`grep "duration - 0.5\|durationSec - 0.5" iosApp/NuvioTV/Screens/MPVPlayerView.swift` or equivalent near the `seekAbsolute(prompt.targetSec)` call site).
- Re-check `cmp-rewrite` tip movement past `e203dc88`.
- Re-ask whether Item C Phase 2 (Simkl backend) has been scoped/started; if a product decision was made either way, stop carrying the "gated on product decision" line and reflect the actual status.

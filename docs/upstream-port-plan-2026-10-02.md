# Upstream port plan — 2026-10-02

Daily scheduled check of `NuvioMedia/NuvioMobile` (`cmp-rewrite`) against this fork's `NuvioMobile` submodule (`tvos-shared-extraction`).

Upstream moved: `d667f432` → `e2f8ac25` — 8 commits (5 real, 3 merges, zero i18n-only, zero version bump, zero store publish this window). All 5 real commits read in full via `git show`, not just commit titles.

Submodule pointer check: the outer repo's committed pointer, `origin/tvos-shared-extraction`'s fetched tip, and this sandbox's local submodule checkout all agree at `3f377cd8` (`tvos-v0.3.0-beta.18-rc5`, build 166) — no fork-sync drift.

**Headline: one real action item, and it's a product/UX call for Christian, not a mechanical port — tvOS's own next-episode autoplay file already made the opposite design choice on purpose.** Everything else this run is either composeApp-only with no live tvOS gap, or already independently converged.

## Decision needed before any build

### 1. [MEDIUM, not mechanical — needs Christian's call] Should dismissing the up-next card still allow autoplay once the episode truly ends?

Commit: `f0f980b3` "fix(player): auto-play next episode on end after dismissing prompt" (fixes upstream #2150)

Upstream's bug report: a user dismisses the early up-next card, then lets the episode play all the way to its real end — autoplay should still kick in at that point, but it didn't, because dismissing the card permanently set `nextEpisodeCardDismissed = true` for the rest of the episode. The fix adds a `LaunchedEffect(playbackSnapshot.isEnded)` that clears the dismissed flag the moment the player reports true end-of-file, provided auto-play-next-episode is enabled and the next episode has aired — so a dismissed card no longer blocks the "it actually ended" case.

This touches only `composeApp/.../player/PlayerScreenRuntimeEffects.kt` — no `shared/` extraction exists for that file, so there's nothing to "port" in the usual mechanical sense.

**But tvOS already built its own equivalent system, and chose the opposite behavior on purpose.** `iosApp/NuvioTV/Screens/NextEpisodeAutoPlay.swift`'s `dismissIfVisible()` calls `cancel()`, which sets a `cancelled` flag that is **sticky for the rest of that playback session** — the file's own comment block (above `dismissIfVisible()`) says this is deliberate, modeled on upstream's *older* issue `4026ec92` (#858: "persist next-episode-card dismissal"). In other words: today's upstream commit reverses the exact behavior tvOS intentionally copied from upstream months ago. Right now, dismissing the up-next card on tvOS means **no autoplay for the rest of that episode**, full stop — including if the user just lets it run to the very end.

This needs a decision, not a build:

- **Keep current behavior** (dismiss = no autoplay this episode, no exceptions) — tvOS stays as-is, nothing to do.
- **Adopt upstream's new behavior** (dismiss still blocks the early/threshold-triggered autoplay, but true end-of-file re-enables it) — small, well-scoped addition, not a blind copy:
  - Hook into wherever tvOS's player reports true end-of-file. The same file already has an `endOfFileSlack` constant (`Self.endOfFileSlack`, used in `onProgress`'s post-credits-hold check) that's the natural anchor for "the episode actually ended," since tvOS already treats "within `endOfFileSlack` of duration" as equivalent to upstream's `isEnded`.
  - When that true-end condition is observed AND `cancelled == true` (i.e. the user dismissed earlier) AND `settings.streamAutoPlayNextEpisodeEnabled` AND `nextVideo`'s `hasAired == true`: clear `cancelled` and call `beginSearch()` again instead of leaving the chip hidden.
  - Needs care: `cancel()` is also the path used for backward-seek and Menu/exit abandonment (see its doc comment), so the reset must only apply to the "episode genuinely ended" trigger, not restore autoplay after an exit-driven cancel mid-episode. A separate flag (e.g. `dismissedByUser` vs. a generic `cancelled`) is probably cleaner than reusing the existing flag for both meanings.

Flagging this now rather than guessing which way Christian wants it, since it's a user-facing behavior change, not a bug with one obviously-correct fix.

## Opportunistic backlog (not a bug, no live gap — just a nice-to-have)

### 2. [LOW] Preload next-episode sources earlier than the display threshold

Commit: `22c9ab20` "feat: preload next episode sources and fix auto-play timeout blocking cached results"

Two halves, both composeApp-only (`PlayerNextEpisodeAutoPlay.kt`, `PlayerSettingsRepository.kt`, `PlayerStreamsRepository.kt`, all under `composeApp/` — confirmed no `shared/` footprint via `grep`, `shared/.../player/PlayerSettingsRepository.kt` has no `preloadNextEpisodeSources` field):

- **"Fix auto-play timeout blocking cached results" — does not apply to tvOS.** Upstream's bug was that composeApp always waited the full configured timeout (`delay(timeoutMs)`) before ever checking whether a stream was already cached, even when preload had already filled the cache. tvOS's `NextEpisodeAutoPlay.swift` never had this shape: `handleStreams()` is a reactive subscriber on `PlayerStreamsRepository`'s flow and calls `attemptSelection()` the instant results arrive (via `FlowWatcherKt.watch`); the `timeoutTask` in the same file is only a fallback deadline for when nothing has arrived yet, never a blocking wait before checking existing results. No action needed.
- **"Preload earlier than the display threshold" is a genuine small gap.** Upstream now starts the next-episode stream search one full timeout-window early (`preloadNextEpisodeSources()`, gated on `positionMs + preloadLeadMs` crossing the display-threshold check) so the search is already warm by the time the up-next card would normally appear — avoiding a "Finding source…" flicker. tvOS's `beginSearch()` only fires at `onProgress`'s own display threshold (the same point upstream used to use), so the same brief flicker is possible on tvOS today, though there's no user report of it.
  - **Port shape, if ever picked up:** add a `preloadTriggered` bool + a lead-time check mirroring upstream's math to `NextEpisodeAutoPlay.swift`'s `onProgress`, calling the existing `beginSearch()`/stream-load path early; optionally expose a `PlayerSettingsUiState`-level toggle if tvOS wants parity with upstream's new `preloadNextEpisodeSources` setting (there's currently no tvOS Settings row for this, and none is strictly required — the preload could just always be on).
  - Low priority — purely a perceived-latency polish item, not a correctness bug.

## Not applicable this run

Confirmed by reading the full diff, not just the commit title:

- `6d252097` "Fix mising poster fallback in Catalog Screen" — adds a Coil `ImageRequest` memory-cache-key extra so a custom-poster-overlay image that fails to load falls back to the original `rawPosterUrl`; composeApp/Coil-specific plumbing, no `shared/` target. **tvOS already has this, independently built and arguably more complete:** `iosApp/NuvioTV/DesignSystem/CachedAsyncImage.swift` is a purpose-built primary→fallback loader with definitive-vs-transient failure detection (`isDefinitiveFailure()`), and `SagaCard.swift` already passes `fallback: sagaFallbackURL` sourced from the card's `rawPosterUrl` — its own comment reads "the original poster is preserved in `rawPosterUrl` for fallback on load error." Nothing to port.
- `a984b390` "fix(ios): declare supported localizations" — adds a 24-language `CFBundleLocalizations` array to `iosApp/iosApp/Info.plist`, which is the **mobile companion app's** Info.plist, not tvOS's. tvOS's own `iosApp/NuvioTV/Info.plist` has no such array either, but tvOS remains English-only with no in-app language switcher (re-confirmed this run: `shared/.../settings/AppLanguage.kt` still has zero Swift consumers), so there's no App Store compliance gap this is closing on tvOS today.
- `b3d7c5b6` "feat(settings): show restart prompt when layout direction changes" — composeApp-only `AppLanguage`/RTL feature: shows a "restart required" dialog when switching to or from Arabic/Hebrew/Urdu, since Compose's `LocalLayoutDirection` doesn't update live on iOS. No `shared/` footprint, and (as above) tvOS has no Settings UI that consumes `AppLanguage` at all — no surface for this to land on.
- 3 merge commits (`e2f8ac25`, `63af0499`, `ff1df243`) — no code of their own.

## Carried items

None open from prior runs. The 2026-10-01 batch's three action items were all built and merged into `tvos-shared-extraction` the same day (`4f26c0d4` → `e4b57595`, pushed); see that run's OUTCOME ADDENDUM in `docs/upstream-port-plan-2026-10-01.md`. The only thing still owed from that batch is the rc15/build 132 cut and its device pass (MDBList Library tab newest-first; Simkl More Like This on a title with an ambiguous id) — tracked in CLAUDE.md, not upstream-porting work, so not repeated here.

## Suggested execution order

Nothing here is ready to build standalone. Item 1 needs Christian's decision first — it's a one-file, well-scoped change either way once he picks a direction, so there's no reason to batch it with anything else. Item 2 is backlog-only; pick it up opportunistically next time `NextEpisodeAutoPlay.swift` is already open for item 1 or something else, rather than as its own session.

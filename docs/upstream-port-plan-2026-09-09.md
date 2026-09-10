# Upstream port check — 2026-09-09

Upstream (`NuvioMedia/NuvioMobile`, branch `cmp-rewrite`) moved: `a30bf519` → `83c409c4`, 6 commits, no merges. All read in full via `git show`.

## Submodule pointer check

No drift. Outer pointer, `origin/tvos-shared-extraction`'s fetched tip, and this sandbox's local submodule checkout all agree at `e3a51787` (tag `tvos-v0.3.0-beta.18-rc7-...`).

## One actionable item

### [MEDIUM] Disable Play button when no playback source is available

Upstream commit `972109f9` ("fix(playback): disable play when no source is available") adds a real UX guard that's missing on tvOS: right now the mobile app lets you tap Play on a title even when nothing can actually play it (no enabled addon covers the type/id, no enabled JS plugin scraper covers the type, no embedded stream, no matching download), and only discovers that after navigating into an empty Streams screen. Upstream now pre-computes availability and disables/greys the Play button up front, with a new `playback_unavailable` string in place of the label.

**Confirmed missing on tvOS, not just unported:** `grep -rn "canPlay\|hasCompatiblePlaybackSource\|PlaybackAvailability\|isPlayEnabled\|playDisabled\|canStream"` against `iosApp/NuvioTV/` returns nothing. `DetailView.swift`'s Play button (`actionLabel("Play", ...)` around line 1418) has no `.disabled()` gating at all today — tapping it always proceeds.

**What upstream built** (all in `composeApp/`, no `shared/` counterpart exists yet):
- New file `PlaybackAvailability.kt` (`composeApp/src/commonMain/kotlin/com/nuvio/app/features/streams/`): an `AddonManifest.supportsStream(type, videoId)` extension (pulled out of `StreamsRepository.kt`'s addon-matching logic, which upstream also refactored to call it — a pure refactor, no behavior change there), a `hasCompatiblePlaybackSource(addons, plugins, type, videoId)` free function (checks enabled addons' manifest resources + enabled JS plugin scrapers), and a `PlaybackAvailability` class with `canStream()` (adds embedded-stream lookup via `MetaDetailsRepository`) and `canPlay()` (adds a downloads lookup via `DownloadsRepository`).
- `MetaDetailsScreen.kt` wires `rememberPlaybackAvailability()` in, computes `isPrimaryPlayEnabled` for the primary Play button and gates the "manual play" long-press/overlay actions on `canStream(...)` for both the movie/series-primary case and the per-episode case.
- `DetailActionButtons.kt` adds a `playEnabled: Boolean = true` param that greys the button color/content-color and disables `combinedClickable` when false.

**Why this is portable:** every dependency `PlaybackAvailability.kt` needs already has a `shared/` extraction on tvOS — confirmed via `find shared -iname`: `AddonRepository.kt`, `MetaDetailsRepository.kt`, `DownloadsRepository.kt` all exist under `shared/src/commonMain/kotlin/com/nuvio/app/features/...`, and tvOS has its own `TvOsPluginRepository.kt` (`shared/src/tvosMain/.../plugins/`) for the JS-plugin half. This isn't a Compose-only feature riding on `@Composable`/`LazyListState` — the actual availability check is plain suspend/property logic, only the `remember`/`collectAsStateWithLifecycle` wrapper in `PlaybackAvailability.kt` is Compose-specific and has no tvOS equivalent needed (SwiftUI would observe the same repos' native `Flow`/`@Published` bridges directly).

**Suggested port shape** (for Claude Code / a future session, not built this run):
1. Port the pure-logic half into `shared/.../features/streams/`: a `supportsStream(type, videoId)` extension on tvOS's `AddonManifest`, and a `PlaybackAvailability`-equivalent class/function exposing `canStream(type, videoId)` and `canPlay(type, videoId, parentMetaId, seasonNumber?, episodeNumber?)`, built on tvOS's own `AddonRepository`, `TvOsPluginRepository`, `MetaDetailsRepository`, `DownloadsRepository` state (mirror upstream's enabled-only filtering).
2. In `DetailView.swift`, compute play-availability for the resolved video id (movie id or the selected/next episode id) and gate the Play button's `.disabled()` state on it, swap the label to a "Playback unavailable" string when disabled (add to the tvOS strings catalog), and apply the same gate to whatever tvOS's equivalent of "manual play" / long-press-to-pick-source affordance is (check `DetailView.swift` around the `SeriesPlayRoute`/`onPlayManually`-equivalent call sites — BUG-14's comment near line 1431 is the relevant spot).
3. Add a unit test mirroring upstream's new `PlaybackAvailabilityTest.kt` (92 lines) for the ported `shared/` logic.
4. Device-check: a title with all addons disabled/uninstalled and JS plugins off should show a disabled Play button rather than navigating into an empty Streams screen.

Not urgent (no crash, no data-loss — the failure mode today is just "tap Play, land on an empty Streams screen instead of seeing it grayed out up front"), but genuine parity and worth batching into the next general fix/feature sweep.

## Not applicable this run

- **`872a5937`** "fix(home): reduce hero height without continue watching" — touches `mobileHeroHeight()` in `HomeHeroSection.kt`, a phone-viewport-ratio calculation (`MOBILE_HERO_VIEWPORT_RATIO`, `viewportHeightDp`). No `shared/` extraction exists (`find shared -iname HomeHeroSection*` empty) and the function is explicitly mobile-viewport-scoped — tvOS's Home hero is a wholly bespoke native SwiftUI system (`HeroCommitGate`, `HeroArtResolver`, `PinnedRowGeometry`, etc., built across the last several beta.18 batches) with no equivalent "mobile below-section height hint" concept.
- **`28df1e7d`** "fix(home): restore hero position when switching profiles" — new `HomeScrollPosition.kt`, pure Compose-runtime (`LazyListState`, `rememberSaveable`, `snapshotFlow`) fix for stale scroll offset surviving a profile switch. No `shared/` extraction exists and the mechanism (Compose state retention across recomposition) has no tvOS analogue to port mechanically. Worth a manual spot-check next time anyone is in tvOS's Home code: does switching profiles ever leave the Home row list scrolled to a stale position instead of resetting to top? No user report of this on tvOS to date — logging as a LOW "look for it" item, not a task.
- **`cf6cf2d6`** "fix(auth): synchronize shared client initialization" — adds `SynchronizedObject`/`synchronized(clientLock)` guarding `SupabaseProvider`'s lazy client init and `reset()` against a concurrent-first-access race. **Already present on tvOS** — read `shared/src/commonMain/kotlin/com/nuvio/app/core/network/SupabaseProvider.kt` directly (not just grepped) and it already has `clientLock: SynchronizedObject` guarding both `client` and `reset()`, including an explanatory comment ("Guards the cache: concurrent first accesses ... must not each build a client"). This looks like independent convergence from the fork's own 2026-08-24 sync-reliability batch rather than a prior port of this exact commit. One minor divergence, not a bug: tvOS's `reset()` calls `rateLimitCoordinator.clear()` outside the lock (upstream's new version keeps it inside); functionally equivalent since `previous?.close()` is also outside the lock in both versions.
- **`04388ce2`** "bump version" — version/build-number bump only.
- **`83c409c4`** "fix(ci): increase iOS release timeout" — `.github/workflows/android-release.yml` only, no app code.

## Verification note

All six commits were read via full `git show` diffs (not commit-message titles), and applicability was checked by grepping/reading actual current `shared/` and `iosApp/NuvioTV/` file contents rather than trusting prior port-plan notes.

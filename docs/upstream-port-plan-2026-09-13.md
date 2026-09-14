# Upstream port check — 2026-09-13

Automated daily run (scheduled task `daily-upstream-check`). Upstream `NuvioMedia/NuvioMobile` `cmp-rewrite` moved **`74492b26` → `157a2375`**, 34 commits (23 real, 3 merges, 5 i18n, 1 version bump, 1 store publish), all read in full via `git show`.

**Two action items this run** — both small. One mechanical fix, one opportunistic feature-parity gap surfaced by a mobile commit. Everything else in the batch is composeApp/Compose UI with zero footprint in `shared/` — confirmed by `git diff --name-only 74492b26..157a2375 -- 'shared/*'` returning empty.

## Action items

### 1. [LOW, mechanical] Season-poster specials placeholder alignment — `60e6a1b5`

Upstream commit: `fix(details): handle null specials poster placeholders`.

`MetaDetailsParser.kt`'s `seasonPosters()` aligns an addon's `seasonPosters` array to season numbers. When an addon's poster array has one more entry than the show has real (positive) seasons, with the extra leading entry being `JsonNull` (a placeholder for "no specials poster"), the current logic falls through to positional numbering (`index + 1`) and every real season's poster shifts by one. The fix adds a branch: if `positiveSeasons.size == posters.size - 1` and the first poster is `JsonNull`, use `[0] + positiveSeasons` as the season list instead.

**Confirmed unported and confirmed live on tvOS.** `shared/src/commonMain/kotlin/com/nuvio/app/features/details/MetaDetailsParser.kt` is the same file (tvOS's shared extraction of the season-poster feature ported 2026-09-01/09-02, upstream `22096a1e` end-state) and still has the pre-fix `when` block verbatim at its `seasonPosters()` function (~line 270). `EpisodesSection.swift` and `DetailView.swift` consume `MetaDetails.seasonPosters` on tvOS, so this is a real (if narrow) season-poster misalignment for any title whose addon emits a null placeholder for specials.

**Port:** add the one `when` branch from upstream's diff to `shared/.../MetaDetailsParser.kt`'s `seasonPosters()`, mirroring the existing comment style there. Mechanical, three lines. Port upstream's new test case (`fix(details)` commit added inline test coverage under `composeApp/.../MetaDetailsParserTest` equivalent — check for a matching case to add to `shared/src/commonTest/kotlin/com/nuvio/app/features/details/MetaDetailsParserTest.kt`).

### 2. [LOW, feature-parity gap] Pause-overlay on/off setting — `ecb69a88`

Upstream commit: `feat(player): add pause overlay toggle` — adds a `pauseOverlayEnabled` key to `PlayerSettingsRepository`/`PlayerSettingsStorage` (mobile's `composeApp` copies) and a Settings switch (`PlaybackSettingsPage.kt`) that lets the user turn off the "paused" metadata overlay Compose already shows after 5s of pause.

**Not a strict port** — the touched files are all `composeApp/` (mobile's own parallel `PlayerSettingsRepository.kt`/`PlayerSettingsStorage.kt`, not `shared/`'s), and the overlay UI itself (`PlayerScreenRuntimeUi.kt`/`PlayerScreenRuntimeEffects.kt`) is Compose-only. But it surfaces a genuine tvOS gap: `MPVPlayerView.swift` already has its own "metadata card after a sustained pause" overlay, built independently for **explicit Android TV `PauseOverlay` parity** (comment at line ~1612/1825), and it has no way to turn it off — `shared/`'s `PlayerSettingsRepository.kt`/`PlayerSettingsStorage.kt` have no `pauseOverlayEnabled` key (grepped, confirmed absent), and no tvOS Settings row exists for it. NativePlayerScreen.swift (the AVPlayer engine) doesn't have the pause-overlay feature at all, so this is MPV-engine-only today.

**Suggested port (opportunistic, not urgent):** add `pauseOverlayEnabled` (default `true`) to `shared/.../PlayerSettingsRepository.kt` + `PlayerSettingsStorage.kt`/`PlayerSettingsStorage.apple.kt`, mirroring the existing `showLoadingOverlay` key pattern already there; add a tvOS Settings toggle; gate `MPVPlayerView.swift`'s pause-overlay block on it. Low priority — this is a nice-to-have off switch for a feature tvOS built on its own, not a bug.

## Not applicable this run

- `bb2d16cc` fix(catalog): update items after library removal — `shared/.../catalog/CatalogRepository.kt` has the exact same one-shot (non-observing) `fetchInternalLibrary()` pattern this fixes in composeApp, **but** `CatalogTarget.Library` (the "browse my Library as a catalog grid" path this bug lives in) has zero tvOS consumers — `grep -rn "CatalogTarget\." iosApp/NuvioTV/` shows only the generic `See All` catalog-grid wrapper, never instantiated with `.Library`. tvOS's own Library tab (`LibraryViewModel.swift`) talks to `LibraryRepository` directly and already reacts live to removals. No tvOS gap.
- `cf4674a8` fix(home): apply poster settings to continue watching cards — composeApp Compose UI only (`HomeContinueWatchingSection.kt` hardcoded dp sizes → the shared `PosterCardStyleUiState`). tvOS already consumes `PosterCardStyleRepository` directly in its own native Home/continue-watching row (`PosterStyle.swift`); this commit is mobile's Compose layer catching up to logic tvOS's Swift layer already had.
- `e75fa3b3` feat(player): match tv autoplay loading screen — a 27-file batch giving phone/tablet Compose UI the same full-screen "opening overlay" loading screen the Android TV (Google TV) Compose build uses. Despite touching files named `StreamAutoPlayLoadingPolicy.kt`/`StreamsRepository.kt`/`StreamModels.kt`, all are `composeApp`'s own parallel copies (UI-state fields like `isDirectAutoPlayFlow`/`showDirectAutoPlayOverlay` don't exist in `shared/`'s versions) — no `shared/` footprint, no tvOS relevance.
- `33c0fe78` fix(streams): position sources panel below ios toolbar — `isIos`-branch-only tablet layout padding fix in composeApp's iPad Streams panel. No tvOS equivalent (StreamPickerView is bespoke).
- `a80302a7` fix(player): disable playback gestures during initial loading — Compose touch-gesture code (tap/drag/hold-to-speed on a touchscreen surface). tvOS's player has no touch surface, remote-based controls only.
- `331f5839` fix(android): correct bottom navigation behavior in RTL — `androidMain` + Compose jelly-tabs, Android-only.
- Ten-commit Compose navigation/profile-picker redesign batch (`4d876b41` glow controls, `19aad9b2` compact profile picker redesign, `76d51fa9`/`cb94f29b`/`c35a82d9`/`356d0162` floating bar fixes, `abe18e03` settings selection indicators, `f815fc25` RTL poster zoom, `1dd6de9b` avatar grid spacing, `b04a1607` profile popup transitions, `90e192ff` custom theme sheet background) — all `composeApp/` Compose UI, zero `shared/` paths touched. tvOS's tab bar and profile picker are wholly bespoke native SwiftUI (per the standing note in CLAUDE.md); `90e192ff` is a continuation of the parked Supporter-perks-v1 custom-theme feature.
- Five i18n commits (Czech ×3, Vietnamese ×2), `edc557fe`/`af10c26e` docs/readme/license-attribution, version bump, store publish.

## Submodule pointer check

Outer pointer, `origin/tvos-shared-extraction`'s fetched tip, and this sandbox's local submodule checkout all agree at `243da21b` (build 129, tag `tvos-v0.3.0-beta.18-rc12`) — no drift. Local submodule is checked out directly on `tvos-shared-extraction` (not a WIP branch) as of this run.

## Carried open item, unchanged

**[MEDIUM] disable Play button when no playback source is available** (`972109f9`, first flagged 2026-09-09) — still confirmed unbuilt as of the last check (2026-09-12); full port shape in `docs/upstream-port-plan-2026-09-09.md`, ready for Claude Code to pick up.

## For Claude Code

Two small, independent patches, safe to batch together or do separately:

1. `shared/src/commonMain/kotlin/com/nuvio/app/features/details/MetaDetailsParser.kt` — add the specials-`JsonNull` branch to `seasonPosters()`'s `when` block (see upstream `60e6a1b5`), add a matching test case to `MetaDetailsParserTest.kt`.
2. (Opportunistic, lower priority) Add `pauseOverlayEnabled` to `shared/.../player/PlayerSettingsRepository.kt` + `PlayerSettingsStorage.kt`/`.apple.kt` mirroring `showLoadingOverlay`; wire a Settings toggle; gate the pause-overlay block in `MPVPlayerView.swift` on it.

Plus the still-open carried item from 2026-09-09 (Play button disable) if picking up a bigger batch.

# Phase 1 — Batch 5 scout: player model-split

Scouted 2026-06-29, after Batch 4d (debrid + cloud) verified green.

## Why player needs a split (recap)
~10 otherwise-movable player files (PlayerSettingsRepository, PlayerTrackSelection,
SubtitleRepository, PlayerScreenRuntime*Actions, PlayerSubtitleCueParser, …) are blocked because
the *types* they need live in three **Compose-coupled** files: `PlayerModels.kt`,
`SubtitleAudioModels.kt`, `PlayerLanguagePreferences.kt`. None of the three moves whole. But the
Compose coupling is shallow in two of them and structural in one.

## The three model files, by difficulty

### 1. `PlayerModels.kt` (226 LOC) — CLEAN SPLIT
- **Pure (movable):** PlayerRoute, PlayerLaunch, PlayerLaunchStore, PlayerResizeMode,
  AndroidPlaybackEngine, AndroidLibmpvVideoOutput, IosVideoOutputPreset, IosToneMappingMode,
  IosTargetPrimaries, IosTargetTransfer, IosHardwareDecoderMode, IosAudioOutputMode,
  PlayerPlaybackSnapshot.
- **Compose coupling = 3 `@Composable fun <Enum>.localizedLabel()/localizedDescription()`**
  extension helpers (use `stringResource`). They are UI-only.
- **Plan:** move the pure types to `:shared`; extract the 3 @Composable extensions into a new
  composeApp file `PlayerEnumLabels.kt` (same package, resolves against the moved enums). No
  i18n-decouple needed — labels are consumed only by Compose settings UI, not by repos.

### 2. `PlayerLanguagePreferences.kt` (648 LOC) — CLEAN SPLIT
- **Pure (movable):** LanguagePreferenceOption, AudioLanguageOption, SubtitleLanguageOption, and the
  bulk language-matching logic.
- **Compose coupling = 1 `@Composable fun languageLabelForCode()`** (+ its `languageLabelResForCode`
  helper, which returns a `StringResource`).
- **Plan:** move the pure part to `:shared`; leave `languageLabelForCode` + `languageLabelResForCode`
  in composeApp (new `PlayerLanguageLabels.kt`).

### 3. `SubtitleAudioModels.kt` (160 LOC) — NEEDS A REAL REFACTOR
- **Pure (movable now):** AudioTrack, SubtitleTrack, AddonSubtitle, SubtitleTab,
  AddonSubtitleStartupMode, SubtitleSyncCue.
- **Structural coupling:** `SubtitleStyleState` bakes `androidx.compose.ui.graphics.Color` into 3
  fields (`textColor`/`backgroundColor`/`outlineColor`), plus a top-level
  `SubtitleColorSwatches = listOf(Color…)`. And `SubtitleAudioUiState` (line 149) **embeds**
  `subtitleStyle: SubtitleStyleState`, so it inherits the coupling.
- **PlayerSettingsRepository has 15 refs to SubtitleStyleState** → it stays blocked until this is
  de-Color'd.
- **Plan (the surgery):** represent colour as a platform-neutral type in the shared model —
  recommended `value class SubtitleColor(val argb: Long)` (or a plain `Long` ARGB). Keep Compose
  `Color ⇄ SubtitleColor` conversion + `SubtitleColorSwatches` in composeApp at the UI boundary.
  This frees SubtitleStyleState → SubtitleAudioUiState → PlayerSettingsRepository.

## Recommended structure: split Batch 5 into 5a (clean) + 5b (refactor)

**Batch 5a — pure model extraction (low risk, high unblock):**
- Move PlayerModels pure types + PlayerLanguagePreferences pure types + the 6 pure subtitle/audio
  types to `:shared`.
- Extract the 4 @Composable label helpers (3 in PlayerModels, 1 in PlayerLanguagePreferences) into
  new composeApp `*Labels.kt` files.
- Unblocks the player files that need only pure types: PlayerTrackSelection,
  PlayerSubtitleCueParser, PlayerNextEpisodeAutoPlay, SubtitleRepository (verify per-file), and the
  runtime-action files that don't touch SubtitleStyleState.
- Standard widen-scan (data class/sealed/value class + ext funs) for staying-UI consumers.

**Batch 5b — SubtitleStyleState Color refactor (the gating surgery):**
- Introduce `SubtitleColor` (value class over Long ARGB) in `:shared`; rewrite SubtitleStyleState +
  SubtitleAudioUiState to use it; move both to `:shared`.
- Add Compose `Color ⇄ SubtitleColor` adapters + `SubtitleColorSwatches` in composeApp; fix the
  Compose call sites (SubtitleStylePanel etc.) to convert at the boundary.
- Unblocks PlayerSettingsRepository (15 refs) + PlayerScreenRuntimeTrackActions + remaining
  subtitle-coupled files. Also re-checks the 4d-deferred `DirectDebridStreamPreparer`
  (imports `PlayerSettingsUiState`, declared in PlayerSettingsRepository.kt) — it likely unblocks
  once PlayerSettingsRepository moves.

## Recommendation
Do **5a first** — it's the same low-risk leaves-first shape as prior batches and clears the bulk of
the player model types with only mechanical @Composable extraction. Then **5b** as a focused
refactor PR (the only non-mechanical work in player). Splitting keeps the Color refactor isolated so
a regression there can't mask a simple extraction bug.

## Verify (each sub-batch)
`:shared:compileKotlinTvosSimulatorArm64`, `:shared:compileKotlinIosSimulatorArm64`,
`:composeApp:compileKotlinIosSimulatorArm64`, `:shared:linkDebugFrameworkTvosSimulatorArm64`.

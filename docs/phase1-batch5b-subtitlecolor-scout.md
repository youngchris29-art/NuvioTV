# Phase 1 — Batch 5b scout: SubtitleStyleState colour refactor

Scouted 2026-06-29, after Batch 5a verified green (tvOS+iOS).

## Goal
Move `SubtitleStyleState` (+ `SubtitleAudioUiState`) to `:shared` by replacing its three
`androidx.compose.ui.graphics.Color` fields with a platform-neutral colour type. This unblocks
`PlayerSettingsRepository` and the subtitle track actions, and **fixes a latent Android break**.

## Latent Android break (found while scouting)
`PlayerSettingsStorage` moved to `:shared` in 5a, but its **Android actual**
(`PlayerSettingsStorage.android.kt`, now in `shared/androidMain`) references
`SubtitleStyleState.DEFAULT.<non-color fields>` for SharedPreferences defaults. `SubtitleStyleState`
is still in composeApp → `shared/androidMain` → composeApp is illegal. tvOS/iOS didn't catch it (the
apple actual reads colours as hex strings and uses its own defaults; only the Android actual touches
`SubtitleStyleState`). 5b moving `SubtitleStyleState` to `:shared` resolves it.

## Design: `value class SubtitleColor(val argb: Long)`
- New `shared/.../player/SubtitleColor.kt`: `value class SubtitleColor(val argb: Long)` (0xAARRGGBB),
  companion `White/Black/Transparent`; pure `SubtitleColor.toStorageHexString()` and
  `subtitleColorFromStorage(String?): SubtitleColor?` (ported from the existing Color versions —
  same `#AARRGGBB` format, so stored prefs round-trip unchanged); `SubtitleColorSwatches` and
  `SubtitleBackgroundColorSwatches` as `List<SubtitleColor>` (argb longs; background alphas
  pre-rounded to match Compose `copy(alpha=…)` → `0x8C/0xB8/0xAD…`).
- Move `SubtitleStyleState` (fields now `SubtitleColor`) + `SubtitleAudioUiState` to `:shared`.
- composeApp keeps only `localizedTrackDisplayName` (@Composable) in `SubtitleAudioModels.kt`.

## Compose boundary — convert, don't rewrite components
All Compose UI keeps working in `Color`; convert only at the `style.<colorField>` boundary. New
composeApp `PlayerSubtitleColorCompose.kt`:
- `fun SubtitleColor.toComposeColor(): Color = Color(argb.toInt())`
- `fun Color.toSubtitleColor(): SubtitleColor = SubtitleColor(toArgb().toLong() and 0xFFFFFFFFL)`

Call sites to edit (read `style.x` → `.toComposeColor()`, write `Color` → `.toSubtitleColor()`):
- `SubtitleStylePanel.kt` — ColorPickerRow stays `Color`-typed; convert `colors=`, `selectedColor=`,
  `onColorSelected`, and the alpha slider (`.alpha`, `.copy(alpha=)`).
- `settings/PlaybackSettingsPage.kt` — `subtitleColorLabel(Color)` calls + autoplay color pickers.
- `SubtitleModal.kt`, `PlayerScreenModalHosts.kt` — mostly pass-through (verify).
- `PlayerEngine.kt` (sig only), `PlayerEngine.ios.kt` (`.toMpvColorString()`),
  `PlayerEngine.android.kt` (`.toMpvColor()`, `.toArgb()`) — convert (android not compile-verified).

## Also in 5b: unblock `PlayerSettingsRepository`
Beyond `SubtitleStyleState`, it uses `AppFeaturePolicy.pluginsEnabled` (3 sites) → rewrite to
`FeaturePolicyProvider.policy.pluginsEnabled` (established seam). Its other deps
(`StreamAutoPlayMode/Source`, `NextEpisodeThresholdMode`) are already in `:shared`. Then move it.

## Deferred (not 5b)
`SubtitleRepository` calls composeApp `getLanguageLabelForCode` (one site) — needs the ~80 `lang_*`
strings decoupled (heavy) or a language-label provider seam. Out of scope; keep it in composeApp.

## Verify
The four: `:shared:compileKotlinTvosSimulatorArm64`, `:shared:compileKotlinIosSimulatorArm64`,
`:composeApp:compileKotlinIosSimulatorArm64`, `:shared:linkDebugFrameworkTvosSimulatorArm64`.
(Android still not locally verifiable, but 5b removes the known illegal reference.)

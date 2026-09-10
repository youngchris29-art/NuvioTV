# Upstream port plan — 2026-09-07

## Upstream movement

`upstream/cmp-rewrite` (`github.com/NuvioMedia/NuvioMobile`) **moved** since
2026-09-06: `68337ffa` → `526a5b97`. Fresh `git fetch upstream` in
`NuvioMobile/` reported `68337ffa..526a5b97 cmp-rewrite ->
upstream/cmp-rewrite`.

One commit, read in full with `git show`:

1. `526a5b97` — "feat: custom static colours" — extends the parked
   Supporter-perks-v1 custom-theme feature so a non-member can pick a
   single solid accent color (previously the three-stop gradient editor
   was gated entirely behind membership). Touches: `CustomThemeColors.kt`
   (new `isSolid`/`solid()`), `CustomThemePalette.kt` (solid vs. gradient
   brush), `ThemeAccess.kt` (`availableAppThemes()` no longer takes a
   `memberTier` param — `CUSTOM` is now always in the list; new
   `resolveCustomThemeColors()` collapses a saved gradient to its middle
   stop when the profile has no membership tier), `ThemeSettingsRepository.kt`
   (splits stored preference `customThemePreference` from the
   membership-resolved `customThemeColors` that's actually rendered),
   `AppearanceThemePicker.kt` + `CustomThemeEditor.kt` (gradient/solid mode
   toggle chip in the sheet), `ProfileSettingsSync.kt` (sync signature now
   watches the raw preference, not the resolved value), strings.xml, plus
   new/updated tests (`ThemeSettingsRepositoryTest.kt`,
   `CustomThemeColorsTest.kt`, `ThemeAccessTest.kt`).

No version-bump/store-publish commit in this window.

## Applicability to tvOS

**Zero action items — not applicable.** Every file touched is under
`composeApp/` (`androidHostTest`, `commonMain/composeResources`,
`commonMain/kotlin/com/nuvio/app/core/ui`, `.../core/sync`,
`.../features/membership`, `.../features/settings`, `commonTest`) —
confirmed via `git show --stat` before reading the full diff. `grep -rl
CustomThemeColors shared/` and `grep -rl ThemeSettingsRepository shared/`
both return nothing: this feature has never had a `shared/` extraction,
so there's no tvOS Swift consumer and no possible "composeApp-looking
path but shared/ has a copy" trap here. It's a continuation of the
**parked Supporter perks v1** feature (member theme gradients/accents) —
same disposition as every prior sighting of this feature line (most
recently `68337ffa` in the 2026-09-06 run, which reached
`PlayerControls.kt`/`ParentalGuideOverlay.kt`/profile screens). Stays
parked per the 2026-08-20 product decision — no action until Christian
re-raises it.

## Fork state check

- Outer repo's committed submodule pointer (`git ls-tree HEAD
  NuvioMobile`) is `9ddc4104` — this is the beta.18-rc3 build-119 cut
  noted in `CLAUDE.md` (tag `tvos-v0.3.0-beta.18-rc3`), confirmed an
  ancestor of `origin/tvos-shared-extraction`'s fetched tip.
- `origin/tvos-shared-extraction` (fetched fresh this run) is at
  `9b02bb16`, **4 commits ahead** of the outer-pinned `9ddc4104`. This
  matches `CLAUDE.md`'s note that rc4 (W4 reaches-first, build 120) is
  in progress in a separate session — the outer pointer hasn't been
  bumped yet for that in-flight work, not drift.
- This sandbox's own local submodule checkout was sitting at `9ffed8ee`
  (30 commits behind the fetched origin tip, 21 behind the outer-pinned
  commit) before this run's `git fetch` — consistent with the
  recurring stale-local-clone note in prior runs, not fork drift. The
  comparison above uses the fetched `origin/tvos-shared-extraction` ref
  directly, so it doesn't depend on the local checkout being current;
  no repo state was changed (fetch only, no checkout/merge attempted).

## Action items for Claude Code

**None new this run.**

Carried, unchanged from the 2026-09-06 run (not re-actioned today,
listed for continuity only):

- **[LOW, mechanical, unstarted]** Port `8b43fd89`'s two fixes
  (`HomeCatalogParser.kt` forEach→for/break loop-exit bug,
  `CollectionRepository.kt` double-JSON-parse) into
  `shared/src/commonMain/kotlin/com/nuvio/app/features/collection/
  CollectionRepository.kt` and `shared/.../home/HomeCatalogParser.kt`.
  Confirmed live on tvOS's Home hot path via `HomeView.swift`/
  `HomeViewModel.swift`/`CollectionsUI.swift`. Pure perf, no correctness
  bug, safe to batch with other small work.
- **[LOW, opportunistic]** `findPersistedAudioTrackIndex()` dub/original
  variant matching port into `PlayerTrackSelection.kt` — dead code on
  tvOS today, port next time that file is touched for anything else.
- **[LOW, investigate before deciding to build]** Check whether tvOS's
  mpv engine shows a visible audio-track switch shortly after playback
  start on multi-audio-track titles (mobile's proactive-`alang` fix,
  2026-09-04's `4f79bfe0`) — no user report to date.
- **[Device pass owed]** Upstream batch 8 (`58864ec1` auto-play
  source-loading-scope) — device pass still owed for the non-default
  auto-play-source-scope case specifically.
- **[Device pass owed]** Steven beta.18 batch (rc2/rc3 fixes incl.
  BUG-96) — device pass with Show Hero OFF still owed per `CLAUDE.md`'s
  "Current open action items".
- **[Unfiled upstream-report candidates, 4 total]** Simkl list-mutation
  precedence divergence, FNV size-prefixing hardening, `CatalogRepository`
  harder guard, TMDB `putIfAbsent`→`getOrPut` KMP-compat fix.
- **[PARKED/DEFERRED by product decision]** Supporter perks v1 (upstream
  keeps extending it — now solid-color custom themes for non-members
  too), subtitle minimum font size — no action until re-raised.
- **[LOW, spot-check only]** Player pause-description staleness — verify
  next time the tvOS player/pause-overlay UI gets touched.

## Verification method

- `git fetch upstream cmp-rewrite` in `NuvioMobile/`; compared fetched
  `upstream/cmp-rewrite` HEAD (`526a5b97`) against the last-recorded
  pointer (`68337ffa`) — one commit via `git log --oneline
  68337ffa..526a5b97`.
- `git show 526a5b97 --stat` then full `git show 526a5b97` to read every
  hunk rather than trusting the commit subject.
- `grep -rl CustomThemeColors "shared/"` and `grep -rl
  ThemeSettingsRepository "shared/"` (both empty) to confirm this
  feature line has no shared/tvOS extraction to check for drift against.
- `git fetch origin tvos-shared-extraction` in the submodule; `git
  ls-tree HEAD NuvioMobile` in the outer repo for the committed pointer;
  `git merge-base --is-ancestor` in both directions between the outer
  pointer (`9ddc4104`), the local checkout (`9ffed8ee`), and the fetched
  origin tip (`9b02bb16`) to establish ordering without assuming it.

## OUTCOME ADDENDUM — same-day session, 2026-09-07 (upstream batch 9)

Submodule branch `claude/upstream-batch9` off `tvos-shared-extraction` @ `9b02bb16` (rc5 build 121), built in the clone `~/Claude/Projects/NuvioMobile-beta18`, five commits, tip `c21190ea`, pushed. **MERGED 2026-09-07 (Christian's call): `tvos-shared-extraction` fast-forwarded `9b02bb16` → `c21190ea`, pushed.** Outer pointer bump is handled separately by the main session.

Closed three carried items from the 09-06 note in one session: the LOW/mechanical `8b43fd89` port, the LOW/opportunistic `4f79bfe0` shared-half port, and the LOW/investigate audio-switch item — which turned out to be a confirmed live bug, not a maybe.

**What the exploration corrected about this run's note.**
- `8b43fd89`: ported as described — `HomeCatalogParser`'s `forEach { return@forEach }` loop-exit bug fixed to `for`/`break`, `CollectionRepository.initialize()` moved off the double-parse to `decodeFromJsonElement` on the already-parsed tree, plus the same idiom applied to the fork's own `importFromJson()` (upstream doesn't have this function; the fork does). `validateJson` was deliberately left untouched — merging it in would trade the localized invalid-JSON error for a raw `SerializationException` leaking to the UI. `HomeCatalogParserTest` mirrored into `shared/commonTest`.
- `4f79bfe0`: the shared half (`findPersistedAudioTrackIndex`) ported byte-identical to upstream. But upstream's commit also *deletes* `findPreferredTrackIndex<T>`, and the fork's composeApp `PlayerScreenRuntimeTrackActions.kt` still calls it — deleting it here would break the mobile build. Retained with a `// Fork: retained (upstream deleted in 4f79bfe0)` marker. The Compose-runtime half of the same upstream commit (`PlayerScreenRuntimeAudioPreferences.kt`, the `PlayerEngine` interface change, Android/iOS-mobile engine implementations, mobile `MPVPlayerBridge.swift`, the 495-line `OriginalAudioPreferenceTest`) is DEFERRED to a future mobile-parity batch — Android cannot compile in this environment, so that half can't even be gated here. Upstream's `PlayerAudioRestoreTest` (6 cases) added to `shared/commonTest`; behavior note: a saved id+language now correctly misses (-1) against a track whose `language` is null, matching upstream's stricter semantics.
- The "investigate before building" item was wrong to file as merely a maybe: `MPVPlayerView.swift` issued `loadfile` in `viewDidAppear` before `PlayerSettingsRepository.ensureLoaded()` had returned, and `autoSelectPreferredTracks` returned early without latching while settings were still nil — so the audio-language preference either applied late (an audible switch on a subsequent track-list event) or never applied until the Info panel was opened. `contentOriginalLanguage` was `nil` on both player engines, so the Settings "Original" audio option was inert regardless of timing. Built the tvOS analogue of upstream's proactive `alang`: settings are now read synchronously in `setupMpv()`, `alang` is set as an mpv OPTION before `mpv_initialize` (confirmed accepted by this libmpv 0.41 build) and re-applied as a property + `aid` write-back + `aid=auto` immediately before `loadfile`. `autoSelectPreferredTracks`'s audio pass is now an idempotent fallback via new `PlayerAudioLanguagePlan.trackToForce` — it only forces a track when mpv's own pick misses every target language. `selectAudio` latches `didUserSelectAudio` so a manual pick isn't overridden by the fallback.

**Fork deviations:**
- New `Screens/Player/PlayerAudioLanguagePlan.swift` (`alangValue`, `trackToForce`, `originalLanguage(for:)`) shared by both player engines — upstream's fix is mobile/Compose-only and has no equivalent shared Swift type; this is a fork-original file, not a port.
- `originalLanguage(for:)` resolves via `PlaybackMeta.originalLanguage` first, then falls back to `MetaDetailsRepository.peek` + `resolveContentLanguage` — `PlaybackMeta.originalLanguage` is a new field, filled from `MetaDetails` on the Detail and episode-launch paths. `NativePlaybackCoordinator` (the non-mpv engine) uses the same helper for parity, even though upstream's `4f79bfe0` never touched a second player engine (mobile only ships mpv).
- New DEBUG-only trace `debug.mpvAlangTrace` + an `aid` property observer — a fork-original diagnostic aid, not in upstream.
- New `PlayerAudioLanguagePlanTests` (8 cases) — fork-original, no upstream equivalent to port since upstream's own test coverage for this logic lives in the deferred Compose-runtime half.

**Codex** (`codex exec -s read-only`, 2 rounds): r1 found one P2 — composeApp's `restorePersistedTrackPreferenceIfNeeded` was latching `preferredAudioSelectionApplied` even when the persisted restore returned -1 (a miss), which would have suppressed the subsequent preferred-language pass; fixed to latch only on a successful restore, matching upstream's semantics (commit `5127bb0e`). r2 came back clean.

**Gates:** `:shared:jvmTest` 753 (was 744), `:shared:tvosSimulatorArm64Test` 773 (was 764), `:composeApp:iosSimulatorArm64Test` 425 (unchanged — this batch didn't touch the deferred Compose-runtime half), NuvioTVTests 179 (was 171), Debug + Release tvOS simulator builds green. Sim harness on FA87 (synthesized eng/jpn/jpn-default 3-track MKV over loopback, `debug.mpvSmokeURL` + `debug.mpvAlangTrace`): with the preference set to Japanese, trace shows `targets=["ja"] applied=true` before load and `file-loaded alang=ja aid=3` (mpv picks the default-flagged Japanese track within the preferred language) with no later `aid` change; with the preference cleared, the device's `["en-us","en"]` languages become the targets and mpv starts on the English track instead of the container's own default. Not sim-verifiable: the explicit-pick latch and next-episode rollover — no track-panel input path exists in the headless sim harness.

**Device pass owed** (Apple TV 4K):
- Preferred audio set to a non-default language on a multi-audio-track title — first audible word should already be in that language, no switch at 1–3 s.
- Info panel shows the preferred track as selected on open.
- A manual track pick during playback holds through the rest of the episode (latch not overridden by the fallback pass).
- Next-episode autoplay starts already in the preferred language.
- "Original" audio option on a non-English title, entered via Detail, plays the original language (Home continue-watching may fall back if the meta cache is cold — worth separately noting during the pass, not a blocker).

**Carried:**
- **[CLOSED 2026-09-07 (evening)]** The Gradle-catalog / Kotlin-toolchain drift noted earlier today (upstream `2a75ad6f`) was ported after all — Christian reversed the exclusion decision. See the "Evening follow-up" subsection below; MERGED at `31d572b4`.
- **[DEFERRED 2026-09-07]** The Compose-runtime half of upstream `4f79bfe0` (`PlayerScreenRuntimeAudioPreferences.kt`, `PlayerEngine` interface change, Android/iOS-mobile engine implementations, mobile `MPVPlayerBridge.swift`, `OriginalAudioPreferenceTest`) — deferred to a future mobile-parity batch; Android cannot compile in this environment. Marker for later: the `// Fork: retained (upstream deleted in 4f79bfe0)` comment on `findPreferredTrackIndex<T>` in the shared player-track-selection file is the trip wire — once the Compose-runtime half is ported and that function's last composeApp call site is gone, delete the retained function and the marker together.
- **[Follow-up, spawned as a separate task, not in this batch]** The long-standing `[MPV] API error: option not found` at mpv setup is `vulkan-disable-interop`, an option mpv 0.41 dropped. A diagnostic added this session now names the rejected option when one is refused at setup; actually removing the stale option call is out of scope here.

### Evening follow-up — toolchain bump (`31d572b4`)

Christian reversed the morning's exclusion and asked to match upstream's Kotlin toolchain instead. Built as one commit on `claude/upstream-batch9`: `31d572b4` "build(deps): align the version catalog with upstream (Kotlin 2.4.10, serialization 1.10.0, Compose 1.12) (upstream 2a75ad6f)", rebased on top of `0e6464b6` (the separate parked-feats session's removal of the never-existed `vulkan-disable-interop` option, closing the follow-up noted just above). Merge into `tvos-shared-extraction` + push done by the main session right after — tip `31d572b4`.

**Versions (`gradle/libs.versions.toml`, now byte-identical to upstream `cmp-rewrite`, unchanged upstream since `2a75ad6f`):**

| dependency | before | after |
|---|---|---|
| kotlin | 2.3.0 | 2.4.10 |
| kotlinx-serialization | 1.8.1 | 1.10.0 |
| kotlinx-coroutines | (implicit) | 1.10.2 pin, + `kotlinx-coroutines-core` alias |
| composeMultiplatform | 1.11.1 | 1.12.0 |
| material3 | 1.11.0-alpha07 | 1.12.0-alpha03 |
| androidx-lifecycle | 2.11.0-beta01 | 2.11.0 |
| androidx-navigation3 | 1.1.1 | 1.2.0-alpha02 |
| androidx-savedstate | (new) | 1.4.0, + 2 aliases |
| compottie | 2.1.0 | 2.3.1 |

Also new: `compose-materialRipple`, `coil-network-cache-control`, `supabase-storage` aliases — added for upstream parity, unused by the fork.

No `build.gradle.kts`, `gradle.properties`, wrapper (9.4.1 both sides), or compiler-flag changes were needed. Upstream's `composeApp/build.gradle.kts` hunks from `2a75ad6f` were deliberately NOT taken — entangled with fork-incompatible restructuring, and nothing in the fork needed them to compile.

quickjs-kt `1.0.5-tvos` klibs in `~/.m2` (built by Kotlin 2.3.20, `abi_version=2.3.0`, `compiler_version=2.3.20`) are consumed by Kotlin 2.4.10 without a rebuild; `scaffolding/build-quickjs-tvos.sh` remains the rebuild path if that ever changes.

**Gates**, all green on the new toolchain: `:shared:compileKotlinTvosSimulatorArm64`, `:shared:jvmTest` 753, `:shared:tvosSimulatorArm64Test` 773, `:composeApp:iosSimulatorArm64Test` 425 (14 min, Compose 1.12 artifacts), NuvioTVTests 179, Debug + Release tvOS simulator builds. A Debug rebuild after the rebase and one Codex static-risk round are being run by the main session (CLEAN — two notes carried: (a) the new `kotlinx-coroutines-core` catalog alias is unused by the fork's build files, so 1.10.2 is not an enforced pin on the shared/tvOS path (resolution stays transitive); (b) Kotlin's klib backward-compatibility guarantee covers ordinary klibs but explicitly excludes cinterop klibs, and quickjs-kt ships both — the green tvOS test link is practical evidence, not a policy guarantee; watch for `IrLinkageError` / incompatible-ABI linker diagnostics the first time the JS plugin runtime is exercised on 2.4.10).

This is the first standalone Kotlin-version bump in the fork's history — Kotlin was set once, in the 2026-03-04 "kmp init" commit.

**Device pass owed:** the batch-9 list above, unchanged, plus: first cold launch on the Apple TV after the toolchain bump (sanity item).

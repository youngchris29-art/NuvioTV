# Upstream port plan — 2026-09-06

## Upstream movement

`upstream/cmp-rewrite` (`github.com/NuvioMedia/NuvioMobile`) **moved** since
2026-09-05: `9ee9da09` → `68337ffa`. Fresh `git fetch upstream` in
`NuvioMobile/` reported `9ee9da09..68337ffa cmp-rewrite ->
upstream/cmp-rewrite`.

17 commits (14 real + 3 merges), all read in full with `git show`:

1. `3c239664` — "fix(android): background downloads" — new
   `AndroidDownloadScheduler`/`AndroidDownloadStore`/`AndroidDownloadTransfer`
   + JobService/Worker, `androidApp/`/`composeApp/src/androidMain/` only.
2. `d7159342` — "fix(streams): refresh resume position" (#1866) —
   `composeApp/.../features/streams/StreamsScreen.kt` only, extracts a pure
   `resolveStreamResumeState()` out of inline derived-state logic.
3. `eb43a6d6` — merge commit, no diff of its own.
4. `6fb5d44f` — "perf(ui): defer loading and parallax state reads" — new
   `Shimmer.kt`, touches Home/Library/Detail Compose screens.
5. `59a13cbf` — "perf(loading): cache bundled animation resource reads" —
   `LoadingIndicator.kt` + new `ResourceLottieCompositionSpec.kt` (Compottie).
6. `e306a0a0` — "perf(ios): release temporary GIF decoding resources" —
   `composeApp/src/iosMain/.../CollectionCardRemoteImage.ios.kt` only.
7. `8b43fd89` — "perf(startup): avoid redundant collection and catalog
   processing" — `composeApp/src/commonMain/.../CollectionRepository.kt` +
   `HomeCatalogParser.kt`. **The one real finding this run — see below.**
8. `2a75ad6f` — "build(deps): align libraries with compose 1.12" —
   `composeApp/build.gradle.kts` + `gradle/libs.versions.toml` (Compose
   Multiplatform 1.11.1→1.12.0, material3, navigation3, lifecycle,
   kotlinx-serialization 1.8.1→1.10.0, new explicit kotlinx-coroutines
   1.10.2 pin, compottie, savedstate).
9. `5fa890ee` — "perf(home): improve lazy list item reuse" —
   `composeApp/.../features/home/HomeScreen.kt` (Compose `LazyRow` keys).
10. `3ee13480` — merge commit, no diff of its own.
11. `42667b9f` — "feat(ui): unify skeleton loading states" — new
    `Skeleton.kt`, rewrites `Shimmer.kt`/`HomeSkeletonLoading.kt`, touches
    Catalog/Person/TmdbEntityBrowse/Home/Library/Search Compose screens.
12. `3554904b` — "fix(player): resolve subtitle formats off the main
    thread" (NUVIO-MOBILE-KZ) — new `PlaybackSubtitleMime.android.kt`,
    `PlayerEngine.android.kt` only.
13. `40af63ad` — "fix(player): synchronize native subtitle rendering" —
    `PlayerEngine.android.kt` + `PlayerLibassCompat.kt`, Android libass/
    ExoPlayer only.
14. `6d4ad8bb` — "fix(player): preserve each foreground service start
    notification" — `PlayerNowPlayingService.android.kt` only.
15. `53c48cd2` — merge commit ("fix/sentry-batch-2"), no diff of its own.
16. `378f120e` — "fix(downloads): exclude foreground service from
    playstore builds" — `AppFeaturePolicy.{android,ios,desktop,common}.kt`
    across the composeApp Android/iOS *mobile* build-flavor matrix
    (`androidFull`/`androidPlaystore`/`iosFull`/`iosAppStore`), plus
    `DownloadsTransferWorker.kt`.
17. `68337ffa` — "feat(members): custom gradient" — extends the parked
    Supporter-perks-v1 theming (new `CustomThemeColors.kt`,
    `CustomThemePalette.kt`, `HsvColor.kt`) into `PlayerControls.kt`,
    `ParentalGuideOverlay.kt`, `ProfileEditScreen.kt`,
    `ProfileBackgroundPicker.kt`. All `composeApp/` mobile UI.

No version-bump/store-publish commit landed in this window (unusual vs.
most prior runs — checked `git log -p` for `versionCode`/`versionName`
edits in `androidApp/build.gradle.kts` / `composeApp/build.gradle.kts` in
range, found none).

## Applicability to tvOS

**One real finding this run, LOW risk / mechanical, confirmed live and
unported.** Everything else in the batch is confirmed not applicable.

### `8b43fd89` — redundant collection/catalog processing (ACTIONABLE)

This is the recurring "composeApp-looking path, but `shared/` has its own
copy" trap. The commit touches two files under
`composeApp/src/commonMain/kotlin/com/nuvio/app/features/`:

- **`collection/CollectionRepository.kt`**: `import()` used to call
  `json.parseToJsonElement(payload)` (to cache `rawCollectionsJson`) and
  then *separately* `json.decodeFromString<List<Collection>>(payload)` —
  parsing the same JSON text twice. Fixed to
  `json.decodeFromJsonElement<List<Collection>>(parsed)`, reusing the
  already-parsed tree.
- **`home/HomeCatalogParser.kt`**: the metas-parsing loop used
  `metas.forEach { ... if (maxItems != null && size >= maxItems)
  return@forEach ... }`. `return@forEach` inside a lambda only skips the
  *current* iteration — it does not break the loop — so once `maxItems`
  was reached the loop kept scanning every remaining element in the
  catalog doing no-op work. Rewritten as a plain `for` loop with `break`/
  `continue`, which actually stops early.

Confirmed via `find shared -iname` that `shared/src/commonMain/kotlin/
com/nuvio/app/features/home/HomeCatalogParser.kt` and
`shared/.../collection/CollectionRepository.kt` are the tvOS extractions
of these exact files, and both still have the **pre-fix** patterns
verbatim (`grep -n "forEach\|for (element"` on the shared copy shows the
old `metas.forEach { ... return@forEach ... }` structure at lines 33–42;
`grep -n "parseToJsonElement\|decodeFromString"` on the shared
`CollectionRepository.kt` shows the double-parse at lines 56/58, plus the
same pattern repeated at two more call sites — `importCollections()`
line 158-159 and another decode at line 174 — that upstream's commit
didn't touch but share the identical double-parse shape).

Confirmed live, not dead code: `grep -rln HomeCatalogParser` across the
repo shows `iosApp/NuvioTV/Screens/HomeView.swift` consuming it directly,
and `grep -rln CollectionRepository iosApp/NuvioTV/` shows
`HomeViewModel.swift`, `HomeView.swift`, and `CollectionsUI.swift` all
calling into it. Both are on tvOS's Home-tab hot path — parsing the
catalog JSON runs on every home load/refresh, and the redundant `forEach`
scan runs once per catalog payload regardless of `maxItems`.

Impact is pure performance (extra CPU/allocation on every home load,
worse the larger a catalog response is), not correctness — no visible
bug, no user report. Mechanical, low-risk port.

### Everything else — confirmed not applicable

- `3c239664`, `3554904b`, `40af63ad`, `6d4ad8bb`, `378f120e` — all Android
  ExoPlayer/downloads/foreground-service internals, confirmed via
  `git show --name-only` to touch only `androidApp/`,
  `composeApp/src/androidMain/`, `composeApp/src/android{Full,Playstore}/`,
  or Android-only test dirs. No `shared/` counterpart exists for any of
  these — tvOS's native mpv player and Top Shelf/background-refresh model
  are architecturally unrelated to Android's WorkManager/ExoPlayer/
  foreground-service stack. `378f120e`'s `AppFeaturePolicy.ios.kt` copies
  are the composeApp **mobile** iOS Compose Multiplatform target
  (`iosFull`/`iosAppStore` build flavors for the phone app), a separate
  codebase from tvOS's native `iosApp/NuvioTV/`.
- `d7159342` — the resume-position fix is a Compose-recomposition
  staleness bug: mobile's `StreamsScreen.kt` memoized resume
  position/fraction as inline derived values that could go stale across
  recompositions; the fix extracts a pure `resolveStreamResumeState()`
  function computed fresh each time. tvOS's equivalent resume-position
  logic in `iosApp/NuvioTV/Screens/StreamPickerView.swift`
  (`openExternally()`, line ~666) already calls
  `WatchProgressRepository.shared.progressForVideo(...)` fresh at the
  call site with no memoization layer — there's no Compose-style derived-
  state cache to go stale, so this class of bug doesn't have a tvOS
  analogue. Not a port candidate.
- `e306a0a0` — `CollectionCardRemoteImage.ios.kt` lives under
  `composeApp/src/iosMain/`, the Compose Multiplatform **mobile** iOS
  target's Coil GIF-decoding path. tvOS's native SwiftUI image loading is
  entirely separate code. Not applicable.
- `6fb5d44f`, `59a13cbf`, `5fa890ee`, `42667b9f` — all Compose UI
  perf/refactor work (new `Skeleton.kt`, reworked `Shimmer.kt`, `LazyRow`
  key tuning, Lottie/Compottie resource caching) confined to
  `composeApp/`'s Compose screens. tvOS has no Compose UI layer at all
  (native SwiftUI + `.focusable()`/`List`), so there is no file for any of
  this to land in. Not applicable, same as every prior "Compose-runtime-
  only" dismissal in this log.
- `2a75ad6f` — dependency-version alignment scoped to
  `composeApp/build.gradle.kts` (Compose Multiplatform 1.12, material3,
  navigation3, lifecycle, compottie, savedstate — all Compose-UI-specific
  artifacts). The `kotlinx-serialization`/`kotlinx-coroutines` version
  bumps in the shared `gradle/libs.versions.toml` catalog will already
  apply project-wide (including to `shared/`) the next time anyone
  touches this repo's Gradle sync, since it's one version catalog for the
  whole multi-module build — no separate Claude Code action needed to
  "port" a catalog bump.
- `68337ffa` — continues the **parked Supporter perks v1** feature
  (member theme gradients), now reaching `PlayerControls.kt`/
  `ParentalGuideOverlay.kt`/profile screens. Entirely `composeApp/`, no
  `shared/` touch. Stays parked per the 2026-08-20 product decision — no
  action until re-raised.

## Fork state check

- `NuvioMobile` submodule outer-repo pointer (`git ls-tree HEAD
  NuvioMobile` in the outer repo) is `25e07e08` (the beta.18-rc2 build-118
  bump). `git fetch origin` in the submodule confirms
  `origin/tvos-shared-extraction` is also at `25e07e08` exactly (fetch
  log: `9ffed8ee..25e07e08 tvos-shared-extraction ->
  origin/tvos-shared-extraction`) — **no drift**.
- Note for the record: this sandbox's own local submodule checkout was
  sitting at the pre-rc2 tip `9ffed8ee` (21 commits behind) before this
  check's `git fetch origin` — that's this read-only environment's clone
  being stale from before today's rc2 cut, not fork drift. An attempted
  `git merge --ff-only` to bring the local checkout current hit a
  `index.lock` error from this environment's mount (`operation not
  permitted` on unlink, consistent with the read-only/concurrent-access
  quirks of this mounted folder) and was abandoned rather than forced —
  no repo state was changed by this check. The comparison above used the
  fetched `origin/tvos-shared-extraction` ref directly, so the "no drift"
  conclusion doesn't depend on the local checkout being current.

## Action items for Claude Code

**One LOW-priority, mechanical item — safe to batch with other small
work, not urgent:**

- **[LOW, mechanical]** Port `8b43fd89`'s two fixes into
  `shared/src/commonMain/kotlin/com/nuvio/app/features/collection/
  CollectionRepository.kt` and `shared/.../home/HomeCatalogParser.kt`:
  (1) in `HomeCatalogParser.kt`, replace the `metas.forEach { ... if
  (maxItems != null && size >= maxItems) return@forEach ... }` loop with a
  `for` loop using `break`/`continue` so hitting `maxItems` actually stops
  the scan; (2) in `CollectionRepository.kt`'s `import()`, replace
  `json.decodeFromString<List<Collection>>(payload)` with
  `json.decodeFromJsonElement<List<Collection>>(parsed)` reusing the
  already-parsed `parsed` value (needs `import
  kotlinx.serialization.json.decodeFromJsonElement`). While in that file,
  consider (optional, upstream didn't do this either) whether the same
  double-parse shape at `importCollections()` (~line 158-159) and the
  third decode (~line 174) are worth tightening in the same pass, since
  they weren't part of upstream's fix but share the identical
  parse-then-decode-from-string pattern. Pure perf, no behavior change,
  no test risk beyond re-running `HomeCatalogParserTest`/whatever
  `CollectionRepository` coverage exists in `shared/commonTest`.

Carried, unchanged from prior runs (not re-actioned today, listed for
continuity only):

- **[LOW, opportunistic]** `findPersistedAudioTrackIndex()` dub/original
  variant matching port into `PlayerTrackSelection.kt` — dead code on
  tvOS today, port next time that file is touched for anything else.
- **[LOW, investigate before deciding to build]** Check whether tvOS's
  mpv engine shows a visible audio-track switch shortly after playback
  start on multi-audio-track titles (mobile's proactive-`alang` fix from
  2026-09-04's `4f79bfe0`) — no user report to date.
- **[Device pass owed]** Upstream batch 8 (`58864ec1` auto-play
  source-loading-scope) — device pass still owed for the non-default
  auto-play-source-scope case specifically.
- **[Unfiled upstream-report candidates, 4 total]** Simkl list-mutation
  precedence divergence, FNV size-prefixing hardening, `CatalogRepository`
  harder guard, TMDB `putIfAbsent`→`getOrPut` KMP-compat fix.
- **[PARKED/DEFERRED by product decision]** Supporter perks v1 (upstream
  keeps extending it — now into player accents/gradients too), subtitle
  minimum font size — no action until re-raised.
- **[LOW, spot-check only]** Player pause-description staleness — verify
  next time the tvOS player/pause-overlay UI gets touched.

## Verification method

- `git fetch upstream` in `NuvioMobile/`; compared fetched
  `upstream/cmp-rewrite` HEAD (`68337ffa`) against the last-recorded
  pointer (`9ee9da09`) — 17 commits via `git log --oneline
  9ee9da09..68337ffa` (14 non-merge + 3 merges), `git log --graph` to
  confirm merge topology.
- `git show --stat=200` then `git show --name-only` on every commit to
  get untruncated file paths before judging applicability by path alone.
- Full `git show <sha>` (complete diff, not just stat) on the two
  ambiguous candidates (`d7159342` resume-position, `8b43fd89`
  collection/catalog processing) to read actual logic changes rather than
  trusting commit subjects.
- `find shared -iname "CollectionRepository.kt" -o -iname
  "HomeCatalogParser.kt"` to confirm both have `shared/` extractions,
  then `grep -n "forEach\|for (element"` /
  `grep -n "parseToJsonElement\|decodeFromString\|decodeFromJsonElement"`
  on the shared copies to confirm the pre-fix patterns are still present
  verbatim.
- `grep -rln HomeCatalogParser` / `grep -rln CollectionRepository
  iosApp/NuvioTV/` to confirm tvOS's Swift actually calls into both files
  (live, not dead code) before classifying the finding as actionable.
- `grep -rln "resumePosition\|ResumeBanner\|isResumable\|lastPositionMs"
  iosApp/NuvioTV/` + read of `StreamPickerView.swift`'s `openExternally()`
  to confirm tvOS's resume-position calculation has no Compose-style
  memoization layer that could exhibit the same staleness bug as
  `d7159342`.
- `git log -p 9ee9da09..68337ffa -- androidApp/build.gradle.kts
  composeApp/build.gradle.kts | grep -i "versionCode\|versionName"` to
  confirm no version bump landed this window.
- `git ls-tree HEAD NuvioMobile` in the outer repo vs. `git fetch origin`
  + `origin/tvos-shared-extraction` in the submodule, to confirm the
  outer pointer matches the shared-extraction branch's actual remote tip
  (not the possibly-stale local checkout) — both at `25e07e08`, no drift.

# Upstream port plan — 2026-09-01

## Upstream movement

`upstream/cmp-rewrite` (`github.com/NuvioMedia/NuvioMobile`) **moved** again:
`6ceffbbe` → `312d499e` (fetched fresh today). Seven real commits plus three
merge commits:

- `a4b5e29b` fix(details): optimize large vertical episode lists (ThePunpun, 2026-08-30 22:43 -0400)
- `649eeb0b` Update strings.xml [bg] (Vik, 2026-08-30 23:51 +0300)
- `80169083` Update strings.xml [bg] (Vik, 2026-08-31 00:06 +0300)
- `e2af47a4` Remove community membership strings from strings.xml [bg] (Vik, 2026-08-31 00:16 +0300)
- `f212242a` Replace ARM with Simkl (skoruppa, 2026-08-31 00:54 +0200)
- `6de79141` Use SIMKL_API_BASE_URL (skoruppa, 2026-08-31 09:44 +0200)
- `624388d3` Fix Bulgarian strings for appearance and playback settings (Vik, 2026-08-31 14:39 +0300)
- `696d808b` / `62fe3754` / `312d499e` merge commits, no additional diff

All seven real commits read in full (`git show`, not just messages). **One
real action item for tvOS this run** — the ARM→Simkl ID-resolution swap for
anime skip-intro/outro detection. Everything else is either Bulgarian-locale
string edits or Compose-runtime-only UI perf work with no tvOS equivalent.

## Commit-by-commit

**`f212242a` + `6de79141` — replace the ARM anime-ID-resolution API with
Simkl (port as one end-state).** Upstream's skip-intro/outro feature needs to
map an anime's IMDB/MAL/Kitsu ID to season/episode numbers for the IntroDB
and Anime-Skip lookups. It previously did this via a third-party ARM API
(`arm.haglund.dev`); this batch replaces it with a new `SimklIdResolver`
object that resolves the same IDs (mal, anilist, kitsu, imdb, tvdb season)
through `api.simkl.com/search/id` + `api.simkl.com/{type}/{id}` and adds a new
`resolveEpisodeTvdb()` path (via `api.simkl.com/{type}/episodes/{id}`) so
anime episode numbers can be mapped onto TVDB season/episode numbers, not just
assumed 1:1. `f212242a` does the swap; `6de79141` (same day) is a one-line
follow-up replacing a hardcoded `"https://api.simkl.com"` literal with the
existing `SIMKL_API_BASE_URL` constant. **Applicable — port both as one
change.** Confirmed unported: `shared/src/commonMain/kotlin/com/nuvio/app/features/player/skip/SkipIntroApi.kt`
still has `ARM_BASE = "https://arm.haglund.dev/api/v2/"` and the six
`resolve*` functions built on it; `SkipIntroRepository.kt` still resolves IDs
via `resolveImdbEntries()`/`ArmEntry` lists; `SkipModels.kt` still has the
`ArmEntry` serializable model. No `SimklIdResolver.kt` exists anywhere in
`shared/`.

This is live-relevant for tvOS, not just a code-quality cleanup: tvOS's native
player (`MPVPlayerView.swift:801`, `NativePlayerScreen.swift:187`) calls
`SkipIntroRepository.getSkipIntervalsForContentId()`, which for anime titles
(`mal:`/`kitsu:`-prefixed content IDs) routes into `getSkipIntervalsForMal()`/
`getSkipIntervalsForKitsu()` — the exact functions this upstream batch
rewires off the ARM API. If ARM API availability degrades (plausible — this
is why upstream moved off it), tvOS's opening/ending-skip feature silently
stops working for anime specifically; non-anime content (the plain IMDB-based
`getSkipIntervals()` path) is unaffected either way, since it never touched
ARM.

The port is mechanical, not blocked on missing dependencies: `shared/` already
has `SIMKL_API_BASE_URL` (`features/simkl/SimklApiMetadata.kt`) and
`SimklConfig.CLIENT_ID`/`APP_NAME` (build-generated, already consumed
elsewhere in `shared/features/simkl/`), and `httpGetText()` already exists as
a commonMain `expect` function with apple/jvm/android actuals in
`features/addons/AddonPlatform.kt`. So the new `SimklIdResolver.kt` file can
be added to `shared/src/commonMain/kotlin/com/nuvio/app/features/player/skip/`
verbatim (adjusting only the internal→internal visibility, which matches),
and `SkipIntroApi.kt`/`SkipIntroRepository.kt`/`SkipModels.kt` updated the
same way upstream did (strip `ArmEntry` + `ARM_BASE` + the six ARM resolver
functions, thread `SimklIdResolver.resolveIds()`/`resolveEpisodeTvdb()`
through the MAL/Kitsu/IMDB skip-interval paths).

Note: upstream's diff also touches `composeApp/.../ExternalPlayerLaunchCoordinator.kt`,
`PlayerScreenRuntimeEffects.kt`, and `MainAppContent.kt` to thread a new
`contentId` parameter through to `resolveSkipSegmentsJson()` for the
external-player-launch path. **Not applicable to tvOS** — grepped
`iosApp/NuvioTV` for `ExternalPlayerLaunchCoordinator`/`prepareExternalPlayerLaunch`
and found no references; tvOS has no external-player-launch concept (it plays
everything in-app via `MPVPlayerView`), so only the `SkipIntroRepository`/
`SkipIntroApi`/`SkipModels`/`SimklIdResolver` half of this batch is relevant.

**`a4b5e29b` — optimize large vertical episode lists.** Adds
`MetaScreenSectionItem.tabGroupForRendering()` and
`MetaDetails.groupedEpisodesForDisplay()` plus ~270 lines of changes to
`DetailSeriesContent.kt` and `MetaDetailsScreen.kt` — this is Compose
`LazyColumn` virtualization/grouping work for large episode lists on the
mobile/desktop details screen, confirmed by the new
`MetaScreenSectionLayoutTest.kt`/`SeriesSeasonSupportTest.kt` unit tests
which test Compose section-layout ordering. **Not applicable** — entirely
`composeApp/`-only Compose-runtime code. Note: `composeApp/.../details/SeriesSeasonSupport.kt`
and `shared/.../details/SeriesSeasonSupport.kt` are two *different* files
that happen to share a name (the composeApp one is a thin Compose-local
helper; the shared one holds `metaVideoSeasonEpisodeComparator`/
`normalizeSeasonNumber`, which the new `groupedEpisodesForDisplay()` extension
actually calls into) — checked `shared/`'s copy directly and confirmed no
change is needed there; the new function upstream added lives only in
`composeApp/`. tvOS's own episode list (`EpisodesSection.swift`) is native
SwiftUI/`List`, not Compose, so this virtualization fix has no tvOS
equivalent bug to fix.

**`649eeb0b` / `80169083` / `e2af47a4` / `624388d3` — Bulgarian locale string
edits.** All four touch only `composeApp/src/commonMain/composeResources/values-bg/strings.xml`
— duplicate-key cleanup, removing now-orphaned `community_membership_*` keys
(strings for the parked **Supporter perks v1** feature; the underlying feature
code isn't touched, just Bulgarian translations for it going stale/removed),
and re-wording two settings strings. **Not applicable** — non-English
localization file, no code or logic change, and the fork's `values-bg` (if it
carries one at all) is a separate localization concern from this daily
mechanical-port check.

## Everything else: re-verified against current `shared/` state

Spot-checked (grep, not full re-audit): `AddonSubtitleStartupMode` search
still comes back clean (`grep -rl AddonSubtitleStartupMode shared/src` only
finds the three expected `legacyAddonSubtitleStartupModeKey` references), and
the 2026-08-28 batches (`upstream-batch6`, `subtitle-engine`) show no
regression.

## Action items for Claude Code

**One real port:**

1. **[MEDIUM, possible live degradation for anime skip-intro] ARM→Simkl
   ID-resolution swap.** Port `f212242a` + `6de79141` end-state into
   `shared/src/commonMain/kotlin/com/nuvio/app/features/player/skip/`: add
   `SimklIdResolver.kt` (new file, verbatim port — `shared/` already has
   `SIMKL_API_BASE_URL`, `SimklConfig`, and `httpGetText()` it depends on),
   remove `ArmEntry`/`ARM_BASE`/the six ARM resolver functions from
   `SkipIntroApi.kt` and `SkipModels.kt`, and rewire `SkipIntroRepository.kt`'s
   `getSkipIntervalsForMal()`/`getSkipIntervalsForKitsu()`/`getSkipIntervals()`
   to resolve IDs via `SimklIdResolver` the way upstream's diff shows,
   including the new TVDB season/episode mapping (`resolveEpisodeTvdb()`) so
   anime IntroDB lookups use the right season/episode instead of assuming a
   1:1 mapping. Skip the `ExternalPlayerLaunchCoordinator`/
   `PlayerScreenRuntimeEffects`/`MainAppContent` half of upstream's diff — no
   tvOS consumer. Worth prioritizing over LOW-priority carried items since
   this affects a live feature path (`MPVPlayerView.swift`,
   `NativePlayerScreen.swift` → `getSkipIntervalsForContentId()` →
   MAL/Kitsu-prefixed anime content IDs) that depends on a third-party API
   upstream is actively moving away from.

**No action, not applicable:**

- `a4b5e29b` episode-list virtualization — Compose-runtime-only, no tvOS
  equivalent (native SwiftUI `List`).
- Four Bulgarian-locale string commits — non-English localization file only.

**No new upstream-report candidates this run.** The four still-unfiled from
prior runs remain open: Simkl precedence, FNV size-prefixing,
`CatalogRepository` harder guard, TMDB `putIfAbsent`→`getOrPut`.

**Carried from 2026-08-31, still unstarted (no branch yet):** the addon
season-poster/certification-fallback batch (`22096a1e` + `0504af98`) and the
multiline TTML cue regex fix (`50ef6a84`) — see
`docs/upstream-port-plan-2026-08-31.md`. Also still owed: the two manual UX
checks (`085e8dc6` delayed-addon-loading-state flash, `4026ec92` next-episode
dismissal persistence).

## Verification method

- `git fetch upstream cmp-rewrite` in `NuvioMobile/`, diffed
  `6ceffbbe..upstream/cmp-rewrite` (`312d499e`).
- Read every new commit's full diff (`git show <sha>`), not commit messages
  alone; used `git show --stat --name-only` to classify composeApp/-vs-shared/
  paths before deciding applicability.
- For the ARM→Simkl commit, didn't stop at "composeApp/ paths only" — grepped
  `shared/` for `ArmEntry`/`ARM_BASE`/`SimklIdResolver` directly and confirmed
  shared/ has its own independent copy of `SkipIntroApi.kt`/
  `SkipIntroRepository.kt`/`SkipModels.kt` still on the old ARM API, then
  traced tvOS's actual Swift call sites (`MPVPlayerView.swift`,
  `NativePlayerScreen.swift`) to confirm the affected code path
  (`getSkipIntervalsForContentId` → MAL/Kitsu branches) is live, not dead
  code carried over from the mobile extraction.
- Verified the port has no missing dependencies before flagging it as
  "mechanical": confirmed `SIMKL_API_BASE_URL`, `SimklConfig`, and
  `httpGetText()` all already exist in `shared/`.
- For `a4b5e29b`, read the full diff (not just the stat) to confirm it's
  Compose `LazyColumn`/section-layout work, then checked that
  `shared/.../details/SeriesSeasonSupport.kt` is a distinct file from
  composeApp's same-named file and needs no change.
- Grepped current `shared/` state for the two 2026-08-28 device-pass-owed
  batches to confirm no regression (not a full re-audit).

## OUTCOME ADDENDUM — same-day evening session, 2026-09-01 (upstream batch 7)

Submodule branch `claude/upstream-batch7` off `tvos-shared-extraction` @ `3c39c677`. Every
still-unported upstream item as of this run's check — the 09-01 ARM→Simkl swap, the carried 08-31
details-parsing + TTML batch, and the two carried "manual UX check" items — closed in one session.
Scope decisions taken with Christian before coding: Supporter perks v1 + subtitle-min-font-size stay
**parked**; TTML = parity port + Kotlin/Native probe only; up-next dismissal = **Menu dismisses the
chip first**; `c4934bce` pause-description = closed not applicable.

### Item-by-item

**1. ARM→Simkl skip-intro ID resolution (`f212242a` + `6de79141`) — PORTED.** New
`shared/.../player/skip/SimklIdResolver.kt` (post-`6de79141` form, two unused imports dropped);
`SkipIntroApi.kt` now byte-identical to upstream (ARM_BASE + six resolvers gone); `ArmEntry` gone from
`SkipModels.kt`; `SkipIntroRepository.kt` rewired — IMDB path resolves MAL/AniList through Simkl,
MAL/Kitsu paths gain `imdbId`/`imdbSeason`/`imdbEpisode` hints and otherwise map the anime episode
onto TVDB season/episode via `resolveEpisodeTvdb()` for IntroDB (the actual behavioural fix: the old
code guessed season = ARM array index + 1). Fork-only `getSkipIntervalsForContentId` **kept with its
Swift-facing signature unchanged** — its `mal:`/`kitsu:` branches have no IMDB id to hint with, so
the defaults are exactly upstream's behaviour for that case, and adding params would rewrite the
exported ObjC selector both player screens call (KDoc says so). `mergeByPriority`'s KDoc retained
(upstream dropped it incidentally). `ExternalPlayerLaunchCoordinator.kt` — in `shared/` in this
fork, not composeApp — got the `contentId` threading + `App.kt:1419` passes `launch.parentMetaId`.
Upstream's `PlayerScreenRuntimeEffects.kt` hunk N/A (fork's copy already dropped the anime
branches); `MainAppContent.kt` N/A (→ `App.kt`). **No unit test** — neither object has an injection
seam (`httpGetText` is a top-level `expect`); verification is compile + sim/device smoke.

**2. Addon season posters (specials-aware) + certification fallback (`22096a1e` end-state +
`0504af98`) — PORTED, both halves.** `MetaDetails.seasonPosters: Map<Int, String>` (keyed by season
NUMBER, specials = 0) + `MetaDetailsParser.seasonPosters(videos)` / `ageRating()` fallback chain
(`ageRating` → `app_extras.certificationLocal` → `app_extras.certification`). New
`shared/src/commonTest/.../details/MetaDetailsParserTest.kt` (9 cases = upstream's final file, so
they run under the tvOS-native gate; composeApp's twin synced to upstream's final too). tvOS half:
`EpisodesSection.seasonPosters(_:meta:)` falls back to `meta.seasonPosters[KotlinInt(int:)]` when no
episode carries a `seasonPoster` — precedence per-episode (TMDB/per-video addon) → addon season map →
show poster → backdrop, same as mobile's `resolveSeasonPoster`; the posters-vs-chips gate picks up
addon-only art automatically. Age rating needs no Swift change (four render sites read
`MetaDetails.ageRating`). First Swift consumer of an Int-keyed Kotlin map in the fork.

**3. Multiline TTML cue regex (`50ef6a84`) — PORTED as parity; K/N probe NEGATIVE.** Added upstream's
`testParseMultilineTtmlCue` FIRST and ran it against the OLD `setOf(RegexOption.IGNORE_CASE,
RegexOption.DOT_MATCHES_ALL)` form on both `:shared:jvmTest` and `:shared:tvosSimulatorArm64Test`:
**passes on both**. So the named-option overload is NOT broken on Kotlin/Native and upstream's
commit message overstates the change — the 08-31 "possible live subtitle bug" worry is retired. The
`(?is)` form landed anyway for parity (comment in `PlayerSubtitleCueParser.kt` records the probe).
**Separate finding, logged as a fork-own follow-up, not built:** no tvOS code path reaches the shared
TTML parser at all — the native AVPlayer path's `SubtitleVTT.swift:262` requires `-->` timing lines
and silently drops TTML addon tracks (multi-line or not); mpv parses subtitles itself. The 08-31 doc's
"tvOS's player subtitle pipeline consumes directly" was wrong.

**4. Delayed addon content states (`085e8dc6`, #1819) — confirmed REAL on tvOS, FIXED both layers.**
Reading the Swift found: Search results showed a terminal "No results." during the manifest window;
Discover showed "Install and enable an add-on…" for an addon that WAS installed and never
self-corrected (`SearchViewModel.refreshDiscoverIfNeeded` deduped on `manifestUrl` only, identical
before/after a manifest lands); Home already avoided the false empty state but on total manifest
failure sat on "Setting up your catalogs…" forever with no error and no retry (and no focusable
control in any placeholder branch). Library/Catalog grid not affected. Kotlin: three predicates added
to `shared/.../addons/AddonModels.kt` as **public** `fun` (upstream `internal`; Swift needs them);
`SearchRepository.search()`/`refreshDiscover()` hand-ported (fork diverged: BUG-33 fan-out line,
`disabledCatalogKeys`, `lastDiscoverHideUnreleasedContent`) — pending → `isLoading`, manifest
failure → `RequestFailed` + message, the pending flag joins the search request key (required, or a
re-search after the last pending addon fails is deduped and sticks on loading). **Deliberate
deviation:** the pending flag is NOT added to the fork's Discover reuse guard — both pending
placeholders are already unreachable by it on the next call, and keying on it would force a
blank-and-refetch of a populated grid every time the last pending addon settles (comment in code).
Tests: new `AddonModelsTest.kt` (2) + `SearchAddonManifestStateTest.kt` (upstream's 2 repository
cases; the rest of upstream's `SearchRequestStateTest` tests `canReuseRequestState`, deleted in the
fork — not ported). Swift: `SearchViewModel` signature now `manifestUrl|hasManifest|isRefreshing`
per addon + **re-search on manifest change** (gap the brief missed — `search()` was only re-invoked
from the typing debounce); `SearchView` Discover shows the manifest error + focusable Retry
(`AddonRepository.refreshAll()`) instead of "try another genre" when `RequestFailed` arrives with no
catalog options; `HomeViewModel.addonManifestError` + `HomeView.placeholder` branch with Retry (the
focusable anchor, BUG-47 rule). New string keys "Retry", "Couldn't load your add-ons." (English
fallback until `populate-localizable-xcstrings.py` runs; same as "Refresh Add-ons").

**5. Up-next dismissal (`4026ec92`, #858) — state half was already correct, gesture half BUILT.**
`NextEpisodeEngine.cancelled` is sticky and guards `onProgress()`, so Compose's re-show bug never
existed on tvOS. But tvOS had NO dismiss gesture: mpv Menu exited the whole player through the chip,
Down played next, only backward-seek cancelled; the native path had no cancel of any kind. Added
`NextEpisodeEngine.dismissIfVisible() -> Bool` (any non-hidden phase; resets `consecutiveAutoPlays`),
`MPVPlaybackState.upNextDismiss`, mpv `pressesBegan` routes `.menu` to it first and swallows the
matching release (`PlayerPanelHostController` pattern); native `NativePlayerHostController.onMenuPress`
+ `pressesBegan/Ended` overrides (UIKit ancestor of AVPVC in the focused responder chain — guarded
against the panel and AVPVC popovers) wired from `AVPlayerContainer.onDismissUpNext`, plus a second
"Dismiss" contextual action for discoverability. Device caveat: with the transport bar visible AVPVC
consumes the first Menu to hide it, so the sequence is bar-hide → chip-dismiss → exit. No test seam;
**device/manual pass only**.

**6. `c4934bce` pause-description staleness — CLOSED, not applicable.** tvOS rebuilds the whole
player per `PlaybackContext` (`.id(ctx.id)`) and `NextEpisodeEngine.makeNextContext` already passes
`next.overview`; the mpv pause card shows no description at all. Retired from CLAUDE.md.

### Gates and verification

- `:shared:jvmTest` **593** / `:shared:tvosSimulatorArm64Test` **613**, all green (14 new tests: 9
  parser, 2 addon predicates, 2 search manifest-state, 1 multiline TTML). Derived baseline (totals minus the 14 new
  tests): 579 / 599 on `3c39c677`.
- NuvioTV **Debug** sim build green; NuvioTV **Release** sim build green on the second run — the
  first Release run caught a real compile error the Debug build had not seen (a post-Debug warning
  fix chained `.flatMap` onto an optional-chained `String`, which Swift resolved as
  `Sequence.flatMap` over characters). The Wave-10 lesson "Release compile is in the gate
  sequence" earned its keep again; fix folded into the tvOS season-poster commit via autosquash.
- composeApp `compileKotlinIosSimulatorArm64` + `iosSimulatorArm64Test`: **425** green (the 9 synced parser cases included).
- Sim smoke on FA87 (Debug build, real signed-in account): profile pick → Home renders hero +
  Continue Watching + Upcoming + 35 rows; Search tab → Discover renders Movies/Series toggles,
  Xperience catalog chips, genre chips, populated grid (the manifest-aware dedupe signature did
  NOT blank-and-refetch); Library → BEEF detail renders with the "TV-MA" age-rating chip intact
  through the parser change. Season-selector visual: osascript Down presses stall on the action
  row while the hero trailer plays (one bout sent the trailer full-screen) — so the season
  selector was verified with the XCUIRemote harness instead: `test33SeasonPosterRow` PASSED
  (asserts ≥2 `season_poster_` buttons in the accessibility tree; its screenshot attachment is
  trailer-obscured, the AX assertion is the evidence).
- Final re-gate after the Codex loop (chain r5 on the final tree): jvmTest **593** / tvosSimulatorArm64Test **613** green, NuvioTV Debug + Release simulator builds green (Release 6 min, silent through the K/N link — check `ps` for the konan LLVM child before assuming a hang).
- Codex (companion direct + unsandboxed, `--base 3c39c677 --scope branch`): settled at round 5 — 8 findings fixed across r1–r4, 1 documented decline at r5. Rounds and
  what they caught, all fixed (each fix autosquashed into its item commit):
  - r1 (3× P2): MAL/Kitsu early-return on a missing TVDB mapping dropped Anime-Skip too → only
    the IntroDB lookup is skipped now; anime cache key ignored the IMDB hint tuple → included;
    Search results UI dressed a failed fan-out up as "No results." → error text + Retry.
  - r2 (1× P2): `resolveIds("imdb", …)` always took `results[0]` while `getSkipIntervals` stopped
    using its season → season-aware resolution (pick the Simkl entry whose `season` matches).
  - r3 (2× P2): Discover feed could publish a terminal NoResults/RequestFailed while another
    manifest was still pending → pending flag carried through the feed's terminal publishes,
    settle re-triggers the refresh only when the grid is empty; Simkl URLs concatenated config
    values unencoded → `buildSimklApiUrl` (which also supplies the real app version).
  - r4 (2× P2): the Search results error state also caught legitimately empty searches (the
    shared `toSection()` throws on an empty page, so all-empty searches publish RequestFailed —
    pre-existing, masked by the old UI) → `searchError` now only for MANIFEST failures, catalog
    RequestFailed keeps "No results."; one failing Simkl candidate's details call sank the whole
    season scan → per-candidate `runCatching`, first success kept as fallback.
  - r5 (1× P2, **declined**): keep an ARM fallback for builds with no `SIMKL_CLIENT_ID`. Declined —
    leaving ARM is the point of upstream's change (the API is being abandoned), upstream ships the
    identical `isBlank()` guard, and this fork's builds carry the id in the generated
    `SimklConfig`; a keyless build losing anime skip resolution is the accepted trade-off.
  The r1/r2 skip findings are latent in upstream's own `f212242a` (early return, shared cache
  slot, unused `tvdbSeason`) — three new upstream-report candidates.

### Follow-ups logged (not built)
- **SubtitleVTT TTML gap** (fork-own): native player drops TTML addon tracks entirely.
- `pauseDescription`/`episodeTitle`/`episodeThumbnail` are persisted as `nil` by both tvOS progress
  recorders, so CW resume from tvOS-recorded progress opens the Info tab without synopsis/still.
- `HomeViewModel.onAddonsChanged` signature is `manifestUrl`-only, so a manifest whose CATALOGS change
  without its URL changing doesn't re-refresh Home (upstream's `buildAddonCatalogRefreshSignature`).
- A `-debug.upNextSmoke…` seed would make the Menu-dismiss path XCUIRemote-testable.
- `SimklIdResolver.commonParams()` hardcodes `app-version=1.0`; `buildSimklApiUrl` already exists.

### Upstream-report candidates
Three new, all in upstream's `f212242a` skip-intro Simkl swap (see Codex r1/r2 above): (a) the
MAL/Kitsu early return when Simkl has no TVDB mapping drops the Anime-Skip result; (b) hinted and
unhinted lookups of the same anime episode share one cache slot; (c) `resolveIds("imdb", …)` always
takes `results[0]` and the computed `tvdbSeason` is never used, so later seasons of a multi-season
IMDb anime query AniSkip/Anime-Skip with season 1's ids. No report from the K/N regex probe (it
passed). Now 7 unfiled in total (4 carried from prior runs).

### Device pass — PASSED 2026-09-02 (Living Room ATV, build `a87ab03f`/115, dev-signed via devicectl)
Christian walked all four items on hardware after the merge: (1) anime skip chip on a `kitsu:`/`mal:`
episode AND IntroDB segments on a plain `tt` series — PASS; (2) addon season posters with TMDB season
posters off (specials = season 0, no shift) and TMDB art winning when on, age-rating chip — PASS;
(3) cold start with Wi-Fi off: Home "Couldn't load your add-ons." + focusable Retry, Search error +
Retry (not "No results."), Discover error + Retry (not "Install and enable…"), Retry after Wi-Fi back
fills everything without retyping — PASS; (4) Menu dismisses the up-next chip on BOTH engines (mpv:
chip gone → post-play at EOF → second Menu exits; native: bar-hide → chip-dismiss → exit, "Dismiss"
contextual action present, panel Menu still closes only the panel) — PASS. Install went over the
existing dev-signed 115 with no IX error; signed-in state preserved. Device console (devicectl
`--console`) corroborates: `[NativePlayer] skip segments: 3` ×3 and `: 2` across the played episodes,
no `arm.haglund.dev` traffic, and a full `[UpNext] search begin → selected → resolved — playing next
episode` cycle (tt0388629 s1e2). Original checklist follows for the record.

### Device-pass checklist (as run)
- Anime skip chip: play a `kitsu:`/`mal:` episode with Skip Intro ON → chip appears; a plain `tt`
  series still gets IntroDB segments; no `arm.haglund.dev` traffic.
- Season posters on an AIOMetadata-style title with TMDB season posters OFF → addon art per season,
  specials card = season 0; with TMDB ON, TMDB art wins. Age-rating chip on a `certificationLocal`-only title.
- Cold start with Wi-Fi off: Home "Setting up your catalogs…" → "Couldn't load your add-ons." + Retry
  (focus lands on Retry); Search results "Searching…" → error + Retry; Discover "Loading…" → error +
  Retry; Wi-Fi back on + Retry → everything loads without retyping.
- Up-next chip: Menu once during "Finding source…"/countdown/"Still watching?"/no-stream → chip gone,
  playback continues, EOF → post-play cover, second Menu exits; Down still plays-now when not dismissed;
  Menu with no chip exits on the first press. Native path: bar-hide → chip-dismiss → exit; the new
  "Dismiss" contextual action; the swipe-down panel's Menu still closes only the panel.

### Branch / merge state
Submodule branch `claude/upstream-batch7`, 8 commits + xcstrings back-fill on `3c39c677`, pushed.
**Merged 2026-09-02 on Christian's call:** `tvos-shared-extraction` fast-forwarded `3c39c677 →
a87ab03f` and pushed; outer pointer bumped in the same commit as this addendum + the CLAUDE.md
update (scoped by pathspec — the outer index still carries a stalled sweep's staged 08-29/08-30 docs,
left untouched). Device pass still owed before the next beta cut.

# Upstream port plan — 2026-08-31

## Upstream movement

`upstream/cmp-rewrite` (`github.com/NuvioMedia/NuvioMobile`) **moved** again:
`e68cbb08` → `6ceffbbe` (fetched fresh today). Ten real commits plus three
merge commits:

- `fbca95ce` fix(player): reset subtitle selection on source change (guuilp, 2026-08-29 01:37 UTC)
- `085e8dc6` fix(ui): handle delayed addon content states — Fixes #1819 (tapframe, 2026-08-30 18:53 +0530)
- `50ef6a84` fix(player): support multiline ttml cues (tapframe, 2026-08-30 18:53 +0530)
- `e8eef59b` merge PR #1812 (fix/reset-subtitle-selection-on-source-change) — no additional content
- `f5726012` fix(details): parse addon season posters (tapframe, 2026-08-30 19:37 +0530)
- `0504af98` feat(details): parse addon certifications (tapframe, 2026-08-30 19:54 +0530)
- `42a9febf` bump version
- `994352f5` chore(store): publish 0.4.13
- `802db48d` fix(updater): apply theme gradient to download progress (tapframe, 2026-08-31 00:51 +0530)
- `22096a1e` fix(details): map addon specials season posters (tapframe, 2026-08-31 13:05 +0530)
- `4026ec92` fix(player): persist next episode dismissal — Fixes #858 (tapframe, 2026-08-31 13:21 +0530)
- `4ff20e4d` / `6ceffbbe` merge commits, no additional diff

All ten real commits read in full (`git show`, not just messages). **Two
action items for tvOS this run** — the first real upstream-batch since
2026-08-27's YouTube-client-swap batch. Everything else is composeApp/-only
UI with no tvOS equivalent, or a follow-on to the parked Supporter perks
feature.

## Commit-by-commit

**`f5726012` + `22096a1e` — addon season posters (port as one end-state).**
Upstream added `MetaDetails.seasonPosters: Map<Int, String>` parsed from
`app_extras.seasonPosters`, then immediately revised the index mapping
(`22096a1e`, same day) to handle specials: instead of always treating
`posters[index]` as season `index + 1`, it now derives the season numbers
from `MetaVideo.season` (falling back to positional numbering only if the
counts don't line up), so a season-0/specials entry doesn't shift every
other season's poster by one. **Applicable — port the `22096a1e` end-state
directly, skip `f5726012`'s intermediate `seasonPosters()` as superseded.**
Confirmed unported: `shared/src/commonMain/kotlin/com/nuvio/app/features/details/MetaDetailsModels.kt`
has no `seasonPosters` field, and `shared/.../details/MetaDetailsParser.kt`
has no `seasonPosters()` function. `shared/.../details/MetaDetailsModels.kt`
already has `MetaVideo.season: Int?`, so the specials-aware mapping is a
straight port with no missing dependency. `DetailSeriesContent.kt` (the
Compose consumer, touched by `f5726012`) is composeApp-only — tvOS's own
season-poster UI (wherever `EpisodesSection.swift` / season picker renders
poster art) needs its own consumption of the new `seasonPosters` field; check
whether tvOS's series detail view currently falls back to the show poster
for every season, which is presumably the visible bug this fixes.

**`0504af98` — addon certifications (age rating fallback chain).**
Upstream changes `ageRating = meta.string("ageRating")` to a new
`meta.ageRating()` helper that also falls back to
`app_extras.certificationLocal` then `app_extras.certification` when the
top-level field is blank/missing. **Applicable.** Confirmed unported:
`shared/.../details/MetaDetailsParser.kt` line 42 still has the old
`ageRating = meta.string("ageRating")` with no fallback, and
`shared/.../details/MetaDetailsModels.kt` has no `certificationLocal`
concept. Port the `ageRating()` private extension function verbatim — it's
pure parsing logic, no Compose dependency. This is a real content-coverage
gap: addons that only populate `app_extras.certificationLocal` (localized
certification, e.g. regional ratings boards) currently show no age rating on
tvOS at all.

**`50ef6a84` — multiline TTML cue regex.** Upstream changes the TTML `<p>`
tag regex from `Regex("""<p\b([^>]*)>(.*?)</p>""", setOf(RegexOption.IGNORE_CASE,
RegexOption.DOT_MATCHES_ALL))` to the equivalent-looking inline-flag form
`Regex("""(?is)<p\b([^>]*)>(.*?)</p>""")`. On the JVM these two forms behave
identically, but the commit message ("support multiline ttml cues") implies
the named-`RegexOption` form was not actually applying `DOT_MATCHES_ALL` on
at least one Kotlin Multiplatform target — plausibly Kotlin/Native (the
target `shared/` compiles to for tvOS), where regex option handling has had
past cross-platform quirks. **Applicable, and worth prioritizing**: this is
in `shared/src/commonMain/kotlin/com/nuvio/app/features/player/PlayerSubtitleCueParser.kt`,
which tvOS's player subtitle pipeline consumes directly, so if the bug is
real on Kotlin/Native, multi-line TTML subtitle cues (common in many addon
subtitle tracks) are silently dropped or truncated on tvOS right now. Confirmed
unported: line 216 still has the old `Regex(..., setOf(RegexOption.IGNORE_CASE,
RegexOption.DOT_MATCHES_ALL))` form. Recommend porting the one-line regex-syntax
change and, given the ambiguity above, adding a unit test with a genuine
multi-line `<p>` cue (mirroring upstream's `PlayerSubtitleUtilsTest.kt`
addition) run on the actual Apple/Native test target — not just JVM — to
confirm whether this was ever actually broken on tvOS, since a JVM-only test
run wouldn't reproduce a Kotlin/Native-specific regex-option bug either way.

**`fbca95ce` — reset subtitle selection on source change.** Fixes a stale
`selectedSubtitleIndex` surviving an episode/source transition in the Compose
runtime + Android ExoPlayer path
(`composeApp/.../player/PlayerEngine.android.kt`,
`composeApp/.../player/PlayerScreenRuntimeEffects.kt`). **Not directly
portable** — composeApp/-only, Android-engine-specific. Checked whether
tvOS's native player has the same class of bug: tvOS's
`NextEpisodeEngine.makeNextContext()` (`iosApp/NuvioTV/Screens/NextEpisodeAutoPlay.swift`)
builds a **fresh `PlaybackContext`** per next-episode transition and hands it
to `onPlayNext`, and subtitle track selection in `MPVPlayerView.swift` /
`NativePlaybackCoordinator.swift` is driven from `PlayerSettingsRepository`'s
`preferredSubtitleLanguage`/`preferredSubtitleTargets` each time, not a
carried-over raw track index — no variable resembling Compose's
`selectedSubtitleIndex` was found surviving across a source change in the
Swift code. tvOS's architecture (new context + fresh player state per
episode, preference-driven re-selection) looks structurally immune to this
specific bug, but this is a spot-check, not an exhaustive trace of every
episode-transition code path — worth re-confirming next time the subtitle
selection code is touched.

**`085e8dc6` — delayed addon content states (Fixes #1819).** Adds
loading/error-state handling (`hasPendingEnabledManifests()`,
`isWaitingForFirstEnabledManifest()`, `firstEnabledManifestError()`) to
`composeApp/.../features/addons/AddonModels.kt`, consumed by
`HomeScreen.kt`/`SearchScreen.kt`/`LibraryScreen.kt`/`CatalogScreen.kt` (all
composeApp/ Compose UI) to show a proper "still loading" state instead of a
premature empty-catalog view while an enabled addon's manifest is still
refreshing. Note: `shared/.../features/addons/AddonModels.kt` **also
exists** in this fork (extracted, same filename) but does **not** have these
three new helper functions — however the actual state-driving logic upstream
added lives entirely in the Compose screen files with no tvOS equivalent
structure (tvOS's Home/Search/Library are native SwiftUI, not Compose). **Not
a mechanical port.** Flagging as a UX bug worth checking manually: does
tvOS's Home/Search/Library show a premature "no results" flash while an
addon manifest is still (re)loading? If so, `HomeViewModel.swift` /
`LibraryViewModel.swift` / `SearchViewModel.swift` would need their own
Swift-side loading-state guard, following the same shape as upstream's three
helper predicates. LOW priority, needs product/UX judgment before treating as
a bug.

**`802db48d` — theme gradient in download-progress banner.** Applies
membership-tier `accentBrush()` theming to `AppUpdaterBanner.kt`'s progress
bar. Same **Supporter perks v1** family as `b86932b9` (2026-08-29, already
parked). Entirely `composeApp/`, nothing in `shared/`. No action — stays
parked per the 2026-08-20 product decision; noting only that upstream
continues extending member theming into more UI surfaces (profile/settings →
player accents → now the updater banner).

**`4026ec92` — persist next episode dismissal (Fixes #858).** Adds a
`nextEpisodeCardDismissed` boolean so that once the Compose up-next card is
explicitly dismissed, it latches and won't re-show later in the same
playback session (previously, re-evaluating the `LaunchedEffect` on
duration/threshold/isEnded changes could flip `showNextEpisodeCard` back to
`true` after a dismiss). **Not directly portable** — composeApp/-only
(`PlayerScreenRuntimeEffects.kt`, `PlayerScreenRuntimeState.kt`,
`NextEpisodeCard.kt`). Checked tvOS's `NextEpisodeEngine`
(`NextEpisodeAutoPlay.swift`): it's phase-based (`.hidden` /`.searching` /
`.counting` / `.stillWatching` / `.noStream`) with a `cancelled` flag that
guards `onProgress()` from re-triggering the search once set — structurally
this looks like it wouldn't have the exact re-show bug Compose had. However,
`cancelled`/`cancel()` is currently only wired to one call site
(`upNextCancel`, fired on backward seek in `MPVPlayerView.swift:1160`) — I
did not find an explicit "dismiss the up-next card without seeking back and
without playing" action in the grepped call sites, so it's unclear whether
tvOS's remote/UI even exposes a plain dismiss gesture for this card the way
Compose's `onDismissNextEpisode` does. **Needs a UX check, not a code port**:
confirm what remote input (if any) dismisses the up-next card on tvOS today,
and whether that path could re-show the card — if tvOS has no dismiss
gesture at all, this bug class doesn't apply; if it does, verify the
existing `cancelled` guard actually covers it before assuming parity.

**`994352f5` / `42a9febf` — version bump + store publish (0.4.13).** No
content. No action.

## Everything else: re-verified against current `shared/` state

No regressions found on spot-check (grep, not full re-audit):

- `claude/upstream-batch6` — `InAppYouTubeExtractor.kt` (now at
  `shared/.../features/trailer/`) still present with the visionos client
  swap; `TmdbMetadataService.kt` still has `aggregate_credits` at both call
  sites (lines 980, 1149).
- `claude/subtitle-engine` — `grep -rl AddonSubtitleStartupMode shared/src`
  finds only the three expected `legacyAddonSubtitleStartupModeKey` false
  positives (apple/jvm/android `PlayerSettingsStorage`), exactly as
  documented in CLAUDE.md — no regression.

## Action items for Claude Code

**Two real ports, one batch:**

1. **[MEDIUM] Addon metadata parsing gap — season posters (specials-aware) +
   certification fallback chain.** Port `22096a1e` end-state (season posters,
   with specials handled via `MetaVideo.season`, not `f5726012`'s simpler
   intermediate) plus `0504af98` (ageRating → certificationLocal →
   certification fallback) into `shared/.../details/MetaDetailsModels.kt` +
   `MetaDetailsParser.kt`, with the two new `MetaDetailsParserTest.kt` test
   cases upstream added. Then check tvOS's series detail/season-picker UI
   (`EpisodesSection.swift` or wherever season posters render) actually
   consumes `MetaDetails.seasonPosters` — if it currently always falls back
   to the show poster per season, that's a second, UI-side half of this port.
2. **[MEDIUM, possible live subtitle-rendering bug] Multiline TTML cue
   regex.** Port the `(?is)` inline-flag regex change into
   `shared/.../player/PlayerSubtitleCueParser.kt`, and add a Kotlin/Native
   (not just JVM) test run with a genuine multi-line `<p>` TTML cue to
   confirm whether tvOS was actually silently mis-parsing these before
   claiming the fix mattered here — the commit message strongly implies a
   real cross-platform regex-option bug, not just a style refactor.

**Needs manual UX verification, not a mechanical port (do these before
writing any code):**

- Confirm whether tvOS's Home/Search/Library screens show a premature
  empty/no-results flash while an addon manifest is still loading
  (`085e8dc6`'s bug, #1819) — if reproducible, port the three loading-state
  helper predicates' *logic* (not the Kotlin) into the relevant Swift
  ViewModels.
- Confirm what remote gesture (if any) dismisses the tvOS up-next card, and
  whether it can re-show after dismissal (`4026ec92`'s bug, #858) — the
  `cancelled` flag in `NextEpisodeEngine` looks structurally safe but the
  call-site audit wasn't exhaustive.

**No action, stays parked/deferred (unchanged):**

- Supporter perks v1 (`802db48d` extends member theming to the updater
  banner — same parked feature).
- Player pause-description staleness — spot-check only, next player UI pass.
- Subtitle minimum font size — deferred, tvOS to pick its own range.

**No new upstream-report candidates this run** (all four from 2026-08-30
remain unfiled: Simkl precedence, FNV size-prefixing, CatalogRepository
harder guard, TMDB `putIfAbsent`→`getOrPut`).

## Verification method

- `git fetch upstream cmp-rewrite` in `NuvioMobile/`, diffed
  `e68cbb08..upstream/cmp-rewrite` (`6ceffbbe`).
- Read every new commit's full diff (`git show <sha>`), not commit messages
  alone, including `git show --stat --name-only` to classify
  composeApp/-vs-shared/ paths before deciding applicability.
- For every composeApp/-only commit, checked whether the fork's `shared/`
  extraction has an identically-named file (`find . -iname <name>`) before
  concluding "not applicable" — this caught that `MetaDetailsParser.kt` and
  `PlayerSubtitleCueParser.kt` *are* extracted into `shared/` even though
  upstream itself keeps them in `composeApp/`, which is why those four
  commits are portable while the player-runtime and UI-state ones are not.
- For the two composeApp-only player bugs (`fbca95ce`, `4026ec92`), read the
  actual tvOS Swift implementation (`NextEpisodeAutoPlay.swift`,
  `MPVPlayerView.swift`, `NativePlaybackCoordinator.swift`) rather than
  assuming "different UI framework" meant "not applicable" — found tvOS's
  architecture is structurally different enough that the exact bug likely
  doesn't reproduce, but flagged the UX-gesture ambiguity instead of
  asserting a clean bill of health.
- Grepped current `shared/` state for the two 2026-08-28 device-pass-owed
  batches to confirm no regression (not a full re-audit).

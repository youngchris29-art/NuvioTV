# Upstream port plan — 2026-09-04

## Upstream movement

`upstream/cmp-rewrite` (`github.com/NuvioMedia/NuvioMobile`) **moved** since
2026-09-03: `9b09045f` → `d4891ffa`. Fresh `git fetch upstream cmp-rewrite` in
`NuvioMobile/` reported `9b09045f..d4891ffa cmp-rewrite -> upstream/cmp-rewrite`.

5 real commits (via 4 merge PRs, all read in full with `git show`):

1. `a48cc79e` — "use Android User-Agent so IPTV DASH streams do not 403"
   (`composeApp/src/androidMain/.../PlayerPlaybackNetworking.kt`). Swaps the
   default `User-Agent` header ExoPlayer sends for stream requests from a
   desktop Chrome/Windows string to a mobile Chrome/Android string, because
   some IPTV DASH origins 403 the desktop UA.
2. `1f2b8e1d` — "select subtitle rows on tap during fling"
   (`composeApp/.../player/ClickableIncludingFlingStop.kt` (new) +
   `SubtitleModal.kt`). `LazyColumn` eats the first pointer-down of a tap that
   lands mid-fling to stop the fling, so Compose's `clickable` never sees a
   click — new helper modifier recovers that consumed tap so subtitle/audio
   rows in the modal select on the first tap instead of needing a second one.
3. `136d467d` — "keep subtitle picker stable for duplicate tracks"
   (`SubtitleSelectionModel.kt`, `PlayerScreenRuntimeTrackActions.kt`,
   `PlayerScreenRuntimeUi.kt`, `SubtitleModal.kt`). Addon subtitles with the
   same display name were losing their picker selection because the option
   `id` didn't always disambiguate; adds `selectionKey`/`matchesSelection`/
   `findSelectedAddon` (URL-first, falls back to `addonName:id`) plus a
   structure-key so the list only rebuilds when tracks actually change, not
   on every selection change.
4. `f6d4ddfa` — Greek (el) string translations for the delayed-addon-content-
   state strings (the upstream `085e8dc6` feature tvOS already ported in
   upstream-batch7, 2026-09-02).
5. `bf37caa4` — Spanish (es) string resource refresh, large diff (372
   insertions), pure localization file.

## Applicability to tvOS — none of the 5 are actionable

All 5 are confirmed **not applicable**, checked against `shared/` (what tvOS
consumes) rather than trusting file paths alone:

- **`a48cc79e` (User-Agent/DASH 403 fix):** file lives under
  `composeApp/src/androidMain/` — Android's ExoPlayer-specific networking
  object, no `shared/` counterpart, nothing for tvOS's native player
  (mpv / `NativePlayerScreen`) to consume. tvOS's own stream-header handling
  (`proxyHeaders` threading, shipped in the 2026-08-20 SDH batch) is a
  separate code path. Noted for awareness only: if IPTV DASH streams start
  403ing on tvOS specifically, this is the shape of fix to reach for (bump
  the default UA to something mobile/TV-like), but there's no evidence of
  that symptom on tvOS today, so no proactive change is warranted.
- **`1f2b8e1d` (fling-tap fix) and `136d467d` (duplicate-track selection
  fix):** both touch Compose-only files (`SubtitleModal.kt`,
  `SubtitleSelectionModel.kt`, `PlayerScreenRuntimeTrackActions.kt`,
  `ClickableIncludingFlingStop.kt`), all under
  `composeApp/src/commonMain/.../player/` — confirmed via
  `grep -rl "selectionKey\|SubtitleSelectionOption\|ClickableIncludingFlingStop" shared/`
  returning nothing. tvOS's subtitle picker is independent native SwiftUI
  (`StreamPickerView.swift`, driven by `MPVPlayerView.swift` /
  `NativePlaybackCoordinator.swift`), not `LazyColumn`, so the fling-tap bug
  doesn't exist on tvOS (10-foot focus-engine selection, no scroll-fling
  gesture on the picker). For the duplicate-track bug: tvOS's mpv path
  already dedups incoming addon subtitles by `sub.url` at ingestion
  (`addedSubtitleUrls.contains(sub.url)` in `MPVPlayerView.swift`), which is
  the same disambiguator upstream's fix promotes to primary — so tvOS's
  existing behavior already matches upstream's fixed state by a different
  mechanism. No port needed, no bug reproduced.
- **`f6d4ddfa` / `bf37caa4` (el/es locale strings):** non-English
  `composeResources` string files, zero logic change, no tvOS equivalent
  (tvOS uses `Localizable.xcstrings`, ported independently).

## Fork state check

- `NuvioMobile` submodule on `tvos-shared-extraction`, HEAD `cf2f674e`
  (`tvos-v0.3.0-beta.17-1-gcf2f674e`) — one commit past the beta.17 release
  tag (`ff487392`), a release-notes template tweak (`cf2f674e`, "drop
  em-dashes"). Outer repo's pinned submodule pointer matches exactly
  (`git submodule status` shows no drift).
- No uncommitted tracked changes in the submodule; untracked `MPVKit` dir and
  a stray `hs_err_pid83786.log` (JVM crash log, harmless build artifact) are
  present but not part of tracked state.

## Action items for Claude Code

**None new.** All 5 upstream commits since the last check are
Android-Compose-only or pure localization; none touch `shared/` or have a
tvOS-relevant equivalent bug.

Carried, unchanged from prior runs (not re-actioned today, listed for
continuity only):

- **[Device pass owed]** Upstream batch 8 (`58864ec1` auto-play
  source-loading-scope) — merged 2026-09-02, device pass still owed for the
  non-default auto-play-source-scope case specifically.
- **[Unfiled upstream-report candidates, 4 total]** Simkl list-mutation
  precedence divergence, FNV size-prefixing hardening, `CatalogRepository`
  harder guard, TMDB `putIfAbsent`→`getOrPut` KMP-compat fix.
- **[PARKED/DEFERRED by product decision]** Supporter perks v1, subtitle
  minimum font size — no action until re-raised.
- **[LOW, spot-check only]** Player pause-description staleness — verify
  next time the tvOS player/pause-overlay UI gets touched.

## Verification method

- `git fetch upstream cmp-rewrite` in `NuvioMobile/`; compared fetched
  `upstream/cmp-rewrite` HEAD (`d4891ffa`) against the last-recorded pointer
  (`9b09045f`) — 5 non-merge commits via `git log --oneline --no-merges
  9b09045f..d4891ffa`.
- `git show --stat` then full `git show` on every commit that could plausibly
  touch shared logic, to read actual diffs rather than trust commit
  subjects.
- `grep -rl` across `shared/` for the specific symbols introduced by the
  Compose-only subtitle-picker fixes, to confirm zero shared-module surface
  area rather than assume from file path alone.
- Read tvOS's own `MPVPlayerView.swift` subtitle-ingestion code to confirm
  its existing URL-based dedup already covers the upstream duplicate-track
  bug, instead of asserting "not applicable" from file location alone.
- `git submodule status` in the outer repo + `git log -1` / `git status
  --short` on `tvos-shared-extraction` in the submodule, to confirm no
  untracked drift between the outer pointer and the submodule's actual HEAD.

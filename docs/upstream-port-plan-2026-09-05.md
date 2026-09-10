# Upstream port plan — 2026-09-05

## Upstream movement

`upstream/cmp-rewrite` (`github.com/NuvioMedia/NuvioMobile`) **moved** since
2026-09-04: `d4891ffa` → `9ee9da09`. Fresh `git fetch upstream` in
`NuvioMobile/` reported `d4891ffa..9ee9da09 cmp-rewrite ->
upstream/cmp-rewrite`, plus new tags `0.4.13` and `0.4.14`.

3 commits, no merges, all read in full with `git show`:

1. `4f79bfe0` — "fix(player): original audio language preference" — the one
   real commit this run. 17 files changed across `composeApp/` (Android +
   iOS mobile engines, the `PlayerScreenRuntime*` Compose player state
   machine, two new test files, a new `PlayerScreenRuntimeAudioPreferences.kt`),
   the mobile `iosApp/iosApp/Player/MPVPlayerBridge.swift`, and a new
   `scripts/test-mpv-audio-preferences.py`.
2. `7950abaa` — "bump version" (0.4.14).
3. `9ee9da09` — "chore(store): publish 0.4.14".

## Applicability to tvOS

**One real finding, classified LOW / investigate-only — not a confirmed
live bug, and the mechanical part is dead code on tvOS today.**

`4f79bfe0` is the "composeApp-looking path, but `shared/` has its own copy"
trap again — worth walking through in full rather than dismissing by file
path:

- **Mechanical, shared/-touching half:** `composeApp/src/commonMain/.../
  player/PlayerTrackSelection.kt` rewrites `findPersistedAudioTrackIndex()`
  to do stricter language-normalized matching with dub/original variant
  disambiguation (reusing `SubtitleLanguageMatching.detectTrackLanguageVariant`,
  the same mechanism the subtitle-track matcher already uses), and deletes
  the now-unused generic `findPreferredTrackIndex<T>()` helper.
  `shared/src/commonMain/kotlin/com/nuvio/app/features/player/
  PlayerTrackSelection.kt` **is** the tvOS extraction of this exact file
  (confirmed via `find shared -iname PlayerTrackSelection.kt`), and its
  current `findPersistedAudioTrackIndex()` is byte-identical to upstream's
  **pre-fix** version — confirmed unported.
  However: `grep -rn "findPersistedAudioTrackIndex" iosApp/NuvioTV/` returns
  nothing. tvOS's Swift only calls three functions out of this file
  (`resolveSubtitleAutoSelectionPlan`, `findPreferredSubtitleTrackIndex`,
  `filterAddonSubtitlesForSettings` — all subtitle-side). tvOS has no
  "restore the specific audio track the user explicitly picked last time"
  feature today, so this function is dead code on tvOS — porting the
  improved matching logic changes nothing live. Worth carrying as a
  parity item so the shared file doesn't silently drift further, and worth
  porting for free the next time anyone touches `PlayerTrackSelection.kt`
  for an unrelated subtitle change, but not worth a dedicated session.
- **Non-mechanical half, tvOS-relevant but needs its own design, not a
  copy-paste:** the mobile bridge fix moves audio-language preference
  application from *reactive* (wait for the track list to populate, then
  call `selectAudioTrack(index)`) to *proactive* (set mpv's `alang` option
  and re-apply it before every `mpv_initialize`/`loadfile`, so mpv's own
  internal track selection honors the preference from the first frame
  instead of visibly switching after the fact). This lives entirely in the
  mobile app's own `iosApp/iosApp/Player/MPVPlayerBridge.swift` — a
  different file from tvOS's `iosApp/NuvioTV/Screens/MPVPlayerView.swift`,
  not shared code. Checked tvOS's own `autoSelectPreferredTracks()` (the
  function serving the same purpose there): it still uses the older
  reactive pattern — wait for `walk`-populated track lists, then
  `eventQueue.async { setMpvInt("aid", ...) }`. That's the exact pattern
  mobile just moved away from, which means tvOS's mpv path could plausibly
  have the same "audio track flashes/switches after first frame instead of
  starting correct" symptom this upstream fix targets. **Not confirmed as
  a live tvOS bug** — no user report, and no direct evidence it's visibly
  wrong on tvOS specifically — so this is a manual investigation item
  (watch tvOS mpv playback start on a multi-audio-track title with
  "original audio" or a non-default language preference set, see if the
  audio track audibly switches shortly after start), not a scheduled port.
  Confirmed separately that `PlayerLanguagePreferencesKt
  .resolvePreferredAudioLanguageTargets` — the actual "which language(s)
  count as preferred, including original-audio-language resolution" logic
  — is untouched by this commit and already shared + consumed by tvOS, so
  tvOS's *target* language resolution is already correct; only the
  *timing/mechanism* of applying it to mpv is potentially behind.
- `7950abaa` / `9ee9da09`: version bump + store publish, no logic, not
  applicable (same pattern as every prior release-chore commit).

## Fork state check

- `NuvioMobile` submodule outer-repo pointer (via `git ls-tree HEAD
  NuvioMobile` in the outer repo) is `cf2f674e`, matching
  `tvos-shared-extraction`'s HEAD exactly — **no drift**, same as every
  prior run since beta.17.
- The submodule's working-copy checkout is currently on
  `claude/steven-beta17` @ `05d6749e` (10 commits past the beta.17 tag) —
  this is the in-progress Codex round 8 work already tracked in the outer
  repo's own commit log (`7400ffb` etc.), not upstream-sync drift. It's
  expected local state for active feature work, not a pointer problem.

## Action items for Claude Code

**No urgent action.** One LOW-priority parity item, no live bugs confirmed:

- **[LOW, opportunistic]** Port the improved `findPersistedAudioTrackIndex()`
  matching (dub/original variant disambiguation, stricter normalization)
  from upstream `4f79bfe0` into `shared/src/commonMain/kotlin/com/nuvio/app/
  features/player/PlayerTrackSelection.kt`, and drop the now-dead
  `findPreferredTrackIndex<T>()` generic alongside it if tvOS's copy still
  has it. Zero live impact today (function is unreferenced on tvOS) — do
  this opportunistically the next time `PlayerTrackSelection.kt` is
  touched for something else, not as a standalone task.
- **[LOW, investigate before deciding to build]** Check whether tvOS's mpv
  engine (`MPVPlayerView.swift` → `autoSelectPreferredTracks()`) shows a
  visible audio-track switch shortly after playback starts on a
  multi-audio-track title, the same symptom upstream's `4f79bfe0` fixed on
  mobile by setting mpv's `alang` option before `mpv_initialize`/`loadfile`
  instead of switching reactively after track enumeration. If reproduced,
  the fix would be a tvOS-native reimplementation of the same
  proactive-`alang` pattern (not a mechanical port — the file is
  `iosApp/NuvioTV/Screens/MPVPlayerView.swift`, entirely separate from
  mobile's `iosApp/iosApp/Player/MPVPlayerBridge.swift`). No user report of
  this on tvOS to date, so this is a "look for it next time you're in this
  file" item, not a scheduled fix.

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

- `git fetch upstream` in `NuvioMobile/`; compared fetched
  `upstream/cmp-rewrite` HEAD (`9ee9da09`) against the last-recorded pointer
  (`d4891ffa`) — 3 non-merge commits via `git log --oneline --no-merges
  d4891ffa..9ee9da09`.
- `git show --stat` then full `git show` on the one non-chore commit,
  reading the actual diff of every touched file rather than trusting the
  commit subject.
- `find shared -iname` + targeted `grep -rn` for the exact function names
  the commit touches, to confirm which half of the diff has a `shared/`
  counterpart before checking whether tvOS's Swift actually calls it.
- `grep -rn "findPersistedAudioTrackIndex" iosApp/NuvioTV/` (and the two
  other function names) to establish tvOS's real call graph into
  `PlayerTrackSelectionKt`, rather than assuming "shared file touched" ==
  "live on tvOS."
- Read `MPVPlayerView.swift`'s `autoSelectPreferredTracks()` in full to
  compare its audio-selection timing/mechanism against the mobile bridge's
  new proactive-`alang` approach.
- `git ls-tree HEAD NuvioMobile` in the outer repo vs. `git rev-parse
  tvos-shared-extraction` in the submodule, to confirm the outer pointer
  matches the shared-extraction branch exactly (the submodule's own
  working-copy checkout being on an unrelated WIP branch doesn't count as
  drift).

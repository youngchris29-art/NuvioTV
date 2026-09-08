# Upstream port plan — 2026-09-08

## Upstream movement

`upstream/cmp-rewrite` (`github.com/NuvioMedia/NuvioMobile`) **moved** since
2026-09-07: `526a5b97` → `a30bf519`. Fresh `git fetch upstream` in
`NuvioMobile/` reported `526a5b97..a30bf519 cmp-rewrite ->
upstream/cmp-rewrite`.

Two real commits + one merge commit, read in full with `git show`:

1. `21f5071a` — "Fix NetworkOnMainThreadException when starting a
   download" — `AndroidDownloadScheduler.execute()` was calling
   `client.connectionPool.evictAll()` synchronously in a `finally` block
   that runs on `Dispatchers.Main.immediate` (because
   `DownloadsTransferJobService` runs its coroutine scope there).
   Evicting the pool closes pooled SSL sockets, which throws
   `NetworkOnMainThreadException` whenever `onNetworkChanged` restarts a
   transfer. Fix wraps the eviction in
   `withContext(NonCancellable + Dispatchers.IO) { ... }`. Touches only
   `composeApp/src/androidMain/kotlin/com/nuvio/app/features/downloads/AndroidDownloadScheduler.kt`.
2. `80910185` — "Added Russian translation" — new
   `composeResources/values-ru/strings.xml` (2254 lines), one line added
   to `composeApp/src/androidMain/res/xml/locale_config.xml`, and a
   `RUSSIAN("ru", Res.string.lang_russian)` entry added to
   `composeApp/src/commonMain/kotlin/com/nuvio/app/features/settings/AppLanguage.kt`.
3. `ffab1e6b` / `a30bf519` — merge commits only, no independent diff.

No version-bump/store-publish commit in this window.

## Applicability to tvOS

**Zero action items — nothing live-breaking or urgent.** One item is
worth an opportunistic one-line port; the other is not applicable.

- `21f5071a` (download NetworkOnMainThreadException fix): confirmed
  Android-only. `find shared -iname "*DownloadScheduler*"` and `grep -rl
  AndroidDownloadScheduler shared/` both return nothing — no `shared/`
  extraction of this file exists. tvOS's own downloads implementation is
  a separate native path, not this Android `OkHttpClient`/`WorkManager`
  scheduler. Not applicable.
- `80910185` (Russian translation): the `values-ru/strings.xml` and
  `locale_config.xml` halves are Android-resource-only, not applicable.
  The `AppLanguage.kt` enum entry is the recurring "composeApp-looking
  path, but `shared/` keeps its own parallel copy" pattern seen before
  with `ARABIC` (ported 2026-08-19): `shared/src/commonMain/kotlin/com/nuvio/app/features/settings/AppLanguage.kt`
  is a fork-maintained, Compose-resource-free mirror of the same enum
  (language code only, no `StringResource` field — confirmed by diffing
  the two files). It's currently missing `RUSSIAN("ru")`, same gap
  pattern as before. **However**, tracing where this enum is actually
  consumed on tvOS shows it's genuinely low-priority: `grep -rl
  AppLanguage iosApp/NuvioTV/` returns nothing (no Swift consumer at
  all); within `shared/` it's only read by `ThemeSettingsStore.kt` /
  `ThemeSettingsRepository.kt` / `TvOsThemeSettingsStore.kt`, and
  `TvOsThemeSettingsStore.kt` has an explicit comment: `applySelectedAppLanguage`
  is a no-op because "the tvOS app is English-only for now." `AppLanguage.fromCode()`
  also has a safe fallback to `DEVICE` for unrecognized codes, so an
  unrecognized "ru" synced in from mobile wouldn't crash or misbehave —
  it just wouldn't be recognized as a named case. Net effect: this is
  enum-completeness parity, not a bug fix or a gap with any visible
  symptom on tvOS today.

## Fork state check

- Outer repo's committed submodule pointer (`git ls-tree HEAD
  NuvioMobile`) is `31d572b4` — matches `CLAUDE.md`'s record of the
  2026-09-07 evening Kotlin-toolchain-alignment merge.
- `origin/tvos-shared-extraction` (fetched fresh this run) is also at
  `31d572b4` — exact match, no drift.
- This sandbox's local submodule checkout (`NuvioMobile/` HEAD) is also
  at `31d572b4` (branch `tvos-shared-extraction`) — for once, no stale
  local-clone gap to note either. All three references (outer pointer,
  origin tip, local checkout) agree.

## Action items for Claude Code

**None new this run requiring immediate action.**

- **[LOW, opportunistic, cosmetic-parity only]** Add `RUSSIAN("ru")` to
  `shared/src/commonMain/kotlin/com/nuvio/app/features/settings/AppLanguage.kt`
  next time that file is touched for anything else — matches the
  existing `ARABIC` precedent, but there is no live tvOS consumer of the
  language-name distinction (tvOS is English-only; `applySelectedAppLanguage`
  is a no-op by design) and `fromCode()` already falls back safely, so
  this is not worth a standalone task.

Carried, unchanged from the 2026-09-07 run (not re-actioned today,
listed for continuity only — see that day's doc and its OUTCOME
ADDENDUM for what already closed):

- **[Device pass owed]** Upstream batch 9 (`8b43fd89` loop-exit +
  double-parse fixes, `4f79bfe0` shared audio-restore half, the
  proactive-`alang` audio-track-switch fix) — full device-pass checklist
  in the 2026-09-07 addendum.
- **[Device pass owed]** Kotlin toolchain bump to 2.4.10 (`31d572b4`) —
  cold-launch sanity check on the Apple TV, plus the existing batch-9
  checklist.
- **[DEFERRED]** Compose-runtime half of upstream `4f79bfe0` — waits for
  a future mobile-parity batch (Android doesn't compile in this
  environment). Trip wire: the `// Fork: retained (upstream deleted in
  4f79bfe0)` marker on `findPreferredTrackIndex<T>`.
- **[Device pass owed]** Upstream batch 8 (`58864ec1` auto-play
  source-loading-scope) — non-default auto-play-source-scope case only.
- **[Device pass owed]** Steven beta.18 batch (rc2/rc3 fixes incl.
  BUG-96) — device pass with Show Hero OFF still owed.
- **[Unfiled upstream-report candidates, 4 total]** Simkl list-mutation
  precedence divergence, FNV size-prefixing hardening, `CatalogRepository`
  harder guard, TMDB `putIfAbsent`→`getOrPut` KMP-compat fix.
- **[PARKED/DEFERRED by product decision]** Supporter perks v1, subtitle
  minimum font size — no action until re-raised.
- **[LOW, spot-check only]** Player pause-description staleness — verify
  next time the tvOS player/pause-overlay UI gets touched.
- **[Follow-up, separate task]** Stale `vulkan-disable-interop` mpv
  option diagnostic — naming added 2026-09-07, actual removal still out
  of scope.

## Verification method

- `git fetch upstream cmp-rewrite` in `NuvioMobile/`; compared fetched
  `upstream/cmp-rewrite` HEAD (`a30bf519`) against the last-recorded
  pointer (`526a5b97`) via `git log --oneline --graph 526a5b97..a30bf519`
  (4 commits incl. 2 merges, 2 real).
- `git show <sha> --stat` then full `git show <sha>` for both real
  commits to read every hunk rather than trusting commit subjects.
- `find shared -iname "*DownloadScheduler*"` and `grep -rl
  AndroidDownloadScheduler shared/` (both empty) to confirm the download
  fix has no `shared/` extraction.
- Diffed `shared/src/commonMain/.../AppLanguage.kt` against the
  pre-Russian `composeApp` version at `526a5b97` to confirm the
  fork-maintained-mirror pattern and the missing `RUSSIAN` entry.
- `grep -rln AppLanguage iosApp/NuvioTV/` (empty) and `grep -rln
  AppLanguage shared/src/` to trace every real consumer before judging
  priority; read `ThemeSettingsRepository.kt`, `ThemeSettingsStore.kt`,
  and `TvOsThemeSettingsStore.kt` in full for the English-only no-op
  comment and the `fromCode()` fallback behavior.
- `git submodule status`, `git ls-tree HEAD NuvioMobile` in the outer
  repo, and `git fetch origin tvos-shared-extraction` + `git rev-parse`
  in the submodule to confirm outer pointer, origin tip, and local
  checkout all agree at `31d572b4` — no drift.

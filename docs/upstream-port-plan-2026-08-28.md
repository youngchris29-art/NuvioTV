# Upstream port plan — 2026-08-28

## Upstream movement

`upstream/cmp-rewrite` (`github.com/NuvioMedia/NuvioMobile`) has **not moved**
since the 2026-08-27 check. HEAD is still `1b84ee47` ("Merge pull request
#1785 from halibiram/fix/tmdb-cast-english-fallback", 2026-08-27 13:22:32
+0530). Fetched fresh today (2026-08-28 11:10 UTC) — zero new commits, zero
new merges.

Because there's no new upstream content, this run re-verifies the 2026-08-27
plan's unported items directly against the fork's current `shared/` state
(`tvos-shared-extraction` @ `dc8281c2`, matches released beta.15 build 113)
rather than re-deriving a new diff.

## Re-verification: all 6 items from 2026-08-27 confirmed still unported

Checked by reading current file contents, not by trusting yesterday's notes:

1. **[HIGH, possible live break]** `InAppYouTubeExtractor.kt` — still
   `PREFERRED_SEPARATE_CLIENT = "android_vr"` (line 21) and the `android_vr`
   client block (line ~96). No `visionos` client, no `isDefaultAudioTrack`
   anywhere in the file. **Still unported.**
2. **[MEDIUM]** `HeroTrailerSelector.kt` — no `distinctBy`. `MetaDetailsModels.kt`
   — no `iso6391` field on `MetaTrailer`. **Still unported.**
3. **[MEDIUM]** `TmdbMetadataService.kt` — no `containsCjkOrHangul`,
   `resolvePersonName`, `fetchEnglishFallbackNames`, or `isCjkLanguage`.
   **Still unported.**
4. **[MEDIUM]** `TmdbMetadataService.kt` — no `aggregate_credits` /
   `TmdbAggregateCreditsResponse`. **Still unported.**
5. **[LOW]** `SimklMutationReceipt.kt` `stringValue()` (line 265) — still the
   bare `get(key)?.jsonPrimitive?.content` with no explicit `JsonNull` guard.
   **Still unported.**
6. **[MEDIUM]** `WatchingPolicies.kt` — no `isShortPlaceholderDuration`, no
   `MinRealContentDurationMs`. **Still unported**, and the tvOS-native player
   call-site investigation (near `MPVPlayerView.swift`) also still hasn't
   happened.

No action has landed on any of these six since yesterday's write-up — same
recommended batching applies (see `docs/upstream-port-plan-2026-08-27.md` for
full per-item detail, file paths, and the suggested 3-group Claude Code
session plan: trailer batch, TMDB name-fallback batch, small fixes).

## Side-check: carried older items

- **HIGH subtitle/player-engine batch** (carried from 2026-08-25) — still
  unported. `grep -rl "StartupMode" shared/src` still finds it in
  `PlayerSettingsStorage.kt`, `PlayerSettingsRepository.kt`,
  `PlayerTrackSelection.kt`, `SubtitleAudioModels.kt`, and the apple/jvm/android
  actuals — the field upstream removed is still present, confirming this
  8-commit batch (buffer-preserving sidecar subtitles, parallelized addon
  subtitle fetch, ASS/TTML parser restoration, forced-subtitle
  auto-selection, etc.) hasn't landed. See `docs/upstream-port-plan-2026-08-25.md`
  for the full commit list and porting notes.
- **A2 crash-cluster fixes** (reported ported 2026-08-26) — spot-checked
  today and confirmed still present: `SearchRepository.kt` uses `trySend`,
  `HomeCatalogSettingsRepository.kt` uses `atomicfu` (`atomic`,
  `SynchronizedObject`), not a plain mutable map. This matches the prior
  claim; no regression.

## Action items for Claude Code (unchanged from 2026-08-27, still open)

- [ ] **[HIGH]** Trailer batch: YouTube extractor `android_vr`→`visionos`
      client swap + `isDefaultAudioTrack` dub-track skip
      (`InAppYouTubeExtractor.kt`), bundled with `HeroTrailerSelector`
      dedup + `MetaTrailer.iso6391` + TMDB trailer-list dedup/lang-tiebreaker
      sort. Device-test trailer playback after — this may be a live break.
- [ ] **[MEDIUM]** TMDB CJK/Romaji cast-crew name fallback, 3-commit chain,
      port as one batch into `TmdbMetadataService.kt` (+ port
      `TmdbMetadataServiceTest.kt` additions).
- [ ] **[MEDIUM]** `tv/{id}/aggregate_credits` for full-series cast/crew
      (`TmdbMetadataService.kt`).
- [ ] **[LOW]** Simkl `stringValue()` `JsonNull` guard
      (`SimklMutationReceipt.kt`) — mechanical, bundle with anything.
- [ ] **[MEDIUM]** Scrobble guard for short placeholder/error-clip durations
      — shared half (`WatchingPolicies.kt`) is a clean port; tvOS-native
      player completion call site needs its own investigation (no direct
      upstream equivalent file to copy from).
- [ ] **[carried, HIGH]** Subtitle/player-engine batch (2026-08-25, 8 commits)
      — still fully unstarted, own dedicated session recommended given size.

## OUTCOME ADDENDUM — same-day evening session, 2026-08-28

**Both batches PORTED.** Two independent submodule branches off
`tvos-shared-extraction` @ `dc8281c2`, both pushed, zero file overlap,
merge decision owed after device pass:

### `claude/upstream-batch6` (tip `437a331f`, 5 commits) — all 6 items closed

1. visionOS YouTube client swap + `isDefaultAudioTrack` — ported verbatim
   (UA/context byte-checked against upstream). **Device-test trailer playback.**
2. Trailer dedup — only `.distinctBy { it.key }` was actually missing (two
   sites); `iso6391` + preferredLang sort were already superseded by the
   fork's own BUG-63/67 `MetaTrailer.language` + `metadataLanguagePriority`.
3. CJK/Romaji name fallback 3-commit chain — ported with `resourceString`
   i18n substitution + new `TmdbMetadataServiceTest.kt` (15 tests);
   `putIfAbsent`→`containsKey` (JVM-only API on a K/N target).
4. `aggregate_credits` for series — ported; upstream's DTOs drop
   `original_name` for TV (ported faithfully, report candidate).
5. Simkl `stringValue()` JsonNull guard — ported.
6. Scrobble guard — **shared-only, investigation closed**: both tvOS engines
   hardcode `isEnded=false` and funnel through `isProgressComplete()`; no
   Swift completion guard needed. Codex then showed upstream's isEnded-only
   guard is inert on tvOS → guard extended to the fraction path AND
   `shouldStoreProgress()` (CW pollution) AND both Swift Trakt drivers
   (skip start / stop-at-0% for short clips) — the fork's analog of
   upstream's Compose-side `MainAppContent.kt` half.

Codex loop settled at round 5: 4 fix commits (fraction-path guard;
media-type-qualified English-title keys — bare-Int keys can swap titles
across movie/TV id namespaces; aggregate TV fallback fetch — upstream still
queries series-level `credits` for the English fallback; English fallback
when localizedName absent), 3 documented parity declines (Trakt start
before mpv duration known — pre-existing, stop-at-0% compensates; sub-121s
content never tracked — upstream's deliberate threshold; `distinctBy`
first-wins — upstream's code).

Gates: jvmTest 529, tvosSimulatorArm64Test 541, NuvioTV sim build green.

### `claude/subtitle-engine` (tip `716c18ea`, 7 commits) — the carried 08-25 HIGH batch

Ported as end-states, not commit-replay: `33c6cdc2` superseded by
`2c7438d6` (its `java.util.Collections` intermediate can't compile in
commonMain), `5a60a95d`'s parser state superseded by `11221560`, its fat
`PlayerSubtitleUtils` superseded by `47decd9d`'s delegate.
`AddonSubtitleStartupPolicy` never existed here (deletion no-op).

- **Wave A**: StartupMode removed everywhere + `SubtitleSyncCue.endTimeMs`.
  Migration: key kept renamed `legacyAddonSubtitleStartupModeKey` and left
  in `syncKeys` so the next `replaceFromSyncPayload` purges the orphaned
  pref — no schema bump, older clients default to the new behavior.
  ⚠️ `grep -rl StartupMode shared/src` still hits the 3 storage actuals via
  that legacy key name — the correct was-it-done check is now
  `grep -rl AddonSubtitleStartupMode shared/src` → empty.
- **Wave B**: cue parser whole-file at `11221560` (ASS/TTML back, +3 tests);
  SubtitleRepository parallel per-addon fetch with incremental emission —
  all fork invariants preserved (`completedRequest` on every terminal path
  incl. the new empty-addons early return — both tvOS players poll it),
  10s per-addon timeout atop the 8s readiness wait (~18s worst case,
  documented); `47decd9d` forced-subtitle selection + `SubtitleLanguageMatching`
  (public) + `subtitleIsForced` persistence incl. the fork-only jvm actual.
- **Wave C**: compose runtime (TrackActions byte-identical to upstream
  `9d4560bc` end state).
- **Wave E**: tvOS Swift call-site migration (AudioTrack-object plan API,
  threaded into `findPreferredSubtitleTrackIndex` — forced auto-select
  returns -1 without it) + the `subsFetchDone` fix: completion now owned
  solely by the `completedRequest` poll, or incremental streaming would
  bake a partial subtitle set into the native path's HLS master.
- **Wave D (Android ExoPlayer sidecar) DEFERRED by product decision
  2026-08-28** — zero tvOS value, hardest package, plus a fork-specific
  SDH-filter/VTT-normalization bypass that needs its own fix. Log for a
  future mobile-parity pass. Also skipped: `0451b02e`
  (PlayerEngine.android.kt-only), Compose SubtitleModal UX halves, the
  `8881eae1`-derived LaunchedEffect keys, dead startup-mode strings.
- Also fixed pre-existing: composeApp's iOS compile was broken at the
  beta.15 base (`StreamsScreen.kt` missing the BUG-74 `IncompatibleContentId`
  branch) — fixed to unblock compile-gating (`ca3d66a8`).

Codex loop settled at round 4: 3 fix commits (persisted `subtitleIsForced ==
false` now excludes forced tracks in both fallbacks; bare-"la" Latin-American
marker now word-boundary — "Castellano" was misread es-419; generic pt/es
targets no longer accept explicitly tagged pt-BR/es-419 tracks — the guard's
raw-language clause neutered it; language-NAME matching now boundary-aware —
"Malayalam" matched target "ms"). 6 documented parity declines, all either
the unshipped compose runtime (byte-identical upstream; tvOS never restores
persisted track selections — verified, delay only) or upstream's deliberate
variant-miss -1 design (addon-ladder interplay; on the device checklist).

Gates: jvmTest 515 / tvos 527 / composeApp iosSim 420, NuvioTV sim build green.

### Upstream-report candidates (new, unfiled — join the 3 carried ones)

1. aggregate_credits DTOs drop `original_name` (weakens CJK fallback for TV)
2. `englishCreditTitlesById` keyed by bare Int across movie/TV namespaces
3. English fallback fetch uses series-level `credits` after the localized
   fetch moved to `aggregate_credits`
4. `resolvePersonName` returns CJK original when localizedName is null even
   with an English fallback fetched
5. Persisted non-forced restore can select a forced track listed first
6. `normalizeLanguageCode` bare-"la" substring misreads "Castellano" as es-419
7. Generic pt/es target accepts explicitly tagged regional tracks
8. Language-name substring matching ("Malayalam" ⊃ "malay")
9. Compose runtime: persisted DISABLED overridden on addon arrival;
   forced addon can win NORMAL_ONLY; empty first scan ends retries
10. Variant-miss `return -1` skips secondary preferred language (may be
    deliberate — verify against the addon ladder before filing)

### Device-pass checklist (owed, irreducibly manual)

Trailer playback (batch 6 #1 — possible live break, screenshot-scan);
multi-addon progressive subtitles + complete HLS master; no-subtitle-addons
title doesn't hang (completedRequest); forced-subtitle auto-select incl.
3-letter tags and pt/pt-BR + es/es-419; a pt-BR-primary + en-secondary user
on an English-only stream (variant-miss -1 decline); beta.15 subtitle sync
offset + SDH stripping regression; settings-sync round trip purges the
orphaned `addon_subtitle_startup_mode` key; short debrid placeholder clip
neither scrobbles, appears in CW, nor marks watched.

## Next scheduled check

Re-fetch `upstream/cmp-rewrite`. If still pinned at `1b84ee47`, verify the
two port branches' items using the file-content checks above (note the
StartupMode grep caveat). If it has moved, diff past `1b84ee47` as usual.

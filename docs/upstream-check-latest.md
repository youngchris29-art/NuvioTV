# Upstream check — latest (rolling)

Overwritten by the `nuvio-upstream-check` scheduled task on every run. The dated reports it also writes (`docs/upstream-port-plan-YYYY-MM-DD.md`, `docs/nuviotv-android-upstream-port-plan-YYYY-MM-DD.md`) stay local and are gitignored; this file is the only tracked record and carries the baselines the next run starts from.

- **Run:** 2026-11-10
- **NuvioMobile baseline** (`NuvioMedia/NuvioMobile` `cmp-rewrite`): `83f07d4c2` — dated report `docs/upstream-port-plan-2026-11-10.md`
- **NuvioTV Android baseline** (`NuvioMedia/NuvioTV` `dev`): `17ddebe73` — dated report `docs/nuviotv-android-upstream-port-plan-2026-11-10.md`

## NuvioMobile — 2026-11-10

Upstream `NuvioMedia/NuvioMobile` (`cmp-rewrite`): `de60c5a16` -> `83f07d4c2`. 24 commits (about 14 non-merge), 33 files. Fork tip checked: `0b167a953`.
**New baseline: `83f07d4c2`.**

1. **PORT (M) — MDBList remap cache** (`9c2d09027`): adds a `remapped` flow (only mappings that really remap) beside `resolved`, and a `MdbListRemapCache` so progress and watched lists are rebuilt once per mapping change, not per read. Files: `shared/.../mdblist/MdbListEpisodeMappingService.kt`, `MdbListTrackingProgressProvider.kt`, `MdbListWatchedSyncAdapter.kt`, new `MdbListRemapCache.kt` (upstream put it in composeApp; fork needs it in shared), tests `MdbListEpisodeMappingTest`. The fork's remap work (11-05, `4d9b47eed`) uses `resolved`, so this is a real consumer change. Gate `:shared:jvmTest`, then Detail/CW device pass on Hunter x Hunter in Test 2.
2. **PORT (M) — Auth: stay signed in when refresh fails** (`daa966d36`): `RefreshFailure` no longer sets Unauthenticated; invalid-session detection moves to `AuthSessionErrors.kt` (jwt-expired triggers a refresh retry under a mutex); lost sessions raise a "signed out" notice via `had_account_session` / `signed_out_notice` flags in `AuthStorage` (needs apple actual of `loadFlag`/`saveFlag` if absent, plus a string). Files: `shared/.../core/auth/AuthRepository.kt`, new `AuthSessionErrors.kt`, `AuthStorage.kt` + `AuthStorage.apple.kt`. Fork's `AuthRepository.kt` still has `RefreshFailure -> Unauthenticated` and `isInvalidRemoteSessionError`. Worth it: Wi-Fi-only box drops would otherwise sign the account out. Needs a StringProvider key for the notice.
3. **PORT (S) — Persisted addon subtitle matched by id** (part of `d5e8bbdfb`): `findPersistedAddonSubtitle` tries `addonSubtitleId` (with addon name) before the language fallback. File: `shared/.../player/PlayerTrackSelection.kt` (+ `PlayerTrackSelectionTest`). `addonSubtitleId` already exists in `PlayerTrackPreferenceStorage`. Gate `:shared:jvmTest`.
4. **DECIDE (S) — forced subtitles on by default** (`a6065c8b1`, `SubtitleStyleState.useForcedSubtitles` default true in shared `SubtitleAudioModels.kt`): the fork's Swift builds `SubtitleStyleState(...)` from stored values, so a default flip changes new installs only. AutoSync default-on is not applicable (the fork has no AutoSync). Christian's call; a release-note line if taken.
5. **WATCH (L) — AutoSync restored-subtitle fallback** (`d5e8bbdfb`, `87e399626`, `cc2bf0d88`, `AutoSyncRunPolicy.kt`, composeApp-only): no AutoSync on tvOS. Revisit only if AutoSync is ever ported.
6. **SKIP — Compose-only UI**: backdrop smart framing/focus (`BackdropFocus*.kt`, `HomeHeroSection`, `DetailHero`; composeApp, the fork has native SwiftUI heroes), opening overlay on tall screens (`OpeningOverlay.kt`), mpv error details on the error screen (`PlayerEngine.android.kt`, Android-only), Bulgarian/French i18n, version bump and store.json.

Suggested order: 2, 1, 3 in one batch (all `shared/`, `:shared:jvmTest` plus tvOS tests), 4 on Christian's decision.

## NuvioTV Android — 2026-11-10

Upstream `NuvioMedia/NuvioTV` (`dev`): `12d96bced` -> `17ddebe73`. 15 commits (about 8 non-merge), 20 files.
**New baseline: `17ddebe73`.**

1. **PORT (S) — Post-play timing from End Credits chapters for movies** (`97015f17b`, PR #4549): `PostPlayRecommendationTiming.kt` uses an End Credits chapter for movie recommendation timing. Android-app file; check whether the fork has an equivalent next-up/post-play timing in `shared/` (`graphify query "post play recommendation timing"`) before porting. Fork already has chapter skip.
2. **CHECK (S) — Continue Watching keyed by show / kept while next-up rebuilds** (`4eb7dda70`, `88c27bbde`, `ContinueWatchingNextUpReconciliation.kt`, `HomeViewModelContinueWatching.kt`): UI-layer fixes in Android's home view model. Compare against the fork's Continue Watching merge in shared (`WatchProgress`/CW projection) for the same flicker/duplicate; likely a Swift-side check only.
3. **CHECK (S) — Pull watch state early on startup and after in-app navigation** (`e12bc8752`, `StartupSyncService.kt`, `MainActivity.kt`): Android startup sync ordering; the fork's sync is separate. WATCH.
4. **SKIP — Android-only**: CloudStream `.cs3` MainActivity stub (`9a8468e0f`), forced AC-3 transcoding with pinned audio caps (`42b1b64ff`), Lithuanian and Dutch translations.

Carried over unchanged from 2026-11-09: forced-subtitles/AutoSync defaults (DECIDE, S; see NuvioMobile item 4, same change in the Mobile repo), Trakt write-mapping guard (`b1bf4bd83`, S, `shared/.../trakt/TraktEpisodeMappingService.kt`) and the Anime-Skip fixes (M).

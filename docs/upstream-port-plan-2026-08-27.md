# Upstream port plan — 2026-08-27

Upstream `NuvioMedia/NuvioMobile` (`cmp-rewrite`) moved `582ae863` → `1b84ee47`
(7 non-merge commits + 2 merge commits) since the 2026-08-26 check. All 7 land
in `composeApp/`, but this fork's `shared/` module is an extraction of that
same code — checked each target file directly against `shared/` on
`claude/beta15` (verified by reading current file contents, not commit
messages). **6 of 7 are unported.**

## Unported — recommended for this fork

### 1. [HIGH — likely live breakage] YouTube trailer extractor client swap
Upstream `c72a3825` ("Match Trailer changes from NuvioTV") switches
`InAppYouTubeExtractor`'s preferred separate-stream client from `android_vr`
to `visionos` — new client id (`101`), new version (`1.02`), new user agent
(visionOS Safari UA), new innertube context block (`VISIONOS`/`RealityDevice17,1`).
This reads as a fix for YouTube blocking/deprecating the `android_vr` client —
if so, in-app trailer playback on this fork is currently broken or degraded
until this lands.

- File: `shared/src/commonMain/kotlin/com/nuvio/app/features/trailer/InAppYouTubeExtractor.kt`
- Confirmed unported: fork still has `PREFERRED_SEPARATE_CLIENT = "android_vr"` (line 21) and the old `android_vr` client block (line ~96).
- Also in the same upstream commit, bundled with the client swap: `isDefaultAudioTrack` field on `StreamCandidate` + `audioTrack.audioIsDefault` parsing, to correctly skip alternate-language dub tracks on multi-language trailer uploads. Confirmed unported (`isDefaultAudioTrack`/`audioIsDefault` absent from `shared/`).
- Action: port the client table swap + `isDefaultAudioTrack` plumbing verbatim. Test trailer playback on-device after — this is exactly the kind of break that won't show up in unit tests.

### 2. [MEDIUM] Trailer language/dedup improvements
Same upstream commit (`c72a3825`), three smaller changes bundled with the
extractor swap:
- `HeroTrailerSelector.selectHeroTrailer()`: added `.distinctBy { it.key }` before ranking, to stop duplicate YouTube keys from both being candidates. Confirmed unported (`shared/.../details/HeroTrailerSelector.kt` has no `distinctBy`).
- `MetaTrailer` gains an `iso6391: String?` field. Confirmed unported (`shared/.../details/MetaDetailsModels.kt`).
- `TmdbMetadataService`'s trailer-list builder: dedups videos by YouTube key before grouping, and adds a `preferredLang` tiebreaker (matches device language → `en` → other) ahead of official/publish-date sort. Confirmed unported (`shared/.../tmdb/TmdbMetadataService.kt` has neither the `distinctBy` nor the `iso6391` sort tier).
- Action: port together with #1 since they're one upstream commit touching overlapping files.

### 3. [MEDIUM] TMDB CJK/Romaji cast & crew name fallback (3-commit chain)
Upstream `c66e80e6` → `e6314ba2` → `754605cb`, same author (halibiram), same
file, each building on the last:
- `c66e80e6`: person-detail bio + name — when TMDB's localized response returns CJK/Hangul text for a non-CJK requested language, fetch an `en`-language copy of the person and fall back to that name/bio. Adds `containsCjkOrHangul()` and `resolvePersonName()` helpers.
- `e6314ba2`: extends the same fallback to filmography credit lists (cast/crew names shown on a person's filmography).
- `754605cb`: extends the same fallback to network/studio browse pages' cast/crew titles.
- Each commit also adds/extends `TmdbMetadataServiceTest.kt` — worth porting the tests too since this is exactly the kind of locale-edge-case logic that regresses silently.
- Confirmed unported: `grep` for `containsCjkOrHangul`, `resolvePersonName`, `fetchEnglishFallbackNames`, `isCjkLanguage` in `shared/.../tmdb/TmdbMetadataService.kt` returns nothing.
- Action: port as one batch (all three commits touch the same function family) rather than three separate passes — the intermediate states aren't independently useful.

### 4. [MEDIUM] `tv/{id}/aggregate_credits` instead of `tv/{id}/credits`
Upstream `0aac4dbe` ("Use aggregate_credits for series like on NuvioTV") —
for TV series, TMDB's `aggregate_credits` endpoint returns cast/crew rolled up
across all seasons (more complete than the plain `credits` endpoint, which is
season/episode-scoped for TV). Adds `TmdbAggregateCreditsResponse` +
supporting DTOs and a `.toStandard()` mapper so the rest of the pipeline is
unchanged; movies still use plain `credits`.
- File: `shared/src/commonMain/kotlin/com/nuvio/app/features/tmdb/TmdbMetadataService.kt`
- Confirmed unported: no `aggregate_credits` / `TmdbAggregateCreditsResponse` in `shared/`.
- Action: straightforward port, independent of items #1–3 (different call site, though same file — expect a small merge-order dependency if porting #3 first).

### 5. [LOW] Simkl mutation-receipt null handling
Upstream `e39084d6` ("fix null in json") — `JsonObject.stringValue()` used
`get(key)?.jsonPrimitive?.content`, which throws/misbehaves if TMDB/Simkl
returns an explicit JSON `null` for that key (`jsonPrimitive` succeeds on a
`JsonNull`, but `.content` on it is the literal string `"null"`, not really
null). Fix adds an explicit `JsonNull` check before reading `.content`.
- File: `shared/src/commonMain/kotlin/com/nuvio/app/features/simkl/SimklMutationReceipt.kt`
- Confirmed unported (fork's `stringValue()` at line 265 lacks the `JsonNull` guard).
- Action: small, mechanical, low-risk — safe to bundle with any other Simkl work, or land standalone.

### 6. [MEDIUM] Scrobble guard for short placeholder/error-clip durations
Upstream `31f5d0e6` ("Add guard to not scrobble short error messages videos
like on NuvioTV") — debrid cache-sync placeholders and error clips sometimes
report a short total duration and reach "ended" state, which was getting
scrobbled/marked-watched as if it were real content. Adds
`isShortPlaceholderDuration()` (anything 1ms–121000ms exclusive) and wires it
into both `isProgressComplete()` (shared, so it flows through automatically)
and the Compose player's completion handler (`MainAppContent.kt`, upstream's
mobile-only file — tvOS has no equivalent, needs its own call site).
- Shared half: `shared/src/commonMain/kotlin/com/nuvio/app/features/watching/domain/WatchingPolicies.kt` — confirmed unported (no `isShortPlaceholderDuration`, no `MinRealContentDurationMs`, `isProgressComplete` doesn't check it).
- Downstream consumer already in `shared/`: `WatchProgressRules.kt` calls `isProgressComplete()` — once `WatchingPolicies.kt` is patched, this consumer picks up the guard for free, no separate change needed there.
- tvOS-native half: upstream's `MainAppContent.kt` guard (skip scrobble+progress write when `isShortPlaceholderDuration(durationMs)`) has no tvOS equivalent to port verbatim — **needs investigation**: find tvOS's native player completion/scrobble call site (likely in or near `MPVPlayerView.swift` or a player view model) and add the same short-circuit there. Check this before deciding the port is complete — the shared-logic half alone doesn't fix the bug if tvOS's Swift completion handler doesn't call it.

## Not applicable / no action

None this run — all 7 non-merge commits are unported and relevant (unlike some prior days, there was no "already covered by a fork divergence" or "feature doesn't apply to tvOS" case this time).

## Suggested batching for a Claude Code session

1. **Trailer batch** (#1 + #2): same upstream commit, same files, do together, then device-test trailer playback specifically since #1 may be fixing a live break.
2. **TMDB name-fallback batch** (#3 + #4): same file (`TmdbMetadataService.kt`), port #3 (three sub-commits) then #4, run `TmdbMetadataServiceTest.kt` after each.
3. **Small fixes** (#5 + #6): mechanical Simkl null fix, plus the scrobble guard — remember #6 needs a tvOS-native call-site search, not just a shared-logic port.

## Verification for next run

Confirm all six landed by re-reading `shared/.../tmdb/TmdbMetadataService.kt`,
`InAppYouTubeExtractor.kt`, `HeroTrailerSelector.kt`, `MetaDetailsModels.kt`,
`WatchingPolicies.kt`, `SimklMutationReceipt.kt` directly, not by trusting
commit messages on whatever branch this lands on.

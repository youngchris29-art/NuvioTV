# Upstream port plan — 2026-09-15

Daily scheduled check of `NuvioMedia/NuvioMobile` (`cmp-rewrite`) against this fork's `NuvioMobile` submodule (`tvos-shared-extraction`).

Upstream moved: `326fb8c7` → `9bc77bc4` — 22 commits (14 real, 6 merges, 1 version bump `3d415441`, 1 store publish `9bc77bc4`). All 14 real commits read in full via `git show`, not just commit titles.

Submodule pointer check: the outer repo's committed pointer and `origin/tvos-shared-extraction`'s fetched tip both sit at `243da21b` (tag `tvos-v0.3.0-beta.18-rc12`) — no fork-sync drift. This sandbox's local submodule checkout is on WIP branch `claude/rc13-batch` (tip `3449db86`) mid-session — that's the rc13 batch CLAUDE.md already records as built-but-not-yet-merged today, unrelated to upstream drift.

Every commit this run touches only `composeApp/` (or mobile's own `iosApp/iosApp/`, `androidMain/`). Three of the fourteen touch a `composeApp/` file that has a same-named, same-package `shared/` extraction — those three are this run's action items.

## Action items

### 1. [MEDIUM, needs reconciliation — not a blind copy] Anime skip-intro: sibling-season Simkl resolution + episode remap

Commit: `aa748fa8` "Improve IMDB -> Mal mapping"

Upstream's `composeApp/.../player/skip/SimklIdResolver.kt` gains:
- `resolveIdsForImdbEpisode(imdbId, season, episode)`: resolves the base anime entry by IMDB id; if its Simkl `tvdbSeason` doesn't match the requested season, it calls the *parent* Simkl entry with `extended=full_anime_seasons`, reads `mapped_tvdb_seasons` to find the sibling entry whose `tvdb_season` matches, and re-resolves MAL/AniList/Kitsu ids from that sibling's own Simkl id.
- `resolveSeasonSimklId()` / `resolveIdsBySimklId()` helpers plus a new `animeSeasonCache`.

`composeApp/.../player/skip/SkipIntroRepository.kt` then:
- Calls `resolveIdsForImdbEpisode()` instead of the plain `resolveIds("imdb", imdbId)`.
- Remaps the TVDB-numbered `episode` to the anime-native per-season `animeEpisode` (via the existing `SimklIdResolver.getEpisodeMapping()`) before calling `fetchFromAniSkip`/`fetchFromAnimeSkip` — long-running anime where TVDB season/episode numbering diverges from the anime's own per-entry numbering (One Piece-style absolute numbering, or a show split across several Simkl anime entries) were getting the wrong AniSkip/Anime-Skip lookup key.

**Why this isn't a mechanical port:** `shared/src/commonMain/kotlin/com/nuvio/app/features/player/skip/SimklIdResolver.kt` already carries a *different* fork-original fix for a related problem, landed with the 2026-09-01/09-02 ARM→Simkl port (see the `// Codex r2/r3/r4` comments): `resolveIds(source, id, season: Int? = null)` scans the `/search/id` result list for a candidate whose `tvdbSeason` matches, falling back to the first result. That approach depends on Simkl's search-by-external-id actually returning multiple candidates for one IMDB id — which it likely doesn't for most multi-season anime (Simkl's IMDB search commonly resolves to one canonical parent entry, not one row per season). Upstream's new approach sidesteps that by querying the parent's own `full_anime_seasons` mapping directly, which is more likely to actually find the sibling. Upstream also adds the episode-remap step, which the fork has no equivalent of at all.

**Confirmed live on tvOS:** `MPVPlayerView.swift` (line ~801) and `NativePlayerScreen.swift` (line ~187) call `getSkipIntervalsForContentId()` for `mal:`/`kitsu:`-prefixed anime content, which routes through this exact `SimklIdResolver`/`SkipIntroRepository` chain — non-anime (plain IMDB) skip-intro is unaffected.

**Suggested port shape:**
- Add `resolveSeasonSimklId()` / `resolveIdsBySimklId()` / `animeSeasonCache` to `shared/.../SimklIdResolver.kt` as new methods — don't touch the fork's existing `resolveIds(source, id, season)` or `resolveEpisodeTvdb()`, which other call sites may depend on.
- Add a `resolveIdsForImdbEpisode(imdbId, season, episode)` entry point that: calls the fork's own `resolveIds("imdb", imdbId, season)` first (keep the existing search-scan behavior as the first pass — it's "free" and occasionally right), and if the returned `tvdbSeason` still doesn't match, falls through to upstream's sibling-lookup via `full_anime_seasons`.
- In `shared/.../SkipIntroRepository.kt`, add the episode-remap step (`getEpisodeMapping` → `animeEpisode`) before the AniSkip/Anime-Skip calls in `getSkipIntervals` (the fork's current `getSkipIntervals` still passes the raw TVDB `episode` straight through — confirmed by reading the file).
- Mirror upstream's session for `getSkipIntervalsForMal`/`getSkipIntervalsForKitsu` variants if they have the same raw-episode gap (check before assuming).
- Add a small unit test exercising a synthetic multi-season anime IMDB id.

### 2. [MEDIUM, mechanical] TVDB as a Simkl anime-ID preference option

Commit: `8aad52d8` "Add TVDB as Simkl Anime ID resolution"

Adds `SimklAnimeIdPreference.TVDB` (alongside the existing IMDB/MAL/KITSU), a `canonicalContentId()`/`alternateContentIds()` branch for it in `SimklProjections.kt` (TVDB id first, falling back through imdb/tmdb/mal/anidb/anilist/kitsu/simkl), and — separately — adds a `kitsu` link to the *existing* IMDB-preference standard fallback chain that was missing one.

Confirmed unported:
- `shared/src/commonMain/kotlin/com/nuvio/app/features/simkl/SimklAnimeIdPreference.kt` — still only `IMDB, MAL, KITSU`.
- `shared/src/commonMain/kotlin/com/nuvio/app/features/simkl/SimklProjections.kt` — `canonicalContentId(preference)` and `alternateContentIds()` have no `TVDB` branch; the standard fallback chain (used for the `IMDB` case) has no `kitsu` line.

Confirmed live tvOS consumers of the preference enum: `iosApp/NuvioTV/Screens/Settings/AccountServicesSettingsPane.swift` (the anime-ID-preference picker row) and `iosApp/NuvioTV/Screens/SimklViewModel.swift`.

**Port shape:** add the `TVDB` enum case + doc comment; add the `canonicalContentId`/`alternateContentIds` branches verbatim from upstream's diff; add the missing `kitsu` fallback line to the `IMDB` chain; add a "Prefer TVDB" option + description string to `AccountServicesSettingsPane.swift`'s picker (mirroring how MAL/Kitsu are already presented there) and the two new string resources (`settings_tracking_anime_id_tvdb[_description]`).

### 3. [LOW, mechanical] Indonesian/Malay subtitle-language disambiguation

Commit: `d95b4f9b` "Add bahasa indonesia mapping"

Upstream's `PlayerSubtitleMatching.kt` adds an `INDONESIAN_TAGS` list (`"indonesia"`, `"indonesian"`, `"bahasa indonesia"`) and two new text-matching branches: subtitle labels containing "bahasa indonesia"/"indonesian"/"indonesia" now resolve to `id`, "bahasa malaysia"/"bahasa melayu"/"malaysian" resolve to `ms`, and — separately — when a subtitle's base language code is already `ms`/`msa`/`may` but its label text actually says Indonesian, it gets reclassified to `id` instead of staying lumped in with Malay.

Confirmed unported: `shared/src/commonMain/kotlin/com/nuvio/app/features/player/PlayerSubtitleMatching.kt` still only has the plain ISO `"ind" → "id"` code mapping (line 61) with none of the new text-based disambiguation.

Confirmed live: `shared/.../player/PlayerTrackSelection.kt` is the only other consumer of `SubtitleLanguageMatching` in `shared/`, and it's an established tvOS audio/subtitle auto-selection code path (from the 2026-09-05/09-07 original-audio-language work).

**Port shape:** copy the `INDONESIAN_TAGS` list and the two new `containsAny(...)`/`haystack.contains(...)` branches verbatim into `shared/.../PlayerSubtitleMatching.kt` at the equivalent spots (the file structure otherwise matches upstream's pre-change state closely, so this should apply near-cleanly).

## Not applicable this run

Confirmed by reading the full diff, not just the commit title, for each:

- `24c08216` "match continue watching badge colors to tv" — mobile Compose UI catching up to tvOS's own existing badge colors; nothing to port.
- `73005d99` "reduce root tab switch stalls" + `f6d172ae` (its same-day revert) — a jelly-physics root-tab-switch perf change that was reverted in the same window, net no-op even for mobile; Compose-only navigation/animation code, no `shared/` footprint either way, tvOS's tab bar is wholly bespoke native SwiftUI.
- `33edb559` "keep android landscape lock during exit" — Android-only `MainAppContent.kt` orientation handling, no tvOS screen-orientation concept.
- `6761ebab` "add active profile toast and back button" + `51951059` "prevent selecting the active profile" — mobile profile-switcher UI fixes; touch composeApp Compose screens plus mobile's own `iosApp/iosApp/ContentView.swift` (the phone/tablet SwiftUI shell, not tvOS's `iosApp/NuvioTV/`). No `shared/` target. Logged as a LOW "check whether tvOS's own profile picker (`ProfilesViewModel.swift`) can select the already-active profile as a no-op vs. a bug" idea — not scheduled work, no user report.
- `998a9bfb` "hide addons with no streams" — mobile's `PlayerSourcesPanel.kt` Compose filter-chip row now hides addon groups with zero streams; no `shared/` target (`PlayerSourcesPanel` doesn't exist there). tvOS's `StreamPickerView.swift` is a bespoke SwiftUI panel — same LOW "worth a manual check for the identical empty-group display issue" status, not scheduled.
- `7012ffe5` "start playback without waiting for addon subtitles" — commit body: *"Match TV sidecar fast-start so prepare is not blocked by subtitle MIME probes or addon fetch."* Mobile is catching up to tvOS's own existing fast-start player design; nothing to port.
- `7a0e80b0` "open ios playback in fullscreen" — mobile/tablet trailer-popup fix (`TrailerPlayerPopup.kt` + mobile's `iosMain/.../PlayerPlatformEffects.ios.kt`); tvOS already has its own bespoke FEAT-32 Trailer Bridge (`TrailerBridge.swift`) built and shipped.
- `770c8ede` "Forward fullyWatchedSeriesKeys to PersonDetails, moreLikeThis & Collections" — pure Compose prop-threading: the shared `WatchedRepository.fullyWatchedSeriesKeys` flow already exists and was already wired into some mobile rows; this commit just threads the same already-existing value into more mobile UI (Person credits rows, Collections, More Like This). No `shared/` change at all. Confirmed `fullyWatchedSeriesKeys` has zero references anywhere in `iosApp/NuvioTV/` today — tvOS's Person/Collections/More-Like-This views don't show a "fully watched series" badge in these spots. Logged as a LOW opportunistic feature-parity idea (would tvOS want that badge there too?), a product call, not a port task.
- `03230c91` "Missing Polish Translations" — `values-pl/strings.xml` only, i18n, no logic change.
- Version bump `3d415441`, store publish `9bc77bc4`, and the 6 merge commits.

## Carried items from 2026-09-14

All four items carried from the 2026-09-14 run — the bundled-TMDB-key/credential-sync reconciliation (`60ee0160` + the paired `1854dfc3` `ProviderCredentialSync`/`ProfileSettingsSync` work), the season-poster `JsonNull` fix (`60e6a1b5`), and the pause-overlay on/off setting (`ecb69a88`) — were folded into today's `claude/rc13-batch` per CLAUDE.md's "Current open action items" list, which is already built (16 commits, tip `3449db86`) and blocked only on Christian supplying a `TMDB_API_KEY` before the batch can be gated open, Release-built, and cut as rc13. They are not carried forward as separate opens in this document.

## Suggested execution order

Items 2 and 3 are small, self-contained, mechanical ports — safe to batch together and land quickly. Item 1 needs actual design thought (how the fork's existing season-scan fix and upstream's new sibling-season fix should compose) before touching code; do it as its own pass with a test against a real multi-season anime IMDB id, not blind-copied.

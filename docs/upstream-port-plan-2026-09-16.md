# Upstream port plan — 2026-09-16

Daily scheduled check of `NuvioMedia/NuvioMobile` (`cmp-rewrite`) against this fork's `NuvioMobile` submodule (`tvos-shared-extraction`).

Upstream moved: `9bc77bc4` → `95347544` — 19 commits (13 real, 6 merges). Of the 13 real commits: 1 version bump (`db34bad9`), 1 store publish (`95347544`), 4 i18n-only (3 Vietnamese `strings.xml` commits + 1 "Add files via upload" that is also Vietnamese strings), leaving **6 commits with actual logic**, all read in full via `git show`, not just commit titles.

Submodule pointer check: the outer repo's committed pointer and `origin/tvos-shared-extraction`'s fetched tip both sit at `243da21b` (tag `tvos-v0.3.0-beta.18-rc12`) — no fork-sync drift. This sandbox's local submodule checkout is still on WIP branch `claude/rc13-batch` (tip `3449db86`, unchanged since yesterday) — the rc13 batch CLAUDE.md already records as built and blocked on Christian supplying a `TMDB_API_KEY`, unrelated to today's upstream drift.

## Action items

### 1. [MEDIUM, batch with the ProviderCredentialSync reconciliation] Personal TMDB API key override, syncable across devices

Commit: `df589078` "feat(tmdb): add personal API key override with credential sync"

Upstream adds an optional per-user TMDB API key that overrides the bundled `TmdbConfig.API_KEY`: `TmdbSettings.apiKey` (default `""`), `TmdbSettingsRepository.setApiKey()`/`effectiveApiKey()` (`apiKey.ifBlank { TmdbConfig.API_KEY }`), platform storage (`TmdbSettingsStorage.android.kt`/`.ios.kt`), a new Settings row (`TmdbSettingsPage.kt`), and — the part that matters most here — a new `ProviderCredentialIds.TMDB` entry wired into `ProviderCredentialSync.kt`'s `combine()`/`buildSnapshot()`/apply-incoming-credential logic, exactly the way `MDBLIST`'s single-`apiKey`-field credential is already handled, so a personal TMDB key set on one device syncs to the user's other devices/profiles.

**Why this is worth flagging now:** rc13 (`101e71f0`, built yesterday, not yet cut) removed the fork's own "enter your TMDB API key" flow entirely in favor of a bundled compile-time key (porting upstream's earlier `60ee0160`) — confirmed by reading the current `shared/.../tmdb/TmdbSettings.kt` (no `apiKey` field anymore) and `iosApp/NuvioTV/Screens/SettingsViewModel.swift` (no `apiKey`/`API Key` string left). Upstream has now partially walked that back: instead of *requiring* a key, it keeps the bundled key as the default and offers a personal key as an **optional override** — useful if the bundled key ever gets rate-limited across all users or revoked. That's a materially different, better design than either the fork's old required-key flow or a bundled-key-only setup with no escape hatch.

Confirmed unported: `shared/.../tmdb/TmdbSettings.kt` has no `apiKey` field, `TmdbSettingsRepository` has no `effectiveApiKey()`/`setApiKey()`, `ProviderCredentialIds` in `shared/.../core/sync/ProviderCredentialModels.kt` has no `TMDB` entry.

**Not a quick drop-in:** `shared/.../core/sync/ProviderCredentialSync.kt` is 668 lines (vs. upstream's much smaller file) — this is the file CLAUDE.md has repeatedly flagged as heavily diverged with fork-only `pendingScopes`/`shouldSeedProviderCredentials`/per-provider pending-edit-survives-a-pull guards (rc13's `458a6de2`, `27012045`). Adding the `TMDB` case needs to go through the fork's existing guard machinery, not upstream's simpler `combine()`/`buildSnapshot()`, or it'll silently skip the fork's own conflict-safety logic for this one provider.

**Port shape:** (1) restore `apiKey: String = ""` to `TmdbSettings` + `setApiKey()`/`effectiveApiKey()` to `TmdbSettingsRepository`, wire `TmdbService`'s bundled-key call sites to use `effectiveApiKey()` instead of `TmdbConfig.API_KEY` directly; (2) add `TMDB` to `ProviderCredentialIds` and thread `TmdbSettingsRepository` through the fork's `combine()`/`buildSnapshot()`/apply-credential/`ensureRepositoriesLoaded()` the same way `MDBLIST` is (single `PROVIDER_API_KEY_FIELD`, no client-id half); (3) add a small "Use my own TMDB API key" settings row on tvOS — a toggle + text field, not the old required-entry flow, in whichever pane replaced the removed TMDB Settings entry, plus the two new string resources. Do this alongside — not before — whatever session finishes the `1854dfc3` `ProviderCredentialSync` reconciliation, since that file is mid-repair.

### 2. [LOW/MEDIUM, mechanical] Addon episode runtimes silently dropped when supplied as a string

Commit: `48bf5ed3` "feat(details): parse addon episode runtimes"

`MetaDetailsParser.kt`'s per-episode video parsing read `runtime = video.int("runtime")` — if an addon returns the episode runtime as a string (`"45min"`, `"1:30"`, `"1 hr 30 min"`, etc., which the test suite shows is common), `.int()` returns `null` and the runtime is silently dropped. Upstream routes it through the existing `parseRuntimeMinutes()` helper (made `internal` and nullable-string-safe) that the top-level meta runtime already used, so episode runtimes now parse the same string formats.

Confirmed unported: `shared/.../details/MetaDetailsParser.kt` line 252 still has the pre-fix `video.int("runtime")`; `shared/.../details/RuntimeFormat.kt`'s `parseRuntimeMinutes` is still `private` and non-nullable.

Confirmed live: `EpisodesSection.swift` is a confirmed tvOS consumer of per-episode runtime — addons that report episode runtime as a string (rather than a raw integer) show no runtime badge on the episode row today.

**Port shape:** in `shared/.../RuntimeFormat.kt`, change `parseRuntimeMinutes` to `internal fun parseRuntimeMinutes(rawRuntime: String?): Int?` with the null/blank guard upstream added; in `MetaDetailsParser.kt`, change the episode-runtime line to `parseRuntimeMinutes((video["runtime"] as? JsonPrimitive)?.contentOrNull)`; port `MetaDetailsParserTest.kt`'s two new test cases (valid string formats, invalid/missing values keep `runtime = null`). Three-file, mechanical.

### 3. [MEDIUM, mechanical shared-side / needs Swift call-site wiring] IMDB id fallback from addon meta response for non-IMDB content

Commit: `90054b7b` "fix: use addon imdb_id as fallback for non-IMDB content enrichment"

Addons whose own id scheme isn't `tt...` (e.g. a Trakt-, TMDB-, or addon-native-id-keyed catalog) but whose meta response includes a separate `imdb_id` field were getting **no** TMDB enrichment, MDBList ratings, IMDb episode ratings, or parental-guide lookup, because every one of those services only ever tried to extract an IMDB id out of the *content id itself*. Upstream adds `MetaDetails.imdbId` (parsed from `meta.string("imdb_id")`) and threads it as a fallback into: `TmdbService.ensureTmdbId(videoId, mediaType, fallbackImdbId)`, `TmdbMetadataService`'s two call sites, `MdbListMetadataService.canEnrich()`/`enrichMeta()`, and (composeApp-only) the player's skip-intro-adjacent IMDb-episode-ratings fetch and parental-guide resolution.

Confirmed unported in `shared/`: `MetaDetailsModels.kt` (no `imdbId` field), `MetaDetailsParser.kt` (no `imdb_id` parse), `TmdbService.kt`'s `ensureTmdbId` (no `fallbackImdbId` param), `TmdbMetadataService.kt` (doesn't pass one), `MdbListMetadataService.kt` (`extractImdbId(meta.imdbId)` fallback missing from both `canEnrich`/`enrichMeta`).

**Confirmed live and currently broken on tvOS:** `DetailViewModel.swift` has the exact same "extract IMDB id from `meta.id` or the outer content id, else give up" pattern at two call sites — episode-ratings fetch (lines ~368–372, via `ParentalGuideRepositoryKt.extractParentalGuideImdbId`) and parental-guide fetch (lines ~395–401) — with no fallback to a `meta.imdbId` field, because that field doesn't exist in shared `MetaDetails` yet. Once it's added, both Swift call sites need the same `?? meta.imdbId` fallback upstream added on the Kotlin side.

Not applicable: `PlayerScreenRuntimeEffects.kt`/`PlayerScreenRuntimePlaybackActions.kt` halves of this commit are composeApp Compose-player-runtime files with no `shared/` extraction — tvOS's native player skip-intro path already goes through `SkipIntroRepository`/`SimklIdResolver`, a different (and already-tracked, see the carried item below) resolution chain that doesn't touch this bug.

**Port shape:** add `imdbId: String? = null` to shared `MetaDetails` + parse `meta.string("imdb_id")` in `MetaDetailsParser.kt`; add `fallbackImdbId: String? = null` param to `TmdbService.ensureTmdbId()` with the normalize-and-retry logic upstream added; pass `meta.imdbId` at both `TmdbMetadataService.kt` call sites; add the `extractImdbId(meta.imdbId)` fallback to both `MdbListMetadataService` methods; port `MetaDetailsParserTest.kt`'s new case if present. Then in `DetailViewModel.swift`, add `?? meta.imdbId` (guarded to `tt`-prefixed) as a third fallback at both the episode-ratings and parental-guide imdb-id resolution sites.

## Not applicable this run

Confirmed by reading the full diff, not just the commit title:

- `12111fd8` "feat(updater): add stable and beta update channels" — a full self-update mechanism (GitHub-release polling, APK download+install, stable/beta channel picker) entirely under `composeApp/src/android{Full,Playstore}Main`, `androidApp/`, `desktopMain`, `iosMain` (mobile). No `shared/` extraction exists or would make sense — `grep -rl "AppUpdater\|UpdateChannel" iosApp/NuvioTV/` is empty. tvOS distributes via TestFlight/App Store, which has no in-app self-update concept; nothing to port.
- `3312374e` "fix(settings): keep page content visible during navigation" — Compose-only tab-host state-preservation fix (`AppShellComponents.kt`/`SettingsScreen.kt`, a `isSelectedTab` flag replacing `screenActive` in a `SaveableStateProvider` gate) for mobile/desktop's Compose settings navigation stack. tvOS's Settings was rebuilt onto native SwiftUI `List`/`Toggle`/`Menu{Picker}` back on 2026-08-27; no Compose navigation stack to have this bug.
- `8ac70e59` "Make anime id preference only for content with anime ids" — a bugfix **on top of** upstream's own `8aad52d8` "Add TVDB as Simkl Anime ID resolution" (the carried item #2 from the 2026-09-15 run, still open below): it guards the anime-id-preference branch in `canonicalContentId()` so it only fires when the entry actually has `mal`/`kitsu`/`anidb` ids, instead of letting a non-anime item with, say, a `tvdb` id get misrouted into the anime chain whenever the user's preference is set to `TVDB`. Confirmed the fork's current `shared/.../SimklProjections.kt` doesn't have the TVDB branch at all yet (re-verified directly, not assumed from CLAUDE.md's rc13 summary — the TVDB item was **not** part of the rc13 batch's commit list), so there's nothing to patch today. **Action:** when the carried TVDB item is finally ported, port upstream's current end-state (`8aad52d8` + this `hasAnimeIds` guard combined), not the original buggy version — noted on the carried item below so it isn't missed.
- 3 Vietnamese `strings.xml` commits (`278b48aa`, `75c415e7`, `dd6a27c1`) + `a50f29b5` "Add files via upload" (also Vietnamese strings) — i18n only, no logic change.
- Version bump `db34bad9`, store publish `95347544`, and the 6 merge commits.

## Carried items (still open, re-verified this run)

All three items from the 2026-09-15 run remain unported — re-checked by reading current `shared/` file contents, not trusted from the prior note:

1. **[MEDIUM, not mechanical]** Anime skip-intro sibling-season Simkl resolution + episode remap (`aa748fa8`) — needs reconciliation with the fork's own `resolveIds(source, id, season)` scan-based fix, not a blind copy. Full shape in `docs/upstream-port-plan-2026-09-15.md`.
2. **[MEDIUM, mechanical]** TVDB as a Simkl anime-ID preference option (`8aad52d8`) — confirmed still absent from `shared/.../SimklAnimeIdPreference.kt` (still only `IMDB, MAL, KITSU`) and `SimklProjections.kt` (`canonicalContentId(preference)` has no `TVDB` branch). **Updated port note:** also fold in today's `8ac70e59` `hasAnimeIds` guard so the ported version doesn't reintroduce upstream's now-fixed bug.
3. **[LOW, mechanical]** Indonesian/Malay subtitle-language disambiguation (`d95b4f9b`) — confirmed still absent from `shared/.../PlayerSubtitleMatching.kt` (still only the plain `"ind" → "id"` ISO mapping).

## Suggested execution order

Items 2 and 3 from today (episode runtime string parsing, imdb_id fallback) are small and self-contained — safe to batch together. Item 1 (personal TMDB key) touches the fragile `ProviderCredentialSync.kt` and should wait for whatever session next does deliberate work on that file rather than being bolted on standalone. The carried TVDB item (#2 above) should pick up today's `8ac70e59` fix as part of the same port, not as a follow-up.

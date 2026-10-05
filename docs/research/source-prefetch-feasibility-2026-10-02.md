# Source pre-fetching on tvOS: feasibility (2026-10-02)

Question from Christian: can NuvioTV resolve playback sources ahead of the Play press, the way some Android TV apps do, so movies and episodes start faster?

Short answer: yes, and in three distinct sizes. The small one is a port of a change upstream merged this morning. The medium one resurrects a design upstream built in May and deleted in June. The large one (resolving sources while the user browses Home) is what one Android fork does, and it is the only one that carries real debrid-account risk.

## 1. Where the time goes today (fork, `tvos-shared-extraction` @ `f2827b7b`)

Nothing is fetched until the stream picker opens. `StreamPickerView.onAppear` calls `StreamsViewModel.start`, which calls the shared `StreamsRepository.load(...)` (`shared/.../streams/StreamsRepository.kt:82-719`). One call does, in order:

1. Settings snapshot (player, debrid, badges, auto-play mode, persisted binge group).
2. Embedded streams short-circuit (addon meta that already carries streams).
3. Addon matching by id prefix, then the BUG-74 `tmdb:` → IMDB remap: a serial `TmdbService.tmdbToImdb` round-trip **before any addon is asked** (`:233-282`).
4. One coroutine per addon, no concurrency cap, Ktor Darwin client with 60 s request/connect/socket timeouts and no other per-addon timeout (`AddonPlatform.apple.kt:78-84`).
5. One coroutine per JS plugin scraper, `Semaphore(10)`, 60 s timeout; each scraper first does `TmdbService.ensureTmdbId`.
6. Per addon, after its response: the debrid cache check (`LocalDebridAvailabilityService.annotateCachedAvailability`). Only TorBox and Premiumize support it. Real-Debrid and AllDebrid have no cache check (RD removed `instantAvailability` in Nov 2024), so their status is unknown until resolve.
7. Presentation (sort, filters, caps), auto-play candidate evaluation.
8. `DirectDebridStreamPreparer.prepare` resolves the top N debrid candidates to real URLs **but N = `instantPlaybackPreparationLimit`, default 0, and tvOS has no Settings row for it**, so on tvOS this step is a no-op unless the phone synced a value over (`DebridSettingsStorage.apple.kt:212,238`).

Then on the actual Play press (`StreamsViewModel.internalPlay`, `:734-788`): a direct URL plays immediately; a debrid stream goes through `DirectDebridPlaybackResolver.resolveToPlayableStreamChecked`. For Real-Debrid that is addMagnet → torrentInfo → selectFiles → torrentInfo → unrestrict, about five sequential calls (`DebridProviderApis.kt:205-270`); TorBox is createTorrent → getTorrent → requestDownloadLink.

So a cold press costs: TMDB remap + slowest addon/scraper you wait for (bounded by the auto-play timeout, 3 s default, or the user's manual pick) + the debrid resolve chain. The Orivio-batch device pass measured "first pick playing in ≤4 s" with Auto-Play Best Source on, which is the floor you can reach without prefetching.

Caches that already exist and could be filled ahead of time:

| Cache | Scope | TTL | Who reads it |
|---|---|---|---|
| `DirectDebridPlaybackResolver.resolvedCache` (`DirectDebridResolver.kt:26-86`) | resolved debrid URL, keyed provider + key fingerprint + hash + fileIdx + S/E | 15 min in memory | every Swift resolve call, the preparer |
| `StreamsRepository` request-key dedup (`:98-105`) | the live request only | until the next `load()` or `clear()` | the picker |
| `PlayerStreamsRepository.episodeStreamsState` | next-episode search during playback | until `clearEpisodeStreams()` | `NextEpisodeEngine` |
| `RejectedStreamLinks` (Swift, UserDefaults) | links that failed | 8 h | first-play auto-play, up-next, picker rows |
| `StreamLinkCacheRepository` ("reuse last link") | last chosen URL per title | 24 h | **mobile only, no tvOS reader** |

There is **no stream-list cache** on tvOS. `StreamPickerView.onDisappear` calls `StreamsRepository.clear()`, so backing out of the picker and pressing Play again refetches everything.

The next-episode engine (`NextEpisodeAutoPlay.swift`) already does a late prefetch: `onProgress` starts `beginSearch()` only in the last 3 % (percentage mode is clamped to ≥ 97 %) or last 3.5 min, and `play()` resolves debrid only after the 3-2-1 countdown. That is the piece upstream just moved earlier.

## 2. Prior art

### Upstream Nuvio (the thing to port first)

- **Merged 2026-10-02 04:12 UTC, verified via `gh pr view`:** NuvioMedia/NuvioMobile [#2140](https://github.com/NuvioMedia/NuvioMobile/pull/2140) "Preload next episode sources" (commit `22c9ab20`, merge `63af0499`, author skoruppa), mirror of NuvioTV [#3795](https://github.com/NuvioMedia/NuvioTV/pull/3795) on Android TV. Upstream `cmp-rewrite` is now `d667f432` → `63af0499`; tomorrow's daily check will list it. What it does:
  - New player setting `preloadNextEpisodeSources`, "Preload Next Episode Sources" under Playback → Auto Play, **off by default**.
  - Trigger: while an episode plays, once `position + streamAutoPlayTimeoutSeconds` would cross the next-episode-card threshold, call `PlayerStreamsRepository.loadEpisodeStreams(nextEp)` silently. Lead time = the auto-play timeout setting, so with the 3 s default it only wins ~3 s; with a 30 s timeout it wins 30 s. Addon `/stream` lists only; **no debrid pre-resolve**.
  - `cancelEpisodeStreamsJob` no longer wipes the request key and results when playback starts, so the preloaded hit survives into the next episode's player. Cancelled on player dispose.
  - Side fix: the bounded auto-play timeout used to `delay(timeoutMs)` even when streams were already cached; now `withTimeoutOrNull` on the settle signal, so cached results resolve instantly.
  - Diff is 128 insertions across `PlayerNextEpisodeAutoPlay.kt`, `PlayerStreamsRepository.kt` (+25/-?), `PlayerSettingsRepository.kt` (+13), storage actuals, the Compose settings page, strings.
- **Deleted prior art, May–June 2026:** upstream had `AddonStreamWarmupRepository` (318 lines, `git show 485e4e81^:composeApp/.../streams/AddonStreamWarmupRepository.kt`) called from `MetaDetailsScreen` on Detail open for the movie or the continue/next episode. In-memory cache + in-flight dedupe, 5 min TTL, key = type + videoId + S/E + addon-set fingerprint + debrid-settings fingerprint; ran the addon fetch, cache check, presentation and the debrid preparer; `StreamsRepository`/`PlayerStreamsRepository` seeded from `cachedGroups(...)` and only fetched the addons still pending. Gated on `canResolvePlayableLinks && torboxApiKey.isNotBlank()`, so in practice a TorBox-only feature; plugins excluded. Removed in `1b6d4fde` "Stop prefetching streams on meta screen" (06-13) and `485e4e81` "Remove stream warmup dead code" (06-14), **no reason given in either commit**, no linked issue or PR. The fork's merge-base with upstream (`94b88483`, 07-19) is after the removal, so the fork never had it. The debrid-settings warning string from that era survives: "links are prepared ahead of time and can count toward rate limits even if you do not press Watch" (`DebridSettingsPage.kt:634`).

### Other apps

- **peden88/NuvioTV** (Android NuvioTV fork, README verified): "streams are found, ranked and resolved while you're still browsing, and the content-server connection is warmed to the right node ahead of time", claims ~6.4 s → ~2 s on a prepared press, plus a test build with "outro-aware next-episode stream prefetch". This is the browse-time prefetch + debrid pre-resolve + TCP prewarm combination, i.e. the full Tier 3 below. No TTL, budget or debrid caveats documented.
- **AIOStreams** (addon side): "Precache Next Episode" fetches the next episode's streams and pings the chosen debrid URLs (default selector: only when nothing is cached), max 2 pings, optional failover. Server-side, so it needs that addon.
- **Syncler**: advertises "Next episode pre-search". No technical detail.
- **Stremio**: no prefetch; open requests stremio-core #949 / #913. Stremio Android fires 1 HEAD + 10 GETs per play, which caused debrid 429s, and the AIOStreams author added a lock + success cache in response (stremio-bugs #2091). A cautionary example of what over-eager resolving does to debrid accounts.
- **TheRedWizard** (Kodi): pre-scrapes, pre-resolves the top source 20–60 s before the end, holds it with a 3 h TTL, and documents the same three risks: link expiry if resolved too early, debrid rate limits, wasted resolves.
- **Weyd**: no prefetch/pre-scrape option found in its settings lists or changelogs (not confirmed either way).

Every shipped implementation except peden88's limits the scope to the **next episode during playback**, with a short lead time, cancelled on player exit, off by default.

## 3. Constraints that shape the design

- **Debrid link lifetimes:** TorBox download links are valid 3 h (official); Real-Debrid says a generated link stays valid 30 days with no uptime guarantee; AllDebrid and Premiumize undocumented. The resolver cache's 15 min TTL is safely inside all of them. A pre-resolved link held across a long gap (Home focus → play an hour later) is a TorBox risk only.
- **Debrid rate limits:** RD 250 req/min and refused requests *count toward the limit*; RD's FAQ and a 2020 RD tweet say apps that "auto-resolve" every link get blocked. AllDebrid 12 req/s, 600/min. TorBox 300/min per key and **60/h for uncached `createtorrent`**; 429 plus `ACTIVE_LIMIT`/`COOLDOWN_LIMIT` codes. The fork's only guard is the preparer's background budget (6/min, 30/h), which exists for exactly this reason and must gate any pre-resolve.
- **RD side effect:** each RD resolve adds a torrent to the account (deleted on failure). Pre-resolving titles the user never plays leaves torrents behind and is what RD's "auto-resolve" complaint is about.
- **Addon rate limits:** Torrentio has no client limit in source but caches stream responses 2 h in memory / 3 d on disk; Comet and MediaFusion public instances apply undocumented "reasonable" limits with 429. Stream lists are therefore cheap to re-request within hours; pre-resolving is the expensive half.
- **Fork plumbing facts:** `StreamsRepository` is a single-slot singleton (one `activeJob`, one key); a prefetch that calls `load()` for a different title would cancel or clobber the live request, and `clear()` on picker close wipes it. So a Detail-page prefetch needs its own cache object (what the deleted warmup repository was) that `load()` seeds from, not a second `load()` call. `PlayerStreamsRepository` has two slots (sources, episode streams) and the fork's shared copy lacks upstream's `pauseSearchForPlayback`/`cancelEpisodeStreamsJob` pair entirely, so the #2140 Kotlin hunk does not apply verbatim.
- **Plugin scrapers:** run under a 10-wide semaphore with 60 s timeouts and do their own TMDB lookup. Including them in a Detail-open prefetch multiplies the cost per Detail visit; the deleted warmup excluded them.

## 4. Options

### Tier 1 — next-episode preload during playback (port upstream #2140). Small.

On tvOS this is mostly Swift. `NextEpisodeEngine.beginSearch()` already loads streams into `PlayerStreamsRepository.episodeStreamsState` and `handleStreams` picks; the change is to split "load" from "show the card":

1. Add `preloadNextEpisodeSources` to the shared `PlayerSettingsRepository`/`PlayerSettingsStorage` (port the Kotlin hunks verbatim: UI state field, setter, reset, load, publish, apple + android storage actuals). Add the toggle to `PlaybackSettingsPane.swift` under the Auto Play block, off by default, and to the namespaced settings blob so the phone never sees it (same pattern as the Orivio batch).
2. In `NextEpisodeEngine.onProgress`, when the toggle is on and `position + streamAutoPlayTimeoutSeconds` crosses the threshold (same clamps, same post-credits hold), call `loadEpisodeStreams` + the subtitle prefetch **without** setting `phase = .searching`. Keep `triggered` for the card; add a `preloaded` flag.
3. At the real threshold, `beginSearch()` runs as today; the repo's request-key dedup (`PlayerStreamsRepository.kt:157-158`) returns the already-populated state, and the first `episodeStreamsState` emission selects immediately. Two things wipe that slot today and need care: the in-player source list (`loadSources()`, `NextEpisodeAutoPlay.swift:172`) shares `episodeStreamsState` and calls `clearEpisodeStreams()` when the user opens it, so a preload must be re-issued (or the list must use the other slot) after that; and the engine's teardown (`:282`) clears it too, which is correct on exit but must not run between the preload and the new player's start.
4. Consider also porting the side fix: the 3-2-1 countdown already runs after selection on tvOS, so the "waited the full timeout with cached results" bug may not exist here. Check `timeoutTask` in `beginSearch` before assuming.
5. Optional: lead time larger than the auto-play timeout. Upstream chose the timeout to avoid a new setting; tvOS could use a fixed 30 s minimum, since a 3 s lead saves almost nothing. Product call.

Effort: a day including tests and a device pass (watch for the card not appearing early, the preloaded streams surviving into the new player, cancellation on Menu exit). Zero debrid risk (stream lists only, one title, one fetch per episode).

### Tier 1b — turn on the debrid preparer on tvOS. Trivial.

`instantPlaybackPreparationLimit` (0–5) already exists in shared code with the 6/min / 30/h budget and feeds the 15 min resolver cache; the picker's `internalPlay` and `FirstPlayAutoPlayController` already read that cache. A tvOS Settings row (Account Services → debrid section, "Prepare top N links for instant playback", default 0) makes the Play press on a debrid stream skip the 3–5-call resolve chain whenever the picker has been open for a few seconds. It only fires after the stream list has loaded, so it does not help the auto-play-best-source path (which resolves the first candidate itself) but it does help manual picks and the "browse the list, then pick" flow. Correction (verified 2026-10-02 in `SyncPlatform.kt:17` / `TvOsProviderInstaller.kt:140-141`): tvOS syncs its player and debrid blobs under its own `tvos` namespace and never reads the phone's, so a phone-set limit does NOT reach tvOS; the limit is always 0 here until a tvOS row exists.

### Tier 2 — Detail-page stream-list warmup. Medium.

Resurrect `AddonStreamWarmupRepository` into `shared/` as a side cache, triggered from `DetailView.onAppear` once `model.meta` (movie) or `model.seriesAction` (series: the continue/next episode, already computed at `DetailViewModel.swift:520`) is available, and seed `StreamsRepository.load()` and `PlayerStreamsRepository` from it.

- Keep upstream's key (type + videoId + S/E + addon fingerprint + debrid-settings fingerprint), the 5 min TTL and the in-flight dedupe. Drop the TorBox-only gate; the fork wants it for every setup.
- Debounce: start ~1–2 s after Detail appears, cancel on `onDisappear` if the fetch has not finished (or let it finish and cache; it is one request per addon either way).
- Include addons only; make plugin scrapers a second toggle or exclude them (cost and the 10-wide semaphore).
- Run the debrid cache check and presentation so the seeded groups are picker-ready; **do not** pre-resolve here unless Tier 1b's limit is set, and then only through the existing budget.
- Feed `FirstPlayAutoPlayController`: it requires a `requestToken` with `manualSelection=false` and reads `autoPlayStream`/`autoPlayCandidates` from `StreamsUiState`, so the seed must go through `StreamsRepository.load()`'s normal evaluation path, not bypass it. The deleted code's `cachedGroups` merge point in `load()` is the right spot.
- Why upstream deleted it is unknown. Plausible reasons: it was TorBox-only, it fired on every Detail open for every addon (people open a lot of Detail pages they never play), and the preparer half counted against debrid limits for titles never watched. A tvOS version that caches lists only and resolves nothing avoids the last one.

Expected win: the addon fan-out (typically 1–5 s, worst case the slowest addon) disappears from the Play press for any title whose Detail page was open ≥ a few seconds. Combined with Tier 1b the press is "cache hit + resolved link", which is the peden88 number.

Effort: 2–3 days (shared repository + tests, two seed points, Swift trigger, Settings toggle, device pass). Cost: one extra addon fan-out per Detail visit. Addon-side risk is low (Torrentio caches), but a user with 15 addons browsing quickly multiplies requests; cap in-flight warmups to one and skip when the previous warmup for the same key is still fresh.

### Tier 3 — browse-time prefetch on Home / card focus, with debrid pre-resolve. Large, not recommended as a first step.

The hooks exist: `ContinueWatchingRow.onItemFocusChange` hands over a `WatchProgressEntry` with type, parent id, videoId, S/E (everything the picker gets), and `HomeHeroFocusModel.reportFocus` already debounces focus at 0.2 s / 0.3 s. Catalog rows only give a `MetaPreview` (id + type), so a series needs a meta fetch first to know which episode. Problems:

- Fan-out per focus change: a user scrubbing a row of 20 titles would issue 20 × N addon requests plus scrapers within seconds. Needs a long debounce (≥ 1.5 s), a single in-flight slot, and probably Continue Watching only (where the episode is known and the intent to play is high).
- Pre-resolving debrid links while browsing is what RD explicitly blocks accounts for, and TorBox's 60/h uncached-add limit is reachable in one browsing session. If done at all: only cached/instant streams, only the single top candidate, only through the 30/h budget, and only when Auto-Play Best Source is on (otherwise there is no "top candidate" to resolve).
- TCP/TLS prewarm to the CDN (peden88's "warmed to the right node") is a separate small win with no account risk: a HEAD to the resolved URL once it exists. Only meaningful after a pre-resolve.

## 5. Recommendation

Build Tier 1 and Tier 1b together as one small batch, ideally with tomorrow's upstream port of #2140 (it is the same change). Both are off by default, both reuse existing caches, neither adds debrid-account risk beyond what the existing budget allows. Then measure on the Living Room ATV: the next-episode transition should drop to the countdown alone, and a debrid pick from an open picker should start in under a second.

Decide on Tier 2 after that, with the warmup confined to stream lists (no resolve) and a Settings toggle. It is the change that makes the **first** play of a title faster, which is what "pre-fetching sources" means to most users, and the deleted upstream code is a working blueprint including the merge points. Skip Tier 3's browse-time resolving; a Continue Watching-only list warmup could be added later as a Tier 2 extension if the Detail-page version proves out.

Open calls for Christian:

1. Lead time for the next-episode preload: upstream's "auto-play timeout" (3 s default, near-useless) or a fixed minimum like 30 s.
2. Whether Tier 2 includes plugin scrapers.
3. Where the preparer limit row lives on tvOS (Account Services debrid section vs Playback → Auto Play).

## Sources

- NuvioMobile #2140: https://github.com/NuvioMedia/NuvioMobile/pull/2140 (merged 2026-10-02T04:12:12Z, `63af0499`)
- NuvioTV #3795: https://github.com/NuvioMedia/NuvioTV/pull/3795 (merged 2026-10-02T04:12:35Z); motivating issue #3777; related PR #3313
- Deleted warmup: `git show 485e4e81^:composeApp/src/commonMain/kotlin/com/nuvio/app/features/streams/AddonStreamWarmupRepository.kt`; removal `1b6d4fde`, `485e4e81`
- peden88/NuvioTV README (lines 165-172): https://github.com/peden88/NuvioTV
- AIOStreams precache: https://github.com/Viren070/AIOStreams/pull/1038
- Stremio requests: https://github.com/Stremio/stremio-core/issues/949, /913; debrid 429s https://github.com/Stremio/stremio-bugs/issues/2091
- TheRedWizard pre-resolve: https://github.com/Purple-Drain/TheRedWizard/issues/1, /247
- Real-Debrid API limits: https://api.real-debrid.com/ ; auto-resolve warning https://github.com/debridmediamanager/awesome-debrid/discussions/7
- AllDebrid limits: https://docs.alldebrid.com/
- TorBox link validity + limits: https://support.torbox.app/en/articles/15315517-why-are-my-download-links-not-working , https://support.torbox.app/en/articles/13726368-api-rate-limits
- Torrentio cache TTLs: https://github.com/TheBeastLT/torrentio-scraper/blob/master/addon/lib/cache.js
- Comet env: https://github.com/g0ldyy/comet/blob/main/.env-sample

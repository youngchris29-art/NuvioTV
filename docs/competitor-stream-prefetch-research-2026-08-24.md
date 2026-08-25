# Competitor research — addon stream prefetching / "instant play"

**Date:** 2026-08-24 · **Scope:** which competing addon-based clients (and addons) pre-fetch or pre-warm
stream links so playback starts faster, and exactly how they implement it.
**Method:** source code read where the project is open source (cloned/raw-fetched and grepped), public
docs/changelogs where it isn't. Every constant quoted below was read out of the code, not from a blog post.

---

## 0. TL;DR

| Project | Layer | Has real prefetch? | Mechanism |
|---|---|---|---|
| **AIOStreams** (Viren070) | addon/server | **Yes — two separate features** | `Preload Streams` pings the top-N results of the *current* item; `Pre-cache Next Episode` fetches next-ep streams in the background and pings them to trigger debrid-side caching |
| **CloudStream** (recloudstream) | Android client | **Yes** | `preLoadNextLinks()` fires at **80 %** of playback into a per-episode link cache (20 min TTL) |
| **Seren** (Kodi) | client | **Yes** | `smartPlay.pre_scrape()` re-runs the whole source scrape for the next playlist item at `max(20 % of runtime, 600 s)` remaining, silently; plus auto "cache assist" that starts a debrid download of the best uncached torrent |
| **Fen Light / Umbrella** (Kodi) | client | **Yes** (same family) | per-provider `autoplay_prescrape`, `autoscrape_nextep`, "Autoplay Cloud Result after a prescrape" |
| **Harbor** (Stremio desktop client, 1.5k★) | client | **No true prefetch — but the best "feels instant" stack** | picker result cache + progressive partial results + early auto-fire + `Range: bytes=0-1` preflight probe + persistent dead-stream blacklist |
| **Stremio official** | client | **No** | zero `prefetch`/`preload` hits in `stremio-core`; only `binge_watching` + `StreamsBucket` (re-uses the *selection*, still fetches at play time) |
| **AutoStream** (addon) | addon | Partial | returns a single pre-picked stream (kills the picker round-trip); claims "episode pre-loading" |
| **Vidi / Fusion / Weyd / Syncler** | clients | **Unverified** | closed source; nothing in their public docs describes prefetching. Fusion (tvOS 26+, iOS/macOS) is our closest product competitor and its docs site is marketing-only |

The single most transferable finding: **the ecosystem's prefetch is a "ping", not a download.** An HTTP request to
the addon's stream URL with `redirect: manual`, body immediately cancelled. That one request is what forces the
addon → debrid chain to do its slow work (resolve/unrestrict, and for uncached torrents, *start caching*) ahead of
the user's click.

---

## 1. Where the latency actually is

Prefetching only helps if it targets the right stage. In a Stremio-addon client, pressing Play costs:

1. **Addon `/stream/{type}/{id}.json` fan-out** — N addons in parallel, each 0.5–6 s (scrape + debrid cached-check).
2. **Link resolution** — the addon's returned URL is usually a *redirect stub* on the addon host; hitting it makes
   the addon call the debrid API (`/unrestrict/link`, or add-magnet + select-file). 300–2000 ms, sometimes much
   worse if the torrent isn't cached.
3. **Origin warm-up** — the debrid CDN has to have the file ready; first byte on a cold file can be seconds, and
   for an *uncached* torrent it's minutes.
4. **Player start-up** — connection/TLS, container probe, first buffer fill.

Stage 1 is what "prefetch the stream list" fixes. **Stages 2–3 are what the ping trick fixes**, and they're the
ones the competitors invest in most, because since **Real-Debrid disabled `/torrents/instantAvailability`
(announced Nov 2024, now returns `disabled_endpoint`)** clients can no longer cheaply *ask* whether a torrent is
cached — they have to either probe it or warm it. Both patterns below descend from that.

---

## 2. AIOStreams — the reference implementation (addon side)

Open source, TypeScript. Two independent features, both in `packages/core/src/main/resources.ts`, both configured
per-user in the addon's config UI under **Background Optimization**.

### 2a. `Preload Streams`

UI copy: *"Automatically sends HTTP requests to selected streams so they start processing before you click — runs
asynchronously without delaying results."*

Flow, fired at the end of serving a normal `/stream` response (`preCaching === false`):

- Cooldown key `preload-{type}-{id}-{userScopeKey}` in a shared `precacheCache`; default **`PRELOAD_MIN_INTERVAL`
  = 3600 s** per item per user (0 disables).
- Picks which results to warm with a user-editable expression, `DEFAULT_PRELOAD_SELECTOR = 'slice(streams, 0, 2)'`
  — i.e. the top 2. `preloadStreams.singleStream !== false` (default on) trims that to 1.
- Hard cap `maxBackgroundPings`; concurrency `PRELOAD_STREAMS_CONCURRENCY = 5` via `pLimit`.
- Marks the chosen streams so the formatter can label them in the stream list.
- Fires `pingStreamUrls()` **without awaiting it** in the response path.

### 2b. `Pre-cache Next Episode`

UI copy: *"Fetches the next episode's streams in the background and pings the URLs selected by the precache
selector, triggering server-side caching before you click."*

```ts
if (ctx.userData.precacheNextEpisode && !preCaching) {
  const cacheKey = `precache-${type}-${id}-${userScopeKey(ctx.userData)}`;
  if (!(await precacheCache.get(cacheKey, false)))
    setImmediate(() => { precacheNextEpisode(ctx, context).catch(...) });   // never blocks the response
}
```

`precacheNextEpisode()`:

1. Derives the next `S/E` from the parsed id + metadata (`getNextEpisode`).
2. **Clones and mutates the user config for the background run**: `excludeUncached = false`, `groups = undefined`,
   `dynamicAddonFetching.enabled = false` — deliberately letting *uncached* torrents through, because the whole
   point is to make the debrid start downloading one. Restores the original config right after.
3. Re-enters its own `getStreams(ctx, precacheId, type, /* preCaching */ true)` — the same pipeline, flagged so it
   can't recurse into another precache.
4. Selects with `DEFAULT_PRECACHE_SELECTOR = 'count(cached(streams)) == 0 ? uncached(streams) : []'` —
   **only do work when nothing is already cached**; if something's cached, the next episode is already instant.
5. Writes the cooldown *before* pinging (`PRECACHE_NEXT_EPISODE_MIN_INTERVAL`, default **86 400 s / 24 h**) so a
   retry storm can't form, then `await pingStreamUrls(streamsToCache)`.
6. v2.31 added **failover during pre-caching** (`failover.precacheFailover`) so "the next episode is pre-warmed
   against a result that actually works" rather than against a dead first pick.

### 2c. The ping itself

```ts
async function pingStream(stream, timeoutMs = PING_TIMEOUT_MS) {
  const wrapper = new Wrapper(stream.addon);
  return wrapper.makeRequest(stream.url, { timeout: timeoutMs, rawOptions: { redirect: 'manual' } });
}
// caller: response.body?.cancel()   ← never reads a byte
```

`redirect: 'manual'` is the whole trick: you make the addon do its resolve work and hand you a `302`, and you stop
there. No bandwidth, no debrid "download" accounting, and the resolved link is now hot in the addon's cache.

---

## 3. CloudStream — client-side next-episode preload (closest analogue for us)

Kotlin/Android, `app/src/main/java/com/lagradost/cloudstream3/ui/player/`.

```kotlin
const val PRELOAD_NEXT_EPISODE_PERCENTAGE = 80          // AbstractPlayerFragment.kt
if (percentage >= PRELOAD_NEXT_EPISODE_PERCENTAGE) viewModel.preLoadNextLinks()   // GeneratorPlayer.kt
```

`PlayerGeneratorViewModel.preLoadNextLinks()`:

- Guards against duplicate work with `currentLoadingEpisodeId` (the episode id already loading → return).
- Cancels the previous job, then `generator.generateLinks(sourceTypes = LOADTYPE_INAPP, clearCache = false,
  isCasting = false, callback = {}, subtitleCallback = {}, offset = episodeIndex + 1)` — **the same generator call
  the real playback path uses, just with `offset + 1` and no-op callbacks.** Results land in the cache, not the UI.
- Requires `generator.hasCache && generator.hasNext(episodeIndex)`.

`RepoLinkGenerator` is where it pays off:

- `HashMap<Pair<String /*apiName*/, Int /*episode id*/>, Cache>`, `Cache(linkCache, subtitleCache, saturated,
  lastCachedTimestamp)`.
- **20-minute TTL** (`unixTime - lastCachedTimestamp > 60 * 20` → wipe).
- A `saturated` flag: when every provider has finished for that episode, a later `generateLinks` for it replays the
  cached links and *stops all execution* instead of re-scraping.

Design lesson: one code path, parameterised by episode offset + silent callbacks, feeding a keyed cache. No parallel
"prefetch implementation" to keep in sync with the real one.

## 4. Seren (Kodi) — the oldest and most aggressive version

`resources/lib/modules/player.py` + `smartPlay.py` + `getSources.py`.

- Trigger: `self.min_time_before_scrape = max(self.total_time * 0.2, 600)` → **the later of "20 % of the runtime
  remaining" and "10 minutes remaining"**; fires once per playback (`pre_scrape_initiated`).
- `smartPlay.pre_scrape()` takes the *next playlist item's* plugin URL and rewrites the action:
  `url.replace("getSources", "preScrape")`, sets a runtime flag `tempSilent`, and `RunPlugin(...)`s it.
- `getSources._handle_pre_scrape_modifiers()` detects `action == "preScrape"` and: forces `silent = True` (no
  dialogs), **disables pre-emptive termination** (normally Seren stops scraping early once it has a good enough
  source — during a prescrape you want everything), and sets the provider timeout to its maximum. Results are
  written to the local torrent/source cache, so the later real `getSources` is a cache read.
- Separately, `general.autocache` + `_get_best_torrent_to_cache()` picks the best-quality, most-seeded
  show/season/single package and `RunPlugin(action=cacheAssist)` — **starting a debrid download of an uncached
  torrent in the background.** This is the ancestor of AIOStreams' precache selector.

**Fen Light** (`plugin.video.fenlight`) carries the same ideas with different names: `prescrape_sources` threaded
through the scraper stack, `settings.autoplay_prescrape(provider)` per provider, `autoscrape_nextep`, and a
changelog entry *"Autoplay Cloud Result … any cloud result found after a prescrape will be automatically played."*
Its built-in *Autoplay Next Episode* explicitly replaces the UpNext addon.

---

## 5. Harbor — no prefetch, but the strongest "feels instant" stack

`harborstremio/harbor` (Tauri + React, 1.5k★, actively developed) is the most credible modern competitor client.
It prefetches catalogs/metas aggressively (`prefetchQuery` on hover/focus/idle, `dns-prefetch` in `index.html`)
but **not streams**. Instead it attacks the same latency with five other techniques, all worth stealing:

1. **Picker cache** (`src/lib/picker-cache.ts`) — in-memory LRU, `MAX_ENTRIES = 80`, `STALE_MS = 30 min`, keyed
   `${meta.id}|s{season}e{episode}` **plus a `configHash`** of (addon transport URLs, debrid slugs, filter mode) so
   a settings change invalidates it. *Partial* results are cached too (`complete = false`). Entries for the
   currently-playing item are **pinned** and exempt from the stale sweep, so "switch stream" mid-playback never
   bounces the user back to a fresh scrape. Old `localStorage` copies are actively purged on boot — deliberately
   memory-only.
2. **Progressive pipeline** — `runPipeline(input, signal, onProgress)` emits partial merged/scored results as each
   addon lands; the UI paints the first candidate long before the slowest addon finishes.
3. **Early auto-fire** (`use-auto-fire.ts`) — instead of waiting for all addons: `AUTO_SETTLE_MS = 1500`
   (`AUTO_SETTLE_PACK_MS = 4000` for season packs), `HIGH_CONFIDENCE_GRACE_MS = 350`. A high-confidence top
   candidate (cached, language-matched, exact episode) fires after the grace window; everything else waits for the
   settle window or pipeline completion.
4. **Preflight probe** (`src/lib/streams/preflight.ts`) — after resolving, before handing the URL to the player:
   `GET` with `Range: bytes=0-1`, `redirect: follow`, **2.5 s timeout, 3 attempts, 1 s apart**, memoised per URL
   with in-flight dedup. Parses `Content-Range`/`Content-Length`: `< 5 MB` ⇒ classified `stub` (a dead
   debrid/"file not ready" placeholder) and skipped. This both *validates* and *warms* the connection.
5. **Dead-stream blacklist** (`src/lib/dead-streams.ts`) — persistent `localStorage` negative cache fingerprinted
   `h:{infoHash}:{fileIdx}` → `u:{url}` → `t:{addonId}:{title}`, TTL **7 days** (stub hits: **4 h**), also fed by
   "playback died under 180 s". Bad sources stop costing the user a retry at all.

Failure handling is a ladder, not an error: `resolveAndOpen()` → on debrid-side failure schedules a same-source
retry, then `advanceAuto()` to the next candidate, and after 2 consecutive debrid failures raises a "debrid down"
modal instead of grinding through the list.

---

## 6. Baseline: Stremio official does *not* prefetch

`Stremio/stremio-core` has **zero** matches for `prefetch`/`preload`. What it has is
`profile.settings.binge_watching` + `StreamsBucket` / `StreamsItem`: when you finish an episode, `meta_details.rs`
"finds a proper stream for the binge watching group and matching stream source", i.e. it re-uses your previous
*selection* (`behaviorHints.bingeGroup`) and keeps track ids, so the next episode is zero-click — but the
`/stream` request and the debrid resolve still happen after you commit. That's the bar the others clear.

The **AutoStream** addon attacks it from the other side: return one pre-picked link (quality/size/speed scoring +
a penalty system that demotes providers whose streams fail), so there's no picker step at all; it also advertises
"Episode pre-loading for continual playback".

---

## 7. Where Nuvio tvOS sits today

Read out of this fork (`shared/features/streams`, `iosApp/NuvioTV/Screens`):

- ✅ `StreamLinkCacheRepository` — persists the last-played link per content key (`type|parentMeta|sNN|eNN|videoId`)
  with headers/infoHash/bingeGroup, and refuses to cache URLs with expiring credentials.
- ✅ `StreamAutoPlayPolicy` / `StreamAutoPlaySelector` — MANUAL / FIRST_STREAM / REGEX_MATCH, reuse-last-link,
  prefer-binge-group. Comparable to Stremio's binge behaviour plus regex.
- ✅ `NextEpisodeAutoPlay` — does load next-episode streams (and prefetches its subtitles) via
  `PlayerStreamsRepository.loadEpisodeStreams`.
- ❌ **but the trigger is the autoplay-card window**: `nextEpisodeThresholdPercent` is clamped to **97–100 %**, or
  `minutesBeforeEnd` clamped to **≤ 3.5 min**. Compare CloudStream (80 %) and Seren (20 % / 10 min). We start the
  fan-out seconds before we need the result.
- ❌ No prefetch on the detail/episode screen — `StreamsRepository.load` runs only when the picker opens.
- ❌ No link pre-resolution and no pre-warm ping anywhere.
- ❌ No preflight/stub probe and no dead-stream memory.
- ❌ Upstream `NuvioMedia/NuvioMobile` has nothing either: `git grep -il "prefetch\|preload\|precache"` on
  `upstream/cmp-rewrite` hits only image/profile-background/Trakt files in `composeApp/`, and **nothing in
  `shared/`**. This is genuinely open ground, not a port.

---

## 8. Ranked port plan (highest value first)

1. **Lower the next-episode search threshold and decouple it from the card.** Split the current single trigger into
   *search at ~75–80 % of runtime* (silent, into a cache) and *show the card at 97 %+*. This is the CloudStream
   model and it's a small change to `NextEpisodeAutoPlay.onProgress` + a cache the picker also reads.
2. **A keyed stream-result cache with a config hash** — Harbor's `picker-cache` shape: key
   `type|metaId|sNN|eNN`, invalidated by a hash of (enabled addon URLs, debrid config, filter settings), 20–30 min
   TTL, partial results allowed, pinned while playing. Everything else plugs into this.
3. **Pre-warm ping on the resolved URL** — AIOStreams' `pingStream`: `GET` with manual redirect (Ktor:
   `HttpRequestBuilder { followRedirects = false }`), short timeout, response body discarded, fired for the top-1
   candidate when the streams list paints and for the next episode after the prescrape. Cheap, no bandwidth, and it
   collapses stage 2–3 latency. Needs a per-item cooldown (AIOStreams: 1 h preload / 24 h precache) so we don't
   hammer addons — and it must respect the `proxyHeaders` we already thread through.
4. **Preflight `Range: bytes=0-1` probe before handing the URL to MPV/AVPlayer** — catches the stub/dead-link case
   that today shows up as a spinner-then-failure on the TV, and warms the socket. Harbor's constants (2.5 s, 3
   tries, `< 5 MB` ⇒ stub) are a sane starting point.
5. **Persistent dead-stream blacklist** keyed by infoHash+fileIdx, 7 d / 4 h TTLs, fed by preflight stubs *and* by
   "playback died in under 3 minutes".
6. **Prefetch on focus/open of the detail screen** (Harbor prefetches metas on focus; nobody does it for streams).
   On tvOS this is attractive because focus dwell time on a hero/episode row is long — but it's the one item that
   multiplies addon load, so gate it behind a setting and a single in-flight request.

tvOS-specific notes: a warm socket only helps if the player reuses it — with `MPVPlayerView` the ping should share
the same HTTP stack/headers we hand mpv, and for the AVPlayer path the equivalent second-stage win is preroll
(`AVURLAsset` + `preferredForwardBufferDuration` / `automaticallyWaitsToMinimizeStalling`) on the pre-resolved URL.
Also note the existing hazard already recorded for this repo: cached links with expiring credentials must be
re-resolved, not replayed — `StreamLinkCacheRepository.hasLikelyExpiringPlaybackCredentials` already encodes that
rule and any prefetch cache has to obey it too.

---

## Sources

Code read directly: [Viren070/AIOStreams](https://github.com/Viren070/AIOStreams)
(`packages/core/src/main/resources.ts`, `config/schema/resources.ts`, `utils/constants.ts`,
`frontend/.../background-optimization.tsx`, `docs/content/changelog/v2.31.mdx`) ·
[recloudstream/cloudstream](https://github.com/recloudstream/cloudstream) (`ui/player/PlayerGeneratorViewModel.kt`,
`GeneratorPlayer.kt`, `AbstractPlayerFragment.kt`, `RepoLinkGenerator.kt`) ·
[nixgates/plugin.video.seren](https://github.com/nixgates/plugin.video.seren) (`modules/smartPlay.py`,
`modules/player.py`, `modules/getSources.py`) · [kornbred/plugin.video.fenlight](https://github.com/kornbred/plugin.video.fenlight) ·
[harborstremio/harbor](https://github.com/harborstremio/harbor) (`lib/streams/preflight.ts`, `lib/picker-cache.ts`,
`lib/dead-streams.ts`, `views/play-picker/*`) · [Stremio/stremio-core](https://github.com/Stremio/stremio-core)
(`types/streams/streams_item.rs`, `models/meta_details.rs`, `types/profile/settings.rs`).

Public sources: [Real-Debrid `instantAvailability` disabled (comet #243)](https://github.com/g0ldyy/comet/issues/243) ·
[Seren pre-emptive scraping timeout report](https://github.com/nixgates/plugin.video.seren/issues/593) ·
[AutoStream addon overview](https://troypoint.com/autostream-stremio-addon/) ·
[Vidi](https://vidi.plomo.se/) · [Fusion Media Center docs](https://fusion.nhyira.dev/) ·
[Fusion on the App Store](https://apps.apple.com/au/app/fusion-media-center/id6759285919) ·
[Weyd/Syncler feature overviews](https://troypoint.com/best-apks/).

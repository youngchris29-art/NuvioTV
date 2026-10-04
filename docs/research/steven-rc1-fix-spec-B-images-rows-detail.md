# Steven beta.19-rc1 fix batch: spec P-B (images, rows, folder page, tab bar, auto-play, Detail, player copy)

Spec writer: P-B, 2026-10-03. **Revision r2** the same day, after the critique (`docs/research/steven-rc1-fix-spec-critique.md`) and Christian's answers; the change table is at the end. Read-only against the clone `~/Claude/Projects/NuvioMobile-steven-rc1`, branch `claude/steven-beta19-rc1-verdict` at `284fd764`. Every `file:line` below is at `284fd764`. Paths are relative to `NuvioMobile/` (`iosApp/NuvioTV/…`, `shared/src/…`).

Plan: `docs/steven-beta19-rc1-verdict-batch-plan-2026-10-02.md` (Status block = the approved calls). Next batch that builds on I1 and F: `docs/home-stage-strip-plan-2026-10-03.md`.

Items: **I1** (4K decode size, sharper poster/logo URLs, Home hero sharpen), **F** (row edge fade as a setting and a reusable, environment-driven modifier), **C** (folder page header), **T1** (tab bar half-shown: probe + two legs, both off), **A** (Auto-Play Best Source ranking), **D** (Detail: labels, glass rule, lighter Cinematic scrim), **P** (player "Preparing" copy). Spec A (`steven-rc1-fix-spec-A-motion-trailers.md`) owns M3/R2/R1, M4, M5, B2.

Christian's answers applied in r2 (2026-10-03):
- TMDB title logos move to `original`, bounded by the per-view decode size.
- Cinemeta/metahub posters move to `large`.
- The Detail Episodes rows get the edge fade.
- The 250 pt ramp is OK, with the "lower one constant" fallback.
- Only an explicit old "Off" migrates from the A/B.
- The glass rule may stop Classic's synopsis-panel flattening.
- T1 ships with both legs off (leg 0) until the device session picks one.

House rules every executor follows:
- No `@State`/`@Published` write per scroll frame. Scroll-driven visuals use `.visualEffect`, or a Bool/Int transform in `onScrollGeometryChange` whose action fires only on a crossing.
- Never an app-root `.tint`.
- Launch-arg knobs are read once from `UserDefaults.standard` into a `nonisolated static let`.
- Comments follow the surrounding code: an item tag first (`I1`, `F`, `C`, `T1`, `A`, `D`, `P` + "(Steven beta.19-rc1 verdict, 2026-10-03)"), then the why, written as prose.
- Never hand-edit `Localizable.xcstrings`. New strings stay English in code; the populate → translate → merge pass runs after merge.
- Agents edit only. The main session builds, tests and commits.

Agent names follow the critique's merged wave plan: **W1-B**, **W2-F**, **W3-T**, **W3-D**, **W3-A**, **W4-H** (§8).

---

## I1. Blurry Detail backdrop, posters and logos on a 4K Apple TV

### Root cause (confirmed)

- **Decode cap.** `ArtworkStore.downsample(data:)` (`iosApp/NuvioTV/DesignSystem/CachedAsyncImage.swift:419-441`) passes a fixed `kCGImageSourceThumbnailMaxPixelSize: 1920` (`:435`). On an Apple TV 4K the UI is 1920×1080 points at scale 2 = 3840×2160 px, so every full-bleed layer is drawn from a 1920-px bitmap stretched 2×.
- **Detail backdrop.** Detail already asks for the larger TMDB file (`DetailBackdropURL.upgraded`, `DetailView.swift:13-25`: `/t/p/w1280/` → `/t/p/original/`). The decode then throws the extra pixels away (Oak Street pair, `docs/research/steven-beta19-photos/2026-10-02-rc1-oak-street-zoom-{nuvio,fusion}.jpg`).
- **TMDB posters** are built at `w500` in `shared/.../tmdb/TmdbMetadataService.kt:264, 299, 334, 369, 655, 1141`, plus three sites the critique found and I verified:
  - `:1274` (season poster);
  - `:1337` (More Like This recommendations, the Detail row Steven looks at);
  - `:1374` (collection-part poster fallback).
  - Also `shared/.../collection/TmdbCollectionSourceResolver.kt:64, 393, 417, 440, 469`.
- **Cinemeta posters** are not built anywhere in our code. They arrive in the add-on's catalog/meta payload as `images.metahub.space/poster/<size>/<imdb>/img` (`MetaPreview.poster`), and every card draws them as given (`PosterCard.swift:954`).
  - HEAD checks on 2026-10-03 (3 titles: tt0111161, tt15398776, tt9603212): `/poster/small/`, `/medium/` and `/large/` all answer 200, with distinct files: small 27–53 KB, medium 73–82 KB, large 157–237 KB.
  - The same check on `/background/` and `/logo/` (2 titles) returned **byte-identical** medium and large files. So the hero's synthesized `background/medium` URL and Detail's existing `/background/large/` rewrite gain nothing; only posters have a real larger size.
  - The pixel size of `large` was not measured: this session downloads no image bodies. W1-B's first simulator run reads it off the probe (`src=`, §I1.9).
- **Title logos** come from TMDB at `w500` (`TmdbMetadataService.kt:989` preview enrichment, `:1140` detail enrichment) and are drawn 600 pt wide (Cinematic slot) = 1200 px on 4K, upscaled about 2.4×. `:597`/`:613` are company/network entity logos, not title logos, and are out of scope.
- **Memory cache** (`CachedAsyncImage.swift:163-168`): one `NSCache<NSURL, UIImage>` keyed by URL only, 400 items / 128 MB of decoded bytes.

### I1.1 Decode request (new file `iosApp/NuvioTV/DesignSystem/ArtworkDecodeSize.swift`; the target is file-system synchronized, so a new file joins the target with no pbxproj edit)

```swift
/// I1 (Steven beta.19-rc1 verdict, 2026-10-03): how large an image is decoded. The cap ImageIO
/// gets is the drawn size in pixels (points × displayScale), aspect-aware, rounded UP to a shared
/// bucket so views of similar size share one bitmap.
nonisolated enum ArtworkDecodeSize: Hashable, Sendable {
    /// The view's drawn size in POINTS (resting size; focus lift is not added). Stored as two
    /// CGFloats, not a CGSize, so the enum is Hashable on every SDK.
    case points(width: CGFloat, height: CGFloat)
    /// A layer that fills the screen: 3840 px on the long side at scale 2 (1920 at scale 1).
    case fullBleed
    /// An explicit long-side cap in pixels, independent of scale. The Stage wash passes 256.
    case pixels(Int)
    /// Today's behaviour (1920 px cap). The default for every call site not listed in §I1.4.
    case legacy
}

nonisolated struct ArtworkDecodeRequest: Hashable, Sendable {
    var size: ArtworkDecodeSize
    var fill: Bool            // ContentMode.fill → true, .fit → false
    var scale: CGFloat        // displayScale at the call site
    static let legacy = ArtworkDecodeRequest(size: .legacy, fill: true, scale: 1)
    /// Critique #23a: a `.points` request with a zero side (a GeometryReader's first pass) is
    /// treated as `.legacy`, so it never decodes a 128 px bucket and then reloads.
    var normalized: ArtworkDecodeRequest
}

nonisolated enum ArtworkDecodeMath {
    static let buckets: [Int] = [128, 256, 384, 512, 640, 768, 896, 1024, 1280, 1536, 1920, 2560, 3072, 3840]
    static let maxPixel = 3840
    /// Seeded once on the main thread in `NuvioTVApp.init` (critique #23c), from the first
    /// UIWindowScene's `screen.scale`, else `UIScreen.main.scale`. Used only by non-view code
    /// (hero resolver, prefetch); views read `@Environment(\.displayScale)`.
    nonisolated(unsafe) static var screenScale: CGFloat = 2
    static func bucket(for px: CGFloat) -> Int                                  // smallest bucket ≥ ceil(px), clamped
    static func neededLongSide(_ r: ArtworkDecodeRequest, source: CGSize?) -> CGFloat
    // .legacy → 1920; .fullBleed → 1920 × scale; .pixels(n) → n.
    // .points(w, h): W = w × scale, H = h × scale; with a source size (sw, sh):
    //   k = fill ? max(W/sw, H/sh) : min(W/sw, H/sh); return max(sw, sh) × k. Without: max(W, H).
    static func storeBucket(needed: CGFloat, sourceLongSide: CGFloat?) -> Int     // bucket(min(needed, sourceLong))
    static func servingOrder(from b: Int) -> [Int]       // b, then every larger bucket
    static func placeholderOrder(below b: Int) -> [Int]  // strictly smaller buckets, largest first
    static let largePoolThreshold = 6 * 1024 * 1024      // decoded bytes
}
```

### I1.2 URL upgrades (new file `iosApp/NuvioTV/DesignSystem/ArtworkURLUpgrade.swift`)

One pure helper decides every "ask the CDN for a bigger file" rewrite. It replaces the idea of per-site rewrites and makes the cache aware that two URLs are the same picture.

```swift
/// I1: a larger rendition of the same picture on the same CDN. nil = no larger rendition known.
nonisolated enum ArtworkURLUpgrade {
    enum Role { case poster, posterLarge, backdrop, logo }
    static func upgraded(_ url: String, role: Role) -> String?
    static func upgraded(_ url: URL, role: Role) -> URL?
    /// Every larger rendition of `url` under any role, largest first, then `url` itself, deduped.
    /// The cache treats these as one family (§I1.3).
    static func family(_ url: URL) -> [URL]
}
```

Rules (host match is exact; path match on the size segment only; query strings and the file name are kept):

| Host | Role | From | To |
|---|---|---|---|
| `image.tmdb.org` | `.poster` | `/t/p/w92|w154|w185|w342|w500/` | `/t/p/w780/` |
| `image.tmdb.org` | `.posterLarge` | `/t/p/w92…w780/` | `/t/p/original/` |
| `image.tmdb.org` | `.backdrop` | `/t/p/w300|w780|w1280/` | `/t/p/original/` |
| `image.tmdb.org` | `.logo` | `/t/p/w45|w92|w154|w185|w300|w500/` | `/t/p/original/`, **except** when the file ends in `.svg` (ImageIO cannot decode SVG; the `w500` path is kept, so no regression) |
| `images.metahub.space` | `.poster`, `.posterLarge` | `/poster/small/`, `/poster/medium/` | `/poster/large/` |
| `images.metahub.space` | `.backdrop`, `.logo` | — | nil (large serves the same file as medium, measured above) |
| anything else (custom poster services, user collection art, add-on CDNs) | any | — | nil |

`family(url)`, for example for `…/t/p/w500/x.png`, returns `[…/original/x.png, …/w780/x.png, …/w500/x.png]`.

Christian's two answers, as implemented:
- **Logos → `original`.** The Kotlin data keeps `w500`: it is what the Home hero fetches inside its 400 ms swap deadline and its 1.5 s launch deadline (critique #2's concern applies to logos as much as to backdrops). Every surface that DRAWS a logo asks for the `.logo` upgrade with a slot-sized decode (§I1.5). The Home hero sharpens its logo after the commit (§I1.7). On screen that is the same result as moving the data to `original`, without slowing the hero.
- **metahub posters → `large`.** Applied at render through `.poster`, with the original URL as the automatic fallback (§I1.4), so a title whose `large` file is missing still shows its `medium` one.

### I1.3 `ArtworkStore` (`CachedAsyncImage.swift:158-442`)

**Pools** (replace `memory`, `:163-168`):
- `small`: `NSCache<NSString, UIImage>`, `totalCostLimit` **192 MB**, `countLimit` 1000.
- `large`: `totalCostLimit` **192 MB**, `countLimit` 24 (critique #2: by bytes, so a row's 1920 prefetches do not evict the carousel).
- The pool is chosen by decoded cost (`bytesPerRow × height` ≥ `largePoolThreshold`).
- Both pools get an `NSCacheDelegate` whose `cache(_:willEvictObject:)` keeps a running cost sum for the probe (critique #23d).
- A `UIApplication.didReceiveMemoryWarningNotification` observer empties `large`.
- Budget: 384 MB worst case, against 128 MB today. The device memory check (§I1.9) decides; if it fails, halve both pools (two constants).

**Key**: `"\(bucket)|\(url.absoluteString)"`. One URL can sit in both pools at different buckets.

**Source sizes**: `NSCache<NSURL, NSValue>` with `countLimit` 4000. It evicts entry by entry, never all at once (critique #3).

**Lookup contract.** Spec A's tile loader and every other caller rely on this:

| Call | Semantics |
|---|---|
| `cached(_ url: URL?)` and `cached(_ url:, .legacy)` | **Any bucket, any family member**: the largest decode of any URL in `ArtworkURLUpgrade.family(url)`. Exactly today's "one entry per URL" behaviour, widened to the family. A poster the card decoded at 896 px from its `large`/`w780` variant is a HIT for a caller asking with the original `medium`/`w500` URL. |
| `cachedLargest(_ url: URL)` | Same as above, by name. `cachedImage(for:)` (`:311-313`, `ArtworkColorStore.swift:178`) returns it, so ring and rail colours keep working when a card draws the upgraded URL. **Spec A's `InlineTileArtLoader` poster fallback uses `cachedLargest(posterURL)`.** |
| `cached(_ url:, request)` with `.points`/`.fullBleed`/`.pixels` | Bucket-aware: `b = storeBucket(neededLongSide(request, source: sourceSizes[url]), sourceLong)`, then `servingOrder(from: b)` over the family, largest URL first. A larger decode serves a smaller request. |
| `cachedPlaceholder(_ url:, request)` | Any family member, any bucket below `b`, largest first: what to show while the right size loads. |

**Fetch**: `fetch(_ url: URL, decode: ArtworkDecodeRequest = .legacy, admission: FetchAdmission = .normal, timeout: TimeInterval? = nil)`.
- The memory check at `:325` uses the lookup contract above (`.legacy` → any bucket).
- `inflight` is keyed by `"\(bucket(for: neededLongSide(request, source: sourceSizes[url])))|\(url)"`. Same-bucket requests coalesce; a second bucket of one URL re-decodes from the URLCache bytes (no second download once the first response is stored).
- `downsample(data:request:)` returns `(image, sourceSize, storeBucket)`, with `maxPixel = min(bucket(for: needed), ceil(sourceLong))`. The image is stored under `storeBucket` and `sourceSizes[url]` is recorded.
- A `.legacy` decode keeps today's `min(1920, sourceLong)`.

**Prefetch**:
- `prefetch(_ urls: [URL], decode: ArtworkDecodeRequest = .legacy)`.
- Typed form `struct ArtworkPrefetchItem { let url: URL; let decode: ArtworkDecodeRequest }` with `static func prefetch(_ items: [ArtworkPrefetchItem])`.
- An item is skipped when `cached(item.url, item.decode) != nil`.

**New**: `prefetchAndWait(_ urls: [URL], decode:, timeout: TimeInterval) async`. It fetches concurrently and returns when all land or the timeout passes; it never cancels the fetches. Used by C.

**URLCache disk** (`:187-191`): 256 MB → 512 MB.

**Probe** (launch arg `debug.artworkProbe`, read once into `ArtworkProbe.enabled`):
- One line per decode: `[ArtworkStore] decode host=<host> size=<seg> req=<bucket> src=<w>x<h> out=<w>x<h> pool=<s|l> ms=<n>`. `size=` is the CDN size segment: `w500`/`w780`/`original` for TMDB, `poster/medium` / `poster/large` for metahub, `-` otherwise. It answers critique #14's "which hosts and sizes do Steven's rows use".
- Every 30 s and on a memory warning: `[ArtworkStore] pools small=<MB>/<n> large=<MB>/<n> avail=<os_proc_available_memory() MB>`.

### I1.4 `CachedAsyncImage` / `CachedImageLoader` (`CachedAsyncImage.swift:12-133, 444-573`)

New init parameters on all four inits (`:39`, `:49`, `:124`, `:129`), after `contentMode`:
- `decodeSize: ArtworkDecodeSize = .legacy`.
- `upgrade: ArtworkURLUpgrade.Role? = nil`. When set, the candidate chain becomes `[upgraded(primary), primary, fallback]` (deduped, upgrade only when non-nil).
- `releasesWhenHidden: Bool = false`. Critique #23e: on `.onDisappear`, `loader.release()` drops the image and resets `currentPair`. On `.onAppear` it reloads, normally a memory hit. Detail's backdrop sets it, so a 10-deep Detail stack does not pin ten 33 MB bitmaps outside the cache.

Wiring:
- `@Environment(\.displayScale) private var displayScale`. The request is `ArtworkDecodeRequest(size: decodeSize, fill: contentMode == .fill, scale: displayScale).normalized`.
- `ImageURLPair` (`:445-448`) becomes `ImageURLChain { let urls: [URL]; let request: ArtworkDecodeRequest }`, so a size or URL change reloads.

`ImageFallbackPlan` (`:452-504`):
- `candidates(upgraded: URL?, primary: URL?, fallback: URL?) -> [URL]` (deduped, at most three).
- `initialRender(headCached: Bool, placeholderCached: Bool, primaryFailed: Bool, hasFallback: Bool)`:
  1. the head (first candidate) at the requested bucket → `.showHead`;
  2. else a placeholder (any family member of any candidate, any bucket) → `.showPlaceholderThenFetch`;
  3. else today's fallback rules.
- In `firstLoaded`, every NON-LAST candidate gets the short 8 s request timeout and `noteFailure` on a definitive failure, not just "the primary with a fallback". A missing metahub `large` therefore costs one quick 404, and is skipped for 10 minutes after that.
- The swap from placeholder to head keeps the existing `withAnimation(.easeIn(duration: 0.25))` at `:565`.

### I1.5 Call sites

| # | Site | Content | `decodeSize` | `upgrade` | Mode | Owner |
|---|---|---|---|---|---|---|
| 1 | `DetailView.swift:1470` `backdropImage` | Detail backdrop | `.fullBleed`, `releasesWhenHidden: true` | — (the existing `DetailBackdropURL` chain stays) | fill | W3-D |
| 2 | `DetailView.swift:1488` `posterBackdropLayer` | poster, right 40 % | `.points(width: geo.size.width * 0.4, height: geo.size.height)` | `.posterLarge` | fill | W3-D |
| 3 | `PosterCard.swift:954` | portrait card, every row and grid | `.points(width: resolvedWidth, height: resolvedHeight)`, defined once as `static func decodeRequest(width:height:scale:) -> ArtworkDecodeRequest` on `PosterCard` (critique #22: the same request C's reveal prefetch uses; the card passes its `displayScale`) | `.poster` | fill | W1-B |
| 4 | `PosterCard.swift:1165` `LandscapeCard` | 16:9 card | `.points(width: width, height: height)` | — | fill | W1-B |
| 5 | `SagaCard.swift:123` | 500×281 card | `.points(width: width, height: height)` | — | fill | W1-B |
| 6 | `CollectionsUI.swift:712` `FolderTile` | folder cover (user art) | `.points(width: style.width, height: Self.artworkHeight(for: folder, style: style))` | — | fill | W2-F |
| 7 | `Detail/DetailCinematicHero.swift:200` | title logo | `.points(width: DetailCinematicLayout.logoMaxWidth, height: DetailCinematicLayout.logoSlotHeight)` | `.logo` | fit | W1-B |
| 8 | `DetailView.swift:1687` (Classic logo) | title logo | `.points(width: 600, height: 180)` | `.logo` | fit | W3-D |
| 9 | `DesignSystem/TitleLogoHeader.swift` (custom loader at `:44`, `:75`, `:80`) | header logo | new init params `decodeSize: ArtworkDecodeSize = .legacy`, `upgrade: ArtworkURLUpgrade.Role? = nil`; the loader tries `fetch(upgraded)` then `fetch(original)`, shows `cachedPlaceholder` first | as passed | fit | W1-B (API) |
| 9a | `StreamPickerView.swift:236` | stream picker title logo | `TitleLogoHeader(…, decodeSize: .points(width: 600, height: 120), upgrade: .logo)` | `.logo` | fit | W1-B |
| 9b | `CollectionsUI.swift` folder header | folder logo (user art) | `.points(width: 1200, height: Theme.Size.heroLogoSlotHeight)` | — | fit | W2-F |
| 10 | `Detail/DetailSynopsisSheet.swift:73` | title logo | `.points(width: 600, height: 180)` | `.logo` | fit | W3-D |
| 11 | `TrailerBridge.swift:221` | bridge caption logo | `.points(width: 360, height: 72)` | `.logo` | fit | W3-D |
| 12 | `ArtworkColorStore.swift:176-181` | colour sampling | none (the store's lookup contract covers the family); comment update only | | | W1-B |
| 13 | Home hero (`HomeView.swift`, `HomeHeroCommit.swift`) | backdrop, logo, poster fallback, prefetch | §I1.7 | | | W4-H |
| 14 | `InlineTrailerCard.swift` | morph tile | spec A's R2 (`InlineTrailerTileArt`): banner with the tile's `.points` size, poster fallback through `cachedLargest` | | | spec A W2-D |
| 15 | Unchanged on purpose (`.legacy`, source-limited or small): `AnimatedGifImage.swift:84`, `ProfileSelectionView.swift:16/332/335/380`, `DetailView.swift:2712` (cast), `:2846` (company logos), `MPVPlayerView.swift:2181/2231`, `EpisodesSection.swift:369/490`, `TrailerThumbnail.swift:82`, `Player/PlayerInfoTab.swift:71`, `TitleLogoStore.swift:356`, `SagaCard.swift:249-254`, `CollectionsUI.swift:904-917` | | `.legacy` | — | | — |

The `HeroCrossfadeImage` URL-driven mode (`HomeView.swift:4892`, `:5055-5111`) has no call site at `284fd764` (only the image-driven `:4692`). Leave it untouched.

### I1.6 Kotlin: posters at w780 (W1-B)

- New `shared/src/commonMain/kotlin/com/nuvio/app/features/tmdb/TmdbImageSizes.kt`:
  ```kotlin
  /** I1 (Steven beta.19-rc1 verdict): TMDB rendition per artwork role. Posters are w780 so a
   *  lifted Large card is not upscaled on a 4K Apple TV. Title logos stay w500 in the data:
   *  tvOS asks for `original` at draw time, outside the Home hero's swap deadline. */
  object TmdbImageSizes {
      const val POSTER = "w780"; const val BACKDROP = "w1280"; const val LOGO = "w500"; const val PROFILE = "w500"
  }
  internal fun tmdbImageUrl(path: String?, size: String): String? {
      val clean = path?.trim()?.takeIf(String::isNotBlank) ?: return null
      return "https://image.tmdb.org/t/p/$size$clean"
  }
  ```
- `TmdbMetadataService.kt`: `buildImageUrl` (`:1971-1974`) delegates to `tmdbImageUrl`. `TmdbImageSizes.POSTER` replaces `"w500"` on every `posterPath`: `:264, :299, :334, :369, :655, :1141, :1274, :1337, :1374`.
- `TmdbCollectionSourceResolver.kt`: `imageUrl` (`:544-547`) delegates. `POSTER` at `:64` (first operand), `:393, :417, :440, :469`.
- Unchanged: profile `:189`, entity logos `:597, :613`, title logos `:989, :1140` (see §I1.2), backdrops, episode stills `:1273`, MDBList (`MdbListLibraryDecoderTest.kt:57` pins `w500`).
- **Grep gate** in the W1-B brief (critique #15): `grep -nE 'posterPath[^)]*"w500"' shared/src/commonMain/kotlin/com/nuvio/app/features/{tmdb,collection}` must print nothing.
- Release note: library/CW items saved from now on carry w780 URLs and sync to the phone (harmless).

### I1.7 Home hero: prefetch as today, sharpen only the presented hero (W4-H, Opus) — re-specced per critique #2

What stays exactly as today:
- URLs, `.legacy` decode (≤ 1920) and `.head` admission for `HeroCommitCoordinator.prepare` (launch head + carousel), `HeroArtResolver.present`'s deadline-bound fetches (`HomeView.swift:3888, 3904, 3926, 3937`), the poster fallback, and every hero prefetch (`:2748`, `:2766`, `:2807`, `heroBackdropPrefetchURLs` `:5797-5812`).
- `heroBackdropURL(banner:id:poster:)` (`:5778-5785`) does not rewrite anything.
- The 400 ms `laterSwapDeadline` and the 1.5 s folder/launch budgets see the same bytes as today.

What changes:
1. **Row poster prewarm** (`HomeHeroCommit.swift:349-368`, `rowPosterPrewarmURLs` `:406`): map each URL through `ArtworkURLUpgrade.upgraded(_, role: .poster) ?? url` and prefetch with `.pixels(896)`, so the warmed entry is the one the card will draw. Add `prefetchItems(_ items: [ArtworkPrefetchItem])` to `HeroCommitArtworkFetching`, with a protocol-extension default that forwards to `prefetchImages(items.map(\.url))`, so `HeroCommitCoordinatorTests`' stub compiles unchanged. `ArtworkStoreHeroFetcher` implements it with the typed `ArtworkStore.prefetch`. Carousel URLs stay on `prefetchImages` (`.legacy`).
2. **Poster fallback** in `present` (`:3837-3838`, `:3937`): the lookup stays `cached(posterFallbackURL)`, which now finds the card's family decode. The fetch uses `.pixels(896)`.
3. **Sharpen after commit.** New `HeroSharpen` logic inside `HeroArtResolver`:
   - **Trigger**: the committed `presented` has stayed the same identity for `HeroSharpen.dwell = 0.6 s` (a cancellable `Task` started from `commit`; any new `present`/target change cancels it). Skip when Reduce Data is on (no such setting today, so a TODO only), or when the hero trailer is playing over the art (the resolver can read the hero trailer model's phase; optional for W4-H).
   - **Backdrop**: `sharpURL = ArtworkURLUpgrade.upgraded(backdropURL, role: .backdrop) ?? backdropURL`. The request comes from the hero form: Nuvio-style (`heroNuvioStyle || focusHeroActive`, `HomeView.swift:790`) → `.points(width: Theme.Size.heroNuvioArtworkWidth (1250), height: Theme.Size.heroBackdropHeight (820))` fill (bucket 3072 at scale 2: 21 MB); classic full-width → `.fullBleed` (33 MB). HomeView sets `resolver.sharpenForm` when the style changes (a plain stored property, no observation). Fetch only when `sharpURL != backdropURL` OR the presented bitmap's long side in pixels is < 0.9 × the needed long side.
   - **Logo**: `ArtworkURLUpgrade.upgraded(logoURL, role: .logo)` (TMDB → `original`, non-SVG) with `.points(width: Theme.Size.heroLogoMaxWidth (520), height: Theme.Size.heroLogoSlotHeight (150))` fit. The resolver keeps `presentedLogoURL` beside `presentedLogoSource` to know which URL the logo came from (the `.pending` path learns it from `TitleLogoStore.awaitLogoURL`).
   - **Fetch**: `.normal` admission, no deadline, no request timeout. Backdrop and logo run concurrently; adoption waits for both (or for the one requested), at most 20 s, then adopts whatever landed.
   - **Adopt**: new `adoptSharpened(backdrop: UIImage?, logo: UIImage?, identity: String)` behind a pure `shouldAdoptSharpened(targetIdentity:presentedIdentity:resolveTaskIsNil:identity:)`: identity unchanged, no resolve in flight. It calls `commit` with the new bitmap(s) and the unchanged item, with `backdropSource: "sharp"` / `logoSource: "sharp"` (append-only probe vocabulary). `HeroPresentation` compares images by reference, so the commit goes through. Spec A's M5 text swap treats a same-identity commit as a silent gap-fill: the art cross-fades between two versions of the same picture and the text does not move.
   - A sharpened entry stays in the cache, so a re-present of the same hero within the session hits the sharp version through the `.legacy` family lookup with no second fetch.
4. Unit tests (new `NuvioTVTests/HeroSharpenTests.swift`):
   - `testSharpenSkippedWhenNoUpgradeAndBitmapLargeEnough`;
   - `testSharpenRequestedForTmdbW1280` (needs the URL upgrade);
   - `testSharpenRequestedForSmallBitmap` (a metahub 1920 decode under a classic `.fullBleed` need);
   - `testAdoptRequiresSameIdentityAndNoResolve` (4 cases of `shouldAdoptSharpened`);
   - `testNuvioFormRequestIs3072Bucket` and `testClassicFormIsFullBleed` (via `ArtworkDecodeMath`).
   - The decision is a pure `HeroSharpen.plan(backdropURL:presentedLongSidePx:form:scale:) -> (url, request)?`.

### I1.8 Tests (W1-B unless noted)

New `NuvioTVTests/ArtworkDecodeMathTests.swift`:
- `testBucketRoundsUpAndClamps`: 0 → 128, 129 → 256, 806 → 896, 2915 → 3072, 5000 → 3840.
- `testFullBleedIsScreenPixels`: scale 2 → 3840, scale 1 → 1920.
- `testLegacyIs1920` and `testPixelsPassThrough`.
- `testPointsFillUsesSourceAspect` (2:3 source in a 360×203 pt tile at scale 2 → 1080) and `testPointsFitUsesSourceAspect` (3:1 logo in 600×180 → 1080).
- `testZeroPointsNormalizeToLegacy`.
- `testStoreBucketNeverAboveSource` (needed 3840, source long 1170 → 1280).
- `testServingOrderAscends` and `testPlaceholderOrderDescends`.
- `testPoolThreshold`.

New `NuvioTVTests/ArtworkURLUpgradeTests.swift`:
- `testTmdbPosterW500ToW780`, `testTmdbPosterW780Unchanged`, `testTmdbPosterLargeToOriginal`.
- `testTmdbBackdropW1280ToOriginal`.
- `testTmdbLogoPngToOriginal`, `testTmdbLogoSvgUnchanged`.
- `testMetahubPosterSmallAndMediumToLarge`, `testMetahubPosterLargeUnchanged`, `testMetahubBackgroundAndLogoUnchanged`.
- `testOtherHostsUnchanged` (a custom poster service, a GitHub-hosted collection cover).
- `testQueryStringKept`.
- `testFamilyLargestFirstAndDeduped` (`w500` → [original, w780, w500]).

`ImageFallbackPlanTests.swift`:
- `testChainOrderUpgradeThenPrimaryThenFallback`;
- `testPlaceholderShownThenHeadFetched`;
- `testNonLastCandidateFailureRecorded` (definitive 404 on the upgrade → `noteFailure`, then the primary loads);
- existing cases updated to the new signatures with unchanged expectations.

Kotlin `shared/src/commonTest/kotlin/com/nuvio/app/features/tmdb/TmdbImageSizesTest.kt` (**jvmTest and tvosSimulatorArm64Test**):
- `posterSizeIsW780`;
- `tmdbImageUrlBuildsPosterUrl`;
- `tmdbImageUrlRejectsBlankPath`;
- `logoStaysW500InData` (pins the deliberate choice).

### I1.9 Proof

Simulator (FA87: signed-out guest, Cinemeta catalogs, TMDB enrichment through the bundled key):
1. Launch with `-debug.artworkProbe YES` and stream `log stream --predicate 'eventMessage CONTAINS "[ArtworkStore]"'`.
2. **metahub large, Gate 1.** Home rows log `size=poster/large`. Compare `src=` against one `size=poster/medium` line (Detail's poster fallback or a cold row before the upgrade). Decision rule: if `large`'s long side is not larger than `medium`'s, the main session deletes the metahub poster rule in `ArtworkURLUpgrade` (one table row and its test). Record both sizes in the batch plan's OUTCOME.
3. **TMDB poster proof** on TMDB-built surfaces (critique #14): the Detail poster layer and More Like This (`size=w780` / `original`, `out=` > 1000 px long side on the poster layer).
4. **Backdrop**: open a Detail page with a TMDB backdrop. `req=3840 … out=` > 1920 when `src` > 1920. Take `xcrun simctl io <FA87> screenshot` (3840×2160) on this build and on a `284fd764` build. Crop 800×800 of text-free art (`sips -c 800 800 --cropOffset 200 2600`) and compare the variance of the Laplacian (a throwaway script in the scratchpad): ≥ 1.5× when `src` ≥ 3000 px.
5. **Home hero sharpen (W4-H)**: focus a TMDB-enriched title and wait 1 s. The probe shows `present … backdrop=sharp`, and the screenshot crop of the hero art improves the same way. A 10-row walk shows no `art=timeout` increase against the base (count `present … waited=` lines over 400 ms on both builds).
6. **Memory**: 10 rows down and back plus a 10-deep Detail → More Like This chain (critique #23e), with the probe on. Pools stay ≤ 192 + 192 MB, and `avail` does not trend down.

Device (Christian, Living Room Apple TV 4K, **Test profile**):
- Plan item 4 (Oak Street Detail backdrop, posters and logo visibly sharper, photographed as Steven did).
- 30 minutes of browsing with `-debug.artworkProbe YES --console`: no jetsam, and the `avail` minimum ≥ 400 MB. Otherwise halve both pools.
- Note the `host=`/`size=` mix in Steven-like rows.

---

## F. Row edge fade: Soft by default, an Appearance setting, one environment-driven row modifier

### Root cause (confirmed)

- The fade today is the `debug.rowEdgeFade` Developer A/B (`RowEdgeEffectStyle.swift:57`, default **2** = system `.automatic`).
- Its Soft leg (`RowSoftEdgeMask`, `:162-224`) is a two-stop LINEAR ramp (`:207`, `:210`) over only the ~140 pt margin OUTSIDE the row frame (`:166`). Cards are fully opaque up to the frame edge: the "hard knee" in the triage (§4, "≈65 pt ramp, then hard cut").
- At Medium+ (262 pt stride) that margin fades mostly a gap.
- Detail rows, the Episodes rows and the folder page have no fade.

Measured constraint (`docs/research/rc13-sim-evidence/bug118-auto-12.png`, Medium, after 12 Rights): the row frame's trailing edge is 140 pt from the bezel, and the focused card's outer edge rests **221 pt** from the bezel. A ramp reaching up to ~200 pt inside from the bezel therefore leaves the focused card essentially untouched.

### F.1 Curve and geometry (`RowEdgeEffectStyle.swift`)

```swift
/// F (Steven beta.19-rc1 verdict, 2026-10-03): the one edge-fade curve, shared by the row mask and
/// the folder page's vertical fades. Smootherstep: zero slope at both ends, so there is no knee
/// where the ramp meets the solid part or the bezel.
nonisolated enum EdgeFadeCurve {
    static func alpha(_ u: Double) -> Double              // t = clamp(u); 6t⁵ − 15t⁴ + 10t³
    static func stops(rising: Bool) -> [Gradient.Stop]    // 9 stops at 0, 0.125 … 1
}
nonisolated enum RowEdgeFade {
    /// Measured from the BEZEL inward: with the standard 140 pt margin it starts 110 pt inside the
    /// row frame. If the Wave-0 measurement finds a focused card closer to the edge, lower THIS.
    static let rampLength: CGFloat = 250
}
```

Pinned values (L = 250, d = distance from the bezel):

| d | 0 | 50 | 100 | 125 | 140 (frame edge) | 186 | 201 | 221 (focused card edge) | 250 |
|---|---|---|---|---|---|---|---|---|---|
| alpha | 0 | 0.058 | 0.317 | 0.500 | 0.611 | 0.890 | 0.945 | 0.987 | 1 |

`RowSoftEdgeMask`:
- `segments(width:margins:rampLength:restClipAllowance:leadingActive:)`, with `L = min(rampLength, side margin + width / 2)` per side.
- Scrolled leading: `[-m.leading, -m.leading + L] rampIn`.
- Leading at rest: unchanged (BUG-92: the first card is never faded at offset 0).
- Then `solid` up to `width + m.trailing − L`, and `rampOut [width + m.trailing − L, width + m.trailing]`.
- Ramps draw `LinearGradient(stops: EdgeFadeCurve.stops(rising:))`.
- Vertical overdraw (critique #12): `static let verticalOverdraw: CGFloat = 72`, replacing `-400`. It covers the focus lift (20) + shadow radius (22) + shadow y (10) + ring (4) + 16 slack. Everything the mask draws stays inside, and the offscreen pass shrinks to the row's own height + 144 pt.

### F.2 Setting, migration, modifier, environment

```swift
nonisolated enum RowEdgeFadeSetting: String, CaseIterable {
    case soft      // app-drawn eased mask, system scroll-edge effect hidden. DEFAULT (see the F.5 gate).
    case system    // tvOS's own .automatic scroll-edge effect
    case off       // scrollEdgeEffectHidden(true), no mask
    static let defaultsKey = "row_edge_fade"
    static let legacyKey = "debug.rowEdgeFade"
    static let defaultValue: RowEdgeFadeSetting = .soft
    static func resolve(_ raw: String?) -> RowEdgeFadeSetting      // unknown/nil → defaultValue
    /// Christian 2026-10-03: only an explicit old "Off" (3) survives as `.off`; 0/1/2 land on the
    /// default. The legacy key is removed. Never overwrites an existing `row_edge_fade`.
    static func migrateLegacy(_ defaults: UserDefaults)
}
```

- The migration runs in `NuvioTVApp.init` (`NuvioTVApp.swift:56-80`), after the `register(defaults:)` line.

Environment (critique #13), defined in `RowEdgeEffectStyle.swift`:

```swift
/// F: the distance from a row ScrollView's frame edges to the visible screen edges (a nav rail's
/// edge counts as the leading screen edge). Every row reads it through `rowEdgeEffectStyle()`, so a
/// host with different chrome (the Stage strip with the rail Always Visible) sets it ONCE on its
/// container and no row type changes.
nonisolated struct RowEdgeMargins: Equatable, Sendable {
    var leading: CGFloat; var trailing: CGFloat
    static var standard: RowEdgeMargins { .init(leading: RowSoftEdgeMask.margin, trailing: RowSoftEdgeMask.margin) }
}
extension EnvironmentValues {
    @Entry var rowEdgeMargins: RowEdgeMargins = .standard
    @Entry var rowEdgeRampLength: CGFloat = RowEdgeFade.rampLength
}
```

`RowEdgeEffectStyleModifier` (`:56-129`):
- Reads `@AppStorage(RowEdgeFadeSetting.defaultsKey)` (LIVE), `@Environment(\.rowEdgeMargins)` and `@Environment(\.rowEdgeRampLength)`.
- Optional explicit `margins`/`rampLength` parameters override the environment when non-nil.
- Style: `.automatic` for system, `.soft` (inert) otherwise. `scrollEdgeEffectHidden(setting != .system, for: .horizontal)`. Mask only for `.soft`. The identity rules at `:88-95` are unchanged.
- DEBUG probe: `row_edge_fade_probe mode=<raw> ramp=<L> margin=<leading>`.

The API keeps its name, so the existing calls compile unchanged:

```swift
func rowEdgeEffectStyle(leadingClipAllowance: CGFloat = 0, margins: RowEdgeMargins? = nil, rampLength: CGFloat? = nil) -> some View
```

`CatalogRowView` (`BrowseComponents.swift:4791-4794`, `:5007`; W2-F, `CatalogRowView` edge lines only):
- `@AppStorage(RowEdgeFadeSetting.defaultsKey) private var rowEdgeFade = RowEdgeFadeSetting.defaultValue.rawValue`.
- `:5007`: `RowEdgeFadeSetting.resolve(rowEdgeFade) == .soft ? RowLeadingEdgeClip.softModeAllowance : leadingEdgeAllowance`.
- Fix the doc at `:4791-4793`; comment-only touch on `RowLeadingEdgeClip.swift:117-120`.

### F.3 Where the fade applies

| Surface | Change | Owner |
|---|---|---|
| Home catalog rows, CW, Upcoming, Home collection row, Search rows | none (they inherit the default through the existing call) | — |
| Detail Cast / More Like This / Collection / Trailers & Extras | `.rowEdgeEffectStyle()` right after `.scrollClipDisabled()` at `DetailView.swift:2178, 2210, 2337, 2482` | W3-D |
| Detail Episodes (Christian: yes) | `.rowEdgeEffectStyle()` after `.scrollClipDisabled()` at `EpisodesSection.swift:87` (season posters) and `:151` (episodes). The text season-chip row (`:90`) has no `scrollClipDisabled`, so it is left alone. | W3-D |
| Folder page chips row | `.scrollClipDisabled()` + `.rowEdgeEffectStyle()`; the grid's vertical fades are in C | W2-F |

### F.4 Settings (all edits by W2-F, critique #16)

- **Appearance** (`Settings/AppearanceSettingsPane.swift`): `@AppStorage(RowEdgeFadeSetting.defaultsKey) private var rowEdgeFade`. After "No Zoom on Focus" (`:189-194`), add a `SettingsPickerRow` titled "Row Edge Fade":
  - options `RowEdgeFadeSetting.allCases.map(\.rawValue)`, labels "Soft" / "System" / "Off" (all four strings already exist, translated);
  - `descriptionID: .appearanceRowEdgeFade`, `.accessibilityIdentifier("appearance_row_edge_fade")`;
  - comment tag `F`.
- **SettingsDescriptions** (`Settings/SettingsDescriptions.swift`):
  - add `case appearanceRowEdgeFade = "appearance.rowEdgeFade"` with `"Fades the left and right edges of rows so posters that run off the screen blend into the background. The left edge fades only after a row has scrolled. Soft by default."`;
  - remove `devRowEdgeFade` (`:188`, `:362`);
  - rewrite `sourcesAutoPlayBest` (`:301`) per §A;
  - add spec A's M4 entry verbatim: `case homeTrailerStartDelay = "home.trailerStartDelay"` after `homeHeroTrailerAutoplay` (`:84`), copy after `:258`, with critique #29 applied: `"Sets how long trailers on posters and in the hero wait before they start. Automatic waits until the rows stop moving, then one second. Default: Automatic."`. If spec A's final text differs (Christian's answer to critique Q1 may change the counting rule), W2-F takes spec A's text verbatim. Spec A's W2-D writes only `descriptionID: .homeTrailerStartDelay` in `HomeScreenSettingsPane`.
  - Deslop every new string to 5/5.
- **Developer** (`Settings/DeveloperSettingsPane.swift`):
  - remove `@AppStorage("debug.rowEdgeFade")` and its doc (`:50-57`) and the "Row Edge Fade" picker (`:614-633`);
  - T1's `.lineLimit(1)` → `.lineLimit(2)` on the Tab Bar Geometry lines only (`:573-577`).

### F.5 Frame-time gate before the cut (critique #12)

Soft goes from an A/B to everyone's default, so every row carries a mask: an offscreen pass per row per changed frame, including an inline trailer playing inside a masked row. The gate measures it.

Instrument (W2-F, file `Screens/CollectionFocusFrameProbe.swift`, exclusive in W2):
- New launch-arg knob `debug.frameSamplerSteadyS` (Int, read once, 0 = off): a repeating `Timer` that arms a `row=steady` window every N s.
- In `CatalogRowView`'s existing `.onChange(of: focusedItemId)` (`BrowseComponents.swift:5053`), one line: `CollectionFocusFrameSampler.shared.arm(rowKey: "h:\(section.key)", gif: false)`. It is a no-op unless `debug.collectionFrameProbe` is on. Horizontal steps then get windows too; today only row hops do (`HomeView.swift:1859`).

Device run (Christian, Living Room Apple TV, **Test profile**):
- Dev build, Large posters, zoom on, inline trailers In Row.
- Launch args `-debug.collectionFrameProbe YES -debug.frameSamplerSteadyS 2 --console`.
- Two cold launches: `-row_edge_fade off`, then `-row_edge_fade soft`. Each does:
  - (a) 10 Downs + 10 Ups;
  - (b) 8 Rights + 8 Lefts on one catalog row;
  - (c) 15 s at rest on a poster whose inline trailer is playing.
- Metric per phase: the median of the windows' `p95=` and the sum of `dropped=` (`[CollectionFrameProbe] focus …` lines).

Rule:
- **Ship Soft as the default** only if, in every phase, median p95 (Soft) ≤ median p95 (Off) + **1.0 ms** AND dropped (Soft) ≤ dropped (Off) + max(2, 10 %).
- **Otherwise ship the default as Off**: `RowEdgeFadeSetting.defaultValue = .off`, one constant. Then:
  - the migration keeps its rule (old Off → off; everything else resolves to the new default, Off);
  - the Appearance row stays, so Steven can pick Soft;
  - the release notes and DM say so;
  - log a follow-up: mask only the two edge strips with a `.compositingGroup()` instead of the whole row.

### F.6 Tests

`NuvioTVTests/RowSoftEdgeMaskTests.swift` (new signature), plus:
- `testScrolledLeadingRampStartsInsideFrame` (`(-140, 110, .rampIn)`, width 1640) and `testTrailingRampStartsInsideFrame` (`(1530, 1780, .rampOut)`);
- `testRampClampsOnNarrowRows` (width 100 → L 190);
- `testAsymmetricMargins` (leading 116, trailing 140);
- `testVerticalOverdrawCoversLiftShadowRing` (≥ `heroPinnedRowFocusLiftAllowance + 22 + 10 + ringWidth`);
- keep the rest and contiguity tests.

New `NuvioTVTests/EdgeFadeCurveTests.swift`:
- `testEndpoints`, `testMonotonic` (101 samples);
- `testTablePinned` (the table above, ±0.001);
- `testFocusedCardIsBarelyTouched` (d 201 ≥ 0.94, d 186 ≥ 0.88);
- `testNineStops`.

New `NuvioTVTests/RowEdgeFadeSettingTests.swift` (an isolated `UserDefaults(suiteName:)`):
- `testUnknownResolvesToDefault`;
- `testMigrationKeepsOnlyOff`;
- `testMigrationNeverOverwritesNewKey`;
- `testMigrationNoopWithoutLegacy`;
- `testEnvironmentDefaultsAreStandard`.

UI `test70RowEdgeFadeSpike` (`NuvioTVUITests.swift:8045+`):
- Legs become `-row_edge_fade soft|system|off`; the probe assertion reads `mode=soft`.
- Pixel samples (screenshot px = pt × 2, d from the nearer bezel in pt):
  - offset 0, trailing edge: x = 3832 (d 4) ≈ background; x = 3480 (d 180) darker than Off; x = 3220 (d 310) equals Off;
  - after 12 Rights, leading edge: x = 8 ≈ background; x = 280 (d 140) partially faded; x = 560 (d 280) equals Off.
- New: the focused card's crop equals Off (mean abs diff < 3/255) apart from its outer 20 pt.

### F.7 Proof

- Simulator: test70.
- **Wave-0 measurement** (main session, decides L): at Medium+, Large and landscape rows after 8 Rights, read the focused card's outer edge distance from the bezel. Needed: ≥ 200 pt portrait, ≥ 186 pt landscape. Otherwise lower `RowEdgeFade.rampLength` until alpha at that distance ≥ 0.94, and record it.
- Device: plan item 8, plus the F.5 gate.

---

## C. Collection folder page (regression from build 133's R4)

### Root cause (confirmed)

- **Header**: `FolderDetailView.header` (`CollectionsUI.swift:1323-1340`) removes `headerContent` from the tree once `gridScrolled` flips (offset > 8, `:1253-1257`), inside a `.clipped()` fixed-height slot with a 0.3 s move+fade. On hardware it reads as a 1–2-frame cut.
- **Chips**: the chips (`:1149-1165`) are the first child of the scroll content, so they scroll away on the next press and return as steps (triage §5).
- **Skeleton**: the grey flash is each `PosterCard`'s `ShimmerView` (`CachedAsyncImage.swift:91`) for 0.25–0.5 s.

### Design: the title rises and stays, the chips pin under it, no per-frame state

Geometry: new pure `nonisolated enum FolderHeaderGeometry` (in `CollectionsUI.swift`, or a new `Screens/FolderHeaderGeometry.swift`):

```
T  = Theme.Spacing.screen − Theme.Spacing.lg − Theme.Spacing.xxs   // 32, today's header top
Lf = Theme.Size.heroLogoSlotHeight                                  // 150
Tc = Theme.Spacing.sm                                               // 12, compact top
Lc = 64                                                             // compact logo slot
g  = Theme.Spacing.md                                               // 16
F  = 36                                                             // top fade under the chips
R  = (T − Tc) + (Lf − Lc) = 106                                     // scroll distance of the rise
contentSpace = "folderContent"
static func progress(scrolled s:) -> CGFloat      // clamp(s / R, 0, 1)
static func logoScale(scrolled s:) -> CGFloat     // lerp(1, Lc/Lf, p)
static func logoOffsetY(scrolled s:) -> CGFloat   // s ≤ 0: 0; else lerp(T, Tc, p) − T + s
static func pinnedOffsetY(scrolled s:) -> CGFloat // max(0, s − R)
static func phase(scrolled s:) -> Int             // Int(p × 4), probe only
```

Layout of `FolderDetailView.body` (`:1131-1278`; replaces the exit logic at `:1323-1404`):

```
ZStack(alignment: .top) {
  background
  VStack(spacing: 0) {
    // 1. Ghost of the COMPACT block (layout only), height Bc = Tc + Lc + g + C + F:
    //    VStack(spacing: g) { Color.clear(Tc + Lc); chipsRow(bindsFocus: false).hidden()
    //    .disabled(true).accessibilityHidden(true) [tabs > 1]; Color.clear(F) }
    // 2. ScrollView(.vertical) {
    //      VStack(alignment: .leading, spacing: 0) {
    //        header.frame(height: R, alignment: .bottom).zIndex(1)   // content overflows UP by Bc
    //        grid … (top padding heroPinnedRowFocusLiftAllowance + Theme.Spacing.sm = 32)
    //      }.coordinateSpace(.named(FolderHeaderGeometry.contentSpace))
    //    }
    //    .scrollClipDisabled()
    //    .onScrollGeometryChange(Bool, > 8) → gridScrolled        // kept: Edit Filters only
  }
  editFiltersOverlay
}
header = ZStack(alignment: .top) {
  band
  VStack(spacing: g) { logoSlot (.padding(.top, T), height Lf); chipsRow(bindsFocus: true) [tabs > 1]; Color.clear(F) }
}
```

- **Scroll amount**: `s = proxy.frame(in: .named(contentSpace)).minY − proxy.frame(in: .scrollView(axis: .vertical)).minY`, computed by each moving piece from its own proxy inside its own `.visualEffect`. No nested `visualEffect`, and no constants.
- **Logo** (`TitleLogoHeader`, centred, `alignment: .top`, `slotHeight: Lf`, I1 row 9b): `.visualEffect { content, proxy in … content.scaleEffect(logoScale(s), anchor: .top).offset(y: logoOffsetY(s)) }`.
- **Chips row and band**: each has its own `.visualEffect { … .offset(y: pinnedOffsetY(s)) }`. At `s = R` the chips' top is `Tc + Lc + g`, the compact position.
- **Band**: opaque `Theme.Palette.background` from 600 pt above the header down to the chips' bottom (with ≤ 1 tab, to the logo slot's bottom + g), then an `F` pt `LinearGradient(stops: EdgeFadeCurve.stops(rising: false))` of the background colour. Grid cards pass under it (`zIndex(1)`; the paint-order note at `:1302-1313`).
- **Rest geometry**: `Bf − Bc = R`, so at rest the first grid row sits within ~12 pt of today's.
- **Bottom fade**: a page overlay outside the scroll, `.allowsHitTesting(false)`, bottom-aligned, ignoring the bottom safe area. 60 pt high, `EdgeFadeCurve` stops from clear to solid background.
- **Edit Filters**: moves to `editFiltersOverlay` (top-trailing, `.padding(.top, T)`, `.padding(.trailing, Theme.Spacing.screen)`). It fades on the existing Bool crossing (0.2 s; `reduceMotion` → nil); `.disabled(gridScrolled)` and `folder.editFilters` are unchanged.
- **Chips row** (critique #22): `private func chipsRow(bindsFocus: Bool) -> some View`. Only the real one carries `.focused($focusedChip, equals: index)` (`@FocusState private var focusedChip: Int?`, probe only). Its horizontal `ScrollView` gains `.scrollClipDisabled()` + `.rowEdgeEffectStyle()`.
- **Delete**: `headerHeight`, the `if !gridScrolled` branch, its transition/animation, the `.clipped()` slot and the 24 pt header gradient (`:1385-1394`).
- **Accessibility**: the title stays in the tree. `folder_header` moves to the real header container; its AX (layout) frame equals the visual frame at rest.
- **Focus**: Down from a chip reaches grid row 1. Up from grid row 1 reaches the chips (the engine reveals their layout frame, which scrolls partway back; the partial rise is stable). No programmatic scroll.
- **Skeleton flash**: `@State private var gridRevealed = false`; grid `.opacity(gridRevealed ? 1 : 0)`. On the first non-empty `model.items` and on each `selectedTabIndex` change:
  ```swift
  Task {
      await ArtworkStore.prefetchAndWait(first12PosterURLs.map { ArtworkURLUpgrade.upgraded($0, role: .poster) ?? $0 },
                                         decode: PosterCard.decodeRequest(width: posterStyle.width, height: posterStyle.height, scale: displayScale),
                                         timeout: 0.45)
      withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { gridRevealed = true }
  }
  ```
  It warms exactly the URL and bucket the card will ask for (critique #22). Reset `gridRevealed = false` without animation at a tab change. One write per load.
- **DEBUG probe** (`:1260-1270`): `folder_header_state scrolled=<0|1> phase=<0…4> chip=<index|-> reveal=<0|1>`. `phase` comes from an Int-transform `onScrollGeometryChange` (5 buckets).

### Tests

New `NuvioTVTests/FolderHeaderGeometryTests.swift`:
- `testRestIsIdentity`;
- `testRiseMidway` (s 53 → scale ≈ 0.713, logo offset 43);
- `testCompactAtR` (s 106 → scale 64/150, logo offset 86, phase 4);
- `testPinnedPastR` (s 306 → pinned 200);
- `testOverscrollMovesWithContent` (s −40 → 0, scale 1);
- `testRIs106`.

**Seeding** (coordinator note; on `284fd764` FA87 test69 SKIPPED with "no folder/collection tile focused within 45 Down presses"):
- **Helper**: `private func launchToHomeWithSeededCollections(_ json: String, extraArguments: [String] = []) -> XCUIApplication`, next to test42 (`NuvioTVUITests.swift:3817`). It returns `launchToHome(extraArguments: ["-debug.collectionsSeedJsonB64", b64] + extraArguments, forceFreshLaunch: true)`.
- **Seed** (pinned, two Cinemeta sources + All tab = three chips; Cinemeta's manifest id matches `CollectionCatalogResolver.kt:16`):
  ```json
  [{"id":"zzfolderprobe-collection","title":"ZZFolderProbe","pinToTop":true,"showAllTab":true,
    "folders":[{"id":"zzfolderprobe-folder","title":"ZZFolderProbeFolder","hideTitle":false,
      "sources":[{"provider":"addon","addonId":"com.linvo.cinemeta","type":"movie","catalogId":"top"},
                 {"provider":"addon","addonId":"com.linvo.cinemeta","type":"series","catalogId":"top"}]}]}]
  ```
- **Teardown**: the import replaces and persists the profile's collections (`CollectionRepository.kt:153-166`), so the `defer` relaunches with the seed `[]` (base64 `W10=`, which `validateImportModel` accepts).
- **The guard at `:3871` checks the wrong thing**: on today's FA87, "Chris" is the LOCAL guest profile. The real risk is a signed-in cloud account syncing the import upward. Fix it at the source: `HomeViewModel.applyCollectionsSeedIfRequested` (`HomeViewModel.swift:841-866`, DEBUG) imports only when `AuthRepository.shared.state.value` is `AuthStateUnauthenticated`, or `AuthStateAuthenticated` with `isAnonymous == true` (the `isCloudAccount` test at `ProfilesViewModel.swift:40-43`). Otherwise it logs `[CollectionsSeed] imported=false refused=signedIn|authLoading` and returns without latching. The helper needs no harness guard; test42 may switch to it.

**test69** (renamed `test69FolderHeaderRisesAndStays`):
1. Walk Down until `fitem` contains `nuvio-folder://` (existing loop). Skip text: "seeded collection not on Home — seed refused (signed-in cloud account?) or not imported".
2. Select.
3. Assert `reveal=1` within 1.5 s, `scrolled=0 phase=0`, and that `staticTexts["ZZFolderProbeFolder"]` exists. Record `headerBefore`.
4. Keep the first-tile overlap check.
5. Down ×6. Assert `phase=4 scrolled=1` and that the title text still exists.
6. **Pixels** (XCUITest frames ignore offset/scale): in an `XCUIScreen.main.screenshot()`, the compact title band y ∈ [Tc, Tc + Lc] pt, centre ±300 pt, has ≥ 1 % of pixels differing from the background by > 40/255; the chips band y ∈ [Tc + Lc + g, Bc − F] shows chip capsules. Use test70's pixel helper.
7. Up until `chip=` ≠ `-` (≤ 14).
8. Up until `scrolled=0 phase=0`. The `folder_header` frame equals `headerBefore` (±2 pt).

### Proof

Simulator: test69 seeded on FA87, with screenshots at phases 0/2/4. Device: plan item 5 in the **Test profile**, with a collection payload installed there and removed afterwards.

---

## T1. Tab bar stuck half-visible after launch (BUG-66 residual)

### What the code says (confirmed)

- `TabBarStateProbe.sample` (`DesignSystem/TabBarStateProbe.swift:277-350`) reports `st=part` when the bar is neither full nor collapsed. UIKit moves a linked bar 1:1 with the tracked offset, so Steven's `y=-13 st=part` means the tracked view rested 13 pt off its baseline.
- `TabBarContentScrollLinkAttacher.LinkView.apply` (`DesignSystem/TabBarContentScrollLink.swift:161-215`) links (`:185-187`) BEFORE switching the pinned rows to `.never` (`:188-190`). That is hypothesis H2, a skewed baseline.
- Hypothesis H1 is a first-row rest a few points deep: `PinnedRowSettle.topRestExempt` (`BrowseComponents.swift:2375-2377`) covers only `offsetY ≤ 0.5`.
- `ins=` is NSLog-only today; the offset is logged nowhere.
- The 08-27 ban (`docs/traces-2026-08-27-bug66-upcoming.md:237-239`, `TabBarContentScrollLink.swift:22-27`): no scroll-driven `.toolbarVisibility`, no `.safeAreaInset` hero, no hero-refocus completion scroll. Both legs respect it.

### Design (W3-T, Opus)

**Probe**:
- `composeLine` (`:253-265`) gains `offset: CGFloat?, inset: CGFloat?` and emits `off=<Int|->` and `ins=<Int|->` right after `st=`. `off` is clamped to ±9999, `ins` to ±999; update the length note at `:30-37` (~110 chars).
- `sample` reads `TabBarContentScrollLink.homeRowsScrollView`'s `contentOffset.y` and `adjustedContentInset.top`.
- The pane's `.lineLimit(2)` change is W2-F's (§F.4).

**Knob**: `nonisolated enum TabBarRestFix { static let leg: Int = UserDefaults.standard.integer(forKey: "debug.tabBarRestFix") }` in `TabBarContentScrollLink.swift`.
- 0 = today, **the shipped default (Christian 2026-10-03: both legs off until the device session picks one)**;
- 1 = relink;
- 2 = top-rest snap.

**Leg 1, relink** (`TabBarContentScrollLink.swift`):
- With leg 1, `apply()` sets `.never` BEFORE `setContentScrollView`. Leg 0 keeps today's order byte-for-byte.
- On `didMoveToWindow`, once per mount, a `Task { @MainActor }`:
  - waits for the first `UIFocusSystem.didUpdateNotification`;
  - polls every 0.25 s (≤ 6 s) until `PinnedRowSettle.isRestPending` (`BrowseComponents.swift:4296-4298`) has been false on two consecutive polls;
  - then: `setContentScrollView(nil, for: .top)` on every linked controller still reporting the view, and on the next main-queue turn `setContentScrollView(scrollView, for: .top)`;
  - logs `[TabBarLink] relinked reason=firstRest off=<y> ins=<top>` and calls a new `TabBarStateProbe.noteRelinked()` (`r=relink`).
- Cancel the task in `willMove(toWindow: nil)` and `tearDown()`.

**Leg 2, top-rest snap** (`BrowseComponents.swift`, `PinnedRowSettle` only):
- New pure helper next to `:2375`:
  ```swift
  nonisolated static func topSnapApplies(leg: Int, offsetY: CGFloat, rowContentTop: CGFloat, headroom: CGFloat) -> Bool {
      leg == 2 && offsetY > 0.5 && offsetY <= topSnapMax && rowContentTop <= headroom + 1
  }
  nonisolated static let topSnapMax: CGFloat = 48
  ```
  `rowContentTop = m.rowTop + sample.offsetY`; `headroom = Theme.Size.heroPinnedRowsHeadroom` (8).
- In `settlePlan`, after the `topRestExempt` branch (`:3873-3878`) and before `guard deficit > 0` (`:3889`), build the plan through the ordinary correction tail (`:4086-4133`) with `target = 0` and the report token `topSnap=1`. The next settle hits `topRestExempt`. The verify/pull-back ledger handles an engine undo.
- Leg 2 needs a focused row (`settlePlan` returns `state=nofocus` otherwise). A half-shown bar while focus is on the hero CTA can only be fixed by leg 1 (critique #21).

### Tests

- `NuvioTVTests/TabBarContentScrollLinkTests.swift`: update the `composeLine` cases, and add `testComposeLineCarriesOffsetAndInset`, `testComposeLineDashesWithoutRows` and `testComposeLineClamps`.
- New `NuvioTVTests/PinnedRowTopSnapTests.swift`: `testLeg0NeverSnaps`, `testSnapsFirstRowSmallOffset`, `testNoSnapAtZero`, `testNoSnapBeyondMax`, `testNoSnapForLaterRows`.
- UI: no new leg (the sim cannot show the bar regime, `docs/research/bug66-sim-rig-2026-08-27/`). Regression: test58/63/64/65 green with `-debug.tabBarRestFix 2`. With `-debug.tabBarStateProbe YES -debug.tabBarRestFix 1`, `tab_bar_state_probe_blob` contains `off=` and `r=relink`.

### Device decision (Christian, **Test profile**, one session)

- Dev build with `-debug.tabBarStateProbe YES -debug.homeScrollProbe YES -debug.pinnedRowSettleProbe YES --console`.
- Three cold launches: `-debug.tabBarRestFix 0`, `1`, `2`.
- Per launch, **two pane photos** (critique #21): at rest on the hero 5 s after launch, then after one Down to row 1 and 3 s.

| Leg 0 reads | Meaning | Ship |
|---|---|---|
| `st=part off≈13 ins=0` (after Down) | H1 | leg 2 if its photo reads `st=exp off=0` with `topSnap=1` in the log |
| `st=part off=0 ins=0` (either photo) | H2 | leg 1 if `st=exp` after `r=relink` |
| `st=part` on the hero photo only | leg 2 cannot act there | leg 1 |
| `st=exp`/`st=min` | does not reproduce on Christian's Apple TV | keep 0; Steven gets a build with both legs named, one photo pair per leg |

The winner becomes the default in a one-constant follow-up commit.

---

## A. Auto-Play Best Source: real ranking (W3-A, Sonnet)

### Root cause (confirmed)

- The setting (`Settings/SourcesSettingsPane.swift:20-24`) sets the shared `streamAutoPlayMode` to `FIRST_STREAM` (tvOS-namespaced blob).
- `StreamAutoPlaySelector.evaluateAutoPlayStream` (`shared/.../streams/StreamAutoPlaySelector.kt:66-195`) takes the first auto-playable stream in list order (`:130`, `:166-178`). The list is debrid groups, then add-ons in installed order, then plugins (`StreamsRepository.kt:350-363`, `orderAddonStreams` `:7-33`).
- On tvOS each group already passes the Sources filters (`StreamsRepository.kt:418-428`, `TvOsProviderInstaller.kt:145`).
- The parsing to reuse already exists: `DebridStreamMetadata.facts` (`shared/.../debrid/DebridStreamPresentation.kt:314-345`, `internal`).
- The tvOS walk (`FirstPlayAutoPlay.swift`, `Policy.snapshot` `:366-372`) follows `autoPlayStream` then `autoPlayCandidates`, so a ranked `readyStreams` ranks both the first pick and the failover.

### Design

New `shared/src/commonMain/kotlin/com/nuvio/app/features/streams/StreamAutoPlayRanking.kt`:

```kotlin
/** A (Steven beta.19-rc1 verdict, 2026-10-03): how FIRST_STREAM orders the streams that arrived. */
enum class StreamAutoPlayRanking { LIST_ORDER, BEST_QUALITY }

/** Platform seam like [StreamPresentationPlatform]: tvOS sets BEST_QUALITY at bootstrap; mobile
 *  keeps LIST_ORDER, so mobile behaviour does not change. */
object StreamAutoPlayPlatform { var firstStreamRanking: StreamAutoPlayRanking = StreamAutoPlayRanking.LIST_ORDER }

/** Best = resolution > DV/HDR (one tier) > cached > size; stable for full ties. */
object StreamQualityRank {
    data class Key(val resolution: Int, val dynamicRange: Int, val cached: Int, val size: Long)
    fun key(stream: StreamItem): Key   // facts(stream, DebridStreamPreferences()); HDR tier = DV, DV_ONLY, HDR_DV, HDR,
                                       // HDR10, HDR10_PLUS, HLG, HDR_ONLY; cached = isAddonDebridCandidate &&
                                       // (isDirectDebridStream || isCachedDebridTorrentStream); size = facts.size ?: 0
    fun rankBest(streams: List<StreamItem>): List<StreamItem>  // keys computed once, stable descending sort
}
```

- `UNKNOWN` resolution has `value` 0 (`DebridSettings.kt:146`), so it ranks last.
- `selectAutoPlayStream` and `evaluateAutoPlayStream` gain a last parameter `ranking: StreamAutoPlayRanking = StreamAutoPlayRanking.LIST_ORDER`. The `FIRST_STREAM` branch (`:130`) becomes `if (ranking == StreamAutoPlayRanking.BEST_QUALITY) StreamQualityRank.rankBest(candidateStreams) else candidateStreams`. Regex, manual and binge-group paths are unchanged; the preferred binge-group stream stays first (`:166-170`).

Callers:
- `StreamsRepository.kt:350-363` and `debrid/DirectDebridStreamPreparer.kt:83-91`: `ranking = StreamAutoPlayPlatform.firstStreamRanking`.
- `appleMain/.../TvOsProviderInstaller.kt` after `:145`: set `BEST_QUALITY`.
- Swift `Screens/NextEpisodeAutoPlay.swift:689-702`: Kotlin defaults do not bridge, so pass `ranking: (effectiveMode == StreamAutoPlayMode.firstStream && !manualAutoSelect) ? StreamAutoPlayPlatform.shared.firstStreamRanking : StreamAutoPlayRanking.listOrder`.

Copy (deslop to 5/5):
- Section footer (`SourcesSettingsPane.swift:17`, W3-A): `"Play starts the best source that has arrived: highest resolution first, then HDR or Dolby Vision, then cached links, then the largest file. Hold Play to choose one."`
- Description `sourcesAutoPlayBest`: written by **W2-F** (§F.4): `"A plain press of Play starts the best source found so far: highest resolution, then HDR or Dolby Vision, then cached, then file size. Your source filters still apply. Hold Play to choose a source yourself. Off by default."`
- Critique #28, for the reply DM and the release notes: "the largest file breaks ties", which can mean a REMUX with TrueHD (AAC on the native path) over a WEB-DL with Atmos. That is the approved order; no code change.

### Tests

New `shared/src/commonTest/kotlin/com/nuvio/app/features/streams/StreamAutoPlayBestQualityTest.kt` (**jvmTest and tvosSimulatorArm64Test**). The builders are as in r1: plain streams with `behaviorHints.videoSize`; cached torrents with `debridCacheStatus = StreamDebridCacheStatus("realdebrid", "Real-Debrid", CACHED)`, `debridEnabled = true`, `activeResolverProviderId = "realdebrid"`. Cases:
- `higherResolutionWinsAcrossGroups` (and `LIST_ORDER` keeps the first);
- `hdrWinsAtSameResolution` (the Lizzie Borden case);
- `resolutionOutranksHdr`;
- `dolbyVisionAndHdrShareOneTier`;
- `cachedWinsAtSameResolutionAndRange`;
- `sizeBreaksRemainingTies`;
- `fullTieKeepsListOrder`;
- `untaggedResolutionRanksLast`;
- `preferredBingeGroupStaysFirst`;
- `regexModeIgnoresRanking`;
- `readyStreamsAreRankedForFailover`;
- `defaultRankingIsListOrder`.

Proof: Kotlin tests on the simulator; on the device, plan item 10 (Lizzie Borden in the **Test profile**: `[AutoPlay] pick #1` plus the Info tab's HDR/DV chip).

---

## D. Detail page items (W3-D, Sonnet)

### D1. Action-button labels untranslated (confirmed)

`DetailView.actionLabel(_ title: String, …)` (`:2119-2126`) uses `Label(String, …)`, which never looks the string up. The literals at `:1885`, `:1967`, `:1982`, `:2000` all have translated keys.

Change:
- `actionLabel(_ title: LocalizedStringResource, systemImage:, primary:)`, which uses `String(localized: title)` for the `Label` and for the icon-only `accessibilityLabel`. Plus `actionLabel(verbatim: String, …)` for the Kotlin-localized `action.label` (`SeriesContinuity.kt:209-216`). Both share one private body.
- `:1885`: `model.isPlayEnabled ? "Play" : "Playback unavailable"`.
- `:1916`: an `if/else` between `actionLabel(verbatim: action.label, …)` and `actionLabel("Playback unavailable", …)`, wrapped in a `Group` that keeps `.font(Theme.Font.meta).prominentAccentLabel()`.
- `:2026-2028`: `"Shuffle On"` / `"Shuffle"`.
- `:2105`: `"Start Over"`.

Status values: `nonisolated enum DetailStatusText { static func localized(_ raw: String?) -> String? }` in `Detail/DetailAboutSection.swift`:
- case-insensitive, trimmed;
- released, ended, returning series, canceled/cancelled, in production, planned, post production, rumored, pilot and continuing map to `String(localized:)` keys;
- unknown passes through; blank → nil;
- used at `DetailAboutSection.swift:37` and Classic `infoRows` (`DetailView.swift:2260`).

Tests (`DetailAboutRowsTests.swift`): `testStatusKnownValuesMap`, `testStatusUnknownPassesThrough`, `testStatusNilAndBlank`.

Proof: on FA87 with `-AppleLanguages "(fr)"`, a Detail screenshot shows French button labels and the About status.

### D2. One glass rule: scrolling never changes glass

- `chipGlassFlat` (`:1433-1442`) is `trailerActive || scrolling || glassDisabled`. The chips (Classic `metaChip` `:1810-1823`; parental-guide chips `:2428`, in both layouts) and Classic's synopsis panel (`:1446-1449`) go flat while scrolling and snap back about 150 ms later (video 3:39.9). The buttons never change.
- "Neither" is chosen because:
  - flattening the buttons means swapping their style on a FOCUSED button (identity change, `:1826-1862`) or replacing the system glass focus look;
  - the scroll input was an unproven BUG-41 candidate;
  - Cinematic has no glass meta chips.
- Change: `chipGlassFlat(trailerActive:glassDisabled:)` and `panelUsesFlatFill(trailerActive:glassDisabled:)` (`:1446-1449`, `:3000-3002`) drop `scrolling`. The instance property stops reading `dimModel.isScrolling`, which also removes two body invalidations per scroll. Classic's panel now follows the chips (Christian: OK). `ScrollDimOverlay`'s signature and the `debug_ux6 scrolling=` token stay.
- Rewrite the doc comments at `:1315-1326` and `:1734-1748`. Documented remaining edge: with a background trailer playing, the chips flatten (trailer rule) and the buttons stay glass, a steady state rather than a scroll transition.

Tests:
- `DetailScrollProbeTests.swift:70-108` becomes a 4-row table over (trailer, glassDisabled). The scrolling-only case at `:103` is deleted rather than replaced by a signature check (critique #18: vacuous).
- `DetailScrimTests.testPanelFlatTruthTable`: 4 rows, panel == chips.

Proof (critique #18):
- **test33** (`test33SeasonPosterRow`, which opens a series Detail on FA87) gets a Classic leg with `-detail_layout classic`. Read `debug_ux6`'s `glass=` before a Down scroll, during it (immediately after the press) and 1 s after; all three are `glass=0`. On the base build the middle read is `glass=1`.
- Device: add `[BUG41] hitches=` for D2 vs base on *Drop* (Classic and Cinematic) to the device pass.

### D3. Lighter Cinematic scrim

| Constant | Today | New |
|---|---|---|
| `cinematicHorizontalLeading` | 0.55 | **0.30** |
| `cinematicHorizontalMid` | 0.15 | **0.06** |
| `cinematicHorizontalTrailing` | 0.00 | 0.00 |
| `cinematicHorizontalTrailingOverPoster` | 0.10 | **0.06** |
| `cinematicVerticalClearUntil` | 0.60 | 0.60 |
| `cinematicVerticalBottom` | 0.60 | **0.55** |
| `cinematicRadialOpacity` | 0.55 | **0.50** |
| `cinematicRadialEndRadiusFraction` | 0.70 | **0.62** |

Composite darkness (existing math, 21×21 grid):

| Region | Today | New |
|---|---|---|
| top-left | 0.599 | 0.332 |
| bottom-left | 0.919 | 0.843 |
| synopsis/meta block (x 0.03–0.30, y 0.55–0.75), mean | 0.646 | 0.485 |
| same block, minimum | 0.477 | 0.311 |
| art region (x 0.5–1, y 0–0.6), mean | 0.081 | 0.031 |

The new stops are ≤ today's and ≤ Classic's everywhere. The darkness now sits under the text column.

Tests (`DetailScrimCinematicTests.swift`):
- `testCinematicStops` (new values);
- `testCompositeSpotValues` (bottom-left 0.8425; top-right with the poster layer 0.06, without 0);
- keep `testCinematicNeverDarkerThanClassic`;
- new `testLighterThanBuild284Everywhere` (old stops as literals in the test);
- new `testTextBlockFloor` (mean ≥ 0.45);
- new `testArtRegionMostlyClear` (mean ≤ 0.04).

Device: plan item 4's Detail visit, on bright art (Oak Street) and red art (Monstre).

---

## P. Player overlay copy (W3-A)

- **Root cause (confirmed)**: `NativePlaybackCoordinator.preparingLabel` (`Screens/NativePlaybackCoordinator.swift:47`, `@Published`) is initialised to "Preparing Dolby Vision…" and never reassigned. It shows for every native-engine file (SDR and HDR10 too; `PlayerEngineRouter.swift:28-113`).
- **Change** (one file):
  - default `String(localized: "Preparing playback\u{2026}")`;
  - new pure `nonisolated enum NativePreparingLabel { static func isDolbyVision(_ s: VideoSignaling?) -> Bool; static func text(for:) -> String }`, where DV = `codecs` prefixed `dvh1`/`dvhe`, or `supplementalCodecs != nil`;
  - `pollForFirstSegment` (`:450-468`) calls a private `updatePreparingLabel(remux.videoSignaling)` each iteration, assigning only on change.
  - A DV file flips once within the first few hundred ms.
- **Tests**: new `NuvioTVTests/NativePreparingLabelTests.swift` with `testNilIsPlayback`, `testHevcHdr10IsPlayback`, `testP8SupplementalIsDV`, `testP5CodecIsDV`, `testDvheIsDV`.
- **Proof**: device only (an HDR10 file and a DV file).

---

## 8. Executors: the merged wave plan (critique), this spec's share

≤ 3 agents per wave, one owner per file per wave. Agents edit; the main session builds, tests and commits.

| Wave | Agent | Tier | This spec's items | Files (exclusive in the wave) |
|---|---|---|---|---|
| W1 | **W1-B** | Sonnet | I1.1–I1.6 + I1.8 (core, URL upgrade incl. metahub `large` and logos `original`, lookup contract, pools, probe, call sites 3, 4, 5, 7, 9, 9a, 12), Kotlin w780 incl. `:1274/:1337/:1374` + grep gate, `PosterCard.decodeRequest`, `screenScale` seed | `DesignSystem/ArtworkDecodeSize.swift` (new), `DesignSystem/ArtworkURLUpgrade.swift` (new), `CachedAsyncImage.swift`, `PosterCard.swift`, `SagaCard.swift`, `TitleLogoHeader.swift`, `ArtworkColorStore.swift`, `Detail/DetailCinematicHero.swift`, `StreamPickerView.swift` (`:236` only), `NuvioTVApp.swift` (seed line only), `ArtworkDecodeMathTests`, `ArtworkURLUpgradeTests`, `ImageFallbackPlanTests`; `shared/…/tmdb/TmdbImageSizes.kt` (new), `TmdbMetadataService.kt`, `collection/TmdbCollectionSourceResolver.kt`, `TmdbImageSizesTest.kt` |
| (W1) | spec A W1-A (Opus), W1-C (Sonnet) | | — | — |
| Gate 1 | main | | Debug build, NuvioTVTests, Kotlin jvm + K/N; **metahub `large` size decision (§I1.9 step 2)**; Wave-0 F measurement | |
| W2 | **W2-F** | Opus | F (all), C (all), every `SettingsDescriptions` edit (F, A copy, spec A M4 with #29), Developer pane (F removal, T1 `lineLimit(2)`), frame-sampler steady knob + horizontal arming, I1 rows 6 and 9b, F migration | `RowEdgeEffectStyle.swift`, `RowLeadingEdgeClip.swift`, `BrowseComponents.swift` (`CatalogRowView` edge lines + the `:5053` sampler line), `CollectionsUI.swift`, `CollectionFocusFrameProbe.swift`, `Settings/AppearanceSettingsPane.swift`, `Settings/DeveloperSettingsPane.swift`, `Settings/SettingsDescriptions.swift`, `NuvioTVApp.swift`, `HomeViewModel.swift` (seed guard), `NuvioTVUITests.swift` (seed helper, test69, test70), `RowSoftEdgeMaskTests`, `EdgeFadeCurveTests`, `RowEdgeFadeSettingTests`, `FolderHeaderGeometryTests` |
| (W2) | spec A W2-D (Sonnet), W2-E (Opus) | | — | — |
| Gate 2 | main | | Build, NuvioTVTests, test69 (seeded) + test70 on FA87; device session 1 (Test profile): **F.5 frame-time gate**, spec A's B1 | |
| W3 | **W3-T** | Opus | T1 | `TabBarContentScrollLink.swift`, `TabBarStateProbe.swift`, `BrowseComponents.swift` (`PinnedRowSettle` only), `TabBarContentScrollLinkTests`, `PinnedRowTopSnapTests` (new) |
| W3 | **W3-D** | Sonnet | D1, D2 (with the test33 Classic leg), D3, F on the four Detail rows + Episodes rows, I1 rows 1, 2, 8, 10, 11 | `DetailView.swift`, `Detail/DetailAboutSection.swift`, `Detail/DetailSynopsisSheet.swift`, `TrailerBridge.swift`, `EpisodesSection.swift`, `DetailScrim*Tests`, `DetailScrollProbeTests`, `DetailAboutRowsTests`, `NuvioTVUITests.swift` (test33 only) |
| W3 | **W3-A** | Sonnet | A + P | `shared/…/streams/StreamAutoPlayRanking.kt` (new), `StreamAutoPlaySelector.kt`, `StreamsRepository.kt`, `debrid/DirectDebridStreamPreparer.kt`, `appleMain/…/TvOsProviderInstaller.kt`, `StreamAutoPlayBestQualityTest.kt`, `Settings/SourcesSettingsPane.swift`, `NextEpisodeAutoPlay.swift`, `NativePlaybackCoordinator.swift`, `NativePreparingLabelTests` |
| Gate 3 | main | | Kotlin gates, NuvioTVTests, Debug + Release, test58/63/64/65 with `-debug.tabBarRestFix 2`, test33 both layouts; device session 2: T1 decision (two photos per leg) | |
| W4 | **W4-H** | Opus | I1.7 (hero sharpen, form-sized decode, prefetch unchanged, row-poster prewarm on the card request) | `HomeView.swift` (hero art lines), `HomeHeroCommit.swift`, `HeroSharpenTests` (new) |
| (W4) | spec A W4-G | | — | — |
| Gate 4 | main | | full gates, UI legs with a sim reboot after ~6 runs, review rounds, device pass (Test profile) incl. I1.9 memory and the hero sharpen check | |

Cross-spec notes:
- `NuvioTVUITests.swift` is touched by W2-F (seed helper, test69, test70) and W3-D (test33) in different waves. Spec A's legs live in a new `TrailerMotionUITests.swift` (W4-G). Its test90 copies the seed helper per the house rule, with the `[]` teardown.
- `BrowseComponents.swift`: W1-A (spec A, `CatalogRowView`), W2-F (`CatalogRowView` edge lines + sampler line), W3-T (`PinnedRowSettle`): one owner per wave.
- `HomeView.swift`: W2-E (spec A M5) then W4-H.
- `SettingsDescriptions.swift`: W2-F only.

---

## 9. Proof matrix

| Item | Simulator (FA87) | Device |
|---|---|---|
| I1 | probe `size=`/`src=`/`out=`; metahub `large` decision; Laplacian crops (Detail, hero sharpen); memory + 10-deep chain | Oak Street; 30-min memory |
| F | test70 pixels; Wave-0 card distance | F.5 frame-time gate; plan item 8 |
| C | test69 seeded | folder in the Test profile |
| T1 | probe tokens, `r=relink`; pinned walks with leg 2 | the leg decision |
| A | Kotlin tests | Lizzie Borden |
| D1 | `-AppleLanguages (fr)` screenshot | — |
| D2 | test33 Classic leg, `glass=` constant | `[BUG41] hitches=` on *Drop* |
| D3 | unit tests; screenshot vs base | Monstre/Oak Street look |
| P | unit test | HDR10 vs DV caption |

---

## 10. Still open for Christian

- **metahub `large` pixel size** is measured at Gate 1, not here. If it is not larger than `medium`, the poster rule comes out (one row).
- **Memory budget**: 384 MB of image cache against 128 MB today, gated on the device `avail` ≥ 400 MB rule. If that fails, the pools halve.
- **Soft default**: still conditional on the F.5 frame-time gate. If the gate fails, Soft ships as an option with Off as the default.

---

## Revision r2 (2026-10-03): critique and Christian's answers

| Critique # | Decision | Where |
|---|---|---|
| 2 (P1, hero slower) | **Fixed**: prefetch, launch head and deadline-bound fetches unchanged (≤ 1920, today's URLs); only the presented hero sharpens, 0.6 s after commit, no deadline, adopted by a new same-identity `adoptSharpened`; form-sized decode (Nuvio 3072 bucket, classic full-bleed); row-poster prewarm on the card's URL and bucket; large pool by bytes 192 MB / 24 | §I1.3, §I1.7 |
| 3 (`.legacy` lookups miss card-size decodes) | **Fixed**: `.legacy` = any bucket, any family member; lookup contract table for spec A (`cachedLargest`); `sourceSizes` in an `NSCache` | §I1.3 |
| 12 (Soft for everyone, no gate) | **Fixed**: F.5 gate with knobs, phases, metric and the threshold (p95 +1.0 ms, dropped +max(2, 10 %)); failing it ships Off as the default; vertical overdraw 400 → 72 | §F.1, §F.5 |
| 13 (Stage reuse needs four row edits) | **Fixed**: `EnvironmentValues.rowEdgeMargins` / `rowEdgeRampLength`; parameters override | §F.2 |
| 14 (w780 misses Cinemeta; proof unmeetable on FA87) | **Fixed**: metahub `large` added (Christian); TMDB proof on Detail poster layer / More Like This; probe logs `host=` and `size=` | §I1.2, §I1.9 |
| 15 (w780 sites missed) | **Fixed**: `:1274`, `:1337`, `:1374` verified and added; grep gate | §I1.6 |
| 16 (`SettingsDescriptions` two owners) | **Fixed**: W2-F owns every edit incl. spec A's M4 case and copy; W2-D writes only the call-site id | §F.4, §8 |
| 17 (wave over-subscription) | **Fixed**: merged plan adopted; agents renamed | §8 |
| 18 (D2 removes a BUG-41 fix; vacuous test; test17 can't open Detail) | **Fixed**: test33 Classic leg reads `glass=` across a scroll; vacuous test deleted; `[BUG41] hitches=` on *Drop* in the device pass. The decision itself stands (Christian OK'd) | §D2 |
| 20 (plan doc device items) | **Not this file**: the plan doc is the main session's; §9 here already reflects the dropped items | — |
| 21 (leg 2 needs a focused row) | **Fixed**: two photos per leg; table row for a hero-only half bar | §T1 |
| 22 (ghost binds focus; reveal prefetch bucket) | **Fixed**: `chipsRow(bindsFocus:)`; `PosterCard.decodeRequest` shared by the card, the C reveal and the hero prewarm | §C, §I1.5 |
| 23a–e (zero size, CGSize Hashable, screenScale, pool drift, pushed Detail pages) | **Fixed**: `.normalized`; `.points(width:height:)`; seeded in `NuvioTVApp.init`; `willEvict` delegate; `releasesWhenHidden` on the Detail backdrop + 10-deep chain in the memory check | §I1.1, §I1.3, §I1.4, §I1.9 |
| 28 (largest file can lose Atmos) | **Fixed** (copy only): stated for the DM and release notes | §A |
| 29 (M4 copy says "Home") | **Fixed**: applied to the M4 text W2-F writes | §F.4 |
| 1, 4–11, 19, 24–27, 30 | **Not spec B** (spec A's items) | — |
| Stage verdict (I1 usable; F needs #13) | **Done** via #13 | §F.2 |
| Christian: logos `original` | **Done at draw time**, `.logo` upgrade with slot-sized decode; hero logo sharpened after commit; the Kotlin data stays `w500` so the hero's deadline fetch is unchanged | §I1.2, §I1.5, §I1.6, §I1.7 |
| Christian: metahub posters `large` | **Done** with automatic fallback to the original; existence verified by HEAD; pixel size decided at Gate 1 | §I1.2, §I1.4, §I1.9 |
| Christian: Episodes rows fade | **Done** (`EpisodesSection.swift:87`, `:151`) | §F.3 |
| Christian: 250 pt, lower-one-constant fallback | **Kept** | §F.1, §F.7 |
| Christian: migrate only "Off" | **Kept** | §F.2 |
| Christian: glass rule stops Classic panel flattening | **Kept** | §D2 |
| Christian: T1 both legs off | **Done**: default leg 0 | §T1 |

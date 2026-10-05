# Home Stage & Strip, P2 spec: ambient wash, folder Rows page, Home Screen settings (2026-10-05)

**Status:** design spec for W1-B, W1-C, W2-B, W2-C and the P2 part of W3. Nothing here is built.
**Plan:** `docs/home-stage-strip-plan-2026-10-03.md` (H3, H5, H8, "Defaults I chose", Target design).
**Base:** `tvos-shared-extraction` `d68b9d61`, clone `~/Claude/Projects/NuvioMobile-home-stage`. Paths are relative to `iosApp/NuvioTV/` unless they start with `shared/` or `iosApp/`. Every `file:line` below was re-read at the base.
**P1 dependency:** P1 (Stage + Strip) is being written in parallel. §2.9 lists the seam this spec needs from it. If P1 lands with other names, the implementer maps them; P3 checks that the behaviour exists.

## 0. Decisions

| # | Decision | Why |
|---|---|---|
| P2-1 | The wash is blurred **once per title on the CPU** into a 160×90 half-float bitmap, drawn magnified. No live `.blur`. | A full-screen `.blur(radius: 80)` renders offscreen at 3840×2160 every frame anything under it changes (the BUG-19/41 class). |
| P2-2 | Wash source = a `.pixels(256)` decode through `ArtworkStore` (I1, `DesignSystem/ArtworkDecodeSize.swift:19`: "The Stage wash passes 256"). | It shares the stage art's bytes (`ArtworkStore.fetch`, `DesignSystem/CachedAsyncImage.swift:610`). |
| P2-3 | The wash follows the stage's **displayed** title and warms on the **pending** one. | It moves with the stage, never on raw focus. |
| P2-4 | Folder per-tab data: **Swift only, no `shared/` change.** | `FolderDetailRepository.initialize` already loads every source's first page concurrently into `state.tabs[i].items` (`shared/.../collection/FolderDetailRepository.kt:194–296`). The VM only exposes the selected tab (`Screens/CollectionsUI.swift:1026`). |
| P2-5 | Folder rows don't paginate in place: first 18 items plus the existing See All tile, which opens that source's catalog grid. | Same as Home rows (`homePreviewLimit = 18`, `Screens/BrowseComponents.swift:4933`) and mobile's Rows mode (`composeApp/.../FolderDetailScreen.kt:323–363`). |
| P2-6 | The per-folder Grid choice is **device-local**. The synced `Collection.viewMode` (`CollectionModels.kt:8, 232–236`) stays ignored on TV, as today. | Its default is `TABBED_GRID`, so it can't tell "chose grid" from "never touched". |
| P2-7 | `home_layout` is read **live** (`@AppStorage`), not through the root `.id` remount. | `hero_nuvio_style` already flips layouts live at the same branch point (`Screens/HomeView.swift:309`). Fallback in §3.5. |
| P2-8 | Stage is the default for new and existing users. No migration. | As Detail's Cinematic default (`Screens/Detail/DetailSettingsKeys.swift:25–35`). |

## 1. Ambient wash (W1-B)

### 1.1 Z-order (Stage pages only)

Bottom → top:
1. Page root `Theme.Palette.background.ignoresSafeArea()` (Home `Screens/HomeView.swift:722`; folder page, §2.8).
2. `AmbientWashLayer`: full screen, `.ignoresSafeArea()`, `.allowsHitTesting(false)`, `.accessibilityHidden(true)`, never focusable.
3. Stage art (P1), right-anchored, faded on the left and bottom by an **alpha mask** (S5).
4. Stage text, strip rows.

With the wash off, layer 2 is absent and the masked art edge reveals the theme background, which looks like today's scrim fade.

### 1.2 Pipeline (per committed title)

| Step | Where | Numbers | Cost |
|---|---|---|---|
| 1. Fetch | main actor, `ImageFallbackPlan.load(candidates: art.urls, request: AmbientWashTuning.decode)` (`DesignSystem/CachedAsyncImage.swift:1281`) | `ArtworkDecodeRequest(size: .pixels(256), fill: true, scale: 1)` | Memory hit, or a ~2–4 ms ImageIO thumbnail from the URLCache bytes. A fetch in flight for the stage art is joined for its bytes. |
| 2. Downsample | detached `.utility` task, `CGContext` RGBA8 sRGB, `.medium` interpolation, black fill, aspect-fill centre crop | 160×90 px (12 pt per px at 1920 pt) | ≤ 1 ms from a 256 px source. Up to ~10 ms if the memory cache served a larger decode (`cached(_:decode:)` serves larger buckets, `:483`). Never on main. |
| 3. Wash colour | `ArtworkColorStore.meanChroma(rgba:)` on the step-2 bytes, then `washRGB` (§1.5) | — | 14,400 px loop, < 0.2 ms |
| 4. Saturation boost | per pixel: `L = 0.2126r + 0.7152g + 0.0722b`, `c' = L + (c − L)·1.25`, clamp 0…1 | 1.25 | trivial |
| 5. Tint | `c' = c·(1 − t) + w·t` | t = 0.25; t = 0 for grey art | trivial |
| 6. Blur | separable box blur, 3 passes, edge-replicated, running sums | σ = 80 pt → 6.67 px → box radius 6 (`boxRadius`, §1.3) | ~0.3 ms |
| 7. Exposure | `meanLuma` (Rec. 709 on the encoded values), then `c·exposureGain(m)` clamped | cap mean at 0.26, lift to 0.10, gain ≤ 1.8 | trivial |
| 8. Output | `CGImage` RGBA16F, `CGColorSpace.extendedSRGB`, `noneSkipLast` + `floatComponents` + `byteOrder16Little` | 160×90×8 B = 115 KB | — |

Display: `Image(decorative: cg, scale: 1).resizable().interpolation(.medium).aspectRatio(contentMode: .fill)`, frame full screen, clipped. Half-float output keeps the 12× magnified dark gradients from banding.

**GPU cost per frame:** at most two 160×90 textures drawn as full-screen quads (two only during a 400 ms cross-fade). No offscreen pass, no `.blur`, no `.drawingGroup()`, no `.compositingGroup()` on the layer. **Memory:** cache of 40 outputs ≈ 4.6 MB (`NSCache`, process-wide), plus at most two live layers per mounted wash.

### 1.3 Types and signatures

New `DesignSystem/AmbientWashRenderer.swift` (pure, `nonisolated`):

```swift
nonisolated enum AmbientWashTuning {
    static let decode = ArtworkDecodeRequest(size: .pixels(256), fill: true, scale: 1)
    static let width = 160, height = 90
    static let blurSigmaPoints: CGFloat = 80
    static let screenWidthPoints: CGFloat = 1920
    static let saturationBoost: Float = 1.25
    static let tintAmount: Float = 0.25
    static let maxMeanLuma: Float = 0.26
    static let minMeanLuma: Float = 0.10
    static let maxGain: Float = 1.8
    static let crossFade: TimeInterval = 0.4
    static let crossFadeReducedMotion: TimeInterval = 0.2
    static let prepareDebounce: TimeInterval = 0.15
    static let oledOpacity: Double = 0.4
    static let increasedContrastOpacity: Double = 0.6
    static let cacheCount = 40
}

nonisolated enum AmbientWashRenderer {
    struct Output: @unchecked Sendable { let image: CGImage; let meanLuma: Float; let millis: Double }
    static func render(_ source: CGImage) -> Output?                       // steps 2–8
    static func downsample(_ source: CGImage, width: Int, height: Int) -> [UInt8]?   // RGBA8, aspect-fill
    static func rgbFloats(_ rgba: [UInt8]) -> [Float]                      // 3 floats per pixel
    static func boostSaturation(_ px: inout [Float], by: Float)
    static func tint(_ px: inout [Float], toward: (r: Float, g: Float, b: Float)?, amount: Float)
    static func boxBlur(_ px: inout [Float], width: Int, height: Int, radius: Int, passes: Int)
    static func meanLuma(_ px: [Float]) -> Float
    static func exposureGain(meanLuma m: Float) -> Float
    // m <= 0 → 1;  m > maxMeanLuma → maxMeanLuma/m;  m < minMeanLuma → min(minMeanLuma/m, maxGain);  else 1
    static func boxRadius(sigmaPoints: CGFloat, workingWidth: Int, screenWidth: CGFloat, passes: Int) -> Int
    // σpx = σ·w/W = 6.67; box width = round(sqrt(12·σpx²/passes + 1)) = 13; radius = (13 − 1)/2 = 6
    static func makeCGImage(_ px: [Float], width: Int, height: Int) -> CGImage?
}

final class AmbientWashCache { static let shared; func output(for identity: String) -> AmbientWashRenderer.Output?; func store(_ o: AmbientWashRenderer.Output, for identity: String) }  // NSCache, countLimit 40
```

New `DesignSystem/AmbientWashLayer.swift`:

```swift
nonisolated enum AmbientWashSetting {
    static let defaultsKey = "home_ambient_background"   // device-local, not synced
    static let defaultValue = true
}

/// One title's wash art. `identity` is the stage's `"\(type):\(id)"` (HeroPresentation.identity).
nonisolated struct WashArt: Equatable, Sendable {
    let identity: String
    let urls: [URL]          // deduped, in order, ≤ 3
    init(identity: String, urls: [URL?])
}
extension WashArt {
    /// [heroBackdropURL(for: item), item.poster, fallback]. `heroBackdropURL(for:)` is the global
    /// chain the stage art uses (Screens/HomeView.swift:6619), so wash and art share a decode family.
    init(item: MetaPreview, fallback: String? = nil)
}

@MainActor final class AmbientWashModel: ObservableObject {
    struct Layer: Identifiable { let id: Int; let identity: String; let image: CGImage }
    @Published private(set) var base: Layer?
    @Published private(set) var incoming: Layer?
    @Published var incomingOpacity: Double = 0
    private(set) var lateCount = 0, lastMeanLuma: Float = 0, lastMillis: Double = 0   // probe only
    typealias Loader = @MainActor (WashArt) async -> AmbientWashRenderer.Output?
    init(loader: @escaping Loader = AmbientWashModel.liveLoader)
    func prepare(_ art: WashArt?)    // debounced 0.15 s, newest wins; warms AmbientWashCache only
    func show(_ art: WashArt?)       // nil or same identity as shown/wanted = no-op
    func promote(_ id: Int)          // called by the view when the fade completes
    static func liveLoader(_ art: WashArt) async -> AmbientWashRenderer.Output?   // cache → fetch → detached render → cache
}

/// Mount once per Stage page. Renders nothing when the setting is off.
struct AmbientWashLayer: View {
    init(displayed: WashArt?, pending: WashArt?, probeID: String = "debug_wash")
}
```

`AmbientWashLayer` body rules:
- Reads `@AppStorage(AmbientWashSetting.defaultsKey)`. Off → `EmptyView()`. On → a private child `AmbientWashContent` that owns the `@StateObject` model, so off drops the layers and on re-runs its `.onAppear { model.prepare(pending); model.show(displayed) }` (a cache hit is back within 0.4 s).
- `.onChange(of: pending) { model.prepare($1) }`, `.onChange(of: displayed) { model.show($1) }`.
- `ZStack { base (opacity 1); incoming (opacity model.incomingOpacity) }`. On `.onChange(of: model.incoming?.id)`: `withAnimation(.easeInOut(duration: reduceMotion ? 0.2 : 0.4)) { model.incomingOpacity = 1 } completion: { model.promote(id) }`. The old layer stays at 1 underneath, so the midpoint never dips toward black.
- Whole-layer opacity: `oled ? 0.4 : (contrast == .increased ? 0.6 : 1)`. `oled` is read at init with the idiom at `DesignSystem/AppThemeModel.swift:35` (`ThemeSettingsRepository.shared.amoledEnabled.value_`). An OLED change re-identifies the whole tree (`ContentView.swift:151`), so `Theme.swift` needs no edit.

### 1.4 Input contract from P1

The host (StageStripHome in W1-A, `FolderRowsPage` in W2-B) passes two values it reads from P1's `StageSwapModel` (S2):

| Input | Set when | Wash does |
|---|---|---|
| `pending: WashArt?` | the 450 ms pause starts for a new target | `prepare`: after a 0.15 s debounce, fetch + render into the cache. Held-Down paging restarts the debounce, so skipped rows render nothing. |
| `displayed: WashArt?` | the swap point (after the 150 ms text fade-out), the same instant the art's 300 ms cross-fade starts | `show`: start the 400 ms fade. The wash ends ~100 ms after the art does. |

Rules:
- `show(nil)` keeps the current wash (genre chips row, See All tile); the same identity is a no-op.
- **Late image:** an uncached `show` records `wanted` and fades in on arrival only if `wanted` is unchanged; a commit > 100 ms after `show` increments `lateCount`.
- A `show` during a running fade (unreachable at the 600 ms swap cadence) promotes `incoming` at once, then fades.
- Cold launch: no layers until the first `displayed`.

### 1.5 `ArtworkColorStore.Use.wash`

Edit `DesignSystem/ArtworkColorStore.swift`:
- `enum Use` (`:57–62`) gains `case wash`.
- `color(from:use:)` (`:153–162`) gains `case .wash: lifted = washLifted(...)`.
- New:

```swift
nonisolated static let washMinSaturation: CGFloat = 0.45
nonisolated static let washMaxSaturation: CGFloat = 0.85
nonisolated static let washBrightness: CGFloat = 0.55
nonisolated static func washLifted(h: CGFloat, s: CGFloat, v: CGFloat) -> (h: CGFloat, s: CGFloat, v: CGFloat) {
    (h, min(washMaxSaturation, max(washMinSaturation, s)), washBrightness)
}
/// The wash tint as sRGB-encoded RGB 0…1 (what the renderer mixes toward); nil for grey.
nonisolated static func washRGB(from mean: Mean?) -> (r: CGFloat, g: CGFloat, b: CGFloat)?
```

| Use | Saturation | Brightness | Purpose |
|---|---|---|---|
| `.ring` | floor 0.55 | floor 0.85 | must read as a focus ring at 10 feet |
| `.rail` | clamp 0.40…0.70 | 1.0 | a 1–3 pt hairline, bright but not neon |
| `.wash` | clamp 0.45…0.85 | **0.55 fixed** | a large background area: rich hue, mid brightness, so the tint never fights the exposure cap or the white text |

Grey art (`meanChroma` nil) → no tint, t = 0. The renderer computes the mean from its own 160×90 bytes (the same image it washes), so nothing hops to the main actor and the per-URL ring/rail cache is untouched.

### 1.6 Debug probe (DEBUG only)

A hidden `Text` with opacity 0.011 and identifier `probeID` (the `folder_header_state` pattern, `Screens/CollectionsUI.swift` body):

`on=<0|1> oled=<0|1> id=<identity|-> gen=<n> shown=<0|1> late=<n> lum=<meanLuma 2dp> ms=<render ms 1dp>`

The folder page passes `probeID: "debug_wash_folder"`, so a pushed folder over Home never yields two `debug_wash` elements.

## 2. Folder Rows page (W2-B)

### 2.1 Rows or Grid

```swift
nonisolated enum FolderPageLayout: Equatable { case rows, grid
    static func resolve(homeLayout: HomeLayout, gridOverride: Bool) -> FolderPageLayout {
        homeLayout == .classic || gridOverride ? .grid : .rows
    }
}

/// Device-local per-folder Grid choice. One `@AppStorage` string: entries joined by "\n",
/// entry = "\(collectionId)\u{1F}\(folderId)". Only Grid choices are stored.
nonisolated enum FolderLayoutStore {
    static let defaultsKey = "folder_layout_grid"
    static let maxEntries = 200
    static func entryKey(collectionId: String, folderId: String) -> String
    static func isGrid(_ raw: String, collectionId: String, folderId: String) -> Bool
    /// New raw string. grid=true appends (dedup, newest last, oldest dropped past 200);
    /// grid=false removes the entry.
    static func setting(_ raw: String, grid: Bool, collectionId: String, folderId: String) -> String
}
```

| Home Layout | Grid choice stored | Folder page |
|---|---|---|
| Classic | — | today's grid, **byte-identical**: no Edit menu, today's `editFiltersOverlay` (`Screens/CollectionsUI.swift:1564`) |
| Stage | no | **Rows page** |
| Stage | yes | today's grid, plus the Edit menu (§2.6) instead of the Edit Filters button |

`FolderDetailView` reads `@AppStorage(HomeLayout.defaultsKey)` and `@AppStorage(FolderLayoutStore.defaultsKey)`, so a change re-renders it live. A folder left open in Home's stack while the user flips Home Layout in Settings shows the new layout on return; both modes share the one view model.

### 2.2 Data (Swift only)

`FolderDetailViewModel` (`Screens/CollectionsUI.swift:976`) changes:
- `collectionId`, `folderId`: `private let` → `let` (the view builds the store key).
- `@Published private(set) var stripRows: [FolderStripRow]`, rebuilt in the existing `FlowWatcher` closure (`:1016–1036`) via `FolderRowsPlan.rows(...)` and assigned only when `!=`. A row whose equality key is unchanged keeps its previous instance and `HomeCatalogSection`, so it never re-renders.
- `@Published private(set) var allSettled` = `!state.isLoading`.
- `@Published private(set) var editableSources: [EditableSource]`, one per filter-editable non-All tab: refactor `editableSource(in:…)` (`:1059`) to `editableSource(forTabAt:in:…)`; the selected-tab property passes `selectedTabIndex`.
- `private(set) var collection: NuvioCollection?` from `CollectionRepository.shared.getCollection(id:)` (`shared/.../CollectionRepository.kt:82`), set in `start()`, refreshed when `state.folder` changes.
- `func retry()`: `FolderDetailRepository.shared.clear()`, then `initialize`. (`reload()` early-returns on unchanged inputs, so it never refetches a failed tab.)
- Grid's `items`, `selectedTabIndex`, `selectTab`, `itemAppeared`, `stop()` are unchanged; `stop()` still `detach()`es, so UX-14's pop-back retention covers Rows too.

### 2.3 Row model, states and visibility

New `Screens/FolderRowsPlan.swift` (pure, `nonisolated` except where noted):

```swift
struct FolderTabSnapshot {           // built from FolderTab by the VM; tests build it directly
    let tabIndex: Int; let label: String; let typeLabel: String; let isAllTab: Bool
    let isLoading: Bool; let items: [MetaPreview]; let error: String?; let canLoadMore: Bool
    let target: Target?              // nil when no target can be built
    enum Target { case collectionSource(sourceKey: String, contentType: String, supportsPagination: Bool)
                  case addon(manifestUrl: String, contentType: String, catalogId: String, genre: String?, supportsPagination: Bool) }
}
enum FolderRowStatus: Equatable { case loading, loaded, empty, failed }
struct FolderStripRow: Identifiable, Equatable {
    let id: String                   // "folder-row-\(tabIndex)"
    let tabIndex: Int; let heading: String; let status: FolderRowStatus
    let section: HomeCatalogSection? // non-nil only when .loaded
    let itemKeys: [String]           // equality key with tabIndex, heading, status, hasMore
    var isFocusable: Bool { status == .loaded }
}
enum FolderRowsPlan {
    static let previewLimit = CatalogRowView.homePreviewLimit      // 18
    static func status(_ t: FolderTabSnapshot) -> FolderRowStatus
    static func section(_ t: FolderTabSnapshot, collectionId: String, folderId: String) -> HomeCatalogSection?
    static func rows(_ tabs: [FolderTabSnapshot], collectionId: String, folderId: String) -> [FolderStripRow]  // All omitted, tab order
    static func visible(_ rows: [FolderStripRow], focusedTabIndex: Int?) -> [FolderStripRow]
    static func firstFocusable(_ rows: [FolderStripRow]) -> FolderStripRow?
    enum PageState { case rows, loading, empty, failed }
    static func pageState(_ rows: [FolderStripRow], allSettled: Bool) -> PageState
    static func plainFolderPreview(collection: NuvioCollection, folder: CollectionFolder) -> MetaPreview   // §2.4
}
```

| Status (first match, top down) | Condition (`FolderTab`, `FolderDetailRepository.kt:38–58`) | Row renders | Focusable |
|---|---|---|---|
| loaded | `!items.isEmpty` and a buildable target (an `error` from a later page is ignored) | `CatalogRowView(section:previewLimit: 18, onItemFocusChange:)` | yes |
| loading | `isLoading` | heading + 6 non-focusable `ShimmerView` cards (`CachedAsyncImage.swift:1369`) at `posterStyle` size, same page height as a loaded row | no |
| failed | `error != nil` | heading + "Couldn't load this source.", secondary | no |
| empty | otherwise (settled, no items, no error; or no buildable target) | heading + "Nothing here yet." (existing string), secondary | no |

**Visibility** (`visible`): loading and loaded rows always show. An empty or failed row shows **only above the focused row** (`tabIndex < focusedTabIndex`), and with no focused row every one is removed. Nothing above the focused row ever vanishes, so it never jumps. The engine skips non-focusable pages, and P1's `scrollPosition(id:)` follows the focused row, so a skip is still one motion.

**Page states** (`pageState`), drawn left-aligned at the top of the strip area:

| State | When | Shows | Focus anchor (BUG-47) |
|---|---|---|---|
| `.loading` | no visible row focusable yet, `!allSettled` | the skeleton rows | the Edit menu (§2.6) |
| `.empty` | `allSettled`, none focusable, not every row failed | "Nothing here yet." + `Button("Go Back") { dismiss() }.buttonStyle(.bordered)` | Go Back |
| `.failed` | `allSettled`, every non-All row failed | "Couldn't load this folder." + `Button("Try Again") { model.retry() }` + Go Back | Try Again |

**Initial focus:** `@State pendingInitialFocus = true`. When `firstFocusable` first becomes non-nil while it is still true, send P1's strip a focus request for that row's first card (S4) and clear the flag. Any focus change the user makes clears it too.

**Section building** (`section`), mirroring `getCatalogSectionsForRows` (`FolderDetailRepository.kt:551–588`) with two differences: the key uses the tab index, not the label, and items are trimmed.
- `key: "folder_\(folderId)_\(tabIndex)"`, `title: label`, `subtitle: typeLabel`, `addonName: ""`.
- `items: Array(items.prefix(18))`, `availableItemCount: items.count`, `hasMore: canLoadMore`.
- Target: tmdb/trakt tabs → `CatalogTargetCollectionSource(collectionId:folderId:sourceKey:contentType:supportsPagination:)`. Addon tabs with a `manifestUrl` → `CatalogTargetAddon(manifestUrl:contentType:catalogId:genre:search: nil, supportsPagination:)`. Anything else → nil, so the row is `empty`.
- Swift needs every argument, since Kotlin defaults don't export (see `NuvioTVTests/SearchPoliciesTests.swift:285–290`).
- See All pushes `CatalogRoute(section:)`, which Home's stack already resolves (`Screens/HomeView.swift:1174`).
- `addonName` stays empty, so W2-A's "· add-on" heading suffix never appears on folder rows.

### 2.4 What the stage shows

```swift
enum FolderStageInput {
    /// Row 0 is the folder's own row: the stage shows the folder there, and the focused item
    /// from row 1 down. `rowPosition` = index of the focused row in `visible`, nil before focus.
    static func choose(rowPosition: Int?, focusedItem: MetaPreview?, folderPreview: MetaPreview) -> MetaPreview?
    // (rowPosition ?? 0) == 0 → folderPreview, else focusedItem (nil = keep, P1's rule)
}
```

- **`folderPreview`:** `HomeView.folderHeroPreview(collection:folder:)` (S6). When that returns nil (a folder with neither backdrop nor logo), use `FolderRowsPlan.plainFolderPreview(collection:folder:)`: the same id/type (`nuvio-folder://…`, `nuvio.folder`, `Screens/HomeView.swift:6585–6589`), name = folder title, `releaseInfo` = collection title, `description` = `HomeView.folderHeroDescription` (`:2990`), banner/logo/poster nil, and every other field nil/empty as in `folderHeroPreview` (`:2949–2985`).
- `isCollectionHero` already gates trailers and enrichment, so a folder stage never plays a trailer.
- **Stage art:** `heroBackdropUrl` only. The cover is not a stage fallback (Wave H, `:2958–2964`).
- **Wash:** `WashArt(item: folderPreview, fallback: folder.coverImageUrl)`, i.e. backdrop, then cover. A blurred square cover makes a good wash. Items from row 1 down use `WashArt(item:)`.

### 2.5 Folder logo: the rise (H5, Steven's "title always visible")

One persistent `FolderStageLogoLayer`, always mounted, never removed or re-identified:
- `TitleLogoHeader(title: model.folderTitle, logoUrl: model.titleLogoUrl, alignment: .topLeading, textFont: Theme.Font.hero, slotHeight: slot, decodeSize: .points(width: 680, height: slot))`.
- `.accessibilityIdentifier("folder_stage_logo")`.

```swift
nonisolated enum FolderStageLogo {
    static let compactScale: CGFloat = 0.6
    static let compactGap: CGFloat = 8           // compact bottom → stage block top
    static let compactTopFloor: CGFloat = 12
    /// Docked = drawn in the stage's logo slot at full size.
    static func docked(rowPosition: Int?, displayedIdentity: String?, folderIdentity: String) -> Bool {
        (rowPosition ?? 0) == 0 && (displayedIdentity == nil || displayedIdentity == folderIdentity)
    }
    static func compactTop(blockTop: CGFloat, slot: CGFloat) -> CGFloat {
        max(compactTopFloor, blockTop - compactGap - compactScale * slot)
    }
    static func offsetY(docked: Bool, blockTop: CGFloat, slot: CGFloat) -> CGFloat {
        docked ? 0 : compactTop(blockTop: blockTop, slot: slot) - blockTop
    }
}
```

- **Frame:** `(blockLeading, blockTop, 680, slot)` from S1.
- **Transform:** `.scaleEffect(docked ? 1 : 0.6, anchor: .topLeading)` and `.offset(y: offsetY)`.
- **Animation:** `.animation(reduceMotion ? nil : .easeOut(duration: 0.5), value: docked)`, the strip's page duration. W2-A retunes both together.
- **Example:** `blockTop` 120 and slot 150 give a compact 90 pt logo at y 22…112. A compressed slot of 110 gives 66 pt at y 46…112.
- **Stage logo:** the stage hides its own logo slot while it displays the folder (S3), so only one logo is ever in the slot.

| Moment | Strip | Stage text | Folder logo |
|---|---|---|---|
| open | row 0 | folder meta + synopsis, logo slot empty | docked, 100 % |
| Down, t = 0 | pages to row 1 (0.5 s) | still the folder | rises at once (0.5 s) to compact |
| t ≈ 0.6 s | — | swap: the item's logo/meta/synopsis fade in | compact; the slot was empty from t = 0.5 |
| Up to row 0, t = 0 | pages to row 0 | still the item | stays compact (`displayed` ≠ folder) |
| t ≈ 0.6 s | — | swap: folder text fades in, slot hidden | descends (0.5 s) into the empty slot |
| Down then back Up inside 450 ms | row 1 → row 0 | never swapped | rises, then docks again |

### 2.6 Edit menu (Stage only)

`FolderEditMenuBand`: an `HStack { Spacer(); editMenu }` full width at the top, `padding(.top, FolderHeaderGeometry.restTop)` (32), trailing `Theme.Spacing.screen`.
- `.focusSection()` on the full-width band, so Up from any card in row 0 reaches it (the Library L1 fix pattern).
- Mounted once in `FolderDetailView`, **outside** the Rows/Grid switch, so choosing a layout keeps focus on it.
- Visible and enabled only when `rows ? rowPosition == 0 : !gridScrolled`, with `.opacity` + `.disabled` animated 0.2 s, the existing `editFiltersOverlay` rule.

```swift
Menu {
    Picker(String(localized: "Layout"), selection: layoutBinding) {      // FolderPageLayout, writes FolderLayoutStore
        Text("Rows").tag(FolderPageLayout.rows)
        Text("Grid").tag(FolderPageLayout.grid)
    }
    // Rows: one entry per model.editableSources; Grid: model.editableSource only (today's behaviour)
    ForEach(entries) { s in Button { editing = s } label: { Label(String(localized: "Edit Filters: \(s.title)"), systemImage: "line.3.horizontal.decrease.circle") } }
} label: { Label("Edit", systemImage: "slider.horizontal.3").font(Theme.Font.meta) }
.menuStyle(.button).buttonStyle(.bordered)
.accessibilityIdentifier("folder.editMenu")
```

The existing `.fullScreenCover(item: $editing, onDismiss: { model.reload() })` serves both modes. In Grid mode the entry keeps today's label "Edit Filters". If `.menuStyle(.button)` doesn't render a bordered pill on tvOS, drop it and keep the system Menu look (HIG contract, system styles only).

### 2.7 Remote

| Press | Rows page |
|---|---|
| Down / Up between rows | P1's strip paging (one motion) |
| Up from row 0 | the Edit band. The strip must not consume it (S4). |
| Down from the Edit band | back to the row the strip shows (its focus section) |
| Menu | **pops** (HIG: Menu = back). Unlike Home, no detour to row 0 (S4 `menuPagesToTop: false`). |
| Back from a pushed Detail | the same row and card (P1's per-row memory, S4; the page's `@State` survives the push) |
| Leaving the folder | Home focus returns to the folder tile (P1's Home strip memory; test57's contract) |

### 2.8 View tree

`FolderDetailView.body` (`Screens/CollectionsUI.swift:1227`) becomes:

```swift
ZStack(alignment: .top) {
    switch pageLayout {
    case .rows: FolderRowsPage(model: model, editing: $editing)
    case .grid: gridPage          // today's ZStack contents moved verbatim; `editFiltersOverlay` only when homeLayout == .classic
    }
    if homeLayout == .stage { FolderEditMenuBand(model: model, layout: layoutBinding, rowPosition: rowPosition, gridScrolled: gridScrolled, editing: $editing) }
}
.onAppear { model.start() } .onDisappear { model.stop() }
.fullScreenCover(item: $editing, onDismiss: { model.reload() }) { TmdbFilterEditorView(target: $0) }
```

The selected-tab `.onChange` and the reveal `.task(id: GridRevealKey…)` move inside `gridPage`, so Rows mode never prefetches a grid. `FolderDetailView` owns `@State rowPosition: Int?` and hands `FolderRowsPage` a binding to it.

New `Screens/FolderRowsPage.swift`:

```swift
ZStack(alignment: .topLeading) {
    Theme.Palette.background.ignoresSafeArea()
    AmbientWashLayer(displayed: washDisplayed, pending: washPending, probeID: "debug_wash_folder")
    StageView(model: stage, hidesLogoWhenDisplaying: folderIdentity)          // S3
    FolderStageLogoLayer(...)                                                  // §2.5
    StageStrip(rows: specs, focusedRowID: $focusedRowID, focusRequest: $focusRequest,
               linksTabBar: false, menuPagesToTop: false) { spec in rowView(spec) }   // S4
    #if DEBUG  probe `folder_rows_state`  #endif
}
```

Probe: `mode=rows rows=<visible> removed=<n> row=<rowPosition|-> tab=<tabIndex|-> docked=<0|1> disp=<displayedIdentity|-> state=<rows|loading|empty|failed>`.

### 2.9 Seam needed from P1 / W1-A

| # | Need | Used for |
|---|---|---|
| S1 | `StripGeometry`: strip height, stage height, stage logo-slot height (150 / 110), `stageBlockTop`, `stageBlockLeading` (pure) | the folder page uses the same geometry; logo docking |
| S2 | `StageSwapModel` publishes `pendingItem` (pause started) and `displayedItem` (swap point), both `MetaPreview?`, plus `displayedIdentity: String?` (`"\(type):\(id)"`). Its input accepts a synthetic folder preview. | wash prepare/show (§1.4); logo docking (§2.5) |
| S3 | `StageView(…, hidesLogoWhenDisplaying identity: String?)`: logo slot at opacity 0 while that identity is displayed; meta and synopsis still draw | one logo in the slot |
| S4 | `StageStrip` generic over rows: `rows: [StripRowSpec(id, heading, isFocusable)]`, `focusedRowID` binding, `focusRequest` (row id + optional item id), `linksTabBar`, `menuPagesToTop`. Never consumes Up at the first row. Per-row card memory survives a push. Next-row heading peek from `heading`. | folder strip; Up to the Edit band; Menu pops |
| S5 | Stage art fades by **alpha mask** on the left and bottom, never by a `Theme.Palette.background` gradient. Nothing in the Stage strip paints an opaque background over the wash. | the wash shows through; wash off = today's look |
| S6 | `HomeView.folderHeroPreview(collection:folder:)` becomes `nonisolated static`, internal (today `private func`, `:2949`; it only reads globals and `folderHeroDescription`). Three call sites become `Self.` | folder stage row 0 without duplicating the synthesis |
| S7 | A Stage probe `debug_stage` with `row=`, `fitem=` (the `nuvio-folder://` id when a folder tile is focused) and `disp=` (`displayedIdentity`) tokens | UI tests 102–106 |
| S8 | `AmbientWashLayer(displayed:pending:)` mounted at the StageStripHome root as layer 2 (§1.1), with `WashArt(item:)` from S2's items | Home wash |

## 3. Home Screen settings (W1-C)

### 3.1 Key and read helper

New `Screens/Home/HomeLayout.swift`:

```swift
nonisolated enum HomeLayout: String, CaseIterable, Sendable {
    case stage, classic
    static let defaultsKey = "home_layout"                 // device-local @AppStorage, not synced
    static let defaultValue: HomeLayout = .stage
    /// nil, blank or unknown → .stage; trimmed + lower-cased so `-home_layout Classic` resolves.
    static func resolve(_ raw: String?) -> HomeLayout
    static func current(_ defaults: UserDefaults = .standard) -> HomeLayout { resolve(defaults.string(forKey: defaultsKey)) }
    var label: String   // String(localized: "Stage") / String(localized: "Classic")
}
```

- **Launch arg** `-home_layout classic|stage`: NSArgumentDomain is in `UserDefaults.standard`'s search list, so both `current()` and `@AppStorage(HomeLayout.defaultsKey)` see it. This is the same mechanism as `-detail_layout` (`iosApp/NuvioTVUITests/RevampEvidenceTests.swift:57`).
- ⚠️ The argument domain **shadows the app domain for the whole process.** A picker write lands in the app domain but every read keeps returning the argument. A UI test that flips the picker must not pass `-home_layout`.
- Every reader uses `HomeLayout.defaultValue.rawValue` as its `@AppStorage` default, so an unset key reads Stage everywhere.

### 3.2 Pane rows (`Screens/Settings/HomeScreenSettingsPane.swift`)

New state:
- `@AppStorage(HomeLayout.defaultsKey) private var homeLayoutRaw = HomeLayout.defaultValue.rawValue`
- `@AppStorage(AmbientWashSetting.defaultsKey) private var ambientBackground = AmbientWashSetting.defaultValue`
- `private var isStage: Bool { HomeLayout.resolve(homeLayoutRaw) == .stage }`

A new first section, `SettingsSection(String(localized: "Layout"))`, goes before "Home Rows" (`:56`).

| # | Row | Kit | Stage | Classic | Description id |
|---|---|---|---|---|---|
| 1 | Home Layout: Stage / Classic | `SettingsPickerRow`, `HomeLayout.allCases`, `label: { $0.label }` | ✓ | ✓ | `.homeLayout` |
| 2 | Ambient Background | `SettingsToggleRow`, subtitle on "A soft wash of the focused title's colors fills the background" / off "Plain background" | ✓ | — | `.homeAmbientBackground` |
| 3 | Upcoming Episodes (`:65`) | unchanged | ✓ | ✓ | `.homeUpcoming` |
| 4 | Refresh Add-ons (empty branch, `:95`) | unchanged | ✓ | ✓ | unchanged |
| 5 | Show Hero (`:111`) | unchanged | — | ✓ | unchanged |
| 6 | Nuvio-Style Hero, Hero Sources + rows (`:127–184`) | unchanged | — | ✓ (Show Hero on) | unchanged |
| 7 | Trailers on Focus (`:186`) | subtitle per §3.3 | ✓ | ✓ | `.homeTrailersOnFocus` |
| 8 | Trailer Location (`:313`) | §3.3 | ✓ (trailers on) | ✓ (trailers on) | Stage `.homeTrailerLocationStage`, Classic `.homeTrailerLocation` |
| 9 | Autoplay Hero Trailer (`:205`) | unchanged | — | ✓ | unchanged |
| 10 | Trailer Start Delay (`:297`) | condition: Stage `inlineTrailersEnabled`; Classic unchanged `inlineTrailersEnabled ‖ heroTrailerAutoplay` | ✓ | ✓ | Stage `.homeTrailerStartDelayStage`, Classic `.homeTrailerStartDelay` |
| 11 | Show Catalog Type in Titles (`:221`) | unchanged | ✓ | ✓ | unchanged |
| 12 | Catalogs + rows (`:242`) | unchanged | ✓ | ✓ | unchanged |

- **Literal ids:** `SettingsDescriptionsTests` finds ids with the regex `descriptionID:\s*\.(\w+)` (`iosApp/NuvioTVTests/SettingsDescriptionsTests.swift:65`). A ternary hides the second id, so rows 8 and 10 are written as `if isStage { Row(descriptionID: .a…) } else { Row(descriptionID: .b…) }`.
- Add `.onChange(of: homeLayoutRaw) { _, raw in if HomeLayout.resolve(raw) == .stage { heroSourcesExpanded = false } }`, next to the existing resets at `:268–282`.
- Upcoming Episodes keeps its BUG-47 floor role. The Home Layout picker is now a second always-present row.

### 3.3 Trailer Location in Stage

- **Picker (Stage):** options `["hero", "poster"]`, labels `"hero"` → "Background", `"poster"` → "In Row". It writes the same `trailer_playback_location` key (`:40`), and the default stays `"poster"`. No fallback captions in Stage (`:325–338` render only when `!isStage`).
- **Picker (Classic):** byte-identical: "Hero" / "Poster" and both captions.
- **`heroLocationEffective`** (`:288–292`) gains a first line: `if isStage { return trailerPlaybackLocation == "hero" }`. The stage always exists, so Background always takes effect.
- **Trailers on Focus subtitle:**
  - off → "Posters show artwork only" (existing);
  - Stage + hero → "Trailers play muted behind the title at the top after you rest on a poster";
  - Stage + poster, or Classic not effective → "Posters play a muted trailer preview after a moment of focus" (existing);
  - Classic effective → the existing hero string.

### 3.4 Strings and descriptions

W1-C adds the ids and plain English drafts, because the `switch` at `SettingsDescriptions.swift:199` is exhaustive and won't compile without them. W2-C runs them through SlopMonster to 5/5 and translates them (§4.1).

New `SettingsDescriptionID` cases, in the Home Screen block (`:78–91`):

| Case | Raw | Draft copy |
|---|---|---|
| `homeLayout` | `home.layout` | "Stage shows the focused title at the top of the screen with one row of posters below it, and Up and Down move one whole row at a time. Classic is the previous Home, with the banner and scrolling rows. Default: Stage." |
| `homeAmbientBackground` | `home.ambientBackground` | "Fills the background with a soft, blurred wash of the focused title's colors. With OLED True Black on, the wash is dimmed. On by default." |
| `homeTrailerLocationStage` | `home.trailerLocationStage` | "Background plays the trailer behind the title at the top of the screen once you stop moving. In Row turns the focused poster into a playing trailer card. Default: In Row." |
| `homeTrailerStartDelayStage` | `home.trailerStartDelayStage` | "Sets how long trailer previews wait before they start. Automatic waits until the row has stopped moving, then one second. Default: Automatic." |

Changed copy (W2-C; both are layout-agnostic now; `SettingsCategoryTests` only checks they're non-empty):
- `.homeScreen` subtitle (`:405`): "The hero and rows, plus trailer previews" → "Layout and rows, plus trailer previews".
- `.homeScreen` summary (`:425`): → "Choose the Home layout, which catalogs appear as rows and in what order, and where trailer previews play."

New English UI strings. These are compiler-extracted, so never hand-edit `Localizable.xcstrings`.

| String | Where |
|---|---|
| "Home Layout", "Stage" | pane, `HomeLayout.label` ("Classic" and "Layout" already exist) |
| "Ambient Background", "A soft wash of the focused title's colors fills the background", "Plain background" | pane |
| "In Row" ("Background" exists) | pane |
| "Trailers play muted behind the title at the top after you rest on a poster" | pane |
| "Edit", "Rows", "Grid", "Edit Filters: %@" | folder Edit menu |
| "Couldn't load this source.", "Couldn't load this folder." | folder Rows page ("Nothing here yet.", "Go Back", "Try Again" exist) |

### 3.5 Defaults, migration, remount

- Stage for everyone, with no migration code (P2-8).
- **Behaviour changes for release notes:**
  - A stored `trailer_playback_location = "hero"` now means Background, including for Classic-layout users whose "Hero" used to fall back to the poster.
  - Show Hero (synced through `model.heroEnabled`), Nuvio-Style Hero (`hero_nuvio_style`), Hero Sources and Autoplay Hero Trailer (`hero_trailer_autoplay`) keep their stored values and do nothing in Stage.
- **Remount (P2-7):** if P1 instead latches the layout per mount or joins `home_layout` to the root `.id` (`ContentView.swift:151`), W1-C adds `pendingAppearanceRowFocus`-style restore. `HomeScreenSettingsPane(model:pendingRowFocus:)` takes `SettingsView`'s existing binding (`Screens/SettingsView.swift:206`), arms `"homeLayout"` before the write, and consumes it in `.onAppear` (pattern at `Screens/Settings/AppearanceSettingsPane.swift:84–133`).

## 4. Ownership and tests

### 4.1 File ownership

| Agent | Owns (edit/create) | Must not touch |
|---|---|---|
| W1-B (Sonnet) | new `DesignSystem/AmbientWashRenderer.swift`, new `DesignSystem/AmbientWashLayer.swift`, `DesignSystem/ArtworkColorStore.swift`; tests `AmbientWashRendererTests.swift`, `AmbientWashModelTests.swift` (new), `ArtworkColorStoreTests.swift` (append) | `Theme.swift`, `HomeView.swift` (W1-A mounts the layer, S8) |
| W1-C (Sonnet) | new `Screens/Home/HomeLayout.swift`, `Screens/Settings/HomeScreenSettingsPane.swift`, `Screens/Settings/SettingsDescriptions.swift` (4 ids + drafts); test `HomeLayoutTests.swift` (new) | `ContentView.swift` unless §3.5's fallback is triggered |
| W1-A (Opus, P1) | adds S1–S8 in its own files plus S6 in `HomeView.swift` | — |
| W2-B (Opus) | `Screens/CollectionsUI.swift` (switch, VM, Edit band), new `Screens/FolderRowsPage.swift`, new `Screens/FolderRowsPlan.swift` (plan, `FolderPageLayout`, `FolderLayoutStore`, `FolderStageInput`, `FolderStageLogo`); tests `FolderRowsPlanTests.swift`, `FolderLayoutStoreTests.swift`, `FolderStageLogoTests.swift` (new) | `HomeView.swift`, `shared/` |
| W2-C (Sonnet) | phase 1 (with Wave 2): SlopMonster pass on the 4 descriptions + 2 category strings in `SettingsDescriptions.swift`. Phase 2 (after the main session builds W2-A/B): `scripts/populate-localizable-xcstrings.py <NuvioTV.build>` → de/es/fr/it/vi part files → `scripts/merge-translations-into-xcstrings.py`. Conventions: fr "vous", product names untranslated. | Swift sources other than `SettingsDescriptions.swift` |
| W3 (Opus) | UI tests §4.3–4.4, the `folderRowsSeedJson` fixture | app sources |

Agents reference each other's new types (`HomeLayout`, `AmbientWashSetting`, `WashArt`) by the signatures above. The main session builds only after a wave lands.

### 4.2 Unit tests (NuvioTVTests)

| File | Tests and expected values |
|---|---|
| `ArtworkColorStoreTests` (append) | wash lift: s 0.2 → 0.45, 0.95 → 0.85, v always 0.55, hue kept · grey → `washRGB` nil and `color(from: nil, use: .wash)` nil · ring and rail outputs unchanged for the same mean |
| `AmbientWashRendererTests` | `boxRadius(80, 160, 1920, 3) == 6` · `exposureGain`: 0.6 → 0.26/0.6, 0.04 → 1.8, 0.18 → 1, 0 → 1 · tint moves 25 % toward the colour, none when nil · saturation boost keeps luma · box blur: a step stays monotone, mean kept within 1e-3, a uniform image's edge pixel unchanged · `render` of a synthetic 3840×2160 and a 171×256 image → 160×90, 16 bpc float · white → mean luma ≤ 0.26 + ε, uniform 0.02 → ×1.8 · deterministic |
| `AmbientWashModelTests` (@MainActor, injected `loader`) | show → `incoming`, then `promote` → `base` · same identity no-op · `show(nil)` keeps · stale late image dropped (show A, show B, A resolves last) · three prepares within 0.15 s → one load, of the last · show during a fade promotes first |
| `HomeLayoutTests` | keys and cases (`home_layout`, `stage`/`classic`, default `.stage`) · `resolve`: nil, "", "pinned" → stage; " Classic " → classic · `current` reads a throwaway suite (as `RowEdgeFadeSettingTests`) · `AmbientWashSetting` key `home_ambient_background`, default true |
| `FolderLayoutStoreTests` | Classic → grid; Stage → rows · grid round trip (set grid → `isGrid`; set rows → entry removed) · same folderId in another collection is separate · 201 entries → 200, oldest dropped; re-setting moves an entry to newest · blank lines ignored |
| `FolderRowsPlanTests` | All omitted, tab order kept · status mapping incl. items + error → loaded, no target → empty · empty/failed below focus removed, above focus kept, all removed with no focus; loading always kept · section trims to 18, keeps `availableItemCount` and `hasMore` · CollectionSource target for tmdb/trakt, Addon otherwise · keys distinct for duplicate labels · rebuild with the same items is `==` · `firstFocusable` · `pageState` loading/empty/failed · `FolderStageInput`: row nil/0 → folder, row 2 → item, row 2 + nil → nil |
| `FolderStageLogoTests` | docked: row 0 + nil/folder displayed → true, row 0 + item → false, row 1 + folder → false · `compactTop`: (120, 150) → 22, (120, 110) → 46, (60, 150) → 12 · offset 0 when docked |

### 4.3 New UI tests

The block test100–test107 is reserved for P2. P1 and P4 take other blocks; W3 renumbers on a clash.

Every Stage leg passes `-home_layout stage` explicitly, so a value stored by an interrupted flip test can't leak in. The only exceptions are tests that flip a picker.

**Fixture.** FA87 is a guest profile with no collections (Wave 0: test54 and the HeroFolderSwap leg can't find a folder). `launchToHomeWithSeededCollections` (`iosApp/NuvioTVUITests/NuvioTVUITests.swift:3948`) already seeds through `-debug.collectionsSeedJsonB64` (`Screens/HomeViewModel.swift:850`, guest-only; refused on a signed-in account). Use it with a new constant beside `folderProbeSeedJson` (`:3937`), and `defer` re-seed `"[]"`:

```json
[{"id":"zzfolderrows-collection","title":"ZZFolderRows","pinToTop":true,"showAllTab":true,"folders":[{"id":"zzfolderrows-folder","title":"ZZFolderRowsFolder","hideTitle":false,"heroBackdropUrl":"https://images.metahub.space/background/medium/tt0111161/img","coverImageUrl":"https://images.metahub.space/poster/medium/tt0111161/img","sources":[{"provider":"addon","addonId":"com.linvo.cinemeta","type":"movie","catalogId":"top"},{"provider":"addon","addonId":"com.linvo.cinemeta","type":"series","catalogId":"top"},{"provider":"addon","addonId":"com.linvo.cinemeta","type":"movie","catalogId":"imdbRating"},{"provider":"addon","addonId":"zz.missing.addon","type":"movie","catalogId":"zzmissing"}]}]}]
```

No `titleLogoUrl`, so the folder title is a `staticText`. The last source fails at once ("Addon not found", `FolderDetailRepository.kt:285–292`), so the removal rule gets exercised. The folder legs except test105 also pass `-folder_layout_grid ""`, which shadows any stored Grid choice.

| Test | Steps | Asserts |
|---|---|---|
| **test100StageHomeScreenSettingsRows** | `-home_layout stage -inline_trailers_enabled YES -trailer_playback_location hero`. Open Settings › Home Screen; walk to "Catalogs" collecting row labels (`walkToRowByTreeIndex`). Relaunch with `-home_layout classic`. | First focused row label starts "Home Layout", value "Stage". Seen: Ambient Background, Upcoming Episodes, Trailers on Focus, Trailer Location (value "Background"), Trailer Start Delay, Show Catalog Type in Titles, Catalogs. Never seen: Show Hero, Nuvio-Style Hero, Hero Sources, Autoplay Hero Trailer, or the classic-hero caption. Classic: Show Hero present, Ambient Background absent, Trailer Location value "Hero". |
| **test101HomeLayoutPickerIsLive** | No `-home_layout`. Settings › Home Screen › Home Layout → Classic → Home tab → Settings → Stage → Home tab. `defer`: re-pick Stage. | After the pick, focus is still on "Home Layout", value "Classic", and "Ambient Background" is gone. Home shows `debug_hero` and no `debug_stage`. After Stage: `debug_stage` exists. |
| **test102AmbientWashOnOff** | `-home_layout stage`; Down ×1; rest 2 s; screenshot. Relaunch with `-home_ambient_background NO`, same walk. | On: `debug_wash` `on=1 shown=1 id=` equals `debug_stage` `disp=`. Off: `on=0 shown=0`. The region x 4…30, y 600…1000 (left gutter) in the off run has mean RGB within ±3/255 of 0x0D0D0D. The on run differs from it by ≥ 8/255 in at least one channel; skip with the reason if the on run's `lum=` < 0.03. |
| **test103AmbientWashFollowsSwap** | Stage; land on a row with ≥ 3 items; Right ×2, 0.25 s apart; sample both probes every 50 ms for 2.5 s. | `gen` rises by exactly 1. The first sample with the wash `id` = the new identity is no earlier than the first with `disp` = the new identity. End state: `id == disp == fitem`. |
| **test104FolderRowsPage** | Seeded; walk Down until `debug_stage fitem` contains `nuvio-folder://zzfolderrows`; Select. Wait for `folder_rows_state` `state=rows`. Down; wait 1.5 s; Up; sample at 50 ms for 2 s. | Open: `rows=3 removed=1 row=0 docked=1`; staticText "ZZFolderRowsFolder" exists; no "All" heading. After Down: `row=1 docked=0` within 0.6 s; `disp` = the focused item within 1.5 s; the folder title staticText still exists. After Up: no sample has `docked=1` while `disp` ≠ the folder identity, and `docked=1` arrives within 1.5 s. `debug_wash_folder` `shown=1`. |
| **test105FolderRowsGridOption** | Seeded. Open folder; Up → "folder.editMenu" focused; Select → Layout › Grid. Menu back; re-open the folder; then Edit › Rows. `defer`: Rows + reseed. | After Grid: `folder_header_state` exists, chip "All" exists, `folder_rows_state` absent, focus still on `folder.editMenu`. Re-opened: still Grid. After Rows: `mode=rows`. |
| **test106FolderRowsExitRestoresFocus** | Seeded (the Stage analogue of test57). Open folder; Down to row 1; Right ×1; Select (Detail); Menu; then Menu again. | Back from Detail: `row=1`, and `debug_stage fitem` equals the item focused before Select. Back from the folder: `debug_stage fitem` is the folder's `nuvio-folder://` id. |
| **test107FolderRowsSeeAll** | Seeded. Row 0 (Cinemeta top movie, > 18 items); Right until the See All tile; Select. | A catalog grid titled with row 0's heading is pushed; Menu returns to the folder at `row=0`. |

### 4.4 Existing UI tests affected by P2

- **Add `-home_layout classic`** (beyond W3's list): test04SettingsRows (walks Show Hero/Hero Sources, `:828`), test57, test69, test37 and the TrailerMotion legs using `trailerArguments(location: "hero", heroPinned:)`. test00z still finds Show Hero within its 6 Downs.
- **test82SettingsExplainerFollowsFocus (`:9198`)** asserts the pane's first row is Upcoming Episodes. Stage run: Home Layout, then Down → Ambient Background. Add a Classic run: Home Layout → Upcoming Episodes → Show Hero (or Refresh Add-ons).
- **HeroFolderSwap test54:** seed with `launchToHomeWithSeededCollections(folderProbeSeedJson)` plus `-home_layout classic`, so it measures instead of failing (Wave 0).

### 4.5 Device pass (Living Room Apple TV, **"Test" profile**)

- **Step 6:** the wash is colourful and changes with the stage art ~0.6 s after a pause, never mid-paging. Off → plain at once; on → back within 0.5 s. OLED True Black → visibly dimmer. No banding in dark gradients; console `ms=` < 20.
- **Step 9:** a folder in Test (Remote Setup or the phone's Test profile) shows one row per source in order, no All row. The logo rises on the first Down and docks again only after the stage shows the folder. Back from Detail restores the card; Back from the folder restores Home's folder tile. Edit › Grid gives today's grid and persists; Edit › Rows returns; Edit Filters still opens the editor.
- **Step 11:** Classic brings back Show Hero, Nuvio-Style Hero, Hero Sources and Autoplay Hero Trailer; Trailer Location reads Hero / Poster.
- **Step 13:** the new Home Screen rows, Background / In Row and the Edit menu are in French, with no truncated picker pills.

## 5. Risks and open questions

1. **Row 0 shows the folder, not the focused poster** (plan text: "the folder logo shows in the stage when the strip is at row 0"). So row 0's posters get no synopsis, and with Trailer Location = Background nothing plays at row 0. The alternative is to show the folder until the first focus move, then follow focus (the logo rises on that move). **Christian's call at the skim.**
2. **The rise target.** This spec reads "rises into the stage's logo slot and shrinks to 60 %" as: docked in the slot at row 0, rising to a 60 % title at the top-left above the stage block from row 1 down. If he meant something else, only `FolderStageLogo` and its tests change.
3. **Wash brightness.** `maxMeanLuma` 0.26 and `minMeanLuma` 0.10 (sRGB-encoded) are first guesses between "cold, dull, too dark" and legible white text. Tune them on device in Wave 2; they're constants.
4. **Banding** at 12× magnification: half-float output should prevent it. If the device shows it, raise the working size to 256×144 (the 4.6 MB cache becomes ~11.8 MB).
5. **Live layout flip** (P2-7) assumes nothing in Stage changes a resolved toolbar preference (the BUG-66 latch class). P1 confirms; §3.5 is the fallback.
6. **The Edit band's reachability** depends on a full-width focus section above the stage. Verify on the simulator (test105) before Gate 2.
7. **P1 seam names** (§2.9) are requirements, not names. P3 should reject a P1 spec that lacks S3, S4's `menuPagesToTop`/Up rule, or S5.
8. **Appearance › "Hide Hero Artwork"** (`hero_poster_focus_only`) has no defined meaning in Stage. P1 decides; it lives in the Appearance pane (W2-D's file).

# P1 Detail spec: "Cinematic Clean" (Part 1, W1-A / W1-C / W2-A)

All line numbers are at base `5f2d5cd3`. Abbreviations:
- **DV** = `NuvioMobile/iosApp/NuvioTV/Screens/DetailView.swift`
- **DRA** = `Screens/DetailRowAnchor.swift`
- **ES** = `Screens/EpisodesSection.swift`
- **DVM** = `Screens/DetailViewModel.swift`

W2-A edits DV after W1-A has landed, so W2-A should find its edit sites by the symbol names given here; the base line numbers will have moved.

The Xcode project uses synchronized folder groups (`PBXFileSystemSynchronizedRootGroup`), so new `.swift` files need no pbxproj edits. The tvOS deployment target is 26.0, so `.defaultFocus` and `onScrollGeometryChange` are available.

---

## A. Geometry table

**How DetailView knows the viewport today.** It doesn't store it. The anchor reads `ScrollGeometry` per frame into plain fields (DV:803-807: `contentInsets.top`, `contentOffset.y`). The probe also prints `vis=` (`geo.bounds.height`) and an inset of 157 on the fixture (DRA:65-68, 76-79).

New: one `onScrollGeometryChange` that writes a `@State viewportMetrics` only when a rounded value changes (rare, so it respects the BUG-41 rule). The hero height is derived from it.

| Element | Value | Source / token |
|---|---|---|
| Content width | 1800 pt | 1920 − 2 × `Theme.Spacing.screen` (60), the VStack padding at DV:591 |
| Left text column max width | **900** | `DetailCinematicLayout.textColumnMaxWidth` |
| Gap between text column and credits | 40 | `Theme.Spacing.xl` |
| Credits block max width | **640**, right-aligned | `DetailCinematicLayout.creditsMaxWidth` |
| Logo slot | fixed **height 180**, max width 600, `.bottomLeading` | `logoSlotHeight = 180`, `logoMaxWidth = 600`. Image: `CachedAsyncImage(string:contentMode:.fit, failure:)`, same as DV:1379. Fallback: `Text(title).font(Theme.Font.hero).lineLimit(2)`, bottom-leading in the same 180 frame. The slot height never changes. |
| Meta line | 1 line, `Theme.Font.metaStrong`, `textSecondary` | `lineLimit(1)` |
| Ratings strip slot | **44** when reserved, otherwise 0 | `ratingsSlotHeight = 44` |
| Synopsis teaser slot | **4 × `Theme.Font.synopsisLineHeight`**, rounded up | `Theme.swift:255` (`static private(set) var synopsisLineHeight`, measured from UIFont caption1: about 30 pt on System, 31.32 on Open Sans). `DetailSynopsisTeaser.slotHeight(lineHeight:maxLines:4)` gives about 120 / 126 pt. |
| Hero vertical spacing | `Theme.Spacing.md` (16) between logo, meta, ratings and synopsis; `Theme.Spacing.lg` (24) above the action row | |
| Action row | Today's `actionRow` (DV:1544), unchanged styles, its own full-width line (see PLAN CONFLICTS 1) | |
| Credits block | `Theme.Font.detail`, `textSecondary`, names in `textPrimary`, `multilineTextAlignment(.trailing)`, each line `lineLimit(2)` | |
| Gap from hero to first row | 36 | Existing page VStack spacing `Theme.Spacing.lg + .sm` (DV:545) |
| Peek band | **140** | `DetailCinematicLayout.peekBand` |
| Hero height | `max(520, H − insetTop − insetBottom − 60 − 36 − 140)`, where H = `geo.containerSize.height` and the insets are `geo.contentInsets.top/.bottom` | `DetailCinematicLayout.heroHeight(...)`; floor `heroMinimumHeight = 520` (also used before the first geometry read). Fixture estimate: 1080 − 157 − 60 − 60 − 36 − 140 = **627**. The DEBUG probe (C) records the real numbers at Gate 1. |
| Bottom anchoring | Hero root `.frame(maxWidth: .infinity, minHeight: heroHeight, alignment: .bottomLeading)` | `minHeight`, so Larger Text grows the hero and shrinks the peek instead of clipping |
| Focus region | The hero root is `.focusSection()` at full width | Same as BUG-117 at DV:1368-1369 |

**Content budget check.** 180 + 34 (meta) + 44 + 120 + about 70 (action row) + 3 × 16 + 24 ≈ 520. That fits the 627 hero.

**Cinematic scrim.** New constants in `DetailScrim` (DV:2559). The classic constants are untouched.

| Constant | Value |
|---|---|
| `cinematicHorizontalLeading` | 0.55 |
| `cinematicHorizontalMid` | 0.15 |
| `cinematicHorizontalTrailing` | 0.00 |
| `cinematicHorizontalTrailingOverPoster` | 0.10 |
| `cinematicVerticalClearUntil` | 0.60 |
| `cinematicVerticalBottom` | 0.60 |
| `cinematicRadialOpacity` | 0.55 (radial centred `.bottomLeading`, black at this opacity fading to clear) |
| `cinematicRadialEndRadiusFraction` | 0.70 (of the screen width) |

**What "ceiling" means here.** Steven's BUG-127 stops (0.80 / 0.30 / 0.18, bottom 0.70) are the ceiling, applied point by point to the composite darkness.
- New pure functions: `DetailScrim.classicCompositeAlpha(x:y:overPoster:)` and `cinematicCompositeAlpha(x:y:overPoster:)`.
  - `x` and `y` are unit coordinates; the radial distance uses a 1920 × 1080 aspect.
  - Composite = 1 − Π(1 − aᵢ).
  - The horizontal gradient is piecewise-linear through 3 equally spaced stops; the vertical is clear until `clearUntil`, then linear to the bottom; the radial is linear to the end radius.
- The unit test requires cinematic ≤ classic on an 11 × 11 grid, both with and without the poster layer.
- **If the test fails, lower `cinematicRadialOpacity` in 0.05 steps until it passes. Never raise any value.**
- BUG-41 glass flattening still applies to the remaining glass chips, which are the parental-guide chips. The Cinematic hero has no glass chips: its age chip is stroke-only.

## B. Layout switch point

**The switch.** DV:546 `topBlock` (inside `ScrollView { VStack {` at DV:544-545) becomes `heroBlock`:

```swift
@ViewBuilder private var heroBlock: some View {
    switch detailLayout {
    case .classic: topBlock            // DV:1339, untouched
    case .cinematic: cinematicHero
    }
}
```

**The scrim switch at both call sites.** DV:532 and the trailer-cover copy at DV:1014 (the Codex r3 rule says they must match):

```swift
if detailLayout == .cinematic {
    cinematicScrimOverlay(posterBackdropVisible:)
} else {
    scrimOverlay(posterBackdropVisible:)
}
```

`scrimOverlay` itself (DV:1303-1323) is not edited. `cinematicScrimOverlay` is a new private function next to it: a `ZStack` of three gradients (horizontal, vertical, and `RadialGradient(center: .bottomLeading, startRadius: 0, endRadius: width × fraction)` read through a `GeometryReader`), then `.ignoresSafeArea().allowsHitTesting(false)`.

**New state in DetailView (W1-A):**
- `@AppStorage(DetailSettingsKeys.layout) private var detailLayoutRaw = DetailLayout.cinematic.rawValue`
- `private var detailLayout: DetailLayout { DetailLayout.resolve(detailLayoutRaw) }`
- `@AppStorage(DetailSettingsKeys.sectionRatings) private var sectionRatings = true`
- `@State private var viewportMetrics = DetailViewportMetrics()`, fed by `.onScrollGeometryChange(for: DetailViewportMetrics.self, of: { DetailViewportMetrics(geo) }, action: { _, m in viewportMetrics = m })`. Add it next to DV:803. The type rounds to whole points and is Equatable.
- `private var cinematicHeroHeight: CGFloat { DetailCinematicLayout.heroHeight(containerHeight:contentInsetTop:contentInsetBottom:) }`
- `@FocusState private var heroFocus: DetailHeroFocus?` with `enum DetailHeroFocus: Hashable { case play }`.
- `@FocusState private var heroHasFocus: Bool` (used by W2-A).
- `@State private var startOverMovie = false`

**`cinematicHero` (private, in DetailView), passes:**

```swift
DetailCinematicHero(
  heroHeight: cinematicHeroHeight,
  title: title,
  logoURL: logoUrl,
  meta: DetailMetaLineModel(
    year: model.meta?.releaseInfo ?? preview.releaseInfo,
    runtime: model.meta?.runtime,
    genres: genres,
    ageRating: model.meta?.ageRating,
    imdbRating: model.meta?.imdbRating ?? preview.imdbRating,
    isLoading: model.isLoading),
  ratings: DetailRatings.ordered(model.meta?.externalRatings.map { DetailRatingInput($0) } ?? []),
  ratingsGateOn: sectionRatings && model.mdbListRatingsActive,
  overview: overview,
  synopsisSlotVisible: !(model.meta != nil && (overview ?? "").isEmpty),
  credits: DetailCredits.make(
    cast: (model.meta?.cast ?? []).map(\.name),
    director: model.meta?.director ?? [],
    writer: model.meta?.writer ?? [],
    isSeries: isSeries),
  onOpenSynopsis: { userInteracted = true; withdrawTrailerBridgeIfLeaving() }
) { actionRow }                        // existing DV:1544, reused verbatim
.defaultFocus($heroFocus, .play)
.focused($heroHasFocus)
```

**Closures and labels the hero relies on:**
- The Play action, hold-for-Choose-Source…, trailer, watched, library and shuffle all stay inside the existing `actionRowButtons` (DV:1562-1712), with their closures, `HoldPlayChooseSourceMenu`, `actionLabel` (icon-only mode plus the accessibility label), `actionButtonPadding`, the BUG-41 leg-4 style swaps and every existing label ("Play", "Playback unavailable", `action.label`, "Watch Trailer", "Mark Watched"/"Watched", "Add to Library"/"In Library", "Shuffle"/"Shuffle On").
- Nothing is copied, so the labels and ids stay identical.

**Required edits inside `actionRowButtons` (Classic renders the same):**
1. Add `.focused($heroFocus, equals: .play)` to both Play buttons: after `.modifier(HoldPlayChooseSourceMenu…)` at DV:1590-1594 and DV:1616-1620.
2. Insert `if showsStartOver { startOverButton }` right after the Play `if/else` closes at DV:1621. `showsStartOver = detailLayout == .cinematic && model.hasResumableProgress`. The button is in E.

**Why `.defaultFocus` is required.** The teaser is focusable when the text is truncated and sits above Play. The engine's top-leading default would otherwise land on it, and the plan requires focus to land on Play.

## C. New files (all under `NuvioMobile/iosApp/NuvioTV/`)

### C1. `Screens/Detail/DetailSettingsKeys.swift` (W1-A)

```swift
enum DetailSettingsKeys {
  static let layout = "detail_layout"                          // "cinematic" default | "classic"
  static let sectionStudioLogos = "detail_section_studio_logos"
  static let sectionParentalGuide = "detail_section_parental_guide"
  static let sectionRatings = "detail_section_ratings"
  static let sectionCast = "detail_section_cast"
  static let sectionCollection = "detail_section_collection"
  static let sectionTrailers = "detail_section_trailers"
  static let sectionMoreLikeThis = "detail_section_more_like_this"
  static let sectionComments = "detail_section_comments"
  static let sectionAbout = "detail_section_about"
  static let hideEpisodeSpoilers = "detail_hide_episode_spoilers"  // must equal EpisodeSpoilerRules.defaultsKey
}
enum DetailLayout: String, CaseIterable { case cinematic, classic
  nonisolated static func resolve(_ raw: String) -> DetailLayout }   // unknown → .cinematic
```

W2-B's Detail Page pane uses these keys.

### C2. `Screens/Detail/DetailCinematicLayout.swift` (W1-A): pure helpers, all `nonisolated`

```swift
enum DetailCinematicLayout {
  static let textColumnMaxWidth: CGFloat = 900, creditsMaxWidth: CGFloat = 640
  static let logoSlotHeight: CGFloat = 180, logoMaxWidth: CGFloat = 600
  static let ratingsSlotHeight: CGFloat = 44, peekBand: CGFloat = 140
  static let heroMinimumHeight: CGFloat = 520, pageRowSpacing: CGFloat = 36   // = Theme.Spacing.lg + .sm
  static func heroHeight(containerHeight: CGFloat, contentInsetTop: CGFloat, contentInsetBottom: CGFloat,
                         screenPadding: CGFloat = Theme.Spacing.screen) -> CGFloat
}
struct DetailViewportMetrics: Equatable { var containerHeight: CGFloat = 0; var insetTop: CGFloat = 0; var insetBottom: CGFloat = 0
  init(); init(_ geo: ScrollGeometry) }   // rounded

struct DetailRatingInput: Equatable { let source: String; let value: Double
  init(source:value:); init(_ r: MetaExternalRating) }
struct DetailRatingEntry: Equatable, Identifiable { let source: String; let label: String; let value: String; var id: String { source } }
enum DetailRatings {
  static let leadingOrder = ["imdb", "tomatoes", "metacritic", "trakt", "letterboxd"]
  static func ordered(_ input: [DetailRatingInput]) -> [DetailRatingEntry]  // dedupe by source (first wins); leadingOrder first; rest stable in input (= MDBList PROVIDER_PRIORITY_ORDER) order
  static func label(for source: String) -> String   // IMDb, Rotten Tomatoes, Metacritic, Trakt, Letterboxd, TMDB, Audience, MyAnimeList, else source.capitalized
  static func formatted(source: String, value: Double) -> String // imdb/mal/letterboxd "%.1f"; tomatoes/audience/trakt/tmdb "\(Int(rounded))%"; metacritic "\(Int(rounded))"; unknown: ≤10 → "%.1f" else Int
}
enum DetailSynopsisTeaser {
  static let maxLines = 4, lineTolerance: CGFloat = 1
  static func slotHeight(lineHeight: CGFloat, maxLines: Int = maxLines) -> CGFloat     // (lineHeight*maxLines).rounded(.up)
  static func isTruncated(fullTextHeight: CGFloat, lineHeight: CGFloat, maxLines: Int = maxLines) -> Bool
      // lineHeight <= 0 || fullTextHeight <= 0 → false; else fullTextHeight > lineHeight*maxLines + lineTolerance
}
struct DetailCreditsText: Equatable { let castNames: String?; let crewLabel: CrewLabel?; let crewNames: String?
  enum CrewLabel { case directedBy, createdBy }
  var isEmpty: Bool }
enum DetailCredits {
  static func make(cast: [String], director: [String], writer: [String], isSeries: Bool) -> DetailCreditsText
  // cast: trimmed, non-empty, excluding names in director ∪ writer (TMDB prepends crew to cast:
  //   TmdbMetadataService.kt:1885-1890), first 3 joined ", ".
  // crew: first 2 non-empty director names joined ", "; label .createdBy when isSeries
  //   (TMDB TV maps createdBy → director, TmdbMetadataService.kt:1901-1915), else .directedBy.
}
struct DetailMetaLineModel: Equatable { year: String?; runtime: String?; genres: [String]; ageRating: String?; imdbRating: String?; isLoading: Bool }
enum DetailMetaLine { static func textParts(year: String?, runtime: String?, genres: [String]) -> [String] } // non-empty only; genres prefix(2) joined ", "; caller joins " · "
enum DetailStartOver {
  static func isAvailable(isSeries: Bool, seriesResumePositionMs: Int64?, movieEntryPositionMs: Int64?, movieEntryResumable: Bool) -> Bool
  // series: (seriesResumePositionMs ?? 0) > 0 ; movie: (movieEntryPositionMs ?? 0) > 0 && movieEntryResumable
}
enum DetailDim {   // used by W2-A; defined here so W1-A's tests cover it
  static let classicRampDistance: CGFloat = 400, ceiling = 0.85
  static func rampDistance(layout: DetailLayout, heroHeight: CGFloat) -> CGFloat   // classic 400; cinematic max(400, heroHeight)
  static func value(scrolled: CGFloat, rampDistance: CGFloat) -> Double            // (min(max(s/ramp,0),1)*0.85 *20).rounded()/20
}
```

**Unit tests: `NuvioTVTests/DetailCinematicLayoutTests.swift`**
- `heroHeight`:
  - (1080, 157, 60) → 627
  - (1080, 157, 0) → 687
  - (0, 0, 0) → 520
  - (700, 157, 60) → 520 (floor)
- `DetailLayout.resolve`: "classic" → classic; "cinematic" → cinematic; "" or "foo" → cinematic.
- `DetailRatings.ordered`:
  - [tmdb 72, imdb 7.4, letterboxd 3.62, tomatoes 87.6, trakt 76, metacritic 71.2] → sources imdb, tomatoes, metacritic, trakt, letterboxd, tmdb; values "7.4", "88%", "71", "76%", "3.6", "72%".
  - MDBList order [imdb, tmdb, tomatoes, metacritic, trakt, letterboxd, audience, mal] → imdb, tomatoes, metacritic, trakt, letterboxd, tmdb, audience, mal.
  - [] → [].
  - [imdb 7, imdb 8] → one entry, "7.0".
  - [foo 5.55, tmdb 60] → tmdb, foo (stable); foo label "Foo".
  - mal 8.13 → "8.1"; audience 90 → "90%".
- `isTruncated(lineHeight: 30)`, slot 120:
  - 120 → false; 121 → false; 121.5 → true; 150 → true
  - full 0 → false; lineHeight 0 → false
  - Open Sans 31.32: `slotHeight` → 126; full 126 → false; 127 → true
- `DetailCredits.make`:
  - cast [A, B, C, D], director [X] → cast "A, B, C", .directedBy "X"
  - cast [X, W, A, B, C], director [X], writer [W] → "A, B, C"
  - isSeries → .createdBy
  - director [X, Y, Z] → "X, Y"
  - all empty → `isEmpty == true`
  - cast ["", " ", A] → "A"
- `DetailMetaLine.textParts("2026", "1h 50m", [Action, Comedy, Drama])` → ["2026", "1h 50m", "Action, Comedy"]; (nil, "", []) → [].
- `DetailStartOver`:
  - series 120000 → true; series nil → false; series 0 → false
  - movie 5000 resumable → true; movie 5000 not resumable → false; movie nil → false
- `DetailDim`:
  - `rampDistance`: (.classic, 900) → 400; (.cinematic, 627) → 627; (.cinematic, 300) → 400
  - `value`: (0, 400) → 0; (100, 400) → 0.20; (400, 400) → 0.85; (1000, 400) → 0.85; (−50, 400) → 0; (627, 627) → 0.85

### C3. `Screens/Detail/DetailCinematicHero.swift` (W1-A)

```swift
struct DetailCinematicHero<Actions: View>: View {
  let heroHeight: CGFloat
  let title: String
  let logoURL: String?
  let meta: DetailMetaLineModel
  let ratings: [DetailRatingEntry]
  let ratingsGateOn: Bool
  let overview: String?
  let synopsisSlotVisible: Bool
  let credits: DetailCreditsText
  let onOpenSynopsis: () -> Void
  @ViewBuilder let actions: () -> Actions
  @State private var measuredSynopsisHeight: CGFloat = 0
  @State private var showSynopsisSheet = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var body: some View
}
```

**Layout of `body`:**
- `VStack(alignment: .leading, spacing: Theme.Spacing.lg)`:
  - `HStack(alignment: .bottom, spacing: Theme.Spacing.xl)`:
    - Text column: `VStack(alignment: .leading, spacing: Theme.Spacing.md) { logoSlot; metaLine; if ratingsGateOn { ratingsSlot }; if synopsisSlotVisible { synopsisSlot } }.frame(maxWidth: 900, alignment: .leading)`
    - `Spacer(minLength: 0)`
    - `if !credits.isEmpty { creditsBlock }`
  - `actions()`
- Hero root: `.frame(maxWidth: .infinity, minHeight: heroHeight, alignment: .bottomLeading)`, `.focusSection()`, `.accessibilityElement(children: .contain)`, `.accessibilityIdentifier("detail_hero")`.

**Pieces:**
- **logoSlot.** See A. Identifier `detail_logo_slot` on the 180-high frame.
- **metaLine.** `HStack(spacing: Theme.Spacing.md)`:
  - `Text(parts.joined(separator: " · "))`
  - Age chip: `Text(age)` with `.padding(.horizontal, Theme.Spacing.sm)` and a `RoundedRectangle(cornerRadius: Theme.Radius.chip).stroke(Theme.Palette.textSecondary, lineWidth: 1)` overlay. No glass.
  - When `showImdbStar`: `HStack { Image(systemName: "star.fill").foregroundStyle(Theme.Palette.star); Text(rating) }`
  - `if meta.isLoading { ProgressView() }`
  - Font `metaStrong`, colour `textSecondary`, `lineLimit(1)`, identifier `detail_meta_line`.
  - `showImdbStar = !(ratingsGateOn && !ratings.isEmpty)` and a non-empty rating.
- **ratingsSlot.** See D. Identifier `detail_ratings_strip`.
- **synopsisSlot.** A fixed frame of width ≤ 900 and height `slotHeight(Theme.Font.synopsisLineHeight)`, alignment `.topLeading`.
  - Measurement: `.background { Text(overview).font(Theme.Font.synopsis).fixedSize(horizontal: false, vertical: true).hidden().onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { measuredSynopsisHeight = $0 } }`
  - When `isTruncated`: `Button { onOpenSynopsis(); showSynopsisSheet = true } label: { teaserText }.buttonStyle(.borderless)`, with `.accessibilityHint("Shows the full synopsis")`.
  - Otherwise: plain `teaserText`, not focusable.
  - `teaserText = Text(overview).font(Theme.Font.synopsis).foregroundStyle(textPrimary).lineLimit(4).multilineTextAlignment(.leading)`
  - Identifier `detail_synopsis_teaser` on whichever branch renders.
- **creditsBlock.**
  - Lines: `Text("With \(Text(names).foregroundStyle(Theme.Palette.textPrimary))")` and `Text("Directed by \(…)")` / `Text("Created by \(…)")`.
  - Use interpolated `Text`, not `Text + Text` (deprecated in the 26 SDK).
  - Font `detail`, colour `textSecondary`, `.multilineTextAlignment(.trailing)`, `.frame(maxWidth: 640, alignment: .trailing)`, not focusable, identifier `detail_credits`.
- **Sheet.** `.fullScreenCover(isPresented: $showSynopsisSheet) { DetailSynopsisSheet(title: title, logoURL: logoURL, overview: overview ?? "") }`
- **DEBUG probe**, inside `#if DEBUG`, same pattern as DV:868-871 (`.font(.system(size: 8)).opacity(0.011)`):
  `Text("debug_detail_hero h=\(Int(heroHeight)) logo=180 syn=\(Int(slot)) trunc=\(0|1) ratings=\(ratings.count) reserved=\(ratingsGateOn ? 1 : 0)")`, identifier `debug_detail_hero`.

### C4. `Screens/Detail/DetailSynopsisSheet.swift` (W1-A)

```swift
struct DetailSynopsisSheet: View {
  let title: String; let logoURL: String?; let overview: String
  @State private var position = ScrollPosition()
  @State private var offset: CGFloat = 0
  @State private var maxOffset: CGFloat = 0
  var body: some View
}
```

**Layout:**
- `ZStack`:
  - `Rectangle().fill(Theme.Surface.panel).ignoresSafeArea()` is the glass/material background. It is only a background layer and never wraps a focusable.
  - `VStack(alignment: .leading, spacing: Theme.Spacing.lg)`:
    - Logo at max height 120 / max width 520 (`CachedAsyncImage`, fallback `Text(title).font(Theme.Font.screenTitle)`).
    - `ScrollView(.vertical) { Text(overview).font(Theme.Font.body).foregroundStyle(textPrimary).frame(maxWidth: 1400, alignment: .leading) }` with `.scrollPosition($position)` and `.onScrollGeometryChange` tracking `offset` and `maxOffset = contentSize.height − containerSize.height`.
  - Overall `.padding(Theme.Spacing.screen)`.

**Focus and scrolling.**
- The ScrollView gets `.focusable()` (inert; a ScrollView with no focusable content cannot be focused or scrolled on tvOS).
- `.onMoveCommand { dir in }`: `.down` → `position.scrollTo(y: min(offset + 240, maxOffset))`; `.up` → `max(offset − 240, 0)`.
- Not animated under Reduce Motion.

**Dismissal.** Menu closes the sheet through the system cover dismissal. No `onExitCommand`, per the remote-grammar rule.

**Identifiers.** `detail_synopsis_sheet` on the root, `detail_synopsis_sheet_text` on the Text.

### C5. `Screens/EpisodeSpoilerRules.swift` (W1-C): see I.

### C6. `Screens/Detail/DetailAboutSection.swift` (W2-A): see G.

## D. Ratings strip

**How the data arrives.**
- First publish: `MetaDetailsRepository` publishes TMDB-enriched meta.
- Second publish: `enrichForMetaScreen` (`shared/.../details/MetaDetailsRepository.kt:462-490`) runs `MdbListMetadataService.enrichMeta` and republishes with `externalRatings` filled.
- `DetailViewModel` adopts every emission (DVM:151-173), so `model.meta?.externalRatings` changes in place.
- The ratings come already ordered by `PROVIDER_PRIORITY_ORDER` (imdb, tmdb, tomatoes, metacritic, trakt, letterboxd, audience, mal; `MdbListMetadataService.kt:19-28`). `MdbListRatingsRepository.kt:112-113` selects in provider order.
- Source ids are lowercase ids. Letterboxd is 0–5, IMDb/MAL 0–10, the rest 0–100 (`MdbListRatingsDecoder.kt:49-70`).

**MDBList setting gate.**
- The user-facing setting is "MDBList Ratings" (`ContentSourcesSettingsPane.swift:75-81`) → `MdbListSettingsRepository.setEnabled`. It is a shared synced repository, not an `@AppStorage` key.
- The effective gate is `MdbListSettings.isActive && !enabledProvidersInPriorityOrder().isEmpty` (`MdbListSettings.kt:39-40, 63-64`), the same test as `shouldFetchForMeta` (`MdbListMetadataService.kt:36-44`).
- **W1-A adds to DVM:**
  - `@Published private(set) var mdbListRatingsActive = false`
  - A `private var mdbListWatcher: FlowWatcher?` set in `start()` after DVM:226 with `MdbListSettingsRepository.shared.ensureLoaded()` and `FlowWatcherKt.watch(MdbListSettingsRepository.shared.uiState) { … as? MdbListSettings … }`, following the pattern at `SettingsViewModel.swift:230-233`.
  - Cancel it in `stop()` (DVM:232-241) and `deinit` (DVM:752-762).

**Section toggle gate.** `@AppStorage("detail_section_ratings")`, default true.
- `ratingsGateOn = sectionRatings && model.mdbListRatingsActive`.
- Cinematic only. Classic's IMDb chip and Details "Ratings" line are untouched.

**Reserved slot and fade-in.**
- When `ratingsGateOn`, a fixed `.frame(height: 44, alignment: .leading)` is always laid out, even while `ratings` is empty.
- Content: a `ViewThatFits(in: .horizontal)` ladder over `ratings.prefix(n)` for n = count…1. Precedent: `StreamPickerView.swift:628-650`. Each entry is `HStack(spacing: Theme.Spacing.xs) { Text(label).font(Theme.Font.meta).foregroundStyle(textSecondary); Text(value).font(Theme.Font.metaStrong).foregroundStyle(textPrimary) }`, with `Theme.Spacing.lg` between entries.
- `.opacity(ratings.isEmpty ? 0 : 1)` and `.animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: ratings.isEmpty)`.
- Because the hero is bottom-anchored and the slot height is constant, nothing moves when ratings land.
- When the gate is off, the slot is absent.
- If the second emission brings no ratings (timeout, no tt id), the slot stays reserved and empty. The view model cannot tell "not yet" from "never", so the empty slot is the price of no layout movement.

**IMDb ★ on the meta line.** Shown only when `!(ratingsGateOn && !ratings.isEmpty)`, so when the strip is off or empty. See PLAN CONFLICTS 3.

RT certified-fresh (`isCertified`) is not shown in v1.

## E. Start Over

**The existing path from the Orivio batch:**
1. The hold menu enum `TitleHoldAction.startOver` (`DesignSystem/TitleHoldMenu.swift:113, 121, 131`: label "Start Over", icon `arrow.counterclockwise`).
2. Home: `onStartOver: { resume = ResumeTarget(entry: $0, startFromBeginning: true) }` (`HomeView.swift:1296`).
3. `ResumeTarget.startFromBeginning` (`HomeView.swift:4562-4569`).
4. `.fullScreenCover(item: $resume) { StreamPickerView(…, startFromBeginning: target.startFromBeginning) }` (`HomeView.swift:1145-1160`).
5. `StreamPickerView.init(startFromBeginning:)` (`StreamPickerView.swift:62-63, 141, 147`), then `startsOver` (:468), then the playback context (:200, `PlaybackModels.swift:76`), then the engines (`MPVPlayerView.swift:1157`, `NativePlaybackCoordinator.swift:653-656`, `PlaybackProgressRecorder.swift:43`).

Detail reuses step 5 by passing `startFromBeginning: true` to its own covers.

**Visibility.** Cinematic only, and only with saved progress. W1-A adds to DVM:
- `@Published private(set) var hasResumableProgress = false`, computed at the end of `refreshFlags()` (DVM:515-522, after `seriesAction`).
- Series: `seriesAction?.resumePositionMs` (Kotlin `Long?`, so read `.int64Value`; `SeriesPlaybackResolver.kt:131-139`).
- Movie: `WatchProgressRepository.shared.progressForVideo(videoId: meta?.id ?? id, parentMetaId: meta?.id ?? id, seasonNumber: nil, episodeNumber: nil)`, then `.lastPositionMs` and `.isResumable` (`WatchProgressModels.kt:47, 92-93`).
- Feed both into `DetailStartOver.isAvailable`.

**Position.** Immediately after Play/Resume, before Watch Trailer.

```swift
private var startOverButton: some View {   // new, DV, near actionRowButtons
  compactActionButtonStyle(Button {
      if isSeries, let action = model.seriesAction, let meta = model.meta {
          model.noteSeriesPlayStarted(action)
          seriesPlay = SeriesPlayRoute(meta: meta, action: action, startFromBeginning: true)
      } else { startOverMovie = true; showStreams = true }
  } label: { actionButtonPadding(actionLabel(String(localized: "Start Over"), systemImage: "arrow.counterclockwise").font(Theme.Font.meta), horizontal: Theme.Spacing.md) })
  .disabled(!model.isPlayEnabled)
  .accessibilityIdentifier("detail_start_over")
}
```

**Supporting edits:**
- `SeriesPlayRoute` (DV:2491): add `var startFromBeginning: Bool = false`.
- Series cover (DV:948-963): add `startFromBeginning: route.startFromBeginning`.
- Movie cover (DV:943-947): add `startFromBeginning: startOverMovie`, and change `onDismiss` to `{ forceManualPlay = false; startOverMovie = false }`.
- All of these are additive with defaults, so Classic's output is unchanged.

**Effect on test72.** `launchTheHundredOnPlay` (`NuvioTVUITests.swift:8069-8079`) presses Left ×3 to reach Play, then Right ×1 on the assumption that Watched is next (no trailer: `-debug.trailerForceNoTrailer`). If The 100 has saved progress on the fixture, Right ×1 lands on Start Over, and the following Select would start playback from 0. The migration is in L.

## F. DetailRowAnchor: hero decisions (W2-A)

**Additions to DRA:**

```swift
enum HeroTransition: Equatable { case exit, enterHero, none }
static func heroTransition(old: DetailRowID?, new: DetailRowID?) -> HeroTransition
   // old == nil && new != nil → .exit ; old != nil && new == nil → .enterHero ; else .none
static func heroExit(old: DetailRowID?, new: DetailRowID?) -> Bool   { heroTransition(old: old, new: new) == .exit }
static func heroReturn(old: DetailRowID?, new: DetailRowID?) -> Bool { heroTransition(old: old, new: new) == .enterHero }
static let heroTopScrollTarget: CGFloat = 0
```

- `DetailRowID` (DRA:187-189): add `about` after `comments`, and update the doc comment.
- `direction` (DRA:148): the missing-`oldTop` fallback becomes `return (old == .comments || old == .about) ? .up : .down` (both sit below every other row).
- `heroReturn` is any row → hero, not only the first row. The reason is in PLAN CONFLICTS 5.

**Wiring in `onChange(of: focusedRow)` (DV:618-716).** Gate everything on `detailLayout == .cinematic`; Classic takes today's path unchanged.

1. Refactor without changing behaviour: extract the `.up` case body (DV:654-676) into `private func startBlendAnchor(_ row: DetailRowID, fallbackNote: String)`. `.up` calls it with `"blend-fallback"`.
2. In `guard let row else {` (DV:625-631): after the existing cancels, add
   `if detailLayout == .cinematic, DetailRowAnchor.heroReturn(old: old, new: nil) { armHeroReturn(); return }`
   before the probe line.
3. After `guard row != .comments` (DV:638-642), before `direction`, add
   `if detailLayout == .cinematic, DetailRowAnchor.heroExit(old: old, new: row) { startBlendAnchor(row, fallbackNote: "hero-exit"); return }`
   This anchors the first row at `screenRest` 108 in one blended motion. It replaces the BUG-99 Down settle for this one transition only.
4. At the top of the handler, also clear `dimModel.awaitingHeroReturn = false` on every change.

**Hero-return mechanics:**
- New plain (unpublished) fields on `ScrollDimModel` (next to DV:84-85): `var awaitingHeroReturn = false` and `var awaitingHeroReturnStartOffset: CGFloat = 0`.
- `armHeroReturn()` sets them (start = `dimModel.lastContentOffset`) and starts `detailAnchorTask`:
  1. Sleep `blendFallbackDelay`. If still armed, disarm and call `heroTopPass("hero-return-fallback")`.
  2. Sleep `verifyDelay`, then `heroTopPass("hero-return-reissued", onlyIfDrifted: true)`.
  3. Sleep 350 ms and publish the geometry sample, as the Up path does.
- Geometry handler (DV:831-835): add a twin block. If `awaitingHeroReturn` and the offset has moved by at least `stationaryThreshold` from the start, disarm and call `heroTopPass("hero-return-blend")`.
- `heroTopPass(_ note: String, onlyIfDrifted: Bool = false) -> Bool`:
  - Guard: `!Task.isCancelled && focusedRow == nil && heroHasFocus && bridgePhase == .idle`. `heroHasFocus` stops a focus loss caused by a push or cover from scrolling the page.
  - Target `heroTopScrollTarget`; expected `DetailRowAnchor.expectedOffset(scrollTarget: 0, contentInsetTop: inset)`.
  - Skip if drifted by no more than `verifyTolerance`.
  - Animate exactly as `anchorPass` does (DV:1202-1208), including Reduce Motion.
  - Probe note: `"hero-return y=0 \(note)"`. It must contain no `top=` token, so the UI anchor oracle does not count it as a residual.
- Clear `awaitingHeroReturn` in `.onChange(of: bridgePhase)` (DV:719-724) and `.onDisappear` (DV:725-728).

**Dim ramp retune.** DV:769: `/ 400.0` becomes `/ Double(dimRamp)`, with `let dimRamp = DetailDim.rampDistance(layout: detailLayout, heroHeight: cinematicHeroHeight)` captured into the closure. The clamp and 0.05 quantisation stay as they are, and the quantised value should match `DetailDim.value`. Classic still ramps over 400. Cinematic saturates as the hero fully leaves.

**Trailer latch.** No numeric change (DV:846-850, 0.80 / 0.55). The latch works in dim space, so with ramp = hero height it tears the trailer down at about 94% of the hero scrolled and remounts it at about 65%. `heroReturn`'s single motion to y = 0 crosses 0.55 and remounts the trailer. Update the comment only.

**Unchanged.** Every other row keeps BUG-96/99/117: Up always anchors, Down only on straddle, `.comments` is tracked and never anchored, the relayout pass stays, and the hero keeps the full-width `.focusSection()`.

**Unit tests appended to `NuvioTVTests/DetailRowAnchorTests.swift`:**
- `heroTransition`: (nil, .logos) → .exit; (nil, .episodes) → .exit; (.cast, nil) → .enterHero; (.episodes, nil) → .enterHero; (nil, nil) → .none; (.cast, .trailers) → .none.
- `heroExit` and `heroReturn` mirror those.
- `direction(old: .about, oldTop: nil, newTop: 300)` → .up.
- `direction(old: .comments, oldTop: 900, newTop: 1400)` with new = .about → .down.
- `heroTopScrollTarget == 0`.

## G. About section (Cinematic only, last row; W2-A)

**Fields.** All of them exist in `MetaDetails` (`MetaDetailsModels.kt:6-46`). Same sources as Classic's `infoRows` (DV:1845-1865), which stays untouched.

| Row | Field |
|---|---|
| Director, or "Created by" when `isSeries` | `director: List<String>`, joined ", " |
| Writers | `writer` |
| Studios | `productionCompanies.map(\.name)` |
| Network | `networks.map(\.name)` |
| Country | `country: String?` |
| Language | `language` |
| Status | `status` |
| Awards | `awards` |
| Ratings (only when `sectionRatings`) | `externalRatings` through `DetailRatings.ordered`, formatted "IMDb 7.4 · Rotten Tomatoes 88% · …" |

**New file `Screens/Detail/DetailAboutSection.swift`:**

```swift
struct DetailAboutRow: Equatable, Identifiable { let label: String; let value: String; var id: String { label } }
enum DetailAboutRows {
  static func make(director: [String], writer: [String], studios: [String], networks: [String],
                   country: String?, language: String?, status: String?, awards: String?,
                   ratings: [DetailRatingEntry], showRatings: Bool, isSeries: Bool) -> [DetailAboutRow]  // skips empty/blank
}
struct DetailAboutSection: View {
  let rows: [DetailAboutRow]
  let isFocused: Bool          // DetailView passes focusedRow == .about
  var body: some View
}
```

**Layout of `DetailAboutSection.body`:**
- `VStack(alignment: .leading, spacing: Theme.Spacing.md)`:
  - `Text("About").font(Theme.Font.sectionTitle).foregroundStyle(textPrimary)`
  - `Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: Theme.Spacing.lg, verticalSpacing: Theme.Spacing.sm) { ForEach(rows) { GridRow { Text(label).font(Theme.Font.meta).foregroundStyle(textSecondary).frame(width: 220, alignment: .leading); Text(value).font(Theme.Font.detail).foregroundStyle(textPrimary).frame(maxWidth: 1100, alignment: .leading) } } }`
- The grid carries:
  - `.background { platter }`: a copy of Person's `topFocusPlatter` (`PersonDetailView.swift:108-116`; fill `surface.opacity(isFocused ? 0.9 : 0)`, white stroke at 0.55 when focused, `.padding(-Theme.Spacing.md)`).
  - `.focusable()` (inert; Select does nothing). This is the Person page's BUG-34 pattern at `PersonDetailView.swift:67-104` (`.focusable()` at :99).
  - `.accessibilityElement(children: .combine)`, `.accessibilityIdentifier("detail_about")`.
- Whole section: `.frame(maxWidth: .infinity, alignment: .leading).focusSection()`.
- Render nothing when `rows` is empty.

**Call site.** In DV's second `Group` after `commentsSection` (DV:587-588):

```swift
if detailLayout == .cinematic && sectionAbout {
  DetailAboutSection(rows: aboutRows, isFocused: focusedRow == .about)
    .detailRowAnchored(.about, focusedRow: $focusedRow, offsets: $detailRowOffsets)
}
```

- The `Group` goes from 5 to 6 children, well under the ViewBuilder limit of 10.
- `.about` takes the normal anchor path. It is not a comments-style bail.
- `aboutRows` is a private computed property in DV calling `DetailAboutRows.make` with the `KotlinInt`/`String?` widening seen at DV:1856-1859.

**Unit tests: `NuvioTVTests/DetailAboutRowsTests.swift`**
- All fields set → 9 rows in the stated order, with labels.
- `isSeries` → first label "Created by".
- Blank and empty values skipped.
- `showRatings: false` → no Ratings row.
- Ratings value joined with " · " in strip order.
- Everything empty → [].

## H. Section toggles

All are new `@AppStorage` Bools in DV (W2-A, except `sectionRatings`, which W1-A adds), default **true**. Keys come from `DetailSettingsKeys`. Episodes has no toggle.

| Toggle | Key | Gate site (base) |
|---|---|---|
| Studio Logos | `detail_section_studio_logos` | DV:550-551 `if sectionStudioLogos { companyLogosRow.detailRowAnchored(.logos…) }` |
| Parental Guide | `detail_section_parental_guide` | DV:552-553 |
| Ratings | `detail_section_ratings` | Cinematic hero strip (`cinematicHero`, W1-A) and the About Ratings row |
| Cast | `detail_section_cast` | DV:568-569 |
| Collection | `detail_section_collection` | DV:570-571 |
| Trailers & Extras | `detail_section_trailers` | DV:572-573 |
| More Like This | `detail_section_more_like_this` | DV:574-575 |
| Comments | `detail_section_comments` | DV:587-588 |
| About | `detail_section_about` | the new call site in G |

The row gates apply to both layouts. Ratings and About only have an effect in Cinematic, because Classic's `topBlock` must stay byte-identical. A stale `detailRowOffsets` entry for a hidden row is harmless: focus can never be in it.

## I. Spoiler-safe episodes (W1-C, `EpisodesSection.swift` only)

**Key.** `detail_hide_episode_spoilers`, default OFF. Read in ES as `@AppStorage(EpisodeSpoilerRules.defaultsKey) private var hideSpoilers = false`.

**How watched state is known.** `watchedEpisodeKeys: Set<String>` ("season:episode") is passed in from `DetailViewModel.computeWatchedEpisodeKeys()` (DVM:730-748: explicitly marked watched, or progress effectively complete), read through `isWatched(_:)` at ES:274-277.

**New `Screens/EpisodeSpoilerRules.swift`:**

```swift
enum EpisodeSpoilerRules {
  static let defaultsKey = "detail_hide_episode_spoilers"
  static let stillBlurRadius: CGFloat = 28
  struct EpisodeFacts: Equatable { let season: Int?; let episode: Int?; let released: String? }
  nonisolated static func isAired(released: String?, todayIsoDate: String) -> Bool
     // trimmed, ≥10 chars, prefix(10) matches ^\d{4}-\d{2}-\d{2}$, and prefix(10) <= todayIsoDate.prefix(10); nil/invalid → false
  nonisolated static func hidesSpoilers(settingOn: Bool, isWatched: Bool) -> Bool   // settingOn && !isWatched
  nonisolated static func airedUnwatchedCount(_ episodes: [EpisodeFacts], watchedKeys: Set<String>, todayIsoDate: String) -> Int
     // counts episodes with both numbers, isAired, and "\(s):\(e)" ∉ watchedKeys
  nonisolated static func airedUnwatchedLabel(count: Int, settingOn: Bool) -> String?
     // nil when !settingOn || count == 0, else String(localized: "\(count) aired unwatched")
}
```

**ES edits, in order:**
1. ES:20: add the `@AppStorage`.
2. Heading, ES:89:
   ```swift
   HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.md) {
     Text(String(localized: "Episodes")).font(Theme.Font.screenTitle)   // unchanged
     if let label = EpisodeSpoilerRules.airedUnwatchedLabel(count: …, settingOn: hideSpoilers) {
       Text(label).font(Theme.Font.meta).foregroundStyle(Theme.Palette.textSecondary)
         .accessibilityIdentifier("episodes_aired_unwatched")
     }
   }
   ```
   The count is for the current season's `episodes` (ES:28), with `today = CurrentDateProvider.shared.todayIsoDate()` (as at DVM:721). This is the line directly under the season selector (UX-15), and it covers single-season shows that have no picker. Movies never render ES (`isSeriesLike`). A fully watched season gives count 0, so the label is hidden.
3. `EpisodeThumbCard` (ES:309):
   - Add `var hidesSpoiler: Bool = false`.
   - In `body`, put `.blur(radius: hidesSpoiler ? EpisodeSpoilerRules.stillBlurRadius : 0, opaque: true)` on the `CachedAsyncImage` before `.clipped()` (ES:325-330).
   - The call site (ES:98-103) passes `hidesSpoiler: EpisodeSpoilerRules.hidesSpoilers(settingOn: hideSpoilers, isWatched: isWatched(episode))`.
4. `focusedOverviewPanel` (ES:159-165): when `hidesSpoilers(...)` is true for the panel's episode, render `Text(String(localized: "Synopsis hidden until watched")).font(Theme.Font.caption).foregroundStyle(Theme.Palette.textSecondary).accessibilityIdentifier("episode_synopsis_hidden")` instead of the overview. The caption line (S/E · date · runtime) stays.

**Not touched in ES:** episode titles, rating badges, the `EpisodeRoute` synopsis handed to the picker, and the season-poster cards.

**Unit tests: `NuvioTVTests/EpisodeSpoilerRulesTests.swift`**
- `isAired`, with today "2026-10-02":
  - "2024-04-12" → true; "2026-10-02" → true; "2026-10-03" → false
  - nil → false; "2024" → false; "2024-04-12T00:00:00.000Z" → true; "abcd-ef-ghij" → false
- `airedUnwatchedCount`:
  - S1E1, E2, E3 aired, watched {"1:1"} → 2
  - plus an unaired E4 → still 2
  - an episode with a nil episode number → excluded
  - all watched → 0
- `airedUnwatchedLabel`: (0, true) → nil; (3, false) → nil; (3, true) → non-nil and contains "3".
- `hidesSpoilers`: the 4-case truth table.
- `EpisodeSpoilerRules.defaultsKey == DetailSettingsKeys.hideEpisodeSpoilers`. This compiles once W1-A has landed; both land before Gate 1.

## J. Classic invariant (`detail_layout = "classic"`)

**Must render byte-identically:**
- `topBlock` (DV:1339-1370), `header` (:1372-1386), `metaLine` and `metaChip` (:1399-1513)
- `synopsisPanel` and `detailPanelBackground` (:1454-1499), `infoSection` and `infoRows` (:1814-1870)
- `scrimOverlay` with the classic `DetailScrim` constants (:1303-1323, :2559-2576)
- The dim ramp over 400; the latch at 0.80 / 0.55
- The anchor behaviour: Down settle, Up blend, Comments bail, no hero scroll
- `actionRowButtons` output: Start Over is gated off; the added `.focused` on Play has no visual effect, and Classic sets no `defaultFocus`
- No About section, no ratings strip
- The section toggles (default ON) and the spoiler setting (default OFF) leave Classic as it is today

**Tests that pin Classic:**
- `NuvioTVTests/DetailScrimTests.swift` (classic stops, panel constants, flat truth table): must pass unchanged.
- `DetailScrollProbeTests` unit (`chipGlassFlat`).
- The existing `DetailRowAnchorTests` unit cases.
- New UI test test80 (L) asserts `detail_synopsis_panel` under `-detail_layout classic`.

## K. Work split

### W1-A (Opus): hero, sheet, switch, scrim constants, view-model gates

**Files owned:**
- `Screens/DetailView.swift`
- `Screens/DetailViewModel.swift`
- New `Screens/Detail/DetailSettingsKeys.swift`, `DetailCinematicLayout.swift`, `DetailCinematicHero.swift`, `DetailSynopsisSheet.swift`
- New `NuvioTVTests/DetailCinematicLayoutTests.swift`, `NuvioTVTests/DetailScrimCinematicTests.swift`

**Ordered edits:**
1. Create C1 and C2 and their tests.
2. Add the cinematic constants and the two composite-alpha functions to `DetailScrim` (DV:2559-2576). Write the grid test plus constant pins (D, A). Apply the tuning rule from A if the grid test fails.
3. DVM: `mdbListRatingsActive` and its watcher (D); `hasResumableProgress` in `refreshFlags` (E).
4. Create C3 and C4.
5. DV state block (B) near DV:343-362 and DV:459.
6. DV:546 → `heroBlock`; add `cinematicHero`.
7. DV:532 and DV:1014 scrim switch; add `cinematicScrimOverlay`.
8. `viewportMetrics` `onScrollGeometryChange` next to DV:803.
9. `actionRowButtons`: the Play `.focused` additions and the `startOverButton` insertion (B, E); add the `startOverButton` property.
10. `SeriesPlayRoute.startFromBeginning` (DV:2491) and both covers (DV:943-963).

**Do not touch:** `topBlock`, `header`, `metaLine`, `synopsisPanel`, `infoSection`/`infoRows`, `scrimOverlay`, the classic `DetailScrim` constants, the `onChange(of: focusedRow)` handler, the dim closure, the latch, DRA, ES, the row views and the section gates.

### W1-C (Sonnet): spoiler-safe episodes

**Files owned:** `Screens/EpisodesSection.swift`, new `Screens/EpisodeSpoilerRules.swift`, new `NuvioTVTests/EpisodeSpoilerRulesTests.swift`.

**Ordered edits:** I.1 → I.4, then the tests.

**Do not touch:** DetailView, DVM, season-poster focus or styles, `cardFocusButtonStyle`/`posterButtonShape`, the shelf scroll logic (ES:115-122).

This is disjoint from W1-A. The only shared symbol is the key-equality test.

### W2-A (Opus, after Gate 1): anchor, scroll, About, section gates, tests

**Files owned:** `Screens/DetailRowAnchor.swift`, `Screens/DetailView.swift`, new `Screens/Detail/DetailAboutSection.swift`, `NuvioTVTests/DetailRowAnchorTests.swift` (append), new `NuvioTVTests/DetailAboutRowsTests.swift`.

**Ordered edits:**
1. DRA: `HeroTransition`, `heroExit`/`heroReturn`/`heroTopScrollTarget`, `.about`, the `direction` fallback (F).
2. `ScrollDimModel` hero-return fields (DV:84-85 area).
3. Extract `startBlendAnchor`; add the hero branches in `onChange(of: focusedRow)`; `armHeroReturn` and `heroTopPass`; the geometry-handler twin block; clears in the `bridgePhase` change and on disappear (F).
4. Dim ramp `/400` → `DetailDim.rampDistance` (DV:769); update the latch comment (DV:844-845).
5. Section `@AppStorage`s and the row gates (H).
6. About file, `aboutRows`, and the call site (G).
7. Unit tests.

**Do not touch:** the Classic hero views, the `DetailCinematicHero` internals (other than reading `cinematicHeroHeight`), ES, the trailer bridge, and the BUG-96/99 rules for non-hero transitions.

Every W2-A edit to classic-path code must keep Classic's runtime behaviour, gated by `detailLayout == .cinematic`.

UI test migration is W3-C (L). W2-B's settings pane consumes `DetailSettingsKeys` as-is.

## L. Test impact

**Existing unit tests**
- `DetailScrimTests`, `DetailScrollProbeTests` (unit), `TrailerBridgeTests`: no change, must stay green.
- `DetailRowAnchorTests` (unit): no existing case breaks. Append the F cases.

**Existing UI tests (`NuvioTVUITests/NuvioTVUITests.swift`)**
- **test02** (:527): Home Down ×4 then screenshots only; no Detail Down counts. Nothing breaks, no change.
- **test17** (:1165): the asserts at :1179-1181 need `detail_synopsis_panel`/`detail_synopsis_text`. Replace with `app.descendants(matching: .any)["detail_synopsis_teaser"].waitForExistence(timeout: 5)` and update the message. The Down ×4 + ×4 dim walk still works (heroExit saturates the dim).
- **test21** (:1506): Down ×10 from Play toward Trailers is a soft probe. The teaser sits above Play, so the Down count is unchanged; About adds a row after Comments. No change needed. Optionally lower to Down ×9 if the screenshot shows an overshoot.
- **test33** (:2524): Down ×3 to the episode row still works (the teaser is above Play). The asserts at :2550-2552 change to `detail_synopsis_teaser`.
- **test51** (:6909): `app.buttons["Watch Trailer"]` is still the same `actionRow` button; `debug_bridge` is unchanged. No change. Default focus is Play through `.defaultFocus`.
- **test68** (:7835): extend the `topBlockLabels` match at :7844 and :7904-7906 to:
  - "Mark Watched", "Watched", "Add to Library", "In Library", "Start Over"
  - any button whose label begins with "Play", "Resume" or "Up Next"
  - the element `detail_synopsis_teaser` having focus

  After the Up press, also assert the hero returned to the top: `debug_ux6` `dark=` reaches 0 within 2 s, or `anchor=hero-return` when the probe is on. Add `-debug.detailScrollProbe YES` to the launch args if asserting the note.
- **test72** (:8145), via the helper at :8075: change `press(.right, times: 1, gap: 1.0)` to `press(.right, times: app.buttons["Start Over"].exists ? 2 : 1, gap: 1.0)`. Add a guard before the Select: `guard app.buttons["Watched"].hasFocus else { throw XCTSkip("focus not on Watched") }`. hasFocus is reliable on 26.5 (precedent in test68 at :7904).
- **DetailRowAnchorTests UI** (`NuvioTVUITests/DetailRowAnchorTests.swift`):
  - The `sectionLabels` whitelist (:123-124) already keeps hero text out of the oracle. The only open-ended matches are the `hasSuffix("Saga"/"Collection")` filters at :131/:199, and no hero line ends that way. No filter change is needed.
  - Step 1 Down now reads `anchor=<row> … hero-exit` with residual ≈ 0, not `free`. `downFreeSteps >= 2` still has steps 2–6 to come from.
  - Up-leg `hero-return` notes carry no `top=`, so they are ignored by design.
  - Re-baseline after the first run.
- **DetailScrollProbeTests UI**:
  - `testDimTrailerGlassHysteresisOnScroll` (:211): the dim still reaches ≥ 800 (the hero exit saturates it); Up back to the hero → dim 0 < 550 and the trailer remounts; `glass=` is unchanged (`chipGlassFlat`). Should pass.
  - The ab-leg-4 test (:271) and the log harvest (:297): unchanged.

**New UI tests (W3-C; test77–test80 are free, the highest today is test90 with 77–89 unused):**
- **test77 Cinematic landing.** Default focus on a Play/Resume button (hasFocus). `detail_logo_slot` frame height is 180 ± 1 at 2 s and again after the meta settles at 8 s. `debug_detail_hero` reports `logo=180`. The first section title has minY < 1080 and > 1080 − 200, i.e. it peeks.
- **test78 Synopsis sheet.** Open a title whose probe says `trunc=1` (skip otherwise). Up from Play focuses `detail_synopsis_teaser`; Select → `detail_synopsis_sheet` exists; Menu → it is gone and Detail is still up.
- **test79 Up from the first row restores the top.** Down ×1 → `anchor=… hero-exit`; Up ×1 → `hero-return`, dim 0, `detail_logo_slot` minY equal to its landing value ± 8.
- **test80 Classic still shows the panel.** `-detail_layout classic` → `detail_synopsis_panel` exists, and `detail_synopsis_teaser`, `detail_about` and "Start Over" do not.

**New unit tests:** `DetailCinematicLayoutTests`, `DetailScrimCinematicTests`, `EpisodeSpoilerRulesTests`, `DetailAboutRowsTests`, plus the DRA additions. The plan's "ratings ordering" and "synopsis truncation" unit tests are inside `DetailCinematicLayoutTests`.

## M. Risks, plan conflicts, open questions

### PLAN CONFLICTS
1. **Action row vs the 900 pt column.** Six labelled buttons (Resume S1E3 · Start Over · Watch Trailer · Mark Watched · Add to Library · Shuffle) measure about 1500 pt, more than both the 900 pt column and the space left beside a 640 pt credits block. The spec puts the action row on its own full-width line below the text column. The credits are bottom-aligned to the synopsis slot instead of the action row.
2. **"Created by when the meta carries it."** `MetaDetails` has no creator field. TMDB maps TV `createdBy` into `director` (`TmdbMetadataService.kt:1901-1915`), so the spec uses "Created by" with `director` whenever `isSeries`. TMDB also prepends crew to `cast` (:1885-1890), so "With" filters out director and writer names.
3. **Ratings toggle OFF brings the IMDb ★ back.** Read literally ("★ only when the strip is off or empty"), turning the Ratings section OFF puts the ★ back on the meta line, which defeats FEAT-28 "hide ratings". The spec is literal. **Christian decides**: the alternative is a one-line change to `showImdbStar = sectionRatings && !(ratingsGateOn && !ratings.isEmpty)`. The spec does hide the About Ratings row when the toggle is off.
4. **"Switch only" in DetailView.** Start Over and focus-on-Play need small additive edits outside the switch point:
   - the `actionRowButtons` insertion and the `.focused` on Play
   - `SeriesPlayRoute.startFromBeginning`
   - the two cover arguments
   - DVM additions (MDBList active, resumable progress)

   Classic's runtime output is unchanged.
5. **`heroReturn` is any row → hero, not only the first row.** BUG-117 lets Up from a far-right season poster jump straight into the hero past rows with no focusable directly above, so "first row only" would miss it. Any transition into the hero is upward by construction.
6. **Wave boundaries moved.** Hero and peek height moved from W2-A to W1-A, because the Gate 1 screenshots need the real hero. The Cinematic `DetailScrim` tests sit with the constants in W1-A, not W2-A.
7. **Plan evidence line.** test02 has no Detail Down counts, and test21's count is not affected.
8. **Scrim ceiling.** Interpreted as point-wise composite darkness ≤ Classic, enforced by a grid unit test.
9. **Spoiler count.** "N aired unwatched" is gated by the spoiler setting, so the defaults keep today's behaviour. It shows next to the "Episodes" heading under the season selector, not in the 180 pt poster captions where it would truncate.
10. **Synopsis sheet scrolling.** tvOS cannot scroll a ScrollView with no focusable content, so the sheet uses an inert `.focusable()` plus `onMoveCommand` paging.

### Risks
- **`.defaultFocus` inside a ScrollView** has not been verified on this runtime. Fallback if test77 fails: make the teaser `.focusable(isTruncated && heroFocusSettled)`, where `heroFocusSettled` flips true about 0.5 s after appear.
- **Focus loss under a push or cover could fire `heroReturn`.** Guarded by `heroHasFocus` plus `bridgePhase == .idle`. Verify on the device pass: Cast → Person → back.
- **Hero height depends on the scroll view's container and insets** (assumed full-screen with a top inset of about 157). Confirm against `debug_ux6 geo` and `debug_detail_hero h=` at Gate 1. If the measured peek is off, adjust only `peekBand`.
- **Larger Text.** The 44 pt ratings slot can clip at accessibility sizes, and the hero then grows past the viewport (the peek is lost).
- **Empty reserved ratings slot** when MDBList returns nothing (a 44 pt gap above the synopsis).

### Open questions
- PLAN CONFLICTS 3: the ★ behaviour when the Ratings toggle is off.
- Should the About section show its Ratings row when MDBList is active but the strip is hidden?

### Critical files for implementation
- `/Users/christianturnbull/Claude/Projects/Nuvio tvOS/NuvioMobile/iosApp/NuvioTV/Screens/DetailView.swift`
- `/Users/christianturnbull/Claude/Projects/Nuvio tvOS/NuvioMobile/iosApp/NuvioTV/Screens/DetailRowAnchor.swift`
- `/Users/christianturnbull/Claude/Projects/Nuvio tvOS/NuvioMobile/iosApp/NuvioTV/Screens/EpisodesSection.swift`
- `/Users/christianturnbull/Claude/Projects/Nuvio tvOS/NuvioMobile/iosApp/NuvioTV/Screens/DetailViewModel.swift`
- `/Users/christianturnbull/Claude/Projects/Nuvio tvOS/NuvioMobile/iosApp/NuvioTVUITests/NuvioTVUITests.swift`

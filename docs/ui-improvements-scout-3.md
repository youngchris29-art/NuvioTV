# UI Improvements Scout 3 — 2026-07-05

Scouting notes for four UI changes: hero backdrop dimming, poster card platter removal,
poster focus clipping, and the profile picker (centering + focus style).
Files are under `NuvioMobile/iosApp/NuvioTV/`.

---

## 1. Home: hero backdrop only when the hero is highlighted; dark background over the catalogs

**File:** `Screens/HomeView.swift`

Current state: `HomeHeroBackdrop` (lines 30–33, struct at 198–219) and `HomeHeroScrim`
(223–241) are drawn **behind** the `ScrollView` in the `ZStack`, pinned to the top with
`ignoresSafeArea`, height `Theme.Size.heroBackdropHeight` (820pt). Because they're outside the
scroll, the artwork stays fully visible while the rows scroll over it — that's why the backdrop
"fills the background" when you're down in the catalogs.

**Key existing hook:** `@FocusState private var heroFocused: Bool` (line 14) is already bound to
the hero foreground via `.focused($heroFocused)` (line 43). It's currently only used to pause the
rotation timer. Focus is a better signal than scroll offset on tvOS — the moment you swipe down
into Continue Watching / a catalog row, `heroFocused` flips false.

**Change (small):** fade the backdrop + scrim out when the hero loses focus, revealing the flat
`Theme.Palette.background` (0x0D0D0D) that's already the bottom ZStack layer:

```swift
if let hero = currentHero {
    HomeHeroBackdrop(item: hero)
    HomeHeroScrim()
}
// becomes:
if let hero = currentHero {
    Group {
        HomeHeroBackdrop(item: hero)
        HomeHeroScrim()
    }
    .opacity(heroFocused ? 1 : 0)
    .animation(.easeInOut(duration: 0.4), value: heroFocused)
}
```

Notes / gotchas:
- Default focus lands on the hero at launch, so the backdrop shows initially — correct behavior.
- Consider dimming to ~0.15 opacity instead of 0 if full black feels too abrupt; try 0 first.
- Optionally pause the hero rotation timer while not focused (`guard heroFocused` in the
  `onReceive`) so the image doesn't churn invisibly — currently it rotates when NOT focused,
  which is the opposite; leave rotation logic as is unless it looks odd on device.
- The hero **foreground** (logo/synopsis, in the scroll content) is untouched — it scrolls away
  naturally and keeps its styling while focused.

Effort: ~15 min + device check.

---

## 2. Poster cards: remove the background/platter around poster + label

**Files:** `DesignSystem/PosterCard.swift` (both `PosterCard` and `LandscapeCard`),
call sites use `.buttonStyle(.card)`.

**Diagnosis:** the grey background/border is the tvOS system **`.card` button-style platter**.
The whole `VStack` (image + title text) is the button label, so the system draws its rounded
platter behind everything — visible as a grey frame around the poster and under the label. It is
not drawn by `PosterCard` itself (the only overlay there is the 4pt accent focus ring).

**Recommended fix — custom button style, one place, app-wide effect:**

Add to `DesignSystem/` (e.g. `PosterCard.swift` or a new `TileButtonStyle.swift`):

```swift
/// Platter-free replacement for `.card`: no background, no border; focus = scale + soft glow.
struct PosterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
extension ButtonStyle where Self == PosterButtonStyle {
    static var poster: PosterButtonStyle { .init() }
}
```

Then inside `PosterCard`/`LandscapeCard` (which already read `@Environment(\.isFocused)`),
add the focus motion that `.card` used to provide, applied to the **image only** so the label
just brightens as it does today:

```swift
CachedAsyncImage(...)
    ...
    .scaleEffect(isFocused ? 1.07 : 1)
    .shadow(color: .black.opacity(isFocused ? 0.55 : 0), radius: 22, y: 10)
```

- `@Environment(\.isFocused)` keeps working with a custom style because the `Button` itself is
  still the focusable element (same mechanism as today under `.card`).
- Keep or drop the accent focus ring (`strokeBorder(Theme.Palette.accentFocus, ...)`) to taste —
  with scale + shadow it may read cleaner without the ring. Flag for device review.
- Trade-off: we lose the system card parallax/tilt on remote-touch. If that's missed, the
  alternative is keeping `.card` but restructuring so ONLY the image is the button label and the
  title sits outside the button — much more invasive (every call site changes shape, and the
  title loses its focus-brighten). Custom style is the better path.

**Call-site swap `.buttonStyle(.card)` → `.buttonStyle(.poster)`** — only where the label is a
poster/landscape tile (leave Settings rows, MPV player, ContentView, Detail action buttons on
`.card` unless they show the same platter problem):

| File | Lines (approx) |
|---|---|
| `Screens/BrowseComponents.swift` | 112, 117 (catalog rows — Home + Search) |
| `Screens/HomeView.swift` | 161 (Continue Watching `LandscapeCard`) |
| `Screens/SearchView.swift` | 210 |
| `Screens/CatalogGridView.swift` | 45 |
| `Screens/LibraryView.swift` | 46 |
| `Screens/DetailView.swift` | 274, 362 ("more like this" / cast rails using `PosterCard`) |
| `Screens/PersonDetailView.swift` | 119 |
| `Screens/EntityBrowseView.swift` | 251 |
| `Screens/CollectionsUI.swift` | 249 (+ 57/290 folder tiles if they platter too) |

Effort: ~1–2 hrs including sweep + device check.

---

## 3. Poster cards: fix cutoff when highlighted

**Diagnosis:** the focus lift (system `.card` today, our `scaleEffect` tomorrow) grows the tile
beyond its layout bounds, and the enclosing `ScrollView` **clips** it. The horizontal rows only
reserve `.padding(.vertical, Theme.Spacing.sm)` (12pt) — a 330pt poster scaled 1.07 needs ~12pt
top AND bottom just for scale, plus shadow. Grids have the same issue between rows.

**Fix (two parts, apply to every poster scroll container):**

1. `.scrollClipDisabled()` on the `ScrollView` (tvOS 17+, we target 26 — fine). This is the real
   fix; it lets the lifted card render outside the scroll bounds.
2. Bump breathing room where rows sit close: `.padding(.vertical, Theme.Spacing.sm)` →
   `Theme.Spacing.lg` in `CatalogRowView` (BrowseComponents.swift:121) and the Continue
   Watching row (HomeView.swift:171) so lifted cards don't overlap section titles above/below.

Containers to touch:

- `BrowseComponents.swift:107` — `CatalogRowView` horizontal ScrollView
- `HomeView.swift:151` — Continue Watching horizontal ScrollView
- `CatalogGridView.swift` — the `LazyVGrid`'s vertical ScrollView (check grid spacing too)
- `LibraryView.swift`, `SearchView.swift`, `CollectionsUI.swift`, `EntityBrowseView.swift`,
  `PersonDetailView.swift`, `DetailView.swift` rails — same pattern, sweep them all
- Note: the outer vertical `ScrollView` on Home (HomeView.swift:35) may also clip a lifted card
  at the screen bottom edge — add `.scrollClipDisabled()` there as well if needed on device.

Effort: ~1 hr sweep + device check (do together with #2 since both touch focus rendering).

---

## 4. Profile picker: center the tiles + soft-glow focus instead of grey border

**File:** `Screens/ProfileSelectionView.swift` (lines 42–211)

### 4a. Centering

Current: tiles live in `ScrollView(.horizontal)` → `HStack` (lines 69–127). A ScrollView's
content is leading-aligned, so with 1–3 profiles the row hugs the left edge.

`maxProfiles = 6` (ProfilesViewModel.swift:18). Six tiles ≈ 6×170 + 5×40 spacing + badges
≈ ~1,250pt — comfortably inside a 1920pt screen even with margins. **The ScrollView is
unnecessary; replace it with a plain centered `HStack`:**

```swift
HStack(alignment: .top, spacing: Theme.Spacing.xl) { ...tiles... }
    .frame(maxWidth: .infinity)          // centers within the full-width VStack
    .padding(.vertical, Theme.Spacing.lg)
    .focusSection()
```

(The outer `VStack` is already vertically centered in the `ZStack`, so this alone puts the row
in the middle of the screen.) If we ever raise `maxProfiles`, revisit — but don't pre-build for it.

### 4b. Focus style: remove grey border, add glow + zoom

The grey border is again the **`.card` platter** (`.buttonStyle(.card)` at lines 95 and 122)
wrapping the whole tile (avatar + name + PRIMARY badge).

Replace with a dedicated style (reuse the `PosterButtonStyle` from #2, or a `GlowTileButtonStyle`
if we want a stronger glow here). Then add focus treatment inside `profileTile(...)` (line 189) —
it needs focus awareness, so add `@Environment(\.isFocused)` by converting `profileTile` from a
private func into a small `ProfileTileLabel: View` struct (env vars don't work in plain funcs):

```swift
struct ProfileTileLabel<Content: View>: View {
    let name: String
    var isPrimary = false
    @ViewBuilder let avatar: Content
    @Environment(\.isFocused) private var isFocused

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            avatar
                .scaleEffect(isFocused ? 1.12 : 1)
                .shadow(color: .white.opacity(isFocused ? 0.45 : 0), radius: 28)
                .shadow(color: Theme.Palette.accent.opacity(isFocused ? 0.35 : 0), radius: 44)
            Text(name)
                .font(Theme.Font.sectionTitle)
                .foregroundStyle(isFocused ? Theme.Palette.textPrimary : Theme.Palette.textSecondary)
            // PRIMARY badge unchanged
        }
        .animation(.easeOut(duration: 0.18), value: isFocused)
    }
}
```

- Double shadow = soft white rim + faint accent halo; tune opacities/radii on device.
  (Avatars are circles, so `.shadow` naturally reads as a circular glow — no extra mask needed.)
- Apply the same style to the **Add Profile** tile (line 122).
- The avatar-catalog + color-palette buttons in `ProfileEditView` (lines 323/337/362) also use
  `.card`; they're small circles where the platter is less offensive — optional same treatment,
  decide on device.
- Keep the `contextMenu` (long-press edit/delete) — unaffected by button style.

Effort: ~1–2 hrs + device check.

---

## Suggested implementation order

1. **#2 + #3 together** (one focus-rendering pass: `PosterButtonStyle`, call-site sweep,
   `.scrollClipDisabled()` sweep) — verify on device.
2. **#1** hero fade (tiny, isolated) — verify.
3. **#4** profile picker (independent screen) — verify.

Single Xcode target rebuild each round; no shared-Kotlin changes anywhere in this batch.

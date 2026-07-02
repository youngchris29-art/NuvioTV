# UI Modernization Scouting — Liquid Glass + App Icon

*2026-07-02. Scope: NuvioTV tvOS target. References: mobile app screenshots (detail hero, home, profile picker) + Nuvio logo.*

## Where we stand

The good news: the deployment target is already **tvOS 27.0**, and every Liquid Glass API (`glassEffect`, `GlassEffectContainer`, `.buttonStyle(.glass)` / `.glassProminent`) is available from tvOS 26.0+. No availability guards needed anywhere — we can adopt the full design language directly.

Current UI state, from a pass over the 42 Swift files:

- **Theme.swift** is a solid token system (Crimson palette + 6 alternate accents, 10-ft typography, overscan-safe spacing). It stays; glass layers on top of it.
- **~8 call sites** use `.background(.thinMaterial, ...)` — ProfileSelectionView, SettingsView, SearchView, AuthView, AddonsView. These are the mechanical `glassEffect` conversions.
- **Buttons** use `.card`, `.bordered`, `.borderedProminent` — DetailView's Play/action row and ProfileSelectionView's management buttons are the visible ones.
- **MainTabView** uses the legacy `TabView` + `.tabItem` API. It renders fine, but the modern `Tab(_:systemImage:value:)` syntax is the tvOS 26+ path and gets the floating glass top bar — which already looks like the pill nav in the mobile home screenshot.
- **App icon**: `App Icon & Top Shelf Image.brandassets` exists with the full Back/Middle/Front layer structure, but **every Content.imageset is empty** — the app currently ships with the default placeholder icon.

One hardware note: Liquid Glass rendering requires Apple TV 4K (2nd gen, 2021) or later. On older boxes tvOS falls back to a dimmed material automatically, so nothing breaks — it just looks flatter.

## Proposed changes, by impact

### 1. Tab bar → modern glass top bar (small, high visibility)

Migrate `MainTabView` to the `Tab` initializer syntax. On tvOS 26+ the system top bar is already Liquid Glass; the new API ensures we get the current treatment plus per-tab niceties. This single change makes every screen's chrome feel current, and visually matches the mobile app's floating pill nav.

### 2. Material → glass conversions (mechanical)

Replace each `.background(.thinMaterial, in: shape)` with `.glassEffect(.regular, in: shape)`. Candidates: search field chrome (SearchView:28), settings cards (SettingsView:463), profile hint + management sheet (ProfileSelectionView:72, 263), auth panels (AuthView:40, 49), addon rows (AddonsView:40, 120). Where the glass sits over the accent color, `.glassEffect(.regular.tint(Theme.Palette.accent.opacity(0.2)), in: shape)` keeps brand color in the material.

### 3. Detail screen hero — match the mobile reference (the big one)

The "The Beauty" screenshot is the target: edge-to-edge backdrop, left-aligned logo/title block, then a control cluster. Concretely for DetailView:

- Wrap the Play button + "+" (library) button in a `GlassEffectContainer` so they read as one floating glass cluster and morph together on focus. Play gets `.buttonStyle(.glassProminent)` (white/accent fill), the "+" gets `.buttonStyle(.glass)`.
- Metadata row as glass capsules: the `TV-MA | ONGOING` outlined pill, runtime, country, language — each a small `.glassEffect(.regular, in: .capsule)` chip instead of plain text. IMDb badge keeps its yellow plate.
- Keep (or strengthen) the left→right gradient scrim under the text block — glass needs contrast management over bright poster art, and the scrim is what makes both the text and the glass legible.

### 4. Profile picker polish

The mobile "Who's watching?" screen uses a subtle color-graded background (deep teal) with the avatar ring focus treatment. tvOS version: radial/linear gradient background derived from `Theme.Palette.accent` at low saturation, glass ring + scale on focus (the `.card` button style already gives motion; add `.glassEffect` on the name/PRIMARY badge chip), and move "Hold to manage profile" into a glass capsule.

### 5. Home hero + rows (incremental)

Home already has the hero/trailer player. Alignments with the mobile reference: page-dot indicator under hero metadata as small glass dots, "View All" as a glass capsule button, and section headers left as-is (typography already matches). Poster cards should *not* get glass — content stays content; glass is for controls, which is Apple's own guidance for tvOS (overlays float above the media layer).

### 6. Player + stream picker (later)

Transport controls are mostly system-provided and already glassy in tvOS 26+. StreamPickerView rows and the next-episode autoplay card are good `glassEffect` candidates once 1–5 land.

## App icon — Nuvio logo

tvOS icons are **layered image stacks** (parallax), not flat PNGs. The brandassets structure already exists; it needs images dropped in:

| Asset | Layers | @1x | @2x |
|---|---|---|---|
| App Icon | Back / Middle / Front | 400×240 | 800×480 |
| App Icon – App Store | Back / Middle / Front | 1280×768 | 2560×1536 |
| Top Shelf Image | single | 1920×720 | 3840×1440 |
| Top Shelf Image Wide | single | 2320×720 | 4640×1440 |

Proposed layering with the Nuvio mark:

- **Back**: dark gradient, `#0D0D0D → #16141F` (matches app background, hint of the logo's purple).
- **Middle**: soft radial glow in the logo's cyan→purple gradient, offset behind the mark — this layer's parallax gives depth on focus.
- **Front**: the play-triangle mark, centered, sized ~60% of icon height. Icon-only for the home screen icon; mark + "nuvio" wordmark for the Top Shelf image.

**What I need**: a high-res transparent PNG (or SVG) of the logo mark. The attached image is a flattened banner. Options: (a) drop `nuvio-logo.png` (transparent, ≥1024px) into the project folder and I'll generate all sizes + wire the Contents.json files, or (b) I recreate the mark as an SVG from the reference — close, but not pixel-identical to the brand asset.

## Suggested order

1. App icon (independent, instant win once logo file is in hand)
2. Tab bar migration + material→glass conversions (one focused pass, low risk)
3. DetailView hero restyle (highest visual payoff)
4. Profile picker + Home polish
5. Player/stream picker glass

Each step builds and ships independently; nothing blocks the existing Tier-1 cloud/autoplay work.

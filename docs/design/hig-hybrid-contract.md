# NuvioTV HIG Hybrid Contract

The revamp direction (decided 2026-07-29): **native structure, controls, focus behavior,
materials, and typography — brand accent retained only for selection states and identity
moments.** This page is the review checklist for every revamp phase. If a diff violates a
MUST below, it doesn't merge.

## Where the system wins (MUST be native)

| Surface | Rule |
|---|---|
| **Focus indication** | System treatment only: `.buttonStyle(.card)` platter/lift/parallax for artwork tiles, system brighten/scale for other controls. **No accent focus rings, no custom `scaleEffect` focus chains, no fake parallax tilt.** *Carve-out (FEAT-14):* an **opt-in** accent focus ring (Appearance setting `accent_focus_ring`, default **OFF**) MAY draw a single `strokeBorder` in `Palette.accentFocus` over artwork tiles, aligned to the card's Corners radius and routed through the contrast decision table (`Theme.Palette.focusRingHex`, White-theme fallback required). With the setting off — the default — focus indication remains system-only. |
| **Typography** | `Theme.Font` tokens only (semantic `Font.TextStyle` under the hood). No `Font.system(size:)` at call sites. |
| **Text color** | `Theme.Palette.textPrimary/.textSecondary` (semantic `.primary`/`.secondary`). Never hex text colors. |
| **Overlay surfaces** | `Theme.Surface` materials (or `.glass`/`.glassProminent` buttons, `glassEffect()`) for anything floating over content. Opaque `Palette.surface*` only for in-content fills. |
| **Buttons** | System styles: `.card` (artwork), `.glass`/`.glassProminent` (actions over media), `.borderless`/`.bordered`/`.borderedProminent` (everything else). Custom `ButtonStyle`s exist only where a system style demonstrably can't express the shape (document why in the style file). |
| **Alerts/confirms** | `.alert` / `.confirmationDialog`. No bespoke confirm overlays. |
| **Remote grammar** | Menu = back, Play/Pause = media, swipe = focus/scrub. Never repurposed. |
| **Motion** | System focus motion. Any remaining custom animation gates on Reduce Motion. |

## Where the brand is allowed (MAY use accent)

- **Selected** state fills: chips, filter pills, active picker rows (`Palette.accent` +
  `accentText` for legibility).
- Progress bars (continue-watching, player scrubber fill) — `Palette.progress`.
- Small identity moments: logo, profile avatars ring, star rating (`Palette.star`),
  onboarding/welcome hero.
- The 7 user-selectable accent themes stay; they surface ONLY through the uses above.

## Explicitly out

- Accent-colored focus rings (deleted in P1; reintroduced ONLY via the FEAT-14 opt-in carve-out under Focus indication — default OFF, single ring, contrast-guarded).
- `posterFocusTilt` fake parallax (system `.card` provides the real thing).
- Hard-coded text hex colors, fixed font point sizes.
- `.searchable` (known tvOS keyboard-bleed bug inside TabView — keep TextField, restyled).

## Token cheat-sheet (post-P0 Theme.swift)

- `Theme.Font.hero/.screenTitle/.sectionTitle/.cardTitle/.body/.meta/.caption` → semantic styles
  (title2-bold / title3-bold / callout-semibold / caption / body / caption-semibold / caption2).
- `Theme.Palette.textPrimary/.textSecondary` → `.primary`/`.secondary` (dark scheme pinned at root).
- `Theme.Surface.panel/.overlay/.chrome` → `.thick`/`.regular`/`.thin` materials.
- `Theme.Spacing`/`Theme.Radius` unchanged (60pt overscan margin per HIG).

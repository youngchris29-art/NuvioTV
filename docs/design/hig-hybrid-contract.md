# NuvioTV HIG Hybrid Contract

The revamp direction (decided 2026-07-29): **native structure, controls, focus behavior,
materials, and typography — brand accent retained only for selection states and identity
moments.** This page is the review checklist for every revamp phase. If a diff violates a
MUST below, it doesn't merge.

## Where the system wins (MUST be native)

| Surface | Rule |
|---|---|
| **Focus indication** | System treatment only: `.buttonStyle(.card)` platter/lift/parallax for artwork tiles, system brighten/scale for other controls. **No accent focus rings, no custom `scaleEffect` focus chains, no fake parallax tilt.** *Carve-out (FEAT-14):* an **opt-in** accent focus ring (Appearance setting `accent_focus_ring`, default **OFF**) MAY draw a single `strokeBorder` in `Palette.accentFocus` over artwork tiles, aligned to the card's Corners radius and routed through the contrast decision table (`Theme.Palette.focusRingHex`, White-theme fallback required). With the setting off — the default — focus indication remains system-only. In ring mode the card swaps the system lift for an equivalent manual scale (hardware cannot composite SwiftUI overlays into the `hoverEffect` lift layer — framebuffer-verified 2026-08-02); this scale exists solely to carry the ring and is part of this carve-out, not a licence for custom focus chains elsewhere. **"Equivalent" is an obligation, and it is now measured, not asserted (BUG-64, 2026-08-25):** the constant sat at 1.06 against a system lift of **1.1212** — barely half — for two betas while the reporter kept saying the ring changed how focus behaves. `cardSystemLiftScale` in `PosterCard.swift` carries the measurement and its provenance; **test44** re-measures both treatments and fails if they drift apart, using ring mode's own known constant as the edge finder's known-answer check. Re-measure rather than re-guess if the tvOS focus lift ever changes. |
| **Typography** | `Theme.Font` tokens only (semantic `Font.TextStyle` under the hood). No `Font.system(size:)` at call sites. *Carve-out (FEAT-31):* `Theme.Font` tokens MAY resolve to `Font.custom("Open Sans", size:relativeTo:)` when the opt-in Appearance setting "Typeface" is set to Open Sans (device-local `ui_font` key, default **System**). The base size fed to `.custom` is DERIVED — `UIFontDescriptor.preferredFontDescriptor(withTextStyle:compatibleWith: .large)`, never a literal — and `relativeTo:` keeps Larger Text scaling working under the custom face. Default System mode is unit-tested byte-identical to the pre-FEAT-31 tokens (`AppFontResolverTests`). Call sites still reference tokens only; nothing outside `Theme.Font` ever names a font family directly. |
| **Text color** | `Theme.Palette.textPrimary/.textSecondary` (semantic `.primary`/`.secondary`). Never hex text colors. |
| **Overlay surfaces** | `Theme.Surface` materials (or `.glass`/`.glassProminent` buttons, `glassEffect()`) for anything floating over content. Opaque `Palette.surface*` only for in-content fills. |
| **Buttons** | System styles: `.card` (artwork), `.glass`/`.glassProminent` (actions over media), `.borderless`/`.bordered`/`.borderedProminent` (everything else). Custom `ButtonStyle`s exist only where a system style demonstrably can't express the shape (document why in the style file). *Carve-out (FEAT-30):* `SidebarItemButtonStyle` in `DesignSystem/SidebarOverlay.swift` draws a per-row white capsule for the focused item inside a `.glassEffect` panel — opt-in via the Appearance setting "Navigation: Sidebar" (device-local `sidebar_style` key, default **Top Tabs**). Neither system style can express this shape: `.borderless` is platter-free on tvOS (lift only, no fill), and `.glass`/`.glassProminent` render at the panel level, not a per-row pill inside one. System focus motion (lift/brighten) is otherwise unchanged. Default Top Tabs mode is byte-identical to today — this style has no call sites until the setting is on. |
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
- Hard-coded text hex colors, fixed font point sizes at call sites (the FEAT-31 Open Sans carve-out's internal base size is DERIVED from the system's own preferred-font descriptor, never a literal — see Typography above).
- `.searchable` (known tvOS keyboard-bleed bug inside TabView — keep TextField, restyled).

## Token cheat-sheet (post-P0 Theme.swift)

- `Theme.Font.hero/.screenTitle/.sectionTitle/.cardTitle/.body/.meta/.caption` → semantic styles
  (title2-bold / title3-bold / callout-semibold / caption / body / caption-semibold / caption2).
- `Theme.Palette.textPrimary/.textSecondary` → `.primary`/`.secondary` (dark scheme pinned at root).
- `Theme.Surface.panel/.overlay/.chrome` → `.thick`/`.regular`/`.thin` materials.
- `Theme.Spacing`/`Theme.Radius` unchanged (60pt overscan margin per HIG).
- 2026-09-05 (FEAT-31): `Theme.Font.family` / `Theme.AppFontFamily` — the selected UI typeface
  (`.system`/`.openSans`), read by every `Theme.Font` token resolver; see the Typography carve-out.

## Settings screen — native List conversion closed (beta.15 C1-C4, 2026-08-23)

The Settings screen's "pending native List conversion" exemption from the Buttons/Focus rows
above is **closed**. `Screens/SettingsView.swift` and every `Screens/Settings/*Pane.swift` now use
stock `List`/`Toggle`/`Menu{Picker}`/`LabeledContent`/`NavigationLink` only — no custom
`ButtonStyle`, no `hoverEffect`, no focus-derived colour (`SettingsRowViews.swift` is the
component kit; see its header comment for the full primitive list).

- **Sidebar rows must be `Button`s to be focusable** — a bare `Label`/`Text` inside
  `List(selection:)` does not take focus on tvOS; every sidebar/category row wraps a `Button`.
- **`Menu { Picker }` over a `LabeledContent` label is the dropdown pattern** — it pops the native
  grey-pill radio-checkmark popover and replaces the old horizontal chip-row anti-pattern
  (`SettingsPickerRow` in `SettingsRowViews.swift`).

**Follow-up (not part of this closure):** `SettingsRowButtonStyle`/`.settingsRow`,
`settingsRowIsFocused`, and `rowTextColor()` (now in `DesignSystem/FlatControlStyles.swift`) are
still load-bearing for five screens outside Settings that have not had their own native-List
pass: `StreamPickerView`, `DetailView`, `CloudLibraryUI`, `AddonsView`, `TmdbFilterEditorView`.
They remain a documented exemption to the Buttons row until each gets converted (beta.16
candidate) — do not extend `.settingsRow` to new call sites in the meantime.

## New card surfaces — birth checklist (BUG-32, added 2026-08-20)

Every new artwork card (poster, thumbnail, tile) MUST, at creation:

1. Read its corner radius from the shared token — `@Environment(\.posterStyle)` →
   `posterStyle.cornerRadius` — in **clip shape, strokes/overlays, depth overlay, and focus
   treatment** alike. Never hardcode `Theme.Radius.card` on an artwork card: the user's
   Poster Style → Corners setting must reach both rest and focused states.
2. Attach `.posterButtonShape()` to its `.borderless` Button so the system focus lockup follows
   the same radius (the BUG-25 class: the system radius silently overrides the card's clip).
3. If its caption sits outside the focus-scaled subtree, give it `CardCaptionFocusDrop` (or
   equivalent clearance) so the lifted artwork never grows over the label (the BUG-15/UX-5/UX-15
   class).

BUG-32's history is this checklist ignored three times: collection tiles (beta.10 fix), then
services tiles, then FEAT-24's season posters + trailer/episode thumbs (beta.13.5 sweep).

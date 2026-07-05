# UI Improvements Scout — 2026-07-05

Scouting notes for six UI changes. Files are under `NuvioMobile/iosApp/NuvioTV/`.

---

## 1. Settings: group sections into categories

**File:** `Screens/SettingsView.swift` (1,194 lines)

Current state: one flat `ScrollView` with 13 `section(...)` blocks in a fixed order:
Account, Theme, Trakt, Debrid, Playback, Subtitles, Audio & Subtitle Language, Poster Style,
Metadata (TMDB), Ratings (MDBList), Plugins, Remote Setup, Home Rows.

**Proposed grouping** (pure reshuffle — no VM changes needed):

| Category | Sections |
|---|---|
| **Account & Services** | Account, Trakt, Debrid |
| **Playback** | Playback (buffer/readahead/frame-rate/skip-intro), Audio & Subtitle Language, Subtitles (appearance) |
| **Appearance** | Theme, Poster Style |
| **Home Screen** | Home Rows (+ hero options later) |
| **Content Sources** | Plugins, Metadata (TMDB), Ratings (MDBList) |
| **Advanced** | Remote Setup |

**Two implementation shapes:**
- **A (light):** keep one scroll page, add big category headers + visual card grouping. ~1–2 hrs, zero navigation risk.
- **B (recommended for a 10-foot UI):** sidebar/split layout — category list on the left, options on the right (like tvOS Settings app). `NavigationSplitView` or a custom two-column with `.focusSection()`. Bigger change (~half day) but solves "crowded" properly and shortens each focus column.

All section bodies (`traktSection`, `debridSection`, etc.) are already `@ViewBuilder` computed vars, so they move freely. Consider splitting the file into per-category files while at it.

---

## 2. Home: remove "Nuvio" title, move profile into the tab bar

**Files:** `ContentView.swift` (MainTabView, lines 117–137), `Screens/HomeView.swift` (lines 20–32)

- Removing the header: delete the `HStack` at HomeView.swift:20–32 (the `Text("Nuvio")` + profile avatar row). Trivial.
- Profile in the top tab bar: tvOS 26 `TabView` supports this natively — add after the Settings tab:

```swift
Tab("Profile", systemImage: "person.crop.circle", value: 5, role: .none) { ... }
```

  Options:
  - **Simplest:** a real tab whose content is `ProfileSelectionView` (or that immediately calls `onSwitchProfile()` via `.onAppear` — hacky).
  - **Better:** a Profile tab showing the avatar + "Switch Profile" button. `MainTabView` already receives `activeProfile` and `onSwitchProfile`, just pass them through.
  - tvOS also supports `TabViewCustomization` / trailing accessory placements; a custom avatar image as the tab icon is possible via `Tab { } label: { ProfileAvatar(...) }`.
- `HomeView` then loses its `activeProfile`/`onSwitchProfile` params (clean up call site).

Effort: ~1–2 hrs.

---

## 3. Focus/scroll navigation — Addons list unscrollable

**Files:** `Screens/AddonsView.swift` (primary), plus a pass over all scroll screens.

**Diagnosis (Addons):** each `AddonRow` is a *non-focusable* `HStack` containing two small `.bordered` buttons (Enabled / Remove) on the trailing edge. Problems:
1. Focus can only land on those small right-aligned buttons. From the Install button (left side of the screen), swiping down has no focusable target below-left → the focus engine refuses to move, so the list never scrolls.
2. Rows are not wrapped in `.focusSection()`, so vertical movement requires near-perfect horizontal alignment with the next focusable item — exactly the symptom described.

**Fixes:**
- Wrap each row (and each logical container) in `.focusSection()` — this tells tvOS "any focus movement toward this region should enter it," removing the need to be directly above/below a target.
- Make the whole `AddonRow` a focusable card (Button with `.card` style) with the toggle/remove as inner actions or a context menu, mirroring `SettingsActionRow`.
- App-wide pass: add `.focusSection()` to the section `VStack`s in SettingsView, the install vs installed regions in AddonsView, hero vs rows in HomeView, and the horizontal rows (`CatalogRowView`, `ContinueWatchingRow`). Cheap modifier, large UX win.
- Where lists are long, ensure `ScrollView` + `LazyVStack` so focus advancement drives scrolling smoothly.

Effort: Addons rewrite ~2 hrs; app-wide focusSection audit ~half day. (The `mcpmarket-me:tvos` HIG skill should be loaded when implementing.)

---

## 4. Player track menu: drill-in sections

**File:** `Screens/MPVPlayerView.swift` — `TrackPickerView` (lines 1424–1663)

Current state: one long scroll panel that renders **everything expanded**: full audio track list, full subtitle list, speed chips, timing steppers, episode chips, source rows, diagnostics. That's the "busy" feel.

**Proposed:** two-level menu.
- Level 1: a compact list of category rows — Audio ("English · AAC 5.1" as current-value subtitle), Subtitles, Playback Speed, Timing, Episodes, Sources, Diagnostics.
- Level 2: selecting a row shows only that category's options (push via `NavigationStack` inside the fullScreenCover, or a two-pane layout: categories left, options right — the Apple TV native player uses the panel-with-tabs pattern).

Implementation notes:
- Wrap TrackPickerView's content in a `NavigationStack`; each section body already exists as a computed var → becomes a destination. Low-risk refactor, no libmpv changes.
- Keep the existing guard at line 364 (track lists frozen while picker is open) — still valid.
- Show the currently-selected value in each level-1 row so users often don't need to drill in.

Effort: ~half day.

---

## 5. "Original player" for better HDR

**Context:** two candidate meanings — both documented in `docs/tvos-feature-parity-and-polish-roadmap.md` (constraint at line 46):

1. **`vo=gpu-next` (libplacebo)** — the originally attempted mpv video output. It was downgraded to `vo=gpu` because gpu-next **asserted on the tvOS simulator** ("vo: hit program assert"). The roadmap explicitly says: *"worth re-testing gpu-next on real Apple TV hardware someday."* gpu-next has substantially better HDR tone-mapping (dynamic peak detection, better DV/HDR10+ handling).
2. **AVPlayer** (`Screens/PlayerView.swift` — still in the tree, currently unused for streams). AVPlayer gives *true* HDR/Dolby Vision passthrough to the display (no tone-mapping at all), but loses format breadth (no MKV, limited codecs/containers, no external-subtitle styling via libass, no mpv delay/speed features).

**Current mpv HDR config** (MPVPlayerView.swift:303–332): `vo=gpu`, `target-colorspace-hint=yes`, `tone-mapping=auto`, `hdr-compute-peak=yes`. This tone-maps in-app rather than passing HDR through in all cases.

**Recommended scouting path:**
- **Step 1 (cheap, high value):** gate `vo=gpu-next` behind `#if !targetEnvironment(simulator)` (or a Settings toggle "Video Renderer: Stable / Enhanced") and test on the real Apple TV 4K. The sim keeps `gpu`. One-line option change + toggle plumbing (~1–2 hrs + device testing).
- **Step 2 (optional):** add an AVPlayer fallback path for direct HTTP MP4/HLS streams where container support isn't a problem — best-of-both: AVPlayer for HDR passthrough on compatible streams, mpv for everything else. Larger effort (~1–2 days: track UI differs, progress reporting duplicated).
- Verify `Match Content Frame Rate` (already implemented, MPVPlayerView ~line 483) also switches dynamic range on the gpu-next path.

---

## 6. Full-bleed home hero (like Detail)

**Files:** `Screens/HomeView.swift` (`HeroPager`/`HeroBanner`, lines 178–303), `DesignSystem/Theme.swift`

Current: hero is an inset rounded card — `frame(height: Theme.Size.heroHeight)` (480pt), `clipShape(RoundedRectangle(cornerRadius: Theme.Radius.hero))`, and it sits *inside* `.padding(Theme.Spacing.screen)`, below the header row. Detail achieves full-bleed because its backdrop is a `ZStack` background layer with `.ignoresSafeArea()` + `GeometryReader`, with the scroll content on top and a scrim gradient between.

**Plan (mirror Detail's structure):**
1. Move the hero image out of the scroll content into the `ZStack` background: `CachedAsyncImage` (current hero item) + `.ignoresSafeArea()` so it runs under the floating Liquid Glass tab bar and to all screen edges. No corner radius, no horizontal padding.
2. Add Detail-style scrim: bottom gradient for text/rows legibility + a subtle top gradient under the tab bar.
3. Keep the interactive part (focusable NavigationLink with logo/synopsis/dots) in the scroll content, but with top padding sized so the text sits over the lower third of the backdrop; remove the image from `HeroBanner` itself (it becomes a text/logo overlay + focus target).
4. Crossfade the background when `HeroPager` advances (`.animation` on the image `.id`).
5. As the user scrolls down, either let rows scroll over the backdrop (Detail behavior) or fade the backdrop out via scroll offset — Detail behavior is cheaper and consistent.
6. Since item 2 removes the header row, the hero becomes the topmost element — clean.

Effort: ~half day incl. focus/scroll tuning on device.

---

## Suggested order

1. **#3 focus fixes** (worst usability bug; Addons is currently broken)
2. **#2 + #6 together** (both touch the Home top area)
3. **#1 settings reorganization**
4. **#4 track-menu drill-in**
5. **#5 HDR renderer experiment** (device testing dependent)

# Home redesign, Stage & Strip: implementation plan (2026-10-03)

**Status: APPROVED by Christian 2026-10-03 (including H9, the floating pill rail). Wave 0 started 2026-10-05 on Christian's go ("start Home Stage Wave 0"): branch `claude/home-stage-strip` off `d68b9d61`; see [Wave 0](#wave-0-2026-10-05) in OUTCOME. No feature code yet.**

**Sources:**
- Decisions: `docs/home-redesign-decisions-2026-10-03.md` (H1–H6, revised to B).
- Options board: `docs/research/home-revamp-2026-10-02.html` (artifact https://claude.ai/artifact/W1rKJiqwEC32ZH1nyZepir).
- Steven's measured verdict: `docs/home-redesign-handoff-steven-beta19-rc1-2026-10-02.md`.
- Code facts: three Explore passes made from the cloud session on 10-02/10-03, summarised under Evidence.

Paths are relative to `NuvioMobile/iosApp/NuvioTV/` unless noted.

## Where to run this

Run it in a **local Claude Code session on the Mac**. The cloud container has no Xcode, simulator, `devicectl` or Codex, and every wave ends on a build, a simulator check or a device check. The local session copies this file to `~/.claude/plans/home-stage-strip.md` and treats it as the approved plan.

## Decisions (Christian, 2026-10-03)

| # | Decision |
|---|---|
| H1 | **Stage & Strip.** The top of the screen is a stage that can't take focus and shows the focused title. Below it, a fixed-height strip shows one row at a time, and Up/Down page whole rows. |
| H2 | **Trailer Location: Background or In Row.** Background plays muted in the stage, behind its text, after the viewer rests, and stops on any move. In Row is today's morph, started only once the strip has stopped, and it keeps the poster-colour ring. |
| H3 | **Ambient background on by default.** A blurred full-colour wash taken from the focused title. A setting turns it off. |
| H4 | **Titles.** The row heading sits at the top of the strip, and item names sit under the posters. Hide Titles still turns the names off. |
| H5 | **Collections.** A folder becomes a second stage-and-strip page (FEAT-43). The grid stays available as an option. |
| H6 | **Fix batch** (`docs/steven-beta19-rc1-verdict-batch-plan-2026-10-02.md`): drop M2 and N1; keep M5 and everything else. |
| H7 | **The next row shows its heading only**, peeking under the strip. No poster sliver. |
| H8 | **Today's layout stays as "Classic"** for one or two betas: a Home Layout picker with Stage / Classic. |
| H9 | **Floating pill rail** (added 2026-10-03; FEAT-45): a small vertical glass pill of icons on the left that opens into a labelled glass panel when focused. It applies to every tab, not just Home. |

### Defaults I chose (override any when approving)

**Home Layout default.**
- Stage for new installs and existing users, the same pattern as Detail's Cinematic default.
- Classic keeps today's Home byte-identical, including its own Show Hero / Nuvio-Style Hero sub-modes.
- Key: `home_layout`, device-local `@AppStorage`, values `"stage"` / `"classic"`. Launch arg `-home_layout classic` for tests.

**Stage swap timing.**
- Pause: 450 ms (official NuvioTV's `MODERN_HERO_FOCUS_DEBOUNCE_MS`).
- Old text fades out over 150 ms, new text fades in over 200 ms.
- Art cross-fades over 300 ms underneath. Art is not text, so a cross-fade there doesn't read as two titles.
- Classic keeps its 0.2 s commit and its cross-fade.

**Stage copy knows about Continue Watching (ride-along).** When the focused item is in progress, the meta line reads "S1 E3 · Episode title · 45m left" and the synopsis is the episode's own. This was recommended on the board as small and natural for a stage. Strike it if unwanted.

**Add-on name after the row heading (ride-along).** "Popular · Cinemeta", in secondary text, in Stage only. Strike if unwanted.

**Ambient wash.**
- A heavily blurred, low-resolution copy of the focused title's backdrop (or poster when there is no backdrop), lifted by the poster colour.
- It decodes **small on purpose** (≤ 256 px): a blur needs no detail, and this keeps it cheap.
- The handoff's "3840 px" rule applies to sharp full-bleed art (the stage art and the background trailer), not to the blurred wash.
- Off-switch: "Ambient Background" in Home Screen settings, default ON. With OLED True Black on, it dims to 40%.

**Navigation rail (H9).**
- **Navigation** becomes **Tabs / Rail**. Rail replaces today's Menu-revealed Sidebar mode (FEAT-30). A stored `sidebar_style = "sidebar"` migrates to `"rail"` on first launch, and `SidebarOverlay.swift` is retired.
- **Default stays Tabs.** Steven likes the tab bar hiding on scroll, and this doesn't change it for anyone who hasn't opted in.
- **New "Rail" option: Always Visible / Hide While Browsing**, default Always Visible. This is the choice FEAT-45 asked for.
  - **Always Visible:** the rail reserves its width, so content never shifts.
  - **Hide While Browsing:** the rail floats over content, slides out once you leave the top row or scroll down, and comes back on Menu or at the top. It never reserves width, so hiding it moves nothing.
- **Rail contents:** Home, Search, Library, Add-ons, Settings, plus the profile avatar at the bottom.

**Folder layout.** A folder follows the Home layout. Stage Home gives a stage-and-strip folder; Classic Home keeps today's grid. A per-folder "Grid" choice stays in the folder header's Edit menu.

**Release vehicle.** A beta.19 rc after the fix batch is cut and confirmed. This batch never shares an rc with the fix batch.

## Sequencing (hard dependencies)

1. **The fix batch merges first.** It edits `HomeView.swift`, `BrowseComponents.swift`, `InlineTrailerCard.swift`, `CollectionsUI.swift`, `CachedAsyncImage.swift` and `RowEdgeEffectStyle.swift`, all of which this plan also touches. This batch also **needs** two of its pieces:
   - I1, the per-view decode size and w780 posters, for the stage art.
   - F, the edge fade as a row modifier, for the strip.
2. **The Detail + Settings revamp:**
   - Its Settings part adds `descriptionID:` plumbing and the `SettingsDescriptions` catalog, and moves Trailer Sound to the Detail Page pane.
   - The Home Screen pane stays its own pane, and this batch owns it.
   - If the revamp's Settings part has merged, the new Home rows get description ids plus copy in all six locales. If not, they ship with English inline subtitles, and the revamp's W3 copy wave picks them up.
   - Either way, this batch never edits `Localizable.xcstrings` while the revamp is open. Strings are added through the same scripts at the end, after the revamp merges.
3. **The navigation picker lives in the Appearance pane,** which the revamp re-sorts. The rail work (W2-D) starts only after the revamp's Settings part has merged.
4. **Branch:** submodule `claude/home-stage-strip`, off `tvos-shared-extraction` after both of the above. Never use `git worktree` on the submodule.

## Evidence (code facts)

### Branch point

- `HomeView.swift:845–920` switches on `heroContainerPinned` (`:309` = `heroNuvioStyle || !heroEnabled`) between the pinned header + `rowsScroll` and the classic `rowsScroll`.
- The cleanest insertion is `if layout == .stage { StageStripHome(...) } else if heroContainerPinned { … } else { … }`, which leaves Classic byte-identical.
- The full-bleed `HomeHeroBackdrop` + `HomeHeroScrim` layer (`:783–809`) must be gated off in Stage, because the stage draws its own.
- The BUG-27 `.onExitCommand` (`:946`) hangs off this `Group`, so the stage branch needs its own handler.

### Rows render standalone

- `CatalogRowView` (BrowseComponents `:4750`), `CollectionRowView` (CollectionsUI `:52`), `ContinueWatchingRow` (HomeView `:4349`) and `UpcomingRow` are self-contained. Each has its own horizontal ScrollView, `.focusSection()` and `@FocusState`.
- Pinned behaviour arrives only through environment keys that default to the Classic look:
  - `rowCardTopReach`
  - `rowCardBottomReach`
  - `rowCardLinkFrameFloor`
  - `pinnedRowIsLast`
  - `trailerPlaysInHero`
  - `pinnedRowFocusRequest`
  - `pinnedRowFocusOwnership`
- With reach 0, the heading is a plain `Text` above the shelf. The strip can host rows unchanged.

### Stage parts to reuse

- **Focus and art pipeline:**
  - `HomeHeroFocusModel` (`:3188`): `commitDelay` 0.2, `revertGrace` 0.3, `reportFocus`, `focusedItem`.
  - `HeroArtResolver` (`:3512`): `presented: HeroPresentation` with item/backdrop/logo/identity, `laterSwapDeadline` 400 ms. It commits text and art together in one 0.3 s animation.
  - `reportRowFocus` (`:2803`): prefetch plus logo lookup.
- **Stage drawing:**
  - `HomeHeroForeground` (`:5356`) with `showsCTA: false` is already the non-focusable FEAT-15 panel layout: logo slot, one meta line, a synopsis that grows into the CTA space, width 680.
  - `HeroCrossfadeImage` (`:4881/:4905`).
  - `HomeHeroBackdrop` (`:4580`): Nuvio-style right-anchored art at 1250×820, with a `TrailerHeroPlayer` overlay.
- **Tests:** 100 unit tests cover the shared commit, art and logo pipeline (HeroCommitCoordinator 53, HeroPresentArtWait 19, HeroLogoPlan 13, HeroCrossfadeLayout 8, HeroArtResolverLateBackdrop 6, probe 1). Stage reuses this pipeline.

### Strip sizing

Row height = heading (≈ 38) + 16 + 24 + art + caption 43.5 (skipped with Hide Titles) + 24. Focus lift is 20 pt above and below (none with No Zoom).

| Poster size | Art (pt) | Row height with titles |
|---|---|---|
| Small | 275 | ≈ 420 |
| Medium | 330 | ≈ 476 |
| Medium+ | 352 | ≈ 497 |
| Large | 403 | ≈ 549 |

- Continue Watching and landscape rows use 203 pt art.
- A fixed 46 % strip (497 pt) **cannot** fit Large with titles. The strip height must be derived from the poster size (W1 spec).

### Other facts the specs depend on

**Colour.**
- `ArtworkColorStore` (`DesignSystem/ArtworkColorStore.swift`) provides `color(for:use:completion:)` and `cachedColor`, with uses `.ring` / `.rail`.
- It is 16×16 mean-chroma, cached per URL, and never downloads.
- A `.wash` use needs adding.

**Images.**
- `CachedAsyncImage` has no pixel-size parameter.
- The decode cap is fixed at `ArtworkStore.downsample` `:435` (1920). The fix batch's I1 adds the per-view size; this batch passes a small size for the wash and 3840 for stage art.

**Trailers.**
- `heroFocusTrailerMode` (`:510`) needs `|| stage`.
- The `trailerPlaysInHero` env (`:1474`) suppresses the in-row morph.
- `InlineTrailerCardModel` (`InlineTrailerCard.swift:344`): `dwellSeconds` 1.0. The fix batch's M3/M4 add rest-gating and a start-delay setting.
- Settings key `trailer_playback_location` = `"poster"` / `"hero"`. In Stage, "hero" means Background.

**Menu, tab bar, sidebar.**
- Menu: the BUG-27 path scrolls to `home_top` and focuses the hero CTA. Stage has no CTA, so Menu at row > 0 pages to row 0, and at row 0 it falls through to `sidebarMenuRevealHandler` (`:2838`).
- Tab bar: `TabBarContentScrollLinkAttacher` (`:1489`) links the rows' vertical UIScrollView. If the strip is a vertical paged ScrollView, linking it makes the bar move with paging:
  - At row 0 the offset is 0 and the bar shows.
  - At row ≥ 1 the offset is at least one strip height, far more than the bar's 68 pt, so the bar is fully hidden.
  - That meets "rest at offset 0 at the top, never half shown".
- `isScrolledDown` must equal `rowIndex > 0` (`:1591` today comes from scroll).

**Pinned-only machinery the stage must not mount:**
- `handleRowsMove`
- `HomeUpIntoHeroGate`
- `PinnedRowUpFallback`
- `PinnedRowSettleRevealModifier`
- `pinnedPlan` / `PinnedRowGeometry`
- `handleHeroUp`
- `HomeUpSwipeCatcher`

This machinery has 102 unit tests, and they stay Classic-only.

**Collections.**
- `FolderDetailView` (`:1110`) is a `LazyVGrid` with tab chips.
- `FolderDetailViewModel` (`:971`) holds **only the selected tab's items**. A row per source needs per-tab item sets: either repository support, or a lazy per-row load keyed by tab.

**Tests.**
- About 22 UI tests are Classic/pinned-specific (list in W4); about 15 have a Stage analogue worth writing.
- The fixture simulator FA87 will default to Stage once this lands. Every Classic test gains the launch arg `-home_layout classic`.

## Target design

### Stage

**Size.** It takes `1080 − stripHeight` pt (minimum 420). The art is right-anchored, left-faded, full-bleed behind the stage and the strip, decoded at 3840 px.

**Left block** (width 680), top-aligned under the tab bar zone (≥ 120 pt from the top):
- logo slot (fixed height, `heroLogoSlotHeight` 150, compressed to 110 when the stage is under 480)
- meta line (`heroMetaSlotHeight`)
- synopsis filling the rest (line count from the measured slot height, as `synopsisLineLimit` does today)

None of it is focusable.

**Folder focus** puts the folder's backdrop and logo in the stage, through the existing `folderHeroPreview`.

**Swap rule:**
1. Wait for a 450 ms pause.
2. Fade the text out (150 ms).
3. Swap the content.
4. Fade the text in (200 ms) while the art cross-fades (300 ms).

The stage frame never changes size. A focus change during the fade-out cancels the pending swap and restarts the pause.

**Background trailer (Trailer Location = Background).**
- Starts after the viewer rests, using the fix batch's M4 start delay (default "Automatic" = rest + 1 s).
- Muted, under the text, with the existing zoom-crop.
- Torn down on any focus change and when the player opens.

### Strip

**Height.**

> `stripHeight = rowHeight(posterSize, titlesShown) + 2 × focusLift + headingPeek`

- `focusLift` is 20, or 0 with No Zoom.
- `headingPeek` is about 44: the next row's heading plus a gap.
- W1 computes this as a pure function with a unit table.
- Rows shorter than the strip (Continue Watching, Upcoming, landscape rows, the genre chips row) are top-aligned in it. Their empty space shows the ambient wash.

**Paging.**
- One row per page.
- Down from row i focuses row i+1's remembered (or first) card.
- The strip makes **one** animated move of exactly one page (≈ 0.45–0.6 s ease-out, tuned on device).
- Nothing moves after that.
- Up mirrors it. Up from row 0 goes to the tab bar (the stage can't take focus).

**Next row.** Only its heading shows, peeking at the bottom edge (H7), in secondary text.

**Edge fade.** The row modifier from the fix batch (F) applies to every row in the strip.

**In Row trailers (Trailer Location = In Row).** Today's morph, with the fix batch's M3 rest gate and R1 ring colour. The strip height doesn't change. The morph widens the card only.

### Ambient wash

- Lives behind everything: one layer for the whole screen.
- Content: a blurred (radius ≈ 80) small decode of the focused title's backdrop, tinted toward `ArtworkColorStore` `.wash`.
- Cross-fades (400 ms) on the same 450 ms pause as the stage.
- The stage art fades into it on the left and bottom.
- Off switch: the art then fades to the theme background, as today.

### Chrome

- **Tab bar:** the strip's vertical scroll view is linked through `TabBarContentScrollLink`. At row 0 the bar shows; at row ≥ 1 it's fully hidden.
- **Menu:** at row > 0, pages to row 0, focusing that row's remembered card. At row 0 it reveals the sidebar in sidebar mode; otherwise it does the system default.
- **Top Shelf:** unchanged.

### Navigation rail (H9)

**Collapsed rail:**
- 84 pt wide, a vertical glass capsule hugging the left edge (16 pt from the bezel), vertically centred.
- Icons 36 pt; the current tab's icon sits on a filled platter.
- Profile avatar at the bottom.
- Visible on every tab root and on pushed pages (Detail, folders). It hides only in the player and full-screen covers.

**Opening it:**
- The rail is its own focus section. **Left from the leftmost focusable item** in content enters it.
  - Detection uses `movementDidFailNotification` / a leading-edge focus guide, not `.onMoveCommand`, which fires on every press (Orivio's lesson).
- On focus it expands to a **300 pt labelled glass panel** over a 0.55 dim of the content.
- **Right or Select** on an item switches tab and returns focus to that tab's remembered item.
- **Menu inside the rail** closes it back to content.

**Menu at a tab root** (at the top) focuses the rail. This replaces today's sidebar reveal and Classic's `sidebarMenuRevealHandler`. In Stage, Menu at row > 0 still pages to row 0 first.

**Glass sits behind the buttons, never around them.** Wrapping focusable content in `glassEffect` hides it from the focus engine; this is the Orivio focus trap noted in `docs/research/orivio-tv-handoff.md`. The buttons follow the HIG contract: native `Button`s, system focus, no custom focus chrome.

**Layout:**
- **Always Visible:** every tab root gets a fixed leading inset (rail + gap, about 116 pt).
  - In Stage: the stage's left block and the strip rows start right of the rail, and the stage art still bleeds full-width behind it.
  - In Settings: the revamp's explainer column moves right by the same inset.
- **Hide While Browsing:** no inset; the rail overlays the left edge.
  - In Stage it slides out when the strip leaves row 0 and slides back at row 0.
  - On other tabs it follows the per-tab scrolled-down state that `SidebarChromeModel` already tracks.

**Tab bar:** in Rail mode the system tab bar is hidden for good, using the same mechanism Sidebar mode uses today (`HiddenTabBarFocusBlocker`). `TabBarContentScrollLink` stays only for Tabs mode.

### Collections (H5)

`FolderDetailView`, when the folder layout is Rows:
- **Stage:** the folder's logo or title, plus its backdrop or mosaic, then the focused item as you browse.
- **Strip:** one row per source tab, in tab order. The "All" tab is omitted in Rows mode.
- **Header:** the folder logo shows in the stage when the strip is at row 0. As you page down it rises gently into the stage's logo slot and shrinks to 60%. It is never removed from the tree abruptly; this is Steven's "title always visible" ask.
- **Data:** a per-tab item load (W3 spec decides between repository support and per-row lazy load).

### Settings (Home Screen pane)

| Setting | Values / default | Notes |
|---|---|---|
| Home Layout | Stage / Classic, default Stage | Picker at the top of the pane. In Classic the existing rows show unchanged. |
| Ambient Background | default ON | Toggle, shown in Stage only. |
| Trailer Location | Background / In Row | Same key. Labels in Stage are Background (`"hero"`) and In Row (`"poster"`). Classic keeps "Hero" / "Poster" wording. The `heroLocationEffective` fallback captions get a Stage case. |
| Navigation (Appearance pane) | Tabs / Rail, default Tabs | Replaces Tabs / Sidebar. |
| Rail (Appearance pane) | Always Visible / Hide While Browsing, default Always Visible | Shown only with Rail. |
| Show Hero, Nuvio-Style Hero, Hero Sources, Autoplay Hero Trailer | — | Classic only, hidden in Stage. The stage always shows the focused title. |
| Upcoming Episodes, Catalogs, Show Catalog Type | — | Apply to both layouts. |

## Branch and delegation

- **Main session does:** builds, tests, simulator legs, screenshots, commits, device installs. Agents only edit files and never build.
- **At most 3 agents at once,** with disjoint file ownership.
- **Model tiers:**
  - Opus: specs, critique, focus/paging, test migration.
  - Sonnet: well-specified execution and strings (never Haiku).
- **Review:**
  - Codex is out until 2026-10-29, so review = internal Opus read-only rounds over `<base>..HEAD` until there are no P1/P2 findings.
  - After 10-29: `.claude/skills/codex-review/tools/review.sh --repo NuvioMobile --base <sha>`, unsandboxed, never piped.
- **`xcodebuild test`:** run with the Bash sandbox off. FA87 is the fixture. Reboot the simulator after about 6 UI runs.

### Wave 0 (main session)

1. Confirm both dependencies have merged; create the branch; record the base sha.
2. Baseline on the base:
   - NuvioTVTests (record the count)
   - Debug and Release simulator builds
   - the C-list UI legs with `-home_layout classic` accepted as a no-op (the key doesn't exist yet), to record which already skip on FA87
3. Tracker rows:
   - FEAT-35-style row for Home Stage & Strip (next free id)
   - FEAT-43 → IN PROGRESS
   - FEAT-53 (ambient) → IN PROGRESS
   - BUG-87/88/89/121/122/126 annotated "retired in Stage; Classic keeps the current behaviour"

### Wave 0.5: paging spike (main session plus one Opus agent; decides the strip mechanism)

The focus engine is the risk. Spike two mechanisms behind a debug arg on a throwaway sub-branch:

- **(a)** A vertical `ScrollView` of fixed-height pages, `.scrollTargetBehavior(.paging)`-style, with `scrollPosition(id:)` driven by the focused row id. The engine's reveal lands on a page boundary because each page is exactly the strip height.
- **(b)** A `ZStack` rendering rows i−1…i+1, offset by `-i × stripHeight`. Up/Down are taken with `.onMoveCommand` on the strip's focus section, and focus is set explicitly to the target row's remembered card.

**Measure on simulator and device** with the probe from the fix batch (M1): movements per press, settle time, any movement after rest, and Down held for 3 s.

**Rail entry (c).** A bare-bones rail on a test tab. Prove three things on hardware:
- Left from the first card of a horizontal row enters the rail. Left mid-row must scroll the row, not open the rail.
- The panel opens without a focus trap.
- Right returns to the same card.

**Pick the paging mechanism with one motion and nothing after.** Record the numbers in OUTCOME. Expectation: (a) if the engine respects page alignment, otherwise (b).

### Design phase (before any edit)

- **P1 (Opus Plan): Stage + Strip spec.**
  - `StageStripHome` view tree and the switch point.
  - `StripGeometry` pure functions: stripHeight per poster size, titles and No Zoom; stage height; logo-slot compression.
  - Paging mechanism from Wave 0.5, with exact focus memory per row.
  - Stage swap state machine (pause, fade-out, swap, fade-in, cancel rules) as a testable model, plus how it wraps `HeroArtResolver`.
  - Continue Watching-aware copy.
  - Menu, tab bar link, `isScrolledDown`.
  - Background-trailer gating.
- **P2 (Opus Plan): Ambient + Collections + Settings spec.**
  - Wash layer (decode size, blur, tint, cross-fade), `ArtworkColorStore.Use.wash`.
  - Folder Rows page (per-tab data load choice, header rise, grid option).
  - Home Screen pane rows and visibility rules, and the `home_layout` key plus launch arg.
- **P4 (Opus Plan): Rail spec.**
  - The `NavigationRail` view and its focus graph (entry via edge detection, exit, Menu).
  - The migration from `sidebar_style`.
  - Insets per tab for both visibility modes.
  - Interplay with the Stage strip, Detail, folder pages and the revamp's Settings root.
  - What gets deleted from `SidebarOverlay.swift` and `ContentView`/`MainTabView`.
- **P3 (Opus critique)** of P1 and P2 against the HIG contract, Steven's measurements (one motion per press, nothing after rest, no doubled title, offset 0 at top) and the test list.
- **Checkpoint:** Christian skims the geometry table and the swap timeline (about 5 minutes).

### Wave 1 (three agents in parallel)

**W1-A (Opus): the stage-and-strip Home.**
- New files:
  - `Screens/Home/StageStripHome.swift`
  - `Screens/Home/StripGeometry.swift`
  - `Screens/Home/StageSwapModel.swift`
- `HomeView.swift` changes, limited to:
  - the branch (`:845`)
  - gating the backdrop layer (`:783`)
  - the stage `.onExitCommand`
  - `heroFocusTrailerMode || stage` (`:510`)
  - `isScrolledDown` from row index
- Row views mounted unchanged, with env defaults.
- Unit tests: `StripGeometryTests` and `StageSwapModelTests`.

**W1-B (Sonnet): ambient wash.**
- New `DesignSystem/AmbientWashLayer.swift`.
- `ArtworkColorStore` `.wash` use, plus tests.
- Small-size decode call (via I1's size parameter).

**W1-C (Sonnet): settings.**
- `HomeScreenSettingsPane.swift`: Home Layout picker, Ambient Background toggle, Stage/Classic visibility rules, Trailer Location labels and captions.
- `home_layout` key and launch-arg read helper.

**Gate 1:**
- Debug build plus NuvioTVTests.
- Simulator screenshots for each poster size (Small, Medium, Medium+, Large, each with titles on and off), No Zoom on, Continue Watching present and empty, and a folder focused.
- Saved to `docs/research/home-stage-strip-sim-evidence/`.
- **Christian design checkpoint before Wave 2.**

### Wave 2 (after Gate 1)

**W2-A (Opus): motion polish and trailers.**
- Background-trailer gating in the stage.
- In Row morph inside the strip: verify M3's rest gate against the strip's settle signal.
- Down held (fast paging: skip intermediate stage swaps; swap only on rest).
- Continue Watching-aware stage copy.
- Add-on name after headings.

**W2-B (Opus): Collections Rows page.**
- `CollectionsUI.swift` `FolderDetailView` Rows mode reuses `StageStripHome` pieces.
- Per-tab data in `FolderDetailViewModel` (or the repository, per P2).
- Header rise.
- Grid option kept.

**W2-C (Sonnet): string pass.**
- English strings for all new settings and labels.
- If the revamp's Settings part has merged: description ids + `SettingsDescriptions` entries (SlopMonster to 5/5), then translations through `populate-localizable-xcstrings.py` → de/es/fr/it/vi → `merge-translations-into-xcstrings.py`.

**Wave 2b (after W2-C): W2-D (Opus): navigation rail.**
- New `DesignSystem/NavigationRail.swift`.
- Changes to the tab shell in `ContentView.swift`/`MainTabView`: migration, rail overlay, insets, Menu routing.
- The Navigation and Rail pickers in `AppearanceSettingsPane.swift`.
- Retire `SidebarOverlay.swift` (keep `HiddenTabBarFocusBlocker`).
  - **Carry Search S1's W2 into the rail** (`docs/search-s1-native-search-plan-2026-10-04.md`). The blocker's `onFocusLandedInHiddenBar` callback must open and focus the rail. tvOS's search container moves focus into the hidden bar on Menu, and nothing else catches it. The rail's Right exit and its post-select hand-off must wait up to 2.5 s for Search's system keyboard, which arrives 1–2 s after the tab opens. `test93SidebarMenuFromSearchKeyboard` is the canary; port it to the rail.
- Stage hook: hide-while-browsing driven by the strip's row index.
- Unit tests: migration plus inset math.

**Gate 2:**
- Debug and Release builds.
- NuvioTVTests.
- **Device spike re-measure** of one-motion-per-press on the Living Room Apple TV, Test profile, with probes.

### Wave 3: tests (W3, Opus)

**Classic tests** get `-home_layout classic` so they keep testing today's Home, unchanged:
- test00z, 06, 08, 14, 22, 47, 48, 58, 61, 63, 64, 65, 66, 67, 54, 70
- HeroFolderSwapTests test54
- HeroOffLaunchTests test31D
- HomeUpIntoHeroUITests test74
- PinnedRowSettleRegimeTests W5a/W5b
- TabBarScrollLinkTests test75/76
- The 102 pinned unit tests stay as they are.

**Card-level tests** measured on Home rows (test27, 28, 32, 44, 46, 49, 50, 56, InlineTrailerTileProbe, RowLeadingEdge):
- Pin them to `-home_layout classic` first.
- Add a Stage run where the measurement is layout-agnostic.

**New Stage UI tests** (next free numbers):
- Down pages exactly one row, with no movement after rest (probe trace: one move event per press).
- The next row's heading peeks.
- Stage swap: never two titles in the tree at once.
- Up from row 0 goes to the tab bar.
- Tab bar fully hidden at row ≥ 1 and shown at row 0 (Stage variant of test75).
- Menu from row 3 returns to row 0, then reveals the sidebar.
- Background trailer starts after rest and stops on move (Stage analogue of test37).
- In Row morph inside the strip (Stage analogue of test01 and test41).
- Folder Rows page: header rise, rows per tab, exit restores focus (Stage analogues of test57 and test69).
- Ambient wash present, and absent when switched off.
- Hold menu on a strip poster (Stage analogue of test71).
- Rail tests:
  - Left from the first card enters the rail; Left mid-row doesn't.
  - Expands with labels; Right returns to the same card.
  - Menu at a tab root focuses the rail.
  - Hide While Browsing hides at row ≥ 1 and returns at row 0.
  - The tab switch works from the rail.
  - Migration from `"sidebar"`.
  - These replace test52SidebarOverlay and its Sidebar-mode cases.

**New unit tests:** StripGeometry table, StageSwapModel timeline, wash colour.

**Gate 3:**
- Full NuvioTVTests.
- All Classic legs (with the arg) and all new Stage legs.
- Debug and Release builds.
- Kotlin gates only if `shared/` is touched; it shouldn't be, since per-tab folder loading should stay in Swift unless P2 decides otherwise.

### Review

- Opus read-only round 1, run as two passes: Stage/strip/ambient, then Collections/settings/tests.
- Fix agents per file owner.
- Round 2, and repeat until there are no P1/P2 findings.
- Record each finding in a `# | Sev | Finding | Decision` table in OUTCOME.

### Device pass

Christian runs it on the Living Room Apple TV in the **"Test" profile**.

Debug build with probes streamed:
`xcrun devicectl device process launch --console --terminate-existing --device <id> com.youngchris29.NuvioTV -- -debug.homeScrollProbe YES > ~/Downloads/home-stage-strip.log 2>&1`

1. Cold launch: Stage, row 0 = Continue Watching (or first row), tab bar visible, stage shows the focused title.
2. Down ×5 at Medium+:
   - each press is one strip move, and nothing moves after it settles;
   - no doubled title in the stage;
   - the next row's heading peeks;
   - the tab bar is fully hidden after the first press.
3. Up back to row 0: the tab bar returns fully. Up again moves focus to the tab bar.
4. Large with titles: rows fit, with no clipped focus lift. Repeat with No Zoom on.
5. Hold Down for 3 s: fast paging, and the stage swaps only once you stop.
6. Ambient wash: colourful, changes after a pause, off-switch works, OLED True Black dims it.
7. Trailer Location Background: a trailer appears behind the stage text after rest and stops on a move. Switch to In Row: the morph happens inside the strip after rest, with the poster-colour ring.
8. Continue Watching-aware stage copy on an in-progress series.
9. Open a collection folder: rows per source, header rises gently, Back restores focus. Switch it to Grid: today's grid.
10. Menu from row 4 goes to row 0. Menu again: sidebar (in sidebar mode) or nothing (tabs).
11. Switch Home Layout to Classic: today's Home, unchanged (spot-check a pinned walk).
12. 4K sharpness: stage art and posters are sharp on the 4K TV.
13. French UI spot check.
14. **Rail Always Visible** (Appearance → Navigation → Rail):
    - On every tab, Left from the first item opens the labelled panel and Right comes back to the same item.
    - Content never shifts.
    - Menu at a tab root opens the rail.
    - Detail and a folder page show the rail too.
    - In the player there's no rail.
15. **Rail Hide While Browsing:** the rail leaves when you page down the strip or scroll another tab, and returns at the top. Nothing else moves when it hides.
16. **Switch Navigation back to Tabs:** today's tab bar, unchanged, still hiding on scroll.

### Merge, cut, comms (each on Christian's go)

1. Fast-forward into `tvos-shared-extraction`, push, delete the branch, bump the outer pointer.
2. Cut the next beta.19 rc.
3. **Steven DM** (SlopMonster to 5/5):
   - Name every new setting and its default.
   - Point him to Home Layout → Classic for comparison.
   - Tell him the FEAT-45 rail is under Appearance → Navigation → Rail, with Always Visible / Hide While Browsing.
   - Ask for a video of a Down walk, like his Fusion comparison, plus a folder walk.
4. Tracker updates: FEAT-43 built, FEAT-53 built, FEAT-45 built (the rail), FEAT-30 Sidebar mode superseded by Rail; BUG-87/88/89/121/122/126 "retired in Stage".
5. Update CLAUDE.md and memory.
6. After one or two betas with Stage confirmed: a small follow-up batch deletes Classic's pinned mode (Nuvio-Style Hero / hero-off pinned) along with its ≈ 5,000 lines, 20 constants, A/B switches and 102 unit tests. The decision on whether Classic's non-pinned billboard stays as a choice is Christian's call then.

## Agent roster (estimate)

| Phase | Agents |
|---|---|
| Spike | 1 Opus |
| Design | 3 Opus Plan (P1, P2, P4) + 1 Opus critique |
| Execution | 5 Opus (W1-A, W2-A, W2-B, W2-D, W3) + 3 Sonnet (W1-B, W1-C, W2-C) |
| Review | 2–3 Opus rounds + about 3 fix agents |

## Risks worth knowing before the go

1. **The paging mechanism (biggest).** tvOS's focus engine decides scrolling. If neither spike candidate gives one motion per press on hardware, the design needs a rethink before Wave 1, which is why the spike comes first.
2. **One row on screen.** Browsing many catalogs means more presses than today. Down held must page fast and skip stage swaps.
3. **The stage swap is the motion Steven criticised.** The 450 ms pause plus fade-out-then-in answers his "doubled title" and "late" complaints, but it is still a change in place. The device pass and his video are the test.
4. **Strip height varies with poster size,** so the stage shrinks at Large (logo slot compression). Screenshots at Gate 1 catch layouts that look cramped.
5. **Collections need per-tab data.** That's new loading behaviour in `FolderDetailViewModel` and possibly the shared repository. P2 must keep it in Swift if possible.
6. **Test churn.** About 40 UI tests are pinned to Classic or duplicated for Stage. The fixture's default layout flips, so every Classic test needs the launch arg, or it fails confusingly.
7. **The rail touches every tab, not just Home.** A focus trap or an inset mistake would show up in Search, Library, Settings and Detail. The spike's rail check, the rail UI tests and device step 14 cover each tab. Tabs mode stays byte-identical for everyone who doesn't switch.
8. **Two batches touch the same files.** This plan must not start until the fix batch merges. The Detail + Settings revamp owns `Localizable.xcstrings` until it merges.

## OUTCOME

### Status (2026-10-03)

- Plan branch merged into outer `main` (`17646af`), branch deleted. Plan copied to `~/.claude/plans/home-stage-strip.md`.
- **Wave 0 not started: the fix batch has not been built.** `docs/steven-beta19-rc1-verdict-batch-plan-2026-10-02.md` is still a draft with no branch. The Detail + Settings revamp has merged (`284fd764`). FEAT-45 was never marked declined, so nothing needed resetting.
- H6 written into the fix plan (`5875482`): M2 and N1 dropped, M5 kept, I1 and F named as the pieces this batch builds on.
- On Christian's go, the Wave 0.5 spike ran ahead of the dependency.

### Wave 0.5 spike

**Where:** throwaway clone `~/Claude/Projects/NuvioMobile-stage-spike`, branch `claude/home-stage-spike` off `284fd764`, one local commit `035095a4`, push disabled. Never merged. Code: `StageStripSpike.swift` (spike Home + frame probe), `SpikeRail.swift`, two branches in `MainTabView`, `StageSpikeTests.swift` (drivers, no assertions).

**Knobs:**
- `-debug.stageSpike a1|a2|b1|b2` (strip mechanism).
- `-debug.stageSpikeRail fail|always` (with `-sidebar_style sidebar`).
- `-debug.stageSpikeStripHeight`, `-debug.stageSpikePageSeconds` (default 0.5).

**Mechanisms:**
- **a1:** vertical `ScrollView`, pages of height P, `.scrollTargetBehavior(.viewAligned)`, focus engine scrolls.
- **a2:** a1 plus `.scrollPosition(id:)` animated to the focused row (0.5 s ease-out).
- **b1:** no scroll view; rows offset by `-i·P`, only the current row enabled, `.onMoveCommand` pages and sends a focus request.
- **b2:** same layout; rows i±1 enabled and the engine moves focus.

**Probe:** a `CADisplayLink` reads a marker's presentation-layer y in window space each frame. A segment = consecutive frames moving ≥ 0.25 pt, ended by 6 still frames. The press summaries mis-assign some segments (the row's focus report lags the scroll), so the per-segment lines with timestamps are the ground truth.

**Simulator (FA87, guest Cinemeta, 4 rows, Medium posters: P = 515.5, H = 559.5, stage 520.5):**

| Mech | Motions per press | Duration per page | Residual after rest | Movement after rest | Held Down 3 s | Up from row 0 |
|---|---|---|---|---|---|---|
| a1 | 1, every press both ways | 1.15–1.9 s | 0.0 pt | none | one 3-page glide (1.94 s) | tab bar |
| a2 | 1, every press both ways | 0.53–0.65 s | 0.0 pt | none | one 3-page glide (2.0 s) | tab bar |
| b1 | 1 | 0.6–0.75 s | 0.0 pt | none | **does not page** (`.onMoveCommand` gets no repeats on a held press) | **failed once** (moveFail up) |
| b2 | **never pages**: the engine won't move focus into offset rows outside the strip | — | — | — | — | tab bar |

The simulator's focus engine is known to park rows differently from the hardware's. The pinned layout rested true in the sim and short on the device. So these numbers pick the candidates, and the device decides.

**Rail entry (c), simulator, a2 Home with `-sidebar_style sidebar`:**
- **`always` (rail permanently focusable): fails.** It takes default focus at launch, and Right goes nowhere (moveFail right). The engine cannot move from the overlay into the TabView's content, the same thing FEAT-30's sidebar hit.
- **`fail` (rail focusable only once armed by a Left that has no target, via `UIFocusSystem.movementDidFailNotification`): works**, after two changes found in the runs:
  1. **Content must be unfocusable while the rail holds focus.** Otherwise Down past the bottom item leaks into content, and Right from row 1 jumps to an off-screen row-0 card whose frame overlaps the rail item's beam. A `UIFocusGuide` right of the rail lost to that card, and `requestFocusUpdate(to:)` with the remembered SwiftUI focus item didn't stick. The spike disables the strip on a rail-focus notification.
  2. **Right becomes an explicit exit.** With content disabled, Right from the rail fails. The rail then posts an exit, and Home re-enables the strip and sends a focus request for the current row (first card; per-card memory needs the row views to accept an item id, a P1/P4 spec item).
- **Results with both changes:**
  - Left mid-row stays in the row ✓; Left from card 0 opens the rail ✓.
  - Up at the top and Down at the bottom stay in the rail ✓.
  - Right returns to the current row from row 0 and from row 1 ✓.
  - Menu in the rail exits ✓; Menu at row 0 opens it ✓; Select on Search switches tab ✓.

**Logs:** `docs/research/home-stage-strip-spike/sim-run1-walks-rail.log` (first walks a1–b2, rail iterations), `sim-run2-a1-a2.log` (re-run with focus-timed press windows).

**Device (Living Room Apple TV, Test profile, 2026-10-03 ~16:03–16:09 ET, Christian at the remote; console streamed):**
- Spike Debug build installed as `com.youngchris29.NuvioTV`.
- The Test profile runs FEAT-30's sidebar mode (`sidebar_style = "sidebar"` on this install), so the system tab bar was hidden in every walk.

| Mech | Per click | Rest position | After rest | Held Down | Swipes | Christian |
|---|---|---|---|---|---|---|
| a1 | one glide of one page, **1.13–1.20 s** | within 0.2 pt of the page boundary | nothing | one 5-page glide (4.1 s) | multi-row swipes glide several pages in one motion | "smooth but a bit slow" |
| **a2** | **one glide of one page, 0.51–0.73 s**, Down and Up | **exactly on the boundary** (every rest a multiple of P from the baseline) | nothing | one 2-page glide (1.0 s) | one page each, or one glide for a multi-row swipe | **"faster and still smooth"** |

- In a1, clicks closer together than ~1.2 s merge into one long glide (3.5 s for two pages on the first walk). The engine's own scroll is the slow part.
- The hardware engine did **not** park off-page in either variant. That is unlike the pinned layout, where the device rested 40–67 pt short of the simulator. With pages exactly one viewport-minus-peek tall and view-aligned targets, the rest is deterministic.
- **b1 and b2 were not run on the device.** b2 never pages, and b1 can't page on a held Down (both seen in the simulator), while a2 met every criterion. That saved Christian two walks.

**Rail on the device** (`-sidebar_style sidebar -debug.stageSpike a2 -debug.stageSpikeRail fail`):
- Left mid-row stays in the row ✓.
- Left from card 0 opens the rail (labels, dim) ✓.
- Up past the top and Down past the bottom stay inside ✓ (`contained heading=up/down`).
- Right returns to the current row ✓ (×3, `exit via=right` → row-1 focus request → focus on row 1's card 0).
- Menu at row 1 pages to row 0 (one 1.36 s motion), then Menu at row 0 opens the rail ✓; Menu in the rail exits to row 0 ✓.
- Select on Search from the rail switches tab, and focus lands in Search's text field ✓.
- **Swipe momentum did not open the rail** (Christian: "rail didn't pop open on swipes"). Two left swipes that landed on card 0 by momentum (16:08:14.13 and 16:08:20.71) armed nothing. The rail did open twice during that step, 1.04 s and 2.4 s after a swipe had landed on card 0. Each was a fresh Left from card 0, the designed entry, and Christian closed each with Right.

**Logs:** `docs/research/home-stage-strip-spike/device-a1.log`, `device-a2.log`, `device-rail.log` (StageSpike lines only).

### Wave 0 (2026-10-05)

**Dependencies:** both merged. The beta.19-rc1 fix batch is `7f8d0790` (shipped in beta.19-rc2). Its I1 per-view decode size and its F row edge-fade modifier are what this batch builds on. Row Edge Fade now defaults to Off after F.5 failed on device; the strip still uses F's modifier. The Detail + Settings revamp is `284fd764`. Since the plan was written, `tvos-shared-extraction` has also taken Library L1 (`422bb0c4`), the custom-poster port (`12b19ff5`) and Search S1 (`d68b9d61`). S1 changed `SidebarOverlay.swift` and `HiddenTabBarRedirect.swift`, so W2-D must carry the hidden-bar redirect and the Search hand-off wait into the rail. That note is under W2-D.

**Branch:** `claude/home-stage-strip` off `tvos-shared-extraction` **`d68b9d61`** (base sha), in the clone `~/Claude/Projects/NuvioMobile-home-stage`. Push is disabled until merge. ⚠️ MPVKit is a symlink over the gitlink there, so stage by explicit paths and never `git add -A`. `local.properties` is copied for the API keys.

**Baseline on `d68b9d61`** (FA87, tvOS 26.5, guest Cinemeta fixture; logs in the clone's `iosApp/build/hs0-*.log`):

- NuvioTVTests **1042 / 0**. Debug and Release simulator builds are green.
- The 23 Classic UI legs from W3's list ran unchanged in three runs, with a simulator reboot before each. `-home_layout classic` doesn't exist yet, so it was taken as a no-op.

| Result | Legs |
|---|---|
| **PASS (13)** | test00z, 06, 08, 14, 22, 65, 67, 70; HeroOffLaunch test31D (it passes on FA87 now; it used to need F38F573A); HomeUpIntoHero test74; PinnedRowSettleRegime W5b; TabBarScrollLink test75, test76 |
| **SKIP (9)**, fixture premises | test47, test48: Poster Size isn't Large (`w=220`). test54CollectionFrameProbeDriver: no folder tile on Home within 28 Downs. test58: the entry already landed on the last row. test61: the No Zoom reach-hold regime isn't set. test63: regime `fits=0`, not the BUG-112 regime. test64: the down walk got stuck on `cinemeta:movie:imdbRating`. test66: the shelf is already at the top with focus on the CTA. W5a: the Settings walk ends on "Import Badges" before reaching Appearance › Size, one of the stale Appearance legs left after the revamp re-sorted Settings. |
| **FAIL (1)**, fixture premise | HeroFolderSwap test54: "Could not locate a collection-folder hero after 45 Down presses". The guest fixture has no collection folders, the same cause as the test54 skip and test31's Leg C skip; this leg fails instead of skipping. |

So at the base, 10 of the 23 legs can't check anything on FA87. W3 should seed a Large-poster fixture and a collection folder, using the guest-sim seeding recipe from memory `bug38-collections-json-resolution`, before counting those legs as Classic coverage. It should also make HeroFolderSwap test54 skip on that premise like its sibling does.

**Tracker:** FEAT-55 added (Home Stage & Strip, IN PROGRESS). FEAT-43 (H5 folders), FEAT-45 (H9 rail) and FEAT-53 (H3 ambient) are marked IN PROGRESS. FEAT-53's "decoded at 3840 px" is corrected: the wash decodes at ≤ 256 px, and 3840 px is for the stage art. BUG-87/88/89/121/122/126 are annotated "retired in Stage; Classic keeps the current behaviour".

**Next:** the design phase, with P1 (Stage + Strip), P2 (Ambient + Collections + Settings) and P4 (Rail) as Opus Plan agents working from the spike verdict below, then the P3 critique and Christian's skim of the geometry table and swap timeline. That's 4 Opus agents, inside the plan's roster.

### Spike verdict (feeds P1 and P4)

**Paging mechanism: (a), as a2.** A vertical `ScrollView`; each row in a page frame of height P = rowHeight + 2·lift, top-aligned; `.scrollTargetLayout()` + `.scrollTargetBehavior(.viewAligned)`; a trailing clear spacer of `peek`; `.scrollPosition(id:anchor: .top)` driven by the focused row's key with a 0.5 s ease-out. The focus engine moves focus, and the app's position animation overrides the engine's slower scroll. On hardware that is one motion per press, exactly on the boundary, nothing after. Tune the duration on device in Wave 2 (0.5 s now; the plan's range is 0.45–0.6 s).

**Rail entry: arm on a failed Left** (`UIFocusSystem.movementDidFailNotification`, heading `.left`), never permanently focusable. Two requirements the spike adds to P4:
1. **Content must be unfocusable while the rail holds focus, on every tab root.** The rail is a TabView overlay, and the engine otherwise leaks out of it (Down past the bottom, and Right from row 1 to an off-screen row-0 card). In the spike, the strip got `.disabled(railFocused)` from a rail-focus notification. P4 needs a shell-level gate every tab root applies.
2. **Right and Menu are app-handled exits.** With content gated, Right fails, and the rail posts an exit. The active tab re-enables and restores its own focus (Home: a focus request for the current row). Per-card memory (e.g. after a Menu reveal from card 5) needs the row views to accept an item id on the focus request, not only the first card. `UIFocusSystem.requestFocusUpdate(to:)` on a remembered SwiftUI focus item did not stick, and a `UIFocusGuide` lost to the off-screen row, so restoration must be SwiftUI-side.

**Open for P4:** the plan says "Right or Select on an item switches tab". In the spike, Right always returns to the current tab. Either works mechanically, since Right is app-handled. P4 decides the semantics.

**Clean-up:** the spike clone stays until P1/P4 are written (the designers may read it), then it is deleted (`~/Claude/Projects/NuvioMobile-stage-spike`). The Apple TV is back on the `284fd764` dev build (reinstalled 16:10).

<!-- Approved plan (Christian, 2026-09-05 evening). Phase 0 spike results and wave outcomes appended at the bottom. -->
# Steven's parked asks: FEAT-30 sidebar, FEAT-31 Open Sans, FEAT-33 frame-rate probe

## Context

Steven (u/mrStevenx3) re-raised two asks on 2026-09-04 that Christian deferred out of the beta.17 batch, and added a third on 09-05:

- **FEAT-30** — move the top tab bar to an Omni-style floating sidebar. Christian told Steven in the 09-05 rc DM that this is in progress. Reference (frames `docs/research/steven-beta17-video-evidence/seq2-omni-sidebar-01/08.png`, `ref-omni-t21.png`): a floating top-left rounded translucent panel inside the safe area, collapsed to one pill showing the current section (icon + label); on focus it grows downward (~0.2 s) into the section list, focused row = white pill; pure overlay, nothing behind reflows; hidden while browsing rows, summonable from mid-page. Omni offers "Sidebar Style: Apple (Tabs) / Custom (Sidebar)".
- **FEAT-31** — Open Sans as a selectable UI font (he points at `vatax3/NuvioTVOS`, which ships a "Typeface" setting with Inter / DM Sans / Open Sans).
- **FEAT-33** — his collections animation "runs at 60 fps on Nuvio vs 30 fps here". His own recording is 30 fps, so the claim is not observable in it. Frame-read of `~/Downloads/IMG_8468.mov` 19–35 s: the "collection animation" is the **hero swap on focus along the streaming-services row** (large brand logo over a poster mosaic, glow under the focused card) — our FEAT-29 folder-hero path.

Christian's decisions (this session): plan covers all three; when the sidebar setting is "Tabs" the app keeps **today's top tab bar, byte-identical** (no `.sidebarAdaptable`). Both new settings default to today's behaviour; Steven opts in. FEAT-33 is **probe first**: instrument, read the numbers on hardware and from Steven's photo, fix only if frames are actually dropping.

All three features are **Swift-only** (`NuvioMobile/iosApp/NuvioTV/`); `shared/` Kotlin is untouched, so no jvm/K/N test gates apply — the gates are Debug + Release sim builds, NuvioTVTests, the UI suite, Codex, and the Living Room ATV.

Work happens on submodule branch `claude/steven-parked-feats` off the current `tvos-shared-extraction` tip (`1d4d8f9d`). Ships as the next rc to Steven (beta.19-rc1, or beta.18-rc2 if his build-117 photo has not settled beta.18 by then — Christian's call at cut time).

---

## Key findings from exploration (what the design rests on)

**Tab shell** (`ContentView.swift`): `MainTabView` is a plain tvOS-26 `TabView(selection: $selectedTab)` with six `Tab`s (Home 0, Search 1, Library 2, Add-ons 3, Settings 4, Profile 5; `:270-305`), every one carrying `.tabBarImmersiveHide()`; no `.tabViewStyle` anywhere. The TabView keeps each tab's `NavigationStack` and `@StateObject`s alive across switches — replacing it is rejected (option c in `docs/steven-beta17-batch-plan-2026-09-04.md:632`). The bar is hidden today only via `.toolbarVisibility(immersive ? .hidden : .automatic, for: .tabBar)` in `TabBarVisibility.swift:156-176`, driven by `immersiveHidden` (Detail push). Toggling that preference mid-session is the BUG-66 latch class (hardware-only); a **constant** `.hidden` for the whole session is the same thing Detail does today. `tabBarVisibility` and `home` are `@State` on reference types on purpose (avoid shell-wide invalidation, `:24-30`, `:254-265`). `.id(appTheme.themeName)` at `:105` remounts the tree on theme change; `selectedTab`, `settingsCategory`, `pendingThemeSwatchFocus` are hoisted above it. No app-root `.tint` (kills Menu pills, `:94-101`).

**Geometry tied to the bar**: `heroPinnedRowsViewportBudget = 455` (`Theme.swift:427`) is a measured constant against the current chrome; `verifyViewportBudget` (`BrowseComponents.swift:611-627`) NSLogs `viewport BUDGET MISMATCH` under `debug.homeScrollProbe` if the live viewport drifts > 4 pt — this is the tripwire and the gate. Bar heights 157 (expanded) / 76 (minimized) exist only in comments.

**Focus/Menu invariants**: focus stranded on root chrome + Menu = app exit (BUG-47 class). Home's only `onExitCommand` (`HomeView.swift:696`) is non-nil only when scrolled down (BUG-27); Settings/Person install none by design. No UIKit focus APIs anywhere; the idiom is `.focusSection()` + `@Namespace`/`.focusScope`/`.prefersDefaultFocus` (`SettingsView.swift:83, 284, 287`). Glass pill precedent: `.glassEffect(.regular, in: .capsule)` (`ProfileSelectionView.swift:151`); `Theme.Surface.overlay` is the overlay material token. Custom `ButtonStyle`s need a written HIG-contract carve-out (`docs/design/hig-hybrid-contract.md:16`), FEAT-14 is the precedent.

**UI harness**: `openTab(_:named:)` (`NuvioTVUITests.swift:295-315`) climbs Up until a tab-bar button `hasFocus` — every navigation test uses it; `launchToHome` uses `app.buttons["Home"].frame.minY > 0` as its root-chrome oracle (`:229`). Knobs are launch args in the argument domain (`-inline_trailers_enabled YES`), probes are hidden `Text` with `accessibilityIdentifier` (`debug_env`, `HomeView.swift:553-557`) and About-pane ring buffers + AX blob (`AboutSettingsPane.swift:100-132`).

**Typography**: 7 tokens in `Theme.swift:161-177`, all `SwiftUI.Font.<textStyle>.weight(...)` (Dynamic Type for free). 417 `.font(` sites: 371 token-backed, **46 stragglers** — 18 `.system(size:)` (11 invisible harness probes, 7 About diagnostics incl. 5 monospaced, 1 SF Symbol size, 1 avatar initial) and 28 semantic-style stragglers, all user-facing: `MPVPlayerView.swift` (14: 1612-1788), `AddonsView.swift` (8: 48-135), `EpisodesSection.swift` (3: 85, 373, 407), `NativePlayerScreen.swift:67`, `NetworkStatusView.swift:16, 23` (dev screen). The only `UIFont` is a caption-height measurement at `CollectionsUI.swift:148`. Subtitles have no font-family setting and are out of scope (mpv `sub-font` never set). Project is fully file-system-synchronized (`objectVersion = 77`): dropping `.ttf` files under `NuvioTV/` adds them as resources with no pbxproj edit; `Info.plist` has no `UIAppFonts` (plist is merged with `GENERATE_INFOPLIST_FILE = YES`). Reference fork: variable font + `wght` axis pinning via `kCTFontVariationAttribute`, device-local `selected_font` key, propagation via `EnvironmentValues`.

**Frame timing**: the only instrumentation is the BUG-41 `HitchCounter` (`DetailView.swift:81-115`, `CADisplayLink`, gap > 25 ms, one NSLog on disappear). Nothing reads `UIScreen.maximumFramesPerSecond`; Instruments has never been run against the device. Folder row = `CollectionRowView`/`FolderTile` in `CollectionsUI.swift` (tile animation `.easeOut(0.15)` on `isFocused` at `:658`, ungated; native `.borderless` lift). The heavy per-step cost is the **hero re-commit on every folder focus change**: `onFolderFocusChange` → `HomeView.swift:1049-1069` → `reportRowFocus` (`:1519`) → `heroResolver.present` inside `withAnimation(.easeInOut(0.3))` (`:2279`) cross-fading two full-screen 1920 px images under a gradient mask + scrim. Second: whole-`HomeView` body re-evaluation per focus step. `ArtworkStore` decodes off-main but caps every image at 1920 px regardless of tile size (`CachedAsyncImage.swift:326`). `debug.pinnedSettleDisarm` and `DetailScrollAB` (`DetailView.swift:135-140`) are the A/B-leg precedents. Steven runs sideloaded Release builds: `defaults write` never reaches the device, so any probe must be an About-pane toggle with a photo-able readout.

---

## Design

### FEAT-30 — floating sidebar (opt-in)

**Setting**: device-local `@AppStorage("sidebar_style")`, values `"tabs"` (default) / `"sidebar"`. Appearance § Theme, after "Settings Style", via `SettingsPickerRow`: title "Navigation", options "Top Tabs" / "Sidebar". Not synced (same reasoning as `inline_trailers_enabled`). Launch-arg testable: `-sidebar_style sidebar`.

**Host**: keep `TabView` with all six tabs in the same order (Steven's Omni reference has four; Add-ons and Profile have no other home, so the sidebar lists all six). In sidebar mode `TabBarImmersiveHideModifier` resolves to a **constant** `.toolbarVisibility(.hidden, for: .tabBar)` for the session; the preference never flips because the mode is part of the remount key (below). Tabs mode stays byte-identical.

**Remount key**: widen `ContentView.swift:105` from `.id(appTheme.themeName)` to `.id(rootIdentity)` = `"\(themeName)|\(sidebarStyle)|\(uiFont)"`. Both new settings are rare user actions; the remount is the theme swatch's proven path. Add a `pendingAppearanceRowFocus: String?` hint hoisted next to `pendingThemeSwatchFocus` (`ContentView.swift:47`) so focus returns to the changed row after the remount instead of falling to root chrome (test43's Defect 2 class).

**Overlay**: new `DesignSystem/SidebarOverlay.swift`:
- `final class SidebarChromeModel: ObservableObject` — `@Published scrolledDownByTab: [Int: Bool]`, `@Published forceRevealed: Bool`. Held as `@State` (reference) on `MainTabView` like `tabBarVisibility`; only `SidebarOverlay` observes it with `@ObservedObject`, so sidebar state never invalidates the shell or the `Tab` closures.
- `struct SidebarOverlay: View` — `VStack(alignment: .leading)` of `SidebarItemButton`s (icon + label, same titles/SF Symbols as the tabs, reuse the existing localized tab titles), `@FocusState private var focusedItem: Int?`; `isExpanded = focusedItem != nil`; collapsed shows only the row for `selectedTab`. Container: `.focusSection()`, `.glassEffect(.regular, in: RoundedRectangle(cornerRadius: Theme.Radius.card))` (`Theme.Surface.overlay` semantics), positioned with `.overlay(alignment: .topLeading)` on the `TabView`, padded `Theme.Spacing.screen` leading and inside the top safe area. Expand/collapse `.easeOut(0.2)`, gated on `accessibilityReduceMotion` (contract § Motion). Selecting a row sets `selectedTab`; focus stays on the sidebar until the user moves Right/Down (Omni behaviour).
- `SidebarItemButtonStyle` (custom; focused = white capsule with dark label like Omni; rest = transparent, icon in a translucent circle). Written justification goes in the style file and a HIG-contract carve-out (Wave 2), same shape as FEAT-14: opt-in, default OFF, documented.
- **Visibility**: rendered only when `sidebar_style == "sidebar"` and not (`tabBarVisibility.immersiveHidden` or `rootCoverActive` or `scrolledDownByTab[selectedTab] == true`), *unless* it currently holds focus (never unmount a focused view). `TabBarScrollAutoHide` (`TabBarVisibility.swift:194-269`) gains an optional `onChange` into `SidebarChromeModel.scrolledDownByTab[tab]` (keyed per tab, so no last-writer-wins; existing hysteresis arms untouched).
- **Summon (Menu grammar in sidebar mode)**: at each tab root, `onExitCommand` = "reveal + focus the sidebar" (`chrome.forceRevealed = true; focusedItem = selectedTab`) when the sidebar is not focused; when the sidebar *is* focused the handler is nil, so Menu falls through to the system default (today's tab-bar-focus + Menu = exit). Home keeps its BUG-27 scroll-to-top branch first: Menu when scrolled down scrolls to top and hands focus to the hero (existing); Menu at top (sidebar mode only) focuses the sidebar. Search/Library/Add-ons get the same root handler in sidebar mode only; Settings' internal Menu grammar (`SettingsView.swift:48-52`) is unchanged because its handler is at the split root only. Up from the hero / first row reaches the pill geometrically (it occupies the region the bar vacated) — Phase 0 verifies on hardware.
- **Geometry**: Phase 0 measures the top safe-area delta with the bar constantly hidden. If `debug_pinned`'s viewport (and `verifyViewportBudget`) still read 455, no compensation. If not, `MainTabView` applies `.safeAreaPadding(.top, sidebarTopCompensation)` on the `TabView` in sidebar mode (a named constant in `Theme.swift` next to the budget, provenance comment with the device measurement) so every tab lays out exactly as it does under the bar and the 455 budget stays valid. The `BUDGET MISMATCH` log line is the gate.
- **Probe**: hidden `Text("debug_sidebar mode= expanded= focused= revealed= concealed=")` next to `debug_env` for the harness; AX identifiers `sidebar_item_<Title>` on each row.

### FEAT-31 — Open Sans UI font (opt-in)

**Setting**: device-local `@AppStorage("ui_font")`, `"system"` (default) / `"openSans"`. Appearance § Theme, after Navigation, `SettingsPickerRow` "Typeface": "System" / "Open Sans". Launch-arg testable: `-ui_font openSans`.

**Files**: `NuvioTV/Resources/Fonts/OpenSans-Regular.ttf`, `OpenSans-SemiBold.ttf`, `OpenSans-Bold.ttf` (static faces from googlefonts/opensans, SIL OFL 1.1) + `OFL.txt`; `Info.plist` `UIAppFonts` with the three filenames. Static faces, not the variable font: `Font.custom(_:size:relativeTo:)` cannot pin a `wght` axis, and static faces let SwiftUI resolve `.weight(.bold)`/`.bold()` to the real Bold face by family name (verify on the sim in Wave 1 by checking `UIFont(name: "OpenSans-Bold")` resolves and a hero title renders non-synthesized). Belt-and-braces `CTFontManagerRegisterFontsForURL` at app init like the reference fork, in case folder sync nests the files.

**Tokens**: `Theme.Font` tokens become computed `static var`s that read `Theme.Font.family` (`nonisolated(unsafe) static var`, mirroring `Theme.Palette.accent` at `Theme.swift:21-35`) and return either the current system text style (family `.system`, byte-identical) or `SwiftUI.Font.custom("Open Sans", size: base, relativeTo: style).weight(w)` where `base = UIFontDescriptor.preferredFontDescriptor(withTextStyle: style, compatibleWith: UITraitCollection(preferredContentSizeCategory: .large)).pointSize` — derived, not hard-coded, so Dynamic Type still scales and no point size is typed into the file. Resolved fonts cached in a small dictionary keyed by token; all 371 call sites stay untouched. `Theme.Font.uiFont(for: textStyle)` helper for the one UIKit measurement (`CollectionsUI.swift:148`). The picker row sets `Theme.Font.family` **before** writing the `@AppStorage` value (custom `Binding` setter), and `NuvioTVApp.init` seeds it from `UserDefaults` — mutation precedes the re-render, no ordering race. Family change → remount via `rootIdentity`.

**Straggler sweep** (user-facing only, to tokens): `MPVPlayerView.swift` 14 sites, `AddonsView.swift` 8, `EpisodesSection.swift` 3, `NativePlayerScreen.swift:67` (`.title`→`screenTitle`, `.title2/.title3`→`screenTitle`/`sectionTitle`, `.headline`→`sectionTitle`, `.callout`→`body`, `.caption`→`caption`/`meta`; keep `.monospacedDigit()` on the timer sites and confirm Open Sans tabular figures do not jitter). Leave: invisible harness probes, About monospaced diagnostics and their empty states, the SF Symbol glyph size, the avatar initial, `NetworkStatusView`.

**Attribution**: About pane gets a "Fonts" `SettingsValueRow` ("Open Sans, SIL Open Font License 1.1") — OFL requires the license to travel with the font; `OFL.txt` is bundled.

### FEAT-33 — collection focus frame probe (no default behaviour change)

New `Screens/CollectionFocusFrameProbe.swift` modelled on `TrailerZoomProbe.swift:29-69` (NSLock, tail-rolling, live-read gate) + a `CADisplayLink` sampler modelled on `DetailView.swift:81-115` that records, per focus window (armed from `CollectionRowView.onChange(of: focusedFolderId)` at `CollectionsUI.swift:314`, closed 600 ms later): frame count, dropped frames (gap > 1.5× `link.duration`), p95 gap, `UIScreen.main.maximumFramesPerSecond`, and whether the focused tile has an animating GIF. One buffered line per window: `focus n frames=N dropped=D p95=Xms refresh=60 gif=0|1`. Never NSLog per vsync.

Exposure for a sideloaded tester: About pane toggle "Collection Frame Probe" + 1 Hz `TimelineView` readout + hidden AX blob `collection_frame_blob` (pattern `AboutSettingsPane.swift:100-132, 280-309`). Also gated by `-debug.collectionFrameProbe`.

A/B legs via `debug.collectionFocusAB` (launch-latched; About picker like `detailScrollAB`): 0 = as shipped; 1 = defer the folder hero re-commit until focus has rested 200 ms (in `HomeView.swift:1049-1069`, folder rows only; **does not touch `HeroCommitGate`/`HeroCommitCoordinator`** — the deferral sits before `reportRowFocus`); 2 = drop the tile's `.animation(.easeOut(0.15), value: isFocused)` (`CollectionsUI.swift:658`); 3 = both. Legs exist to turn "is it 30 fps" into "which of these is the 30 fps". No leg becomes default in this plan; a fix is a follow-up decided from the device numbers and Steven's photo.

---

## Phases and delegation (≤ 3 agents in flight; waves by file ownership; main session owns builds, Codex, commits, device)

Estimated agent spend: 7 agents × ~150–200k tokens ≈ 1.2–1.5 M tokens, plus Codex rounds and the main session. Build lock via `scratchpad/xcb.py -- xcodebuild …`; agents never build concurrently.

### Phase 0 — hardware spike (main session, ~1 h, before Wave 1 starts)
1. Tiny edit (main session, no agent): launch-latched knob `-debug.sidebarSpike YES` makes `TabBarImmersiveHideModifier` resolve `.hidden` for the session.
2. Debug build → Living Room ATV via `devicectl` (`--` before app args), launch with `-debug.sidebarSpike YES -debug.homeScrollProbe YES`.
3. Record: (a) Home pinned viewport vs 455 (`debug_pinned`/`BUDGET MISMATCH` lines) → sets `sidebarTopCompensation` or 0; (b) Menu with focus on the hero CTA at top: exit, no-op, or something else; (c) Up from the hero CTA and from the first row: where focus lands with the bar hidden; (d) same two on Search. Write the four answers into the plan doc copy before Wave 1 (they parameterize agent A's spec). If (b) is "exit", the summon design above holds as written; if Menu becomes a no-op at root, the sidebar's own nil-handler branch must instead call a documented exit path (`UIApplication.shared.perform(#selector(NSXPCConnection.suspend))` is **not** acceptable — surface it to Christian, do not improvise).

### Wave 1 — three agents, disjoint files
| Agent | Model | Owns | Deliverable |
|---|---|---|---|
| A | **Opus** (focus/geometry judgment, hotspot file) | `DesignSystem/SidebarOverlay.swift` (new), `ContentView.swift`, `DesignSystem/TabBarVisibility.swift`, `Screens/HomeView.swift` (`onExitCommand` sidebar branch at `:696`; `debug_sidebar` probe; FEAT-33 leg 1 deferral hook at `:1049-1069`), `SearchView.swift`/`LibraryView.swift`/`AddonsView.swift` root `onExitCommand` (sidebar mode only), `Theme.swift` compensation constant | Sidebar overlay end to end in sidebar mode; tabs mode byte-identical (agent diffs a tabs-mode screenshot pair) |
| B | **Sonnet** (exact spec) | `DesignSystem/Theme.swift` Font block, `NuvioTV/Resources/Fonts/*` + `OFL.txt`, `Info.plist`, `NuvioTVApp.swift` (seed + registrar), new `NuvioTVTests/AppFontResolverTests.swift` (family→font resolution, base-size derivation, system-mode identity) | Tokens switchable, default byte-identical, unit tests green |
| C | **Sonnet** (exact spec) | `Screens/CollectionFocusFrameProbe.swift` (new), `Screens/CollectionsUI.swift` (arm hook at `:314`, leg 2 at `:658`, `UIFont` helper use at `:148`), `Screens/Settings/AboutSettingsPane.swift` (toggle, AB picker, readout, blob, Fonts attribution row) | Probe + legs behind knobs, no default change |

Main session after Wave 1: Debug + Release sim builds, NuvioTVTests, commit per agent by explicit paths.

### Wave 2 — three agents
| Agent | Model | Owns | Deliverable |
|---|---|---|---|
| D | **Sonnet** | `Screens/Settings/AppearanceSettingsPane.swift` (Navigation + Typeface rows, `pendingAppearanceRowFocus` restore), `Localizable.xcstrings` via `NuvioMobile/scripts/populate-localizable-xcstrings.py <NuvioTV.build dir>` → translate the ~5 new keys (Navigation, Top Tabs, Sidebar, Typeface, System; "Open Sans" untranslated) into de/es/fr/it/vi → `merge-translations-into-xcstrings.py`; `docs/design/hig-hybrid-contract.md` carve-outs (sidebar `ButtonStyle` + `Font.custom` with derived base sizes) | Settings rows + strings + contract |
| E | **Haiku** (token edits) | `Screens/MPVPlayerView.swift`, `Screens/AddonsView.swift` (fonts only — A finished its `onExitCommand` edit in Wave 1), `Screens/EpisodesSection.swift`, `Screens/NativePlayerScreen.swift` | 26 straggler sites → tokens per the mapping table |
| F | **Sonnet** | `NuvioTVUITests/NuvioTVUITests.swift`: sidebar-aware `openTab` (if `sidebar_item_Home` exists: climb Up until a sidebar row `hasFocus`, walk Down/Up by name, Select) and `launchToHome` oracle; `test52SidebarOverlay` (`-sidebar_style sidebar`: collapsed pill shows Home; Up from hero → `debug_sidebar expanded=1`; Down → Search → Select → Search content; Menu at top → sidebar focused; `debug_pinned` viewport unchanged); `test53TypefaceOpenSans` (`-ui_font openSans`: `debug_env font=openSans`, hero title screenshot, player timer screenshot); FEAT-33 driver in the shape of `DetailScrollProbeTests:297`; FixtureSetup section-order assertion (`FixtureSetupTests.swift:179`) updated for the two new rows | Gates |

### Wave 3 — main session only
1. Full gates: Debug + Release sim, NuvioTVTests, UI suite (test03 tabs-mode unchanged, test30/43 fixture, test52/53, FEAT-33 driver), `verifyViewportBudget` log harvest clean in both modes.
2. Codex loop (direct, unsandboxed, `--wait`) until clean; fix → re-review.
3. Device pass on the Living Room ATV, Steven's configuration (Large posters, No Zoom, Card Depth as he runs them): sidebar reachability (Up from hero, Left from column 0, Right back into content on every tab), Menu grammar (scrolled-down → top → sidebar → exit; Detail pop unaffected; no BUG-47 eject on Add-ons/Profile/Settings empty states), pill hides on scroll and on Detail, no `BUDGET MISMATCH`, Large compression unchanged; Open Sans on Home/Detail/Settings/player chrome (bold real, timers steady, captions not clipped at `CollectionsUI:148`); Collection Frame Probe numbers for legs 0–3 while walking a folder row, photographed.
4. Commit, merge `claude/steven-parked-feats` → `tvos-shared-extraction`, bump the outer pointer, build number bump, unsigned rc IPA (verify `content-length` after upload), DM draft through the SlopMonster loop (5/5) with: the two Appearance rows to flip, the probe toggle and a photo ask for the readout, and no fps promise. Tracker rows FEAT-30/31/33, CLAUDE.md open items, memory note.

---

## Critical files

- `NuvioMobile/iosApp/NuvioTV/ContentView.swift` (`:33-51` hoisted state, `:105` remount key, `:238-320` MainTabView)
- `NuvioMobile/iosApp/NuvioTV/DesignSystem/TabBarVisibility.swift` (`:156-184` hide modifier, `:194-269` scroll auto-hide)
- `NuvioMobile/iosApp/NuvioTV/DesignSystem/SidebarOverlay.swift` (new)
- `NuvioMobile/iosApp/NuvioTV/DesignSystem/Theme.swift` (`:21-35` mutable palette pattern, `:139-153` Surface, `:161-177` Font tokens, `:418-462` viewport budget + compression table)
- `NuvioMobile/iosApp/NuvioTV/Screens/HomeView.swift` (`:553-590` probes, `:696-721` onExitCommand, `:1049-1069` folder focus → hero, `:1519` reportRowFocus)
- `NuvioMobile/iosApp/NuvioTV/Screens/CollectionsUI.swift` (`:148`, `:314`, `:658`)
- `NuvioMobile/iosApp/NuvioTV/Screens/Settings/AppearanceSettingsPane.swift` (`:35`, `:98-103` picker-row template), `SettingsRowViews.swift:274-293` (`SettingsPickerRow`)
- `NuvioMobile/iosApp/NuvioTV/Screens/Settings/AboutSettingsPane.swift` (`:100-132` probe readout pattern, `:280-309` toggles)
- `NuvioMobile/iosApp/NuvioTV/Screens/TrailerZoomProbe.swift:29-69`, `Screens/DetailView.swift:81-140` (probe + AB templates)
- `NuvioMobile/iosApp/NuvioTV/Info.plist`, `NuvioTVApp.swift`
- `NuvioMobile/iosApp/NuvioTVUITests/NuvioTVUITests.swift` (`:204-315` harness helpers, `:508-528` test03, `:4019-4090` test43), `FixtureSetupTests.swift:179`
- `NuvioMobile/scripts/populate-localizable-xcstrings.py`, `merge-translations-into-xcstrings.py`
- `docs/design/hig-hybrid-contract.md`, `docs/beta-feedback-tracker.md:168-171`

## Reuse
`SettingsPickerRow`, `SettingsToggleRow`, `SettingsValueRow` (row kit); `.glassEffect` + `Theme.Surface.overlay`; `TabBarScrollAutoHide` hysteresis; `verifyViewportBudget` as the geometry gate; `TrailerZoomProbe` buffer + `HomeHeroProbe` About/AX-blob pattern; `DetailScrollAB` leg pattern; `pendingThemeSwatchFocus` restore pattern; `launchToHome(extraArguments:)` argument-domain knobs; `Theme.Palette.accent` mutable-static pattern for `Theme.Font.family`.

## Explicit non-goals
`.sidebarAdaptable`; replacing `TabView`; subtitle typeface; changing hero commit or settle-corrector defaults; any fps fix before the probe numbers exist; syncing either new setting.

## Verification (end to end)
- Tabs mode + System font (defaults): test03 screenshots and `debug_env`/`debug_pinned` fields identical to the branch base; `verifyViewportBudget` silent.
- Sidebar mode: test52 green on FA87; device pass items above, photographed; `BUDGET MISMATCH` absent in the device log.
- Open Sans: test53 green; `UIFont(name: "OpenSans-Bold")` non-nil on device; AppFontResolverTests green; visual check of hero/section/caption/meta and the mpv timer.
- FEAT-33: probe lines appear in About on device for legs 0–3 while walking the Services/folder row with `debug.homeScrollProbe` and `debug.collectionCoverProbe` OFF; Steven's photo of the readout closes the question either way.
- Codex clean; Debug + Release sim builds green; NuvioTVTests green.

---

## Phase 0 — spike protocol (2026-09-05 evening)

Knob `-debug.sidebarSpike YES` (`TabBarVisibility.swift`, `TabBarImmersiveHideModifier.sidebarSpike`) resolves the tab bar to a constant `.hidden` for the session. `verifyViewportBudget` now also logs `viewport live=<vh> expected=<budget+compression>` once per distinct value under `-debug.homeScrollProbe YES`, so a matched viewport is positively confirmed rather than inferred from a missing MISMATCH line.

Device: Living Room ATV (`C11A7D65-498A-576D-B2AA-9F91D69BCBF7`), Debug build from `claude/steven-parked-feats` with the two edits above, installed over Debug 116.

Console half (main session, no input needed): launch with `-- -debug.sidebarSpike YES -debug.homeScrollProbe YES`, read `[HomeScrollProbe] hero viewport live=` and any `BUDGET MISMATCH`; in classic mode read `y= inset=` (the bar's 157/76 inset should be gone).

Remote half (Christian, in this order, one observation each):
1. Home at top, focus on the hero CTA (Play). Press **Up**. Where does focus go? (nothing / hero dots / offscreen / app exits)
2. Focus on the first row's first poster. Press **Up** twice. Same question.
3. Focus on the hero CTA. Press **Menu** once. Result? (app exits to the tvOS home screen / nothing / something else). If it exited, relaunch (the launch command re-applies the knobs).
4. Scroll down two rows, press **Menu**: does it still scroll to the top and focus the hero (BUG-27 behaviour)? Then **Menu** again at the top: result?
5. Search tab (reach it via… there is no bar; use the fact that `selectedTab` is remembered: instead, before the spike relaunch, leave the app on Search). With the bar hidden on Search: **Up** from the search field, and **Menu** with focus on the field. Results?
6. Anything visually odd with the bar hidden: content shifted up under the top safe area? Home hero clipped? Note it.

Results are recorded below and parameterize agent A's spec (compensation constant; Menu grammar branch).

## Wave 1 outcome (2026-09-05 ~20:30 ET)

- Spike build (Debug, `claude/steven-parked-feats` @ spike edits) installed on the Living Room ATV over Debug 116. First launch attempt refused: the TV was asleep (`System is asleep - foreground app launch forbidden`); console half pending on a wake.
- **Agent B (Sonnet) — FEAT-31 machinery, committed `70df06d4`.** `Theme.AppFontFamily` (`ui_font`: system/openSans), `Theme.Font` tokens now computed from a per-family cache (`apply`, `baseSize(for:)`, `uiFont(for:)`, `isCustomFaceAvailable`), three static Open Sans faces + `OFL.txt` in `Resources/Fonts/` (folder-synced, staged flat into the bundle root — verified in the built `.app`), `UIAppFonts`, `AppFontRegistrar.registerIfNeeded()` in `NuvioTVApp.init`. Caught its own `UIFont.TextStyle.caption1` vs `SwiftUI.Font.TextStyle.caption` mismatch. Main session fixed one warning (Token enum `nonisolated` under MainActor default isolation).
- **Agent C (Sonnet) — FEAT-33 probe, committed `ee3c8ce3`.** `CollectionFocusFrameProbe.swift` (sampler + `CollectionFocusAB` legs), `CollectionsUI.swift` (arm hook after `onFolderFocusChange`, leg 2 animation drop, caption height via `Theme.Font.uiFont`), About pane toggle "Collection Frame Probe" + readout + `collection_frame_blob` + "Collection Focus A/B" picker + "Fonts" attribution row (placed in the Tab Bar/Stream diagnostics Group to respect the 10-child ViewBuilder ceiling — revisit placement in Wave 2 if it reads oddly). Line format: `focus n= row= frames= dropped= p95=ms max=ms refresh= gif=`.
- Gates: Debug sim build green; `NuvioTVTests` 117/117 (7 new `AppFontResolverTests`, system-mode identity holds, Open Sans face registers in the test host).
- Spike knob + `viewport live=` line committed `3811b94e`.
- **Agent A (Opus) launched** with the compensation as a bisectable launch knob (`debug.sidebarTopCompensation`, default 0) so its work no longer waits on the spike numbers; **agent E (Haiku)** launched on the three straggler files A does not touch (AddonsView fonts deferred to Wave 2 because A owns that file this wave).

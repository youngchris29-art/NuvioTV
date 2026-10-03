# Detail + Settings revamp: spec corrections (main session, 2026-10-02)

Binding on every executor. Where this file and the P1/P2 specs disagree, **this file wins**. Sources: P3 critique (findings numbered F1–F21 below) and Christian's answers D9/D10 (recorded in the plan's Decisions table).

## Christian's decisions that change P1

- **D9, Cinematic action row: icon-only secondary buttons.** P1 §M PLAN CONFLICT 1 (full-width action row) is REJECTED. In Cinematic:
  - Play/Resume keeps its full label (the existing `seriesAction` label, hold for Choose Source…).
  - Start Over, Watch Trailer, Watched, Library and Shuffle render as round icon-only buttons using the same button style the existing `detail_action_icons_only` mode uses (reuse that code path; do not invent a new style). Each keeps its existing `accessibilityLabel` and accessibility identifier, so `app.buttons["Watch Trailer"]` etc. keep matching.
  - The action row sits inside the 900 pt text column, as the plan says. The credits block sits on the right, bottom-aligned to the action row (the plan's original layout), not to the synopsis slot.
  - The `detail_action_icons_only` setting keeps its current meaning in Classic. In Cinematic it is moot (secondaries are always icons, Play always labelled).
- **D10, IMDb ★:** `showImdbStar = sectionRatings && !(ratingsGateOn && !ratings.isEmpty)`. Ratings OFF hides the strip, the ★ and the About Ratings row. P1 §M PLAN CONFLICT 3 resolved this way.

## P1 (Detail) corrections

1. **F3 meta line:** fixed-height meta-line slot `DetailCinematicLayout.metaLineHeight` (unit-pinned). No `ProgressView` inside it in Cinematic (drop the spinner; loading is already conveyed by the hero/backdrop). Nothing above the bottom-anchored stack may change height after first paint.
2. **F4 ratings slot:** in `DetailViewModel.start()`, seed `mdbListRatingsActive` synchronously from `MdbListSettingsRepository.shared.uiState.value_ as? MdbListSettings` (same pattern as `readAutoPlayFirstStreamOn`, DVM:140-145), then start the watcher. Also require a usable IMDb id (`meta.imdbId` or a `tt…` id; rule from `MdbListMetadataService.kt:36-44 shouldFetchForMeta`) before reserving the slot.
3. **F5 hero height:** no `@State viewportMetrics`, no new `onScrollGeometryChange`. Use `.containerRelativeFrame(.vertical) { h, _ in max(520, h - 60 - 36 - 140) }` (constants named in `DetailCinematicLayout`, nonisolated, unit-pinned) on the Cinematic hero only. Classic gets nothing new. Gate 1 validates against `debug_detail_hero h=`.
4. **F8 synopsis sheet:** `showSynopsisSheet` lives in `DetailView` as `@State` and is passed to the hero as a `Binding`. Fold `&& !showSynopsisSheet` into `isTrailerActive` (DV:1164-1166). **No `.presentationBackground(...)` on the sheet**: the material sits over the default opaque cover (DV:1003-1007 records that a clear cover background made one Menu press dismiss the cover AND pop Detail).
5. **F17:** write both `DetailScrim` call sites out literally: the main one (DV:532) keeps `posterBackdropVisible: showPosterBackdrop`, the trailer-cover copy (DV:1014) keeps `posterBackdropVisible: false`.
6. **F18:** apply `.defaultFocus($heroFocus, .play)` on DetailView's outermost ZStack, not deep inside the ScrollView. Keep P1 §M's fallback if the Gate-1 leg shows focus not landing on Play.
7. **F16:** every pure helper type in C2/C5 is a `nonisolated enum`. No `Theme.*` references in nonisolated signatures or default arguments; mirror the value (`static let screenPadding: CGFloat = 60 // == Theme.Spacing.screen`) and pin it with a unit test.
8. **F19:** About labels (Director, Created by, Writers, Studios, Network, Country, Language, Status, Awards, Ratings, Audience) and "Shows the full synopsis" go through `String(localized:)`, reusing Classic `infoRows` keys where they exist.
9. **F6 `heroExit` guard (W2-A, decided now):** `.exit` fires only when `old == nil && new != nil` AND the page is at the top (`abs(lastContentOffset - expectedOffset(scrollTarget: 0, …)) <= verifyTolerance`). Returning from a cover/push to a deep row must not re-anchor. Add a DRA unit case; device step: Cast → Person → Back does not move the page.
10. **F7 probe note (W2-A):** add a plain field `dimModel.awaitingRevealNote`; the hero-exit branch sets it to `"hero-exit"`, and the geometry handler's blend pass appends it (`anchor=… blend+hero-exit`), then clears it. test79 asserts on `hero-exit` as a substring.
11. **F2 test72 (W3-C):** Right count `app.buttons["Start Over"].exists ? 2 : 1`; the return leg in `launchTheHundredOnPlay` becomes `press(.left, times: 3, gap: 0.8)` plus a focus guard on Play/Resume. (With D9 the row is still Play, Start Over, Watch Trailer, Watched…, so verify the actual order at Gate 1 and set counts from it.)
12. **F21a:** `hasResumableProgress` is written only when the value changes.
13. **F20:** accepted: a DetailView alive in Home's stack while Settings changes layout/sections re-resolves focus on return. Added to device step 6.

## P2 (Settings) corrections

1. **F1 keys:** P2 §E's Detail Page literals and its "DetailSectionKeys" proposal and J-7 are DELETED. Every row binds to `DetailSettingsKeys.*` (P1 §C1, lands in W1-A). The layout picker iterates `DetailLayout.allCases` with a binding over `DetailLayout.resolve(raw)` / `.rawValue`.
2. **F13:** P2 §B5's interim switch spells out the full call `AccountServicesSettingsPane(trakt:simkl:debrid:confirmingSignOut:confirmingTraktDisconnect:confirmingSimklDisconnect:debridDisconnectId:confirmingUseOfficial:)` exactly as at SettingsView.swift:224-233.
3. **F14 explainer:** never clear on blur. Keep the last focused entry; reset only in the pane's `onDisappear`. Use `Task { @MainActor in }`, not `DispatchQueue.main.async`. Write only when the id actually changes.
4. **F21b:** the root's focused-category state lives in a small observable model read only by the explainer column, so focus moves do not re-render the whole root List.
5. **F15 coverage test:** every helper parameter that carries a description id is named `descriptionID:`. Resolve sources with `URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("NuvioTV/Screens/Settings")`.
6. **F9 test helper (W3-C):** `openSettingsCategory` detects arrival by identifier (`settings_category_<raw>`, set on each root row Button) or `focusedButton(app)?.label.hasPrefix(title)`, with the deterministic fallback Up×12 then Down×index from the fixed root order. Root rows MUST carry `.accessibilityIdentifier("settings_category_\(category.rawValue)")`; the root List carries `settings_root_list`.
7. **F10 path restore:** Gate-1 evidence must include (a) a theme swatch change inside Appearance keeps the pane, (b) Custom Posters push → Menu → still on Appearance. If either fails, the named fallback is `enum SettingsRoute: Hashable { case category(SettingsCategory), customPosters, serverConnection }` as the path element.
8. **F11:** new UI leg (W3-C) launched with `-sidebar_style sidebar`: open a pane → Menu → `settings_root_list` exists and `sidebar_item_Search` does not. Fallback if it fails: in the root's exit handler pop when `!path.isEmpty` before `requestReveal`; never toggle the modifier structurally.
9. **F21d:** P1's new UI tests use test77–80; P2's start at test81.
10. **F21e:** W3-C uses P2 §I's migration table (it covers tests the plan's list missed: 00z, 07, 09, 11-13, 18, 26-28, 30, 32, 36, 45).
11. **F21f:** W1-B runs on **Opus** (focus-critical navigation), and the main session reads `SettingsRootView` before Gate 1.

## Hygiene (all agents)

- **F12:** never stage or rewrite `iosApp/NuvioTV/Localizable.xcstrings`, `iosApp/NuvioTV/Info.plist` or `iosApp/iosApp.xcodeproj/project.pbxproj`. New `.swift` files need no pbxproj edit (synchronized groups). The main session restored IDE re-serializations of all three on 2026-10-02; keep Xcode closed during the batch. Only W3-B touches the xcstrings, through the scripts.
- Agents edit files only: no `xcodebuild`, no `git`. The main session builds, tests and commits.
- Project default actor isolation is MainActor (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`).

## Wave 2 additions (Gate 1 checkpoint, Christian 2026-10-02, decision D11)

Detail is approved as built at Gate 1. Settings must match the option 1 mockup in `docs/research/detail-settings-revamp-2026-10-02.html` (lines 364-398):

- **V1 Switch toggles.** `SettingsToggleRow` keeps a real `Toggle` (VoiceOver on/off state, `isOn` binding) but applies a new `SettingsSwitchToggleStyle`: a `Button` that flips `configuration.isOn`, label on the left, a capsule switch glyph on the right (on: green track `#34C759` with white knob on the right; off: grey track with knob on the left; animate the knob unless Reduce Motion). On the white focus platter the off track must stay visible (darker grey) and the on track stays green. System focus platter only, no custom focus chrome, no `hoverEffect`. The glyph is decorative (`accessibilityHidden`); the Toggle carries the state.
- **V2 Row platters.** Every kit row (toggle, picker, value, link, action, destructive, debrid entry) gets the same subtle rounded platter at rest (white ~6% over the background, corner radius matching the system focus platter), via `listRowBackground` or an equivalent that does not fight the system focus platter. Rows must look uniform: today Menu-picker rows show a grey pill while toggle rows show nothing.
- **V3 Section headers.** `SettingsSection` headers render as small uppercase letter-spaced captions in `textSecondary` (mockup `.s-row.hd`).
- **V4 Values with chevrons.** Picker rows and link rows show the current value plus a `›` chevron in `textSecondary` on the right, not the native grey Menu pill and not accent-coloured text. The Menu{Picker} popover behaviour stays.
- **V5 Explainer.** `SettingsExplainerColumn` (root and pane): an accent-gradient tile (theme accent → a darker shade of it, rounded ~20% of its side, about 200-240 pt) with a white SF Symbol; a bold title in a display-size `Theme.Font` token; the description in `body`/`detail` with `textSecondary`-ish opacity; and an optional small footnote line (new optional `footnote` per description id in `SettingsDescriptions`, e.g. Match Frame Rate: "Also set in tvOS Settings › Video and Audio › Match Content"). A row without its own icon shows the pane's icon.
- **V6 Copy now.** The ~148 row descriptions and their footnotes are written in Wave 2 (they were W3-A), replacing "TODO", so Gate 2 screenshots show real text. Pane-split agents wire `descriptionID:` onto every row they move. The coverage tests' skips come off once every id has copy and is used.
- **Init signatures of the kit rows do not change in the visual pass**, so pane-split agents can work in parallel against the current API.

# Detail page + Settings revamp: implementation plan (2026-10-02)

**Status: APPROVED 2026-10-02, implementation in progress (local session), submodule branch `claude/detail-settings-revamp` off `5f2d5cd3`. Progress in OUTCOME at the end.**

Source: the options board `docs/research/detail-settings-revamp-2026-10-02.html` (artifact https://claude.ai/artifact/Rm6gGagVfNg71Q6emRaK7p). Christian picked **Detail option A, "Cinematic Clean"** and **Settings option 1, "Native Split + Explainer"**, then answered eight spec questions (recorded under Decisions). Paths are relative to `NuvioMobile/iosApp/NuvioTV/` unless stated otherwise.

## Where to run this

**Run it in a local Claude Code session on the Mac, not in this cloud session.** The cloud container is Linux with no Xcode, Swift toolchain, tvOS simulator, `devicectl` or Codex CLI. It cannot build the app, run `NuvioTVTests` or the UI legs, take simulator screenshots, or install on the Apple TV, and every wave below ends on one of those gates. The memory files (`agent-delegation-playbook` and others) and `~/.claude/plans/` also live only on the Mac. This cloud session produced the research and this plan. The local session starts by copying this document to `~/.claude/plans/detail-settings-revamp.md` and treating it as the approved plan.

## Decisions (Christian, 2026-10-02)

| # | Question | Answer |
|---|---|---|
| D1 | Technical badge line (4K/DV/HDR/Atmos) | **Skip in v1.** NuvioTV does not know a title's quality until streams load. |
| D2 | Keep the current layout? | **The new layout is the default. A "Detail Layout: Cinematic / Classic" picker keeps today's page for 1–2 betas, then Classic is deleted.** |
| D3 | Reaching a long synopsis | **The synopsis becomes focusable when it is truncated. Select opens a full-text sheet; Menu closes it.** |
| D4 | Detail add-ons in this batch | **All four: ratings strip, Detail Page settings pane with section toggles, Start Over button, spoiler-safe episodes.** |
| D5 | Setting descriptions | **English plus de/es/fr/it/vi**, through the existing xcstrings scripts. |
| D6 | Category navigation | **The explainer replaces the sidebar.** The Settings root is a grouped list of categories with a large icon and summary on the left. Selecting a category pushes its pane. Inside a pane, the left side explains the focused row. |
| D7 | Diagnostics | **An always-visible "Developer" category** at the bottom of the root list. Nothing is hidden behind an unlock. |
| D9 | Cinematic action row (asked 10-02 after P1 measured six labelled buttons at ~1500 pt) | **Icon-only secondary buttons in Cinematic.** Play/Resume keeps its label; Start Over, Watch Trailer, Watched, Library and Shuffle are round icon buttons with their existing accessibility labels, so the row fits the text column and the credits stay beside it. The Icon-Only Buttons setting keeps applying to Classic. |
| D10 | IMDb ★ when the Ratings toggle is off (asked 10-02) | **Hidden too.** Ratings OFF hides the strip, the ★ on the meta line and the About ratings row. The ★ shows only with Ratings ON and the MDBList strip off or empty. |
| D11 | Gate 1 checkpoint (10-02): Detail approved as built; Settings should look like the option 1 mockup "with toggle buttons and everything" | **Settings visual pass in Wave 2:** switch-style toggles (custom `ToggleStyle` over a real `Toggle`; a deliberate, Christian-directed exception to the HIG contract's native-Toggle-only rule), a subtle rounded platter on every row at rest, small-caps section headers, picker/link values shown as `value ›` instead of the grey pill, and the explainer as an accent-gradient icon tile + bold title + description + optional footnote. Description copy moves from Wave 3 into Wave 2 so the explainer shows real text at Gate 2. |
| D8 | Re-sort | **9 panes in 4 groups, plus Developer = 10 categories.** Advanced (Remote Setup only) folds into Account & Profiles. |

### Defaults I chose (override any of them when approving)

- **Storage.** Section toggles, spoiler blur and the layout picker are device-local `@AppStorage`, like the six existing Detail keys. They are not profile-synced, so the phone's Detail choices never reshape the TV. NuvioMobile's synced `MetaScreenSettingsRepository` stays as it is (it still owns Episode Ratings).
- **Defaults keep today's behaviour,** except for the layout:
  - Every section toggle defaults ON.
  - Spoiler blur defaults OFF.
  - Detail Layout defaults to Cinematic (D2).
- **Settings Style "Minimal"** hides the icons and the explainer column, so panes use the full width. "Default" shows both.
- **No Classic toggle for Settings.** D2 applies to Detail only.
- **Out of scope:**
  - Clear Cache / Licenses rows in About.
  - Settings search.
  - FEAT-41's depth sliders and preview.
  - The FEAT-45 icon rail: D6 removes the sidebar, so the tracker reply explains that.
  - An ambient-colour background (option D).
  - The trailer-bridge caption lining up with the hero logo.

  All of these are logged as follow-ups.
- **Release vehicle.** Cut beta.19-rc1 from the already-merged verdict batch (`3f377cd8`) first, as planned. This batch ships in a later rc, which keeps a regression in one apart from the other.
- **Two merges, one branch.**
  - Part 1 (Detail) and Part 2 (Settings) are developed on one branch, `claude/detail-settings-revamp`.
  - Each part gets its own review rounds and device pass, and Part 1 can fast-forward into `tvos-shared-extraction` first.
  - If Settings runs long, Detail ships without it.

## What the code looks like today (evidence from three Explore reports, 2026-10-02)

### Detail (`Screens/DetailView.swift`, 2,570 lines)

- **`topBlock`** (DV:1333-1364)
  - An `HStack` with a 1200 pt left column on the left: `header`, `metaLine`, `actionRow`, genres, and `infoSection` (the "Details" table, DV:1814).
  - On the right, the 560 pt glass `synopsisPanel` (DV:1461), capped at 18 lines, not focusable.
  - The height is intrinsic, and the first row follows 32 pt below.
  - The full-width frame is required for BUG-117, so Up from a far-right season poster still finds a target.
- **`header`** (DV:1367): the logo is `maxWidth 600, maxHeight 180` with no fixed slot, so the page shifts when the logo loads.
- **Focus**
  - There is no `prefersDefaultFocus`; the engine lands on Play.
  - `DetailRowAnchor.swift` tracks every row except the top block (`focusedRow == nil` means focus is in the hero).
  - Down leaves the engine's minimal reveal alone and anchors only above `screenRest` 108 (BUG-99).
  - Up always anchors.
  - Moving back into the hero does **not** scroll to y = 0 (DV:619-625).
- **Dim ramp:** 0 → 0.85 over 400 pt (DV:754-776). The trailer tears down at a dim of 0.80, about 376 pt of scroll.
- **Trailer bridge:** fades the whole ScrollView via `chromeOpacity`. `TrailerBridgeCaption` has no dependency on the header frame.
- **Data available at first paint**
  - `MetaDetails` carries `description`, `releaseInfo`, `runtime`, `ageRating`, `imdbRating`, `genres`, `director`, `cast`, `externalRatings` and more (`shared/.../details/MetaDetailsModels.kt:6-46`).
  - Cast and director arrive with the first meta publish.
  - `externalRatings` (MDBList) arrives in a second emission, so the ratings strip must reserve its slot or fade in without moving anything.
  - The shared helpers `formatMetaReleaseLineForDetails` and `formatRuntimeForDisplay` exist but have no tvOS callers.
- **Settings keys:** `detail_trailer_autoplay`, `detail_trailer_background`, `detail_trailer_duration`, `detail_poster_backdrop` and `detail_action_icons_only` are device-local `@AppStorage`. Episode Ratings is the synced `MetaScreenSettingsRepository`.
- **Tests that pin the current layout:**
  - `DetailScrimTests`: the panel constants.
  - `test17` and `test33`: `detail_synopsis_panel` / `detail_synopsis_text` must exist.
  - The `DetailRowAnchorTests` UI leg: its `sectionTitleFrames` heuristic would count new hero text lines as headers.
  - `DetailScrollProbeTests` UI: scroll depth.
  - `test68`: Up from the last season poster lands on Mark Watched or Library.
  - `test72`: "Watched" is one Right from Play.
  - `test51`: `app.buttons["Watch Trailer"]` and the `debug_bridge` trace.
  - `test02` and `test21`: Down counts.
- **Start Over:** the Orivio batch's Continue Watching hold menu already has a Start Over path to reuse.

### Settings (`Screens/SettingsView.swift`, 356 lines, plus 7 panes)

- **Structure**
  - `NavigationStack` → title → `HStack` (sidebar `List`, detail `List`).
  - Focus is selection (`onChange(of: focusedCategory)`, :305).
  - `selectedCategory` is a `@Binding` owned by `ContentView` (:40), so it survives the theme `.id()` remount. `pendingThemeSwatchFocus` and `pendingAppearanceRowFocus` survive the same way.
  - `.sidebarMenuReveal()` (:118) handles the FEAT-30 sidebar navigation mode.
- **Row kit** (`Screens/Settings/SettingsRowViews.swift`)
  - Every kit row builds `SettingsRowLabel` (:110), which is the natural place to attach a description.
  - The row types are Toggle (:255), Picker (:280), Value (:328), Link (:356), Action (:387), Destructive (:414) and DebridKeyEntry (:448).
  - Custom rows outside the kit: `ThemePickerRow` swatches, the subtitle colour swatches, `HeroSourceRow`, `CatalogSettingRow`, the plugin repo rows, the badge pack rows, and the activation cards.
  - Per-row focus has precedents: `appearanceRowFocus` `@FocusState`, and `HeroSourceRowLabel` reading `\.isFocused` (only populated on the focusable control and its descendants).
- **ViewBuilder ceiling:** Playback and About already hit the 10-child limit and use nested `Group`s.
- **Storage:** every row binds to a repository singleton or a UserDefaults key, never to a pane. Moving rows is purely a UI change. A new pane needs the right view model injected; `SettingsView` owns `model`, `badges`, `plugins`, `trakt`, `simkl`, `debrid` and `remote`.
- **Localization:** `Localizable.xcstrings` has 1,014 keys in de/es/fr/it/vi. Scripts: `populate-localizable-xcstrings.py` → translate → `merge-translations-into-xcstrings.py`. **Use Sonnet for strings, never Haiku** (09-30 handoff).
- **Copy that names panes and must change:**
  - `StreamsViewModel.swift:168, :249, :265`
  - `StreamPickerView.swift:749, :809, :1159`
  - `CloudLibraryUI.swift:61`
  - `ServerConnectionViewModel.swift:204`
  - ContentSources `:70, :98, :159`
  - StreamBadges `:18`
- **Tests that pin the current structure** (about 20 UI tests):
  - `moveToSidebarRow(named:)` + Right, and `walkToRowByTreeIndex` (sidebar maxX).
  - test04: Down ×3 from Account & Services to Home Screen.
  - test40SettingsFocusGraph.
  - test05: German Settings, Down ×2.
  - FixtureSetupTests :214-306 and PinnedRowSettleRegimeTests :427-459: fixed Down counts through Appearance.
  - test31, HeroOffLaunchTests, HeroLogoFocusTests, HeroFolderSwapTests, TabBarScrollLinkTests and test54 open About to read probe readouts. These move to Developer.
  - The probes are seeded by `-debug.*` launch args. `@AppStorage<Bool>` does not coerce the string "YES", so readouts OR in a live read, and that must be preserved.
- **HIG contract** (`docs/design/hig-hybrid-contract.md`):
  - Native `List`/`Toggle`/`Menu{Picker}` only, with no custom focus chrome.
  - Rows that act must be `Button`s.
  - `Theme.Font` tokens and `textPrimary` / `textSecondary` only.
  - No `.searchable`.
  - Glass only as a background, never wrapping focusable content (Orivio's focus-trap lesson).

## Target design

### Part 1: Detail, "Cinematic Clean"

**First screen, bottom-anchored, in the left column (max width ≈ 900 pt):**

1. **Logo slot, fixed height 180 (max width 600).** The logo is bottom-aligned inside the slot, with the `Theme.Font.hero` title as the fallback. The slot never changes height. This copies Orivio's 180 pt slot and avoids Plex's logo-shift bug.
2. **Meta line** (`metaStrong`): Year · Runtime · Genre 1, Genre 2 · age-rating chip, plus the IMDb ★ score *only when the ratings strip is off or empty*.
3. **Ratings strip** (new, `meta`).
   - Sources: `meta.externalRatings`.
   - Order: IMDb, Rotten Tomatoes, Metacritic, Trakt, Letterboxd, then others (MDBList's own order).
   - Fixed-height slot. It fades in when the second meta emission lands and never pushes content.
   - Hidden when the MDBList Ratings setting is off, or the Ratings section toggle is off (closes FEAT-28).
4. **Synopsis teaser**, 4 lines, `Theme.Font.synopsis`.
   - Fixed slot of 4 × `synopsisLineHeight`.
   - When the text is truncated, the teaser is a focusable `Button` (system style) that opens **`DetailSynopsisSheet`**: a `.fullScreenCover` or overlay with a glass background, the logo/title, the full text in a scroll view, and Menu to close.
   - Not focusable when the text fits.
5. **Action row** (`GlassEffectContainer`, unchanged button styles):
   - Play / Resume (the existing `seriesAction` label, hold for Choose Source…).
   - **Start Over** (new, only with saved progress; reuses the Orivio hold-menu Start Over path).
   - Watch Trailer.
   - Watched.
   - Library.
   - Shuffle.
   - Icon-only mode keeps working and so do the accessibility labels; the test labels stay the same.

**Right side, bottom-aligned to the action row:** a non-focusable **credits block** (`detail` token, `textSecondary` with `textPrimary` names), right-aligned:
- "With *top 3 cast*"
- "Directed by *director(s)*", or "Created by" for series when the meta carries it.

The block is hidden when both lines are empty.

**Removed from the hero:**
- The 560 pt glass synopsis panel.
- The genres line (folded into the meta line).
- The Details table (moved to the About section).

**Peek:**
- The hero fills the viewport minus a **peek band of about 140 pt**. The first row's title and the top of its cards show at the bottom.
- The rows below keep today's order and code: logos, parental, episodes, cast, saga, trailers, More Like This, comments, then **About**.

**About section (new, last):**
- Title "About".
- A two-column label/value grid with Director, Writers, Studios, Network, Country, Language, Status, Awards and the full ratings list.
- Non-focusable text in token fonts, plus one focusable anchor so Down can reach it. This is the same pattern as the Person page's inert focusable block.
- Tracked as a new `DetailRowID.about`.

**Motion:**
- **Down from the hero** (new branch where `old == nil`): the first row anchors at `screenRest` (108) in one motion, the dim ramps, and the hero leaves.
- **Up from the first row back into the hero** (new): scroll to y = 0 so the hero is fully restored and the dim returns to 0.
- Both decisions are pure functions in `DetailRowAnchor` with unit tests.
- The BUG-96/99 rules for the other rows stay as they are.

**Scrim:**
- A Cinematic variant in `DetailScrim`: a stronger lower-left radial or diagonal under the text block, with the rest of the image left brighter.
- Steven's BUG-127 "too dark" stops (0.80 / 0.30 / 0.18, bottom 0.70) are the ceiling, not the floor.
- Glass flattening while scrolling or during a trailer (BUG-41) applies to the remaining chips.

**Classic:** `detail_layout = "classic"` renders today's `topBlock` byte for byte, including the synopsis panel and the Details table. The About section, ratings strip and Start Over appear only in Cinematic. The section toggles and spoiler blur apply to both layouts.

**Spoiler-safe episodes** (`EpisodesSection.swift`):
- Setting "Hide Spoilers in Unwatched Episodes" (default OFF). It blurs the stills of unwatched episodes and replaces their synopsis with "Synopsis hidden until watched".
- The season picker shows "N aired unwatched" (aired = air date ≤ today).
- Hidden for movies and fully watched seasons.

### Part 2: Settings, "Native Split + Explainer"

**Root (`SettingsRootView`):**
- One "Settings" title.
- Left, about ⅓ of the width: the **explainer**, a large SF Symbol tile (accent-tinted, 240 pt) plus the focused category's title and a 2–3 sentence summary.
- Right: a native grouped `List` of category `Button`s, each showing an icon, title and a one-line subtitle. Groups:

  | Group | Categories |
  |---|---|
  | You | Account & Profiles, Services |
  | Look | Appearance, Home Screen, Detail Page |
  | Watch | Player, Sources, Subtitles & Audio |
  | System | About, Developer |

- Selecting a row pushes the pane through `NavigationStack`. The path is held in a `ContentView`-owned binding so a theme remount restores the open pane.
- Menu in a pane pops back to the root with focus on that category. Menu at the root keeps the FEAT-30 sidebar-reveal behaviour.

**Pane (`SettingsPaneScaffold`):**
- Left: the explainer, showing the focused row's icon, title and description (`detail`/`body` tokens, `textSecondary`). When the focused row has no description, it shows the pane summary.
- Right: today's native `List` content for that pane.
- Pushed sub-pages (Custom Posters, Server connection) keep their own layout.

**Description plumbing:**
- Add a `descriptionID:` parameter (a stable string id such as `player.matchFrameRate`) to `SettingsRowLabel` and the six kit row inits. A `.settingsDescription(_:)` modifier covers custom rows.
- The focused row publishes its id upward through a `PreferenceKey`, read from `\.isFocused` inside the label. A `SettingsExplainerModel` held by the scaffold receives it.
- Copy lives in one catalog, `Screens/Settings/SettingsDescriptions.swift` (id → `LocalizedStringResource`), so it can be reviewed and translated in one place.
- A unit test asserts that every id used in a pane has copy and that every copy entry is used.

**Re-sort (row → new pane):**

| New pane | Comes from |
|---|---|
| Account & Profiles | Account, Server (Account & Services) + Remote Setup (Advanced) |
| Services | Trakt, Simkl, MDBList, More Like This, Debrid (Account & Services) |
| Appearance | Theme, Poster Style (minus Detail rows), Custom Posters, Card Depth, Stream Badges |
| Home Screen | unchanged |
| Detail Page (new) | Detail Layout (new), Auto-Play Trailer, Background Trailer, Trailer Duration, Trailer Sound by Default (from Playback), Poster in Background, Icon-Only Buttons, Episode Ratings, Hide Spoilers (new), Sections: one toggle each for Studio Logos, Parental Guide, Ratings, Cast, Collection, Trailers & Extras, More Like This, Comments, About (new). Episodes deliberately has no toggle, as in Orivio. |
| Player | Default Player, Skip Intro + Auto-Skip, Episode Shuffle, Match Frame Rate, Enhanced Renderer, Native DV/HDR, Profile 7 FEL, Pause Info Card, Streaming Buffer, Network Readahead |
| Sources | Auto-Play Source section, Sources filters section (Playback) + Metadata (TMDB), Ratings (MDBList), Library & Watch Progress, Search Sources, Plugins (Content Sources) |
| Subtitles & Audio | Subtitle style controls, Audio & Subtitle Language |
| About | Version, Build, Commit, tvOS, Device, Source |
| Developer | every diagnostic, probe and A/B row from About, unchanged, with the AX blob ids kept |

**Settings Style:** "Default" shows the root icons and the explainer. "Minimal" shows text-only root rows with no explainer column.

## Branch and delegation

- **Branch:** submodule `claude/detail-settings-revamp`, cut from `tvos-shared-extraction` **after** the beta.19-rc1 build bump lands. Never use `git worktree` on the submodule.
- **What stays in the main session:** builds, tests, simulator legs, screenshots, commits and the device install. Agents edit files only, and never build.
- **Concurrency:** at most 3 agents at once, split by file ownership. A file touched in two waves is edited sequentially, never concurrently.
- **Model tiers:**
  - Opus: specs, critique, judgment refactors, focus and scroll work, test migration.
  - Sonnet: well-specified execution, copy, translations.
  - Haiku: unused (strings go to Sonnet, per the 09-30 handoff).
- **Review:** Codex is on its usage limit until 2026-10-29, so review means internal Opus read-only rounds over `<base>..HEAD` until clean, with fix agents per file owner. If the batch reaches review after 10-29, use `.claude/skills/codex-review/tools/review.sh --repo NuvioMobile --base <sha>` instead (unsandboxed, never piped).

### Wave 0: main session

1. Fetch. Confirm the rc1 cut is in. Create the branch and record the base sha.
2. Baseline gates on the base:
   - `NuvioTVTests` (expect 620 / 0)
   - Debug + Release simulator builds
   - UI legs test17, 33, 40, 51, 68, 72 and FixtureSetupTests, to record which already skip on FA87 state.
3. Tracker rows:
   - FEAT-35 → IN PROGRESS.
   - New FEAT rows (next free ids) for the Settings explainer/re-sort and spoiler-safe episodes.
   - FEAT-28 → folded into the Ratings section toggle.
   - FEAT-45 → declined (D6), reply text owed.
4. Copy the three Explore reports from this cloud session into `docs/research/detail-settings-revamp-explore-2026-10-02.md` if the local session wants them verbatim; the evidence section above is the summary.

### Design phase (before any edit)

- **P1 (Opus Plan): Detail spec.**
  - Exact geometry: slot heights in tokens, the peek band, left-column width, scrim stops.
  - The `DetailLayout` switch point in `DetailView.body`.
  - The new `DetailRowAnchor` decisions (`heroExit`, `heroReturn`) with signatures.
  - The `DetailRowID.about` wiring.
  - The ratings-strip ordering function, the synopsis truncation test (measured line count against the slot), the Start Over call path, and the spoiler-blur rules.
  - Every new `@AppStorage` key and default.
  - Output: a spec per W1/W2 agent with file:line anchors.
- **P2 (Opus Plan): Settings spec.**
  - `SettingsCategory` rewrite (10 cases, group, icon, title, subtitle, summary).
  - Navigation-path ownership in `ContentView` and the theme-remount restore.
  - Pop-to-root focus restore, and the `.sidebarMenuReveal()` interplay.
  - The scaffold layout, the `PreferenceKey` design, the Minimal behaviour.
  - The **row-to-pane table with every row** (from the Explore inventory), the view-model injection per pane, the ViewBuilder child counts per new section, and the cross-reference string edits.
  - The description id list (every focusable row).
- **P3 (Opus critique)** of P1 + P2 against the HIG contract, the focus rules and the test list. The main session folds its P1/P2 findings into the specs.
- **Checkpoint:** Christian reads the two specs' summary tables (geometry and row map) before Wave 1. This takes about 5 minutes and is optional if he prefers to judge from screenshots.

### Wave 1: three agents in parallel, disjoint files

- **W1-A (Opus): Detail hero.**
  - New `Screens/Detail/DetailCinematicHero.swift`: logo slot, meta line, ratings strip, synopsis teaser, action row with Start Over, credits.
  - New `DetailSynopsisSheet.swift`.
  - In `DetailView.swift`: the layout switch only, around `topBlock`. Classic stays untouched.
  - `DetailScrim` Cinematic constants.
- **W1-B (Sonnet): Settings infrastructure.**
  - New `SettingsRootView.swift`, `SettingsPaneScaffold.swift`, `SettingsExplainerModel.swift`, and `SettingsDescriptions.swift` (ids only, English placeholders "TODO").
  - `SettingsCategory` rewrite in `SettingsView.swift`.
  - `descriptionID:` plumbing in `SettingsRowViews.swift`.
  - The navigation-path binding in `ContentView.swift` (that one function only).
- **W1-C (Sonnet): spoiler-safe episodes.**
  - `EpisodesSection.swift` and the `@AppStorage` key.
  - The "N aired unwatched" label.
  - Unit tests for the aired/unwatched count.

**Gate 1:**
- Debug build plus `NuvioTVTests`.
- Simulator screenshots: Detail for a movie, a series, a title with no logo, a long synopsis, and a title with no backdrop; the Settings root; one pane with the explainer showing.
- Saved to `docs/research/detail-settings-revamp-sim-evidence/`.
- **Christian design checkpoint on the screenshots**, before Wave 2 polishes anything.

### Wave 2: after Gate 1

- **W2-A (Opus): Detail scroll, focus and About.**
  - `DetailRowAnchor.swift`: `heroExit` / `heroReturn`, `.about`.
  - `DetailView.swift`: `onChange(of: focusedRow)` branches, peek geometry, dim ramp and trailer latch retune, the About section view, section-toggle gates on each row.
  - Keep the full-width focus section (BUG-117).
  - `DetailRowAnchorTests` (unit) cases for the new decisions; `DetailScrimTests` updated for the Cinematic constants, with Classic constants still pinned.
- **W2-B (Sonnet): pane split, part 1.**
  - New pane files: `AccountProfilesSettingsPane`, `ServicesSettingsPane`, `DetailPageSettingsPane` (including the section toggles and layout picker).
  - Trim `AccountServicesSettingsPane` and `AdvancedSettingsPane` (deleted once empty), and the Detail rows out of `AppearanceSettingsPane`.
- **W2-C (Sonnet): pane split, part 2.**
  - New `PlayerSettingsPane`, `SourcesSettingsPane`, `SubtitlesAudioSettingsPane`, `DeveloperSettingsPane`.
  - Trim `PlaybackSettingsPane` (deleted once empty), `ContentSourcesSettingsPane` and `AboutSettingsPane`.
  - The cross-reference copy edits in Streams, StreamPicker, CloudLibrary and ServerConnection.

W2-B and W2-C own disjoint pane files. `SettingsView.swift`'s pane switch is edited by the main session after both land.

**Gate 2:** Debug + Release builds, `NuvioTVTests`, and a manual simulator walk of every pane (screenshots added to the evidence folder).

### Wave 3

- **W3-A (Sonnet): description copy.**
  - Plain-language English for every id: what the setting does, when to change it, and the default.
  - About 130 rows plus 10 category summaries.
  - Run through `scripts/deslop/deslop.py` to 5/5, then hand to Christian for an asynchronous skim.
  - Then wire `descriptionID:` onto every row in the new panes. These are mechanical edits on files whose owners are done.
- **W3-B (Sonnet): translations, after Christian's skim.**
  - `populate-localizable-xcstrings.py` → de/es/fr/it/vi → `merge-translations-into-xcstrings.py`.
  - Also translates the new pane titles, the Detail strings ("With", "Directed by", "About", "Start Over", "Synopsis hidden until watched", "N aired unwatched") and the section toggle labels.
- **W3-C (Opus): test migration and new tests.**
  - **Helpers:** `openSettingsCategory(named:)` (focus the root row, then Select to push) replaces `moveToSidebarRow` + Right; `openDeveloper` is used by the probe readers.
  - **Settings tests to migrate:** test04, test05, test40 (rewritten as a root/pane/pop focus graph), test16, test25, test29, test35, test43, test53, test54, test31 and the Hero* probe readers, TabBarScrollLinkTests, and the Fixture/PinnedRowSettle Down-count walks (new Appearance order).
  - **Detail tests:**
    - test17 and test33 move from the panel ids to `detail_synopsis_teaser`.
    - The `DetailRowAnchorTests` UI `sectionTitleFrames` filter excludes the hero.
    - test68: Up target labels.
    - test72: Right count; no Start Over without progress.
    - test02 and test21: Down counts.
  - **New UI tests (next free numbers):**
    - Cinematic landing: focus on Play, logo slot height constant, first row peeking.
    - Synopsis sheet open and close.
    - Up from the first row restores the top.
    - Classic layout still shows the panel.
    - Settings root push and pop with focus returning to the category.
    - Explainer text changes with row focus.
    - Developer readouts still reachable with `-debug.*` args.
  - **New unit tests:**
    - Description coverage.
    - `SettingsCategory` grouping and order.
    - Ratings-strip ordering.
    - Synopsis truncation decision.

**Gate 3:**
- Full `NuvioTVTests`.
- All migrated and new UI legs (reboot the simulator after about 6 runs, per the harness lessons).
- Debug + Release builds.
- Kotlin gates only if `shared/` is touched (it should not be).

### Review

- Opus read-only round 1 over `<base>..HEAD`, Detail and Settings as separate passes.
- Fix agents per owner.
- Round 2.
- Repeat until no P1/P2 findings remain.
- Record a `# | Sev | Finding | Decision` table in the OUTCOME section of this document.

### Device pass (Christian, Living Room Apple TV, **"Test" profile**)

Debug build launched with `-debug.detailScrollProbe YES --console`, logged to `~/Downloads/detail-settings-revamp.log`.

**Detail**
1. Open a movie with a logo: the logo does not shift; meta line; ratings strip fades in without moving anything; 4-line synopsis; credits on the right.
2. Long synopsis: Select opens the full text; Menu closes it.
3. A series with progress: Resume + Start Over; Start Over plays from 0.
4. Down from the hero: the first row lands under the top in one motion. Up: the hero is fully back.
5. The About section at the end reads correctly.
6. Turn each section toggle off and check the row disappears.
7. Spoiler blur on: unwatched stills are blurred and "N aired unwatched" is correct.
8. Trailer auto-play and the bridge still work, and the return to the page is clean.
9. Switch to Classic: today's page, unchanged.
10. Scroll smoothness (BUG-41 class).

**Settings**

11. Every category opens; the explainer follows focus.
12. Menu pops back to the right category.
13. A theme change inside Appearance keeps the pane open.
14. German UI spot check.
15. Developer probes work.
16. Minimal style.
17. Sidebar navigation mode: Menu at the root reveals the sidebar.

### Merge, cut and comms (each on Christian's go)

- Fast-forward Part 1 when its device pass passes, Part 2 when its pass does (or both together).
- Push, delete the branch, bump the outer pointer.
- Cut the next beta.19 rc.
- **Steven DM** (SlopMonster loop to 5/5): name every new setting and its default; point him to Detail Layout → Classic to compare; ask for photos of the hero and a Settings pane.
- **Tracker replies:**
  - FEAT-35: built.
  - FEAT-28: section toggle.
  - FEAT-7 / FEAT-45: the explainer layout replaces the sidebar.
  - FEAT-41: next.
- Update CLAUDE.md and memory.

## Agent roster (estimate)

| Phase | Agents |
|---|---|
| Explore | 3 (done in the cloud session; reports summarised above) |
| Design | 2 Opus Plan + 1 Opus critique |
| Execution | 3 Opus (W1-A, W2-A, W3-C) + 5 Sonnet (W1-B, W1-C, W2-B, W2-C, W3-A) + 1 Sonnet translation (W3-B) |
| Review | 2–3 Opus rounds + about 3 fix agents |

## Risks worth knowing before the go

1. **Push navigation vs the theme remount.** Today `selectedCategory` survives the `.id()` remount through a binding. The new `NavigationPath` must as well, or changing the theme from inside Appearance throws you back to the root. P2 must spec this, and test43 covers it.
2. **Focus-driven explainer on tvOS `List`.** `\.isFocused` is only populated on the focusable control and its descendants, and custom rows (swatches, catalog rows, plugin rows, activation cards) are not built from `SettingsRowLabel`. They need the modifier path or they fall back to the pane summary. That is acceptable, but it must be decided per row in P2.
3. **The peek and Down-from-hero change the scroll mechanics that BUG-96/99/117 were tuned on.** The new decisions are isolated to the hero boundary, but the device pass must walk the first three rows in both directions.
4. **Two Detail layouts for 1–2 betas.** Classic must stay byte-identical, so W1-A is limited to the switch point. Deleting Classic later is its own small batch.
5. **Test churn.** About 25 UI tests change. Shared helpers are migrated first so individual tests change little. The simulator wedges after about 6 UI runs; plan the reboots.
6. **Translation quality** for about 140 new strings across 5 languages. Sonnet, the existing merge scripts, and a spot check of German on the device.
7. **Scope.** This is the biggest UI batch since beta.15's Settings rewrite. The two-part merge lets Detail ship if Settings slips.

## OUTCOME

### Wave 0 (2026-10-02)

- Release order: beta.19-rc1 was already cut (build 133 `5f2d5cd3`, sweep-1002 batch on top of `3f377cd8`) before this session started, so the branch was cut from that tip. Outer `main` got this plan via `--no-ff` merge `5a9cdbd`; the plan branch was deleted.
- Baseline on `5f2d5cd3`: `NuvioTVTests` 650 / 0; Debug + Release simulator builds green. UI legs test17/33/40/51/68/72: all 6 FAIL at launch ("profile picker never appeared"). The FA87 fixture came back from a shutdown signed in but with zero profiles and no network requests from the app (relaunch did not help). That is the fixture, not code (nothing on the branch yet). Diagnosis: the container prefs held `anonymous_user_id` and no session/profile keys, i.e. the fixture had been signed out onto an anonymous guest session. Workaround applied (BUG-38 guest-seeding recipe): a local-only `profile_payload` with one profile named "Chris" bound to the anonymous user id, written into the container plist (backup `/tmp/fa87-prefs-backup.plist`). The picker shows it and the harness's `app.buttons["Chris"]` matches; content is guest Cinemeta, not Christian's library. Re-signing FA87 into his account needs him (credentials). Baseline UI legs were not re-run on the guest fixture; Gate legs are judged per failure. FixtureSetupTests not run as a baseline: it writes the synced Poster Size / Hide Titles settings through the UI.
- Tracker: FEAT-35 and FEAT-28 marked in progress; new FEAT-50 (Settings re-sort + explainer) and FEAT-51 (spoiler-safe episodes). **FEAT-45 left as is:** it asks for an icon rail for the app's FEAT-30 navigation sidebar, not the Settings sidebar, so D6 does not answer it; the plan's "declined (D6)" reply text is wrong and needs Christian's call before any reply.
- Design: P1 spec `docs/research/detail-settings-revamp-spec-p1-detail.md`, P2 spec `docs/research/detail-settings-revamp-spec-p2-settings.md`; P3 critique pending. Spec-level resolutions taken by the main session: P1 key names (`DetailSettingsKeys`: `detail_layout`, `detail_section_*`, `detail_hide_episode_spoilers`) are canonical; P2 Q14 keeps "Account & Profiles" (D8); P2 Q15 Minimal root rows are title + subtitle, no icon, no explainer; P2 Q16 Detail row labels unchanged in this batch. D9/D10 asked and answered.


### Wave 1 (2026-10-02) — `53c1edc8`

- Three agents: W1-A Detail hero (Opus), W1-B Settings infrastructure (Opus, upgraded per F21f), W1-C spoiler-safe episodes (Sonnet). P3 critique folded into `docs/research/detail-settings-revamp-spec-corrections.md` first (2 P1 / 9 P2 / 10 P3).
- Main-session fixes: missing `import Combine` in `SettingsExplainerModel.swift`; one unit test assumed a ratings order the plan doesn't specify (non-leading sources keep MDBList order) and was corrected.
- Gate 1: Debug green, `NuvioTVTests` 686 / 0 (2 deliberate skips). Evidence via the new `RevampEvidenceTests` harness (`8928c440`), screenshots `docs/research/detail-settings-revamp-sim-evidence/g1-*`. Captures need `detail_trailer_autoplay = false` in the fixture prefs (else the full-screen trailer covers the page). Christian approved the Detail look as built; asked for Settings to match the option 1 mockup (D11).

### Wave 2 (2026-10-02) — `f5f15b1a`, `7d535bd0`, `ff6eb202`

- Four agents: W2-A Detail anchoring/About/section toggles (Opus), W2-V Settings visual pass (Opus), W2-B and W2-C pane split (Sonnet), then W2-D description copy (Sonnet, 148 rows, deslop 5/5, footnotes on 9 rows). Main session rewired the pane switch and deleted the four emptied pane files (AccountServices, Advanced, Playback, ContentSources).
- Gate-1 "3-line teaser" was NOT a bug: Cinemeta's own Dune description ends in "fu..."; the probe now reads `syn=126` (measured four-line slot), `trunc=0` correctly.
- Visual fix round 1 (`ff6eb202`): link rows show one chevron with a full-width platter, disclosure rows get the rest platter, native Menu pill left untinted with the rest platter raised to 9.5% white to match it.
- Gate 2: `NuvioTVTests` 701 / 0, no skips (description coverage tests run). Screenshots `g2-*`. Christian: "lock it" for Settings (2026-10-02).
- Carried into Wave 3: the focused picker row highlights light grey (not white); Hero Sources' inner toggles lack the switch look.

### Wave 3 + review round 1 (2026-10-02/03) — `4d232296`, `7bc66962`, `e3d2b04a`, `fd2cfefa`

- Translations: populate found 356 new keys; Sonnet translated ~347 per language (de/es/fr/it/vi), merged with zero specifier mismatches. Review r1 corrected "Detail Page" (was the mobile app's "Meta screen" wording), "Layout", "Look" and es "Player"; 12 stale keys removed.
- Visual fix round 2: focused picker rows no longer forced into a light scheme; Hero Sources and Catalogs rows use the switch + platter.
- UI legs (FA87, guest fixture, 4 batches + 2 reruns): final state for the 24 legs run — PASS test04, 05, 16, 17, 25, 29, 40, 43, 53, 79, 80, 81, 82, 83, 84, TabBarScrollLink 75/76; SKIP with explicit guest-data reasons test33 (no season posters), 35 (not signed in), 54 (no collection tile), 68 (no 6+ season shelf), 72 and 77-Play (Play disabled, no streams), 78 (no truncated synopsis), DetailRowAnchorTests (Play disabled changes the focus path). Not run: FixtureSetupTests/PinnedRowSettleRegimeTests (they write synced poster settings) and the long-tail Appearance legs (07/09/11-13/18/26-28/30/32/36/45), whose chip steps were already stale before this batch.
- App bugs the legs found and fixed: the switch ToggleStyle exposed an empty accessibility value (now explicit On/Off + toggle trait); the Settings root ignored `prefersDefaultFocus` inside a tvOS List on a cold entry and after the theme remount (now `@FocusState` + `.defaultFocus` + a one-shot landing correction).
- Gates on `fd2cfefa`: `NuvioTVTests` 708 / 0, Debug + Release simulator builds green.

**Review round 1 (Opus, read-only, Codex on its limit until 10-29)**

| # | Sev | Finding | Decision |
|---|---|---|---|
| D1 | P2 | Ratings slot could appear after first paint (gate waited for a tt id) | Fixed: reserved from settings alone |
| D2 | P2 | Series Play mounts late, `.defaultFocus` had no target | Fixed: one-shot late Play focus, never after user input |
| D3 | P3 | Start Over hidden for percent-only progress | Fixed |
| D4 | P3 | Aired-unwatched count recomputed per press | Fixed: cached per visit |
| D5 | P3 | `isAired` compared UTC timestamps to a local date | Fixed: full ISO-8601 parse |
| D6 | P3 | Actor-directors dropped from "With" | Fixed: leading crew run only |
| D7 | P3 | About focus animation ignored Reduce Motion | Fixed |
| D8 | P3 | Classic carries `.defaultFocus` | Accepted: Classic has nothing focusable above Play; documented here |
| D9 | P3 | Live settings changes re-render a mounted Detail | Accepted (focus re-resolves on return; device step 6) |
| D10 | P3 | Teaser could lose focus when re-measured | Fixed: flips to plain text only while unfocused |
| S1 | P2 | Focusable About rows showed no focus | Fixed: no-op Button with kit chrome |
| S2 | P2 | Explainer models observed by the List owners (re-render per focus move) | Fixed: held via `@State` |
| S3-5 | P3 | Wrong translations (Detail Page, Layout/Look, es Player) | Fixed |
| S6 | P3 | Stale catalog keys | Fixed (12 removed) |
| S7 | P3 | UI tests uncommitted at review time | Fixed (`fd2cfefa`) |
| S8 | P3 | One debrid hint still said "in Settings" | Fixed, translated |

Next: review round 2 over the fix diff, then the device pass.

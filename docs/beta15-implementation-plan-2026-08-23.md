# beta.15 implementation plan — task & model delegation (2026-08-23)

**Status (2026-08-23, same day): BUILT on NuvioMobile `claude/beta15` (from `e0b9ef9d`), not pushed, no
device pass yet.** Commits: `23079774` A1+A2 (Codex ×3), `8c375436` C0 spike, `552900f1` B1–B3
subtitle delay (Codex ×5), `e2855c70` C1/C2 kit+shell, `71f984b9` B5 tests (NuvioTVTests target),
`4a74ab9a` C3 all seven panes, `88582a6e` C4+C5 cleanup + test re-pointing, `c0632c41` stale-offset
fix from the final whole-branch Codex pass (clean at `c0632c41`) — see
§H "Build log" at the end. Last release `tvos-v0.3.0-beta.14.5` (build 112). Deployment target tvOS 26.0.

**Sources:** `docs/upstream-port-plan-2026-08-23.md` (the daily upstream diff), Christian's two
feature asks (subtitle sync offset; Apple-TV-app-style Settings), Apple HIG/SwiftUI docs for
tvOS (URLs inline), and the hardware-verified gotchas already recorded in this repo
(`docs/design/hig-hybrid-contract.md`, BUG-45/65/33 histories).

Three workstreams, in priority order: **A** upstream ports (small, mechanical), **B** subtitle
sync offset (the user-facing fix), **C** Settings revamp (the biggest UI change since the HIG
revamp). A and B can ship together early as beta.15; C is gated by a visual spike and may become
beta.15.5 if it slips — do not hold the subtitle fix hostage to the redesign.

## Delegation principles (token efficiency)

Same rules as the beta.14 plan, restated so this doc stands alone:

- **Fable (this session) plans, reviews diffs, and integrates. It does not grind.** Every
  token-heavy step below — exploration, code, tests, Codex loops, xcstrings sync — is delegated.
  Fable reads agent *summaries and diffs*, never whole files; it re-runs a task at a higher tier
  only on failure.
- **Haiku 4.5** — closed-list text transforms: xcstrings key sync, tracker/README/changelog
  flips, highlights draft, comms blocks.
- **Sonnet 5** — well-specified code with an in-repo pattern to copy. Most of A and B, and the
  mechanical half of C (row-by-row conversion once the component kit exists).
- **Opus 5** — design judgment with blast radius: the native-engine subtitle delay mechanism
  (B3), the Settings component kit + focus graph (C1/C2), final pre-push review of C.
- **Codex (GPT-5.x via `codex-companion.mjs review`)** — adversarial review after every wave,
  review→fix→re-review until clean (the beta.11/13/14 loop). Also used as the *second
  implementer* on B3 if Opus's spike and Codex's spike disagree — cheap insurance on the one
  item with real technical risk.
- **Christian** — every device pass (no automated input path to the physical Apple TV), the
  three decisions in §6, and the release cut.
- **Waves by file ownership, one build per wave, agents never commit.** No two concurrent agents
  in `MPVPlayerView.swift`, `SettingsView.swift`, or `Localizable.xcstrings`.

## A. Upstream ports (from the 08-23 daily check)

Everything new upstream since beta.14 is `composeApp/`-only (`git log HEAD..upstream/cmp-rewrite
-- shared/` is empty). Two items carry over as real work; the rest stay parked/no-action exactly
as the daily doc decided — this plan does not re-litigate them.

| # | Task | Upstream | Model | Spec |
|---|------|----------|-------|------|
| A1 | **Addon removal confirmation** | `faae0cd7` (addon half) | **Sonnet** | `iosApp/NuvioTV/Screens/AddonsView.swift:91` fires `model.remove(addon)` with no confirmation. Match the existing tvOS pattern — `.alert(_:isPresented:)` with a `role: .destructive` button + `Cancel`, exactly as `SettingsView.swift:88/94/132` and `ServerConnectionView.swift:75` do. **Do not** introduce `.confirmationDialog`; nothing in `Screens/` uses it. Hold the pending addon in `@State private var addonPendingRemoval: AddonSummary?`, alert title `"Remove \(name)?"`, body says it stops all its catalogs/streams. Two new xcstrings keys. |
| A2 | **Simkl anime-movie library cross-reference (delta only)** | `54aa75ea`/`9ae179d0` | **Sonnet** (Kotlin, `shared/`) | Upstream's `isMovie` now ORs in `isAnimeMovie = libraryEntries[id]?.animeType == "movie"`. tvOS's `shared/.../simkl/SimklProjections.kt` classifies via the session's `type == "movie"` marker (deliberate divergence, documented in-code as the Codex review of the `6e5e41f3` port). The research confirmed a real gap: an anime-movie session with **no `type` marker and a non-null `episode`** is misclassified on tvOS today. Port **only** the library-lookup OR clause; keep tvOS's `type == "movie"` check and keep the `episode == null` heuristic *out* (that's the divergence). Add one commonTest case for the missing-marker/non-null-episode shape. Update the in-code divergence comment to name both sources. |
| A3 | Pause-description staleness spot-check (`c4934bce`) | — | folded into **B** | tvOS's panel is app-drawn; B2's PlayerTopPanel work touches the same surface, so the Sonnet agent on B2 verifies the episode description row re-renders on next-episode autoplay (`NextEpisodeAutoPlay.swift`). No separate task. |

Supporter perks (`bd88760e`…`52e28562`) stays **parked**; subtitle min-font (`d50f84fc`) stays
**deferred** — but note B's new delay row and C's Playback pane are the "next player styling
pass" that item was waiting on: decide tvOS's own subtitle-size floor while B's agent is in
`PlaybackSettingsPane.swift` (see §6 Q3).

## B. Subtitle sync offset

### What actually exists (research, verified 2026-08-23)

- **mpv engine** (`MPVPlayerView.swift:48,63,191,880-896`): `sub-delay` and `audio-delay` are
  already wired. The UI is `Player/MPVPlaybackTab.swift:57` — `delayRow("Subtitle Delay",
  step: 0.5, limit: 30)` inside the **4th "Playback" tab** of the top panel. It is session-only
  (`MPVPlaybackState` is a fresh `StateObject` per `MPVPlayerView.init`, line 1433).
- **Native AVPlayer engine** (Dolby Vision / HDR MKVs when the Playback > native toggle is on):
  **no delay at all.** Subtitles are WebVTT renditions in the app-synthesized HLS master served
  by `LocalHLSServer.swift` (`SubtitleVTT.renditions`/`webVTT`, `NativePlaybackCoordinator.swift:416-429`),
  rendered by AVPlayer's own captions layer. There is no app-side time→cue lookup to hook.
  `NativePlayerPanelAdapter.swift` passes `extraTab: nil`, so the native panel has no Playback
  tab either.
- **Shared contract already compiled into SharedCore:** `PlayerTrackPreferenceStorage`
  (`shared/.../player/PlayerTrackPreferenceStorage.kt:24-26`, Apple actual in
  `PlayerTrackPreferenceStorage.apple.kt:63-80`, NSUserDefaults key
  `subtitle_delay_ms|<videoId>`, profile-scoped) with `loadSubtitleDelayMs(videoId)` /
  `saveSubtitleDelayMs(videoId, delayMs)` — callable from Swift today, zero new Kotlin.
  Constants in `SubtitleAudioModels.kt:35-38`: `SUBTITLE_DELAY_MIN/MAX_MS = ∓60_000`,
  `STEP_MS = 100`, `AUTO_SYNC_REACTION_COMPENSATION_MS = 300`. Upstream mobile also has an
  "auto-sync" gesture (`PlayerScreenRuntimeSubtitleActions.kt:51-64`: capture the moment the
  user hears a line, then pick the cue that should have been showing → delay computed).

So the user-visible problem is three things: the control is **undiscoverable** (wrong tab, mpv
only), it **forgets** every session, and it's **absent on the native engine**.

### Tasks

| # | Task | Model | Spec |
|---|------|-------|------|
| B1 | **Subtitle Delay row in the Subtitles tab, both engines, persisted** | **Sonnet** | Move/duplicate the delay control out of `MPVPlaybackTab` into `Player/PlayerSubtitlesTab.swift` under a "Timing" caption (the subtitle tab is what a user opens when subs are off). Control = one row: `[−1s] [−0.1s]  +0.00 s  [+0.1s] [+1s]  Reset`, D-pad friendly (five focusable chips, `PlayerChipStyle`), monospaced value, range ±60 s to match `SUBTITLE_DELAY_*_MS`; step 0.1 s per press (mobile parity) with the ±1 s coarse chips for remote ergonomics. Accessibility ids `player.panel.subtitleDelay.{minus1,minus,value,plus,plus1,reset}`. Behaviour contract: `onChange` → engine setter (mpv: existing `setSubtitleDelay`; native: B3's hook) **and** `PlayerTrackPreferenceStorage.shared.saveSubtitleDelayMs(videoId:, delayMs:)`; on player init `loadSubtitleDelayMs(videoId:)` → apply before first frame. Keep `MPVPlaybackTab`'s audio-delay row where it is; remove its subtitle row (one source of truth). Localize new strings. A3's description-staleness check rides along. |
| B2 | **Persistence + reset semantics** | **Sonnet** (same agent as B1, same files) | Key = `context.videoId` (`PlaybackModels.swift:34`) — per title/episode, per profile, like mobile. Reset writes 0 (not delete) so "I reset it" survives relaunch. Add the stored value to the Stream Info overlay line so device passes can read it without the panel. Wipe: confirm `PlayerTrackPreferenceStorage` keys are already covered by the account-data wipe registry (`core.account.AccountDataStores`) — if not, **stop and report**, do not add a cleaner. |
| B3 | **Native-engine delay mechanism (the risky one)** | **Opus** designs + implements; **Codex** `adversarial-review` with focus "AVPlayer HLS subtitle re-timing" before the diff is accepted | Two candidate mechanisms, **spike both in ≤1 day, pick by evidence**: **(a) Re-timed renditions** — on delay change, regenerate the rendition's WebVTT with shifted cue times (`SubtitleVTT.webVTT` gains a `offsetMs` parameter; clamp at 0; keep `X-TIMESTAMP-MAP`), serve it under a new cache-busting path from `LocalHLSServer`, and force AVPlayer to refetch by flipping the media selection to a twin rendition (master lists each subtitle twice, A/B, same NAME+LANGUAGE, one `AUTOSELECT=NO`); the Subtitles tab toggles A↔B on each delay change. Keeps AVPlayer's styling/menus intact. Risk: AVPlayer caching the media playlist — measure with `read_network_requests`-style logging on the local server. **(b) App-drawn overlay** — `AVPlayerItemLegibleOutput` is *not* usable (it delivers already-timed cues); instead keep the parsed cues (the app already parses SRT/VTT in `SubtitleVTT.swift`) and draw them in a SwiftUI overlay driven by `addPeriodicTimeObserver(0.1s)` with `currentTime + offset`, deselecting AVPlayer's rendition when offset ≠ 0. Risk: must replicate `SubtitleStyleState` styling (font scale, background, SDH strip) — the renderer would become the third subtitle styler in the app. **Decision rule:** ship (a) if the refetch is reliable within one segment boundary on hardware; otherwise (b), scoped to *external/addon* subs only (embedded text tracks stay on AVPlayer, no delay — documented). Either way the mpv path is untouched. |
| B4 | **Auto-sync (stretch, only if B3 lands early)** | **Sonnet** | Port upstream's gesture: "Mark now" chip captures `currentTime`; the tab then lists the 5 nearest cues (text excerpts) — pick one → `delay = captured − cue.start − 300 ms` (`SUBTITLE_AUTO_SYNC_REACTION_COMPENSATION_MS`). Needs B3(b)-style access to parsed cues on both engines (mpv: `sub-text`/track data via `mpv_get_property` of the loaded file we wrote to temp — we own the file, parse it). Skip if B3 picks (a) and cue access isn't free. |
| B5 | **Tests** | **Sonnet** | XCUITest: extend `NuvioTVUITests/PlayerTopPanelProbeTests.swift` — open Subtitles tab, press +1 s twice, assert value label `+2.00 s`, relaunch player (same videoId via the `debug.mpvSmokeURL` harness), assert the value restored. Native path: same under the remux harness (`tvos-remux-verification` workflow). Unit: none exist for `SubtitleVTT`; add a first `SubtitleVTTTests` target with the cue-shift/clamp cases from B3(a) — small, and it's the seam most likely to regress. |

### Verification (Christian, device)

Two titles with known drift (pick one addon-sub movie on mpv, one DV MKV on native). Adjust until
lips match, back out to Home, replay → delay restored; switch profile → delay is 0 for that
profile. Screenshot-scan the subtitle surface (never trust logs alone — BUG-59 lesson).

## C. Settings revamp — "looks like the Apple TV app"

### What "like the Apple TV app" means on tvOS 26, concretely

Apple's own TV app on tvOS 26 uses a **Liquid-Glass floating sidebar** (`TabView` +
`.tabViewStyle(.sidebarAdaptable)`, "macOS and tvOS always show a sidebar"; refracts the content
behind it) for top-level navigation, and its **settings live in the system Settings app** as
native grouped lists: a plain dark canvas, full-width rows that **highlight, grow slightly and
round on focus** ("don't add your own corner masks" — HIG Lists and tables), section
headers/footers in Caption text, toggles/pickers as trailing values, and pushed sub-lists for
choices. Sources: HIG Split views
(https://developer.apple.com/design/human-interface-guidelines/split-views — 1/3 : 2/3 default,
one title for the whole split, never per pane), HIG Sidebars
(https://developer.apple.com/design/human-interface-guidelines/sidebars — two levels max, SF
Symbols, don't hide by default), `sidebarAdaptable`
(https://developer.apple.com/documentation/swiftui/tabviewstyle/sidebaradaptable), `List`
(https://developer.apple.com/documentation/swiftui/list — "use List for settings/sidebars"),
typography (https://developer.apple.com/design/human-interface-guidelines/typography — Body 29,
Caption1 25, Caption2 23, nothing below 23), layout safe zone 60/80
(https://developer.apple.com/design/human-interface-guidelines/layout). **As of August 2026** —
confirm on Apple's pages before relying on exact wording.

### What we have (research, verified)

`SettingsView.swift` (267 lines) is a hand-rolled two-column `HStack` — sidebar `width: 460`,
detail `ScrollView` `maxWidth: 1500`, each in a `.focusSection()`, categories activate on focus.
Every row is a custom `Button` + `SettingsRowButtonStyle` (`DesignSystem/FlatControlStyles.swift:48-88`,
whose own comment says "pending the native List conversion"); toggles are fake
(`checkmark.circle.fill` glyphs, `SettingsRowViews.swift:153-155`); language choice is a chip
row (`LanguageSelectRow`, `:240-267`), which the field notes call out as the anti-pattern versus
`Menu { Picker }`. No `prefersDefaultFocus`. Seven panes, 3,500 lines of pane code, nine files.
Two shipped focus bugs live in this code (BUG-45 sidebar label colour, BUG-65
`settingsRowIsFocused` environment hack) plus the BUG-33 contrast class — all symptoms of
hand-drawing what the system draws for free. The hybrid contract
(`docs/design/hig-hybrid-contract.md`) already says system styles only; this is the conversion it
anticipated.

### Design decisions (recommended; Christian confirms in §6 Q1/Q2)

1. **Keep the two-pane split; make both panes native `List`s.** Not `NavigationSplitView` (it
   collapses to a single stack on tvOS), not a nested `sidebarAdaptable` `TabView` (Settings is
   already a tab of the app's top-level TabView; nesting two sidebar systems is untested and the
   known ≥8-item focus-restore bug is Apple-acknowledged). Left: `List(selection:)` of categories
   (tvOS 16+ selection binding), ~1/3 width, SF Symbol + label, activate-on-focus retained
   (native Settings does this) but with `prefersDefaultFocus` inside a `focusScope` so a long
   walk can't strand focus in the detail pane. Right: `List` with `Section(header:footer:)`
   groups — no `ScrollView`, no custom row buttons.
2. **System controls, no fakes.** `Toggle` (real switch, system platter), `Picker` presented via
   `Menu { Picker }` (radio-checkmark popup, the native dropdown), `LabeledContent` for
   value rows, `NavigationLink` rows for sub-pages (Debrid keys, server connection, addon list),
   `Button(role: .destructive)` + `.alert` for sign-out/disconnect (already the pattern).
   Delete `SettingsRowButtonStyle`, the `settingsRowIsFocused` environment key, the
   checkmark-glyph toggle, and the chip row. The BUG-45/65 workarounds go with them.
3. **Glass only where Apple puts it.** The app's tab bar already gets Liquid Glass from the
   system. In Settings, glass is limited to popovers/menus the system draws; the list canvas is
   the plain dark background with `Theme.Palette` tokens — Apple TV 4K 1st gen and HD render
   no glass, so nothing may *depend* on it (contract rule).
4. **Type:** row title Body 29, row subtitle Caption1 25 secondary, section headers Caption2 23
   uppercase-free (HIG), one page title ("Settings", Title3 48) above the split. Nothing under 23.
5. **Information architecture stays** — the seven `SettingsCategory` cases and their contents
   are unchanged; this is a presentation conversion, not a reshuffle. (If Christian wants
   regrouping — e.g. About → bottom, Advanced merged — that's a §6 Q2 answer, then a Haiku
   edit to the enum order/labels.)

### Tasks

| # | Task | Model | Spec |
|---|------|-------|------|
| C0 | **Visual spike (gate for everything below)** | **Sonnet** builds; **Christian** judges on hardware | A throwaway `SettingsKitPreview` screen behind `DebugConfig` showing: `List(selection:)` sidebar + `List` detail with two `Section`s, a real `Toggle`, a `Menu{Picker}` row, a `LabeledContent`, a `NavigationLink` row, a destructive `Button`. Build, sim screenshot, then **device screenshots in both focused/unfocused states** (the sim doesn't render the lift/platter). Question it answers: does the stock tvOS 26 `List` look like Settings.app out of the box, and how does focus travel between the two lists? If the answer is "yes, with ≤2 modifiers", C1–C4 proceed; if it needs a custom row style again, **stop and re-plan** — we are not rebuilding `SettingsRowButtonStyle` under a new name. ~150 lines, deleted at the end. |
| C1 | **Settings component kit** | **Opus** | Replace `Screens/Settings/SettingsRowViews.swift` with a kit built *only* from the C0-proven primitives: `SettingsToggleRow`, `SettingsPickerRow<T>` (Menu+Picker), `SettingsValueRow`, `SettingsLinkRow`, `SettingsDestructiveRow`, `SettingsSection`. Same call-site signatures where possible so C3's conversion is mechanical. Document the focus graph (default focus, Up/Down/Left/Right exits per pane, the empty/error states — every pushed sub-page keeps a focusable control, BUG-47 class). Sketch the focus graph *before* code (skill workflow step 1) and put it in the PR description. |
| C2 | **Shell conversion** | **Opus** (same agent as C1) | `SettingsView.swift`: sidebar → `List(selection: $selectedCategory)` inside `focusScope` + `prefersDefaultFocus`; detail → `List` per pane; single page title; remove `focusedCategory` plumbing and the BUG-45 label-colour special case; keep "only the selected pane is built" (`switch selectedCategory`) for perf. Verify Menu pops exactly one level (back to the tab bar at the root). |
| C3 | **Pane conversion, 3 agents by file ownership** | **Sonnet ×3**, sequential builds | Wave C3a: `PlaybackSettingsPane` + `AppearanceSettingsPane` (860 lines; includes `StreamBadgesSection`). Wave C3b: `AccountServicesSettingsPane` (687; Trakt/Simkl/Debrid/server sub-flows → `NavigationLink` pages; `DebridKeyEntryRow` keeps `TextField`, drops its hand-rolled `glassEffect` chrome). Wave C3c: `HomeScreenSettingsPane` + `ContentSourcesSettingsPane` + `AdvancedSettingsPane` + `AboutSettingsPane` (1,020). Each agent: row-for-row swap to the C1 kit, no behaviour changes, no new strings unless a chip row becomes a picker (label text survives). Report any row that *can't* map to a kit primitive instead of inventing one. |
| C4 | **Cleanup + contrast sweep** | **Sonnet** | Delete `SettingsRowButtonStyle`, `settingsRowIsFocused`, `LanguageSelectRow`, `C0`'s preview screen. Grep for remaining raw-palette-on-platter sites in Settings (the BUG-33 class) — there should be none once labels use semantic colours under the system platter. Update `docs/design/hig-hybrid-contract.md`: the "pending native List conversion" exemption is closed. |
| C5 | **Tests** | **Sonnet** | Re-point `test04SettingsRows`, `test05SettingsGerman`, `test16SettingsNewRows`, `test18FocusedSettingsRowLegibility`, the UX-8 Discover-hide test and `ScratchServerSwitchTests` at the new accessibility ids (keep ids stable where the old ones were meaningful). Add one walk: Settings default focus → Down×7 → Right → first detail row → Menu → back on the sidebar, not out of the app. Remember the 27.0 runtime never reports `hasFocus` — existence-driven assertions only. |
| C6 | **Codex loop** | **Codex** | `codex-companion.mjs review --wait` after C2, after each C3 wave, and `--base <pre-C0-sha> --scope branch` at the end. Known hot spots to name in the focus text: focus escaping between lists, Menu exiting the app from an empty `NavigationLink` page, `Toggle` bindings that used to be fire-and-forget Buttons (double-toggle on select+focus). |

### Verification (Christian, device — the sim is worthless for this)

Walk every pane with the Siri Remote (swipes, not just clicks): focus platter look vs
Settings.app side by side, label legibility on the white platter, picker menus open and close
with Menu, no focus strands in either list, Reduce Motion on, VoiceOver reads each row. Both
Apple TV 4K (glass) and, if available, an HD/1st-gen (no glass).

## D. Sequencing

```
Wave 0  A1, A2, C0                      (parallel: 3 files, 3 agents, no overlap)  → build, Codex
Wave 1  B1+B2 (one agent), B3 spike     (mpv files vs native files — disjoint)      → build, Codex
Wave 2  B3 implementation, B5            → device pass #1 (subtitles)    ┐
Wave 3  C1+C2 (Opus)                     ← gated on C0 verdict           │ could cut beta.15 here
Wave 4  C3a → C3b → C3c (sequential)                                     │ with A + B only
Wave 5  C4, C5, C6 final Codex           → device pass #2 (Settings)     ┘
Wave 6  Haiku: README features/screenshots, highlights, Reddit block, tracker flips; release cut
```

Budget sketch (agent tokens, rough): Wave 0 ~250k, B ~600k (B3 spike is the swing), C ~1.2M
across Opus kit + 3 Sonnet waves + Codex rounds, Haiku comms ~50k. Fable stays under ~150k for
review/integration if summaries are kept to diffs. Per the cost-guardrail memory: **no fan-out
above 3 concurrent agents without asking**, and no `claude -p` harness loops.

## E. Release gates (unchanged from beta.14's §8, plus)

1. All three XCUITest additions green on the signed-in 27.0 sim clone.
2. Codex clean (`--base` re-review of the whole branch).
3. Device pass #1 and #2 signed off by Christian with screenshots in `docs/device-pass-beta15/`.
4. README features + screenshots updated *before* `scripts/release-beta.sh` (script enforces).
5. `docs/upstream-port-plan-2026-08-23.md` open items A1/A2 marked landed; CLAUDE.md status block
   updated; `PlayerTrackPreferenceStorage` wipe coverage confirmed (B2).

## F. Decisions needed from Christian

- **Q1 (C, blocking C1):** Two-pane `List` + `List` (recommended, §C design decision 1) — or try
  a nested `sidebarAdaptable` TabView for the Settings pane and accept the untested nesting?
- **Q2 (C, non-blocking):** Keep the seven categories and their order as-is, or regroup? Any
  rows to drop while we're touching every one?
- **Q3 (B, non-blocking):** Subtitle delay step — 0.1 s fine + ±1 s coarse chips (recommended),
  or keep the current 0.5 s single step? And: settle tvOS's subtitle minimum font size in the
  same Playback pane pass (the deferred `d50f84fc` item) — propose a floor of 23pt-equivalent
  per HIG rather than upstream's 6sp.
- **Q4 (B3):** If neither native mechanism is reliable on hardware within the spike day, ship
  beta.15 with delay on mpv only + "Use mpv for this stream" hint on native, and carry native
  delay to beta.16? (Recommended yes — don't block the fix most users hit.)

## G. Explicitly out of scope

Supporter perks (parked), subtitle min-font *as upstream shipped it* (deferred; see Q3), Simkl
Settings parity items (separate beta). ~~Any change to the app's top-level tab bar, BUG-30/66
tab-bar investigation (awaiting device data)~~ — **amended 2026-08-23 evening:** the device data
arrived (mrStevenx3's diagnostics photos, via DM) and decoded fully; the tab-bar work moved IN
scope as batch 2 (see §I).

## H. Build log (2026-08-23)

- **Wave 0** — A1 addon-removal `.alert` (+ the context-menu path), A2 Simkl library
  cross-reference. Codex found two real defects in A2 across three rounds: promoted anime
  movies kept S01E01 coordinates (now nulled for every movie), and the library fallback could
  override an explicit `type == "episode"` (now untyped sessions only). 137 Simkl jvm tests.
  C0 spike verdict on the sim: stock `List` = Settings.app look; **plain `Label` rows in
  `List(selection:)` are not focusable on tvOS — rows must be `Button`s** (+ `.focused` for
  activate-on-focus). `Menu{Picker}+LabeledContent` renders the native pill + glass popover.
- **Wave 1** — B1/B2 as planned. **B3 finding that changed the design:** AVPlayer refetches a
  subtitle rendition's VTT *body* on every (re)selection but caches its media playlist for the
  item's life, so the twin-rendition A/B flip was unnecessary (and harmful — each slot freezes
  to the body it first saw). Shipped mechanism = server-side re-timed VTT + Off→same-option
  reselect (60 ms, debounced 350 ms); new timing in force by the next cue; persisted delay
  applied before first frame. Embedded text tracks not re-timed (row hides). Codex 5 rounds:
  tab-delimited cue settings, native Stream Info readout, cancellable restore task (not
  `selectionVersion`-guarded — our own `select(nil)` bumps it asynchronously), and
  `isRefetchingSubtitles` so the focused Timing row stays mounted during the hop.
- **Wave 2/3** — B5: 9 `SubtitleVTT.shift` unit tests in a new hosted `NuvioTVTests` target
  (pbxproj +110 lines, additive) and `SubtitleDelayProbeTests` (value walk + relaunch
  persistence) both green. ⚠️ Toolchain: `TEST_RUNNER_*` env-var pass-through is silently
  broken on this Mac/Xcode — the pre-existing probe tests skip too; B5 used a
  `build-for-testing` + PlistBuddy-edited `.xctestrun` workaround. Needs a look before the
  next harness run. C1/C2: kit + shell, built first time, focus graph in the SettingsView
  header; sidebar `max(400, width/3)`.
- **Wave 4** — C3a/b/c ran in parallel (disjoint files, one build): −240 net lines, zero
  compile errors, Codex clean. Left custom by design: theme/text-colour swatches, badge-pack
  rows, URL/key entry forms. Self-hosted server flow is now a `NavigationLink` push from
  Settings (still a cover from Welcome). Sim walk of all seven panes OK. Observation for the
  device pass: pressing Down from the *tab bar* lands on the nearest detail row (Sign Out in
  Account), not the sidebar — `prefersDefaultFocus` only governs first entry; decide on
  hardware whether to pin it.
- **Not done / owed:** device pass #1 (subtitles — confirm `[HLS] 200 sub-N.vtt` per change,
  screenshot-scan captions, blink on the hop) and #2 (Settings — platter/lift on hardware,
  swipes, both glass and non-glass boxes); README/screenshots/highlights (Wave 6); push.

### Wave 5 addendum (C4/C5, end of day)

- C4: spike deleted, disclosure groups on system styles, Settings/ grep-clean of the legacy
  style identifiers; `rowTextColor` moved (not deleted) to FlatControlStyles — five non-Settings
  screens still use `.settingsRow` (beta.16 candidate, listed in the hybrid contract).
- C5: Settings XCUITests re-pointed. Facts that cost real debugging: real `Toggle`s resolve
  as `.switch` OR `.toggle` (query `descendants(.any)` by label); on native Lists the Focused
  trait sits on the wrapping **Cell**, never the inner control; List laziness means far rows
  don't exist until walked to; toggle state is `.value` OR a label suffix. Green: test04/18/40.
- **Punch list for the device pass:** (1) `test16` is red on the FA87 fixture only because the
  signed-in profile's **synced `accent_focus_ring` is ON** — left by automated runs; flip it
  off in the app (this also affects the real living-room device via sync). Local
  `defaults write` cannot fix it — the cloud pull clobbers it. (2) `test30`'s Appearance walk
  is flaky on the native List (arrival detection); (3) test07/09/12/13/27 CardSettings audits
  need Menu{Picker}-interaction rewrites; (4) `TEST_RUNNER_*` env pass-through broken on this
  Mac (PlistBuddy-edited `.xctestrun` workaround in B5's doc comment).
- Final whole-branch Codex (`--base e0b9ef9d --scope branch`): one real find (stale captured
  `offsetMs` if the delay changes during the initial 10 s VTT download) → fixed `c0632c41`,
  re-review clean. Gates re-run at `c0632c41`: Simkl jvm suites green, NuvioTVTests 9/9.

### Device pass #1 — subtitles (2026-08-23 evening, Living Room Apple TV, build from `c0632c41`)

**CORE RESULT: PASSED — Christian: "subtitle delay works."** Console-verified over a full
native-engine session (16 addon renditions): every adjustment (+100 ms, cumulative +1.1 s/+2.1 s,
negatives to −4.2 s, a debounced −5 s walk, Reset-to-0) logged
`[NativePlayer] subtitle delay Nms applied (reselect …)` followed immediately by a fresh
`[HLS] 200 sub-0.vtt` — **hardware AVFoundation refetches the VTT body exactly like the sim**;
the twin-slot fallback stays off. A seek re-pulled the shifted body (delay held). Consecutive
presses kept panel focus (mount-guard working). No crashes.

New punch-list items from the pass:
1. **Duplicate re-apply, low priority:** twice the same value re-applied back-to-back
   (−600 ms, −4.2 s) → one redundant reselect/blink each. Trace what re-triggers
   `forceSubtitleRefetch` with an unchanged value (suspect: panel rebuild or the debounce task).
2. **Late addon subs lose the session (pre-existing, now more visible):** a session whose addon
   subtitle fetch missed the 8.1 s gate started with 0 renditions; subs "arrived after master —
   too late this session". With the delay feature making subs more valuable, consider a
   master-rebuild/retry on arrival — beta.16 candidate.

**Still owed:** replay-persistence spot-check on device (restore line at launch), mpv-engine
spot-check, profile-isolation check, and all of device pass #2 (Settings walk + flip the synced
Accent Focus Ring OFF in Appearance). Deploy recipe: Debug-appletvos build UUID `303A92F3`,
`devicectl device install app` to `C11A7D65-…`, console tap =
`devicectl device process launch --console` piped through the `[HLS]|[NativePlayer]` grep.

## I. Batch 2 (2026-08-23 evening) — mrStevenx3's 08-22 DM report

Full plan in `~/.claude/plans/lets-make-a-plan-cozy-pebble.md`; tracker rows BUG-30/41/66 updated
+ new BUG-71/72/73. Five issue clusters, all landed on `claude/beta15` the same evening, every
wave built green and Codex-gated (waves: 8 commits P/H-2 → 5 commits T → 3 commits H → hoist →
P-3+tests; Codex found 1 P1 in wave 1, 2 P2 + 2 P2 in wave 3, and 4 successive P1s in wave 4's
hoist — all fixed, final rounds clean):

- **P (trailer/detail/poster):** no-trailer flash killed (never-morph-on-speculation: peek
  pre-check `afacc8bb`, ticket-before-morph `311e4096`, morph-after-meta `01f60618` + focus-loss
  guard `53829a7d`; `debug.trailerForceNoTrailer` knob `f3ca70ab`); BUG-41 instrumented honestly
  (probes behind `debug.detailScrollProbe` `0a348667`, four-leg `debug.detailScrollAB` `891c80bc`,
  dim 0.05+interpolation `c0bc0cbd`); pinned-title re-seed on poster-style change (P-3, last
  commit, first-revert candidate).
- **H (hero + label):** BUG-72 label removal `10f8db4d`; probe fidelity `10d64813`; same-title
  paint suppression `51fbf363` + `79cfad05` + `d97b5e33`; sync no-op suppression `587d6bfa`
  (6/6 jvm tests); HomeViewModel hoist `b1b03b98` + `8f45ed40` + `0e289173` + `e9f458f9`
  (@State root ownership, profile-guard resets, published-content clears, pipeline generation
  token — the 4-round Codex ladder).
- **T (tab bar):** sign fix + y/i/r pane `c7e858ff`; shared-state retirement `9634b0c5`;
  publish-storm decoupling `569d3ca4`; uniform declarations `a02f2075`; hard-edge A/B toggle
  `af232e12`. No new fix for the BUG-30 clip itself (banned rounds honored; the corrected pane
  finally measures it).

**Batch-2 tail (2026-08-24 early AM, probe-verified live on the FA87 sim):** the new probe caught
the boot remount in the act — `theme CRIMSON→OCEAN` at 3.1s (profile-scoped theme key resolves
only at profile entry; `AppThemeModel` seeded "CRIMSON") → release/stop/acquire/start on the
hoisted model, every single launch. Fixes: repo-seeded `AppThemeModel.init` + synchronous
`reseedNow()` in `onSelected` before `entered` flips (`55c7b8cb` + `c264c4d1`, new shared
`currentThemeName()` accessor); About pane gained a `hero_probe_blob` single-Text AX probe (the
List row clips children out of the AX tree; `.combine`+value did NOT surface on tvOS 26.5);
test31 re-pointed at the blob, time-windowed, + a boot-window theme-flip tripwire. **test31 now
GREEN: one `vm start`, zero remounts.** Also observed in the capture: a tab switch to Settings
now DOES fire `HomeView.onDisappear` (release→stop at 20.2s) — the T3 prunable subtrees changed
that lifecycle; the refcount handles it correctly but the old "only on shell teardown" doc claim
is stale. Suite: NuvioTVTests 10/10; test03/15/17/41 green; test42 loud-skips on the signed-in
fixture (needs a guest container). Final whole-branch Codex (`--base c0632c41`): clean at
`c264c4d1` (rounds found: wave-1 focus-loss P1, wave-3 P2×4, wave-4 P1×4, final refocus P2 — all
fixed).

**Device pass punch list (batch 2, on top of §H's owed items):** (1) forced no-trailer leg (10
cards, nothing morphs) + natural + refused-slot legs + cold-meta morph-delay feel check (revert
`01f60618` alone if sluggish); (2) detail A/B legs 0–3 ranked blind → BUG-41 attribution; (3)
tab-bar recipe A–E (pane photos at top + deep; Home⇄Settings ×10 reading `i`; 5× push/pop →
`cycles=5`; FEAT-25 audio mute on tab switch); (4) hero probe photo after 60s cold launch (one
`vm start`, one `first=1`, no `theme →` after start) + fast CW↔catalog focus-hop art check;
(5) labels gone on hero + folder page, folder-name fallback intact; (6) poster Size flips clean
first frame. Ask Steven for his no-trailer repro title; his re-photos of both panes after
updating are the wild confirm.

## J. Consolidated device pass (2026-08-27) — everything owed, one sitting

Build under test: `claude/beta15` @ `c77e9caa` (beta.15 batches 1+2 + sync-reliability + BUG-75
batch + 08-26 upstream ports, Codex clean ×13). **Deploy blocked 2026-08-27: Xcode has no
signed-in account ("No Accounts") — Christian signs into Xcode → Settings → Accounts, then
rebuild Release with `-allowProvisioningUpdates` and gate on a FRESH `dwarfdump --uuid` +
`NuvioCommitSHA = c77e9caa` before installing (two cached no-op builds shipped the 08-20
binary with stamp `9a83122f` this morning — the UUID gate caught it).**

Ordered for one walk (sources: §H owed items, device pass #1 follow-ups, §I batch-2 punch list,
BUG-75/upstream new items):

**Leg 1 — launch + profiles (5 min)**
1. Cold launch → profile picker renders, pick Chris. (New: coordinator arms at launch — no
   visible change expected; a hang/crash here is the regression signal.)
2. Profile switch to KT and back — Discover state resets, no cross-profile leak (new
   `SearchRepository.reset()` in the switch fan-out).

**Leg 2 — BUG-75 / Continue Watching (10 min)**
3. Home CW row: content should now match mobile's row for the same source (limit 300 parity,
   dropped-show filter, days-cap window). Side-by-side with the phone: same titles, same order
   (mobile's next-up entries excluded — tvOS has no Up Next by design).
4. Settings → Content Sources: flip Watch Progress Source (e.g. Trakt→Simkl) → row swaps
   without relaunch. Flip back.
5. Cross-device: change the source on the PHONE → tvOS foreground-refresh → row follows within
   one pull (the new shared-namespace sync; this is the BUG-75 reporter's exact scenario).
6. Top Shelf: back out to the tvOS home screen — shelf mirrors the in-app row (capped ~20).

**Leg 3 — Discover persistence (3 min)**
7. Search tab → pick a NON-default Discover catalog → force-quit → relaunch → same catalog
   selected (new persistence; pre-fix it always reset to first).

**Leg 4 — subtitles follow-ups from device pass #1 (10 min)**
8. Replay-persistence spot-check: set a delay, exit playback, replay same title → restore line
   at launch, delay still applied.
9. mpv-engine spot-check: same Timing row works under mpv.
10. Profile isolation: delay set under Chris does not appear under KT.
11. Watch for the duplicate re-apply blink (known, low priority — just note frequency).

**Leg 5 — Settings pass (= owed device pass #2) (15 min)**
12. Full Settings walk on the native List: platter/lift on hardware, swipes, focus lands sane
    on entry per pane; check both glass and non-glass boxes if available.
13. Appearance: FIRST flip the synced Accent Focus Ring OFF (fixture left it ON — syncs to
    this device; local defaults-write cannot fix it). Then theme accent picker: category
    survives, glyphs/picker values tint with accent (the 08-25 SettingsAccentTint fix).
14. Simkl: add an ANIME to a list (watchlist/plan-to-watch) → verify it projects as anime, not
    show (new list-mutation port + repair precedence: a pre-fix misclassified entry should
    self-correct on the next list touch).

**Leg 6 — batch-2 trailer/tab-bar items (§I list, 15 min)**
15. Forced no-trailer leg (10 cards, nothing morphs) + natural + refused-slot legs; cold-meta
    morph-delay feel check (revert `01f60618` alone if sluggish).
16. Detail A/B legs 0–3 ranked blind → BUG-41 attribution.
17. Tab-bar recipe A–E (pane photos top + deep; Home⇄Settings ×10 reading `i`; 5× push/pop →
    `cycles=5`; FEAT-25 audio mute on tab switch).
18. Hero probe photo after 60 s cold launch (one `vm start`, one `first=1`, no `theme →` after
    start) + fast CW↔catalog focus-hop art check.
19. Labels gone on hero + folder page, folder-name fallback intact; poster Size flips clean
    first frame.

Sign-off → screenshots into `docs/device-pass-beta15/`, then the release wave (README /
screenshots / highlights / cut) unblocks.

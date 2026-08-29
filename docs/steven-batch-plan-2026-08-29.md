# Steven's beta.15 feedback batch — investigation + fix plan (2026-08-29)

Source: u/mrStevenx3's 10-item DM list (2026-08-28) + his 5m08s video (`~/Downloads/IMG_8428.mp4`).
Beta.16 already fixed: the account addon wipe, Settings sidebar icon spacing, header platter
clearance. This plan covers the rest. Model delegation per the agent-delegation playbook: Sonnet
executes exact specs, Explore for read-only sweeps, specs + verification + Codex loops stay in
the main session, waves by file ownership, no concurrent builds.

## Diagnosed: the "blank catalog selection" cluster (video + code trace, 2026-08-29)

Two independent defects compound:

**(a) Data clobber — `definitions` wiped by an unguarded writer.** `HomeCatalogSettingsUiState.items`
derives ONLY from in-memory `definitions` (never from disk; `ensureLoaded()` restores preferences
only). `SettingsViewModel.swift:172-179` calls `syncCatalogs(enabledAddons)` with NO manifest
filter and NO empty guard — any empty/pending-manifest `AddonRepository` emission (initialize()
pre-refresh, pullFromServer's never-seen-URL pending rows, profile change, wipe, removeAddon)
zeroes the singleton's definitions → pane blank. `HomeViewModel.onAddonsChanged` has all three
guards — which is why Home keeps working while the pane blanks (the reported asymmetry).
Permanent because SettingsViewModel never calls `AddonRepository.initialize()` (H2), and our
beta.16 seed gate WIDENS the window for signed-in fresh installs (H5: no early Cinemeta seed to
repopulate definitions).

**(b) Render/focus death — white-on-white + stranded focus.** Video frames 3:35/3:49: the
expanded catalog group renders as a giant white platter with no legible rows, and a focused
toggle row's label is near-invisible on the platter. Two mechanisms: the BUG-65 device-only
class (`\.isFocused`-driven label colors die inside custom containers ON HARDWARE ONLY — sim
renders fine, which is how every sim gate missed it), and H4: `HeroSourcesGroup`/
`HomeCatalogsGroup` are animated `ForEach`s inside ONE List row — a shrinking `items` vanishes
every focusable child under focus (BUG-47 class) → dead white screen (his "removing a catalog →
big white screen").

**(c) Sync wedge (H3, beta.15 regression):** `HomeCatalogSettingsSyncService.pullFromServer`
now throws on fetch/parse failure and skips `markInitialPullComplete` → `triggerPush` wedged for
the session (silently — runStep swallows). Legacy-platform fallback + newest-wins merge were
also dropped. Plus the audit's #2: `completedInitialPull` never cleared on account wipe.

## Wave 1 — catalog-pane cluster (specs ready; 4 Sonnet agents, disjoint files)

- **A. SettingsViewModel.swift** — mirror HomeViewModel's three guards before `syncCatalogs`
  (manifest != nil filter, empty-skip); call `AddonRepository.shared.initialize()` in `start()`.
- **B. HomeCatalogSettingsRepository.kt** (+ commonTest) — `syncCatalogs` refuses to replace a
  non-empty `definitions` with an empty list (last-known-good retained; log). Closes the class
  for every present/future caller.
- **C. HomeCatalogSettingsSyncService.kt** (+ test) — wire `clearAccountState()` (null
  `completedInitialPull` + cached blob) into the wipe cascade via `ProfileSettingsSync.clearAccountState()`;
  port the ProfileSettingsSync deferred-push (`pendingGatedPushSignature`) so a pre-settle edit
  pushes after settle instead of wedging. ⚠️ This is the race-dense settle-gate pattern — budget
  Codex rounds (5 races found last time); mirror the settled/not-settled path mapping exactly
  (decode failure ≠ settled). Legacy-platform read fallback: DEFERRED, product call (one-release
  bridge vs. dead namespace).
- **D. HomeScreenSettingsPane.swift** — empty state gains a focusable row (BUG-47 rule);
  flatten/de-animate the two groups so shrinking items can't strand focus.

Gates in main: jvm + tvOS-native tests, sim build, Codex loop, then device eyeball (the
white-on-white half is only verifiable on hardware).

## Wave 2 — device-only white-on-white legibility (after Wave 1 lands)

Apply the documented BUG-65 recipe (row-published `@FocusState` via `settingsRowIsFocused` env
key instead of `\.isFocused` inside custom labels) to `SettingsRowViews` rows and the two pane
groups. Spec from main session after re-reading the beta.13.5 fix; Sonnet executes; verification
is irreducibly a Christian device pass (sim provably renders these correctly).

## Wave 3 — remaining list (investigate → spec → delegate)

| Item | First step | Owner |
|---|---|---|
| Trailer zoomed in description + only "Behind the Scenes" visible | Explore agent on DetailView trailer surface + video frames ~2:10 (washed-out frame) | investigate |
| Doubled hero + collection background resize | Needs his Hero Paint Diagnostics photo on beta.16 (probe shipped in .15); re-ask in DM | blocked on reporter |
| Poster text overlay overlap (worse; hits "Services de Streaming") | Explore agent (BUG-73 fix landed in .15 — regression or new surface?) | investigate |
| Focus ring border on titles + Card Depth thick on Subtle | Explore agent on TileFocusLift/CardDepth style paths | investigate |
| Ratings hide toggle (MetaVideo.rating port) | Small feature: settings toggle + render gate — direct Sonnet spec | spec ready-ish |
| Home collection title size (bigger; NOT inside collections) | Trivial UI tweak — fold into whichever wave touches Home rows | spec ready |
| Top bar (BUG-66), focus-ring zoom (BUG-64), choppy scroll (BUG-41) | Already tracked, hardware-only; unchanged | existing tracks |

## Sequencing

1. Wave 1 now (it also neutralizes the H5 widening our beta.16 gate introduced — do not ship
   another beta before this).
2. Wave 2 next (device-verify with Wave 1's pass).
3. Wave 3 investigations can run as Explore agents in parallel with Wave 1 implementation
   (read-only, disjoint); their specs become Wave 4 implementers.
4. One beta.17 at the end of Waves 1+2 (+ whatever Wave 4 items are ready), single release wave.

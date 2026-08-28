# Two traces from the 2026-08-27 device pass

Both findings from the beta.15 device pass (§J of `beta15-implementation-plan-2026-08-23.md`),
traced the same evening against `claude/beta15` @ `c77e9caa`. Every claim below was verified by
reading the code, not inferred from the reports.

---

## Trace A — Upcoming row empties on a Watch Progress Source flip

**Verdict: real defect, code-provable, ~15-line fix.**

### The chain

`UpcomingEpisodesRepository.observeShowSet()`
(`shared/.../features/upcoming/UpcomingEpisodesRepository.kt:236-246`) seeds the sweep from a
`combine` of **`WatchProgressRepository.uiState`** *and* `LibraryRepository.uiState`:

```kotlin
refs = collectUpcomingShowRefs(progress.entries, library.items)
```

`collectUpcomingShowRefs` (`UpcomingEpisodesRules.kt:104-109`) is a plain union — progress-derived
shows are first-class members of the row's seed.

`WatchProgressRepository.uiState.entries` is **source-scoped**: `publish()` → `currentEntries()` →
`projectWatchProgressSourceEntries` (`WatchProgressSourceProjection.kt:15-33`), which, once a
provider owns the source, discards the local/Nuvio entries wholesale and publishes only the
provider's rows. Simkl with no scrobble history ⇒ `entries = []` ⇒ half the seed vanishes ⇒
`distinctUntilChangedBy { trigger.key }` (`:253`) sees a new key ⇒ `recompute` republishes, and
with an empty ref set takes the early return at `:274-277` (`items = emptyList()`).

Swift then hides the row: `HomeView.swift:851` renders it only
`if upcomingRowEnabled, !model.upcoming.isEmpty`.

### Ruled out (each checked against code)

- **Coordinator side effects** — `WatchProgressSourceCoordinator`'s transition surface is
  enrichment-cache invalidation + `activateSource`/`refreshForSource` on watch-progress and
  watched only (`:215-222`); no `LibraryRepository`/`UpcomingEpisodesRepository` reference in
  `runTransition` or `clearLocalState`. `UpcomingEpisodesRepository` has four call sites total,
  none on the source-switch path.
- **Library gated on the progress provider** — `effectiveLibrarySourceMode()`
  (`LibraryRepository.kt:622-629`) resolves against Trakt authentication only;
  `setWatchProgressSource` copies only `watchProgressSource`.
- **The 08-27 sync change** — `Library` and `ActiveWatchSource` are sibling `launch`es in one
  `coroutineScope` (`SyncManager.kt:159-184`); the new `error(...)` is swallowed by `runStep`'s
  catch and only records a failed step. `Library` runs unconditionally.

### Why it reads as "correct but wrong"

The feature's own KDoc says it tracks "every show the user follows (watch progress + Library)"
(`:44-45`), and the rules doc defends not anchoring on watched position. But "follows" was
implemented as *library ∪ has-watch-progress*, and the second term silently inherits the
watch-progress **source**. The notifications twin does it the expected way —
`EpisodeReleaseNotificationsRepository.kt:341,428` seeds from `LibraryRepository` only.

### Fix

Publish a source-independent followed-show set from `WatchProgressRepository` (union of
`localEntriesSnapshot()` and the active provider's entries, bypassing the projection) and combine
*that* in `observeShowSet()`. Continue Watching still swaps with the source (correct); Upcoming
keeps its seed. No persistence change, no new store.

### Residual needing the device

Whether the row hit *zero* (vs merely shrinking) also requires that no Library show airs inside
the 14-day horizon — plausible for a watchlist skewed to finished shows. Probe: log
`progressEntries/libraryItems/refs` in the combine and `published` at the end of `recompute`.
`libraryItems=0` would mean the library seed itself broke (re-open the ruled-out branch).

---

## Trace B — BUG-66: the tab bar does not minimize on Home

**Verdict: the beta.15 fix's THEORY IS REFUTED. Primary new hypothesis identified; one cheap
device/sim measurement discriminates it. Do not write code first.**

### What the shipped fix assumed, and why that's now dead

The tracker declares BUG-66 "ROOT-CAUSED AND FIXED" (2026-08-23) on a publish-storm theory:
`MainTabView` held `TabBarVisibility` as `@StateObject`, so every tab switch re-resolved
`.toolbarVisibility` mid-transition and latched the bar. T2–T4 retired the shared state, moved to
`@State`, and declared `.automatic` uniformly on all six tabs.

**All of that is present in the build that just failed** (verified in `c77e9caa`:
`tabBarImmersiveHide()` at `ContentView.swift:262+`, `@State private var tabBarVisibility` at
`:254`). The device confirm the row was waiting on has come back **negative**, and the reported
shape ("never minimizes") is not the latch shape ("minimizes, then sticks") the fix addressed.

### How the bar is actually driven

One value, one publisher: every tab declares `.tabBarImmersiveHide()`
(`ContentView.swift:270-305`), which resolves to
`.toolbarVisibility(immersive ? .hidden : .automatic, for: .tabBar)`
(`DesignSystem/TabBarVisibility.swift:168`). `immersiveHidden` publishes **only** on a detail-depth
0↔>0 crossing, driven from the single push/pop pair in `DetailView.swift:348-349`.

So: pushed detail hides the bar **declaratively** (works — matches the observation), and **nothing
in the app ever asks the bar to minimize on scroll**. Round 4 settled that deliberately
(`b68d5961`, "scroll never toggles bar visibility; system owns scroll presentation"), leaving the
minimize entirely to tvOS.

### Primary hypothesis (H1): pinned Home hands the tab bar's band to the hero

`HomeView.swift:544-556` splits by mode:

```kotlin
if heroContainerPinned {
    VStack(spacing: 0) { if heroHeaderVisible { pinnedHeroHeader }; rowsScroll(pinned: true) }
} else { rowsScroll(pinned: false) }
```

In **pinned** mode the rows `ScrollView` is the *second child of a VStack* — it no longer reaches
the top screen edge, so it never takes the tab bar's safe-area inset, and the system has no
scroll-edge relationship to minimize against. The repo states the geometry itself in three places
(`HomeView.swift:510-518`, `:1127-1130`, `Theme.swift:259-270`).

`heroContainerPinned = heroNuvioStyle || !heroSettings.heroEnabled` (`:241`) — **default is
classic**, which is what in-house testing has always run, while the reporter runs hero-off
(tracker `:260`, and his FEAT-25 hero-trailer confirmation is only possible in pinned mode). The
pinned hero shipped in beta.10 on 2026-08-03; his first "top bar always visible" complaint is
2026-08-05.

Structural contrast: Search, Library and Add-ons are all bare `ScrollView` under the bar and all
measured `i=157`. `.scrollClipDisabled`, `focusSection` and `ScrollViewReader` are *not*
discriminants (working screens use them).

### Secondary hypothesis (H2): the minimize was never opted into

`.tabBarMinimizeBehavior(_:)` appears **zero times** in the app (verified), while the deployment
target is tvOS 26.0 and Apple's own TV app uses `.onScrollDown`. If `.automatic` does not imply
scroll-minimize on tvOS, the bar never minimizes on **any** tab — which would also mean the
premise behind the FEAT-17 decline ("it already minimizes as you scroll") was never true.

### The shipped diagnostic recipe cannot decide this

beta.15's recipe reads `i` as "157 = stuck expanded, ≈76 = minimizing correctly". But the only
device capture of that band — `docs/research/bug30-probe-capture-2026-08-02.log`, 1,603 samples
across ~7,878pt of classic-mode scrolling — reads **`inset=157` on 1,599 samples** (2×`302`,
2×`0`, all launch transients). The inset never moved, so it does not track bar state and the
recipe would report "caught, stuck expanded" on every run regardless of truth. The defensible
reading of `i` is **157-vs-0: is Home's scroll view under the bar at all**.

Also refuted: "focus-driven reveal produces no scroll signal" — the same capture shows
`contentOffset.y` running −157 → +7721 under a pure D-pad walk. The signal exists; the
*association* is what's missing.

### Discriminator (cheapest first, no code)

1. **Which mode was the failing session in?** Settings → Appearance → Show Hero / Nuvio-Style
   Hero. Hero-off or Nuvio-style ⇒ pinned ⇒ H1 live.
2. **Scroll Search deep on the device.** If Search's bar also never recedes ⇒ H2 (or H2+H1), and
   the fix is one line. If Search's bar recedes and Home's doesn't ⇒ H1.
3. **Sim A/B** reproduces H1 without hardware — in-house never saw this because in-house always
   ran classic. The rig already exists: `docs/research/bug60-bug61-sim-repro-2026-08-10/`
   (`simkit.py`, `sweep.py`) was built to drive the sim with hero-off/pinned.

### Candidate fixes, in order

- **F1 — declare `.tabBarMinimizeBehavior(.onScrollDown)` on the `TabView`.** One line, shell
  level, touches no scroll position or focus and never toggles `.toolbarVisibility`, so it sits
  outside all six banned rounds. Fixes H2; may not fix pinned Home if H1 is the cause.
- **F2 — restore the pinned hero's scroll-view association** (overlay rather than VStack sibling).
  **High risk:** every shape re-enters the region reverted on 2026-08-03 for focus-reveal reasons.
  Spike gated on the sim A/B, never written blind.
- **F3 — make the diagnostics answer it in one photo** (zero behavioural risk): thread the hero
  mode into the About-pane probe readout so the Home line reads `Home[pinned-panel] … i=0`, and
  correct the recipe text to 157-vs-0.

### Bonus: a shared-root candidate with BUG-30

The pinned height budget assumes a **76pt** tab-bar band (`Theme.swift:263`), but the only device
measurement is **157**. If the device band is really 157, the pinned rows viewport is ~425pt, not
the ~506pt budgeted — below the ~494pt reach-extended row focus frame, i.e. exactly the
unsatisfiable-reveal condition documented at `Theme.swift:271-277`. That would make one
mis-measured constant the shared root of BUG-30's rest-short residual **and** BUG-66's
non-minimize. One capture tests both.

---

## Trace B — CONFIRMED 2026-08-27 by discrimination on the device

Christian answered both discriminators:

- **Nuvio-Style Hero is selected** ⇒ `heroContainerPinned == true` ⇒ the VStack split is live.
- **Search's bar DOES minimize while scrolling results** ⇒ **H2 is dead.** The system minimize
  works fine under `.automatic`; nothing needs opting in. It is specifically *Home in pinned mode*
  that never minimizes.

**H1 is therefore the confirmed root cause:** in pinned mode the rows `ScrollView` is the second
child of a `VStack` (`HomeView.swift:544-556`) and never occupies the tab bar's band, so the
system has no scroll-edge relationship to recede against. Search/Library/Add-ons are bare
full-bleed `ScrollView`s under the bar and all minimize correctly.

### Why the obvious fix is off the table

Restoring the association means putting the rows `ScrollView` back under the bar with the hero
overlaid — i.e. `.safeAreaInset(edge: .top)` or equivalent. That is a **known-bad pattern on this
platform, not merely a past failure here**: the focus engine's scroll-to-reveal *ignores*
`.safeAreaInset` and `.contentMargins`, so rows slide up through the inset region and focused
cards rest behind the header. Apple-doc-derived guidance is explicit that a pinned header over
scrolling content should be "a real `VStack` split: fixed header on top, rows in their own
`ScrollView` whose frame is the remaining height" — which is exactly what this code does, and why
the 2026-08-03 revert was correct. The VStack is load-bearing for focus correctness.

So the two requirements are in direct conflict:
- the **focus engine** needs the rows `ScrollView` to have honest bounds *below* the hero;
- the **tab bar minimize** needs a scroll view that *occupies the bar's band*.

In pinned mode the hero permanently owns the top band, so no single scroll view can satisfy both.
This is a genuine layout conflict, not an oversight — and it explains why five rounds of
scroll/visibility fiddling never touched it.

### Recommended order (cheapest first, none of it blind)

1. **Sim reproduction, now possible for the first time.** In-house always ran classic (the
   default); the config that fails is Nuvio-Style Hero. Seed the setting into sim prefs rather
   than walking Settings (the `poster_card_style_payload_2` precedent) and watch the bar while
   scrolling. This gives the rig every later step needs, and costs no device time.
2. **F1 — `.tabBarMinimizeBehavior(.onScrollDown)` on the `TabView`, tested in that rig.** One
   line, shell level, touches no scroll position, no focus, and never toggles
   `.toolbarVisibility`, so it is outside all six banned rounds. Its *stated* effect is the
   behaviour we want; whether it can associate with a scroll view that is not under the bar is
   genuinely unknown, which is why it is an experiment and not a fix. **Prediction: it will not
   help**, because Search already minimizes without it — but it is minutes to falsify.
3. **F3 — thread hero mode into the About-pane probe** (`Home[pinned-panel] … i=0`) and correct
   the recipe from 157-vs-76 to 157-vs-0. Zero behavioural risk, and it makes every future report
   from the reporter self-diagnosing.
4. **Only then, the real decision — a product call, not a bug fix.** If the association cannot be
   had while the hero stays pinned, the options are: (a) accept a permanently-expanded bar in
   pinned mode and say so plainly on the thread (it is the mode's cost); (b) compact the pinned
   hero enough that the lost band stops mattering; (c) give pinned mode its own top treatment that
   does not reserve the bar's band. Each is a design change with focus-geometry blast radius, and
   none should be written without the rig from step 1.

**Do not** re-enter: scroll-driven `.toolbarVisibility` toggling (round 4, banned — it is BUG-30's
clip), `.safeAreaInset` for the pinned hero (reverted 08-03, and contrary to platform guidance),
or a hero-refocus completion scroll (rounds 5–6, wedged Down navigation).

### Bonus finding stands and is now more interesting

The pinned height budget assumes a **76pt** tab-bar band (`Theme.swift:263`); the only device
measurement is **157** (`bug30-probe-capture-2026-08-02.log`). In pinned mode that band is
consumed *above* the rows viewport — so if the real band is 157, the viewport is ~425pt against a
~494pt reach-extended row focus frame, the documented unsatisfiable-reveal condition
(`Theme.swift:271-277`). That is a plausible shared root for BUG-30's rest-short residual, and it
is measured by the same sim rig as step 1.

---

## Step 1 DONE — the sim rig was built and run the same evening

Rig + full results + gotchas: `docs/research/bug66-sim-rig-2026-08-27/` (README has the
verdict table and frames). Four passes against Debug `e19fbfc8` on the 26.5 sim fixture, hero
mode seeded into the app-container plist and every pass self-validated by the probe's own mode
name. Two outcomes that reshape the plan:

1. **The sim cannot show the failure.** The bar recedes on scroll-down and returns at top in
   ALL four passes — Search control, classic, pinned-hero (the reporter's config) and
   pinned-panel. The device's "never minimizes" does not reproduce on the sim runtime; bar
   presentation is hardware-divergent, as it was through all six BUG-30 rounds. So the step-2
   F1 experiment **cannot be decided in the sim** — its sim gate is regression-only and its
   real test is a device pass.
2. **H1's geometry is confirmed by measurement**, not just code reading: classic Home's rows
   ScrollView reports `inset=157/302` (it owns the bar's band, rests `residual=0`), both
   pinned modes report `inset=0` on every non-transient sample of full walks. The **F2 sim
   gate is therefore structural**: an association fix is working when pinned Home's probe
   reads `inset=157` at rest-at-top — this rig measures exactly that, so F2 spikes stay
   sim-gated despite finding 1. F3's 157-vs-0 recipe correction is likewise now
   measurement-backed on both instruments (sim + the 08-02 device capture), and the bonus
   76pt-vs-157 budget question hardened: the sim's expanded band is 157 too.

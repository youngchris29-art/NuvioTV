# Steven beta.18 batch — feedback record + fix plan (2026-09-05)

Status: **MERGED 2026-09-06 into `tvos-shared-extraction` (`8560d305`)** — device pass (Show Hero OFF) + rc2 + DM owed; see the outcome section. **rc5 CUT (build 121, `9b02bb16`) is latest** — rc4 (build 120, `a4dbb976`) was cut but its DM was NEVER sent and is superseded; rc5 = rc4 + the full rc2-feedback batch (sidebar hide fix, bridge caption, Saga names, Settings font, last-row inset floor, Row Settle Diagnostics); device pass still owed.

## 1. What Steven reported on build 117 (rc1, DM 2026-09-05 5:48 PM ET)

Photos: `docs/research/steven-beta18-photos/2026-09-05-hero-paint-diagnostics-build117.jpg`,
`…/2026-09-05-trailer-diagnostics-build117.jpg`; the two beta.17 photos from 09-04 are filed beside them.

**Fixed (his words):** the double hero ("finally fixed"); the poster ring now goes around the poster instead of on it;
title size and the text no longer appearing before the logo; zoom + card depth; the second-to-last collections row.

**Caveats on the last one:** switching Medium → Large in Settings brings the old symptom back until a restart; and the
correction is visible ("you first see part of the row above, then the app realises 'oops' and quickly hides it").

**Not fixed:**
- Catalog titles bouncing; on his first launch the title vanished entirely (relaunch fixed that); a glitch on the
  title whenever he scrolls a row horizontally.
- Description page stutter, with every trailer option disabled ("not caused by the trailer").
- Trailer zoomed in on the description page.
- Trailers overflowing a focused poster, now believed to happen only on the first poster of each row.
- Collection backdrop repositioning in the hero: the new image appears, then re-crops in front of him when the
  previous image had a different size.
- Top bar still visible (FEAT-30, other session).

His 09-05 4:18 AM message also asked for the trailer bridge animation (FEAT-32, built) and 60 fps collections (FEAT-33).

## 2. What the photos say

**Hero Paint Diagnostics (build 117):** no `publish` lines, no `commit` line.

```
1403ms vm acquire id=1 rc=1
1451..1539ms addonsChanged ready=1..5 catalogs=0..18 addonRoute=refresh bootstrap=settled
1700ms rows vm=1 n=2 first=collection_… settingsSig=7805ec5f heldRebuilds=3
1811ms present item=nuvio.folder:… backdrop=fetched logo=fetched waited=73 same=0
1831ms paint kind=seededPrimary first=1 … item=collection-hftcv0ta-community/folder-JRWZVYWG
2477ms rows vm=1 n=6 first=tmdb-addon:movie:… rowsHash=2d82fb78c925689c settingsSig=f2774137
2686ms present item=movie:tt37752275 backdrop=fetched logo=fetched waited=165 same=0
2703ms paint kind=image first=0 … same=0 item=movie:tt37752275
186661ms vm release / vm stop
```

Reading: Steven runs **Show Hero OFF**. With no hero items there is no `publish` and no `commit`, and the top of Home is
the FEAT-15 focus panel (`HomeView.focusHeroActive`), whose resting title is the first item of the first catalog row
(`heroPanelSeed`). `decideHeroGate` releases immediately for `heroOff` (`HeroCommitGate.kt:201`), the Swift route sends
that to `.noHero`, the rows gate opens on the first released publish at 1.7 s, and when the launch sync burst lands at
2.5 s (settings signature changes) the rows reorder, the first catalog row changes, and the panel repaints a different
title. The two beta.17 photos show the same profile (no `publish` lines, a paint every second for a minute as the rows
churned), so Wave G's rows gate is what collapsed that churn to one swap. The plan's "Steven's configuration" assumed
Show Hero ON, so the 09-05 device pass and the photo contract never covered his profile.

**Trailer Diagnostics:** inline poster surface (`movie:tt37752275`): cached zoom applied (token match), layer 1458x820
zoom 1.080, probe abandoned after 2 samples when focus left (verified-cached kept). Description page = full-screen
surface (`series:tt34771210`, FEAT-32 auto-enters the cover): cached zoom 1.125 applied, re-measured and
`verify-confirmed`. 1.125 = exactly a 2.00:1 picture inside a 16:9 frame (1080/960). The crop is the letterbox-fill
policy working as designed on a surface where Steven expects the official app's uncropped behaviour. Cache: 36 entries.

## 3. Decisions (Christian, 2026-09-05 evening)

- Full-screen trailer surface never crops (zoom 1.0, `.resizeAspect`, bars). Hero loop and inline poster unchanged.
- The structural Large-frame fix is allowed (the 09-04 plan had rejected it): make the focusable link frame fit the
  pinned rows viewport so the hardware focus engine has one rest.
- The parked features (FEAT-30 side/collapsible top bar, FEAT-31 Open Sans, FEAT-33 60 fps) belong to a second
  session. It already occupies the main `NuvioMobile/` checkout (branch `claude/steven-parked-feats`), so THIS batch
  works in a separate local clone: `/Users/christianturnbull/Claude/Projects/NuvioMobile-beta18`, branch
  `claude/steven-beta18` off `1d4d8f9d` (remotes: `origin` = GitHub, `local` = the main checkout for fetch-back).
  This batch merges into `tvos-shared-extraction` first; the feature branch rebases.

Item → tracker: hero-off rows gate = BUG-86 remnant; bounce / vanished title = BUG-87; scroll glitch = BUG-88;
second-to-last row + Medium→Large = BUG-89; detail stutter = BUG-41; first-poster bleed = BUG-92; detail trailer crop =
BUG-94 (new); folder backdrop reposition = BUG-95 (new, the BUG-86b video evidence).

## 4. The plan

The approved plan is `~/.claude/plans/lets-make-a-detailed-cozy-comet.md`; summary of the waves:

**Phase 1 (parallel, disjoint files):**
- **W1 hero-off ROWS gate** (Opus): Kotlin owns it. `HeroGateDecision.rowsReleased`, `HeroGateInputs.rowsElapsedMs`;
  `HERO_OFF`/`NO_SOURCES` set `rowsReleased = syncSettled || rowsElapsedMs ≥ 4000`; `HomeRepository` holds `rowsHeld`
  on that, arms a rows-timeout job, widens `republishForGate()`; `HomeUiState.rowsGateReleased/rowsGateReason`;
  `gate=` string gains `rowsWait=… rowsWaitMs=…`; Swift `HeroPublishRoute.decide(rowsReleased:)` holds; a `publish n=0`
  probe line for the hero-off profile; `-debug.homeHeroOff YES` non-persisting fixture flag; new test31 leg D in
  `HeroOffLaunchTests.swift`; Kotlin gate tests for the five shapes.
- **W2 full-screen no-crop + first-poster bleed** (Sonnet): pure `zoomPolicy(surface:cached:)`, full →
  `(1.0, .resizeAspect, measure:false, persist:false)`, `policy=uncropped` probe line, cache never written by the full
  surface; `RowLeadingEdgeClip` shape (attached by W5 at `BrowseComponents.swift:3107`), player layer corner radius +
  `masksToBounds`, `debug_trailerTile x=`, screenshot-diff UI test.
- **W3 folder backdrop** (Sonnet): `HeroCrossfadeImage` gets `Color.clear` + `.clipped()` so its size never depends on
  the bitmap; `HeroArtResolver.commit` assigns outside `withAnimation`; `.transaction { animation = nil }` on the
  images; `present … frame=WxH` probe; layout unit test.

**Phase 2 (parallel):**
- **W4 pinned geometry** (Opus): `PinnedRowGeometry.plan(...)` spends compression (link-frame keyed, cap moved behind
  `showsCTA`: 142 give in panel mode vs 70 in carousel mode), then bottomReach 44→24, then topReach 88→64, publishes
  `fits`/`restRange`; HomeView reads the plan for compression, reaches, shelf chrome, bottom inset and last-row height;
  `debug_env` gains `comp= topR= botR= fits= slack=`; `regimeKey` `.onChange` drives the re-reveal in the same
  transaction as the compression change. (rc4: order reversed, reaches first — see outcome 09-06 17:00)
- **W5 corrector + belt** (Opus): first Reading may not arm the belt (0.5 s grace, `remeasureTick`); bounded
  re-measure watchdog while faded; `noteRegimeChange(key:)` resets the session-wide disarm/pull-back/verify state and
  re-arms with `retryAfter: 0`; settle line gains `regime= fits=`; attaches W2's clip; new regime UI test.
- **W6 detail stutter** (Sonnet, after an A/B evidence run with `-debug.detailScrollProbe YES -debug.detailScrollAB
  <0..4>`): debounced `isScrolling` on `ScrollDimModel`, `chipGlassFlat` also true while scrolling; acceptance ≤ 2
  hitches / 10 s, `maxGap ≤ 40 ms`, within 20% of glass-off.

**Phase 3:** Codex loop to clean → docs/tracker/CLAUDE.md/memory → merge into `tvos-shared-extraction` + pointer bump →
device pass in Steven's REAL shape (Show Hero OFF, French, Large, No Zoom ON, ring OFF, Card Depth ON, Hide Labels ON)
→ rc2 (build 118) → DM through the SlopMonster loop with the hero-off photo contract → beta.18 public only after his
photo passes.

**Hero-off photo contract:** good = `publish … n=0 … gate=released:heroOff rowsWait=settled rowsWaitMs≤4000`, then one
`rows … rowsGate=open`, then `present … same=0` + `paint … first=1`; bad = a second `rows` line with a changed
`settingsSig` followed by a `present` with a different `item=`.

## 5. Outcome (append as it happens)

- 2026-09-05 ~20:15 ET: clone created, Phase 1 agents (W1 Opus, W2 Sonnet, W3 Sonnet) launched.
- 2026-09-05 ~21:00 ET: **Phase 1 COMMITTED** on `claude/steven-beta18` in the clone — `db2240bb` W1 hero-off rows
  gate (Kotlin `rowsReleased`/`rowsWait=`, Swift route hold, `publish n=0` probe, `-debug.homeHeroOff`, test31 leg D),
  `89006585` W2 full-screen never crops + `RowLeadingEdgeClip` (attachment owed to W5), `ecc00536` W3 crossfade
  container. Gate so far: jvmTest 744 green (+42); Debug sim build green; NuvioTVTests 126 → two findings: (1) W3's
  own layout probe showed a square bitmap still grew the stack to 1250×1250 with `Color.clear` alone — fixed with a
  GeometryReader-pinned frame, probe green; (2) `testPrepareTimesOutEvenWhenAFetchNeverReturnsAndIgnoresCancellation`
  is a pre-existing one-`Task.yield()` race (passed 1 of 2 re-runs; the other re-run was a sim host crash) — hardened
  to a bounded poll. Release build + K/N tests + UI legs pending. Agent deviations accepted: W3 kept the commit
  `withAnimation` (the foreground text/logo crossfade rides that transaction; geometry is now pinned so it cannot
  animate); W1 applies `debugForceHeroOff` in `publish()` too (HomeView follows `uiState`, not `snapshot()`); W2's
  cache-untouched test proves the policy is cache-inert (no DI seam for `TrailerZoomCache.shared`). Note: the
  `-debug.homeLaunchBurstSim` replay waits for a non-empty hero publish, so on a hero-off profile it bursts only after
  its own 6 s timeout — leg D's real reproducer is the fixture's genuine launch sync.
- 2026-09-05 ~21:40 ET: Phase 1 gate continued — Release sim build green (Debug + Release both from `ecc00536`), K/N
  `tvosSimulatorArm64Test` 764 green. UI legs (test31 A/B/C, HeroOffLaunchTests leg D, RowLeadingEdgeTests, test37/41,
  TrailerSoakTests) running from a detached worktree snapshot of `ecc00536` (`~/Claude/Projects/NuvioMobile-beta18-p1`,
  own DerivedData) against the spare simulator `F38F573A` that now carries a clone of the FA87 fixture (data container +
  app group + prefs; FA87 itself is booted by the parked-features session). Phase 2 agents launched in parallel: W4
  (Opus, PinnedRowGeometry + HomeView/Theme), W5 (Opus, BrowseComponents belt/regime + leading clip attach), W6
  (Sonnet, DetailView glass flatten while scrolling); W6's A/B evidence run moved to the Phase 2 gate.
- 2026-09-05 ~22:30 ET: **Phase 2 waves delivered (uncommitted, gate running).** Phase 1 UI-leg run 1 failed to
  compile the test bundle (`RowLeadingEdgeTests.swift:100` "failed to produce diagnostic" on
  `Double(...).map(CGFloat.init)`) — spelled out and committed as `fdd7442e`; re-run in progress from the worktree.
  **W4** (`PinnedRowGeometry.swift`, Theme, HomeView): Steven's shape (Large 403.33, Hide Labels, panel) now
  compression 112.33 / reaches 88/44 / viewport 567.33 / linkFrame 535.33 / `fits=1` / restRange 32 inside a 74 pt
  band; Small/Medium/landscape 0 (explicit gate: spend only where today's compression is > 0); Large+captions+carousel
  unsatisfiable → today's numbers + `fits=0 CAPPED` log. Panel give made real (`heroPinnedCompressionCap(showsCTA:)`
  = 142; `synopsisLineLimit` derived from the slot) — **visible trade-off: the focus panel synopsis at that shape
  drops from 3 lines to 1** (the alternative spend order, reaches to their 64/24 floors first, would keep 3 lines at
  the cost of both focus-reach cushions) — **Christian's call at the device pass**. `.animation(.easeInOut(0.28),
  value: pinnedPlan)` on the pinned container + `.onChange(of: regimeKey)` → `noteRegimeChange`. `debug_env` gains
  `comp= topR= botR= fits= slack=`. Collection last-row height corrected via `pinnedPlanReachDelta` (helper lives in
  CollectionsUI.swift, out of scope — fold in later). **W5** (BrowseComponents): first-reading grace (0.5 s
  `remeasureTick` + republish), faded recovery watchdog (1 s × 5), `noteRegimeChange(key:fits:)` resets every
  session-wide brake and re-arms with delay 0 (scheduler slot now `(Int, TimeInterval)`), settle line `regime= fits=`,
  `UNEXPECTED-WITH-FIT` on a correction with `fits=1`, `RowLeadingEdgeClip` attached on `CatalogRowView`'s LazyHStack
  before `.scrollClipDisabled()` (CollectionRowView's row in CollectionsUI.swift NOT clipped — folder tiles play no
  trailer, so no user-visible gap); new `PinnedRowSettleRegimeTests` (leg A drives the real Poster Size picker, gated
  on `debug_env`; leg B idles 5 s then focuses one row to read `beltFaded`). **W6** (DetailView): `ScrollingLatch`
  (150 ms) on `ScrollDimModel`, third `onScrollGeometryChange` on raw offset, `chipGlassFlat` = trailer ∨ scrolling ∨
  A/B, `detailChipBackground` swap without animation, `debug_ux6 scrolling=`; the action-row `GlassEffectContainer`
  stays on its own A/B leg-4 knob by design. Main-session fix: the clear task is one per scroll, not one per frame.
  Gate: Debug build green with all three waves; unit bundle running on a third simulator; Release, UI legs (test47/48,
  regime tests, test31 re-run), and the BUG-41 A/B evidence run pending.
- 2026-09-05 ~23:00 ET: **Phase 1 UI legs (worktree @ `fdd7442e`, spare sim with the cloned fixture): 9/10 passed** —
  test31 A/B/C, test37, test41, RowLeadingEdgeTests both legs, TrailerSoakTests all four (the soaks ran despite the
  YouTube LOGIN_REQUIRED note — the smoke video id path still works). **Leg D failed and found a second gap:** the
  probe dump shows the hold working (`gate=released:heroOff rowsWait=sync` at 5520 ms, rows open at 6014 ms with
  `rowsWait=settled rowsWaitMs=712`), but the focus panel painted at 5659 ms — BEFORE the rows opened — from the
  Continue Watching seed (`heroPanelSeed` falls through rows → CW → folder, and CW is not behind the rows gate), then
  repainted the first catalog row's title at 6507 ms: the same double paint by another door. Fix: `HomeViewModel.
  rowsGateOpen` (published mirror of `RowsGate.isOpen`) and `heroPanelSeed` returns nil until it opens, so the panel's
  first paint is the rows' first paint (the "Loading catalogs…" placeholder covers the hold). The 12449 ms move in the
  dump is the burst sim's reversed row order (first rows changed) — legitimate; leg D now forbids any `present` before
  the rows open and allows a later title move only after a `rows` line with a CHANGED `settingsSig` (the photo
  contract's own rule). Note for the record: on a hero-off profile `HomeLaunchBurstSim.runBurst` waits for a hero
  publish that never comes and bursts after its 6 s timeout (~12 s here), so it never lands inside the hold; the real
  launch sync is what leg D exercises, and that part passed.
- 2026-09-05 ~23:45 ET: **Codex rounds 1–2 + Phase 2 UI run.** Round 1 (branch `1d4d8f9d..6561c73c`): P1 the
  initial pinned regime was never registered (`onChange` skips the initial value, so the first Medium→Large switch
  was `noteRegimeChange`'s record-only first call) → `initial: true`; P2 `cancelScrollLatch()` left `isScrolling`
  stuck if the page left inside the 150 ms window → cleared on cancel. Both in `1a8ba8ab`. Round 2: P2 the
  `AddonBootstrapRoute.openRowsNoSources` path opened the Swift rows gate on its own, bypassing the Kotlin rows hold
  → it now honours Kotlin's decision, waits on `LaunchSyncSignal` (bounded 4 s) when the launch sync is running, and
  reads the current publish/sync state through new Kotlin accessors (`currentUiState`, `launchSyncRunning`; the first
  cut guessed at StateFlow/enum interop names and broke the Release build); P2 the leading clip sliced the 22 pt
  focused-card shadow → allowance includes it. Commits `b…` (round 2 fixes) + `9ff57411` (accessors). Round 3 pending.
  Phase 2 UI run at `6561c73c` (spare fixture, machine under three builds + a Codex Gradle probe): test37/41,
  RowLeadingEdge ×2, regime leg B PASSED; **test31 leg A FAILED on `gate=released:timeout gateWait=sources
  sources=0/2`** (both hero-source catalogs unfinished at 4 s — the contract forbids timeout on Wi-Fi; passed in Phase 1
  on the same fixture, so re-run quiet before reading anything into it); leg D died on an AX snapshot timeout at its
  first query (infrastructure); **test47/48 SKIPPED: the fixture was at Medium (`debug_env w=220`)** — set Large +
  Hide Labels on the spare fixture via `poster_card_style_payload_1` in user defaults (profile index 1 from
  `profile_payload`); regime leg A SKIPPED loudly (the Appearance → Size picker walk landed on "Import Badge Pack";
  no adjacency map for that pane — owed). Unit bundle 148 green at `6561c73c` (the prewarm-timeout test's earlier
  miss re-ran 53/53 twice in isolation: load). Gate on `9ff57411` running.
- 2026-09-05 ~22:35 ET: **Codex round 3** (branch at `9ff57411`): P2 a Show Hero toggle while the launch gate is
  armed inherited the launch-sync rows hold → `rowsHoldBaselineHeroEnabled` stamped on the first evaluation from the
  caller's snapshot; a `heroOff` decision whose baseline was `true` releases the rows at once with `rowsWait=toggle`
  (`dbc9570d`, then `591e1ed8` fixed my own arm-time reset that nulled the stamp, then `0817b2a4` dropped an
  under-lock `snapshot()` call the first cut had introduced); P2 the scroll latch could over-hold by a full 150 ms
  interval → the clear task now sleeps only the remaining window from the newest change (`dbc9570d`). **Codex round 4
  failed twice: usage limit until 23:09 ET** — round 3's commits were reviewed internally (debounce sound; the lock
  point above was the one finding). Tip `0817b2a4`. Spare fixture set to Large + Hide Labels (profile index 1) for
  test47/48 and the regime legs. Gate on the tip owed: JVM, Debug/unit/Release, UI legs (quiet machine), BUG-41
  evidence run; Codex round 4 after 23:09.
- 2026-09-05 ~23:40 ET: **UI run on `0817b2a4` (spare fixture, machine quieter): test31 leg D PASSED** (the hero-off
  contract end to end with the seed hold), test37/41/46, regime cold-launch leg, RowLeadingEdge ×2 PASSED; test31
  failed on leg C (folder hero committed with `pbd=0` — the 1.5 s folder-art deadline; overlapped Codex's Gradle
  probe, re-run quiet); test47/48 skipped (`debug_env w=220`: the `defaults write` of the poster payload is clobbered
  by the synced pull) → `9f6c70a8` makes test47/48 carry `-poster_card_style_payload_<0..3>` as launch arguments
  (the defaults ARGUMENT domain beats the persisted/pulled value for the process); regime leg A still skips (picker
  walk). **Codex round 4 (after the usage reset): P1 the bootstrap route checked `launchSyncRunning` only — `Idle`
  with an expected sync is unsettled → new Kotlin `launchSyncSettled` (the gate's own term); P1 a re-entry with the
  watcher installed opened the rows → idempotent; P2 `noteRegimeChange` re-armed on the previous regime's
  measurements → `latest`/`sample` cleared so the settle HOLDS until fresh geometry; P2 the leading clip's allowance
  used the resting poster width → sized off the expanded tile (`height × 16/9`).** Round 5 running; gate + quiet
  UI re-run on the tip owed after it.
- 2026-09-06 ~00:20 ET: **Codex loop ended at round 4 (reviewer unavailable after it).** Round 5 failed four ways:
  usage limit (reset 23:09), then `gpt-6-astra` (the account's configured default) "requires a newer version of
  Codex" even on CLI 0.153.4 (upgraded at 23:19 by the other session or Christian), and every explicit model tried
  (`gpt-5.3-codex`, `gpt-5.4-codex`) is "not supported with a ChatGPT account". Round 4's fixes (`cddd23f4` Kotlin
  `launchSyncSettled` + idempotent bootstrap wait; `d7bf763e` stale measurements cleared on regime re-arm + clip
  allowance off the expanded tile — the first attempt's text match had silently failed, caught and redone) were
  reviewed internally: the re-arm lands on `MeasurementReport.unmeasured`'s HOLD until fresh geometry; the bootstrap
  wait is bounded (4 s task) and returns on re-entry. **Owed: one more Codex round on the final tip when the CLI can
  talk to the account's model again.** Tip `d7bf763e`; the tip gate (JVM/Debug/unit/Release) + quiet UI re-run
  (test31 A/B/C, leg D, test47/48 at Large via launch args, regime leg B, RowLeadingEdge) running.
- 2026-09-06 ~01:15 ET: **MERGED.** `origin/tvos-shared-extraction` had moved to `9ffed8ee` (the parked-features
  session landed FEAT-30 sidebar / FEAT-31 Open Sans / FEAT-33 probe, 17 commits) — merged into `claude/steven-beta18`
  with no conflicts (Theme/BrowseComponents/HomeView overlapped in different regions). Merge commit `8560d305` gated:
  Debug + Release green; unit bundle green except `testPrepareFailedWhenArtworkFetchThrowsWithinBudget` (timing, passed
  in isolation); UI on the spare fixture: test31 A/B/C, leg D, test37, regime cold-launch leg, RowLeadingEdge ×2
  PASSED (test31 fails under a concurrent build lane: 4 s gate timeout — run it quiet). `tvos-shared-extraction`
  fast-forwarded to `8560d305` and pushed with `claude/steven-beta18`; outer pointer recorded via update-index (the
  main `NuvioMobile/` checkout belongs to the other session). test47/48 launch-arg payload reverted (`26e946ae`, the
  synced pull publishes over it). **Owed:** device pass in Steven's real shape (Show Hero OFF, Large, Hide Labels, No
  Zoom, ring OFF, Card Depth ON) incl. the synopsis 1-line trade-off call; BUG-41 evidence run (script drafted at the
  scratchpad, untested); one Codex round when the CLI can use the account's model; rc2 (build 118) + DM (SlopMonster).
- 2026-09-06 ~02:00 ET: **Codex round 5 ran** (via `codex exec` — the companion's review mode is what the account's model rejects on CLI 0.153.4; `exec` works with both the npm and the ChatGPT-app binaries). Two P2s, fixed in `ebe14a0f`: the releasing publish after a mid-launch Show Hero toggle used the raw decision (`rowsReleased=false`) so Swift kept holding — now the effective post-apply state; the no-sources bootstrap wait's completions could open the Swift gate after a sync pull enabled an add-on — the refresh path bumps a generation both completions check. Gate: JVM, Debug, unit; `tvos-shared-extraction` fast-forwarded + pushed, outer pointer bumped.
- 2026-09-06 ~01:30 ET: **rc2 CUT.** Build number 118 (`25e07e08`, tag `tvos-v0.3.0-beta.18-rc2`, on `tvos-shared-extraction`); unsigned Release device build stamped `NuvioBetaTag=tvos-v0.3.0-beta.18-rc2 NuvioCommitSHA=25e07e08`; IPA 25,818,355 bytes at https://litter.catbox.moe/js7mfl.ipa (litterbox 72 h, `content-length` verified; copy in `~/Downloads/NuvioTV-beta18-rc2.ipa`). DM draft at 5/5 with the link and commit filled: `docs/comms-dm-drafts-2026-09-06.md` — NOT sent; the optional synopsis paragraph is Christian's call. Device pass with Show Hero OFF still owed before the public beta.
- 2026-09-06 ~01:45 ET: **rc2 DM SENT** to Steven (without the synopsis trade-off paragraph; the sidebar early-stage ask included). Verified in-thread. The send also surfaced an unread edit from him (~23:45 ET): the second-to-last collections row "doesn't work" after further testing on rc1 — to be read and triaged.
- 2026-09-06 ~14:30 ET: **BUG-96 FIXED** (`46ab30f0` + review fixes, tip `69ebad3a`, pushed). Mechanism found by the fixture: `ScrollViewProxy.scrollTo(id:)` is ignored by the focus-driven vertical scroll; `ScrollPosition.scrollTo(y:)` (Home's corrector) works, lands at `y − contentInsets.top` (inset 157 on the fixture), and the engine's own reveal overrides anything issued before it settles (0.35 s). Rest = 108 pt on screen under a 96 pt top scrim. Codex exec review: 5 findings fixed (comments unanchored, geometry read at fire time, cancel on leave/bridge, Reduce Motion, probe published at rest). Side fix: the trailer cover's dim-overlay copy carried a second `debug_ux6` probe (test17 broken since FEAT-32). NOTE for background chains: `codex exec` must run with `</dev/null` or it waits on stdin forever (10 h stall on 09-06).
- 2026-09-06 ~15:30 ET: BUG-96 Codex rounds 2–3 (exec, stdin closed): r2 fixed cancellation honoured in the anchor pass + the comments row genuinely unanchored (`0e68e254`); r3 P3 fixed (the UI leg requires three DISTINCT anchored rows); r3 P2 DECLINED with reason: the Episodes section rests as one row (season chips anchored at 108, the episode shelf fully visible under them); a per-shelf anchor needs EpisodesSection internals and adds a second move inside one section, the land-then-nudge class this fix avoids. Fixture-found follow-up in `072dfa63`: late layout under the focused row (cast photos) moved it 470 pt after the pass and the engine re-revealed; the row's measured offset now re-triggers one debounced pass per layout change. Housekeeping: the morning sweep renumbered the trailer-crop row BUG-94 → BUG-97 (ID collision); earlier BUG-94 mentions in this doc mean BUG-97. Tip `072dfa63` on `tvos-shared-extraction`.
- 2026-09-06 ~15:50 ET: **rc3 CUT.** Build 119 (`9ddc4104`, tag `tvos-v0.3.0-beta.18-rc3`, on `tvos-shared-extraction`) = rc2 + BUG-96; unsigned Release device build stamped `NuvioBetaTag=tvos-v0.3.0-beta.18-rc3 NuvioCommitSHA=9ddc4104`; IPA 25,855,404 bytes at https://litter.catbox.moe/2cljii.ipa (litterbox 72 h, size verified; copy in `~/Downloads/NuvioTV-beta18-rc3.ipa`). Follow-up DM draft 5/5 with the link filled: `docs/comms-dm-drafts-2026-09-06-rc3.md` — NOT sent, awaiting Christian's go.
- 2026-09-06 16:05 ET: **Steven's rc2 feedback (DM 08:34 AM ET, read after the rc3 follow-up went out; video https://fromsmash.com/OstKtGR5AA-ct, Large + Medium, hero ON).** FIXED per him: full-screen trailer (BUG-97); choppy description (BUG-41); floating bar hides on Home (FEAT-30); Open Sans works (FEAT-31) — but not applied to the Settings categories. NOT FIXED: the second-to-last row at Large "still always visible" (BUG-89); title bounce persists — Medium: titles bounce; Large: no bounce on the first row but titles DISAPPEAR on the other rows and stay hidden (BUG-87/88, "whether the Hero is enabled or not"); the Home focus-panel synopsis at Large shows one line (the W4 compression trade-off — he objects: "one line is not enough"; he sees one line sometimes and several other times); NEW: floating bar flickers for a second when pressing Up while scrolling a catalog, then settles (FEAT-30); the floating bar should sit higher and further left (FEAT-30); trailer bridge (FEAT-32) "looks really clean" but the title resizes with the still (odd) and the logo is missing (text only); saga/franchise titles missing in the description (only images). No hero photo yet. TRIAGE OWED — the Large title-hiding and the still-visible second-to-last row say W4/W5's structural fit did not land the way the sim predicted on hardware (the corrector/belt regime is still live at Large); the one-line synopsis is the W4 spend order (reaches-first would keep 3 lines) — Christian's call, now with Steven's vote against one line.
- 2026-09-06 16:40 ET: Steven's rc2 video fetched via Smash: `~/Downloads/IMG_8477.mov` (589 MB, 3840×2160, 30 fps, 186.6 s; contact sheets in the session scratchpad). Sheets confirm the shapes in his text: Large + Nuvio-style hero ON on Home ("Nouveaux films", "Top 10", "Genres"/"Services de Streaming" folder rows), the FEAT-32 bridge (Avatar), the sidebar and the Navigation/Typeface settings, then Medium. Frame-level triage of the Large title-hiding, the still-visible second-to-last row and the Medium bounce is the next session's job (needs the device, or at least a Large synced profile on a sim, which the fixture is not). Decisions Christian owns before that work: the W4 spend order (reaches-first keeps a 3-line synopsis; Steven objects to one line) and whether rc3/beta.18 waits for it.
- 2026-09-06 ~16:00–17:00 ET: **W4 SPEND ORDER CHANGED (reaches first).** Christian's decision on Steven's rc2 feedback: `PinnedRowGeometry.plan` now spends the reach cushions (bottomReach 44→floor 24, topReach 88→floor 64) and only then hero compression, instead of compression first — his shape (Large 403.33, Hide Labels ON, focus panel = Show Hero OFF) had compression-first spend 112.33 and drop the panel synopsis to one line ("one line is not enough"). At his shape under the new order: compression 68.33 (Wave 10's own Large number), reaches 64/24, linkFrame 491.33 fits the 523.33 viewport, restRange 32, panel synopsis keeps 3 lines. Second half: the hero's compression split (`synopsisSlotGive`/`logoSlotGive`) extracted from `HomeHeroForeground` into a pure, unit-tested `PinnedRowGeometry.HeroSlotGive.split`, with a three-tier spend in panel mode (synopsis 36, logo 32, then the panel's extra 72 only beyond those plus the 2 pt frame slack) — needed because the prior panel-mode split drained the synopsis first (68.33 → 75.67 pt slot → 2 lines, not 3). Small/Medium/landscape unchanged (compression 0, reaches 88/44); Large + captions + carousel still unsatisfiable → `fits=0 CAPPED`. Commits on `claude/steven-beta18` (clone `~/Claude/Projects/NuvioMobile-beta18`): `0d449346` ("home: PinnedRowGeometry spends the reach cushions before hero compression (rc2 feedback)") and `a4dbb976` ("release: bump build number to 120 for beta.18-rc4"); both pushed, `tvos-shared-extraction` fast-forwarded to `a4dbb976` and pushed, outer pointer recorded via `git update-index --cacheinfo`. Gates (scratchpad DerivedData): Debug sim green; NuvioTVTests 170/0 failures (22 in PinnedRowGeometryTests incl. 9 new HeroSlotGive tests + a spend-order invariant); Release sim green; UI legs on the spare fixture F38F573A: test31HeroCommitsOnce PASSED (306 s, all legs incl. D), HeroOffLaunchTests test31DHeroOffRowsWaitForSync PASSED, PinnedRowSettleRegimeTests testW5bColdLaunchLeavesNoTitleHidden PASSED, RowLeadingEdgeTests ×2 PASSED, test47/test48 SKIPPED as expected (fixture's synced profile is Medium). Codex review round 1 via `codex exec -s read-only` (`</dev/null`): CLEAN for material bugs, 2 P3 doc nits (a wrong "31.7 pt" rationale figure — the old slot was 36 pt = 144 − min(112.33, 108); a stale BrowseComponents line reference) fixed before the commit. No JVM/K-N run needed (no Kotlin change). **⚠️ The reach floors 64/24 are UNPROVEN ON HARDWARE** (72 was the long-proven reach, 88 the BUG-53 title cushion, 100 kills focus; at reach 64 the settled title clearance is 2 pt vs 26 at 88, so No Zoom OFF users at Large may see the focus lift clip a title) — device pass owns the verdict; revert = `topReachFloor` 72 (Steven's shape then compression 76.33 → 2 lines) or the compression-first order.
- 2026-09-06 ~17:30 ET: **rc4 CUT.** Build number 120 (`a4dbb976`, tag `tvos-v0.3.0-beta.18-rc4`, on `tvos-shared-extraction`); unsigned Release device build stamped `NuvioBetaTag=tvos-v0.3.0-beta.18-rc4 NuvioCommitSHA=a4dbb976`; IPA 25,853,147 bytes at https://litter.catbox.moe/77tezp.ipa (litterbox 72 h ≈ 2026-09-09 ~16:30 ET; copy in `~/Downloads/NuvioTV-beta18-rc4.ipa`). DM draft at 5/5: `docs/comms-dm-drafts-2026-09-06-rc4.md` — NOT sent, awaiting Christian's go. Still owed: device pass with Show Hero OFF (now also the reach-64/24 focus check, and a No Zoom OFF Large title-clip check), BUG-41 evidence, Steven's hero photo, the rc2 remaining-items batch (Large title hiding, second-to-last row at Large, Medium bounce, floating bar flicker/placement, bridge title/logo, saga titles) working from `~/Downloads/IMG_8477.mov`.
- 2026-09-06 ~18:00 ET: **rc4 DM HELD; rc2 video triaged frame by frame.** Christian decided not to send the rc4 DM and instead worked through the rest of Steven's rc2 feedback list from `~/Downloads/IMG_8477.mov`. Frame-level triage record: `docs/research/steven-rc2-video-triage-2026-09-06.md`, evidence crops in `docs/research/steven-rc2-video-evidence/`. Findings: at Large the row label survives a landing from above and vanishes on the first horizontal move (belt), entering from below it fades; the last row rests ≈90 pt deeper than a middle row at both sizes; at Medium every landing is followed by a ≈50 pt upward slide (the corrector's second move = "bounce"); the sidebar pill stays painted over detail pages opened from Search; the bridge caption scales in 1.25→1 and is text where the header is a logo; the Saga row shows bare posters (Hide Labels ON reaches it); Settings categories render in the system face. Sidebar root cause found: `MainTabView` applies `.environment(\.tabBarVisibility)` on the TabView and attaches the sidebar as an `.overlay` OUTSIDE it, so the overlay's environment read resolved to the unconnected default instance and the immersive push never reached it (the pill only hid on Home's detail because the page was scrolled down). Key diagnostics reading on the fixture (Medium profile with captions): `plan M330c1p1r0 vh=455 link=506 rest=0 … fits=0` — 51 pt over-tall, matching the ≈50 pt Medium land-then-slide; extending the fit to Medium+captions is Christian's call (a default layout change).
- 2026-09-06 ~18:10 ET: **rc2 FEEDBACK BATCH BUILT + MERGED.** Submodule clone `~/Claude/Projects/NuvioMobile-beta18`, branch `claude/steven-beta18`: commit `3de9c5ce` "rc2 feedback batch: …" + `9b02bb16` "release: bump build number to 121 for beta.18-rc5"; both pushed; `tvos-shared-extraction` fast-forwarded to `9b02bb16` and pushed; outer pointer recorded at `9b02bb16`. Waves: **W1** sidebar (explicit `TabBarVisibility` pass-through; pill in the corner 60 pt from the left / 40 pt from the top, safe area ignored; 0.35 s show-edge settle, hide/focus/reveal/immersive immediate; `sidebar_state` gains `immersive= resting=`). **W2** bridge caption (no scale-in — `captionScale` removed; title logo via `CachedAsyncImage` with text fallback; one `placedBottomLeading()` helper for both copies; note: an Extras-row clip's caption now shows the title logo instead of the clip name) + Saga row `PosterCard(showTitle: true)`. **W4** Settings categories `Theme.Font.body`. **W5** last-row inset floor `Spacing.screen + plan.restRange + Theme.Size.heroPinnedRowsDeviceParkSlack (96)` + NEW "Row Settle Diagnostics" About toggle (`debug.pinnedRowSettleProbe`, lines persisted under `debug.pinnedRowSettleProbe.lines`, head 12 / tail 28; lines: `regime`, `plan … vh= link= rest= comp= topR= botR= fits= botInset= lastRowH=`, `lastRow`, `settle <report>`, `belt <event>`; strings fr/de/es/it/vi added to Localizable.xcstrings by hand). Codex exec round 1: CLEAN for material bugs; 1 P2 (the plan line only fired on a regime change → companion `lastRow` line on the last row's height change) + 1 P3 (buffer test needed `resetForTesting()`), both fixed. Gates: Debug + Release sim green; NuvioTVTests 171/0 (25/0 on the three touched classes after the fixes); UI legs on the spare fixture F38F573A: test31HeroCommitsOnce, HeroOffLaunchTests, PinnedRowSettleRegimeTests cold-launch leg, RowLeadingEdgeTests ×2, test52SidebarOverlay, test53TypefaceOpenSans, DetailRowAnchorTests, test51TrailerBridgeAutoPlay (PASSED end to end — YouTube extraction works again from this Mac, the proof owed since FEAT-32) all passed; test47/48 skipped as expected. Visual pass with a scratch XCUITest (deleted, not committed): pill at the corner; sidebar element ABSENT on detail pages pushed from an unscrolled Home AND from Search; Settings categories in Open Sans; About shows the toggle with live lines; bridge caption = logo + hint, no resize, return lands on the enlarged still; Saga row names under the posters. Gotchas: osascript key input does not reach a headless-booted simulator even after opening its window (use an XCUITest driver + `xcrun xcresulttool export attachments`); `-ui_font` value is `openSans` (case); detail auto-play trailer is `-detail_trailer_autoplay NO`; the fixture's Home row 4 is the Netflix folder.
- 2026-09-06 ~18:40 ET: **rc5 CUT.** Build number 121 (`9b02bb16`, tag `tvos-v0.3.0-beta.18-rc5`, on `tvos-shared-extraction`); unsigned Release device build stamped `NuvioBetaTag=tvos-v0.3.0-beta.18-rc5 NuvioCommitSHA=9b02bb16`; IPA 25,868,367 bytes at https://litter.catbox.moe/dm1noh.ipa (litterbox 72 h ≈ 2026-09-09 ~18:30 ET; copy `~/Downloads/NuvioTV-beta18-rc5.ipa`). DM draft at 5/5: `docs/comms-dm-drafts-2026-09-06-rc5.md` — NOT sent. rc4 (build 120) was cut and uploaded but its DM was never sent; it is superseded by rc5. Still owed: device pass (Show Hero OFF, reach 64/24 focus walk, No Zoom OFF Large title-clip check, last row rest on hardware), Steven's two photos (Hero Paint Diagnostics + Row Settle Diagnostics at Large), the Medium+captions fit decision, BUG-41 evidence.

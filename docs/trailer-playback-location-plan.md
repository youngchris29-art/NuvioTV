# Trailer Location: poster morph vs hero playback (FEAT-25 round one) — 2026-08-21

**Status (2026-08-21, final): MERGED — folded into beta.14 by Christian's call.** Fast-forwarded
into NuvioMobile `claude/beta14` and `tvos-shared-extraction` (both `aa57a8d6`, pushed); outer
`main` to be fast-forwarded onto `claude/trailer-playback-location-option-lwpsd0`. NuvioMobile
`claude/trailer-playback-location` final head **`aa57a8d6`** (`6b84fbe8` feature → `2dd6bf81`
test37 hardening → `cf306e09` location-aware summary → `aa57a8d6` fallback-aware summary), all
pushed. Sim-build CI green on `6b84fbe8` (run 32531337429). **Codex gate: 5 rounds** (r1 clean,
r2 adversarial 2 findings — 1 taken / 1 kept, r3 P3 taken, r4 two P2 — 1 taken / 1 kept, r5
clean). **Sim:** test01 + test37 PASS back-to-back (8 runs to harden test37). **Device pass:**
items 3–7 PASS, item 8 PASS with notes (see results below). Merge to `main` /
`tvos-shared-extraction` is Christian's call.

## What it is

The round-one half of FEAT-25 (the reporter's original hero-or-thumbnail ask): a
device-local setting `trailer_playback_location` (`"poster"` default / `"hero"`),
surfaced as a "Trailer Location: Poster / Hero" chip row under Trailers on Focus in
Settings > Home Screen. With `hero` selected in a pinned hero layout (Nuvio-Style
Hero on, or Show Hero off), the focused poster no longer morphs into an inline
trailer tile — the trailer plays in the hero backdrop, which already follows focus.
Classic layout and Search keep the poster morph; a Settings caption explains each
fallback (classic layout; zero hero sources).

## How it works (all in NuvioMobile)

- `HomeView.swift`: `heroFocusTrailerMode` (settings + a single-flip
  hero-surface-seen latch), `heroFocusTrailerActive`, `heroTrailerActive` (the one
  Bool `HomeHeroBackdrop` consumes — the FEAT-25 `syncTrailer` machinery is reused
  unchanged); shared cover gates hoisted into `heroTrailerSharedGatesOpen`;
  `debug_hero` probe gains `tloc=`/`hph=` fields; a `[TrailerPipeline]
  trailerLocation` mode line logs at mount and on flips.
- `BrowseComponents.swift`: `trailerPlaysInHero` environment key;
  `CatalogRowView.inlineTrailersActive` suppresses the morph under it (Search
  defaults false).
- `HomeScreenSettingsPane.swift`: chip row + two fallback captions.
- `Localizable.xcstrings`: 5 new keys x de/es/fr/it/vi; `debug_hero` key renamed
  with its source string.
- `NuvioTVUITests.swift`: `test37TrailerLocationHero` (hero leg asserts no morph +
  `tloc=h` + `hph` past idle; poster control leg asserts the morph; peak-width
  oracle so a morph-then-collapse cannot false-pass).

## Review record (in-session pre-commit loop, 6 rounds, all actionable fixed)

r1 zero-hero fallback hole + probe dedupe flip-flop; r2 test frame-read race +
cover-gate duplication; r3 focus-panel seed churn; r4 hero-empties latch (BUG-42
evidence) + stale xcstrings debug key; r5 mount-time double log + morph-collapse
test oracle; r6 zero-hero-source Settings caption + mid-morph-snap documentation.
**Recorded keeps:** `controlRow`/`chip` pane-local copy (established pattern); no
play/pause handler for CW/Upcoming-focused hero trailers (matches the FEAT-25 v1
keep); latched suppression after a permanent mid-session hero-source loss
(self-heals at relaunch; documented in code).

## Mac gate record (2026-08-21, this session)

**Codex round 1** (`review --base dcd84a69 --scope branch`): clean — "No actionable
correctness regressions" across logic, settings wiring, xcstrings, and the UI test.
**Codex round 2** (`adversarial-review`, focused on the latch, slot exclusion, coverage
gates, Search regression, and test vacuousness): two findings.

- **Taken — test37 could pass on carousel autoplay.** The hero leg never forced
  `hero_trailer_autoplay` off and never asserted the focus claimant, so a sim whose stored
  settings had Autoplay Hero Trailer on could satisfy the `hph` oracle with FEAT-25's
  carousel attempt. Fix: `-hero_trailer_autoplay NO` on both legs; hero leg asserts
  `src=f` and a non-empty `fitem=` before reading the phase. The XCTSkip paths on
  `focusedButton == nil` stay — that is the 27.0-runtime `hasFocus` contract, not a gap.
- **Kept — transient hero-empty "zero claimant" interval.** Codex argued a BUG-42
  nonempty→empty→nonempty refresh leaves the focused title with neither surface while the
  latch holds. Verified against `displayHero`: with Show Hero on, an empty fan-out returns
  nil and unmounts the WHOLE hero header (artwork included) regardless of this feature —
  that is pre-existing hero-empty behaviour. The feature's only delta in that window is
  "posters don't morph", which the latch doc already accepts as fail-soft (the
  alternative — unlatching on empty — is the nonempty→empty re-branch the latch exists to
  prevent). Codex's remedy (keep a synthetic hero surface mounted through the empty) is a
  BUG-42 change, out of this feature's scope.

**Sim run 1:** `test01InlineTrailerDwell` PASS (65s). `test37TrailerLocationHero` FAIL on
the hero leg — `src=f fitem=tt14403504 tloc=h` but `hph=idle` through the poll. The app
log (`[TrailerPipeline]`) showed why: the walk's 0.8s press gap stretched to 2.0s on one
intermediate card, whose hero attempt (hero mode arms on EVERY committed row focus, CW
cards included) fired its dwell and took the single extraction slot; the destination
card's dwell was `beginExtraction refused held=2.2s` and, by the pipeline's
skip-don't-queue design (BUG-46), never retried. Poster mode behaves identically for two
posters focused ≥1.2s apart inside one extraction window, so this is not a branch
regression — but hero mode widens the exposure to rows whose cards never morph (CW).
**Hardened the test, not the app:** if the first attempt idles through the poll, wait out
the slot (3s), re-focus right→left with 0.3s gaps, and judge that attempt — still
asserting the poster never grows during it. Device-pass item 3 should judge the feel of
the refused-attempt case (pause on a CW card, move to a poster within ~3s).

**Sim run 2** (hardened test37): hero leg PASSED via the retry path — and the refused first
attempt recurred identically (intermediate `tt3908634` commit, destination refused 2.6s
later), so in this walk it is systematic, not a one-off; the nudge's neighbour held focus
0.33s (no dwell), the retried attempt was granted → `claimPlayback` → `hph=exp`. Poster leg
FAILED on the width oracle: the morph DID fire (`claimPlayback` at +3.7s after focus), but
both fixed samples (+1.4s, ~+3s) landed before it; run 1 passed only because its second
sample drifted past the same 3.66s resolve. Test-only fix: poll the peak width at 0.5s
through an 8s window (test01's own morph window is 8s+); peak oracle unchanged.

**Sim run 3:** hero leg PASS (retry path again); poster leg still FAIL at peak=220 across
the whole 8s poll — while the exported `37b_poster_02_after_dwell` screenshot shows Last
Breath as a full landscape trailer tile with the row pushed right, and the log shows
`claimPlayback` at +3.6s. So the focused Button's AX frame never follows the morph (the
card body is `accessibilityHidden`; the Button's reported frame stays the resting
220×330) — run 1's pass was the `hasFocus` sweep matching some other element. Oracle
replaced: the morph pushes the focused card's row NEIGHBOURS right by the
landscape−portrait delta (~170pt), so the test now tracks the peak rightward shift of the
nearest right-hand neighbour's `minX` (same vertical band). Hero leg asserts ≤12pt shift,
poster leg >20pt.

**Sim run 4:** hero leg PASS end-to-end on the new oracle (neighbours static at 388/636/884
through the whole poll; retry → `hph=play`). Poster leg hit a harness race:
`allElementsBoundByIndex[n].frame` re-resolves by index and the morph re-shuffles the lazy
row tree mid-poll ("No matches found for Element at index 13"). Fix: frames now come from
one consistent `app.snapshot()` walk (`buttonFrames`), no index re-resolution.

**Sim run 5: test37 PASSED** (96s) — but a margin pass on the poster leg: its baseline
neighbour read 693 (resting is 388), i.e. the morph was already in flight when the
baseline was taken. The log shows the morph starts at the DWELL (+1.0s after focus; the
tile expands to `expandedStatic` before resolution), and the 0.8s press gap plus the slow
`focusedButton` `hasFocus` sweep straddled it. Fix: the baseline is now ONE immediate
`snapshot()` 0.3s after the final press (focused card via the snapshot's own `hasFocus`
flag + its neighbours from the same read; `buttonSnapshots`), no separate sweep.

**Sim run 6:** baseline now truly resting (neighbours 388/636/884 on both legs) and — a
welcome side effect — with the final press 0.3s after the third, the intermediate card
never dwells, so the hero leg's first attempt went through directly (no refused-slot
retry). Poster leg FAILED on a filter bug: the immediate baseline lands while the row is
still sliding up into place (focused y=711 vs its 648 rest), so a vertical band anchored
to the baseline's midY rejected every later neighbour (`neighbour=-1`). Fix: the band is
anchored to the focused card's position in each sample's OWN snapshot; only minX feeds
the oracle, which is scroll-independent.

**Sim run 7: test37 PASSED (90s) with a clean signal** — poster leg neighbour shift
366.5pt from a resting 388 baseline; hero leg 0pt shift through the whole poll, first
attempt refused again this run (the cadence is intermittent — run 6 didn't need the
retry, run 7 did) and the retry landed `hph=exp`. Run 8 = back-to-back confirmation with
test01 (below).

**Sim run 8 (confirmation, test01 + test37 back-to-back): both PASS** — test01 69s,
test37 81s (poster shift 366.5 / hero 0, retry path exercised). Test hardening committed
as NuvioMobile `2dd6bf81` on `claude/trailer-playback-location` (pushed). **Codex round 3**
runs against that head.

**Codex round 3** (`2dd6bf81`): one P3, taken — with "Hero" selected, the parent
"Trailers on Focus" toggle's enabled subtitle still said posters play the preview. Fixed
in `cf306e09`: the summary names the surface the picker selects (new catalog key,
de/es/fr/it/vi); the two fallback captions still explain when "Hero" can't take effect.
**Codex round 4** (`cf306e09`): two P2s. **Taken** — the new summary claimed "hero" even in
the fallback configurations (classic layout / no hero source) where posters keep playing;
`aa57a8d6` adds `heroLocationEffective` (the complement of the two captions) and the summary
uses it. **Kept** — "test37 can skip on landscape catalog rows": `XCTSkip` reports SKIPPED,
not passed (Codex's "both legs pass" is wrong), the message names the cause, and that is
the house pattern for fixture-dependent guards (`catalogLandscapeModeEnabled` is a
profile-scoped payload with no argument-domain override); the FA87 fixture is portrait.
**Codex round 5** (`aa57a8d6`): **clean** — "No actionable correctness defects"; gate closed
at 5 rounds. The device build was re-installed at that commit mid-pass (Settings-only
change; items 1–3 were judged on `cf306e09`, item 4 onward on `aa57a8d6`).

## Device pass results (2026-08-21, Living Room Apple TV, Debug build via devicectl)

- Item 1 (Codex gate): rounds 1–5, see above.
- Item 2 (sim): test01 + test37 PASS back-to-back (run 8).
- Item 3 (hero playback feel, Search still morphs, CW→poster handoff feel): **PASS**.
- Item 4 (mute via play/pause on the focused poster, no hero glyph): **PASS** — with a
  follow-up wanted: play/pause should also mute CW/Upcoming-focused hero trailers. Backlog
  item for a later branch (the v1 keep stands for this one).
- Item 5 (FEAT-25 coexistence: carousel autoplay, focus takeover, unfocus handback after
  grace + dwell, seamless same-title handoff): **PASS**.
- Item 6 (coverage: Detail push, tab switch, CW stream picker silence the hero trailer;
  return re-dwells): **PASS**.
- Item 7 (classic layout fallback: caption + poster-wording summary in Settings, posters
  morph, hero silent): **PASS**.
- Item 8 (cold-launch latch flip): **PASS with notes** — the snap-closed of an in-flight
  poster morph when the hero fan-out lands is visible on EVERY cold launch when a poster
  is focused early (not rare as hoped). Tolerable for v1 (the keep stands: once per Home
  lifetime, player released cleanly, trailer re-dwells on the hero), but a candidate
  follow-up: animate the collapse, or hold the morph until the fan-out resolves.

**Follow-ups recorded (not this branch):** play/pause mute for CW/Upcoming-focused hero
trailers (item 4); animated/withheld collapse at the cold-launch latch flip (item 8); hero
mode's refused-slot exposure on CW cards — consider retrying the focused title's attempt
when the extraction slot frees (item 3 / sim runs 1–8).

**beta.15 update (2026-08-23):** the refused-slot *exposure* is resolved by SUPPRESSION, not
retry — `beginExtraction` is now consulted before any visible morph, so a refusal never puts a
landscape tile on screen to snap back (`311e4096` + `01f60618`, tester BUG-73). Retrying the
focused title's attempt when the slot frees stays OPEN for beta.16 (a waiter list is the
queueing BUG-46's skip-don't-queue design exists to prevent — decide deliberately, not as a
patch). Item 8's snap-close also became much rarer as a side effect (the morph starts later and
only with something to play) but its animated-collapse fix is NOT done.

## Device-pass checklist (Christian, before the pointer bump)

1. Codex gate on the Mac (`--base dcd84a69 --scope branch`), rounds until clean.
2. `test37TrailerLocationHero` + `test01InlineTrailerDwell` on the sim.
3. Hero location feel: browse posters — trailer starts in the hero ~1.2s after
   focus rest (0.2s commit + 1s dwell); poster never morphs; Search still morphs.
4. Mute: play/pause on the focused catalog card toggles hero-trailer audio (no
   glyph on the hero — FEAT-25 v1 keep). CW/Upcoming-focused hero trailers have no
   play/pause (recorded keep — judge whether v1 acceptable).
5. FEAT-25 coexistence: Autoplay Hero Trailer ON + location hero — focus plays the
   focused title, unfocus hands back to the carousel title after grace + dwell;
   same-title handoff continues seamlessly.
6. Coverage: Detail push / tab switch silences the hero trailer; return re-dwells.
7. Classic layout fallback (Nuvio-Style off): poster morph, caption in Settings.
8. Cold-launch race: focus a poster before the hero fan-out lands — the one-time
   latch flip may snap an in-flight morph closed (documented keep) — judge feel.

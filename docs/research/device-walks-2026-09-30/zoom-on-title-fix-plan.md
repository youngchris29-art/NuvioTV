# Zoom-on row title fix plan (BUG-87/89), 2026-09-30

## 1. Root cause (zoom on, walk1z `L403c0p0r0z0t37`)

### 1.1 The geometry
Numbers are for Large 403.3, captions off (Hide Titles), carousel, system font (title 38).

- **Plan:** demand 112.3. Bottom reach 44 â 24 (â20). Top reach 88 â 86 (floor = 48+38â24+20+4 = 86). Hero compression 70, which is the carousel's full give (logo 32 + synopsis 36 + slack 2).
  - vh 525 (matches `vh=525`), link frame 513.3, restRange 11.7.
- **Clearance:** 24 at rest, 4 with the focused card lifted (lift 20). So `bandLo` = â4 and `bandHi` = min(48, 48+525â492â8) = 48. Matches the log (`clearance=24 clearanceLift=4 bandLo=-4 bandHi=48`).
- **Walk6b (No Zoom, hold on):** same plan (reach 86, vh 525) but lift 0, so the focused clearance is 24 and `bandLo` = â24.
- **Engine rests match.** Rest offsets on the same rows are identical within Â±1:
  - walk6b: 1203, 1763, 2311, 2872, 3432, 3992, 4553, â¦
  - walk1z, before correction: 1762, 2310, 2871, 3431, 3991, 4552, â¦
  - The engine's rest is a fixed function of each row's frame. It does not depend on earlier corrections: after row 4 was corrected to margin 0 (y=1750), row 5 still came to rest at â11 (y=2310).
- **Title lines at rest (every middle row, both walks):** `margin=-12 slide=12 net=0`. The title is fully visible and pushed 12 pt down.
  - walk6b: lifted intrusion â12. Clean, in band, never arms.
  - walk1z: lifted intrusion +8, because the lifted poster top sits 8 pt inside the title's line box.
  - The belt arms at >4 (13:24:06.386 `belt arm â¦ intr=4`) and fires ~0.7â0.8 s after motion stops.
- **Conclusion:** zoom on fails because the lift uses up the 20 pt of band that makes the hold work in No Zoom.
  - The bottom 8 pt of the title (the overlap Christian sees) is covered by the lifted poster.
  - The belt then hides the title (the fade).
  - Whenever the corrector is active, it pulls the row back +12 (the bounce).

### 1.2 The "creep" is the engine's own tail
Example: snoak_top100_series.
- Margin 0 at 13:24:06.219, then â2, â4, â¦ â12 by 06.555, in 1â2 pt steps every 17â120 ms (y 4539 â 4552).
- Steps are below `driftTolerance` (4), so the settle debounce treats this as stillness. The settle fires at 06.680, while the tail is still running (the last +1 pt step is at 06.753).

### 1.3 Why the corrector acted only 15 times and then stopped
- **Rows 4â8 (Down):** `collection-hftcv0ta`, `recs_series_for_you`, `recs_because_movies`, `recs_because_series`, `snoak_top100_movies`. Each settled at â11/â12, nudged +11/+12, and landed (REST margin 0).
  - Example: y 1762 â 1750 in 250 ms at 13:23:53.6â53.86.
  - These are the bounces. The belt armed but recovered before its 0.7 s.
- **Row 9 `snoak_top100_series`:** 13:24:06.680 `nudge=12`, target 4540. The offset never moved toward it (4552 â 4553 at 06.753; REST 4553 at 07.162).
  - The engine's last tail step overrode the `scrollTo(y:)` animation (`BrowseComponents.swift` ~L3971â3977).
  - At 07.455 the next settle saw landed â13 against from â12. That is within `pullBackTolerance` 4, so it logged **PULLBACK count=1** plus standdown. The belt fired at 07.195.
- **Stray Up press, 13:24:14.** The ladder moved focus via `recs_because_series` and back to `snoak_top100_movies`.
  - The direction tracker (`noteSettle`) saw a +560 hop, so direction stayed +1.
  - 16.239 `nudge=11`, again never applied (3991 â 3992) â **PULLBACK count=2** â **DISARMED-PULLBACK** at 16.945 for direction +1.
- **From then on**, every settle is `nudge=0 disarmed=1`. Those lines do not reach the console, because only the correction branch prints (`BrowseComponents.swift` L3635; the pane mirror at ~L3961 is pane-only).
- **Up walk:** REARM-DIRECTION fired only at 13:26:23 on `upcoming`, so corrections stayed off for the whole up walk. It is unclear whether the ladder-driven settles ever reached `noteSettle`; the `focus-hop` / `external-scroll` re-arm paths need checking.
- **The 15 lines:** middle rows 7 (5 landed, 2 never applied), Continue Watching 2, Upcoming 3, `collection-erfs5gwk-community-2` 1, `recs_movies_for_you` late content 2 (458, then 238).

### 1.4 Quantified (walk1z)

| | Down | Up |
|---|---|---|
| Middle-row rests | 31 (5 at margin 0 after correction, 26 at â12) | 11, all at â12 (ladder moved 2 rows per press, REST Îy â 1120) |
| Belt fires `reason=rest` | 30 middle rows, plus 1 on the stray Up press and 1 on the last row after 11.8 s idle | 10 |
| Time from motion stop to fire | 700â823 ms | 704â751 ms |
| Press to fire | â1.55â1.65 s (e.g. 13:24:20.281 â 21.875) | â2.0 s (ladder) |
| Margin 0 to fire | â1.0 s | â |

Total fires: 42.

### 1.5 The other walks
- **Walk1 (No Zoom, hold off, reach 66):**
  - Rests at â21..â23 on every middle row in both directions.
  - 62 `UNEXPECTED-WITH-FIT`: +21..+23 nudges, all landed (e.g. y 1152 â 1130; `VOID` lines are content-height changes).
  - 1 PULLBACK, at the last row only.
  - 2 belt fires, both trakt-trending (last row) at 10â11.7 s idle. The "fades at rest after ~10 s" in the brief are last-row only.
- **Walk6b:** middle rows at â12, lifted intrusion â12, 0 fires, 5 settle lines (edges only).
  - Brief says the up walk rests at ââ2. My extraction shows â12 in both directions (â20 on one collection row); re-check.
- **Engine rest vs top reach** (device, and sim per test61's notes): reach 66 â â22, reach 86 â â12, i.e. about +0.5 margin per point of reach.
  - No single anchor on the frame, title or artwork explains both points; it is an empirical law from two points only.

## 2. Fix options
Shorthand for Large, system font, carousel, zoom on, top reach R:
- At-rest clearance = R â 62; focused clearance = R â 82; `bandLo` = 82 â R.
- Lifted intrusion = âm â (R â 82), where m is the rest margin.
- Belt arms when lifted intrusion > 4. The Â±2 in-band slack applies to the band.

Predicted rest by reach (slope 0.5 case / flat case):

| R | Rest m | `bandLo` | Lifted intrusion | Result |
|---|---|---|---|---|
| 86 (today) | â12 | â4 | 8 | arms, fires |
| 88 (today's cap) | â11 / â12 | â6 | 5 / 6 | still arms |
| 90 | â10 / â12 | â8 | 2 / 4 | not armed; in band only in the slope case |
| 92 | â9 / â12 | â10 | â1 / 2 | in band either way, never arms |

### A. Zoom-on reach hold (recommended)
**What changes**
- `PinnedRowGeometry.plan` (~L471â528):
  - Add a zoom-on park allowance: `floorLift = lift + zoomHold` with `Theme.Size.heroPinnedRowZoomReachHold = 6`.
  - Add a separate cap `heroPinnedRowTopReachHoldCap = 92` via a `cap:` parameter on `topReachFloor`.
  - Let the top reach exceed the base 88: `topReach = max(88 â topSpend, topFloor)`, and push the extra into `short`.
  - If the result does not fit, fall back to the unheld plan.
- `FocusModeFlags` (`BrowseComponents.swift` ~L335â375): new `zoomReachHold` (About A/B "Zoom Row Reach", default ON) with `zoomReachHoldEffective = zoomReachHold && !noZoom`. `regimeKey` appends `hz` only when it is active (same pattern as `h1`).
- Clearances, band, last-row floor and bottom inset all follow automatically from the plan.

**Geometry at R=92**
- Large carousel: compression stays 70 (the hero's give is already spent), so no synopsis or logo change. Link frame 519.3, restRange 5.7, at-rest clearance 30, focused 10, band [â10, 48], bottom inset 60 + 5.7 + 96.
- Large panel (Show Hero OFF): +6 compression via tier 3; synopsis slot 87.67 â 81.67, still 2 lines.
- Medium+ carousel: compression 38 â 44; the logo gives 6 more; synopsis already at its 1-line floor.
- Open Sans: wants 90.2 + 6 = 96.2 but is capped at 92, so only partly fixed. Note it and measure.

**What it removes:** overlap, fade and bounce. The engine's own rest lands in band, so there are no corrections and no belt arms (the No Zoom hold's mechanism).

**Risks and bans**
- No scroll, no retry, no budget change, nothing on hero focus gain: cleanest against the standing bans.
- Real risk: a top reach above 88 is outside the proven 72â88 range (reach 100 broke focus resolution; the reach-64 warning in the 09-06 entry). A taller upward reach overlaps the row above and can hurt Up resolution, which the ladder already patches.
- So gate it on:
  - a sim reach sweep;
  - the BUG-112 up-walk test;
  - one device walk.

**Interaction with the No Zoom hold:** none. z1h1 keeps reach 86 (band â24, rest â12, 12 pt spare). Do not add the +6 to No Zoom; it would only cost restRange.

### B. Belt and band tolerate lift-only intrusion
**What changes**
- `PinnedRowTitle.reading` (~L592â652): for the focused row, when `overshoot <= 0` and the unlifted intrusion `slide â atRest <= 0`, arm at `fadeIntrusionArm + liftOnlyTolerance` (8â10) and recover at `â¤ liftOnlyTolerance`.
- `settlePlan` band (~L3370): `bandLo = âmin(clearance.focused + liftOnlyTolerance, clearance.atRest)`.

**Geometry at R=86:** band [â12, 48]; rest â12 in band; lifted intrusion 8 â¤ 12; no nudge, no fade; no hero cost.

**What it removes:** fade and bounce. The overlap stays: the lifted poster covers about 8 pt of the title's line box, which is the descender zone, visible on g/p/y and bright artwork.

**Risk:** partly walks back the Codex r4 P1 / BUG-84 rule that the title is never on the focused artwork, though bounded at 8â10 pt against the 20 pt r4 rejected. test48 must still pass. No effect in No Zoom (lift 0).

### C. Make the corrector act (and not falsely disarm) before the belt
**What changes**
- (i) Fire a correction only after the offset has not moved at all for â¥ 120â150 ms (the engine's tail is done), not merely "under 4 pt".
- (ii) In `settlePlan` (~L3204), track progress toward the target since the correction fired (sampled in `noteScroll`). If progress is under 25% of the correction, log `DROPPED`, not PULLBACK.
  - Do not call `notePullBack`.
  - Allow at most one re-issue within the same rest. It is cancelled by any focus or epoch change, spends the window budget, and is never refunded.
- (iii) `PullBackLedger`: take direction from row order, not offset delta, so a ladder anchor hop cannot mislabel an Up press.
- (iv) Print every settle decision to the console under the probe flag.

**What it removes:** fade, and the overlap at rest. But it makes the +12 bounce happen on every row, which is the walk1 symptom Christian rejected, just smaller.

**Risk:** (ii) is closest to the "no delayed retries that fight the next press" ban. It must stay within the same rest and be cancelled by the next press. It never replaces A or B, but (ii) and (iv) fix a real misclassification: two correction attempts that never applied turned into 26 fades.

### D. Per-regime device park-offset constant
**What changes:** a table `E(regimeKey)` of calibrated engine rest margins. From these logs: L403 z0 R86 = â12; z1 R66 = â22; z1h1 R86 = â12. Used by `plan` to pick the reach (feeds A) or by `settlePlan` to set expectations.

**What it removes:** nothing on its own; it is the calibration input for A or B.

**Risk:** brittle. Medium+, Open Sans and the panel hero are unmeasured, and one constant would fail silently on the next engine or tvOS change. Better to measure the law with a sim sweep (the sim reproduces â22 at 66 and â12 at 86 per test61's notes) and encode it as a formula with a unit test. Unrelated to `heroPinnedRowsDeviceParkSlack` (96, the bottom inset).

### Recommendation
1. **Step 0 (sim, 1 session).** Add a DEBUG override `-debug.pinnedTopReachOverride N`. Run test61-style walks at R = 80/84/86/88/90/92/94 in zoom on and No Zoom, recording rest margin, `bandLo`, lifted intrusion and Up/Down resolution. Confirm the slope, and that R=92 keeps Up working (BUG-112 up-walk leg, `upFallback` count per press â¤ 1).
2. **Step 1.** Ship A behind the A/B toggle (default ON, key `hz`), plus C(ii) and C(iv) as hardening.
3. **Fallback.** If R=92 breaks Up resolution on the sim or the device, ship B with `liftOnlyTolerance` 8, capped at the at-rest clearance, and tell Steven a small overlap may remain.

## 3. Verification

### 3.1 Unit tests (`PinnedRowGeometryTests`, `PinnedRowSettleDirectionTests`)
- L403 t38 carousel zoom-on with hold: topReach 92, compression 70, restRange â 5.67, fits.
- Panel synopsis lines stay 2.
- Medium+ compression 44.
- Open Sans capped at 92.
- No Zoom h1 unchanged (86 / 11.67).
- Hold off byte-identical, and the regime key is unchanged when off.
- A correction that never moved is classified as DROPPED and does not increment `pull`.
- A ladder anchor hop does not flip direction.

### 3.2 Sim UI test
New `test64ZoomReachHold`, cloned from `test61NoZoomReachHold` (`NuvioTVUITests.swift` L6446).
- **Fixture:** add `FixtureSetupTests` testSetNoZoomOff / testSetNoZoomOn. The fixture persists No Zoom ON, and test61's doc warns that the `-no_zoom_on_focus` launch argument gives an inconsistent state.
- **Assert on every walked middle row:**
  - regime contains `z0` and ends with `hz`;
  - `debug_env` topR = 92 and slack 6 Â± 2;
  - `bandLo` â10 Â± 1, focused clearance (`clearanceLift=`) 10 and its unclamped value (`clearanceLiftRaw=`) 10, `lift=20`;
  - no `UNEXPECTED-WITH-FIT`.
- Because the sim reproduces the â12 rest, hard-assert `inBand=1 corrN=0 pull=0 pbDisarm=0 beltFaded=0` (unlike test61's soft gate).
- **Control leg (hold off):** assert `bandLo` = â4 and that the zoom-on symptom reproduces (`beltFaded=1 beltFadeReason=rest` or `UNEXPECTED-WITH-FIT` at margin â â12). This is the first sim reproduction of Steven's config.
- **Re-run:** test48 (the belt still hides uncorrectable titles under `-debug.pinnedHeroCompressionOff`), test58 (last-row frame floor = max(519.3, 501); check any slack expectation), test61, and the BUG-112 up walk.

### 3.3 Next device walk
Christian's ATV, Debug, Steven's config, toggle ON; slow Down to the last row, then Up.
- **Console:** `REGIME â¦ L403c0p0r0z0t37hz`.
- **Title lines at rest:** `margin` in [â12, â8], `slide` â¤ 12, `net=0`, lifted intrusion (`intrLifted=`) â¤ 2 on every middle row.
- **Counts on middle rows:**
  - `UNEXPECTED-WITH-FIT`: 0 (was 7);
  - `belt fire reason=rest`: 0 in both directions (was 40);
  - `PULLBACK` / `DISARMED*`: 0;
  - `belt arm` at rest: 0 (arms while moving must be followed by `recover`).
- **No bounce:** no REST y change in the 1.5 s after REST (â¤ 1 pt).
- **Up walk:** REST Îy â 560 per press (one row; confirms `aae1aadf`).
- **Repeat:**
  - at Medium+ (P351, unmeasured) with the same criteria;
  - a No Zoom hold regression walk, which must match walk6b (0 fires, 0 corrections).

### 3.4 Ask Steven
On the new build, with Large + Hide Titles + Show Hero carousel + Zoom ON + system font, and then Medium+:
- walk 10 rows down and back up slowly;
- (1) did any row title fade away?
- (2) did any title touch or sit under the top of the focused poster? (Send a close photo of a focused row whose title has g/p/y.)
- (3) did any row jump after it stopped?
- (4) does one Up press move exactly one row?
- Send a photo of About â Row Settle after the walk.

## 4. Secondary findings (log, don't fix now)
1. **Late-content rows.**
   - walk1: margin 538â540 settles on 5 rows, each followed by two â220 nudges (540 â 320 â 0), and 5 `standdown reason=budget` on the following rows. walk1z: `recs_movies_for_you` 458 â 238.
   - The settle fires at 0.25 s before the engine has scrolled (y still the previous row's REST), so the corrector does the engine's reveal in 220 pt steps and uses up the next row's budget.
2. **Short top rows park low.** Continue Watching rests at +54..56 (> `bandHi` 48, â10 nudge). Upcoming rests at +160..161 (â117 nudges, twice on one up walk, corrN=2). Both are visible jumps at the top of every walk.
3. **A correction that never applied is logged as a pull-back** (13:24:06.680, 13:24:16.239). The `scrollTo` animation loses to the engine's final tail step.
4. **Direction tracker.** It mislabels ladder anchor hops, and it did not re-arm until the top row. The `DISARMED-PULLBACK` text says "session" but the disarm is per direction.
5. **Console coverage.** The console only prints correction settles; in-band and disarmed settles are pane-only, which made walk1z look like the corrector was idle.
6. **Last-row idle fade.** trakt-trending fades 10â12 s after motion in walk1 (Ã2) and walk1z (Ã1). The belt flips between armed (intrusion 9) and recovered (â11) 36 ms apart, i.e. the lifted/unlifted 20 pt switching, which suggests focus state flickering on the last row.
7. **Up walks moved two rows per press** (REST Îy â 1120 in walk1z and walk6b). This is the double-consumed press targeted by `aae1aadf`; up-walk data in these logs is affected by it.
8. **The engine's rest is a fixed function of each row's frame** (identical y across walk6b and walk1z), so the sim is a valid oracle for rest margins. It has not yet been used for zoom on.
9. **Brief discrepancy.** My extraction shows walk6b's up walk resting at â12, not about â2 (one collection row at â20). Re-check before quoting.

### Critical files for implementation
- /Users/christianturnbull/Claude/Projects/Nuvio tvOS/NuvioMobile/iosApp/NuvioTV/DesignSystem/PinnedRowGeometry.swift (`plan` L438â543, `topReachFloor` L291, `regimeKey` L583)
- /Users/christianturnbull/Claude/Projects/Nuvio tvOS/NuvioMobile/iosApp/NuvioTV/Screens/BrowseComponents.swift (`FocusModeFlags` L335â375, `reading` L592â652, `PullBackLedger` L2145â2238, `settlePlan` L3076â3637, correction apply L3971)
- /Users/christianturnbull/Claude/Projects/Nuvio tvOS/NuvioMobile/iosApp/NuvioTV/DesignSystem/Theme.swift (L593 TopPad 88, L689 lift 20, L708 budget 455, L783 compression cap, L823 park slack 96)
- /Users/christianturnbull/Claude/Projects/Nuvio tvOS/NuvioMobile/iosApp/NuvioTVUITests/NuvioTVUITests.swift (test61 L6446, test48 L5391, test58 L5763)
- /Users/christianturnbull/Claude/Projects/Nuvio tvOS/docs/research/device-walks-2026-09-30/walk1z.log.gz (evidence; key lines 13:23:53.589, 13:24:06.680â07.455, 13:24:16.239â16.945, 13:26:23.848)"}},"serverClassifierRequest":"71d344d8-c275-4d12-9f62-53a655cdf8f3","apiBlockIndex":1,"requestId":"req_011Cfa2vfGi4zKuC2iHTaZC9","attributionAgent":"Plan","type":"assistant","uuid":"0d749465-464f-426e-9b6b-03d991f2d5b6","timestamp":"2026-09-30T17:42:45.178Z","advisorModel":"claude-opus-5-5","effort":"medium","perTurnEffort":"medium","userType":"external","entrypoint":"claude-desktop","cwd":"/Users/christianturnbull/Claude/Projects/Nuvio tvOS/NuvioMobile","sessionId":"b7abbb6f-5908-4bda-ba49-4d6affe99163","version":"2.1.284","gitBranch":"main","slug":"lets-make-a-plan-dynamic-moth"}

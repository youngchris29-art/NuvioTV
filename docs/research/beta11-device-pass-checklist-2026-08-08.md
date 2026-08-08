# beta.11 device pass — 2026-08-08 (Living Room Apple TV)

Build under test: Release, `tvos-shared-extraction` @ `d8c06127` (one Simkl poster-res port past
the suite-gated `b8c4e60c`; suite 54/54 ×3 incl. tvOS 27.0 ran at `b8c4e60c`).
Launch is instrumented: `-debug.trailerProbe YES -debug.homeScrollProbe YES`, console streamed to a log —
narrate what you're doing out loud order doesn't matter, but tell me when you start/finish each item.

## A. The P0 headline — BUG-47 eject + UX-13 restore (See All lifecycle)
1. Search for anything → open **See All** from a results row → press **Back**.
   - Expected: returns to search results, app stays alive. Repeat ×3 (the test23 cycle, now on hardware with real swipes).
2. In any See All grid: scroll deep → open a title → press Back.
   - Expected (UX-13): grid returns to the same position with focus on the card you left, not the top.
3. Force the empty-state path: open a See All that renders empty (search See All still drops the query — BUG-48, known, ships broken).
   - Expected: a focusable **Go Back** control exists, Back exits cleanly — **no eject to the tvOS home screen**.

## B. 90-second [TrailerPipeline] browse (BUG-46 instrumentation)
- With inline trailers ON, browse Home for ~90s letting focus trailers start/stop across rows.
- I'll watch the console for `[TrailerPipeline]` attach/teardown pairing and `live≤1`. You just browse; flag anything that goes black-and-collapses (the BUG-46 signature).

## C. UX-9 scope trailer — "Lucky"
- Focus the **Lucky** card (CinemaScope 2.34:1 source) until its inline trailer plays.
  - Expected: fills the card edge-to-edge (computed per-item zoom ≈1.34), no top/bottom bars.
- Control: a 16:9 trailer (e.g. Futurama) still edge-to-edge, not over-cropped.
- NOTE: do NOT claim UX-9 fixed in the notes unless this passes — two prior failed claims.

## D. White-accent / contrast sweep (BUG-45 / BUG-49 / BUG-50 / BUG-40)
- Switch to **White** theme + White accent, then:
  1. Settings sidebar focused rows — readable? (BUG-45 sidebar half)
  2. Settings → Home Screen (Écran d'accueil equivalent): focused **Hero style Nuvio** toggle row — readable? (BUG-45 content-pane half; sim test25 says correct, this is the hardware confirm)
  3. Collections **TabChip** row — readable? (BUG-49)
  4. The six formerly raw-palette surfaces outside Settings (BUG-50) — spot-check a couple.
  5. FEAT-14 accent focus ring with a near-white accent — ring visible? (BUG-40 fallback)

## E. Authenticated credential round-trip (provider-credential sync, upstream 24971f4a port)
1. Signed in: set/change the **TMDB key** on the device → confirm it lands in Supabase (I'll verify the row from here if you tell me when).
2. With a **debrid key stored locally**, trigger a sync pull.
   - Expected: remote-wins pull does NOT blank the local debrid key (AllDebrid gap was the caught defect).

## F. BUG-30 residual — classic-mode top rest (measured, not eyeballed)
- Classic hero mode: D-pad walk deep down Home, then walk back up to the top.
- I read the probe's `REST classic` residual from the console: **0 ≈ fixed; 67 unchanged = CTA restyle next round** (`0ad450b6` explicitly not claimed fixed until this number moves).
- Also glance: tab bar not clipped at top after the up-walk.

## G. BUG-37 pinned-mode title check (probe read)
- **Hero style Nuvio ON** (pinned): scroll down past **Genres** and **New Movies**, back up, rest.
- You eyeball: row titles present at rest. I read per-row margin/slide/net from `[HomeScrollProbe]`.

## H. Batch spot-checks (quick)
- BUG-35/42: cold-start Home — hero commits ONCE (no English→localized text swap mid-flight).
- BUG-36/31: whole-card focus lift back everywhere; `no_zoom_on_focus` option works if toggled.
- BUG-38: Genres/collections row tiles have cover art (not flat gradients); collection title logos render.
- BUG-39: Services GIF row still smooth (decode-at-tile-size didn't regress BUG-19's fix).
- FEAT-15: Show Hero OFF → focus-follow mode, Home degenerates cleanly to rows.
- Simkl: Settings → Simkl pane renders (PIN auth flow reachable; full sync optional today).

## Recording verdicts
Per item: PASS / FAIL / SKIPPED + one line. Fails get triaged before the cut; no blind re-fixes
of BUG-30 (six banned rounds) — the probe number decides.

---

## VERDICTS (recorded 2026-08-08 evening — full detail in the tracker's update-log entry)

- **A: PASS** — 3× See All→Back cycles + deep-grid restore, real swipes.
- **B: PASS** — probe-confirmed: live≤1 across 266 lines, 30 attach / 29 teardown (1 = still playing), no BUG-46 signature.
- **C: FAIL** — bars the whole time; measure correct (z=1.343 computed on the inline card), apply stomped: backing-layer transform re-asserted by SwiftUI layout. `applied=` log prints unconditionally; sim gate was log-only. Fix (dedicated sublayer) → beta.12. Notes stay silent on UX-9.
- **D: PASS** — BUG-45 both halves, BUG-49, BUG-50, BUG-40 ring.
- **E: FAIL → FIXED LIVE (`c642c083`, 4 Codex rounds) → PASS** — filed **BUG-51 (P1)**: AllDebrid entry (even blank) poisoned every push; sync dead for all users. Re-verified: push clean, TorBox survived, TMDB landed. (Adapted: no AllDebrid key on hand; TorBox survival substituted.)
- **F: FAIL (improved)** — most rests −157/0 (pre-fix: never), one walk-up at the exact −90/**67** → CTA-frame alignment confirmed → CTA restyle = beta.12 per the pre-registered rule.
- **G: PASS** at rest (margins 12–18pt, slide=0) — plus **BUG-53 filed**: lift/tilt occludes row titles while a row card is focused; candidate BUG-37 mechanism.
- **H: FAIL → FIXED LIVE (`f248ad39`) → PASS** — filed **BUG-52**: service tiles doubled wordmarks (BUG-38 overlay over branded covers); only H failure per Christian. Genres logos confirmed retained.

Builds: `d8c06127` (UUID CAEF63E8) → +sync filter (94332B16) → +logo fix (102A6673) → final rebuild at committed `f248ad39`.
Standing item surfaced: `register_current_device` → 22023 "Unsupported Nuvio client" every launch (BUG-51 row note).

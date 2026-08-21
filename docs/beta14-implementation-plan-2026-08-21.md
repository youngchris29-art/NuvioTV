# beta.14 implementation plan — task & model delegation (2026-08-21)

**Source:** `docs/issue-triage-plan-2026-08-21.md` (the 08-21 daily GitHub check's consolidated
triage). This document turns that triage into an execution plan: who does each task, **which
model tier runs it**, where it runs, and in what order. Scope decisions (what's in beta.14 at
all) are the triage doc's §7; this doc does not re-litigate them.

## Delegation principles (token efficiency)

- **The orchestrator session (Fable/Opus) plans, reviews, and integrates — it does not grind.**
  Subagents return diffs and structured summaries, never whole-file dumps, so the expensive
  context stays small.
- **Haiku 4.5** — mechanical, fully-specified text transforms where the spec *is* the work:
  tracker status flips, comms drafts from existing decided language, xcstrings key sync.
- **Sonnet 5** — well-scoped code tasks with an established in-repo pattern to copy: the
  diagnostics panes (BUG-42's Hero Paint Diagnostics is the template), the contrast-class fix +
  sweep, the tracker guard script, the `:shared` JVM target (verifiable by running Gradle in the
  remote Linux environment — a rare shared-code task with a real feedback loop off-Mac).
- **Opus 5 / Fable** — anything architectural, ambiguous, or with public blast radius: FEAT-25
  (publicly committed, touches the Home hero), the BUG-30/66 investigation design, final review
  before each push, release-gate judgment calls.
- **Escalate, don't pre-pay:** start each task at the cheapest tier that can plausibly do it;
  the orchestrator reviews the diff and only re-runs at a higher tier on failure. A Haiku miss
  costs pennies; defaulting everything to Opus costs the budget the sweep runs on.
- **Mac-only work is Christian's**, with the plan doing everything short of the device: code and
  diagnostics land review-ready from remote sessions; sim/device verification and the release
  cut happen on the Mac.

## Task board

| # | Task | From triage | Model | Runs where | Depends on |
|---|------|-------------|-------|------------|------------|
| **Wave 0 — comms (today, no build needed)** |
| C1 | GitHub #2 "fix is live in beta.13.5, please retest" reply (ask for named channels); GitHub #1 retest-hold clock (close-or-confirm after ~7 days) | §2 | Haiku draft → Christian approves → post via GitHub MCP | remote | — |
| C2 | Reddit comms block: BUG-38 alternate delivery channel, BUG-58/65 verdict ask, BUG-41 re-verdict ask, BUG-55 spinner-vs-nothing question, BUG-37 one-shot repro ask, BUG-62 follow-up | §4.2, §7 | Haiku draft (all decided language exists in the triage doc) → Christian posts | remote draft / Christian posts | — |
| **Wave 1 — diagnostics (build first, unblocks three P1s)** |
| D1 | `[TabBar]` diagnostics: scroll-geometry callback firing, reported offset, immersive depth, push/pop counter → Settings → About | §4.1 (BUG-30/66/62) | Sonnet (copy the BUG-42 probe pattern) | remote, code-only; sim check on Mac | — |
| D2 | Resolved `CardFocusMode` + both raw toggle values in the same About pane | §4.1 (BUG-64) | Sonnet (same PR as D1, trivial addition) | remote | D1 |
| **Wave 2 — the committed feature** |
| F1 | FEAT-25: hero trailer plays without focus, behind a setting, default off; reuse `InlineTrailerCard` extraction/reveal-gate machinery against `HomeHeroBackdrop` (`HomeView.swift:1395`) | §5, §7 | **Opus** (architecture + public commitment; no cheaper tier) | remote code; **device-verify plays-without-focus on Mac** | Christian: setting name/default (§9.2) |
| **Wave 3 — contrast-class sweep** |
| K1 | BUG-33 defect 3: recent-search chip (`SearchView.swift:102–108`) **plus** one sweep of remaining raw-palette-on-focus-platter sites — this class has shipped four defects; kill it once | §4.3 | Sonnet (fix + checklist-driven audit) | remote | — |
| K2 | BUG-40: verify White accent's ring path doesn't composite through an opacity/blend other accents escape | §4.3 | Sonnet | remote | — |
| **Wave 4 — infrastructure (no user-facing change)** |
| I1 | `:shared` `jvm()` target wired to `commonTest` (52/54 test files already there) + JVM actuals for storage/crypto expects | §6.1 | Sonnet, **verified by running Gradle in the remote Linux env**; escalate to Opus only if the expect/actual shims get hairy | remote, end-to-end | Christian approves build-graph change (§9.4) |
| I2 | Tracker hygiene: flip every "Fixed in code (unreleased…)" row whose build shipped → `Shipped (beta.N)` (BUG-34/44/49/50, UX-11/12/13) + matching dashboard ITEMS bucket flips | §6.4 | **Haiku** (pure text transform, closed list) | remote | — |
| I3 | `check-tracker.py` guard: no row may say "unreleased" for a build tag that exists as a published release | §6.4 | Sonnet (small script + wire into sweep instructions) | remote | I2 |
| I4 | `test24CatalogGridFocusRestore`: reset FA87 fixture sign-in state, re-run; bisect harness if still red; UX-13 device spot-check in same pass | §6.2 | **Christian (Mac-only)** | Mac | — |
| **Wave 5 — device pass, then cut** |
| V1 | BUG-30/66 device protocol: walk-up (BUG-30 shape), 10× push/pop (BUG-66 shape), read `[TabBar]` diagnostics after each; *only then* code the fix the data points to (stable scroll-view identity vs presentation) | §4.1 | Christian on device; follow-up fix Sonnet or Opus **depending on which branch the data picks** | Mac + Living Room Apple TV | D1 |
| V2 | BUG-64: photo of About pane with toggle ON → decides settings-state vs compositing | §4.1 | reporter + Christian; no code until then | device | D2 |
| V3 | Release gates 1–7 (triage §8), cut beta.14 | §8 | Christian, orchestrator assists | Mac | all above |

**Explicitly not in scope (unchanged from triage):** BUG-42 (awaiting photo), BUG-38 (awaiting
payload), BUG-37 (awaiting repro), FEAT-16, FEAT-3, both parked upstream items.

## Sequencing

Wave 0 fires immediately — it's pure comms and every day of silence costs goodwill (the lesson
of GitHub #1). Waves 1, 3, and 4's remote tasks (D1/D2, K1/K2, I1–I3) are independent and can
run as parallel subagents in one orchestrated session; each lands as a reviewed commit on the
work branch. Wave 2 starts once Christian answers §9.2 (setting name/default). Wave 5 is
Christian's device time and is the long pole — everything else exists to make that one session
decisive: the diagnostics ship *so that* the device pass answers "do the scroll-geometry
callbacks stop firing?" with data instead of an eighth blind fix.

## Decisions (answered by Christian 2026-08-21, except FEAT-3)

1. **FEAT-22** — ✅ **best quality, step down**: pick the highest quality the connection
   sustains, fall back a tier on buffering. Buildable when scheduled.
2. **FEAT-25** — ✅ **default off**, setting named consistently with neighboring toggles
   ("Autoplay Hero Trailer" shape). Wave 2 unblocked and started same day.
3. **BUG-37** — ✅ **downgrade to P3 and park** after one final screenshot ask.
4. **§6.1 JVM target** — ✅ **approved**. I1 started same day, verified by running Gradle in
   the remote session.
5. **FEAT-3 (TestFlight)** — still open: set a decision date, or say publicly it's not this
   cycle.

## Build progress (2026-08-21, remote session — NuvioMobile branch `claude/beta14`)

Committed as **batch 1** (`1be3bef` on `claude/beta14`, based on the beta.13.5 pointer
`36effd50`): D1+D2 (TabBar + BUG-64 diagnostics in Settings → About), F1 (FEAT-25 hero trailer
autoplay, default off), K1 (BUG-33 chip fix + ChipButtonStyle hardening + ~45-site sweep).
Written by delegated agents, reviewed here; one review fix applied (the probe's enable flag was
a latched `static let`, now a live read so the same-session toggle protocol works). **Not
compiled — no macOS in this environment.** K2 (BUG-40) concluded **no divergence**: the ring
path is identical for all accents, the original luminance-fallback fix already shipped in
beta.11 with a standing unit test; the reporter's grey is display-side (TV picture processing).
Recommend replying with that and closing BUG-40. C1 posted (GitHub #1 + #2, links in
`docs/comms-drafts-2026-08-21.md`); I2 shipped (tracker + dashboard + republish).

**Batch 2** (`4f7301a` on `claude/beta14`): I1 done — `jvm()` target on `:shared`, 55 jvmMain
actuals (SharedPreferences-shaped Properties store backing the ~35 storage actuals ported from
androidMain; clocks verbatim; functional HttpURLConnection network actuals). **Verified on
Linux: `:shared:jvmTest` = 52 classes, 432 tests, 0 failures, 0 skipped** — twice by the
implementation and once independently. Zero exclusions, zero weakened assertions; the two
NSUserDefaults-bound appleTest files stay Apple-only. The shared suite is now runnable by any
future remote session or CI. Every remotely-buildable task in this plan is now done; what
remains is Mac/device work (I4, V1–V3) and comms follow-through.

### Device-pass checklist for batch 1 (beyond the standing §8 gates)

FEAT-25 (from the implementation's own risk flags):
1. **Stop-on-push:** hero trailer playing → Select into a Detail page → listen. Teardown rides
   `HomeHeroBackdrop.onDisappear`; if that doesn't fire on a NavigationStack push, two trailers
   can be audible at once. Same question for a tab switch.
2. **Audio:** with `trailer_audio_default_on` on, Home now makes noise with zero user action —
   first surface that does. Confirm that's acceptable before the cut.
3. No play/pause handler on the hero (mute changes only via Settings) — accepted for v1, flag
   in the release notes.
4. One screenshot of the player under the nuvio-style gradient mask, both hero layouts.
5. The headline check: trailer actually starts with focus far from the hero.

Diagnostics: toggle Tab Bar Diagnostics ON, walk Home down/up, run 10 push/pop cycles, confirm
counters move (no relaunch needed).

Contrast: focused Recent Searches chip label is near-black on the platter; K1's three
device-judgment sites — `PlayerTopPanel.swift:144` and `MPVPlaybackTab.swift:218/222`
(`.secondary` detail text on default-styled buttons) and `ProfileSelectionView.swift:443/475`
(fixed `.red` destructive labels on chips) — eyeball on device, fix only if they wash out.

## Done alongside this plan (2026-08-21, this session)

- Triage plan doc merged onto this branch (fast-forward of the daily check's
  `claude/brave-cori-mvsdlv`).
- **`docs/beta-feedback-sweep-instructions.md` created** — the canonical sweep procedure both
  daily sweeps read, now covering **Reddit + GitHub issues + pull requests** (closes triage
  §6.3). Until this file reaches `main`, each Routine's own prompt carries the full GitHub
  step, so no sweep depends on the merge.
- Evening Routine ("NuvioTV Reddit feedback sweep — 7pm ET") prompt updated to include the
  GitHub issues/PR check and the mandatory GitHub digest line.
- **Morning sweep moved to the cloud**: new Routine "NuvioTV morning feedback sweep — 8am ET"
  (12:00 UTC, fresh session per fire) with the same Reddit+GitHub procedure, replacing the
  local scheduled task on Christian's machine (Christian deletes the local one).

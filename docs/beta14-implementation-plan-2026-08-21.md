# beta.14 implementation plan — task & model delegation (2026-08-21)

**RELEASED 2026-08-22: `tvos-v0.3.0-beta.14`, build 111, NuvioMobile `2e732534` (`tvos-shared-extraction` = `claude/beta14`).** Ships FEAT-25 (both halves), FEAT-26, BUG-38 folder-page hero, BUG-33 chip contrast, About diagnostics. Highlights: `scripts/release-notes/tvos-beta14-highlights.md`; Reddit block: `docs/comms-reddit-beta14-changelog.md`.

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

### Gate 2 (sim build) — ✅ GREEN in CI, 2026-08-21

`tvos-sim-build.yml` on `claude/beta14` builds the full app for tvOS Simulator on a GitHub
macOS runner (Xcode 26.6, tvOS 26.5 SDK) — the project's first build CI. Run 5
(`bf17ab1`) succeeded end-to-end: MPVKit submodule + SPM resolve, quickjs-kt `1.0.5-tvos`
built from the outer repo's scaffolding script into mavenLocal (cached on the patch hash),
`:shared` Kotlin/Native framework link, full Swift compile of both batches, arm64 app link.
Four failures were diagnosed and fixed to get there: missing MPVKit checkout, the buried
Gradle error (isolated into its own step), the mavenLocal-only quickjs artifact, and the
x86_64 slice having no Kotlin framework (pinned `ARCHS=arm64`, matching a dev Mac). Caches
are warm — subsequent runs are much faster. Still Mac-only: the UI suite (FA87 fixture),
device pass, release cut.

### Security review (2026-08-21, both batches + CI workflow + dashboard JS)

Full-diff review of `claude/beta14` (`36effd50..72a19c1`) plus the docs branch's dashboard
HTML/JS, tracing untrusted inputs (addon responses, TMDB data, tracker strings, CI event
context) to sensitive sinks. **No vulnerabilities found — zero HIGH/MEDIUM findings.**
Verdicts: Swift batch clean (trailer path adds gating only, probe is in-memory with hardcoded
labels); jvmMain actuals clean (0700 per-process temp dir, compile-time store names, no
exec/TLS-weakening/secret-logging); CI workflow clean (no untrusted input reaches `run:`,
write-access-gated triggers, no secrets); dashboard clean (all ITEMS strings render via
`textContent`, no `innerHTML`-class sinks).

Two sub-threshold notes, no action required: (1) `AddonPlatform.jvm.kt` passes headers to
`HttpURLConnection.setRequestProperty` without the CR/LF rejection the OkHttp Android actual
gets — unreachable today (JVM target ships nowhere, commonTest never calls the header path);
adopt the Android validation if the JVM target ever gains a real consumer. (2)
`ServerConfigurationStorage.jvm.kt` mirrors the fork's pre-existing lenient `tv_login` guard —
not introduced by this branch.

### Mac session (2026-08-21) — I4 done, Codex gate closed at 7 rounds

**I4 root cause found and fixed:** the FA87 `test24` failure was the **sim-wide prefs mirage** —
a 115 KB `com.nuvio.media.NuvioTV` plist in the simulator's device-global prefs layer, stamped
08-19 09:58 (the server-switch scratch morning), carrying a stale expired session and a full
stale app-state copy the app reads through. Backed up to scratchpad, domain deleted, cfprefsd
kicked; the app container's own prefs (real signed-in session, verified by JWT decode) were
untouched. `test24` solo: green immediately after.

**Full sim UI suite:** 109 executed, 7 skipped, 2 failing test cases — both harness-class, not
app defects. `test27CardDepthCoverageAB` failed in-suite on loud prerequisites (Appearance pane
never reached — the known Settings focus-restore/lazy-pane class) and **passed solo**;
`test30AppearanceBaselineRestore` passed in-suite, so no account-state drift. `test24` failed
in-suite AND solo-after-suite on See All grid mis-entry: the existence-walk + blind Right
strides cannot cross a long Search results row (the SeeAllCard is in the tree while focus is
still 20 cards short). Harness fixed twice-over (`d3fb779c`): `selectIntoSeeAllGrid()` detects
detail mis-entry via the `debug_ux6` probe and retries, and on tvOS 26.5 (which DOES report
focus) entry now walks Right **by focus identity** until the focused element IS the SeeAll
card. Final solo run: green, zero mis-entries. UX-13 app behavior was never wrong.

**Codex gate (rounds 1–7, `--base 36effd50 --scope branch`, all findings fixed same-day):**
- r1: CI workflow — unpinned executed outer-repo checkout (P1) + quickjs cache key missing the
  build script (P2) → `fc44bc30`.
- r2: FEAT-25 — carousel advanced during cold-cache trailer resolution (held only on
  `playingKey`) → `a3225a89`: model hoisted to HomeView, tick holds on `phase != .idle`, and
  `expand()`'s skip paths now land `.idle` (a parked `.dwelling` would have held forever).
- r4: diagnostics — unmatched `popImmersive()` logged a phantom push/pop cycle → `c3555631`.
- r5: FEAT-25 — stale `UIAccessibility.isVideoAutoplayEnabled` after background-flip →
  `b48b03ee` (gate mirrored into `@State`, refreshed by the status-change notification and on
  every return to `.active`).
- r6: diagnostics — About probe readout had no invalidation source (would fake the exact
  "callbacks stopped firing" signature on device) → 1 Hz `TimelineView` refresh (`0613dd45`).
  The r6 play/pause finding is the **recorded v1 keep** (checklist item 3 below), not taken.
- r3, r7: clean. **r7 verdict: no actionable defects in production, JVM-test, CI, or UI-test
  code.**

Branch is 6 commits ahead of the CI-built `bf17ab13`, unpushed pending Christian's word.

### Device pass — batch 1 RESULTS (2026-08-21, Living Room ATV)

**Round 1:** FEAT-25 plays without focus ✅ (the headline); carousel hold ✅ (waits out the full
trailer); diagnostics protocol ✅ (`cycles=` read exactly 10; scroll counters moved; no tab-bar
clipping on the full Home walk). **Item 2 FAILED**: trailer stayed audible under pushed Detail
pages and across tab switches — `onDisappear` fires on neither (tabs keep their stacks alive; a
push keeps the root mounted).

**Fix campaign (same day):** four coverage doors found and closed — tab switch (shell-level
`homeSurfaceCovered`), Home-stack pushes (bound `NavigationPath` depth; appearance counting was
refuted twice by Codex rounds 8/9 before landing here), the CW stream-picker cover, Top Shelf
deep-link covers. Each sim-verified by `[TrailerPipeline]` console-truth (release-on-cover,
re-claim-on-return, zero claims while covered); test24 green as the path-binding regression
gate; Codex round 10 clean (10 rounds total on the branch). Landed `082a6cdb..dcd84a69`, pushed.

**Round 2 (retest): ✅ PASS — "the trailer stops everywhere now."** Batch 1 device pass is
complete. Remaining before the cut: V1's on-device BUG-30/66 reproduction attempt (walk-up +
push/pop with diagnostics photographed IF the bar ever glitches — counters proven live), V2
reporter photo, release gates 1–7.

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

### Trailer Location (FEAT-25 round one) — FOLDED INTO beta.14, 2026-08-21 (Christian's call)

Built on `claude/trailer-playback-location` off the batch-1 head `dcd84a69`; gated on the Mac
(Codex 5 rounds clean, test01 + test37 green on the sim, device pass items 3–8 passed, 8 with a
note) — full record in `docs/trailer-playback-location-plan.md`. Merged by fast-forward:
`claude/beta14` and `tvos-shared-extraction` are both at **`aa57a8d6`** (pushed). Ships in
beta.14 as the `trailer_playback_location` Settings › Home Screen chip row ("Trailer Location:
Poster / Hero" under Trailers on Focus). Release-notes line: *"Trailers on Focus can now play in
the hero instead of morphing the poster (Settings › Home Screen › Trailer Location)."*
Follow-ups (not beta.14): CW/Upcoming-focused hero-trailer mute, animate the cold-launch
latch-flip collapse, refused-slot retry. README features/screenshots still owe this entry at
release time (the release script enforces).

### FEAT-26 (bigger season posters) — FOLDED INTO beta.14, 2026-08-21 (Christian's call)

Christian's device photo showed the detail screen's season cards still at 120×180 — the fix
existed (`f539eafd` on `claude/season-poster-sizing-7g8cm0`, cut off `dcd84a69`: 180×270 via
`Theme.Size.miniPoster*`, card-depth treatment, 4pt selected border, bigger placeholder label)
but had never been merged. Merged (`--no-ff`) into `claude/beta14` and fast-forwarded to
`tvos-shared-extraction`: both at **`65c486f7`**, pushed. Codex pass on the one-file diff:
clean. Installed on the Living Room ATV as a Debug build for a look. Release-notes line:
*"Season posters on the detail screen are now the same size as More Like This."*

### BUG-38 (collection covers & logos) — SETTLED + FIXED, FOLDED INTO beta.14, 2026-08-21 (late)

u/mrStevenx3's Collections JSON landed by DM. Seeded into a guest-mode sim (`debug.collectionsSeedJsonB64`)
it proved the Home tiles were always right — the "flat gradient" tiles are his own Fusion cover images —
and that the never-rendered assets were `heroBackdropUrl` + `titleLogoUrl` (Fusion's folder-page hero).
`FolderDetailView` now renders them (`c747efd8` + Codex-round fixes `23304095`; `claude/beta14` =
`tvos-shared-extraction`). Release-notes line: *"Collection folders now open with their configured
backdrop and title logo."* Retest ask for beta.14: open a Genres folder. Full record in
`docs/beta-feedback-tracker.md` (BUG-38) and `docs/research/bug38-collections-json-2026-08-21/`.

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

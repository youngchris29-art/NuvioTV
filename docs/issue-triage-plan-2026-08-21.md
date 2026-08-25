# NuvioTV — open-issue triage & fix plan (2026-08-21)

**Baseline:** `tvos-v0.3.0-beta.13.5` (build 110, submodule `36effd50`, released 2026-08-20 19:34 UTC).
This document is the consolidated read of *everything currently open* — GitHub issues, pull
requests, the beta feedback tracker, and the state of the working tree itself — and what the plan
is for each. It is the candidate scope for **beta.14**.

**Sources read:** GitHub issues #1 and #2 (with all comments), the GitHub PR list, all 112 rows of
`docs/beta-feedback-tracker.md`, `docs/beta13.5-release-plan.md`, `CLAUDE.md`'s upstream-sync open
items, and the tvOS Swift sources in the `NuvioMobile` submodule at the pinned pointer.

**What this pass could and could not verify.** The submodule was checked out fresh and read
directly, so every code claim below was confirmed against the actual source at `36effd50`. What
could *not* run here: the Xcode sim suite and the shared Kotlin tests — both need macOS (see
§6.1). No claim below is based on a green test run in this environment.

---

## 1. Repo & worktree health

| Check | Result |
|---|---|
| Outer repo working tree | **Clean** — no uncommitted or untracked files |
| `NuvioMobile` submodule working tree | **Clean**, detached at `36effd50`, matching the pinned pointer exactly (no drift) |
| Branch | On `claude/brave-cori-mvsdlv`, in sync with `origin` |
| Open pull requests | **None** — the repo has never had one; all work lands as direct commits |
| `TODO` / `FIXME` / `HACK` markers in `iosApp/NuvioTV` | **Zero** |
| Last release published | beta.13.5, same day the review that caused it landed |

**Nothing is half-finished in the tree.** There is no stranded work-in-progress, no
merge conflict, and no pointer drift. Everything below is *reported* or *infrastructural*, not
uncommitted.

---

## 2. GitHub issues

### #1 — "Crashes after logging in" (ozdek, filed 2026-07-24, **open**)

- **Reported:** app crashes on login with a 10,000+ item watched library.
- **Diagnosed:** the attached crash log names it exactly —
  `__CFPREFERENCES_HAS_DETECTED_THIS_APP_TRYING_TO_STORE_TOO_MUCH_DATA__`. Watched history was
  written into the preferences store; the OS kills the process once that store passes its limit.
- **State:** **fixed in beta.10** (`becb24b3`, 2026-08-04) — watched history, watch progress and
  four other unbounded stores moved out of preferences into files. Reporter's last data point was
  beta.9, one build before the fix. A retest ask was posted 2026-08-20.
- **Plan:** *no code work.* Hold for the retest. If no answer within ~7 days, close with a
  summary pointing at the fix commit and invite reopening. If it still crashes on beta.13.5, that
  is a **new P0** and needs a fresh `.ips`.
- **Process note worth keeping:** this issue sat unanswered for 27 days while the Reddit thread
  got all the attention, and the reporter's second comment ("the whole thing looks abandoned")
  is the cost of that. **The GitHub tracker needs to be part of the daily sweep, not an
  afterthought** — see §6.3.

### #2 — "Some video no stream" (konrepo, filed 2026-07-31, **open**)

- **Reported:** a personal addon (`khmerhub.onrender.com`) plays in Stremio and Nuvio iOS but
  spins forever on tvOS; some KhmerTV live channels buffer or never start.
- **Diagnosed:** real bug on our side — the tvOS players never forwarded the addon's
  `behaviorHints.proxyHeaders`, so any source needing a `Referer`/`User-Agent` failed. Mobile
  passes them, which is why the same addon worked there.
- **State:** **fixed and released in beta.13.5** — shared `sanitizePlaybackHeaders` →
  `PlaybackContext.requestHeaders` → mpv `http-header-fields` and the FFmpeg `headers` option on
  the AVPlayer/remux path. The reporter has also confirmed their SundayDrama catalog is offline
  server-side, which explains the one title that could not be tested.
- **Plan:** post the "fix is live in beta.13.5, please retest" follow-up (the reply was drafted
  pre-release and never updated after the cut). Ask specifically for **named channels** that
  still buffer, so slow-host buffering can be separated from a real failure. Close on confirmation.

---

## 3. Pull requests

**None open, none ever opened.** Nothing to review, rebase, or drive to green. No action.

---

## 4. Open bugs from testers

Twelve rows are genuinely open. They split cleanly into three groups by *what is blocking them*,
which is the only useful ordering — several have had blind fix attempts burned on them already.

### 4.1 Blocked on hardware we control (build after a device investigation)

#### BUG-30 (P1) — tab bar rests clipped after a D-pad walk back up Home
#### BUG-66 (P1) — tab bar stops minimizing and stays permanently visible after a while

These are almost certainly **one defect with two rest positions**, and they are the top of the
queue. BUG-66 also decides whether FEAT-17's public decline holds: five feature asks since
2026-08-05 turned out to be five sightings of this bug, so fixing it retires FEAT-17 as
*satisfied* rather than declined.

- **Evidence:** BUG-30 confirmed in the wild on beta.13, verbatim — *"when I scroll down and then
  back up, the bar gets cut off. This does not happen when I press the back button to return
  directly to the top."* BUG-66, same reviewer — *"the top bar eventually stays permanently
  visible after some time."*
- **Code read (`DesignSystem/TabBarVisibility.swift`):** the app deliberately **never toggles bar
  visibility for scrolling**. After the round-4 device pass (2026-08-02) the toolbar drives off
  `immersiveHidden` (detail-push only); the tvOS 26 system bar is left to minimize/expand
  natively under `.automatic`. So *no app-owned state machine can be stuck* — what is stuck is the
  **system bar's own scroll-edge state**.
- **Root-cause hypothesis (single mechanism, both symptoms):** the system bar minimizes off the
  scroll-edge signal of whichever scroll view it considers primary. If a tab root's `ScrollView`
  loses that association — most plausibly when the root is re-created or re-identified after a
  `DetailView` push/pop, or after a focus-driven programmatic scroll rests short of the true top —
  the bar stops receiving edge updates and freezes wherever it was: mid-slide (**BUG-30**, clipped)
  or fully expanded (**BUG-66**). Menu-to-top never clips because it scrolls to the *real* top,
  which re-fires the edge transition. "After some time" then means "after N push/pop cycles", not
  a clock — which is a countable repro.
- **Plan — instrument before touching layout. Six blind rounds are already banned on this row
  (`.automatic`→`.visible`, dropping the custom animation, never-toggle, hero-refocus completion
  scroll ×2); a seventh is not warranted.**
  1. Ship a `[TabBar]` diagnostics line (same release-safe pattern as BUG-42's Hero Paint
     Diagnostics, rendered in Settings → About): each tab root's scroll-geometry callback firing,
     the offset it reports, the immersive depth, and a push/pop counter.
  2. **Device protocol:** walk Home down and back up (BUG-30 shape), then run 10 detail
     push/pop cycles and re-check the bar (BUG-66 shape), reading the diagnostics after each. The
     question to answer is precisely: *do the scroll-geometry callbacks stop firing before the bar
     freezes?*
  3. **If yes** → the fix is to keep the tab root's scroll view stably identified across pushes
     (stable `.id`, no re-creation on pop) and/or re-assert the scroll-edge association on
     re-appearance. **If no** → the bar is receiving updates and ignoring them, which is a
     presentation issue and a genuinely different fix; do not guess between them.
- **Verification:** the failing state must be reproduced in-house *first*. A fix that cannot be
  shown failing before and passing after does not ship on this row.
- **Also feeds BUG-62** (P2, "top menu bar freezing", a second reporter, no build number) — likely
  the same bar; keep filed separately until the repro lands.

#### BUG-64 (P2) — focus zoom appears regardless of the "No Zoom on Focus" toggle

- **Evidence:** answered unconditionally by the reporter, ~2h after the ask — *"the zoom feature
  appears regardless of whether or not I select the zoom option on the posters."*
- **Code audit done in this pass — the guard is complete.** Every focus-treatment surface was
  read at `36effd50`:
  - `CardFocusMode.resolve` (`DesignSystem/PosterCard.swift:144`) checks `noZoomOnFocus` **before**
    the ring, returning `.still(ringed:)` — correct precedence.
  - `CardFocusTreatment` `.still` applies no scale of any kind; `CardArtworkSystemLift`
    (`:316`) applies `.hoverEffect(.highlight)` **only** in `.systemLift`; `CardCaptionFocusDrop`
    returns 0 offset outside `.systemLift`.
  - `TileFocusLift` (`:254`) reads the same key and goes still — so `SeeAllCard`,
    `EpisodeThumbCard`, `SeasonPosterCard` and `TrailerThumbCard` are all covered.
  - `FolderTile` and `CastCard` apply no scale at all. Every poster call site
    (`CollectionsUI:614`, `LibraryView:45`, `CatalogGridView:44`, `SearchView:218`,
    `DetailView:663/754`, `PersonDetailView:196`, `EntityBrowseView:294`, `HomeView:1305`) routes
    through `PosterCard`/`LandscapeCard` under `.buttonStyle(.borderless)` — no system card lift.
  - `.hoverEffect` appears in exactly one file, correctly gated.
  **There is no unguarded surface left to sweep.** Sim measurement agrees (test32: poster band
  delta 0.001 with ring + No-Zoom both ON).
- **Therefore the mechanism is state, not drawing** — the two candidates are (a) the toggle's
  `@AppStorage("no_zoom_on_focus")` value on his box is not what the pane shows (a settings-sync
  or profile-switch path re-normalizing it, the shape of BUG-42's ~1s settings re-normalization),
  or (b) a device-only compositing difference the sim cannot show — the **BUG-65 shape**, which was
  also invisible until hardware.
- **Plan:** add the resolved `CardFocusMode` plus both raw toggle values to the About diagnostics
  pane (three lines, near-zero cost, rides the same probe as BUG-30/66). Ask for one photo of that
  pane with the toggle ON. **No blind fix** — the code is provably correct, so a code change now
  would be changing something that works.

### 4.2 Blocked on the reporter (chase, do not build)

| Row | What is owed | Chase plan |
|---|---|---|
| **BUG-42 (P1)** — hero paints a duplicate poster on cold launch, reported 4× | His photo of Settings → About → **Hero Paint Diagnostics** on a cold launch. The probe shipped in beta.13.5; three in-house device launches have disagreed with him twice. | Ask once more with the exact steps. **No fifth fix attempt until the photo arrives** — four mechanisms were already closed in beta.13 and the symptom survived, which means the remaining one is on his box. |
| **BUG-38 (P2)** — collection covers / title images missing on his config | His Collections JSON export. **The blocker is now the channel, not him** — two DM attempts errored on his end. | **Offer a different channel** (paste as a thread comment, or a file-drop link) rather than a third same-channel retry. The `[CollectionCover]` probe is already in the build and found `focusVideoUrl`/`focusVideoWebmUrl` in the synced payload that this build silently drops — file that as its own row when the payload lands. |
| **BUG-62 (P2)** — "top menu bar freezing", new reporter | Build number, stuck-visually vs stops-responding, whether they were scrolling back up Home. Asked 2026-08-13; no reply in 8 days. | One follow-up. If silent, park it explicitly behind BUG-30/66 rather than leaving it as an unanswered "New". |
| **BUG-37 (P1)** — row titles clipped in pinned-hero mode | A repro. Two videos have now failed to show it; every Home rest position in the footage renders row titles correctly, including through a post-relaunch up-walk. | **Ask directly, once, with a screenshot request.** If it cannot be produced, this row should be downgraded to P3 and parked — it has consumed two video analyses without a single confirmed frame. |
| **BUG-55 (P1)** — trailers do not play | Whether *Nando entre dos mundos* shows a spinner or a clean "no trailer". | The mass symptom is retired (BUG-63 shipped); TMDB has **zero** videos for that title in any language, so offering none is correct behavior. **This row should close as soon as the spinner-vs-nothing question is answered** — and if it spins, the fix is a no-trailer empty state, not a lookup fix. |

### 4.3 Buildable now (small, no tester input needed)

| Row | Symptom | Plan |
|---|---|---|
| **BUG-58 (P3)** — Appearance colour picker | Black background fixed in beta.13; the fix exposed **white-on-white selection** underneath. | The residual was fixed as **BUG-65** and released in beta.13.5 (settings rows track their own focus state; swatches wear a contrasting ring). **Awaiting confirmation only** — ask for a verdict, then close both rows. |
| **BUG-33 (P2, defect 3)** — focused *Recent Searches* chip | Mid-grey label on a near-white focused platter, measured **1.52:1** contrast (vs 2.23:1 unfocused in the same frame). The label draws — it just landed on a secondary/dimmed text style instead of a contrast-aware one. | Same class as BUG-45/58/65, and now the third time this class has shipped a defect. **Fix the chip** (`Screens/SearchView.swift:102–108`) *and* sweep for remaining raw-palette-on-focus-platter sites in one pass, so this class stops recurring one surface at a time. |
| **BUG-40 (P3)** — white focus ring reads grey | Reporter is emphatic and specific — *"even though the focus ring is actually set to white, it looks gray… if I choose any other color, it works correctly"* — but camera measurement found the opposite (RGB 250,255,255). Colour-specific and everywhere. | Cheap and worth doing blind for once: verify the White accent's ring path does not composite through an opacity/blend that other accents escape. Low risk, and the reporter has repeated it three times. |
| **BUG-41 (P2)** — detail description scrolling choppy | A *regression* claim from beta.10. The suspected `@State`-per-scroll-frame invalidation was measured in sim and **did not reproduce** (body evals ~10–19 across 58 scroll changes, both variants). The hygiene fix shipped anyway. | **Ask for a fresh verdict on beta.13.5 before spending anything more.** Three builds of unrelated work have landed since; if it is still choppy, instrument with the `[BUG41]` probe on device (the sim has already proven it cannot see this). If it is fine now, close it. |
| **BUG-36 (P2)** | Hidden-title half confirmed fixed; the overlap it traded for is **BUG-53**, which shipped in beta.12. | Row is stale — close it. |

---

## 5. Open feature requests

| Row | Ask | Recommendation |
|---|---|---|
| **FEAT-25 (P2)** | Play the trailer **in the hero, without requiring focus**, like Nuvio. | **Build it — this is the one with a public maintainer commitment on record** (`p4vvgxc`, 2026-08-20). The blocker it was implicitly waiting on (the aspect-fit rule) is gone now that BUG-59/UX-9 shipped and were confirmed in the wild. Reuse the `InlineTrailerCard` extraction/reveal-gate machinery against `HomeHeroBackdrop` (`Screens/HomeView.swift:1395`). **Device-verify that it plays without focus** — that is the sharpened half of the ask and the half a sim will not catch. Ship behind a setting, defaulting to current behavior. |
| **FEAT-26 (P3)** | Season posters could be bigger. | Cheap — `SeasonPosterCard` is hardcoded 120×180 (`Screens/EpisodesSection.swift:411`). **Batch it with the next detail-page pass**, not alone, and ask how much bigger before picking a number. |
| **FEAT-22 (P2)** | Automatic quality selection. | Two design calls are still unanswered by the reporter (fallback tier; best-quality vs fastest-start). **Christian's call, not the reporter's** — 8 days of silence is enough. Decide the rule, then build. |
| **FEAT-16 (P3)** | User-selectable app font, as Nuvio's Android TV app has. | Concrete spec exists on camera (a *Police de l'application* row, Open Sans). tvOS has no user font library, so this means **bundling faces** (~8 static weights, licence-clean). Real work for a P3 — recommend deferring until a font pass is warranted, and saying so publicly rather than leaving it silent. |
| **FEAT-3 (P2)** | TestFlight / App Store distribution. | Standing, recurring, and publicly committed to in principle. Research is done; the blocker is the pull-risk question. **Not beta.14 scope** — but it deserves a dated decision rather than indefinitely "researching". |
| **FEAT-14 / FEAT-17** | Shipped / declined respectively. | FEAT-17's decline is **conditional on BUG-66 being fixed** — if BUG-66 lands, re-post the decline as "this is fixed, which is what you were actually asking for". |

---

## 6. Engineering-infrastructure issues found in this pass

These are not tester reports. They are things wrong with how the project can be worked on, and
they are the reason several rows above are harder than they need to be.

### 6.1 The shared Kotlin test suite cannot run anywhere but macOS — **new finding, recommend fixing**

`:shared` declares only Apple targets plus Android (`shared/build.gradle.kts:286–291`). There is
no `jvm()` target, and no `jvmTest`/`testDebugUnitTest` task exists — the suite runs exclusively as
`:shared:iosSimulatorArm64Test` / `:shared:tvosSimulatorArm64Test`, which need an Apple simulator
host. This was confirmed by running Gradle here: configuration resolves fine, the test task does
not exist.

**Consequence:** the "444/444 shared tests" gate can only ever be run by Christian on his Mac. Any
automated, CI, or non-macOS session — including this one — can read the shared module but cannot
verify a single change to it. For a module that exists *specifically* to hold Compose-free,
platform-free business logic, that is backwards.

**Plan:** add a `jvm()` target to `:shared` wired to the existing `commonTest` source set.
**52 of the 54 test files already live in `commonTest`**, so most of the suite should light up with
little more than the target declaration plus JVM actuals for whatever `expect` declarations the
tests touch (storage and crypto are the likely ones). Payoff: shared logic becomes verifiable off
a Mac, and future upstream ports — which land in `shared/` by design — get a real pre-flight check.

### 6.2 `test24CatalogGridFocusRestore` fails on the current sim environment

Carried into this plan from the beta.13.5 gate, unresolved. It fails **on clean HEAD** (beta.13
code) as well as on the working tree, having been green in the beta.13 gate on 08-18/19 — so it
is fixture or runtime drift, not a code regression. The leading suspect is the FA87 fixture's
damaged sign-in state from the 08-19 server-switch testing. All other 73 UI tests pass.

**Plan:** reset the fixture's sign-in state and re-run before anything else; if it still fails,
bisect the harness rather than the app. Give the underlying **UX-13** behavior a device spot-check
in the same pass so a broken test does not hide a real defect.

### 6.3 GitHub issues are outside the daily sweep

The daily scheduled sweep reads the Reddit thread and updates the tracker. GitHub issues are not
part of it, which is how #1 went 27 days without a reply while its crash log contained the whole
answer — and cost the reporter's goodwill in a public comment.

**Plan:** add both open-issue checks to the sweep's routine, and give GitHub issues tracker rows
(or at minimum a fixed section) so they age visibly like every other row.

### 6.4 Tracker hygiene — stale statuses

Several rows still read *"Fixed in code (unreleased, rides beta.10/beta.11)"* — BUG-34, BUG-44,
BUG-49, BUG-50, UX-11, UX-12, UX-13 — for builds that shipped up to 17 days ago. They are not
open, but they read as open, which inflates every "what is left" count including this one.

**Plan:** one sweep flipping every "unreleased" row whose build has shipped to
`Shipped (beta.N)`, and add a `check-tracker.py` guard: *no row may say "unreleased" for a build
tag that already exists as a published release.*

### 6.5 Upstream backlog (from `CLAUDE.md`, both parked by product decision)

- **Supporter perks v1** (upstream `bd88760e`) — mobile monetization, entirely in `composeApp/`,
  nothing in `shared/`. Parked; zero drift risk from waiting. No action.
- **Subtitle minimum font size** (upstream `d50f84fc`) — upstream lowers the iOS floor 12sp → 6sp.
  tvOS uses a different renderer, and a 10-foot UI arguably wants a *larger* floor. **Do not port
  as-is** — decide tvOS's own range at the next player-styling pass.

Upstream `cmp-rewrite` has not moved since 2026-08-17 (pinned at `bbac53b2`), so there is no port
pressure right now.

---

## 7. Proposed beta.14 scope

Ordered by what unblocks the most, and deliberately small — the last two builds succeeded because
they were tight and turned around in a day.

**Wave 1 — diagnostics (build first, ship early, unblocks three P1s)**
- `[TabBar]` scroll-edge + push/pop diagnostics in Settings → About (BUG-30, BUG-66, BUG-62).
- Resolved `CardFocusMode` + both raw toggle values in the same pane (BUG-64).
- Both are additive, release-safe, and cost nothing if the hypotheses are wrong.

**Wave 2 — the committed feature**
- FEAT-25: hero trailer playback without focus, behind a setting, defaulting off.

**Wave 3 — contrast-class sweep**
- BUG-33 defect 3 (recent-search chip) plus a sweep of any remaining raw-palette-on-focus-platter
  sites. This class has now shipped four defects (BUG-45, BUG-58, BUG-65, BUG-33) — sweep it once
  instead of a fifth time.
- BUG-40 white-accent ring check.

**Wave 4 — infrastructure (no user-facing change)**
- `:shared` JVM test target (§6.1).
- `test24` fixture reset (§6.2).
- Tracker status sweep + guard (§6.4).

**Wave 5 — device pass, then cut**
- The BUG-30/66 investigation protocol is the *reason* for this pass, not an item in it. Nothing
  on those rows ships without a reproduced-then-fixed sequence.

**Explicitly not in scope:** BUG-42 (awaiting photo), BUG-38 (awaiting payload), BUG-37 (awaiting
repro), FEAT-16, FEAT-3, both upstream backlog items.

**Comms owed regardless of build scope:** GitHub #2 retest ask, GitHub #1 close-or-confirm,
BUG-38 alternate delivery channel, BUG-58/65 verdict ask, BUG-41 re-verdict ask, BUG-55
spinner-vs-nothing question, BUG-37 repro ask, BUG-62 follow-up.

---

## 8. Gates before any cut

Unchanged from the beta.13.5 process, which worked:

1. Shared Kotlin tests green (and, after Wave 4, runnable off a Mac).
2. Sim app build succeeds.
3. Full sim UI suite green — **including** `test24` once its fixture is reset.
4. Codex review loop until clean.
5. l10n: xcstrings sync for every new key, all five languages.
6. Device pass on the Living Room Apple TV — the tab-bar protocol in §4.1 is the headline item and
   is irreducibly manual.
7. README + screenshots, then `scripts/release-beta.sh`.

---

## 9. Decisions needed from Christian

1. **FEAT-22** — the two design calls (fallback tier; best-quality vs fastest-start). The reporter
   has been silent 8 days; recommend deciding without them.
2. **FEAT-25** — setting name and default. Recommend default **off** so beta.14 cannot regress a
   Home screen that testers just confirmed working.
3. **BUG-37** — downgrade to P3 and park after one more repro ask? Two videos have failed to show it.
4. **§6.1** — approve the `:shared` JVM target. It is the only item here that changes the build
   graph, and it is the one that most changes what can be verified without a Mac.
5. **FEAT-3 (TestFlight)** — set a date to decide, or say publicly that it is not happening this
   beta cycle.

# Steven's beta.19-rc1 verdict: fix plan (2026-10-02)

**Status: APPROVED and STARTED 2026-10-03 ("start the fix batch").** Clone `~/Claude/Projects/NuvioMobile-steven-rc1`, branch `claude/steven-beta19-rc1-verdict` off `284fd764` (the revamp merge). Wave 0 baselines are running.

**Christian's calls, answered 2026-10-03:**
1. Auto-Play Best Source → **(b) real ranking**: resolution > DV/HDR > cached > size within the streams that arrived, honouring the Sources filters.
2. Trailer Start Delay default → **Automatic** (rest + 1 s).
3. Soft row fade → **the default, with a real Appearance setting**; the About A/B row goes.
4. Colour → **a lighter Cinematic Detail scrim only.** No warmer neutral tokens. The ambient poster-colour background is the Stage batch's H3 (FEAT-53).
5. FEAT-43 → the Stage batch's H5 (answered by H6).
6. Coordination message → **moot**: the revamp merged before it was sent. Its Detail items come into this batch (see below).

**Spec-phase answers (Christian, 2026-10-03):**
- Trailer Start Delay fixed values count from focus, never before rest.
- Title logos move to TMDB `original`.
- Cinemeta/metahub posters move from `medium` to `large` (w780 only covers TMDB).
- Episodes row gets the edge fade.
- Defaults taken without objection: 250 pt ramp (lower the constant if Large/landscape rest closer); only an explicit "Off" migrates from the old A/B; scrolling never changes Detail glass (this also stops Classic's synopsis-panel flattening); T1 ships with both legs off until the device check picks one.

**Defaults taken at the start (Christian can override):**
- **Detail items join this batch**, since the revamp is merged and they are unowned:
  - the action-button labels go through the localized keys (`DetailView.actionLabel` still uses `Label(String, …)` at `284fd764`), plus status keys;
  - F's edge fade on More Like This, Trailers, Cast and Collection;
  - one glass rule for the chips and the action buttons on scroll back up;
  - the lighter Cinematic scrim (call 4).
  Classic Detail's synopsis panel is left alone: Classic is removed after one or two betas.
- **M1 shrinks to a device check for T1 and B1.** Its two questions served M2, which is dropped. T1 needs the new `off=`/`ins=` probe on hardware; B1 needs the Infuse play-and-return repro. Both run with Christian once the first build carries the probes.
- **UI legs run on FA87 itself**: no parallel session owns it now.

**Update 2026-10-03, decision H6** (`docs/home-redesign-decisions-2026-10-03.md`). Christian picked the Stage & Strip Home redesign (`docs/home-stage-strip-plan-2026-10-03.md`). That batch starts only after this one merges, because both edit the same Home files. For this batch:
- **Drop M2** (the one-motion settle and slide rules) **and N1** (Up into Genres). The new Home pages whole rows and its stage can't take focus, so neither is needed there. The old Home stays as the "Classic" layout with today's motion.
- **Keep M5** (the hero text fades out before the new text fades in). The new Home's stage uses the same rule.
- **Keep everything else as written:** B, I1, F, M3, R1, R2, T1, C, M4, A.
- **The redesign builds on two pieces of this batch:**
  - I1's per-view decode size and w780 posters, for its 3840 px stage art.
  - F, which must land as a reusable row modifier, because the redesign's strip applies it to every row.
- **Call 5 under "Christian's calls before Wave 1" is answered, and so is the ambient half of call 4.** The ambient poster-colour background is part of the redesign (H3; log it as FEAT-53 as planned). FEAT-43 Follow layout is the redesign's collections page (H5). (Correction: call 4's "warmer neutral tokens" half was still open. Answered with the others below.)
- **The Detail + Settings revamp merged on 2026-10-03** (`tvos-shared-extraction` at `284fd764`). Branch this batch off that tip rather than `5f2d5cd3`; the Coordination section's file-avoidance rules no longer apply.

## Sources

- **DM:** Steven's beta.19-rc1 verdict, 5:09 PM ET 2026-10-02, plus:
  - a 6:39 PM follow-up (the action-button labels are not translated);
  - two earlier notes at 3:22/3:29 AM (an optional trailer start delay, and why Open Sans has no size control).
- **Photos:** 5 chat photos and 6 Smash photos, archived in `docs/research/steven-beta19-photos/`.
- **Video:** 6 min 36 s, 4K, filmed off his TV. The raw file is `~/Downloads/steven-beta19-rc1-2026-10-02/IMG_8880.mov` and is kept out of the repo.
  - Frame-by-frame triage: `docs/research/steven-beta19-rc1-video-triage-2026-10-02.md`.
  - 31 named frames and kymographs: `docs/research/steven-beta19-rc1-video/`.
- **Code:** three read-only Explore reports against `5f2d5cd3` (build 133). They are summarised under each item below.

## What he confirmed fixed

- **Tab bar:** it now hides completely, including after a tab switch. One leftover is listed below as T1.
- **Depth Takes Poster Color:** "WOW".
- **Fonts and weights:** perfect.
- **Up into the first genre row:** partly fixed. The leftover is listed below as N1.

## Findings and fixes

Tracker rows take the next free IDs: BUG-130 onward and FEAT-52 onward. `docs/beta-feedback-tracker.md` currently has an uncommitted edit from elsewhere, so I add rows only after checking who owns that change.

### M: Home motion, his number-one complaint

**What the video measured.** One Down press produces four visible events over about 2 s:

1. A row slide of about 625 pt, settled at about 1.15 s. The label and the posters move together.
2. A creep of 3–4 px that settles over 0.6 s.
3. A hero cross-fade 0.4–0.5 s after the last focus change. Old and new logo, meta and synopsis overlap for about 3 frames. This is the "doubled title".
4. A late step in which the row title alone drops about 9 pt in 0.17 s, 1.9–2.3 s after the press and 0.2–0.3 s after a hero swap.

**The reference.** Fusion makes one ease-out of about 1.0 s, and nothing moves after it settles.

**Findings from the code:**
- Two app clocks run after the engine's reveal:
  - the settle corrector (0.25 s delay, up to 3 hops, re-armed by any vertical scroll sample);
  - the held title slide (released by settle, quiet, fallback at 0.6 s, or the 1.5 s ceiling, then a 0.22 s move).
- The inline trailer morph widens the card and calls `proxy.scrollTo` twice (at 0 and 450 ms) without telling `PinnedRowSettle`. Any vertical spill re-arms the corrector.
- Every mounted row observes `trailerCoordinator.playingKey`, so a claim or release re-renders every row. This is the BUG-126 stutter class.
- With the Nuvio hero off, Home runs in classic mode with no corrector and no title tracking. That is why he finds it smoother there.

**Fixes:**
- **M1. Instrument first, on hardware.**
  - Run a Debug build on the Living Room Apple TV in the **Test** profile, set up like Steven's: Large and Medium+ poster sizes, ring and zoom on, Nuvio hero, inline trailers on.
  - Stream the probes over `--console`: `homeScrollProbe`, `pinnedRowSettleProbe`, `trailerProbe`, and the BUG-126 frame sampler.
  - Two questions to answer:
    - Which release (`via=`) produces the late 9 pt step?
    - Does a hero commit trigger it (relayout → geometry change → hold release)?
  - Main session plus Christian, about 20 min.
- **M2. One motion per press (Opus).** **DROPPED 2026-10-03 (H6, see the update under Status).**
  - The title's slide is decided once, inside the same transaction as the row's settle (or the engine's rest). No independent title motion after rest.
  - A hero swap or commit must never re-arm the corrector or release a held slide.
  - The corrector stands down for residuals of 10 pt or less, so the 3–4 px creep goes.
  - The exact rules follow from M1's data, and the existing `PinnedRowSlideHoldTests`/`PinnedRowSettleRc14Tests` get new cases.
- **M3. Trailer morph versus settle (Opus, same owner as M2).**
  - The morph's `scrollTo` calls go through `PinnedRowSettle.noteExternalScroll`, or are dropped when the row is already in view.
  - The dwell starts only after the row has come to rest (`!isRestPending`), not 1 s after focus.
  - `playingKey` is read only by the playing row: move it to a non-published store with a per-row subscription.
- **M4. FEAT-52: Trailer start delay (Sonnet).**
  - Settings → Home Screen, next to the inline-trailers toggle: "Trailer Start Delay": Automatic (rest + 1 s, the new default) / 1 s / 2 s / 3 s.
  - Applies to the Home inline and hero trailers. Detail keeps its own 4 s.
  - Strings go English-first; translations are covered under Coordination.
- **M5. Hero cross-fade without double text (Sonnet, spec from Opus).**
  - The logo, meta and synopsis block fades out and then in, about 0.12 s each.
  - The artwork keeps its cross-fade.
  - Also fix:
    - the stale hero item shown for about 1 s after returning from a folder;
    - the hero with no title and no logo (Comme des frères, 0:24–0:36).

### B: Trailers stop until relaunch (new bug, P1)

**What the video shows.**
- Trailers work at 0:30, 1:12 and 1:34.
- The first failure is at 4:34, after the Detail page and the Infuse hand-off.
- In the end state, cards morph to a still, then collapse back on their own after 2–3 s.

**Most likely cause (code).** The loopback HLS listener (`TrailerLocalHLS.shared`) wedges:
- `attemptStart` ignores `.waiting`.
- `ensureStarted` and `playbackURL` have no deadline.
- The app was suspended while Infuse played. That is a textbook way for an `NWListener` to die without a callback.
- Every trailer from a split audio/video client (almost all of them) needs that listener, and only a relaunch resets the singleton.

**Fixes:**
- **B1. Repro on the simulator** (main session): play inline → background the app → foreground → play inline again. A device repro is Infuse play-and-return, with `-debug.trailerProbe YES`.
- **B2. Listener lifecycle (Sonnet, exact spec):**
  - Add a start deadline and handle `.waiting`.
  - Rebuild the listener on `didBecomeActive` and after any failure.
  - Put a timeout on `playbackURL(for:)` at both call sites. On timeout, record the result as transient and never as unavailable.
  - Log a `[TrailerRepack] listener …` probe line.
  - Unit tests with an injected listener factory.
- **B3. Leak check** (main session, Instruments or the probe's `attach live=N`) after 30 minutes of browsing. A decoder leak gets its own fix if it shows.

### R: Morph glitches and ring colour

- **R1. The morphed card's ring loses the poster colour.** Confirmed: the ring is hard-coded to `focusRingColor` at `InlineTrailerCard.swift:1345`.
  - Fix: read `focus_ring_poster_color` and `depth_rail_poster_color`, tint from `ArtworkColorStore.cachedColor(poster sources)`, and add the depth rail to the tile.
  - Sonnet.
- **R2. The "first poster" glitch.** This is a morph abort, not an edge-clip problem.
  - When focus leaves a card whose morph has just started, card #2 is pushed right and a ghost of the landscape logo spans the gap for 0.2 s.
  - Related glitches in the video:
    - an empty dark frame for one frame when a morph starts;
    - an empty slot for one or two frames when a card collapses;
    - poster and landscape art drawn side by side mid-morph;
    - a morph that starts and aborts in 0.4 s while focus stays on the card.
  - Fix: an abort before the expansion finishes collapses inside a transaction with animations disabled. The layout width only commits once the expansion is past its first frame. The poster stays in place until the landscape art is decoded.
  - Opus, because it shares `InlineTrailerCard` with M3. Same owner, done sequentially.
- **R3. Not a bug:** the striped Netflix tile is an animated cover. I explain that in the reply.

### I: Image sharpness and colour

- **I1. The Detail backdrop and posters are blurry (confirmed root cause).**
  - `ArtworkStore.downsample` caps every decode at 1920 px (`CachedAsyncImage.swift:435`). A 4K Apple TV draws 1920 pt at 2× = 3840 px, so:
    - the Detail page's `/original/` upgrade is downsampled back to 1920 px and stretched;
    - posters (w500) are upscaled once lifted.
  - Fix (Opus for sizing, Sonnet to execute):
    - The cap becomes the target view's pixel size: points × `nativeScale`, passed per call site. Full-bleed layers get 3840.
    - Size the memory cache by bytes so 4K backdrops don't push posters out.
    - Request w780 posters instead of w500 in shared `TmdbMetadataService`/`TmdbCollectionSourceResolver`; this needs the Kotlin gates.
    - Upgrade the Home hero backdrop the same way as Detail.
  - Proof: a simulator screenshot comparison at 4K plus Steven's Oak Street photo pair.
- **I2. Colours "cold, dull, slightly dark."**
  - Nothing in the image pipeline changes colour.
  - The video's colour comparison is inconclusive: the camera's auto-exposure confounds it.
  - The real differences:
    - Detail's scrim (black 0.80 at the left, 0.70 at the bottom);
    - the glass;
    - the near-black, slightly teal-grey palette, against Fusion's full-colour ambient background.
  - I1's sharpness fix will help the perception.
  - **Christian's call:**
    - a lighter Cinematic scrim (owned by the revamp, see below);
    - a warmer neutral background token (`0x0D0D0D` stays, the outline's teal cast goes);
    - an opt-in "ambient poster-colour background" for Home, like Fusion. The revamp deferred that as its option D; I'd log it as FEAT-53.

### F: Row edge fade

**Findings:**
- The Soft ramp is a 140 pt two-stop linear gradient that starts at the row's edge and runs outward into the overscan. Cards stay fully opaque up to the edge, so it reads as a hard knee.
- At Medium+ the ramp is narrower than one card stride, so portrait rows often show only the gap fading.
- Detail rows, the folder page and Search have no fade at all.

**Fix (Sonnet, spec in the item):**
- The ramp width is one card stride (at least 250 pt), starts inside the frame, and uses an eased multi-stop gradient.
- The leading edge only fades once the row has scrolled (the BUG-92 rule).
- Add it to the folder page here. The Detail rows are handed to the revamp.
- **Christian's call:** make Soft the default and a real Appearance setting once the revamp's Settings re-sort lands. Today it is an About A/B row, and that pane is being split.

### C: Collection folder page (regression from build 133's R4)

**Finding.** R4 removes the title from the tree after 8 pt of scroll. The chips are content inside the ScrollView, so they scroll away on the second press. Both disappear abruptly, and they come back as abrupt steps.

**Fix (Opus):**
- The title stays and rises gradually with scroll offset, clamped to a compact pinned position. It is driven by a geometry effect, with no per-frame `@State` (the BUG-19/41 rule).
- The chips are pinned under the title.
- Add the F fade and smooth out the 0.25–0.5 s skeleton flash.
- test69 updated.

**Not in this batch:** FEAT-43, the full Home-style "Follow layout" inside collections. That is a bigger product item. I propose it as the next batch and tell him so.

### T1: Tab bar stuck half-visible (BUG-66 residual)

**Finding.** His pane shows `y=-13 st=part` at rest after launch, and a tab switch fixes it. UIKit moves the bar 1:1 with the tracked offset and never snaps it. Two hypotheses:
- a non-zero top rest (the pinned headroom or a deep park);
- a skewed link baseline set during launch.

**Fix (Opus):**
- Add `off=`/`ins=` to the probe line and check on the device which hypothesis holds.
- Then one of:
  - relink once after the first `REST`;
  - snap the rows to y = 0 in `PinnedRowSettle`'s top-rest plan. It must not be focus-triggered: the 08-27 ban.

### N1: Up into the genre row with no Continue Watching

**DROPPED 2026-10-03 (H6, see the update under Status).**

**Finding.** The engine resolves Up straight to the hero when Genres is the topmost row and parked under the hero clip, or when the short-row floor's focus section reaches into row 2. The reveal only scrolls; it never moves focus.

**Fix (Opus):** when Up lands in the hero from a row that has a `previousRowTarget`, redirect focus to that row. This needs a new redirect verdict in `HomeUpIntoHeroGate`.
- Repro on the FA87 fixture with Continue Watching emptied.
- New test next to test74.

### A: Auto-Play Best Source picks a non-HDR link

**Finding.** The setting maps to `StreamAutoPlayMode.FIRST_STREAM`, so there is no quality ranking. It takes the first playable stream in group order (debrid, then add-on order) after in-scope add-ons answer or a 3 s timeout. HDR detection feeds only the sort and filters.

**Christian's call:**
- (a) Rename it "Auto-Play First Source" and explain it; or
- (b) **(recommended)** make it a real Best: within the streams that arrived, rank resolution > DV/HDR > cached > size, honouring the Sources filters. Shared selector plus tests, Sonnet; Kotlin gates.

### Detail page items, all handed to the revamp session (see Coordination)

- The glass synopsis panel looks wrong over the art; he prefers the previous version. Cinematic removes it.
- Fade on More Like This and Trailers.
- On scroll back up, the chips' glass re-forms but the action buttons' does not.
- Untranslated labels: `actionLabel(_ title: String)` uses `Label`'s `StringProtocol` initializer. The keys already exist translated. The status value ("Released"/"Ended") has no keys.

### P: Player, report only, no code this batch

- "Preparing Dolby Vision" is hard-coded for any native-player file, and it waits on a probe plus the remux of the first segment (up to about 60 s before falling back to mpv, which shows HDR10).
- Atmos survives only for EAC3-JOC. TrueHD and DTS become AAC 5.1, and mpv decodes to PCM.
- One small fix belongs in this batch: the overlay says "Preparing playback…" unless the track is actually DV (Sonnet, one file).
- Ask him whether tvOS Match Content → Dynamic Range is on. He uses Infuse, so this is low priority.

### Q: Questions he asked, answered in the reply DM

The reply explains, with the facts from the Explore report:
- Resolve Streams with Debrid, and Prepare Links (0–5). With AllDebrid on fiber the gain is small: it only skips the 1–3 s resolve when you press Play on one of the top N after the list has been open for a few seconds, and it costs link quota.
- How the auto-play pick works today.
- Trailer Max FPS / Buffer / Letterbox Probe: what each does, and leave them on Auto unless asked.
- Why the system font follows tvOS text size but Open Sans is a bundled face at 92% with its layout measured at the default size.
- The DV/Atmos limits.

## Coordination with the Detail + Settings revamp (running in parallel)

**Where it runs.** The revamp session owns the submodule working tree (branch `claude/detail-settings-revamp` off `5f2d5cd3`). Its uncommitted Xcode re-serializations touch `Localizable.xcstrings`, `Info.plist` and `project.pbxproj`. Therefore:
- **This batch runs in a separate local clone,** `~/Claude/Projects/NuvioMobile-steven-rc1` (branch `claude/steven-beta19-rc1-verdict` off `5f2d5cd3`), with its own `-derivedDataPath`. Never `git worktree` on the submodule. It lands with `git fetch <clone> <branch>:<branch>`.
- **Simulator:** this batch's UI legs run on a clone of the FA87 fixture, not FA87 itself, so the two sessions' runs can't collide. Device installs are sequenced with Christian, one build on the Apple TV at a time.

**Files this batch avoids** because the revamp owns them:
- `DetailView.swift`
- `DetailScrim`
- `EpisodesSection`
- every Settings pane except Home Screen
- `AboutSettingsPane` (being split into About + Developer)
- `ContentView.swift`

New debug knobs in this batch are launch arguments only, with no new About rows until the revamp lands.

**Shared files and conflict handling:**
- `NuvioTVUITests.swift`: test69 and a new N1 test. Edits stay inside those test functions; whoever merges second rebases.
- `HomeScreenSettingsPane.swift`: one new row (M4). The revamp's W3-A adds `descriptionID:` to every row; the second to merge adds the id for the new row.
- `Localizable.xcstrings`: this batch never hand-edits it. New strings stay English in code, and after both branches merge, one `populate-localizable-xcstrings.py` → translate (Sonnet) → merge run picks them up, alongside the revamp's W3-B if timing allows.

**What to hand the revamp session** (one message on Christian's go):
1. **Steven on the synopsis panel.** He dislikes the 560 pt glass panel and prefers the previous version (pre-build-133). Classic is currently specced as "today's page byte for byte", which keeps the panel he rejected.
   - Suggest that Classic restore the pre-T2 hero (left-column synopsis), or that D2 be revisited.
2. **Fix the action-button labels in both layouts:** `LocalizedStringKey`/`String(localized:)` in `actionLabel`. Add status → localized keys in the new About section.
   - This breaks "Classic byte-identical" by one line; worth it.
3. **Add the row edge fade (F's improved ramp) to More Like This, Trailers, Cast and Collection** when W2-A adds the section gates. The modifier lands in this batch first; if the revamp lands first, it can use today's modifier and pick up the better ramp automatically.
4. **One glass rule for the chips and the action buttons on scroll back up.** He sees the chips re-form while the buttons don't. Either flatten both while scrolling (manual `.glassEffect` on a stable button) or neither.
5. **"Colours too dark/cold":** treat BUG-127's stops as a ceiling and go lighter in the Cinematic scrim, as the plan already says. His Oak Street and Monstre photo pairs against Fusion are in `docs/research/steven-beta19-photos/`.
6. **The I1 decode-cap fix lands in the shared loader in this batch.** The revamp's backdrop needs no change to benefit; don't add a separate workaround.

**Merge order.** Both branches start from `5f2d5cd3` and touch almost disjoint files. Whichever is device-passed first fast-forwards; the other rebases (expected conflicts: the two noted above). The cut (beta.19-rc2) can carry either or both.

## Waves and delegation

**Rules.** At most 3 agents at once, split by file ownership. Agents edit, the main session builds, tests and commits. Opus is used for focus/scroll/motion judgment, Sonnet for exact specs. Codex is out until 10-29, so review means internal Opus read-only rounds.

| Wave | Who | Work |
|---|---|---|
| 0 | main | Clone, branch, baseline gates (NuvioTVTests, Debug + Release, test69/74/75/76, PinnedRow* units), FA87 clone; tracker rows |
| 0.5 | main + Christian | M1 device walk with streamed probes; B1 sim repro (background/foreground) |
| P | 1 Opus Plan | Specs for M2/M3/R2 (motion + morph, one owner) and T1/N1, built from M1 logs; 1 Opus critique |
| 1 | Opus A | M2 + M3 + R2 (`BrowseComponents` settle/slide, `InlineTrailerCard`, coordinator store) |
| 1 | Sonnet B | B2 listener lifecycle + tests (`TrailerLocalHLS`, two `playbackURL` call sites only, not inside ITC's morph code: coordinate via exact line spec) |
| 1 | Sonnet C | I1 Swift loader (`CachedAsyncImage`/`ArtworkStore`, call-site sizes) + Kotlin poster sizes |
| 2 | Opus D | C folder page + F fade modifier (`CollectionsUI`, `RowEdgeEffectStyle`) |
| 2 | Opus E | T1 + N1 (`TabBarContentScrollLink`, probe, `HomeUpIntoHeroGate`, HomeView Up path) |
| 2 | Sonnet F | R1 ring tint (after Opus A releases ITC), M4 delay setting, M5 hero text fade, P overlay copy, A Best ranking if approved |
| 3 | main | Gates: jvm + K/N (if shared touched), NuvioTVTests, Debug + Release, UI legs on the FA87 clone with reboots after ~6 runs |
| R | 2–3 Opus review rounds + fix agents | Until no P1/P2 |
| Comms | Sonnet draft → SlopMonster loop | Reply DM (fixes, answers to Q, asks: Match Content DR, Medium+ fade photo after the fix) |

## Device pass (Christian, Living Room Apple TV, **Test profile**)

Dev build with `-debug.homeScrollProbe YES -debug.pinnedRowSettleProbe YES -debug.trailerProbe YES -debug.tabBarStateProbe YES --console`, logged to `~/Downloads/steven-rc1-verdict.log`. Steven's settings.

1. **Home walk, 10 rows down and up, at Large and Medium+:** never two hero titles at once (old text fades out before the new text fades in), no stale hero after leaving a folder, no hero without a title or logo. Row motion is not judged here: M2 was dropped (H6) and the pinned motion is retired by the Stage batch.
2. **Inline trailer on a focused poster:** starts after the row rests, the ring keeps the poster colour, and leaving mid-morph shows no gap or ghost.
3. **Detail → Play via Infuse → return:** inline trailers still play, and after 30 minutes of browsing too.
4. **Detail backdrop and posters are visibly sharper** (Oak Street).
5. **Folder page:** the title rises and stays, the chips stay, the edges fade.
6. **Cold launch, then rest on row 1:** the tab bar is fully shown or fully hidden, never half.
7. ~~Empty Continue Watching, Up from row 2: focus lands on Genres.~~ Dropped with N1 (H6).
8. **Row fade at Medium+** on portrait rows.
9. **Trailer Start Delay** options.
10. **Auto-Play Best** (if built) on Lizzie Borden picks the HDR link.

## Christian's calls before Wave 1

1. Auto-Play Best Source: rename (a) or real quality ranking (b, recommended).
2. Trailer Start Delay default: Automatic (rest + 1 s), recommended, or keep 1 s.
3. Soft fade as the default, now a real setting after the revamp (yes/no).
4. Colour: warmer neutral tokens now (yes/no); ambient poster-colour background logged as FEAT-53 for later.
5. FEAT-43 Follow layout as the next batch (yes/no).
6. Send the coordination message to the revamp session (yes/no).

## OUTCOME

### Wave 0 (2026-10-03)

- Clone `~/Claude/Projects/NuvioMobile-steven-rc1`, branch `claude/steven-beta19-rc1-verdict` off `284fd764`. `local.properties` copied (backend `https://api.nuvio.tv`); MPVKit symlinked from the main checkout.
- **Baseline on `284fd764` (FA87):**
  - Debug and Release simulator builds green; NuvioTVTests **709 / 0**.
  - UI legs:
    - test74 PASS, test75 PASS, test76 PASS;
    - **test69 SKIPPED**: no collection row on the guest fixture's Home. The C test plan seeds one through the existing `-debug.collectionsSeedJsonB64` helper.
- Tracker (`87430cf`): BUG-131…140 and FEAT-52…54 added; BUG-66, BUG-126 and BUG-127 annotated.
- **Design phase done.**
  - Spec A r2 (`docs/research/steven-rc1-fix-spec-A-motion-trailers.md`) and spec B r2 (`docs/research/steven-rc1-fix-spec-B-images-rows-detail.md`) written.
  - Opus critique (`docs/research/steven-rc1-fix-spec-critique.md`): 30 findings, 2 P1 / 15 P2 / 13 P3. Both P1s fixed in r2: the hero-mode Play/Pause mute path, and the hero sharpen moved after commit so prefetches are unchanged.
  - The waves follow the critique's merged plan (W1 A/B/C, W2 D/E/F, W3 T/D/A, W4 H/G).
- **metahub poster sizes measured (main session):** small 300×450, medium 500×750, large 780×1170 (2–3× the bytes of medium) on three titles. The `large` poster upgrade stays.
### Wave 1 + Gate 1 (2026-10-03 evening)

- **Clone commit `8d3e361b`.**
  - W1-A (Opus): M3 rest gate + per-row playing key, hero-mode mute kept; R2 morph stages and abort.
  - W1-B (Sonnet): I1 decode sizes, w780 + metahub large posters, original logos.
  - W1-C (Sonnet): B2 listener lifecycle.
- **Gate 1:**
  - Debug green; NuvioTVTests **788 / 0** (+79); jvm **1372 / 0**; K/N **1390 / 0**; w500 grep gate clean.
  - Warnings 321 → 321: two new Swift-6-only isolation warnings, both harmless in Swift 5 mode (the `ArtworkLetterbox.zoom` call shape copied from `CachedAsyncImage`; Detail's legacy trailer completion is now `@Sendable` but still delivered on main).
- **Simulator (FA87), classic hero:**
  - gate fires at rest + 1.00 s (`src=clock` until W2-E feeds Home's rest);
  - morph goes reveal → wide; row scroll pass 1 moves, pass 2 measures `fits`;
  - the listener starts on first use and serves 1920×1080; the trailer attaches and plays;
  - a fast double-Right collapses the card cleanly.
- **Image probe:**
  - Home posters fetch metahub `poster/large` 780×1170 and decode at card size 512×768 (`req=768`);
  - backdrops ≥ 1920 go to the large pool;
  - `poster/small … req=1920` lines come from call sites scheduled for W3/W4.
- **B1 knob recipe:** `silent` → `health alive=0` → `dead reason=active` → `rebuild prefer=8230` → `retire-timeout` → `ready port=8230` (same port) → new titles play.
- **Finding, pre-existing, not from this batch.** In the pinned (Nuvio-style) hero on the simulator, focus jumps from the morphing row-0 card into the hero about 1.3 s after the morph starts (`upFallback … reason=upIntoHero src=press-any`), and the card collapses. The unchanged `284fd764` build does the same. It only touches Classic's pinned mode, which the Stage batch retires. Recheck on the device pass with the Nuvio hero on.
- **Mute in both trailer locations** waits for W2-E's leaf readout (no log line yet); checked at Gate 2.

### Wave 2 + Gate 2 (2026-10-03 night)

- **Clone commit `f12c1d29`.**
  - W2-D (Sonnet): R1 ring, B2 inline call sites, M4 row.
  - W2-E (Opus): M5 `TextSwapModel` + `HeroTextLayer`, cover freeze, logo ink, M3 Home hooks, DEBUG leaf labels.
  - W2-F (Opus): F Soft default + `row_edge_fade` Appearance setting + migration, C folder header, all SettingsDescriptions copy.
- **Gate 2:** Debug + Release green; NuvioTVTests **863 / 0** (+75); `devRowEdgeFade` gone; `debug.rowEdgeFade` only in comments and the legacy key.
- **Simulator:**
  - **Hero text:** a 10-step pinned-hero walk reads `maxLive=1` throughout (swaps 1 → 11 → 12), so never two title blocks at once; `present … logoInk=legible`; one `logoInk sync-sample ms=1.01`.
  - **Mute, Poster location:** `event=play host=card`, then `mute muted=0`, then `muted=1`.
  - **Mute, Hero location** (row card focused, `-hero_trailer_autoplay YES`): `gate … host=hero src=pinned`, `event=play host=hero`, then `muted=0` / `muted=1`. The critique's P1 case is fixed.
  - **Listener readout:** `rebuilds=` and `recent=` present.
- **test69 / test70 harness, in progress:**
  - **test69:** the folder seed imports (`[CollectionsSeed] imported=true collections=1 folders=1`). The walk could not see a folder with no hero art (BUG-38 rule), so the seed now carries a backdrop. It now reaches the page, then skips: it samples pixels at the header's accessibility frame (y −443), which ignores the visual-effect offset. Being fixed.
  - **test70:** legs now land in identical states. The scrolled phase matches Off almost exactly (middle 0.00013, focused card 0.00003). The rest phase differs by 0.094: Off and Soft rest bands look identical, so the difference is the pinned hero backdrop behind the cards. Being fixed to compare card interiors.

### Wave 3 + Gate 3 (2026-10-03 night)

- **Clone commit `2b53224c`.**
  - W3-T (Opus): T1 legs behind `-debug.tabBarRestFix 1|2`, default 0, works in Release; `off=`/`ins=` probe.
  - W3-A (Sonnet): Auto-Play Best ranking + "Preparing playback…" unless DV.
  - W3-D (Sonnet): D1 labels + status keys, D2 glass never changes on scroll, D3 lighter scrim (top-left 0.60 → 0.33), F on Detail rows incl. Episodes, Detail I1 sizes.
- **Gate 3:** Debug + Release green; NuvioTVTests **898 / 0**; jvm **1385 / 0**; K/N **1403 / 0**; composeApp iosSim **435 / 0**.
- **UI legs, passed:** test69 (seeded folder page), test80, test74, test79, test75, test76, test64, test65, test83.
- **UI legs, skipped (guest fixture limits, unchanged from before this batch):**
  - test77: Play disabled on the guest;
  - test78: synopsis fits, no sheet;
  - test58 / test63: four rows, wrong poster regime.
- **UI legs, failed, both traced to the harness, not the app:**
  - **test33's Classic leg:** `glass=1` at rest because `-debug.trailerForceNoTrailer` is honoured only with `-debug.trailerProbe YES`. Detail played its trailer, which correctly flattens the glass. Fixed by adding the flag.
  - **test70's rest phase:** the first launch after a cold start rests the pinned rows about 14 pt lower; Soft happened to run first. Off-first then Soft-second rest shots are pixel-identical, shift 0. Fixed with a throwaway warm-up leg. The scrolled phase already matched Off exactly.

### Wave 4 (2026-10-03 night)

- **Clone commit `4665b300`.**
  - **W4-H (Opus), I1.7 hero sharpen:**
    - prefetches, the launch head and the deadline-bound hero fetches stay as before;
    - 0.6 s after a commit, the on-screen hero sharpens to the form size (Nuvio 3072 bucket, classic full-bleed) and the TMDB logo to `original` at slot size;
    - the sharpen is a same-identity `adoptSharpened` and logs `[HomeHero] sharpen start|adopt|paint|none|skip`.
  - **W4-G (Sonnet), new UI legs:** test85/85B/85C/86/86B/87/88/88B/89/90/91 in `TrailerMotionUITests.swift`, plus `-trailer_start_delay 1` pins on the legs that assumed the old dwell.
- **Gate 4:** Debug green; NuvioTVTests **913 / 0**. UI batches running. Review round 1 running: two Opus read-only passes, A trailers/hero and B images/rows/Detail/tab bar/auto-play.

- Previously: design phase running: spec A (`docs/research/steven-rc1-fix-spec-A-motion-trailers.md`: M3, R2, R1, M4, M5, B2) and spec B (`docs/research/steven-rc1-fix-spec-B-images-rows-detail.md`: I1, F, C, T1, A, Detail items, P).

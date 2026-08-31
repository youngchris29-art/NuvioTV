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

## Status 2026-08-29 (later the same day)

- **Wave 1 DONE + MERGED (`0d707629`)** — Codex settled r4 (per-token push debts; two documented
  declines). **Wave 2 DONE + MERGED (`571c2129`)** — Codex clean r1; NOTE the agent's frame pulls
  corrected the synthesis: the VIDEO's blank pane was Wave 2's bug (rows present, invisible —
  header read "6 sur 14 actives"; tvOS label-inversion never reaches free-standing cell content,
  and ChipButtonStyle forced .dark, erasing the chevrons), while Wave 1's data clobber is a real
  but distinct reachable state. New `settingsRowPlatterActive` env key; 7-point device checklist
  in the Wave 2 commit + agent report. Both waves are DEVICE-PASS OWED together.

## Wave 3 investigation outcomes → Wave 4 specs (all file:line refs in the agent reports)

1. **Trailers: French rank bug (HIGH, 1-line)** — `TmdbMetadataService.kt:1419-1430` compares
   TMDB's always-English `type` ("Trailer") against `resourceString(generic_trailer)`
   ("Bande-annonce") → Trailer group ranks last alphabetically → `prefix(10)` = all Behind the
   Scenes for non-English users. Fix: literal compare + first-ever `fetchTrailers` ordering test.
2. **Trailer zoom collision (HIGH)** — zoom cache is TITLE-keyed and `TrailerHeroPlayerView.swift:808-826`
   applies the cached zoom BEFORE the token check with no conceal on mismatch → row clips inherit
   the hero's ~1.34 crop visibly. Fix: apply only on tokenMatches + conceal on mismatch (or
   per-video zoomKey at `DetailView.swift:337`). No-build diagnostic exists (`debug.trailerProbe`,
   `debug.resetTrailerZoomStore`).
3. **HDR-variant washout risk (beta.16+, MEDIUM)** — `InAppYouTubeExtractor.kt:483-494` HLS
   variant picker has no VIDEO-RANGE filter; the 08-28 visionos client swap changed the offered
   set; PQ on the bare non-EDR AVPlayerLayer renders milky-white. Fix: skip non-SDR variants.
   (Steven's beta.15 white frame is more likely the French-tier hero picking a bright BTS clip.)
4. **"No Zoom on Focus" never disabled the system lift (HIGH, explains multi-beta BUG-64)** —
   zero `focusEffectDisabled()` in the codebase; `.borderless` lifts the whole lockup at ~20 card
   sites regardless of the setting; no test ever asserted still-mode rise ≈ 0. Fix: shared
   `cardFocusButtonStyle()` modifier + call-site sweep + rise test at `-no_zoom_on_focus YES`.
   Related: beta.15 doubled `cardSystemLiftScale` 1.06→1.12 sim-derived (device-validate or
   scope to caption-drop only); `.manualScale` scales the LOCKUP (title included) unlike
   `.systemLift` (artwork only); false comment at `NuvioTVUITests.swift:3283` claims
   `accent_focus_ring` is synced — it is plain @AppStorage, correct it.
5. **Card Depth "thick on Subtle" (MEDIUM, pre-beta.15)** — `CardDepthStyle.swift:188-203` keys
   lineWidth on COVERAGE (<1 → 2pt boosted rail), so Subtle+Top (the default) is thicker than
   Bold+Full; still-mode border is a fixed 4pt unrelated to depth; beta.15's new black platter
   amplifies the rail. Fix: derive width from edgeStrength (update CardDepthRailTests in step).
6. **Poster/tile title overlap (MEDIUM)** — beta.15's fix addressed only a one-frame flash; the
   steady-state intrusion is a FIXED 72pt slide cap (~46pt onto artwork) vs SCALED cards, worst
   on folder tiles (`CollectionsUI.swift:221-227` collapses square/landscape height to
   style.width → up to 25% intrusion). Fix: clamp slide against actual artwork height
   (`BrowseComponents.swift:166-169`) + reconsider tileHeight. Steven's Size/ring answers
   (asked in DM) decide whether the 1.12 lift revert joins this item.
7. Reporter asks outstanding: Size + ring settings (asked); About-pane Focus Mode readout photo
   (worth adding); doubled hero needs his beta.16 Hero Paint Diagnostics photo.

## Status update 2 (2026-08-29, evening)

**Wave 4 DONE + MERGED (`c705c7aa`)** — all six items; Codex settled ROUND 7 (r1: cross-manifest
SDR + localized blank-type rank + cast/chip sweep gaps; r2: slide cap visibility P1 → the
proportional cap is PROBE-ONLY, binding stays absolute (visibility beats bounded intrusion; the
deep rests are the settle bug); r3-r5: still-ring design converged to artwork-hugging rings drawn
INSIDE FolderTile/CastCard fed by site FocusState; r6: expanded inline-trailer neutral ring).
Steven CONFIRMED the beta.16 Settings-icons fix in DM.

**Two specced follow-up slices remain before beta.17:**
A. **beta.16 trailer regression (HIGH — investigation definitive):** visionos returns
   hlsManifestUrl → repack path disabled by a `>` tie-loss (`repackWorthwhile`,
   TrailerExtractionPlatform.apple.kt:145) → raw VIDEO-ONLY variant playlist (extractor parses no
   EXT-X-MEDIA audio groups) → silence + fragile playback = both reported symptoms; android_vr
   was ALREADY dead (LOGIN_REQUIRED in the 08-27 rig logs) so beta.15's "working" trailers were
   the repack path all along. Fixes: F1 `>`→`>=` (1 char, do first), F2 master-URL when the
   picked variant carries an AUDIO group, F3 ordered client chain (android_vr, visionos) instead
   of a single preferred client. F4 only if device logs show sidx 403 (UA plumbing). Zero-build
   diagnostic: [TrailerExtract] `manifests collected=` and `repack decision:` lines are
   unconditional NSLog — Steven's own log answers H3.
B. **Scroll-repro settle fix (Steven's right-then-up overlap, Large):** mechanism = mixed-shape
   collection row height collapses ~134pt during horizontal scroll (LazyHStack sizes to REALIZED
   tiles; square tile = width, poster = 1.5×width) → the up-reveal computes against a layout
   that no longer exists → wrong settled rest → title correctly parks on artwork. Why Large:
   proportional focus lift vs constant 16pt cushion (1.12 eats it at Large, not Medium),
   viewport slack 121pt vs 194pt, biggest collapse delta. Fix list (scroll-repro report):
   (1) re-reveal on settle via onScrollGeometryChange, (2) `.frame(minHeight:)` on the
   collection shelf from max folder artworkHeight — one line, kills the displacement at source,
   (3) lift-aware clearance / device-validate the 1.12 constant, (4) rowKey into styleKey
   (CW/Upcoming sibling re-match hazard), (5) real artworkHeight for CW/Upcoming probe values,
   (6) nil-measure no longer snaps slide to 0.

## Status update 3 (2026-08-30) — rc1 verdict + Wave 5

Steven's rc1 verdict (DM 08-29 20:09): PARTIAL — trailers+sound and card depth FIXED; still
broken: catalog selection (functional), description-trailer zoom, "No zoom on selection"
lift, Large-poster title overlap.

**Catalog selection ROOT CAUSE + Wave 5 MERGED (`468d7aff`, PUSHED).** Sim-reproduced, not
device-only: since the beta.15 Settings List revamp the Hero Sources / Catalogs groups were ONE
native List row each (header + all expanded rows), and a tvOS List row exposes exactly one focus
target — no expanded row was EVER focusable. "Impossible to select" was literal for three betas;
Waves 1-2 fixed data + legibility but selection was never reachable. Wave 5: every expanded row
hoisted to its own List row (expansion state pane-level, reset on branch disappearance);
CatalogSettingRow reshaped to row-Select-toggles + long-press context menu for reorder (three
chips in one row = the same trap one level down); hero-source DRIFT-REFILL in the repository (a
selection stranded on keys vanished from a still-present addon refills first-in-order instead of
staying 0-of-2 forever — the live fixture healed on launch) with an exact per-preference addonId
stamp (new stored field, "" fails closed) so incremental manifest loading and colon-containing
addon ids can never misread an unloaded addon's selection as drift. Codex settled ROUND 7
(orphan consumption, partial-load P1, expansion-state P3, two colon-id prefix escalations →
exact-id stamp, remote stamp preservation, UI-test abort + teardown-restore hygiene; r7 clean).
Gates: jvm suite + 7-scenario HomeCatalogSettingsHeroDriftTest green, sim build green, NEW UI
regression gate test45CatalogsGroupFocusReachesExpandedRows green (walks focus INTO an expanded
group — the gap that let this ship), interactive sim pass incl. context menu. Device pass owed
with the rest of the batch; a beta.17-rc2 needs cutting for Steven.

## Status update 4 (2026-08-30, overnight) — Waves 6/7/8: the rest of the rc1 list

All three remaining rc1 items fixed, committed, PUSHED (submodule tip `218a700c`):

**Wave 6 — description trailer zoom (`6c330e69`, Codex clean r1).** Three compounding defects:
token-matched cache entries were terminal (a bad crop from betas ≤16 reapplied for 30 days —
repack tokens are release-stable), the hero loop + every Trailers & Extras clip thrashed ONE
title-keyed entry, and finish() persisted maxZoom-clamped logo-window measurements. Fixes: store
v1→v2 (upgraders' stale entries die on first launch), per-clip zoomKeys, VERIFY mode (a match
applies instantly but re-measures and corrects/confirms — probe-verified live: persisted-hit →
verify-confirmed), clamp guard, smoke-knob for the full-screen path.

**Wave 7 — "No Zoom on Focus" (`4dce574d`, Codex r1 declined-documented).** The entire no-zoom
mechanism was ONE unverified focusEffectDisabled; still mode now uses a custom StillCardButtonStyle
(cannot receive the system lift, hardware-independent). The still-ring band reservation (BUG-64's
accent-ring inset) was never applied to the neutral ring Wave 4 made universal — that WAS "Ring
Focus even when off cuts off the posters"; all five ring sites now reserve the band. New
test46StillModeRiseIsZero (ring-aware luma measurement) — the rise gate Wave 4 specced but never
wrote. Its first run measured rise=4.0pt = exactly ringWidth: independent proof the lift is gone
and the band reserved.

**Wave 8 — Large title overlap (`218a700c`, Codex 10 rounds, r11 re-review OWED — quota reset
06:07).** Sim-reproduced: focused Large rows settle at margin≈-90 with slide saturated at 72 →
net NEGATIVE + 46pt intrusion (66 against the focused card); the lift is a FIXED ~20pt at both
sizes (pixel-measured — the proportional-lift theory is dead), so the cause was the size-dependent
settled rest 954d62a9's deferred settle re-reveal never fixed. Shipped: the settle re-reveal
(monotone/bounded/self-disarming ScrollPosition nudge), lift/mode/row-aware clearances (0 in
Wave 7 still mode, 20 native incl. folder tiles, scale-derived for ring mode), a visibility fade
belt for uncorrectable rests, lift-honest probe fields (device logs were under-reporting by
exactly the lift), and gate test47 (settle-probe oracle; AX frames + pixels are both documented
vacuous-green traps here). Before/after verified live: margin -90/net -28 → margin +24..42/net ≥ 24.

**⚠️ Fixture state: FA87 deliberately left at Size=Large + No Zoom ON (+ ring off) — Steven-parity
for the beta.17 device pass. Restore Medium + No Zoom off afterward.** Trailer zoom store was
reset during Wave 6 verification (v2, one healthy entry). Device-pass extras: grep
`[HomeScrollProbe] settle` for MISS/DISARMED (the one device-falsifiable assumption is
contentInsets.top==0 in pinned mode — disarm leaves beta.15 behavior + fade belt), and
`[TrailerZoom] verify-` lines on a title played under beta.15/16.

**Status update 5 (2026-08-30 late evening): Wave 8 review debt CLEARED (+ concurrent-session
work folded in).** Codex r11 (scoped `--base`) + r12 (via the concurrent plugin session's
tree-wide round) settled: sliding-window motion classification (creep vs deceleration-tail —
the two regimes must not merge), focused-lockup correction bound on mixed-shape rows (exact
per-folder extent incl. the title-logo-replaces-caption case), host-lifecycle seams closed at
BOTH ends (the theme `.id()` swap registers the incoming host first, so takeover — not
disappear — is the boundary that always runs), and test46 hardened against pinned-title
pollution (its one red run measured rise=-39.5 = title glyphs; the walk now side-steps the
title band; test44 shares the exposure, noted in-comment). Follow-up `5cec7563`; branch tip
`b08dc991` PUSHED — also carrying the three spawned-task fixes that landed concurrently:
`603d1081` plugin push race (upstream-report candidate: upstream's PluginRepository.pushToServer
carries the identical race), `3a0b3640` AES-GCM oneshot (GCM never used the IV and never
verified tags — latent while pluginsEnabled=false), `082a0935` CI trigger for
tvos-shared-extraction. Gates: test45/46/47 + full jvm green on the merged state.

**Status update 6 (2026-08-31): DEVICE PASS RUN + Wave 9.** Living Room ATV (fresh dev-signed
install over the sideloaded 114 — devicectl needed a reboot for wedged DDI services, and
signature-mismatched upgrades fail with opaque IX errors): B (trailer zoom) and C (no-zoom/ring)
CONFIRMED on hardware; catalog toggles + context-menu reorder confirmed. Two failures, both
root-caused from the device probe log and fixed in Wave 9 (`2c256ff7`, PUSHED, Codex settled r4,
gates test45-48 green): (1) hero-source limit rows were a focus trap (.disabled → eject to tab
bar) → focusable-but-inert; (2) the Large title overlap persisted because hardware parks rows
~75pt deeper (BUG-66 tab-bar family), Large frames become unsatisfiable (bound=19..0), and the
visibility belt livelocked (nil-measurement epoch resets + corrector motion stamps starved its
rest gate) → unmeasured-holds + stand-down handoff + monotonic 2.6s fade ceiling; test48
reproduces the device rest shape (margin=-80/intr=45/bound=0) in sim and gates both directions.
Also: cinterop tasks now track the shim header (stale-klib footgun hit twice). Remaining:
short device RE-CHECK of A+D on this build, the BUG-66 deep-park decision (fixing the tab-bar
tuck would let the corrector fully succeed on device instead of belting), rc2 cut + Steven DM.

## Sequencing

1. Wave 1 now (it also neutralizes the H5 widening our beta.16 gate introduced — do not ship
   another beta before this).
2. Wave 2 next (device-verify with Wave 1's pass).
3. Wave 3 investigations can run as Explore agents in parallel with Wave 1 implementation
   (read-only, disjoint); their specs become Wave 4 implementers.
4. One beta.17 at the end of Waves 1+2 (+ whatever Wave 4 items are ready), single release wave.

# beta.13 release plan (drafted 2026-08-16, the day beta.12 shipped)

Successor to the beta.12 plan (`~/.claude/plans/lets-build-a-plan-elegant-frost.md`, executed
2026-08-10 → 08-16; record in `docs/research/beta12-campaign-notes.md`). Same shape: scoped waves,
a Codex gate per wave, sim suite + one consolidated manual device pass, then `release-beta.sh`.

## Context — where beta.12 left the board

- **Shipped 2026-08-16:** `tvos-v0.3.0-beta.12` (build 108, `2a8c387c`), announced as `p41ifp4`.
  17 tracker rows flipped to released; all await "confirmed in the wild".
- **Public promises now outstanding:** **BUG-58** (colour picker in Appearance draws on a black
  background — Christian promised the fix "in the next beta" in `p41ifp4`). Nothing else was
  promised in the announcement.
- **Open questions posted, awaiting reporters:** UX-9 (which title shows the letterboxed focus
  trailer?), BUG-62 (tab bar clipped — repro asked 08-13), FEAT-22 (auto quality — answered
  08-13), BUG-47 (u/tiyeuedm's Stremio Catalog Plus retest, DM), DOC-2 (account-change
  propagation — needs a code check THEN an answer).
- **Retests due on 108:** BUG-46/55 (long-session trailer survival on the stateless build),
  BUG-31 (No Zoom on Focus everywhere; the system lift stays by design), BUG-38 (collection
  backdrop against the reporter's own config), BUG-39 ("still average" → sharper?), BUG-43/45 on
  the White theme, FEAT-19 (u/tiyeuedm in Tiếng Việt).
- **Explicitly deferred out of beta.12:** TMDB Discover exclusion-filter *UI* (shared plumbing
  landed `7dac9a67`), self-hosted server discovery (upstream `ddc28dc8`/`cc20e716`, product
  decision), subtitle minimum font size (product decision), title-hoisting rework (moot now —
  BUG-53 closed by reach 88; keep parked), further BUG-39 gains (source-limited; the trade shipped).
- **Watch list carried:** non-fatal `PostgrestRestException: Unsupported Nuvio client (22023)`
  from `register_current_device` on every launch (caught, retried every 15 min) — the backend
  does not recognise this fork's client id; harmless today, but it is a silent dependency on the
  official backend's tolerance. Codex branch-level findings left for triage: quickjs `mavenLocal`
  reproducibility (Sentry URL scrubbing `d5b29180` and Hebrew locale `df18b711` already fixed).

## Scope decisions (CONFIRMED by Christian 2026-08-16 — "yes to all four": BUG-58 headline + FEAT-18/UX-8/BUG-57 build set; FEAT-17 DECLINED as asked (native answer in the reply); self-hosted discovery = LATER; negative beta.12 retests jump the queue)

1. **BUG-58 is the headline** — it is the only public promise; the campaign is not done until it
   is fixed AND device-verified on the White theme with the reporter's exact route.
2. **Ship the three small, well-specified tester asks that have survived multiple releases:**
   FEAT-18 (title always shown in the trailer focus view — "smallest and best-specified item on
   the board", asked twice), UX-8 (hide the entire Discover section — one container toggle
   satisfies all three statements), and the BUG-57 "Upwards" card-depth mode.
3. **FEAT-17 (hide the top pill nav) — decide, don't drift.** Recommendation: **decline as
   asked, offer the native answer.** The tab bar is the tvOS system tab bar and already
   minimizes on scroll (beta.11); removing it entirely is the Android-TV-copied feel this fork
   exists to avoid (memory: `nuvio-tvos-native-feel-principle`). If Christian wants a middle
   ground, the only native-shaped option is "start minimized" — scope it only if he says so.
4. **Upstream ports:** TMDB Discover exclusion-filter UI needs real tvOS design → **Later**
   unless a tester asks. Self-hosted discovery → **decision only** this cycle (yes/no/later),
   no build. Subtitle min size → decide tvOS's own range when the player gets a styling pass.
5. **Not this cycle:** FEAT-3 TestFlight (research done, separate track), FEAT-16 font choice,
   FEAT-22 auto quality (needs the reporter's fallback answer first), UX-2/UX-3 batches (done),
   BUG-39 beyond the shipped trade, title hoisting.

## Wave structure

### Wave 0 — Identify before fixing (sim-runnable now)
- **BUG-58 surface hunt — ✅ DONE 2026-08-16.** Christian's own Apple TV clip (`IMG_0193.MOV`,
  12 s, default theme) settled it: it is the inline **Theme swatch row itself**, not a pushed
  screen. As focus walks the row, the FOCUSED swatch's name label vanishes — near-black text on
  the dark pane ("Amber" disappears while focused). Cause: beta.11's BUG-50 sweep (`6028ef1c`)
  painted the focused `SwatchLabel` `onFocusPlatter` (`black.opacity(0.85)`) on the false
  premise that the `.borderless` swatch button draws the white system platter — it doesn't
  (lift only). Route: Settings → Appearance → Right into the pane → any swatch focused.
  (The reporter's "black background" = this; on the White theme every other pixel is light so
  the black label reads as a black backdrop.)
- **BUG-57 A/B method.** Prefs injection is INVALID for profile-synced payload keys
  (beta.12 lesson: sync restores the account value at launch). Plan the A/B through the real
  Settings UI in the UITest harness (or with sync disabled for the run) — decide which before
  anyone touches `card_depth_style_payload_2`.
- **DOC-2 code check — ✅ DONE 2026-08-16.** Pull-only, two triggers (profile pick = full pull;
  every foreground = forced full pull), NO timer on tvOS (the 4-min loop is composeApp-only);
  appearance prefs are per-platform namespaced (phone/web changes never reach the TV — by design);
  addon set removed to zero on web won't clear the TV. Answer drafted in the tracker row.
- **`Unsupported Nuvio client (22023)` — ✅ ROOT-CAUSED + FIXED 2026-08-16.** Not a server
  allowlist we can't influence: the fork's 07-29 port renamed `p_client_name` from upstream's
  `"Nuvio Mobile"` to `"Nuvio tvOS"`, and the RPC rejects unknown names. Reverted to the
  accepted literal (`DeviceSessionRegistration.kt`; platform "tvOS 27.x" + device name still
  identify the box honestly). **Empirical (sim unified log, 2026-08-16):** the warning fired
  on 3/3 launches before the rebuild (11:49, 11:59, 12:09) and on 1 of ~18 launches after it
  (13:52, no "Unsupported" text alongside — read as transient). Watch once on device; the
  Living Room box should now appear in the account's device list.
- Codex gate 0.

### Wave 1 — BUG-58 + the theme family (P3 but promised; highest comms risk)
- ✅ **Fix landed 2026-08-16 (`2799bc79` in NuvioMobile, `AppearanceSettingsPane.swift`):** focused swatch
  label → `textPrimary` (focus brightens; selection reads primary at rest — the same shape as
  ProfileSelectionView's borderless avatar tiles); the misleading BUG-50 comment replaced.
- ✅ **Class sweep done:** every other `onFocusPlatter` consumer (`RowTextColor`, the Settings
  sidebar, `StreamBadges` focused chips) sits on `.settingsRow`/chip styles that DO draw the
  platter — `SwatchLabel` was the only misapplication. `PlaybackSettingsPane`'s borderless
  subtitle-colour swatches carry no text label, so nothing to fix there.
- ✅ **Regression guard:** `test26ThemeSwatchFocusedLabelLegible` (NuvioTVUITests) walks focus
  onto Violet and MEASURES the label band under it in the screenshot — asserts max luma > 0.7
  and > 0.5 % bright pixels (26.5 sim result: max 1.0, 17.2 % bright; pre-fix would be ≈0.05 /
  0 %). Skips loudly if the swatch never reports focus (27.0 runtime gotcha). One more test in
  the suite (57 → 58 in the Verification count below).
- ⏳ Device check on the White theme by the reporter's route → device-pass item (1).
- ✅ Codex gate 1 clean (2026-08-16, `--base HEAD~2 --scope branch`: "focused swatch now uses a legible foreground color for the platter-free borderless style, and the added UI test appropriately exercises that state"; the one P1 raised — CGFloat×Double — was a false positive under SE-0307 but the scale factor is now an explicit CGFloat, `5a7830f8`).

### Wave 2 — Small tester asks (each independent, each its own commit) — ✅ BUILT 2026-08-16
- ✅ **FEAT-18** (`f6bf490e`) — the premise was subtler than the tracker note: nothing "hides" a
  title on trailer start; the caption below the tile survives playback. The reporter runs **Hide
  Titles** (p2qudtq t22 — no captions anywhere), so the playing tile carried no title at all.
  Fix: logo art (text fallback) drawn ON the tile bottom-left over a foot scrim, only when the
  caption slot is hidden; bottom-anchored (pinned band untouched), after `.clipShape` (ring
  precedent). Sim-verified (test28).
- ✅ **UX-8** (`a9b1b05e`) — Content Sources → Search Sources → "Hide Discover", synced via the
  shared home-catalog payload (`hide_discover`, hideCatalogUnderline precedent; other clients
  ignore unknown keys and merge on push). Skips the Discover fan-out while hidden and re-arms on
  clear. Sim-verified (test29 round-trip).
- ✅ **BUG-57** — "upwards" is *En haut* = Edge Coverage **Top** (BUG-31's unfixed half). The
  Settings-UI A/B (test27, Bold, ring+no-zoom) showed Top's 1 pt ≤56 % hairline is invisible at
  couch distance while Full's closed hairline registers. Top/Half now draw a 2 pt rail with the
  top stop lifted ×1.5 (cap 0.9); mask geometry and Full unchanged. `CardDepthRailTests` (6 unit
  tests). Sim A/B renders on file (`docs/research/bug57-sim-ab/`).
- **Harness work this wave (kept, it is what made the A/Bs possible):** `openTab` climbs until
  a tab reports focus (fixed Up×8 could not leave a long pane); `walkToRowByTreeIndex` counts
  ROWS by frame (chip rows are one row), anchors on the focused element's frame, hops only to
  unique-label rows, re-enters the pane by category when a tree rebuild drops focus onto the
  sidebar, and excludes the tab bar; `ensureToggleRow` is state-aware via a new
  `accessibilityValue("On"/"Off")` on `SettingsToggleRow` (a real VoiceOver gain);
  `test30AppearanceBaselineRestore` puts the synced sim profile back to Ocean/portrait/all-OFF
  — run it after ANY failed appearance test (a mis-landed walk once flipped Landscape Rows and
  the theme on the real account). Sim-run lesson: Right-first along chip/swatch rows — Left from
  the leftmost element exits to the sidebar, whose focus SWITCHES panes.
- ✅ Codex gate 2 clean (2026-08-16, `--base 5a7830f8 --scope branch`: "No actionable correctness defects … persistence, synchronization, view-model lifecycle, and UI wiring changes appear internally consistent").

### Wave 3 — Home tab-bar clip (BUG-30 / BUG-62), device-only
- The `0ad450b6` measured reframe shipped in beta.11 with the device verdict PENDING and an
  open question in code (engine may align to the `.glass` CTA frame; `debug.homeScrollEdgeHard`
  A/B knob ships off). BUG-62 (a new reporter, 08-13) is likely the same. Device pass item:
  read `REST classic residual` on hardware; if 67 unchanged → restyle the CTA (device in the
  loop, NOT one of the six banned rounds). No sim work possible.

### Wave 4 — Localization catch-up + upstream check
- Every new string from Waves 1–3 through the populate pipeline: 6 languages (incl. vi) at
  key-count parity — FEAT-4's failure mode (German 81 keys short) is the acceptance test.
- Daily upstream check continues (`docs/upstream-port-plan-*.md`); port anything mechanical
  that lands; carry the three decision items unchanged unless decided.

## Verification

- **Automated:** full suite (57 UITests + `GifDecodePlanTests` 14 + `StreamBadgeColorTests`
  + `AccentFocusRingTests`) on tvOS 26.5, structural guard, `TrailerSoakTests`; new tests for
  Waves 1–2. Check for concurrent sim sessions before runs (osascript sim input is dead while
  the Claude app is frontmost — drive via the XCUIRemote harness).
- **Manual device pass** (one consolidated checklist, `docs/research/beta13-device-pass-checklist.md`
  when written): (1) BUG-58 on the White theme by the reporter's route; (2) FEAT-18 with
  Trailers on Focus in both hero modes; (3) UX-8 toggle round-trip incl. sync; (4) BUG-57 both
  depth modes; (5) BUG-30/62 residual read; (6) VidHub retest with the `debug.vidhubMethod` knob
  IF VidHub has shipped an update; (7) regression sweep of beta.12's device-verified items.
  Launch-arg knob route + live `devicectl … --console` capture (no USB on the Living Room box).

## Release + comms

- `release-beta.sh` discipline unchanged: README features (+ screenshots for anything visible:
  FEAT-18/UX-8) FIRST, `bump version` (109) + `scripts/release-notes/tvos-beta13-highlights.md`,
  cut `tvos-v0.3.0-beta.13` to both repos, then the Reddit block via old.reddit
  `/api/editusertext` + modhash (works on the gallery post — beta.12 lesson, no UI needed).
- Announcement must: close BUG-58 by name (promised); name FEAT-18/UX-8 to their askers
  (u/mrStevenx3); state BUG-30/62 honestly; carry the retest asks; keep the native-feel line on
  focus motion (`p41ijt8`) — do not re-open "still cards".
- Tracker: release entry, rows flipped, Now cell rolled; the beta.12 rows move to Resolved only
  on wild confirmation.

## Out of scope (explicit)

- Removing/hiding the system tab bar (FEAT-17 as asked) and any "no focus motion at all" —
  design principle, see Scope decision 3.
- TMDB Discover exclusion-filter UI, self-hosted discovery build, subtitle-size range — decisions
  recorded, no build unless Christian says so.
- FEAT-3 TestFlight, FEAT-16 fonts, FEAT-22 (until the reporter answers), title hoisting.

## Open questions for Christian — ANSWERED 2026-08-16 (all four: yes / decline / later / agreed)

1. Confirm the headline (BUG-58) + the three small asks (FEAT-18, UX-8, BUG-57) as the build set.
2. FEAT-17: decline-with-native-answer as recommended, or scope "start minimized"?
3. Self-hosted discovery: yes / no / later?
4. Any beta.12 retest that comes back negative jumps the queue — agreed default?

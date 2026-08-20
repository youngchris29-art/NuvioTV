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
- ✅ Device check 2026-08-16 (Christian, Debug `301792fe` on the Living Room box): "everything seems to be working" — item (1) PASS.
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

### Wave 5 — Native player swipe-down panel (Christian's ask 2026-08-16) — ✅ BUILT 2026-08-16/17
Plan + status: `docs/tvos-native-player-info-panel-plan.md`. Three commits on
`tvos-shared-extraction`: W1 `2477ba7f` (Info tab header + rows, Preferred Audio/Subtitle
Language on the native path), W2 `740845e2` (embedded text subtitles as segmented WebVTT
renditions in the system Subtitles tab; **native engine default-ON**), W3 `b08b4f62` (demuxed
alternate audio renditions — the system Audio tab lists every track, switching is AVPlayer's own;
D4 rebuild + transport-bar menu removed). Codex-gated (14 / 4 / 6 rounds). l10n: 13 new keys ×
fr/es/de/it/vi merged (catalog at parity). README Playback bullets updated.
**Sim can't verify the system tabs** (the tvOS simulator renders no Subtitles/Audio tabs — not
even for Apple's reference stream); those are device-pass items (below).

### Wave 5b — App-drawn swipe-down top panel + HIG-uniform chips (Christian's ask 2026-08-17) — ✅ BUILT 2026-08-17
Christian's device clip showed the truth about tvOS 26: **there is no system swipe-down tabbed
panel any more** — a `customInfoViewControllers` tab renders as a bottom-left "Info" pill under
the seek bar, and Subtitles/Audio are transport-bar popovers. He wants Infuse's UX: no Info under
the seek bar, a swipe-down/D-pad-down top panel with **Info · Subtitles · Audio**, Menu closes it.
Built (plan: `~/.claude/plans/…lazy-pillow.md`, results in `docs/tvos-native-player-info-panel-plan.md` §5f):
`Screens/Player/` — `PlayerPanelHost.swift` (container VC over AVPlayerViewController with
Down-press/down-swipe recognizers; presented `.overFullScreen` hosting VC that swallows Menu),
`PlayerTopPanel.swift` (+ Info/Subtitles/Audio tabs, `PlayerTopPanelModel`, `NativePlayerPanelAdapter`,
`PlayerSwipeHint`), `PlayerChipStyle.swift` (shared chip look; native = contextualActions with static
titles + a countdown caption, mpv = matching `PlayerActionChip`; `UpNextCard`/`SkipPromptPill`
deleted). Native transport-bar Subtitles/Audio popovers KEPT (Enhance Dialogue / Reduce Loud Sounds
have no public API); output routing re-added via `AVRoutePickerView`. `PlaybackContext.meta`
(year/runtime/rating/genres from Detail) + `fileSizeBytes` feed the Info chip row. l10n: 10 keys ×
fr/es/de/it/vi (parity); 5 dead keys pruned. **Sim-verified** with `NuvioTVUITests/PlayerTopPanelProbeTests`
(`TEST_RUNNER_PLAYER_PANEL_PROBE=1`, app pre-warmed on `long2a-sub.mkv`): Down opens, tabs switch,
subtitle select/Off round-trip, audio select → `audio selection → stream 2`, Menu closes without
popping the player, Down with the transport bar visible opens too. **W5c (same day): mpv adopted the
same panel** — swipe-up TrackPickerView deleted; 4th "Playback" tab (speed · delays · diagnostics ·
episodes · sources); Down / down-swipe opens; probe green on both engines (panel plan §5g).

### Waves 6–10 — the beta.12 tester verdict + upstream ports (added 2026-08-18, plan `~/.claude/plans/let-s-make-a-plan-tranquil-ember.md`)

Trigger: u/mrStevenx3's structured beta.12 review (`p4afwfo`, 2026-08-17) — BUG-63 (P1, new),
BUG-64/FEAT-24/FEAT-25 new, BUG-59 reopened, BUG-38/39/42/UX-9 re-reported on 108 — plus the
three mechanical upstream ports from `docs/upstream-port-plan-2026-08-18.md`. Christian's
standing rule ("a negative beta.12 retest jumps the queue") applied. All on `tvos-shared-extraction`,
one Codex gate per wave, sim-verified where the sim can see it.

- ✅ **Wave 6 — `d66ae6c3` (Kotlin):** **BUG-63** — `fetchTmdbVideos` sent `language=fr-FR` alone
  and TMDB `/videos` returns only that language's tagged videos, so a non-English Metadata
  Language made "no trailer" the common case (the reporter proved it by flipping the setting).
  Fix: `include_video_language=fr,fr-FR,en,null` on every `/videos` call AND, for non-English
  languages, a parallel `en-US` request merged preferred-first (correct whether or not the
  standalone endpoint honors the param); `TmdbVideoResult.iso_639_1` → `MetaTrailer.language`;
  `selectHeroTrailer(trailers, preferredLanguage)` overload (preferred > en > untagged > other,
  BELOW the official/type tiers; 1-arg selector byte-compatible + language-neutral); wired at
  MetaDetailsScreen.kt / DetailViewModel.swift / InlineTrailerCard.swift. Invalidation:
  language change (setters, `loadFromDisk`, profile switch) → `MetaDetailsRepository.clear()`,
  which now has a cache GENERATION (main-dispatcher, atomic with `clear()`) so an in-flight
  old-language load can neither repopulate the cache nor publish UI; Swift
  `TrailerResolutionCache` is language-scoped and `resolve()` drops a result whose language
  changed mid-flight. **Upstream ports:** `96618a86` Simkl anime `mediaCategory` (3 files;
  `LibraryDisplaySettings` hunk is parity-only on tvOS — no type-filter UI), `5327166f` PIN verify
  pulls profiles first (faithful port), `3c0ab547` `AppLanguage.ARABIC` as a **2-file** port
  (shared enum + composeApp `AppLanguageLabels` exhaustive `when`) plus upstream's `values-ar/
  strings.xml` trimmed to the fork's key set (129 upstream-only keys dropped, 3 fork-only keys
  translated → full parity) and `ar` in Android `locale_config`. Tests: shared/commonTest
  HeroTrailerLanguageSelectionTest (4), TmdbVideoLanguageTest (3), LibraryAnimeCategoryTest (1);
  `:shared:tvosSimulatorArm64Test` 51/51. Codex gate 6: 11 rounds → clean.
- ✅ **Wave 7 — `72064a5a` (Swift, trailer surface):** **BUG-59/UX-9** — the beta.12 probe could
  not measure before ~2–3.5 s and the memo was per playback URL + process-lifetime (loopback
  port + repack token change every process/extraction), so nearly every focus started at the
  1.08 floor. Now: eager video output, first sample 0.25 s / 0.25 s ticks, INTERIM zoom after the
  2nd usable sample (skipped while clamped at maxZoom — a fade-in signature), FINAL needs ≥3
  samples over ≥0.95 s, `TrailerZoomCache` keyed by TITLE and PERSISTED (`trailerZoom.v1`,
  `{zoom, token, at}`, cap 300, clamp [1.0, 1.45], drop >30 d, drop the blob on version mismatch;
  `token` = repack token or host/path+id+itag for direct URLs, never nil), a mismatched entry
  applies as interim and re-measures. `debug.trailerSmokeVideoId` honored ONLY with
  `debug.trailerProbe` (the one persisted knob matching "every trailer extremely zoomed until I
  reinstalled"), logged once per session. Sim (`TrailerSoakTests.testShortDwellZoomProfile`, 2
  launches): 8 final (all 1.343 for the forced 2.39:1 stream), interims ~1 s after attach, 17
  persisted-hits incl. across launches (`store loaded n=7`), 0 insufficient. Codex gate 7: 3
  rounds → clean.
- ✅ **Wave 8 — `cb580fab` (Kotlin + Swift):** **BUG-42** artwork half — four mechanisms found by
  the new release-safe probe (`debug.homeHeroProbe` → `[HomeHero] publish/paint`) and closed:
  (1) `HeroCrossfadeImage` painted the cached POSTER first and crossfaded to the backdrop —
  first paint now waits up to 600 ms for the backdrop, later swaps give a FETCHED poster a
  150 ms grace from arrival, a late primary after a committed first-paint fallback is
  suppressed; (2) hero was re-shuffled from a growing pool on every batch publish —
  `stableHeroSelection` (HeroSelection.kt) keeps a stable RANKING across request keys and forced
  refreshes (tvOS force-refreshes on every addon-manifest arrival), reserved half + newcomers +
  displaced tail, reset only by `clear()` and an ACCEPTED explicit Hero Sources change (atomic
  `resetHeroSelectionAround`); (3) the collection fallback filled the hero before the catalog
  hero existed (`rank=0` first heads) — held while a load is in flight and while no catalog-bearing
  refresh has happened (`awaitingFirstRefresh`, 5 s grace for collection-only profiles); (4)
  publishes/resets/clear serialized under one lock. `first_hero` also on Release behind the knob.
  test31HeroCommitsOnce ×6 launches on the final code: exactly one `paint first=1`, zero
  `headChanged=1`. HeroSelectionTest (9). Codex gate 8: 16 rounds → clean.
- ✅ **Wave 9 — `b22ea933` / `f67a9582` / `28285016` / `f0ff367d`:** **BUG-39** GIF frame-rate
  floor 12 → 5 cs (~20 fps): device case 391 px/53 f → 301 px/90 f (still 1.5× beta.11),
  GifDecodePlanTests re-pinned + 2 new (16/16). **BUG-64** ring mode draws the artwork inset by
  `ringWidth` inside the same card frame (static, concentric inner radius; LandscapeCard progress
  bar too; inline trailer tile unchanged) — test32AccentRingArtworkInset: outerDelta 0.497 /
  innerDelta 0.001. **BUG-38** title-logo gate keys on company/network source + tmdb.org cover
  (not "any own cover"), `[CollectionCover]` probe (`debug.collectionCoverProbe`) names the raw
  JSON keys the build doesn't read per folder (`unknownFolderKeysFromRawPayload`,
  collectionId|folderId); emoji-vs-collection-backdrop precedence left as designed. **FEAT-24**
  season posters (Fallout: Season 1 / Season 2 / Specials with real art, test33). Codex gate 9:
  3 rounds → clean.
- **Wave 10:** no new user-facing strings landed (grep-verified) → no l10n pass. Docs: this
  section, `docs/research/beta13-campaign-notes.md`, device checklist items 9–15, tracker rows.
  Full sim suite: see campaign notes.
- **Wave 11 — Self-hosted server discovery (upstream `ddc28dc8`/`cc20e716`) — ✅ BUILT 2026-08-19**
  (Christian: "implement both"). Domain ported into `shared/` (serves tvOS AND the fork's
  composeApp): `ServerConfiguration`/`ServerConfigurationRepository`/`ServerConfigurationStorage`
  (apple + android actuals, TV-lenient load guard), `ServerDiscovery` (+ `ServerAuthRequirement`
  — tvOS accepts `email_password_auth` OR `tv_login`, like NuvioMedia/NuvioTV), cached
  `SupabaseProvider.client` + `reset()`, `AuthRepository.prepareForServerSwitch()` (fork: runs
  the FULL account-data wipe — nothing from server A may sync into server B) / `reinitialize()`
  (cancels BOTH fork jobs, resets the restore watchdog), `ServerConnectionController` state
  machine in shared `features/auth` (cancels TV-login + account sync, re-arms settings push),
  `TvLoginRepository` now uses the active server's `tvLoginWebBaseUrl` (`<backend>/tv-login` for
  custom servers) and reports `unsupportedByServer`; `FeaturePolicy.customServerConnectionsEnabled`
  flipped on first thing in `installTvOsSharedProviders()`. tvOS UI: `ServerConnectionView`
  (ENTER → REVIEW with the Android-TV trust copy → `.alert` confirm), Welcome 4th button +
  email-primary layout when the server lacks `tv_login`, QR caption derived from the web URL,
  Settings › Account & Services › **Server** section (info row, connect, Use Official Server
  alert). composeApp parity: `ServerConnectionDialogs.kt` verbatim, AuthScreen hunks, 40
  `server_*` strings, `AppFeaturePolicy` flag, MainActivity storage init. Tests: 27 new shared
  tests (discovery policy, configuration), `test35ServerDiscoveryReview` (loopback stub server,
  non-destructive), `ScratchServerSwitchTests` 90a/b/c (destructive, env-gated, scratch sim).
  Pre-existing gap fixed on the way: tvOS never re-armed `ProfileSettingsSync` after a wipe.
  - ✅ Codex gate 11 clean (2026-08-19, 6 rounds → round 6 "SHIP: no remaining correctness
    defect"). Seeded by 3 untriaged P2s from the review run during the BUG-59 trailer wave, all
    real and fixed: WelcomeView email actions gated on `supportsEmailPassword` (QR-only servers
    offered email routes), AuthScreen entry sheet re-presented after a successful switch (now
    dismissed on a durable `ServerConnectionUiState.switchGeneration` counter — conflated
    collectors can miss the `isSwitching` edge), `SupabaseProvider.client` check-then-set race
    (now a `SynchronizedObject` around getter + `reset()`). Rounds 2–5 surfaced and fixed 8 more:
    Apple `httpRequestRaw` now streams ≤ `maxResponseBodyBytes` (pre-trust discovery endpoint
    could force an unbounded buffer; Android truncation-marker semantics mirrored),
    `connectDiscovered` pre-flights the feature-policy save precondition before the destructive
    wipe, `switchServer` admission made atomic (flag before launch, released in `finally` — two
    rapid confirms could race two wipes), TMDB filter validation tightened (votes 0–10, counts
    ≥0, year 1874–2100, real calendar dates, positive-int id lists, two-letter codes),
    persistence failures propagate (`PayloadFileStore`/`CollectionStorage` — Android `commit()`
    not `apply()` — `persist()`/`updateCollection` return Boolean; editor raises `saveFailed`
    instead of dismissing with the edit only in memory, and advances `editedSource` so a retry
    after a failed write still relocates), `updateCollection` returns false when a concurrent
    pull removed the target (silent no-op reported success), ALL `CollectionRepository` mutators
    + `persist()` serialized under one reentrant `mutationLock` (stale-snapshot re-assign could
    resurrect a just-removed collection), Apple server config re-shaped to ONE versioned JSON
    blob `server_custom_config` (split defaults keys could tear mid-replace; version required +
    validated; no migration — never shipped). Accepted trade-offs documented in-code:
    wipe-before-save ordering (cross-server contamination beats rollback), Android `commit()`
    sync I/O. New tests: `ServerConfigurationStorageTest` (6, appleTest),
    `saveRejectsOutOfRangeAndMalformedValues`, `saveReportsFailureWhenPersistenceDoesNotLand`
    (caught a real retry-forever bug pre-fix), `updateCollectionRejectsAMissingTarget`. Bonus fix
    from the FA87 fixture triage: a RESTORED anonymous QR-scaffolding session now flips
    Loading→Unauthenticated immediately (CAS + log) instead of burning the 10s watchdog.
    Verified: `:shared:iosSimulatorArm64Test` full battery green ×3, composeApp iOS compile,
    NuvioTV sim Xcode build ×3; consolidated post-gate battery (run by the Wave 11/12 session on
    the final state): shared tvOS 431/431 + iOS 431/431, composeApp iOS test 412/412, both iOS
    flavor compiles, tvOS framework link, NuvioTV build-for-testing — ALL GREEN. NOTE: the FA87 signed-in fixture itself is damaged (its real
    session was overwritten by anonymous QR scaffolding at 21:24Z on 08-19) — needs a manual QR
    re-sign-in from Christian's phone; not a code bug.
- **Wave 12 — TMDB Discover exclusion-filter UI (upstream `0fc4616b`, UI half) — ✅ BUILT
  2026-08-19.** Mobile hunks applied verbatim (+ the 12 strings, ar/hu translations). tvOS: new
  shared `TmdbSourceFilterEditor` (string-field draft of an existing TMDB source's filters,
  validation, save → `CollectionRepository.updateCollection` + push) + `TmdbFilterPresets`;
  `FolderDetailView` gains **Edit Filters** for DISCOVER/COMPANY/NETWORK sources (and a focusable
  Go Back in the empty state); `TmdbFilterEditorView` (sort, genres incl./excl. with live TMDB
  genres, keywords, studios, networks, watch providers + region, dates/ratings, language/country,
  quick chips, validation); `CollectionSyncService.startObserving()` now runs on tvOS so local
  edits push; DEBUG `-debug.collectionsSeedJsonB64` seed knob. 18 new shared tests; scratch test
  90b drives exclude-a-genre → save → reopen.
  - ✅ Codex gate 12 clean (2026-08-19, shared with gate 11 — one 6-round campaign covered both
    waves; round 6 verdict "SHIP"). Wave-12-specific findings fixed: filter validation tightened
    (ranges/dates/id-lists/codes — malformed values used to persist and make the source
    unloadable at TMDB), editor no longer reports `saved` when the collections payload write
    fails or the collection was removed by a concurrent pull, retry-after-failed-persist
    relocation fixed, `CollectionRepository` mutation lock. Full detail + test list under the
    gate 11 entry above.
- **Wave 13 — BUG-59/UX-9 reveal gate ("no barred frame ever") — BUILT 2026-08-19.** Wave 7
  closed the measurement (early interim, per-title persisted zoom) but left a structural window:
  the FIRST-ever play of a title revealed the video at the 1.08 floor and only zoomed ~0.5–1.5 s
  later, so a letterboxed source *showed its bars, then cropped them* — once per title, i.e. on
  nearly every fresh dwell of a browsing session, which is exactly what the reporter keeps
  filming (the p4afwfo frame-by-frame read: "the first second of a dwell"). Three parts, all
  Swift: **(a) reveal gate** (`TrailerLetterboxProbe`): a surface with no persisted entry for its
  title starts at `alpha = 0` (static art / backdrop stays up) and is revealed only when its crop
  is decided — persisted hit (immediate, match or mismatch), interim/final measurement, or a cap
  of ~3 s of DELIVERED frames with no usable sample (dark opening/fade — dark frames have no
  bars). The cap counts frame-bearing ticks, never wall clock (Codex round 2 P1: startup
  routinely exceeds 3 s, and a wall-clock cap revealed before the first frame — bars until the
  interim, the exact defect again); a frameless stream stays concealed until the 6 s startup
  watchdog removes the surface. Render-only (`view.alpha`), so UX-4a morph + BUG-29 scroll
  geometry untouched; every reveal logs `[TrailerZoom] reveal reason=… frameTicks=…`. The invariant is now structural: an unzoomed letterboxed
  frame can never reach the screen. **(b) static-art scan** (`ArtworkLetterbox`, new;
  `CachedAsyncImage(cropsBakedLetterboxBars:)`, inline tile only): TMDB backdrops are sometimes
  trailer stills with bars baked in, and the art is on screen from morph to reveal — scanned once
  per URL with the probe's exact thresholds plus a SYMMETRY guard (dark-content art like the
  reporter's *Idaho Murders* night-sky frame is never cropped), memoized, off-main. **(c)**
  `-debug.resetTrailerZoomStore` launch knob (probe-gated, same discipline as the smoke id) wipes
  `trailerZoom.v1` for cold-store repros. Tests: `ArtworkLetterboxTests` (10, mirror-style per
  `StreamBadgeColorTests` precedent) + `TrailerSoakTests.testColdStoreFirstDwellRevealProfile`
  (2 launches: cold-store dwell bursts with a 12-shot screenshot oracle per card, then
  persisted-hit revisits; log oracle in the test doc).
  - **🔴→🔧 THE ACTUAL ROOT CAUSE, found by this wave's pixel oracle (2026-08-19, evening):**
    the measured zoom **never rendered at all** — on beta.12 and on every beta.13 build before
    this. UX-9 applied the zoom to the hosted view's BACKING-layer transform
    (`layerClass = AVPlayerLayer`), and SwiftUI owns a hosted view's transform/frame and
    re-asserts them on layout, so the crop was silently neutralized: `[TrailerZoom]` logged
    `applied=1.343` while the playing tile kept its 12.8 % bars (first cold-dwell screenshot
    scan caught it — every prior gate, including Wave 7's sim soak and the 08-18 device-pass
    item 10, read the LOG stream, not pixels; the measurement was fixed, the rendering never
    was). This single mechanism explains the reporter's whole beta.12 "~90 % of titles still
    letterbox" verdict — and why "GIGN OK, others not": natively-scope-coded encodes fill under
    plain aspect-fill with no zoom needed, bars-baked-into-16:9 encodes need the zoom that
    wasn't rendering. **Fix:** `AVPlayerLayer` is a managed SUBLAYER of `TrailerPlayerUIView`
    now; `layoutSubviews` re-asserts bounds + position + crop zoom together (SwiftUI can't touch
    a sublayer's transform), and `clipsToBounds` genuinely crops the overscale. Verified by
    re-running the cold-dwell soak and re-scanning the tile rect per frame (scanner tool +
    `cardFrame=` log rect).
  - **Gate status (2026-08-19):** build-for-testing green (app + UITests);
    `ArtworkLetterboxTests` 10/10 on sim; Codex round 1 clean on Wave 13 files; round 2 (via the
    Wave 11/12 whole-tree gate) found 2 real ones, both fixed: [P1] wall-clock reveal cap →
    frame-bearing-tick cap, [P2] the guest scratch harness is now `XCTSkip`-gated on
    `TEST_RUNNER_NUVIO_GUEST_REVEAL_SCRATCH=1` (unguarded it would have created a profile on a
    signed-in account in ordinary suite runs). Knob wiring device-proven (`[TrailerZoom] store
    reset` observed on sim). **Still owed: the end-to-end cold-dwell screenshot run** — blocked
    2026-08-19 because the signed-in sim fixture FA87E9B6 lost its session to the Wave 11
    scratch-clone Sign Out (Christian must re-sign-in via QR; the physical Apple TV is
    unaffected), and the guest fallback path dead-ends at the Add Profile cover, which ignores
    ALL synthetic input incl. XCUIRemote (known gotcha, now re-confirmed). Run
    `testColdStoreFirstDwellRevealProfile` on FA87E9B6 right after the QR re-sign-in, before the
    device pass; item 10b covers the same invariant on hardware.
- **Decisions applied (defaults from the plan):** FEAT-17 stays declined-with-native-answer
  (now a fifth ask — weigh before the reply is written); FEAT-25 not built (answer with
  FEAT-15/17/18 as one design decision); `values-ar` WAS ported after all (Codex gate 6 argued,
  correctly, that exposing "Arabic" without strings is a half-feature; trimmed to fork keys);
  BUG-39 at fps floor 20 / budget unchanged; BUG-59 zoom persisted with clamp+version.

## Verification

- **Automated:** full suite (57 UITests + `GifDecodePlanTests` 14 + `StreamBadgeColorTests`
  + `AccentFocusRingTests` + `ArtworkLetterboxTests` 10 — Wave 13) on tvOS 26.5, structural
  guard, `TrailerSoakTests` (incl. Wave 13's `testColdStoreFirstDwellRevealProfile`); new tests
  for Waves 1–2. Check for concurrent sim sessions before runs (osascript sim input is dead while
  the Claude app is frontmost — drive via the XCUIRemote harness).
- **Manual device pass** (one consolidated checklist, `docs/research/beta13-device-pass-checklist.md`):
  **new for Waves 6–9 — (9) BUG-63:** Metadata Language = Français, focus 10 titles that failed on
  108 → trailers play; `[TrailerPipeline] noTrailerListed` ≈0; flip language → no 20-min stale
  window (`[TrailerPipeline] cache purge reason=language`); **(10) BUG-59:** `debug.trailerProbe`
  → `[TrailerZoom] interim` within ~1 s of play, `final … persisted=1`, relaunch → `persisted-hit`;
  the reporter's GIGN-vs-neighbours pair if identifiable; **(10b) Wave 13 reveal gate:** add
  `debug.resetTrailerZoomStore` for ONE launch, dwell 3 fresh letterboxed titles and watch the
  tile the whole time — the video must appear already-cropped (art → cropped video, never
  art → barred video → zoom); logs show `reveal reason=interim|cap` per cold play and NO `reveal`
  lines on the re-dwell after relaunch (persisted-hit surfaces are never concealed); **(11) BUG-42:** `debug.homeHeroProbe`,
  reboot-cold launch ×5 → one `paint first=1`, zero `headChanged=1`; **(12) BUG-39:**
  `debug.gifDecodeProbe` on the collections row → `keptFrames=sourceFrames`, phone 60 fps clip for
  cadence; **(13) BUG-64:** ring ON + No Zoom ON, poster edge visible inside the ring; **(14)
  BUG-38:** `debug.collectionCoverProbe` on Christian's account (unknownKeys=[] expected), the
  reporter's JSON when it arrives; **(15) FEAT-24** on a multi-season series (Fallout). Then the
  original items: (1) BUG-58 on the White theme by the reporter's route; (2) FEAT-18 with
  Trailers on Focus in both hero modes; (3) UX-8 toggle round-trip incl. sync; (4) BUG-57 both
  depth modes; (5) BUG-30/62 residual read; (6) VidHub retest with the `debug.vidhubMethod` knob
  IF VidHub has shipped an update; (7) regression sweep of beta.12's device-verified items;
  **(8) native player panel (Wave 5/5b — app-drawn)**: swipe down AND D-pad down on a
  native-routed title (controls hidden and visible) → our top panel with Info · Subtitles · Audio;
  **no "Info" pill under the seek bar**; Menu closes the panel without exiting; swipe up closes;
  playback never pauses; the transport bar doesn't react to panel presses; Up from a list lands
  on the CURRENT tab; Info shows poster/title/S·E·episode name/synopsis + the chip strip + the
  live rows; the "Swipe down for info" hint shows after start and after a pause; the Speakers &
  Headphones column names the route and the picker opens the AirPods/HomePod sheet; the native
  Audio popover still offers Enhance Dialogue / Reduce Loud Sounds; the up-next countdown caption
  sits above (not on) the contextual pill — tune `contextualActionClearance` if it overlaps; Subtitles lists the MKV's embedded text tracks (named by language, SDH/Forced
  flagged) alongside addon subs and cues render; Audio lists every track (language · codec ·
  layout) and switching plays on within a few seconds with the video continuing (no black/reload)
  — Info "Audio" row follows; Preferred Audio Language picks the start track; a DV title still
  lights the DOLBY VISION badge on the demuxed master; seek after an audio switch; an audio
  switch during a seek. Native engine is now default-ON: retest one plain H.264/HEVC MKV end to
  end. Grab a real-title panel screenshot for the README (design/screenshots/player-panel.png).
  Launch-arg knob route + live `devicectl … --console` capture (no USB on the Living Room box).

## Release + comms

- `release-beta.sh` discipline unchanged: README features (+ screenshots for anything visible:
  FEAT-18/UX-8) FIRST, `bump version` (109) + `scripts/release-notes/tvos-beta13-highlights.md`,
  cut `tvos-v0.3.0-beta.13` to both repos, then the Reddit block via old.reddit
  `/api/editusertext` + modhash (works on the gallery post — beta.12 lesson, no UI needed).
- Announcement must: close BUG-58 by name (promised); name FEAT-18/UX-8 to their askers
  (u/mrStevenx3); state BUG-30/62 honestly; carry the retest asks; keep the native-feel line on
  focus motion (`p41ijt8`) — do not re-open "still cards". **Waves 6–9 additions:** name BUG-63
  as the trailer fix and credit u/mrStevenx3's repro; acknowledge BUG-31 closed on his word; state
  BUG-38 honestly (needs his exported Collections JSON — ask for it); carry BUG-59 as "trailers
  now never show letterbox bars — the video is only revealed once its crop is decided, including
  the very first focus of a title" — and still ask him to name a title + a 3-second dwell if he
  ever counts bars again on 109; FEAT-24
  shipped for him; FEAT-25/FEAT-17 answered as one design note (not toggles). Consider a short
  interim reply on `p4afwfo` before the cut ("found the trailer cause — Metadata Language gate").
- Tracker: release entry, rows flipped, Now cell rolled; the beta.12 rows move to Resolved only
  on wild confirmation.

## Out of scope (explicit)

- Removing/hiding the system tab bar (FEAT-17 as asked) and any "no focus motion at all" —
  design principle, see Scope decision 3.
- Subtitle-size range — decision recorded, no build unless Christian says so. (TMDB exclusion-filter
  UI and the self-hosted discovery build were pulled IN on 2026-08-19 — Waves 11/12.)
- FEAT-3 TestFlight, FEAT-16 fonts, FEAT-22 (until the reporter answers), title hoisting.

## Open questions for Christian — ANSWERED 2026-08-16 (all four: yes / decline / later / agreed)

1. Confirm the headline (BUG-58) + the three small asks (FEAT-18, UX-8, BUG-57) as the build set.
2. FEAT-17: decline-with-native-answer as recommended, or scope "start minimized"?
3. Self-hosted discovery: yes / no / later?
4. Any beta.12 retest that comes back negative jumps the queue — agreed default?

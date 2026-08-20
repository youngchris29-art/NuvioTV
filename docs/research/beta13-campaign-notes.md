# beta.13 campaign — working notes (Waves 6–10, 2026-08-18)

Running log of diagnoses and decisions for the second half of beta.13 (the beta.12 tester
verdict + upstream ports). Plan: `~/.claude/plans/let-s-make-a-plan-tranquil-ember.md`; the
first half (Waves 0–2, 5/5b/5c) is in `docs/beta13-release-plan.md`. All commits on
`tvos-shared-extraction`, unpushed until the release step.

## Commit ledger
- Wave 6: `d66ae6c3` — BUG-63 trailer language fallback (include_video_language + parallel en-US
  merge, `MetaTrailer.language`, `selectHeroTrailer(_, preferredLanguage)` overload, cache
  generation in `MetaDetailsRepository`, language-scoped Swift `TrailerResolutionCache`) +
  upstream ports 96618a86 / 5327166f / 3c0ab547 (+ trimmed `values-ar`, Android locale_config).
  Codex gate 6: **11 rounds** — wire the language into the callers (P1); Arabic without strings
  is a half-feature (ported the file, trimmed to fork keys, 3 fork-only keys translated); keep the
  1-arg selector language-neutral; profile-driven language change also invalidates; the Swift
  cache repopulating under the new scope from an old-language resolve; `publishLoadedMeta`
  repopulating after `clear()` → cache generation; enrichment reading the post-clear generation →
  thread it; stale request publishing UI → `isLiveRequest`; check-and-write not atomic across
  dispatchers → `putCache` on `Main.immediate`, `clear()` hops to main; standalone `/videos` may
  ignore `include_video_language` → parallel `en-US` request merged; clean.
- Wave 7: `72064a5a` — BUG-59/UX-9 measured zoom: earlier (0.25 s), interim after 2 samples
  (skipped while clamped — the 1.450→1.343 bounce seen in the sim), final ≥3 samples over ≥0.95 s
  (float-equality miss on 1.00 s in the sim), per-TITLE persisted `TrailerZoomCache`
  (`trailerZoom.v1`, clamp/version/age), stream identity token (repack token or host/path+id+itag,
  never nil — Codex: nil==nil matched unrelated direct streams), interim from fresh samples may
  correct a persisted-mismatch value; `debug.trailerSmokeVideoId` gated on `debug.trailerProbe`.
  Sim: `testShortDwellZoomProfile` ×4 iterations → final run 8 final / 8 interim / 17
  persisted-hit / 0 insufficient. Codex gate 7: 3 rounds, clean.
- Wave 8: `cb580fab` — BUG-42 artwork half. **The probe found four mechanisms, not the two the
  plan expected:** (1) poster-first crossfade (fixed: first-paint deadline 600 ms, later-swap
  fetched-fallback grace 150 ms from ARRIVAL, late primary after a committed first-paint fallback
  suppressed); (2) reshuffle on every batch publish (fixed: `stableHeroSelection` full RANKING,
  reserved half + newcomers + displaced tail — the truncated first version churned its own
  displaced tail as "newcomers", caught by my own test + Codex); (3) **the collection fallback
  filled the hero BEFORE any catalog load existed** (`rank=0` first heads, `inRows=0`) — hold
  while loading AND while `awaitingFirstRefresh` (lifted by the first catalog-BEARING refresh —
  a catalog-less add-on becoming ready first must not lift it — or a 5 s grace for
  collection-only profiles, generation-guarded against `clear()`); (4) `refresh(force=true)` on
  every addon-manifest arrival + settings sync re-normalizing hero-source slots — the ranking is
  kept across keys and forced refreshes, reset only by `clear()` and an ACCEPTED explicit Hero
  Sources change (`resetHeroSelectionAround`, atomic with the mutation + republish; a rejected
  third source at the 2-limit must not reshuffle). Publishes/resets/clear all under one lock.
  test31 ×6 launches: one `paint first=1`, zero `headChanged=1`. Codex gate 8: **16 rounds**
  (the `didTraceFirstHero` `#if DEBUG` Release compile break was a real catch — Release build
  verified after). Sim regression mid-wave: my "collection key changed" invalidation fired on the
  FIRST resolve (previous key null) and again after `clear()` (cache empty) → both guarded.
- Wave 9: `b22ea933` BUG-39 (floor 12→5 cs; device case 301 px/90 f; GifDecodePlanTests re-pinned
  from the run + 2 new); `f67a9582` BUG-64 (static ring-band inset in ring mode; test32
  outerDelta 0.497 / innerDelta 0.001 — first version skipped itself twice: two launches focused
  different cards, then the same-card guard was tighter than the ~5 pt frame drift between focus
  treatments); `28285016` BUG-38 (company/network + tmdb.org gate; `[CollectionCover]` probe with
  per-folder unknown raw keys keyed collectionId|folderId, de-duplicated on the whole line;
  known limitation documented — no provenance field); `f0ff367d` FEAT-24 (season posters;
  Fallout on the sim). Codex gate 9: 3 rounds, clean.
- Wave 10: no new user-facing strings (grep-verified) → no l10n pass. Docs updated: plan
  (`docs/beta13-release-plan.md` Waves 6–10), device checklist items 9–15, this file, tracker rows.

## Things worth remembering
- **`upstream/cmp-rewrite` has the same BUG-63 defect** — nothing to port; the fix is ours.
- **The tvOS sim can prove "commit once" for the hero** with `debug.homeHeroProbe`; it could NOT
  before because the launch race (addons ready progressively, profile sync ~1 s in, collection
  fallback resolving first) is exactly what makes the sim non-deterministic — hence 6 launches.
- **Long UITests hit the tool's 10-minute cap** (test32 with three Settings walks ~9 min): run
  them in the background and poll the log; never build while one is executing.
- **The stale `.git/index.lock` from 07:13** blocked both the outer repo (sweep) and the submodule
  (Wave 6 commit) — 0-byte, no git process; removed both times.

## Sim suite (Wave 10)
- 2026-08-18, tvOS 26.5 sim (Apple TV 4K 3rd gen), scheme `NuvioTVUITests`, everything except the
  three opt-in soak/probe classes: **86 tests, 0 failures, 3353 s** (NuvioTVUITests 34 incl. new
  31–33, GifDecodePlanTests 16, CardDepthRailTests 6, AccentFocusRingTests 11,
  StreamBadgeColorTests 16 + TabChipContrastTests 4 — the earlier "57" count in the plan was the
  UI class + a subset). Soak zoom profile and test31 were run separately during their waves.
- Kotlin: `:shared:tvosSimulatorArm64Test` 51/51 after Wave 6, home tests 9/9 after Wave 8.

## Waves 11/12 additions (2026-08-19, self-hosted discovery + TMDB filter editor)
- Kotlin: `:shared:tvosSimulatorArm64Test` now **423 tests, 0 failures** (+45: ServerDiscoveryPolicyTest 18,
  ServerConfigurationTest 9, TmdbSourceFilterEditorTest 18); `:composeApp:iosSimulatorArm64Test` 412/412.
- UI class gains **test35ServerDiscoveryReview** (non-destructive: loopback `DiscoveryStubServer` on
  127.0.0.1, official-host refusal + review step; never presses Connect) → UI class = 36 tests. New
  **ScratchServerSwitchTests** (3 tests, env-gated `TEST_RUNNER_NUVIO_SCRATCH_DEVICE=1`, XCTSkip
  otherwise): 90a full switch (destructive), 90b guest TMDB-filter editor round-trip via
  `-debug.collectionsSeedJsonB64`, 90c Use Official Server — each self-establishing; all three
  verified solo-green on fresh scratch clones 2026-08-19.
- ⚠️ Scratch-clone lesson (cost the shared sim session): a real **Sign Out on a clone revokes the
  server-side session shared with the source sim** — the signed-in 26.5 sim (FA87E9B6) was signed
  out + locally wiped on 2026-08-19 and needs a one-time QR re-sign-in before the signed-in suite
  (tests needing the "Chris" profile) can run again. Scratch recipe + sim-wide-prefs gotcha in the
  `selfhost-server-discovery` memory.

## Device pass (2026-08-18 evening, Living Room Apple TV, build 109)
- Items 9–15 all PASS on Christian's read + the console stream (details in the checklist Notes).
- **One reversal:** BUG-38's refined logo gate (`28285016`) doubled the curated Services
  wordmarks — those folders are addon-sourced with a wordmark cover + titleLogoUrl, exactly the
  case the TMDB company/network discriminator can't see. Reverted in `5cb2f8b9`; the probe stays.
- **Probe finding for a future row:** the synced Services folders carry `focusVideoUrl` /
  `focusVideoWebmUrl` — focus VIDEO fields this build ignores. Not the reporter's cover issue,
  but a real capability another client has.
- Ledger: `5cb2f8b9` (revert) — pointer `a5a5eee`, both repos pushed.
- Gotchas: devicectl `--console` streams from two launches into one file collide (relaunch 2's
  output vanished — start each launch's capture in its own file next time); free-team profiles
  expire on a 7-day clock and Xcode needs the Apple ID signed in to renew — check
  `embedded.mobileprovision` ExpirationDate before a pass, not just the profile store.

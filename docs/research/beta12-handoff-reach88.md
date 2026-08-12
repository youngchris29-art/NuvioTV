# beta.12 session handoff — continue with the reach-88 experiment (BUG-53)

> **OUTCOME (2026-08-11, follow-up session): reach-88 SHIPPED.** Full sequence ran clean:
> sim UITests test00z/06/20/22 all green; device walk (Christian) — focus crisp under D-pad +
> swipes, no title clip on leftmost cards, spacing approved ("this looks good now"); probe
> re-check — every settled rest parks at margin 0 / slide 0 / net 0 (no slide needed at rest
> under the new geometry; the only negative-net lines were scrolled-away rows at the 72 clamp
> mid-flight, which is expected). Committed as NuvioMobile `5f6f2900`, Codex-gated clean
> (scoped `--base HEAD~1`; the unscoped default reviewed the whole branch vs cmp-rewrite and
> surfaced 3 pre-existing branch-level findings — Android Sentry URL-path scrubbing, quickjs
> mavenLocal reproducibility, Hebrew missing from locale_config — none from this change, left
> for triage). Pushed. BUG-53 is fixed for beta.12; continue with checklist sections 2–10.

Written 2026-08-11 at the end of the campaign session. A new session should read this and
continue at "NEXT STEP" below. Full campaign record: `beta12-campaign-notes.md`; device pass:
`beta12-device-pass-checklist.md`.

## Where things stand

**beta.12 is code-complete, pushed, and mid-device-pass.**
- NuvioMobile `tvos-shared-extraction` @ `99faf002` (pushed), outer repo @ `dd5102a` (pushed).
  All 8 campaign waves landed, every wave Codex-gated clean (`node ~/.claude/plugins/cache/
  openai-codex/codex/1.0.6/scripts/codex-companion.mjs review --wait [--base X]` from
  NuvioMobile, direct + unsandboxed, review→fix→re-review). Suite 57/57 on tvOS 26.5.
- Release build (stamp `NuvioCommitSHA: 99faf002`, UUID 9C51AC69-B614-3BB2-B4BB-461A63E36F32)
  is installed on the Living Room Apple TV — device id `C11A7D65-498A-576D-B2AA-9F91D69BCBF7`,
  paired over network (NO USB: `log collect` can never work; the ONLY log channel is a live
  console bridge).
- Live console capture may still be running as a background task of the OLD session writing to
  its scratchpad. A new session should START ITS OWN capture (command below) — don't rely on
  the old one.

## Device-pass results so far (section 1 DONE, sections 2–10 remain)

- **Rest-error discovery (big):** the 2026-08-02 measurement (reveal rests 40–67pt short under
  Siri-remote SWIPES, 1,603 samples) **no longer reproduces**. Christian walked with clicks AND
  swipes on the beta.12 build: every settled rest parks identically — top row margin −8 /
  slide 8 / net 0, rows below slide 0, scrolled-away rows released at the 72 clamp. Zero rests
  between 8 and 72. Consequences: no `debug.pinnedTitleMaxSlide` calibration needed (shipped 72
  never binds at rest); BUG-60's permanent-overlap form cannot occur; BUG-37's vanish
  condition cannot arise.
- **BUG-61 eased slide: CONFIRMED on device** — "the title glides."
- **BUG-53: CONFIRMED SURVIVING** — focusing the two leftmost cards of a row clips/overlaps the
  row title (the system `hoverEffect(.highlight)` lift, ~10–16pt rise). Geometry: at every
  parked rest the title bottom lands EXACTLY at the artwork top (clip-edge→art band = 40pt,
  title ≈ 40pt) — zero slack in ANY title placement; the band itself must grow.

## NEXT STEP — the reach-88 experiment (Christian approved building it)

**Change:** `Theme.Size.heroPinnedRowTopPad` 72 → 88 in
`NuvioMobile/iosApp/NuvioTV/DesignSystem/Theme.swift` (~line 301). This constant is BOTH the
per-row top band and the `rowCardTopReach` in pinned mode (deliberately coupled — do NOT
decouple; a reach larger than the band would overlap the previous row's focus frames). Growing
it to 88 gives the parked title a 16pt cushion above the art, clearing the lift.

Check the doc comments around `heroPinnedRowTitleInset`/`heroPinnedRowTitleMaxSlide` in the
same file — they state band arithmetic ("shelf padding 24 + reach 72 = 96", "margin+clearance
= 32") that must be updated to the new numbers (24+88=112; margin+clearance = 88−40 = 48).
`heroPinnedRowTitleInset` (48) and `heroPinnedRowTitleMaxSlide` (72) stay as they are — the
slide parks the title at the clip edge regardless, and rests are deterministic.

**Risks to respect:** reach is the most regression-prone dial (BUG-30's six banned rounds; the
sim bisected reach 100 = focus resolution dies outright; 72 was the proven value; 88 is
untested). Also a visible design change: pinned rows sit 16pt airier.

**Verification sequence:**
1. Sim: build Debug for sim `FA87E9B6-F28D-4DF9-84E4-A5A4C5DBFC4E`
   (`xcodebuild -project iosApp/iosApp.xcodeproj -scheme NuvioTV -destination
   'id=FA87E9B6-...' -configuration Debug build`), then run the focus-sensitive UITests:
   `xcodebuild test -scheme NuvioTVUITests -destination id=... -only-testing:
   NuvioTVUITests/NuvioTVUITests/test22PinnedHeroDeepScroll` (+ test20, test06 if quick).
   NOTE: suite scheme is `NuvioTVUITests` (the NuvioTV scheme has no test action). The suite
   normalizer test00zRestoreShowHeroOn keeps profile hero state sane.
2. Device: Release build with `-destination 'generic/platform=tvOS' -configuration Release
   -allowProvisioningUpdates` (profiles lapse without the flag), install via
   `xcrun devicectl device install app --device C11A7D65-... <path>/Release-appletvos/NuvioTV.app`,
   then launch WITH CONSOLE CAPTURE + knobs:
   `xcrun devicectl device process launch --terminate-existing --console --device C11A7D65-...
   com.nuvio.media.NuvioTV -- -debug.homeScrollProbe YES -debug.trailerProbe YES
   -debug.gifDecodeProbe YES > <logfile> 2>&1 &`  (the `--` is REQUIRED or devicectl eats the
   app args; knob-gated lines appearing = args landed).
3. Christian walks pinned Home ~2 min: (a) D-pad + swipe navigation must stay crisp — ANY
   focus hesitation/miss = revert the constant immediately; (b) leftmost-card focus must no
   longer clip the title; (c) row spacing visual verdict (16pt airier — his design call).
4. Probe re-check from the capture: settled `[HomeScrollProbe] title` lines should still park
   clean (slide ~8 or wherever the new geometry rests — verify net ≥ 0 and art-overlap 0).
5. If good: commit (BUG-53 fix, reach 72→88, updated doc comments), Codex-gate it, push, and
   fold into the release. If navigation degrades: revert, ship beta.12 with BUG-53 honestly
   deferred to the beta.13 structural fix (title hoisting out of the scroll clip — see
   campaign notes Wave 1 findings), and say so in the reporter reply.

## Remaining after reach-88: checklist sections 2–10, then release

Sections 2–10 of `beta12-device-pass-checklist.md` (BUG-31 toggle-ON check, trailer soak,
GIF decode numbers, French hero/rows, badge vs mobile, VidHub handoff — needs VidHub from the
App Store, Vietnamese spot-check, White-theme sidebar, regression sweep). Then: tracker row
updates + release entry, README features/screenshots FIRST, `scripts/release-beta.sh` (bumps
build number; current build still says 107), announcement + replies (BUG-53 and UX-9 were
publicly promised; BUG-58 needs reporter clarification — no matching surface exists; BUG-59
ask which title showed it).

## Session gotchas worth carrying
- Profile-synced payload keys can NOT be A/B'd by prefs injection — sync pulls the account
  value back on every launch. Change state through the real UI (see test00zRestoreShowHeroOn).
- zsh shadows `/usr/bin/log`; osascript sim input dies when the Claude desktop app holds
  frontmost — use the XCUIRemote/UITest harness for sim walks.
- Console showed a pre-existing non-fatal `PostgrestRestException: "Unsupported Nuvio client"
  (22023)` from the `register_current_device` RPC (caught, retried 15-min) — tracker
  watch-list item, not a beta.12 blocker.

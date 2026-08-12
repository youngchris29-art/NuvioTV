# beta.12 manual device pass — checklist (prepared 2026-08-10)

One consolidated pass on the Living Room Apple TV (AppleTV11,1, tvOS 26.6). Every item below is
device-only by nature — the sim cannot produce the rest error, the 4K backing store, the flagged
cookie identity, or App Store installs. Sideload the beta.12 candidate build first.

Probe knobs (launch-argument route works on device; Mac-side `defaults write` does NOT reach the
sandbox):

```bash
xcrun devicectl device process launch --terminate-existing --device <udid> com.nuvio.media.NuvioTV \
  -debug.homeScrollProbe YES -debug.trailerProbe YES -debug.gifDecodeProbe YES
```

## 1. BUG-53 / BUG-60 / BUG-61 — pinned-title geometry calibration (P1, promised)
- Pinned mode (Afficher le Hero = Off), walk rows up/down. The BUG-61 jump should now EASE
  (0.22s glide, sim-verified zero snap oscillations).
- Read `[HomeScrollProbe] title … slide=` at rests. Sim rests slide ≤8; the device's 40–67pt rest
  error is what parks titles onto art and under the focused card's lift.
- Live-bisect the clamp without rebuilds: relaunch with `-debug.pinnedTitleMaxSlide 40` (then 24,
  56…) and judge the trade: smaller clamp = titles clip at the top on deep rests; larger = titles
  ride over art and under the lift. Pick the value that looks right on hardware; ship it as the
  new `heroPinnedRowTitleMaxSlide` (or keep 72 if the eased motion alone reads fine).
- BUG-53 verdict: with the chosen clamp, focus the LEFTMOST card of a row and check the title.
  If the lift still occludes it, the beta.13 candidate is the title-hoisting rework (notes,
  Wave 1 findings).

## 2. BUG-31 — zoom-on-focus with the toggle ON (P2)
- Settings → Apparence → No Zoom on Focus → ON. Verify on Home rows whether ANY motion remains
  on focus (the reporter says zoom persists with the toggle on). Film/screenshot if it does.

## 3. BUG-46 / BUG-55 — trailer death (P1, hardened this release)
- beta.12 makes extraction traffic stateless (no persisted cookies/cache) — the theory is the
  dead state can no longer arise. Soak: browse with trailers ~15 min.
- If trailers DIE anyway: take the LIVE container dump immediately
  (`xcrun devicectl device copy appDataContainer …`), then check `Library/Cookies` and
  `Library/Caches` for youtube/googlevideo entries — their presence would falsify the ephemeral
  fix; their absence + death points back at an in-memory mechanism the new
  `[TrailerPipeline] focus/dwell/expand` probes will now name exactly.
- Also read the unconditional `[TrailerPipeline] gates …` line — it says outright if the
  toggle/system-autoplay gates are the reason nothing plays.

## 4. BUG-39 — GIF sharpness on the 4K panel (P2)
- With `-debug.gifDecodeProbe YES`, focus a few collection tiles; read `[GifDecode] side= ceiling=
  sourceFrames= keptFrames=`.
- beta.12 doubled the decode ceiling on 4K (400→800px). If `side` now reads ~2× and tiles look
  sharper: done. If `side` is budget-clamped well below `ceiling` for typical GIFs, note the
  sourceFrames counts — that's the input for the frame-vs-resolution trade (notes, Wave 0).

## 5. BUG-42 / BUG-35 — hero + row localization in Français (P2)
- Langue des métadonnées = Français. Cold-launch: hero must commit ONCE (no EN→FR swap).
  `[LaunchTrace] first_hero` vs `first_rows` if in doubt.
- NEW in beta.12: scrolled-into-view rows localize their first 12 items (BUG-35 fix). Verify row
  captions turn French as rows appear.

## 6. BUG-43 — stream-list language badge (P2)
- Open a stream list with the badge pack installed. The ARGB parsing fix should make 8-digit
  pack colors render as mobile does. Compare the badge against the phone side-by-side.

## 7. FEAT-21 — VidHub handoff
- Install VidHub from the App Store. It should appear in Settings → Playback → Default Player
  AND the stream long-press menu automatically ([ExtPlayerProbe] logs canOpenURL on launch in
  debug builds).
- Play a stream via VidHub: verify playback starts, the title shows (filename param), a partially
  watched title resumes (position param), and backing out returns to Nuvio.

## 8. FEAT-19 — Vietnamese spot-check
- Apple TV language → Tiếng Việt. Walk Home / Cài đặt / a detail page / stream picker / player
  OSD. Look for truncation/overflow at 10 feet and any stray English.
- Also confirm "Vietnamese"/"Tiếng Việt" appears in the metadata + audio/subtitle language lists.

## 9. BUG-45 — Settings sidebar on the White theme
- Theme = White. Focused sidebar row must show a DARK label on the platter (was: zero label
  pixels). Also glance at the Écran d'accueil toggle rows while focused — if any label washes
  out there, note it (the env-based rowAccentTint sites were deliberately not blind-swept).

## 10. General regression sweep
- BUG-56: Trailer Sound by Default ON → focus trailer has sound; navigate away/back → still has
  sound. (Static analysis says the code is right; the beta.11 report likely observed the
  container-reset default.)
- UX-13/UX-14: See All grid and a collection folder grid both restore scroll position after
  backing out of a title.
- BUG-48: See All from a SEARCH row shows the searched results (Stremio Catalog Plus no longer
  empty; Bingecat shows searched, not unfiltered, titles).

---

## RESULTS (2026-08-11 device pass, recorded live)

**Section 1 — DONE (see beta12-handoff-reach88.md).** Rest error gone on beta.12 (deterministic
rests), BUG-61 confirmed, BUG-53 fixed via reach 72→88 (`5f6f2900`, gated, pushed). No clamp
calibration needed — shipped 72 never binds at rest.

**Section 2 — DONE, BUG-31 FIXED.** Reporter was right: the toggle never reached SeeAllCard
(every Home row), episode cards, or the detail trailer thumbnail (unconditional
`.hoverEffect(.highlight)`; only PosterCard/LandscapeCard read the key). Fix: shared
`TileFocusLift` — zoom ON keeps the system lift, OFF draws still-mode border+shadow.
Device-verified on all three surfaces, sim UITests ×7 green, Codex clean (`c6d762eb`, pushed).
No filming needed — fixed instead.

**Section 3 — DONE, PASS.** ~15 min trailer soak on the stateless build: trailers survived.
Probe counts over the soak: 92 focus / 18 dwell / 18 expand (3 resolved, 14 cache-miss →
resolution) / 12 begin / 11 end / 12 teardown / 0 errors. Gates line:
`inlineTrailersEnabled=YES systemAutoplay=YES`. BUG-46/55 hardening holds — the dead state
did not arise; no container dump needed.

**Section 4 — DONE, DATA CAPTURED.** `[GifDecode] side=200 ceiling=782 sourceFrames=90
keptFrames=78 bytes=7113600` (and side=200 ceiling=782 sourceFrames=80 keptFrames=78).
Verdict: the doubled 4K ceiling never engages for real collection GIFs — they run 80–90
source frames, so the 12 MiB per-GIF budget clamps decode side to 200px, far below the 782px
ceiling. Short GIFs (<~12 frames) gain full resolution; typical collection tiles are
unchanged from beta.11. The frame-vs-resolution trade (delay-folding subsampling and/or a
bigger budget) now has its device data: 80–90 frames typical. Deferred to beta.13 tuning.

## RESULTS (2026-08-12 device pass, sections 5–10, recorded live)

Build on device: the 2026-08-11 Release product (stamp `5f6f2900`, includes the then-uncommitted
`c6d762eb` TileFocusLift code — built 21:56, committed 22:01). Console captured live via
`devicectl … launch --console` with `-debug.trailerProbe YES`. Session noise, both known:
the non-fatal `PostgrestRestException: Unsupported Nuvio client (22023)` from
`register_current_device`, and one JetsamEvent at 18:14 whose victim was `storekitd`
(per-process-limit) — NuvioTV was healthy at ~44 MiB in the same snapshot; the capture's
signal-9 exit was a foreground force-quit/App Store visit on the TV, not an app problem.
Release-build gating note: `[LaunchTrace]` and `[ExtPlayerProbe]` are DEBUG-only and never
appear; `[TrailerPipeline]` is knob-gated and live.

**Section 5 — DONE, PASS.** Langue des métadonnées set to Français through the real UI (profile
sync forbids prefs injection), then cold relaunch via devicectl. Hero committed ONCE, already
French — no EN→FR swap (BUG-42 holds; verdict is the eyeball on the committed hero since
LaunchTrace is compiled out). Rows: captions localize as rows scroll in (BUG-35 fix works) —
*The Odyssey* renders French while *Spider-Man: Brand New Day* stays English, and that pair is
CORRECT: TMDB's own fr-FR title is "Spider-Man : Brand New Day" (verified live against
themoviedb.org fr-FR — French marketing keeps English Marvel titles). "Still English" captions
are titles whose official French title IS the English one, not enrichment misses. Row HEADER
names stay addon-manifest English by design; the fix targets item captions only.

**Section 6 — DONE, PASS.** Stream-list language badges compared against the phone side-by-side
with the badge pack installed: "badges match the phone now" (Christian, live). The beta.12
8-digit ARGB parsing fix renders pack colors as mobile does; the beta.11 white-box symptom
(BUG-43) is gone on device.

**Section 9 — DONE, PASS (both halves).** White theme: "shows a dark label in the settings side
pane for all options" (Christian, live) — the BUG-45 invisible-focused-label state is gone on
device. Home Screen pane focused toggle rows: "all readable on white theme" — the env-based
rowAccentTint sites that were deliberately not blind-swept hold up too.

**Section 10 — DONE, ALL PASS.** On the original 2026-08-11 build, pre-bisect-deploy: BUG-56
trailer sound works (Trailer Sound by Default ON → sound, and it survives navigate-away-and-back
— the beta.11 report was indeed the container-reset default, as static analysis predicted);
UX-13 + UX-14 both restore scroll position (See All grid AND collection folder grid, after
backing out of a title); BUG-48 search See All "shows correctly" — searched results, no empty
grid (Stremio Catalog Plus class fixed in the wild's exact repro shape).

**Section 7 — IN PROGRESS, /play FAILED on device.** VidHub detected everywhere it should be
(Default Player dropdown + long-press menu both list it; console shows `open-vidhub://`
canOpenURL succeeding while vlc/outplayer fail -10814 as expected). But the handoff does NOT
play: VidHub opens to its home screen with no playback attempt, on the documented `/play`
method, and a post-onboarding retest reproduced it — first-run interception ruled out.
VidHub's integration docs claim Apple TV supports `/play` (verified live at
vidhub.okaapps.com/3rd-party-app-integration); the tvOS build appears to lag them. Encoding
exonerated (strict RFC 3986 unreserved-only encoder). Bisect build deployed live (stamp
`c6d762eb` + uncommitted knobs, UUID `688F6DBA-409D-3F8E-938E-5DD967393CC0`): new
`debug.vidhubMethod` knob (open | minimal | unset=full /play) + knob-gated
`debug.extPlayerProbe` URL log (single-arg NSLog, %-escaped — the K/N varargs segfault trap).

**Section 7 — VERDICT: VENDOR-SIDE FAILURE, full bisect matrix run on device.** All three
variants fail identically — VidHub opens to its home screen, zero playback attempt:
(1) documented `/play` with url+filename+position, (2) legacy `/open` with url only,
(3) minimal `/play` with url only. The probe captured the exact URL delivered
(`open-vidhub://x-callback-url/open?url=https%3A%2F%2Fnexus-136.snam.tb-cdn.io%2F…` — clean
encoding, plain https CDN source), onboarding was completed and retested, and no public
reports of a working tvOS handoff exist (the Stremio ask, issue #907, is an open feature
request). Detection/menu integration all works (Default Player dropdown + long-press menu +
canOpenURL). Conclusion: the tvOS VidHub build ignores its own documented x-callback-url
API; nothing left to fix on our side. The `debug.vidhubMethod` bisect knob stays (launch-arg
domain is volatile — no cleanup needed; unset = documented /play). **Ship decision (Christian,
live): KEEP VidHub listed, with a known-issue note** in the release notes/announcement — "VidHub
appears in the player list but its tvOS build currently ignores playback handoffs; implemented
per VidHub's own integration docs and verified byte-exact on device; reported to Oka Apps."
Follow-ups: report to Oka Apps; retest with the bisect knob when VidHub updates; tell Ginosaure
(FEAT-21 requester) the state honestly in the reply.

**Section 8 — DONE, PASS.** System language flipped to Tiếng Việt, UI walked: "vietnamese is
working" (Christian, live). Reported as a pass on the walk; no truncation/overflow or stray
English called out.

---

**PASS COMPLETE (2026-08-12).** All 10 sections done across two sessions (1–4 on 08-11, 5–10
today). Scoreboard: sections 1–6, 8, 9, 10 PASS (BUG-53, BUG-31, BUG-46/55 soak, BUG-39 data,
BUG-42/35, BUG-43, FEAT-19, BUG-45, BUG-56/UX-13/UX-14/BUG-48 all hold on hardware). Section 7
is the one failure and it is VENDOR-SIDE: VidHub's tvOS build ignores its own documented
x-callback-url API on all three method variants (byte-verified delivery); shipping listed with
a known-issue note per Christian's call. Code delta from this pass: the `debug.vidhubMethod`
bisect knob + gated `[ExtPlayerProbe]` URL log (uncommitted at pass end — gate + commit next).
Remaining before release: tracker row updates, README features/screenshots, release-beta.sh,
announcement + replies (BUG-53 + UX-9 publicly promised; FEAT-21 known-issue note; BUG-58/59
reporter asks).

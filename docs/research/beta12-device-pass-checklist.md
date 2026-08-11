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

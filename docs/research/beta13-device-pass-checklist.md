# beta.13 device pass — checklist (Living Room Apple TV, tvOS 27.0)

Build under test: NuvioTV **Debug**, `generic/platform=tvOS`, NuvioMobile `301792fe` (outer `eae1883`),
installed via `devicectl` on 2026-08-16. Same shape as the beta.12 pass
(`docs/research/beta12-device-pass-checklist.md`). Tick each line PASS / FAIL and note what you saw;
anything FAIL jumps the queue (scope decision 4).

Reporter configs to reproduce where noted: **u/mrStevenx3** = White theme, Accent Focus Ring ON,
No Zoom on Focus ON, Hide Titles ON, portrait rows, French UI.

## 1. BUG-58 — theme swatch labels (PROMISED publicly)
Settings → Appearance → walk focus along the Theme row.
- [x] Every focused swatch's name is bright/legible on the default (dark) theme.
- [x] Switch to **White**, repeat: focused name legible; selected name reads primary at rest.
- [x] Nothing else in the row regressed (selection ring on the selected swatch, White swatch's dark ring).

## 2. FEAT-18 — title on the focus-trailer tile
Home Screen → Trailers on Focus ON. Appearance → **Hide Titles ON**.
- [x] Portrait rows: dwell on a card → tile widens → **logo (or title text) sits bottom-left over a dark foot scrim**, still + while the trailer plays; no overlap with a pinned row title in Nuvio-Style Home.
- [x] Landscape Rows ON: same tile shape, same overlay.
- [x] Hide Titles OFF: **no** in-tile overlay (caption below stays, no double title).
- [x] Reduce Motion / accent ring ON: overlay sits under the ring cleanly.

## 3. UX-8 — Hide Discover
Settings → Content Sources → Search Sources → **Hide Discover**.
- [x] ON → Search tab shows the field + recent searches only; typing still searches.
- [x] OFF → Discover section returns (types / catalogs / genres / grid) without relaunch.
- [x] Sync: toggle on the TV, then check it stuck after a background→foreground; if you have the phone build handy, confirm it survives a phone-side settings push (it should — merged keys).

## 4. BUG-57 — Card Depth "Top" (En haut)
Appearance → Card Depth ON → Edge **Bold** → Edge Coverage **Top**, reporter config (ring+no-zoom).
- [x] Unfocused cards show a clearly visible light rail across the top edge arcing over the corners, no side rails, no bottom.
- [x] **Full** unchanged (closed hairline).
- [x] Half sits between. Subtle edge at Top still visible from the couch? (note your read).
- [x] Reset to Defaults afterwards.

## 5. BUG-30 / BUG-62 — Home tab-bar clip (device-only, Wave 3)
- [x] Nuvio-Style hero: scroll rows up/down; does the minimized tab bar ever clip / land on the hero band? Note the `REST classic residual` if the probe is on (`debug.homeScrollProbe`).

## 6. Device registration (22023)
- [x] After launch + profile pick, does this Apple TV now appear in your Nuvio account's device list (web/phone)? Previously it never did.

## 7. VidHub retest (only if VidHub shipped an update)
- [x] `debug.vidhubMethod` knob route as in beta.12.

## 8. Regression sweep of beta.12's device-verified items
- [x] French hero + rows commit once; badges; White-theme labels (BUG-45); UX-13/14 grid restore; BUG-48 search See All; sound survives navigation (BUG-56).

## 9. BUG-63 — trailers gated on the Metadata Language (Waves 6–7, `d66ae6c3` + `72064a5a`)
Settings → Content Sources → Metadata Language = **Français**. `defaults write com.nuvio.media.NuvioTV debug.trailerProbe -bool YES`.
- [ ] Focus 10 titles that showed NO trailer on 108 (the reporter's list: most of *Films tendances*): the inline trailer now plays for the ones that have an English trailer.
- [ ] `log show … "[TrailerPipeline]"`: `noTrailerListed … listed=0` ≈ 0 for those titles (a non-zero `listed=` with no play is a different bug).
- [ ] Flip Metadata Language → English → back to Français: `[TrailerPipeline] cache purge reason=language from=… to=…` appears each time and no card keeps the old language's answer for 20 min.
- [ ] Detail hero trailer + Trailers & Extras still list everything (language is a preference, not a filter).

## 10. BUG-59 / UX-9 — measured zoom learns per title and survives relaunch (Wave 7)
Same probe knob. Trailers on Focus ON.
- [ ] Focus a card ~2 s: `[TrailerZoom] interim samples=2… applied=…` within ~1 s of the `attach`, then `final … persisted=1`.
- [ ] Relaunch the app, focus the same card: `[TrailerZoom] persisted-hit key=… token=match|mismatch` BEFORE any sample line; `store loaded n=` > 0 at launch.
- [ ] Zero `insufficient … interimApplied=0` lines across ~10 focuses (an `abandoned samples=0` on a card left before playback started is fine).
- [ ] If the reporter's GIGN-vs-neighbours pair can be identified: both fill the tile.
- [ ] `defaults write … debug.trailerSmokeVideoId` present WITHOUT the probe knob → `smokeVideoId present=… honored=NO` at launch and trailers are NOT all the same clip.

## 11. BUG-42 — hero commits its artwork once (Wave 8, `cb580fab`)
`defaults write com.nuvio.media.NuvioTV debug.homeHeroProbe -bool YES`. Reboot-cold launch ×5 (or force-quit + relaunch ×5).
- [ ] Each launch: exactly ONE `[HomeHero] paint … first=1` (kind=primary, or seededPrimary on a warm memory cache) and ZERO `publish … headChanged=1` / `hero emptied` before any focus moves. A `paint kind=fallbackHeld first=1` (poster shown after 600 ms) is allowed — count them.
- [ ] Watch the hero with your eyes on the same launches: one image, no swap.
- [ ] Settings → Home Screen → change a Hero Source → back Home: the hero DID redraw (explicit change resets the ranking).
- [ ] Collection-only check if you have such a profile: the collection hero appears within ~5 s of Home (first-refresh grace).

## 12. BUG-39 — GIF cadence (Wave 9, `b22ea933`)
`defaults write … debug.gifDecodeProbe -bool YES`, scroll the Collections row.
- [ ] `[GifDecode] … side=~300 sourceFrames=90 keptFrames=90` (all frames; side ~300 on 4K, ~245 on HD).
- [ ] Phone 60 fps clip of one focused GIF tile: uniform cadence, no 5/10 cs judder. Softer than 108 (301 vs 391 px) — your read: acceptable? If "too soft" the follow-up is the 24 MiB 4K budget.

## 13. BUG-64 — ring never covers the poster (Wave 9, `f67a9582`)
Appearance → Accent Focus Ring ON + No Zoom on Focus ON (reporter config), any theme.
- [ ] Focused poster: the ring sits in a 4 pt band AROUND the artwork; the poster's own edge is fully visible inside it (compare 108: the stroke ate the outer 4 pt of art).
- [ ] Unfocused cards in ring mode: the reserved 4 pt band is invisible at couch distance (row spacing reads normal).
- [ ] Landscape cards (episodes / continue watching): same, and the progress bar sits inside the band.
- [ ] Ring OFF: byte-identical to before (no inset).

## 14. BUG-38 — collection covers / title images (Wave 9, `28285016`)
`defaults write … debug.collectionCoverProbe -bool YES`, open Home with collections.
- [ ] One `[CollectionCover] collection=… folder=… own= heroBackdrop= collectionBackdrop= logo= … unknownKeys=[…] shown=…` per tile; on YOUR account `unknownKeys=[]` (a non-empty list names a key another client writes that this build doesn't read — that is the reporter's likely answer).
- [ ] A folder with BOTH a user cover and a title logo (create one on the phone if none): the logo now overlays the cover; a Netflix/Prime (TMDB network) folder still shows the wordmark once, not twice (BUG-52).
- [ ] Ask u/mrStevenx3 for his exported Collections JSON — the payload IS the answer.

## 15. FEAT-24 — season posters (Wave 9, `f0ff367d`)
Open a multi-season series (Fallout, Breaking Bad).
- [ ] The season selector is a row of 2:3 season posters with labels; the selected season is outlined in the accent; focus lifts (still under No Zoom).
- [ ] Left/Right across seasons switches the episode row; Down lands on the episodes; Up returns to the posters.
- [ ] A series with no TMDB season art still shows the text chips.

## Notes

**2026-08-16 — Christian ran the pass on the Living Room Apple TV (Debug `301792fe`): "Everything seems to be working."** Sections 1–4 + 6 + 8 read as PASS on his word (no FAIL reported; no per-line notes). Section 5 (BUG-30/62 residual) and 7 (VidHub — no vendor update yet) carry no new data. Wave 3 therefore stays at "no device-observed clip this build" rather than a measured residual.

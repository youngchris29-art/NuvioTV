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

## Notes

**2026-08-16 — Christian ran the pass on the Living Room Apple TV (Debug `301792fe`): "Everything seems to be working."** Sections 1–4 + 6 + 8 read as PASS on his word (no FAIL reported; no per-line notes). Section 5 (BUG-30/62 residual) and 7 (VidHub — no vendor update yet) carry no new data. Wave 3 therefore stays at "no device-observed clip this build" rather than a measured residual.

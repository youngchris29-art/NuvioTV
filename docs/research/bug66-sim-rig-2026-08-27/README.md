# BUG-66 sim rig — tab-bar minimize A/B (2026-08-27)

The rig called for by `docs/traces-2026-08-27-bug66-upcoming.md` Trace B step 1: seed the
hero mode straight into sim prefs (no Settings walking), walk each surface, and watch the
system tab bar. Built and run against the Debug build of `e19fbfc8` (claude/beta15 lineage,
contains the full beta.15 T2–T4 fix) on the tvOS 26.5 sim fixture
`FA87E9B6-F28D-4DF9-84E4-A5A4C5DBFC4E`.

## Files

- `barkit.py` — driver library: osascript D-pad, screenshots (2 px/pt exact), tab-bar band
  crop/metrics, **container-plist prefs seeding** (`seed_hero_mode`, `cold_seed`), console-pty
  launch + `[HomeScrollProbe]` parsing, loud input-dead self-check.
- `run_ab.py` — the protocol. `python3 run_ab.py [search|classic|pinned-hero|pinned-panel ...]
  [--cold]`. Each pass: fresh launch → default-focus profile select → top/mid/deep/return
  stations with screenshots + band metrics → probe-mode self-validation. `--cold` seeds through
  a sim shutdown/boot (see gotchas). Always ends by restoring the fixture to Nuvio-style.
- `out/` — curated 1280px station frames (`<pass>_<station>_view.png`), probe logs.

## RESULTS (all four passes valid, seeds verified by the app's own probe mode line)

| pass | config | bar at top | bar deep | bar on return | rows-ScrollView inset |
|---|---|---|---|---|---|
| search (control) | untouched | expanded | **receded** | back | n/a |
| classic | nuvio=F hero=T | expanded | **receded** | back | **0 / 157 / 302** |
| pinned-hero (reporter) | nuvio=T | expanded | **receded** | back | **always 0** |
| pinned-panel | nuvio=F hero=F | expanded | **receded** | back | **always 0** |

Two headline findings:

1. **The sim does NOT reproduce the device's "never minimizes".** On the 26.5 sim runtime the
   bar recedes on scroll-down and returns at top in *every* mode, including both pinned Home
   flavors — while Christian's same-code Release device confirm shows pinned Home never
   minimizing. Bar *presentation* is hardware-divergent (consistent with the BUG-30 history:
   the sim never showed its stuck states either). So the sim canNOT visually falsify H1, and
   canNOT show whether F1 (`.tabBarMinimizeBehavior(.onScrollDown)`) helps — F1's sim gate is
   regression-only; its real test is the device.
2. **H1's geometry is nonetheless CONFIRMED, measured by the app itself:** classic Home's rows
   ScrollView reports `inset=157` (expanded bar) / `302` (transients), i.e. it owns the bar's
   safe-area band and rests at `residual=0`; both pinned modes report `inset=0` on every
   sample of full walks (575/672 samples) — the pinned rows ScrollView **never occupies the
   bar's band**. This also validates F3's recipe correction: the discriminating device reading
   is `i` **157-vs-0** (under the bar at all), never 157-vs-76.

Consequence for the fix order in the trace doc: the **sim-verifiable criterion for any F2-style
association fix is structural, not visual** — after the fix, pinned Home's probe must read
`inset=157` at rest-at-top. That is exactly what this rig measures, so it remains the gate for
F2 spikes even though the sim's visual bar behavior diverges from hardware.

Bonus finding strengthened: the expanded-bar band measures **157pt in the sim too** (classic
inset), matching the only device capture — `Theme.swift:263`'s 76pt pinned budget looks
mis-measured on both instruments now.

## Gotchas re-learned building this (all encoded in the scripts)

- **`simctl spawn defaults write/read` is the sim-wide prefs mirage** — the app never sees that
  domain. Seed by editing the app data container's plist with plistlib (BUG-60 precedent), and
  the container UUID **rotates on every reinstall** — resolve with `get_app_container` fresh,
  never cache (and resolve *before* `simctl shutdown`; it errors 149 on a shut-down device).
- **cfprefsd clobbers warm plist edits that FLIP a value** it has cached (same-value rewrites
  survive). `cold_seed` (shutdown → edit → boot) defeats it. Either way every Home pass
  self-validates via the probe's mode name — never trust the seed silently.
- The probe log always opens with **~4 "classic" launch transients** (Home renders once with
  default settings before the profile payload loads) — validate on the dominant mode.
- **osascript keys get eaten if Simulator loses frontmost** — re-`activate` before every press
  batch, and treat identical station screenshots as a wedged walk, not a verdict.
- The house rule held: verdicts by reading the frames; band metrics only flag candidates.

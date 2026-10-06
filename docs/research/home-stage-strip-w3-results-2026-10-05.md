# Home Stage & Strip: tests and review results (2026-10-05)

Branch `claude/home-stage-strip` in the clone `~/Claude/Projects/NuvioMobile-home-stage`, local only, tip `4f62e836` (was `7494ee21` at Gate 2). Everything below the device-pass section ran on the FA87 simulator (tvOS 26.5) in the guest fixture.

**Where it stands:** Wave 3 and three review rounds are done and Gate 2 is green on the simulator. The device pass on the Living Room Apple TV (Test profile) passed all 16 steps; its one finding, a grey bar with OLED True Black, is fixed in `4f62e836` and confirmed on the TV. Next: the merge and a cut, each on your go.

## Device pass (2026-10-05)

- **All 16 steps pass.** Tabs for steps 1–13, the rail for 14–15, back to Tabs for 16. Full table in the plan's OUTCOME "Device pass".
- **Paging on hardware:** 71 single-row presses, one move each, settled in 529–631 ms. Menu glides take 1.15–1.84 s (a tuning note).
- **The one bug, OLED grey bar:** the ambient wash took its size from the image's 16:9 shape instead of the space it was given. That made Stage 2006 pt wide and pushed Home's black background 160 pt in from the left edge; at OLED's 40 % wash the gap showed. Fix `4f62e836`; a new UI test measures the step at x 160 (15.4 before, 0.0 after). On the TV: no bar, and rows now keep the designed 140 pt right margin.
- **r3's checks on hardware:** no 140 → 176 jump at a cold launch in Always Visible; the Grid keyboard clears the pill; Search Menu → rail → Right works; Reduce Motion cuts (by eye; the console missed that window).
- **Watch item:** once, on the first Up after a fast Down walk, a row moved in 83 ms instead of gliding (1 of 152 logged moves).

## Reviews (Opus, read-only; Codex is over quota until 10-29)

| Round | Found | Done |
|---|---|---|
| r1, two passes over Waves 1–2 | 1 P1, 7 P2, 13 P3 | All P1/P2 fixed, plus 11 P3s (`02c45450`) |
| r2 over the r1 fixes | 1 P2, 5 P3 | Fixed (`66f2a00c`); the Upcoming/collection remount restore is deferred |
| r3 over the r2 fixes and the shell inset | **CLEAN**: no P1/P2, 4 P3 | 3 applied; the first-frame inset is a device check |

The ones that mattered:
- **P1, memory:** every folder page you opened leaked its stage controller and the 4K backdrop it holds, about 33 MB per visit. Fixed: the pager now lets go when the page goes away.
- **Focus pulled back:** a late restore step could pull focus back after you'd moved on (Down right after Menu; a second Menu to the tab bar).
- **Re-rendering:** every Down/Up re-rendered all the mounted rows, the stutter class from BUG-126. Now only the rows entering or leaving the window re-render.
- **Hidden row:** a Continue Watching or Upcoming row arriving while focus sat on the tab bar ended up hidden above row 0.
- **Layout flip:** switching Home Layout live left Menu in the wrong state (it could suspend the app at Classic's top).
- **Edit band:** the folder Edit band could vanish while it held focus.
- **Reduce Motion:** Menu could unmount the row that still held focus, which switched off focus-lost detection.

## UI suite

| Area | Result |
|---|---|
| Stage, S01–S16 | **16 / 16** |
| Rail, Rail01–10 (+01b, 05b) | **10 / 10** |
| Folder page and Stage settings, test84, 93, 100–108 | **11 / 11** |
| Search legs, test19, 23, 24, 29, 92 | **5 / 5** |
| Classic legs (`-home_layout classic`) | 20 pass, 8 skip, 1 known fail. No regressions against the Wave 0 baseline; test64 and HeroFolderSwap test54 now pass. The skips are fixture premises, as at the baseline. test48 fails on its known "premise unreachable" guard. |
| Card-level legs | 8 pass, 2 skip. The 2 fails are test27/28, Appearance legs that went stale with the Detail + Settings revamp (already listed in CLAUDE.md). |

Unit tests: **1271 / 0**. Translations: 48 strings in de/es/fr/it/vi.

## What the run itself found

1. **Always Visible's room for the rail only reached Stage.** SwiftUI's safe-area padding never got past each tab's navigation stack. So Classic Home, Search, Library, Settings and pushed pages kept content at 140 pt, while the fade settings assumed 176. Fixed at the tab controller (UIKit safe area): content now starts at 176 everywhere. The system Search keyboard moved from x 80 to 116 too, so it clears the pill.
2. **Seven test-side fixes, all measurement problems, not app bugs:**
   - container frames that are their children's union (S04, Rail08);
   - an open tvOS Menu exposes its options as cells, and the Edit menu's focus sits on an unlabelled node (test101, 105);
   - the Menu exit was detected late (Rail04);
   - the simulator's Down hop settles in 0.2 s (S09);
   - one missed profile pick (S13).
3. **test93 flake:** it failed once (the rail stayed expanded after focus reached the keyboard), then passed 4 / 4. Worth a look on the TV.

## Open

- **Folder title at row 0** sits under the tab bar pill in Tabs mode. You said to leave it.
- **Device checks: all done 2026-10-05** (see the device pass above):
  - the Grid keyboard clears the pill;
  - no 140 → 176 jump on a cold launch;
  - Reduce Motion paging cuts;
  - Search: Menu → rail → Right works;
  - `[NavRail] reserved leading safe area=36` logs once at a cold launch; a shell remount (switching to Rail, an OLED toggle) logs it again with the same value, and nothing moves.

Screenshots: `docs/research/home-stage-strip-sim-evidence/w3-*.jpg`.

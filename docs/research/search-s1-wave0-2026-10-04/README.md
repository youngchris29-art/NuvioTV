# Search S1 · Wave 0 evidence (2026-10-04)

Results and decisions are in `docs/search-s1-native-search-plan-2026-10-04.md`, section "Wave 0 outcome". This folder holds the evidence.

- `wave0-rig.patch`: the throwaway rig, applies to NuvioMobile `tvos-shared-extraction` `dad2bed5`. It is the search-field spike patch plus:
  - variants A0 (the spike's SearchView verbatim) and A2 (`.searchable` in a layer that observes only the query box);
  - SearchView split into owner, field layer and content;
  - rows hold modes 1 and 2 (`-debug.searchRowsHold`);
  - two tab-bar link modes (`-debug.searchTabBarLink YES`, `-debug.searchTabBarLinkMode 2`);
  - the Sidebar Menu router and hidden-tab-bar focus redirect (`-debug.searchMenuRouter YES`);
  - a passive press logger and render counters;
  - the XCUITests `testW0SearchableSimA` and `testW0SearchableSimA2`.

  Never merge it.
- `logs/device-search-spike.log`: the probe's file log from the Living Room Apple TV (tvOS 27.2, Test profile, Grid keyboard). It has five launches: run 1 (A, rows mode 1), run 2 (A2, rows mode 2, top-down link), run 3 (A0), run 4 (Sidebar, router as a consuming recognizer) and run 4b (Sidebar, simultaneous recognizer plus focus redirect).
- `logs/console-run*.log`: the probe lines from each `devicectl --console` stream. They are partial where the stream dropped, and the rest of the app's console is left out.
- `logs/sim-fa87-26.5-search-spike.log`: the probe's file log from the FA87 simulator (tvOS 26.5), last run only (A2, top-down link).
- `logs/xcuitest-sim*.log`: the `W0 [...]` lines and the pass line from each XCUITest run (A; A2 with the existing attacher; A2 with the top-down link).

Christian's run 2 video of the pinned tab bar (`IMG_0379.MOV`, 41 MB) is not committed. It stays in his Downloads.

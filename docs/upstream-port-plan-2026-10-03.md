# Upstream port plan — 2026-10-03

Daily check of `NuvioMedia/NuvioMobile` (`cmp-rewrite`) vs the fork's `NuvioMobile` submodule (`tvos-shared-extraction`).

Upstream moved: `e2f8ac25` → `7be1b56c` (tag `0.5.6-beta`, build 138). 7 commits: 3 real (`81863d34` auto-skip notifications, `312f7399` tablet detail hero, `3fa2c120` Vietnamese i18n), 2 merges, 1 version bump (`7540fa29`, 0.5.5/137 → 0.5.6/138), 1 store publish. Zero changes under `shared/`. The rest of 0.5.6 (#2150 autoplay-on-end, #2140 preload, #2139 poster fallback, a984b390 localizations, b3d7c5b6 RTL prompt) was covered in `upstream-port-plan-2026-10-02.md`; #2150 and #2140 are already adopted on tvOS (see CLAUDE.md).

**Headline: one small, optional port (LOW). Nothing blocking.**

## Port 1 [LOW, optional UX polish] — "Intro skipped to 1:23" toast on auto-skip

Upstream `81863d34` (PR #2137, composeApp-only, no `shared/` footprint): when auto-skip fires, show a 1.4 s toast: "Intro/Recap/Outro/Credits skipped to %1$s" (position the seek landed on). Strings `player_auto_skip_{intro,recap,outro,movie_credits}_notification`. Upstream also moved `autoSkippedIntervals.add` after message build — irrelevant to tvOS.

tvOS gap (verified): auto-skip is silent. `SkipSegmentPlanner` returns `Decision.autoSkipTargetSec`; `NativePlayerScreen.swift:265` calls `skipSeek(to:kind: .auto)` and `MPVPlayerView.swift:1313` calls `seekAbsolute(_, kind: .auto)`. No toast, and "skipped to" is absent from `Localizable.xcstrings`.

Plan for Claude Code (on a branch off `tvos-shared-extraction`):
1. Extend `SkipSegmentPlanner.Decision` (or the `.auto` seek path) to carry the interval's `AutoSkipSegmentType` so the screen can pick the label. Keep the planner pure; add a unit test in the existing planner tests.
2. Add a tiny transient-message overlay for the player (check `NextEpisodeAutoPlay.swift` / existing player chips for a reusable style; tvOS focus must NOT be taken). Auto-dismiss ~1.4 s; re-trigger resets the timer.
3. Wire in both engines: `NativePlayerScreen.skipSeek(... kind: .auto)` after `finished == true`, and the mpv `seekAbsolute(... kind: .auto)` path. Time label: reuse the existing `timeString` helper (`MPVPlayerView.swift:2145`), formatting target seconds.
4. Add 4 strings to `Localizable.xcstrings` (English only, with `%@` position arg), matching upstream wording.
5. Optional gate: show only when Settings → Playback auto-skip is on (it already must be for the path to fire). No new setting needed.
6. Gates: NuvioTVTests, Debug + Release sim builds. Device-check: enable auto-skip intro, play an episode with IntroDB data, confirm toast appears once, doesn't steal focus, and doesn't fire on chip-initiated or scrub seeks.

Effort: ~1–2 h. Safe to defer; purely cosmetic.

## Not applicable

- `312f7399` tablet detail hero (`TabletDetailHero.kt`, `DetailActions` refactor, `details_season_count` plural): composeApp/Compose layout for ≥600 dp screens. tvOS Detail is native SwiftUI and is mid-revamp on `claude/detail-settings-revamp`; nothing to port. Only inspiration-level note: upstream now folds Actions + Overview into the hero on large screens and shows a "N Seasons" count (`details_season_count`: "%d Season"/"%d Seasons") — check whether the tvOS revamp already has a season-count label; if not, trivial add.
- `3fa2c120` Vietnamese strings: tvOS is English-only; no action.
- `7540fa29` / `7be1b56c` version bump + store.json publish: mobile release plumbing.
- Merges `6565c9c8`, `9ec460a0`, `8ad330fb`: no code.

## Carried items

None open. Prior decision item (#2150) was adopted; preload (#2140) shipped (off by default).

## Suggested execution order

1. (Optional) Port 1 auto-skip toast, after the Detail + Settings revamp merges, to avoid player/Settings merge noise.
2. Fold the "N Seasons" label check into the Detail revamp review.

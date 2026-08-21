# Upstream port check — 2026-08-21

## Summary

`upstream/cmp-rewrite` (`NuvioMedia/NuvioMobile`) has **not moved**: still pinned at `291b09b7` (2026-08-20 01:59 +0530), zero new commits since yesterday's check. No new tags beyond `0.4.7`. `upstream/copilot/refactor-project-structure` remains stale/abandoned (last commit `cbc9fc4f`, 2026-03-24 — unchanged for months). `upstream/simkl` remains deleted from the remote (harmless, already fully merged).

Fork state at check time: outer `main`-derived work is on branch `claude/beta14` (active in-progress session — CI gate 2 green, security review recorded, uncommitted `docs/beta14-implementation-plan-2026-08-21.md` edits in flight). Submodule `NuvioMobile` HEAD `d3fb779c` on `claude/beta14`, ahead of the last tagged pin (`tvos-shared-extraction` @ `36effd50`, the beta.13.5 release point) — this is expected in-progress beta.14 work, not upstream drift.

**Verified by reading actual file contents (not commit messages):** SDH subtitle stripping (logged as ACTIONABLE in the 2026-08-20 plan) is now fully landed on `claude/beta14` HEAD —

- `shared/.../SubtitleAudioModels.kt:61` — `val stripSdh: Boolean = false`
- `shared/.../PlayerSettingsStorage.apple.kt:42,113,447,449-451,942,1018` — key, load/save actuals, sync payload encode + decode
- `iosApp/NuvioTV/Screens/MPVPlayerView.swift:751-752` — `sub-filter-sdh` / `sub-filter-sdh-harder` mpv properties wired into `applySubtitleStyle()`
- `iosApp/NuvioTV/Screens/Settings/PlaybackSettingsPane.swift:109,264,312-313` — toggle row wired to `SettingsViewModel.setSubtitleStripSdh`

No action needed — this item can drop off future reports.

## Open items (no change since 2026-08-20)

Both remaining items are standing product decisions Christian already made on 2026-08-20; upstream hasn't touched either area since, so there's nothing new to weigh:

1. **[PARKED] Supporter perks v1** (upstream `bd88760e`/`38e6ea28`). Mobile monetization feature (membership tiers, theme accents, custom profile backgrounds, "Support Nuvio" entry point), entirely under `composeApp/`, nothing in `shared/`. Not a mechanical port. Park until re-raised.
2. **[DEFERRED] Subtitle minimum font size** (upstream `d50f84fc`). tvOS uses a different native subtitle renderer (`SubtitleVTT.swift`) than the one upstream's fix touches (`PlayerEngine.ios.kt`); 10-foot UI likely wants a *larger* floor, not smaller. Decide tvOS's own range next time player styling gets a pass — not a straight port.

## Action items for Claude Code

None. Nothing new landed upstream, and the one actionable item from yesterday (SDH stripping) is already shipped and verified in the current tree. Standing decision items (Supporter perks, subtitle min font size) remain parked/deferred by product decision — no urgency, zero drift risk from waiting.

## Next scheduled check

Re-fetch `upstream/cmp-rewrite`, diff past `291b09b7`. If it's still stale, this becomes the third consecutive no-movement day (`bbac53b2` held 2026-08-17→08-19, then moved once to `291b09b7` on 08-20, now flat again 08-20→08-21).

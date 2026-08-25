# Upstream port check — 2026-08-22

## Summary

`upstream/cmp-rewrite` (`NuvioMedia/NuvioMobile`) **moved** for the first time since 2026-08-20: `291b09b7` → `b80ee5ab`, two new commits (both from `tapframe`, 2026-08-21 evening IST). `upstream/copilot/refactor-project-structure` remains stale/abandoned (unchanged for months). `upstream/simkl` remains deleted from the remote (harmless).

Fork state at check time: outer `main` @ `c165199` ("beta.14.5 comms posted"). Submodule `NuvioMobile` pinned at `386eabfd` on `tvos-shared-extraction` (matches beta.14.5 build 112 release). Clean, no drift between outer pin and submodule HEAD.

## New upstream commits (`291b09b7..b80ee5ab`)

### 1. `faae0cd7` — feat(addons): confirm addon and download deletions

Adds a confirmation modal (`NuvioStatusModal`) before deleting an installed addon or a download, instead of deleting immediately on tap. Touches only `composeApp/` (`AddonsScreen.kt`, `DownloadsScreen.kt`, strings) — nothing in `shared/`.

- **Downloads half: not applicable.** tvOS has no downloads/offline feature at all (verified: no `Download` references under `iosApp/NuvioTV`) — Apple TV doesn't do local downloads in this app. Nothing to port.
- **Addon-deletion half: actionable UX gap.** Verified in current tvOS code: `AddonsViewModel.remove(_:)` (`iosApp/NuvioTV/Screens/AddonsViewModel.swift:52-54`) calls `AddonRepository.shared.removeAddon(manifestUrl:)` directly with no confirmation, and `AddonsView.swift:91` wires the remove button straight to `model.remove(addon)` — no `Alert`/`confirmationDialog` anywhere in that view. One stray focus click on the remote currently deletes an addon with no undo. Upstream's fix (require a Yes/No confirm) is a real, cheap safety improvement and translates cleanly to tvOS idioms.

### 2. `b80ee5ab` — fix(profiles): use profile background on mobile loading screen

New `ProfileBackgroundBackdrop.kt` composable; wires the profile's custom background (from `ProfileBackgroundRepository`/`MemberAccessRepository`) into the mobile loading/profile-selection screen instead of the plain mesh gradient. This is a follow-up/fix within the **Supporter perks v1** feature family (custom profile backgrounds gated by membership tier) — same feature already logged as `[PARKED by product decision 2026-08-20]` in prior reports (upstream `bd88760e`/`38e6ea28`). Entirely `composeApp/`, depends on membership/background-catalog infra that doesn't exist on tvOS.
- **Not actionable.** Stays parked with the rest of Supporter perks v1 — no new decision needed, just noting the family keeps growing upstream while parked.

## Action items for Claude Code

- [ ] **[LOW effort, NEW 2026-08-22] Add delete-confirmation to tvOS addon removal.** In `iosApp/NuvioTV/Screens/AddonsView.swift`, wrap the remove action (currently `model.remove(addon)` at line 91) in a tvOS-native confirmation — `.confirmationDialog` or `.alert` with "Remove addon?" / Cancel / Remove — matching the mobile UX added in upstream `faae0cd7`. No `shared/` changes needed; this is pure `AddonsView.swift`/`AddonsViewModel.swift` work. Use existing tvOS alert/dialog patterns elsewhere in the app (e.g. Remote Setup confirm flows) for consistent styling per the `mcpmarket-me:tvos` HIG skill. Small enough to fold into the next UI-polish pass rather than needing its own release.

## No action needed

- Downloads deletion confirm (upstream `faae0cd7`, downloads half) — tvOS has no downloads feature.
- Profile background on loading screen (upstream `b80ee5ab`) — part of parked Supporter perks v1; no new decision, stays parked.

## Standing decision items (unchanged since 2026-08-20)

1. **[PARKED] Supporter perks v1** (upstream `bd88760e`/`38e6ea28`, now also touched by `b80ee5ab`). Membership tiers, theme accents, custom profile backgrounds. `composeApp/`-only, not a mechanical port. Park until re-raised.
2. **[DEFERRED] Subtitle minimum font size** (upstream `d50f84fc`). tvOS's native subtitle renderer (`SubtitleVTT.swift`) differs from what upstream's fix touches (`PlayerEngine.ios.kt`); 10-foot UI likely wants a larger floor, not smaller. Decide next time player styling gets a pass.

## Next scheduled check

Re-fetch `upstream/cmp-rewrite`, diff past `b80ee5ab`. If the addon-delete-confirmation item above ships, drop it from the open-items list (verify by reading `AddonsView.swift` for the alert/dialog, not just checking the commit log).

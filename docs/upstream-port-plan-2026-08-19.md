# Upstream port check — 2026-08-19

## Summary

`upstream/cmp-rewrite` (`NuvioMedia/NuvioMobile`) has **not moved** since yesterday — still pinned at `bbac53b2` (last commit 2026-08-17). Zero new commits to review today.

`upstream/copilot/refactor-project-structure` unchanged — still stale/abandoned (latest `cbc9fc4f`). The `upstream/simkl` ref no longer exists on the remote (likely deleted post-merge) — harmless, it was already fully merged into `cmp-rewrite` with zero unique commits.

Fork state at check time: outer `main` HEAD `35d8ff8` (BUG-59 frame-read docs), submodule `NuvioMobile` HEAD `5cb2f8b9` on `tvos-shared-extraction`, pinned pointer matches actual HEAD — no drift.

## Verification: did the 2026-08-18 open items land?

**Yes — all three mechanical/actionable items from yesterday's report have landed**, as part of the fork's own "beta.13 waves 6-10" work (outer commit `50af095`, "upstream ports landed"):

1. **Simkl anime library filtering (upstream `96618a86`) — LANDED.** Confirmed in `shared/src/commonMain/kotlin/com/nuvio/app/features/library/LibraryModels.kt` (`mediaCategory: String? = null` field present), `.../simkl/SimklLibraryProjection.kt` (sets `mediaCategory = "anime"` for `SimklMediaType.ANIME`), and `.../library/LibraryDisplaySettings.kt` (`buildLibraryVerticalProjection()` now reads `entry.item.mediaCategory ?: entry.item.type` in both the `availableTypes` computation and the filter predicate). Matches upstream's fix shape exactly.
2. **PIN verify refreshes profile first (upstream `5327166f`) — LANDED.** `shared/src/commonMain/kotlin/com/nuvio/app/features/profiles/ProfileRepository.kt` `verifyPin()` now calls `pullProfiles()` immediately before `rememberVerifiedPin(...)` inside the `if (verifyResult.unlocked)` block, with an explicit code comment crediting upstream `5327166f`.
3. **`shared/AppLanguage.kt` missing `ARABIC` (upstream `3c0ab547`) — LANDED.** `ARABIC("ar")` is present in the enum.

All three were verified by reading the actual current file contents, not assumed from commit messages.

## Still open (unchanged from 2026-08-18)

1. **[MEDIUM, needs a product decision] Self-hosted server discovery** (upstream `ddc28dc8`/`cc20e716`). Confirmed `shared/src/commonMain/kotlin/com/nuvio/app/core/network/SupabaseProvider.kt` still has no discovery/config-URL logic — still hardcoded to the official backend. See `docs/upstream-port-plan-2026-08-16.md` for the full port plan. Highest-value remaining item, but scope decision is Christian's call, not mechanical.
2. **[LOW, needs a product decision] Subtitle minimum font size** (upstream `d50f84fc`). `shared/.../SubtitleAudioModels.kt` still has unbounded `fontSizeSp: Int = 18`. tvOS's native renderer (`iosApp/NuvioTV/Screens/SubtitleVTT.swift`) is a different code path from the one upstream touched — still "decide tvOS's own floor next time player styling gets a pass," not a straight port.
3. **[LOW, new UI needed] TMDB Discover exclusion filters — UI half** (upstream `0fc4616b`). Shared query-builder plumbing already ported (`7dac9a67`, 2026-08-13). Confirmed `iosApp/NuvioTV/Screens/CollectionsUI.swift` still has no exclusion-filter controls — still browse-only by design, no dedicated collection-editor screen exists yet on tvOS.

## Action items for Claude Code

None outstanding from mechanical/shared-code ports — the last batch (Simkl anime type, PIN-verify-refresh, AppLanguage Arabic) is fully landed and verified. Remaining backlog is unchanged and all three items require a product/design decision before implementation, not a mechanical diff-port:

1. Decide scope for self-hosted Supabase-compatible backend discovery (item 1 above) — this is the only MEDIUM-priority item outstanding and the one most worth Christian's attention next.
2. Decide tvOS's own subtitle minimum font size floor (item 2) next time player/subtitle styling gets touched.
3. Design a tvOS SwiftUI exclusion-filter control for `CollectionsUI.swift` / a future collection-editor screen (item 3) — no urgency, additive/default-null fields mean no risk to existing collections in the meantime.

## Next scheduled check

Re-fetch `upstream/cmp-rewrite`, diff past `bbac53b2` (still the reference point — upstream hasn't moved in 2 days). If it advances, check new commits against `shared/` and `iosApp/` as before. Otherwise, backlog is just the three decision-needed items above — no mechanical work queued.

# Upstream port check — 2026-08-23

## Summary

`upstream/cmp-rewrite` (`NuvioMedia/NuvioMobile`) moved `b80ee5ab` → `e27b9195`, 9 new commits (2026-08-19 through 2026-08-23, several translation-only PRs merged out of author-date order). `upstream/copilot/refactor-project-structure` remains stale/abandoned. `upstream/simkl` remains deleted from the remote (harmless).

Fork state at check time: outer `main` @ `50cb163`. Submodule `NuvioMobile` pinned at `e0b9ef9d` on `tvos-shared-extraction` — matches actual submodule HEAD, no drift.

**Every substantive commit in this range touches `composeApp/` only — nothing in `shared/`.** So none of this is a mechanical port; each item needs a native-SwiftUI judgment call same as usual.

## New upstream commits (`b80ee5ab..e27b9195`)

### 1. `54aa75ea` / `9ae179d0` (merge) — Fix anime movies for Simkl

Changes `composeApp/.../simkl/SimklProjections.kt`: `toWatchProgressEntry()` now takes the full library-entry list and cross-references it to detect anime *movies* (vs. episodic anime) by checking whether a matching library entry has `animeType == "movie"`, instead of relying on `episode == null`. Also patches `resolveAnimeEpisodeForSimkl()` to default episode `1` when nothing else resolves it.

**Worth investigating, not a straight port.** tvOS's `shared/src/commonMain/kotlin/.../simkl/SimklProjections.kt` already has a *different*, deliberately-diverged fix for the same anime-movie misclassification bug — there's a code comment there citing "Codex review of the 6e5e41f3 port": it classifies anime-as-movie via the session's explicit `type == "movie"` marker rather than cross-referencing library entries, specifically to avoid discarding incomplete episodic sessions. Upstream's new approach and tvOS's existing approach solve overlapping but not identical cases. Before touching this: diff the two implementations side by side (`git show upstream/cmp-rewrite:composeApp/src/commonMain/kotlin/com/nuvio/app/features/simkl/SimklProjections.kt` vs. `shared/src/commonMain/kotlin/com/nuvio/app/features/simkl/SimklProjections.kt`) and check whether upstream's library cross-reference catches any anime-movie case tvOS's `type == "movie"` check currently misses. If tvOS's existing logic already covers it, no action needed — just note upstream converged independently.

### 2. `52e28562` — feat(supporters): show membership status card

Adds `MembershipOverview`/`MembershipOverviewRepository`/`SupporterMembershipCard.kt` (new membership-status card UI on the Supporters/Contributors settings page), entirely in `composeApp/features/membership` + `features/settings`.

**Not actionable — folds into the parked Supporter perks v1 item.** Same family as `bd88760e`/`38e6ea28`/`b80ee5ab`, already parked by product decision 2026-08-20. No new decision needed; the family keeps growing upstream while parked.

### 3. `1a4ed637` — fix(profiles): show add profile only in edit mode

Mobile bug fix: the "Add Profile" tile was showing outside of edit mode; now gated behind `isEditMode`.

**Doesn't map cleanly — tvOS has no equivalent "edit mode" concept here.** Checked `iosApp/NuvioTV/Screens/ProfileSelectionView.swift:120-136`: tvOS always shows the "Add Profile" tile whenever `profiles.count < maxProfiles`, and edit/delete is done via long-press context menu per-profile rather than a global edit-mode toggle. This isn't a bug on tvOS's own terms — there's no mode where "Add Profile" should be hidden. No action unless tvOS's profile UX changes to add an edit-mode concept.

### 4. `3e9ffad0` + `0363f38c` — fix(ui): blur episode thumbnails consistently / fix(home): blur in-progress episode thumbnails

Two related fixes to the mobile "blur unwatched episode thumbnail" feature (`shouldBlurContinueWatchingArtwork` etc.) across Home continue-watching, meta details, player episode panel, streams screen.

**No action — tvOS never built this feature's UI.** `blurUnwatchedEpisodes` exists in `shared/src/commonMain/kotlin/.../MetaScreenSettingsRepository.kt` (it's carried through the cross-platform settings sync payload), but grepping `iosApp/NuvioTV` turns up zero Swift consumers of that flag — tvOS stores/syncs the setting without ever using it to blur anything. These upstream fixes patch a UI surface tvOS doesn't have. Nothing to port; flag only if tvOS decides to build episode-thumbnail blurring later.

### 5. `c4934bce` — fix(player): refresh pause description between episodes

Mobile Compose player bug: `pauseDescription` wasn't refreshing when switching episodes (new `activePauseDescription` state var threaded through instead of the stale captured value).

**Not a code port — tvOS uses a native player (`MPVPlayerView`), not the Compose `PlayerScreenRuntime*` files this touches.** Worth a quick manual check next time the tvOS player/pause-overlay UI gets touched: does tvOS's native pause overlay show stale episode-description text after switching episodes via next-episode/skip? If so it's the same underlying bug in different code; if not, no action.

### 6–9. `84285fc4`, `0cc5da0d`, `6df97f91`, `05d68d2f`, `e27b9195` — translations + version bump

Bulgarian (`values-bg`) string translation PRs and an `iosApp/Configuration/Version.xcconfig` bump. Both mobile-only (Compose string resources / mobile iOS app version), no tvOS equivalent. No action.

## Action items for Claude Code

- [ ] **[carried over, still open] Add delete-confirmation to tvOS addon removal** (upstream `faae0cd7`, logged 2026-08-22). Verified still unfixed: `iosApp/NuvioTV/Screens/AddonsView.swift:91` still calls `model.remove(addon)` with no confirmation. Wrap with `.confirmationDialog`/`.alert` ("Remove addon?" / Cancel / Remove). Small, no `shared/` changes.
- [ ] **[NEW 2026-08-23, investigate before deciding] Compare Simkl anime-movie fixes.** Diff upstream's `54aa75ea` library-cross-reference approach against tvOS's existing `type == "movie"` marker approach in `shared/.../simkl/SimklProjections.kt` (`toWatchProgressEntry`). Determine whether upstream's fix catches a case tvOS's current logic misses (e.g. anime movies whose playback session lacks an explicit `type == "movie"` marker but which the library confirms as a movie). Port only the delta if one exists — don't blindly replace tvOS's documented divergence.
- [ ] **[NEW 2026-08-23, low priority, spot-check only] Player pause-description staleness.** Next time the tvOS native player overlay gets touched, verify the pause/episode-description text refreshes correctly when switching episodes (mirrors upstream `c4934bce`'s bug in the Compose player). No code changes now — just a thing to watch for.

## No action needed

- Membership status card (upstream `52e28562`) — parked with Supporter perks v1.
- "Add Profile only in edit mode" (upstream `1a4ed637`) — tvOS has no edit-mode concept for profile selection; not a bug on tvOS's own UX terms.
- Episode-thumbnail blur fixes (upstream `3e9ffad0`, `0363f38c`) — tvOS never implemented this feature's UI; the setting is carried through sync but unused.
- Bulgarian translations, version bump (`84285fc4`, `0cc5da0d`, `6df97f91`, `e27b9195`) — mobile-only.

## Standing decision items (unchanged since 2026-08-20)

1. **[PARKED] Supporter perks v1** (upstream `bd88760e`/`38e6ea28`/`b80ee5ab`, now also `52e28562`). Membership tiers, theme accents, custom backgrounds, membership status card. `composeApp/`-only. Park until re-raised.
2. **[DEFERRED] Subtitle minimum font size** (upstream `d50f84fc`). tvOS's native subtitle renderer differs; 10-foot UI likely wants a larger floor, not smaller. Decide next time player styling gets a pass.

## Next scheduled check

Re-fetch `upstream/cmp-rewrite`, diff past `e27b9195`. Verify by reading actual file contents (not just commit log) whether the addon-delete-confirmation item shipped. If the Simkl anime-movie comparison above was done, note the outcome here instead of re-investigating from scratch.

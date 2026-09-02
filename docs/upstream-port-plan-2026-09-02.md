# Upstream port plan — 2026-09-02

## Upstream movement

`upstream/cmp-rewrite` (`github.com/NuvioMedia/NuvioMobile`) **moved** again:
`312d499e` → `9b09045f` (fetched fresh today). Three real commits, no merge
commits:

- `58864ec1` fix(streams): honor autoplay source loading scope (tapframe, 2026-09-01 12:54 +0530) — Fixes #1825
- `92466c4e` fix(player): align mobile control icons with tv (tapframe, 2026-09-02 11:06 +0530)
- `9b09045f` fix(player): allow minimum device brightness (tapframe, 2026-09-02 16:31 +0530) — Fixes #1592

All three read in full via `git show`. **One real action item for tvOS this
run.**

## Commit-by-commit

### `58864ec1` — honor autoplay source loading scope. **Applicable — port.**

Upstream refactors `composeApp/.../streams/StreamsRepository.kt`'s stream
auto-play flow. Before this fix, the "wait for all sources before falling
back to a full auto-play evaluation" logic didn't account for the user's
configured `StreamAutoPlaySource` scope (all sources / installed addons only
/ enabled plugins only) — it wired multiple duplicated, ad-hoc
"early binge-group match" blocks (one after each addon's cache check, one
after each debrid-availability job, one after each debrid-prepared stream,
one on a 60s timeout, one at final completion) with no single source of
truth for "have the addons/plugins the user actually cares about finished
loading yet." The fix consolidates all of that into three small functions —
`evaluateAutoPlay()`, `settleAutoPlay()`, `updateAutoPlayAfterStreamsChanged()`
— and a new `areAutoPlaySourcesLoaded()` extension (new file
`StreamAutoPlayLoadingPolicy.kt`) that only considers a source "loaded" once
every stream group relevant to the configured scope has finished loading,
so auto-play can no longer trigger early against streams from an addon the
user didn't even select as an auto-play source (or, symmetrically, hang
waiting on an addon that's out of scope).

**Confirmed unported and live-relevant to tvOS**, not just composeApp: this
is the "path-only looks like composeApp/-only, but shared/ is an extraction
of it" pattern that's bitten this project before (see 2026-08-26,
2026-08-28 runs). `shared/src/commonMain/kotlin/com/nuvio/app/features/streams/StreamsRepository.kt`
(903 lines) is the shared/tvOS-consumed copy of the exact same file, still
carrying the pre-fix duplicated early-binge-match blocks verbatim (grepped:
five separate `StreamAutoPlaySelector.selectAutoPlayStream(...)` call sites
plus a sixth `evaluateAutoPlayStream(...)` — matches the messy pre-refactor
shape upstream just cleaned up in composeApp). `iosApp/NuvioTV/Screens/StreamsViewModel.swift`
and `iosApp/NuvioTV/Screens/NextEpisodeAutoPlay.swift` both consume this
shared `StreamsRepository`, so tvOS's stream-picker auto-play and
binge/up-next auto-continue flow carry the same bug class upstream just
fixed: auto-play can fire against a stream from a source outside the user's
configured `streamAutoPlaySource` scope, or fail to fire promptly when it
should, because the old logic never checked scope membership before
deciding "sources are loaded."

Dependencies all already exist in `shared/`, so the port is mechanical:
`StreamAutoPlaySource` enum already lives in
`shared/.../streams/StreamAutoPlayModels.kt`, `AddonStreamGroup` already in
`shared/.../streams/StreamModels.kt`, `StreamAutoPlaySelector` already in
`shared/.../streams/StreamAutoPlaySelector.kt`. Port as one end-state:

1. Add `shared/src/commonMain/kotlin/com/nuvio/app/features/streams/StreamAutoPlayLoadingPolicy.kt` — the `areAutoPlaySourcesLoaded()` extension, verbatim from upstream (internal visibility matches).
2. Refactor `shared/.../streams/StreamsRepository.kt`'s `load()` the same way upstream refactored composeApp's: replace the five duplicated early-binge-match / timeout / final-fallback blocks with `evaluateAutoPlay()`, `settleAutoPlay()`, `updateAutoPlayAfterStreamsChanged()`, and call the latter from `presentStreamGroup`'s update path and the post-debrid-availability update path (same call sites as upstream's diff, adjusted for whatever local divergence exists in this file vs. composeApp's — diff line-by-line, don't blind-copy, since this file has picked up fork-only changes in past ports).
3. Port `composeApp/src/commonTest/kotlin/com/nuvio/app/features/streams/StreamAutoPlayLoadingPolicyTest.kt` into `shared/src/commonTest/kotlin/com/nuvio/app/features/streams/` (4 test cases, no platform-specific code — should move verbatim).
4. Run jvmTest + tvosSimulatorArm64Test; smoke-test on device: start playback with auto-play set to "installed addons only" or "enabled plugins only" and confirm it doesn't fire against an out-of-scope source, and doesn't hang if the in-scope source resolves fast while an out-of-scope one is still loading.

### `92466c4e` — align mobile control icons with tv. **Not applicable.**

Adds two new drawables (`ic_player_episodes.xml`/`.svg`,
`ic_player_source.xml`/`.svg`) to `composeApp/src/androidMain/res/drawable/`
and `composeApp/src/commonMain/composeResources/drawable/`, wires them into
`AppIconPainter.kt`/`.android.kt`/`.ios.kt`, and swaps two icon references in
`composeApp/.../player/PlayerControls.kt` — this is upstream's **mobile**
Compose player UI adopting icon styling that (per the commit message) tvOS's
native player already uses. Nothing to port; tvOS is the reference here, not
the target.

### `9b09045f` — allow minimum device brightness. **Not applicable.**

Widens the coercion range for the mobile player's swipe-to-adjust-brightness
gesture from `0.02f..1f` to `0f..1f` (and the Android system-brightness
read-back from `1..255` to `0..255`) in
`composeApp/src/androidMain/.../PlayerPlatformEffects.android.kt` and
`composeApp/src/iosMain/.../PlayerPlatformEffects.ios.kt` — so a mobile user
swiping brightness all the way down can reach true zero instead of getting
stuck at a 2% floor. This is `composeApp/`-only mobile gesture-controller
code (`UIScreen.mainScreen.brightness` on iOS, `Window.attributes.screenBrightness`
on Android) with no tvOS equivalent — Apple TV has no display-brightness API
to gesture-control (output goes to a connected TV/monitor, not a
brightness-adjustable screen). Grepped `shared/` and `iosApp/NuvioTV/` for
"brightness" — the only hits are subtitle-styling and SwiftUI `Color`
brightness modifiers, unrelated. Confirmed no port needed.

## Verification notes

- Fetched `upstream/cmp-rewrite` fresh this run (`312d499e..9b09045f`,
  fast-forward, no merge conflicts on the remote-tracking ref).
- All three commits read via full `git show`, not commit messages alone.
- The one action item (`58864ec1`) was confirmed unported by grepping
  `shared/src/commonMain/kotlin/com/nuvio/app/features/streams/StreamsRepository.kt`
  for the pre-refactor call-site pattern (5x `selectAutoPlayStream` + 1x
  `evaluateAutoPlayStream`, matching the messy pre-fix shape) rather than
  trusting the prior run's notes.
- Confirmed tvOS live consumption path via grep:
  `StreamsViewModel.swift` and `NextEpisodeAutoPlay.swift` both reference
  shared `StreamsRepository`.
- No new upstream-report candidates this run. The four still unfiled from
  2026-08-30 (Simkl precedence, FNV size-prefixing, `CatalogRepository`
  harder guard, TMDB `putIfAbsent`→`getOrPut`) remain unfiled.

## Carried open items (unchanged from 2026-09-01)

- Device pass owed for `claude/upstream-batch7` (merged into
  `tvos-shared-extraction` at `a87ab03f` on 2026-09-02) — anime skip chip,
  AIOMetadata season posters, Search during cold-start manifest load, Menu
  on the up-next chip (both player engines).
- Device pass owed for `claude/upstream-batch6` (`437a331f`) and
  `claude/subtitle-engine` (`716c18ea`), both merged 2026-08-28.
- Merge decision owed for `claude/sync-reliability` (`9221cc5d`, unpushed).
- Supporter perks v1 — parked by product decision 2026-08-20.
- Subtitle minimum font size — deferred by product decision 2026-08-20.

## OUTCOME ADDENDUM — same-day session, 2026-09-02 (upstream batch 8)

Submodule branch `claude/upstream-batch8` off `tvos-shared-extraction` @ `a87ab03f`, two commits, tip `3b140cc7`, pushed. Merge into `tvos-shared-extraction` + pointer bump: Christian's call.
The one action item (`58864ec1`, auto-play source loading scope, #1825) — PORTED, plus the tvOS-side
half the daily check did not see.

**What the exploration corrected about this run's note.** The shared `StreamsRepository` auto-play
region was byte-identical to upstream's parent, so the 280-line refactor applied with a path rewrite
only (903 → 761 lines, zero leftovers of the old five-call-site shape) and the new
`StreamAutoPlayLoadingPolicyTest` (4 cases) ports verbatim into `shared/src/commonTest`. BUT the
"live-relevant to tvOS" claim was wrong for that file: tvOS's stream picker always calls
`load(…, manualSelection = true)`, so `isDirectAutoPlayFlow` is always false here and the whole
refactored block is inert on this platform — Swift reads only `groups`/`isAnyLoading`/
`emptyStateReason`. The tvOS-visible half of #1825 lives in `NextEpisodeAutoPlay.handleStreams`
(the up-next engine, fed by `PlayerStreamsRepository`, with its own Swift selection loop): while
`isAnyLoading` it only accepted a same-binge-group match regardless of the configured
`StreamAutoPlaySource`, so an in-scope source that had finished sat waiting on an out-of-scope one
until the soft timeout.

**Fork deviations (both in service of the Swift half):**
- `areAutoPlaySourcesLoaded` is public (upstream `internal`) so SharedCore exports it.
- New `StreamsUiState.installedAddonIds`, published by `StreamsRepository` and
  `PlayerStreamsRepository` from the id set they already compute — the fork's group ids are
  `streamAddonInstanceId(manifest.id)` (BUG-33 duplicate disambiguation), so Swift cannot re-derive
  them from manifests.
- `NextEpisodeAutoPlay`: once every in-scope group has finished, the full selection runs immediately
  (a miss is terminal — the selector already filters by scope); with the default ALL_SOURCES scope
  this is exactly the old `!isAnyLoading`. Also fixed in passing: the selector was handed EVERY group
  as an "installed addon" (`Set(groups.map { $0.addonName })`), so INSTALLED_ADDONS_ONLY let plugin
  streams through and ENABLED_PLUGINS_ONLY matched nothing; it now uses the repository's installed
  ids. The effective-source rule (MANUAL mode + next-episode/binge → ALL_SOURCES) lives in one helper
  shared by the policy check and the selector.

**Codex:** settled at round 3 (r1 + r2 one P2 each, both fixed; r3 clean). r1 (1× P2, fixed): my empty-`installedAddonIds` fallback to "all groups are
addons" would have misclassified a legitimate plugin-only fan-out — the set is authoritative now.
r2 (1× P2, fixed): the synthetic `embedded` streams group was published with no installed ids, so
the new classification would have treated embedded episode streams as plugin streams; both
repositories now publish `installedAddonIds = setOf("embedded")` for that path (they come from the
installed meta addon, which is what the old all-groups set implied).

**Gates:** `:shared:jvmTest` 597 / `:shared:tvosSimulatorArm64Test` 617 (4 new), Debug + Release
simulator builds green (Debug 1m40, Release 4m25) on the final tree. No sim smoke is possible for the changed path from the UI: tvOS has no
Settings row for the auto-play source (it is whatever mobile/cloud sync last wrote, default
ALL_SOURCES), so the scope branches are exercisable only with a synced non-default value; the shared
policy is unit-tested and the ALL_SOURCES path reduces to the previous behaviour.

**Device pass owed** (only meaningful with a non-default scope synced from mobile): set
"Installed addons only" on mobile, on tvOS let an episode run into the up-next countdown with a
slow plugin enabled — the next episode should be picked as soon as the addons finish, not at the
timeout; with "Enabled plugins only", addon streams must not be picked.

**Not applicable, confirmed:** `92466c4e` (mobile icons aligned TO tvOS) and `9b09045f` (mobile
brightness gesture floor).

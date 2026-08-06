# Upstream port check — 2026-07-30 (scheduled)

## Result: no action items today

`upstream/cmp-rewrite` (NuvioMedia/NuvioMobile, the branch previously tracked) has **not moved** since the 2026-07-29 check — tip is still `979d5680` "Merge branch 'library-delta' into cmp-rewrite". Nothing new to diff or port from the branch that matters.

**Confirmed landed in the fork** (all three items from the 07-29 plan, verified present in `shared/` on the fork's current submodule HEAD `b941de1e`):
- Device session registration — `shared/src/commonMain/kotlin/com/nuvio/app/core/auth/DeviceSessionRegistration.kt` (+ apple/android actuals)
- Library incremental delta sync — `shared/src/commonMain/kotlin/com/nuvio/app/features/library/LibrarySyncReconciler.kt`
- Auth error sanitization — `safeAuthErrorDescription()` present at both call sites in `AuthRepository.kt`

Outer repo also has a pointer commit confirming this: `731353e "pointer: upstream port 2026-07-29 implemented — device sessions, library delta sync, auth error sanitization"`.

No Claude Code action needed for `cmp-rewrite` this cycle.

## Watch item (not actionable yet): `simkl` feature branch

Upstream has a long-running, still-actively-developing branch `upstream/simkl` (70 commits ahead of the `979d5680` merge-base with `cmp-rewrite`, latest commit `e4911b77` dated **today**, 2026-07-30 — "fix(simkl): preserve posters during library updates"). It is **not merged into `cmp-rewrite`** and is still receiving bugfix commits daily, so treat it as unstable/in-flux, not a stable port target.

**What it is:** a full Simkl tracking-provider integration (anime tracking, PKCE OAuth, watch-progress/scrobble sync) built on top of a new generalized "tracking provider" abstraction layer that also refactors the existing Trakt integration to sit on the same interfaces. Scope is large: 101 files changed, +9714/-1985 lines vs. the merge-base, touching:
- New: `features/tracking/{TrackingMedia,TrackingProvider,TrackingReads,TrackingScrobbleCoordinator,TrackingSettings,TrackingSources,TrackingWrites}.kt` — the new provider-neutral abstraction
- New Simkl provider files (auth, library, scrobble — mirrors the Trakt file layout)
- Rewritten: `TraktAuthRepository.kt`, `TraktScrobbleRepository.kt`, `TraktSettingsRepository.kt` adapted onto the new interfaces; new `TraktTrackingLibraryProvider.kt` / `TraktTrackingProgressProvider.kt` adapters
- Heavily rewritten: `WatchedRepository.kt` (+465/-?), `WatchProgressRepository.kt` (416 lines touched), `WatchProgressSourceCoordinator.kt`, plus new `WatchProgressMetadataProjection.kt`, `WatchProgressSourceProjection.kt`

**Why not porting now:** (1) not merged upstream yet — could still be rebased/restructured before it lands on `cmp-rewrite`; (2) it rewrites the Trakt provider tvOS already ported ([[nuvio-tvos-upstream-catchup]] notes Trakt per-profile auth isolation landed as `8a287b31`) — porting now risks redoing that work twice if upstream's abstraction shifts again; (3) 9.7k-line diff is too large to hand-port piecemeal without a stable target.

**Trigger to revisit:** either (a) `simkl` merges into `cmp-rewrite` (check via `git merge-base upstream/simkl upstream/cmp-rewrite` — currently `979d5680`; once that equals `simkl`'s tip, it's merged), or (b) the branch goes quiet for several days (a proxy for it stabilizing) — whichever comes first. If Christian wants Simkl support (Trakt-equivalent competitor, adds anime tracking via MAL/Kitsu ID resolution) sooner regardless of upstream's merge status, that's a product decision for him to make, not something to infer from this check.

## Other upstream branches checked, confirmed not relevant

- `upstream/copilot/refactor-project-structure` — exists but not inspected this run; name suggests a structural refactor branch, not a feature; will inspect if it merges to `cmp-rewrite`.

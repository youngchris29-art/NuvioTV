# Upstream port check — 2026-08-06 (scheduled)

## Headline: one real feature gap to port. Both bugs flagged on 2026-08-05 are confirmed landed.

Fork state checked this run: submodule `NuvioMobile` HEAD on `tvos-shared-extraction` (outer repo ahead 12 commits of `origin/tvos-shared-extraction`, working tree otherwise clean).

`upstream/cmp-rewrite` (NuvioMedia/NuvioMobile) moved from `ba5fb0df` (2026-08-05, last check) to `5601421f` (2026-08-06) — only **2 commits**, both part of one feature: `24971f4a` "feat(sync): sync provider credentials across clients" + its merge commit. Quiet day upstream; today's check is almost entirely about this one feature.

---

## Confirmed landed since last check (no action needed)

Both 2026-08-05 action items are verified fixed in the fork's current `shared/` source:

- **Item 1 (next-up release-day bug)** — `shared/.../features/watching/domain/WatchingPolicies.kt:56-63` now has the split branch (`if (daysUntilRelease <= 0) return true` / `if (!showUnairedNextUp) return false`) matching upstream `257e8060`. Confirmed via direct read.
- **Item 2 (Simkl anime-movie watched checkmarks)** — `isMovieEntry()` exists in `SimklSyncModels.kt` and is used throughout `SimklProjections.kt`. `SimklScrobbleReconciliation.kt` uses an equivalent (and per the in-file comment, Codex-reviewed and *hardened past* upstream's version) `isAnimeMovieEvidence()` check rather than a literal `isMovieEntry()` call, but covers the same cases. Matches the 2026-08-05 memory note that this landed same-day via commits `89369c95`/`91ddd802`.

No re-verification needed on these two next time.

---

## Action item (port this): Provider credential sync across devices (TMDB / MDBList / debrid / AnimeSkip / IntroDB API keys)

**Upstream commit:** `24971f4a` on `cmp-rewrite`, merged as `5601421f`.

**What it does:** upstream split provider API-key credentials (TMDB, MDBList, three debrid providers, AnimeSkip client ID, IntroDB API key) out of the general profile-settings sync blob into a dedicated `ProviderCredentialSync` system with its own Supabase RPCs and proper merge semantics. Previously (and still true in this fork today) these keys travel inside the same JSON blob as theme/player/UI settings via `ProfileSettingsSync`, which does a signature-diff push/pull with no per-field merge logic — a stale or empty value from one device can blank out a good key set on another. The new path pushes/pulls credentials independently, keyed by provider, and never lets a null remote value clobber a present local one.

**Why this matters for tvOS specifically:** Christian's tvOS build and any mobile install share the same profile settings sync. Today, setting a TMDB/MDBList/debrid key on tvOS (or on mobile) rides the general settings blob — the exact class of bug this upstream commit exists to fix. Porting it both fixes a latent correctness risk and gives tvOS real cross-device credential sync it doesn't have today (Trakt is untouched by this — confirmed no `trakt` references anywhere in the new upstream files, so tvOS's intentionally-diverged `TraktCredentialSync.kt`, kept since the 2026-07-07 token-bricking incident, needs no changes and is not in scope here).

**Files to add (new, copy from upstream then adjust package path from `composeApp` to the fork's `shared` module — all consuming classes already exist identically in `shared/`, verified this run):**

1. `shared/src/commonMain/kotlin/com/nuvio/app/core/sync/ProfileSettingsCredentialPolicy.kt` — new file. Defines `PROFILE_PLAYER_SETTINGS_FEATURE` / `PROFILE_DEBRID_SETTINGS_FEATURE` / `PROFILE_TMDB_SETTINGS_FEATURE` / `PROFILE_MDBLIST_SETTINGS_FEATURE` constants + `withoutProfileCredentials(feature, payload)` (strips credential keys before push) + `preservingLocalProfileCredentials(feature, remotePayload, localPayload)` (keeps local credential values intact when applying a remote settings blob). ~47 lines upstream, no dependencies outside `kotlinx.serialization.json`.
2. `shared/src/commonMain/kotlin/com/nuvio/app/core/sync/ProviderCredentialModels.kt` — new file. `ProviderCredentialIds` (TMDB/MDBLIST/ANIMESKIP/INTRODB constants + `debrid(providerId)` helper), `ProviderCredentialValue`, `ProviderCredentialSnapshot` (with `mergeRemote`), `SupabaseProviderCredential` DTO. ~61 lines, straightforward port.
3. `shared/src/commonMain/kotlin/com/nuvio/app/core/sync/ProviderCredentialSync.kt` — new file, the main object. ~316 lines. Observes `DebridSettingsRepository.uiState` / `TmdbSettingsRepository.uiState` / `MdbListSettingsRepository.uiState` / `PlayerSettingsRepository.uiState`, debounces 500ms, pushes/pulls via 3 new Supabase RPCs (`sync_seed_provider_credentials`, `sync_push_provider_credentials`, `sync_pull_provider_credentials`). All the repository methods it calls (`DebridSettingsRepository.setProviderApiKey`/`snapshot()`, `TmdbSettingsRepository.setApiKey`/`snapshot()`, `MdbListSettingsRepository.setApiKey`/`snapshot()`, `PlayerSettingsRepository.setAnimeSkipClientId`/`setIntroDbApiKey`) **already exist verbatim in this fork's `shared/`** — confirmed this run by grep, no adaptation needed there. Main port risk is import paths (`com.nuvio.app.core.auth.AuthRepository`, `com.nuvio.app.core.network.SupabaseProvider`, `com.nuvio.app.features.profiles.ProfileRepository` — all should resolve unchanged in `shared/`) and the `kotlinx.atomicfu.locks.SynchronizedObject`/`synchronized` pattern (already used elsewhere in this fork's `SyncManager.kt`, so the dependency is already on the classpath).

**Files to modify:**

4. `shared/src/commonMain/kotlin/com/nuvio/app/core/sync/ProfileSettingsSync.kt` — wrap the four credential-bearing `exportToSyncPayload()` calls (`playerSettings`, `debridSettings`, `tmdbSettings`, `mdbListSettings`) in `withoutProfileCredentials(...)` on push, and wrap the corresponding `replaceFromSyncPayload(...)` calls in `preservingLocalProfileCredentials(...)` on apply (capturing local state — `PlayerSettingsStorage.exportToSyncPayload()` / `.loadIntroDbApiKey()`, `DebridSettingsStorage.exportToSyncPayload()`, `TmdbSettingsStorage.exportToSyncPayload()`, `MdbListSettingsStorage.exportToSyncPayload()` — *before* the pull overwrites it). Also call `ProviderCredentialSync.startObserving()` / `.clearAccountState()` from this file's own `startObserving()`/`clearAccountState()`. Exact before/after is in upstream commit `24971f4a`, diff `ProfileSettingsSync.kt` directly rather than retyping — the credential-preserving pattern repeats 4x with slightly different local var names each time.

   ⚠️ **Divergence to preserve while porting:** this fork's `ProfileSettingsSync.kt` already carries fork-specific fixes not in upstream — the BUG-20 legacy-platform migration (`seedFromLegacyPlatformsLocked`) and the "only apply feature blocks present in remote JSON" guard in `applyRemoteBlob` (upstream doesn't have either; see the docstring above `applyRemoteBlob` in the current file). Merge the credential-stripping/preserving logic into the fork's existing structure — do not replace the file wholesale with upstream's version, or both of those fork-only fixes will be lost.

5. `shared/src/commonMain/kotlin/com/nuvio/app/core/sync/SyncManager.kt` — add `ProviderCredentials` to the `ProfileSyncStep` enum (after `ProfileSettings`, before `Library` — ordering matters, credentials must land before the library/watch-source steps that may read them), add `syncProviderCredentials: suspend (Int) -> Unit` to `ProfileSyncOperations`, wire `runStep(ProfileSyncStep.ProviderCredentials, operations.syncProviderCredentials)` right after the existing `ProfileSettings` step in `runOrderedProfileSync`, and add the operation to the `profileSyncOperations` val in the `SyncManager` object (`syncProviderCredentials = { profileId -> ProviderCredentialSync.syncFromRemote(profileId) }`). Also add the equivalent call into `pullForegroundForProfile()`'s sequential preamble (alongside the existing `ProfileSettingsSync.pull(profileId)` call — see how upstream's `SyncManagerTest.kt` asserts credentials land before `library`/`active-watch-source` in both the ordered-sync and foreground-pull paths).

**Tests:** upstream added `ProfileSettingsCredentialPolicyTest.kt`, `ProviderCredentialModelsTest.kt` (both new, straightforward ports — pure logic, no platform deps), and extended `SyncManagerTest.kt` with `credentialsApplied`/`"credentials"` event assertions. This fork's `SyncManager.kt` has no existing `SyncManagerTest.kt` twin under `shared/src/commonTest/` yet (only `composeApp/src/commonTest/kotlin/com/nuvio/app/core/sync/SyncManagerTest.kt` exists, testing the composeApp copy) — worth adding one under `shared/src/commonTest/kotlin/com/nuvio/app/core/sync/` while doing this port, mirroring upstream's updated assertions, since `shared/`'s `SyncManager.kt` is what tvOS actually runs.

**Backend dependency:** the 3 new RPCs (`sync_seed_provider_credentials`, `sync_push_provider_credentials`, `sync_pull_provider_credentials`) aren't documented in this repo's `docs/nuvio-cloud-api-reference.md` yet. Since tvOS shares the same Supabase project as the official mobile app, these should already exist server-side once upstream's backend migration ships — but this needs a live check (call `syncFromRemote` in a debug build and confirm it doesn't 404/42883 "function does not exist") before shipping, and the API reference doc should get a new section once confirmed.

**Suggested verification after porting:** exercise the 4-slice `verify` command from `nuvio-tvos-build-setup` memory; add a manual test setting a TMDB key on tvOS, confirming a Supabase row appears, then confirm it round-trips (simulate a "remote wins" case with a non-empty debrid key already set locally — should NOT get blanked, per the whole point of this fix).

---

## Checked, not applicable

Nothing else changed upstream this run — the 2-commit window was entirely this one feature.

---

## Next scheduled check

Verify the provider-credential-sync port landed (`grep -rl "ProviderCredentialSync" shared/`); re-fetch `upstream/cmp-rewrite` and diff past `5601421f`.

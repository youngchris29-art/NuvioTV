# Upstream port check — 2026-08-07 (scheduled)

## Headline: one trivial 1-line fix to port. Everything from 2026-08-06 is confirmed landed.

Fork state checked this run: outer repo `main` at `bc83b4e` (clean except unrelated doc-file edits + submodule pointer). Submodule `NuvioMobile` HEAD `b8c4e60c` on `tvos-shared-extraction`.

`upstream/cmp-rewrite` (NuvioMedia/NuvioMobile) moved from `5601421f` (2026-08-06, last check) to `3ac0a14c` (2026-08-07) — only **1 commit**. Quietest day yet upstream.

`upstream/copilot/refactor-project-structure` still stale at `cbc9fc4f` — no new commits, still abandoned, no action.

---

## Confirmed landed since last check (no action needed)

- **Provider credential sync (2026-08-06 action item)** — fully ported. `shared/src/commonMain/kotlin/com/nuvio/app/core/sync/ProviderCredentialSync.kt` and `ProfileSettingsCredentialPolicy.kt` both exist, `SyncManager.kt` references `ProviderCredentialSync`. Landed via fork commit `c90d3e71` "feat(sync): provider credential sync (upstream 24971f4a) + hardened migration". Backend RPC gate also confirmed met per the fork's own doc commits (`ad1e6da` "tracker — credential RPC gate met (all three exist, signatures match)", `6b4503a` "docs: API reference — Provider Credentials section (3 RPCs)"). No re-check needed on this item going forward.

---

## Action item (port this): Simkl library poster resolution — wrong image-size suffix

**Upstream commit:** `3ac0a14c` "fix(simkl): update library poster res" on `cmp-rewrite`.

**What it does:** one-line fix in `simklPosterUrl()` — the wsrv.nl-proxied poster URL was built with the `_ca.webp` size suffix; upstream changed it to `_m.webp`. (`_ca` looks to be a stale/incorrect Simkl CDN size code; `_m` is presumably "medium," the correct one — no further explanation in the upstream commit message, but it's a deliberate, tested change, not a typo: the paired unit test assertions were updated in the same commit.)

**Why this matters for tvOS specifically:** the affected file, `SimklProjections.kt`, lives in **`shared/`** in this fork (migrated there during the original extraction — confirmed still present, unchanged, at `shared/src/commonMain/kotlin/com/nuvio/app/features/simkl/SimklProjections.kt:332-337`, still reads `_ca.webp`). Simkl shipped to tvOS on 2026-08-04 ([[nuvio-tvos-upstream-catchup]]), so this is a live, shipped code path — any Simkl library poster/backdrop tvOS renders today is requesting the `_ca` size variant instead of `_m`. Low severity (cosmetic/possibly-broken-image risk, not a crash or data-loss bug) but trivial to fix, so no reason to defer.

**File to modify:**

`shared/src/commonMain/kotlin/com/nuvio/app/features/simkl/SimklProjections.kt` — line 337:

```kotlin
// before
?.let { normalized -> "https://wsrv.nl/?url=https://simkl.in/posters/${normalized}_ca.webp&q=90" }

// after
?.let { normalized -> "https://wsrv.nl/?url=https://simkl.in/posters/${normalized}_m.webp&q=90" }
```

**Tests to update (same commit upstream):**

`shared/src/commonTest/kotlin/com/nuvio/app/features/simkl/SimklProjectionsTest.kt` — 2 assertions reference the old suffix and need the same swap:
- line 73: `assertTrue(item.poster.orEmpty().contains("simkl.in/posters/12/poster_ca.webp"))` → `poster_m.webp`
- line ~212 (second occurrence, same assertion pattern for a library entry): `assertTrue(entry.poster.orEmpty().contains("simkl.in/posters/12/poster_ca.webp"))` → `poster_m.webp`

No other files reference `_ca.webp` or `simklPosterUrl` in the fork (checked via repo-wide grep) — this is a fully self-contained, mechanical port. `shared/src/commonTest/kotlin/com/nuvio/app/features/simkl/SimklSyncEngineTest.kt:339` also calls `simklPosterUrl("12/canonical")` but only checks it returns non-null/the general shape — verify it doesn't hardcode `_ca` too before assuming it's untouched.

**Suggested verification after porting:** run the 4-slice `verify` command from `nuvio-tvos-build-setup` memory (`./gradlew :shared:compileKotlinIosSimulatorArm64 :shared:linkDebugFrameworkTvosSimulatorArm64 :composeApp:compileKotlinIosSimulatorArm64 :composeApp:iosSimulatorArm64Test -Pnuvio.android.distribution=full`); optionally open a Simkl-linked profile on device/sim and confirm library posters still load (should look identical or better — this is a CDN size-variant swap, not a URL-shape change, so a broken image would indicate `_m` isn't a valid Simkl CDN suffix and the port should be reverted pending upstream investigation).

---

## Checked, not applicable

Nothing else changed upstream this run — the 1-commit window was entirely this fix. `upstream/simkl` branch ref no longer resolves on `git fetch` (likely deleted post-merge, consistent with Simkl work having fully landed upstream weeks ago per the 2026-08-04 check) — not a problem, just noting the branch is gone so future runs shouldn't try to diff it.

---

## PORTED — 2026-08-07 (same day)

Landed as fork commit `d8c06127` (pushed). 4-slice verify green including `:composeApp:iosSimulatorArm64Test`. Outer pointer bumped in the same session. Next check only needs to diff upstream past `3ac0a14c`.

## Next scheduled check

Verify this Simkl poster-suffix fix landed (`grep -n "_ca.webp" shared/src/commonMain/kotlin/com/nuvio/app/features/simkl/SimklProjections.kt` should return nothing); re-fetch `upstream/cmp-rewrite` and diff past `3ac0a14c`.

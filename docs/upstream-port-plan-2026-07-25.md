# Upstream Port Plan — 2026-07-25

**Task:** Port two upstream changes from `upstream/cmp-rewrite` into this fork's `shared/` module. This document is self-contained — implement it top to bottom.

## Context (read first)

- This repo is a tvOS port of NuvioMobile (Kotlin Multiplatform). The `NuvioMobile/` submodule contains the KMP code; app logic was extracted into `NuvioMobile/shared/src/commonMain` (branch `tvos-shared-extraction`), consumed by a **native SwiftUI tvOS app** — there is no Compose UI on tvOS.
- Anything in upstream's `composeApp/` (Compose UI, Android resources, drawables) is **not portable and not needed**. Only changes that map into files under `shared/` matter.
- Upstream remote: `upstream`, branch `cmp-rewrite`. As of 2026-07-24 its tip was `755f6ff9`; merge-base with the fork is `94b88483`. A scheduled check on 2026-07-24 identified exactly **two** unported items (verified by grepping the fork's files — details below). Re-verify they're still unported before starting (someone may have ported them since).

## Item 1 — Trakt per-profile auth isolation bugfix (priority: this is a real bug)

Upstream commit `05a5f9d7` "fix: per-profile isolation for Trakt auth and storage".

**Bug being fixed:** `TraktAuthRepository` has a single `hasLoaded` flag, and `TraktAuthStorage.loadPayload()`/`savePayload()` take no profileId — one Trakt auth blob is shared across all profiles via a single NSUserDefaults key. On a multi-profile Apple TV, switching profiles can read/write/clobber the wrong profile's Trakt credentials.

**The fix (mirror the upstream commit's pattern):**
1. `git show 05a5f9d7` in `NuvioMobile/` to get the exact upstream diff — treat it as the spec.
2. Thread `profileId` through `TraktAuthRepository`: `ensureLoaded`/`onProfileChanged`/`loadFromDisk`/`persist` (currently bare, no params — confirmed at `shared/src/commonMain/kotlin/com/nuvio/app/features/trakt/TraktAuthRepository.kt`).
3. Scope the storage key via `ProfileScopedKey.of(payloadKey, profileId)` in the storage layer.
4. Update the `TraktAuthStorage` expect + **all actuals**: the appleMain actual `TraktAuthStorage.apple.kt` (this single file covers BOTH iOS and tvOS — it's what the tvOS app actually links against; do not miss it) and the android actual (needed for compile parity only).
5. Update call sites: `ProfileRepository.kt`, `WatchedRepository.kt`, `SyncManager.kt`, `LibraryRepository.kt` (all under `shared/src/commonMain`).

Note: file paths in the upstream diff are under `composeApp/`; the fork's copies live under `shared/src/commonMain` (and may have drifted slightly). Locate each corresponding fork file and hand-translate — do not blind-apply the patch.

## Item 2 — MyAnimeList (MAL) rating provider (small additive feature)

Upstream commit chain `a8e64fdf` → `755f6ff9` (PR #1591). The shared-relevant change is tiny and backward-compatible:

1. `MdbListMetadataService`: add `PROVIDER_MAL = "mal"` and add it to `PROVIDER_PRIORITY_ORDER`.
2. `MdbListSettings`: add `useMal: Boolean = true` (default true — no breaking constructor change).
3. Thread the new setting through `MdbListSettingsRepository.kt` and `MdbListSettingsStorage.kt` + its `.ios.kt`/`.android.kt` actuals, mirroring how the existing `use*` toggles are persisted.

**Skip** the other 6 commits in the chain — they're Compose-UI icon churn (rating badge SVG→PNG iterations) for Android/desktop. tvOS needs no Swift changes: `DetailView.swift` renders `meta.externalRatings` generically, so MAL scores appear automatically once the shared change lands.

## Suggested execution (model/token efficiency)

- Item 1: delegate to a **sonnet** subagent with the upstream diff as spec (mechanical multi-file translation; no design work needed).
- Item 2: delegate to a **haiku** subagent — hand it the exact upstream diff and the fork file paths above.
- Review + build verify: main session.

## Review checklist (before building)

- `profileId` threaded through every path — no stale single-slot `hasLoaded`/unscoped-key path left behind.
- The appleMain actual (`TraktAuthStorage.apple.kt`) got the profileId param — this is the one tvOS links; the port is worthless without it.
- No `composeApp`-only references (Compose imports, Android resources) leaked into `shared/`.
- MAL: `useMal` defaults to `true` and constructor stays backward-compatible.

## Build verify (run from `NuvioMobile/`)

```bash
./gradlew clean :shared:compileKotlinIosSimulatorArm64 \
  :shared:linkDebugFrameworkTvosSimulatorArm64 \
  :composeApp:compileKotlinIosSimulatorArm64 \
  -Pnuvio.android.distribution=full
```

Then the device-slice relink (Xcode won't see new/changed symbols without it; missing-symbol errors after a shared/ change almost always mean a stale framework, not broken code):

```bash
./gradlew :shared:linkDebugFrameworkTvosArm64 -Pnuvio.android.distribution=full
```

JDK 17 required (Homebrew openjdk@17 — the Xcode run-script hardcodes `/opt/homebrew/opt/openjdk@17`).

## Commits

Two **separate** commits in `NuvioMobile/` (plus the outer-repo submodule bump if that's the usual flow):
1. `fix: per-profile isolation for Trakt auth and storage (port upstream 05a5f9d7)`
2. `feat: MAL rating provider (port upstream a8e64fdf, PR #1591)`

Do not push unless asked.

## Left for Christian (on-device, after the build is green)

- Trakt isolation test: auth Trakt on profile A → switch to profile B → confirm B shows logged-out (not A's account) → auth B → switch back → confirm A's auth intact.
- MAL test: open an anime title's detail page → confirm a MAL score appears in the ratings row.

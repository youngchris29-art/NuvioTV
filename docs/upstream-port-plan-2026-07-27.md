# Upstream Port Plan — 2026-07-27

**✅ IMPLEMENTED 2026-07-29** as Item 1 of the 2026-07-29 port batch (see `docs/upstream-port-plan-2026-07-29.md`). `DeviceSessionRegistration.kt` (commonMain + appleMain + androidMain actuals) + both Swift call sites (AuthViewModel sign-in transition with `force: true` — guarded on gate AND prior anonymity so guest→account upgrades register immediately; ContentView foreground, self-throttled). `register_current_device` RPC confirmed live on the backend. Device test pending.

*Prior status 2026-07-28 (re-verified by scheduled check, no changes needed):* Still open. Upstream `cmp-rewrite` tip is unchanged (`88d3cbdf`, same as 2026-07-27) — no new upstream commits to consider. `find NuvioMobile/shared -iname "*DeviceSessionRegistration*"` still returns empty, confirming Item 1 below has not been ported yet. This plan is still accurate top to bottom; nothing to re-derive.

**Task:** Port one upstream change from `upstream/cmp-rewrite` into this fork's `shared/` module (+ a small Swift call site). This document is self-contained — implement it top to bottom.

## Context (read first)

- This repo is a tvOS port of NuvioMobile (Kotlin Multiplatform). The `NuvioMobile/` submodule contains the KMP code; app logic was extracted into `NuvioMobile/shared/src/commonMain` (branch `tvos-shared-extraction`), consumed by a **native SwiftUI tvOS app** — there is no Compose UI on tvOS.
- Anything in upstream's `composeApp/` Compose UI, Android resources, or drawables is **not portable and not needed**. Only changes that map into files under `shared/` (or need a Swift call site) matter.
- Upstream remote: `upstream`, branch `cmp-rewrite`. Last scheduled check (2026-07-26) had upstream tip at `b6099532`. This check (2026-07-27) found tip moved to `88d3cbdf` — 8 new commits. Re-verify this item is still unported before starting (run the "Verify still needed" grep below — someone may have ported it since).

## Item 1 — Device session registration (`upstream` commits `b3f22a6b` + `8937dc7b`, merged via `19f216be` "Merge branch 'devices'")

**What it does:** a new Compose-free `DeviceSessionRegistration` object in `composeApp/src/commonMain/kotlin/com/nuvio/app/core/auth/` that calls a Supabase RPC (`register_current_device`) to register the current signed-in session against the account, so it shows up wherever Nuvio surfaces "your devices" / session management (tied to the same commit's Play Store account-deletion compliance work — `accountDeletionEnabled` flipped `true` for the Play flavor). It registers on auth-state settling and again on every foreground event (throttled to once per 15 minutes unless `force = true`).

**Why this is relevant to tvOS, not just mobile:** the fork's `SupabaseProvider` (`shared/src/commonMain/kotlin/com/nuvio/app/core/network/SupabaseProvider.kt`) points at the **same Supabase backend** the official app uses (see `[[nuvio-cloud-api]]` doc, `docs/nuvio-cloud-api-reference.md`). tvOS sessions authenticate against that same backend via the already-ported `AuthRepository`. Without this, a tvOS login never registers a device session — so any current or future "manage your devices" / session-revocation feature on the account side won't see (or won't let the user revoke) the Apple TV. All the Kotlin dependencies this needs are already ported to `shared/` (verified below), so this is a clean, low-risk addition.

**Verify still needed (run first):**
```
find NuvioMobile/shared -iname "*DeviceSessionRegistration*"   # should be empty
```
If it's not empty, this item is already done — stop here and check whether Item 2 (below) also landed already before re-flagging.

**Verified dependencies already exist in `shared/` (confirmed 2026-07-27, don't re-check unless the above grep surprises you):**
- `AuthRepository` + `AuthState` / `AuthState.Authenticated.isAnonymous` — `shared/src/commonMain/kotlin/com/nuvio/app/core/auth/{AuthRepository,AuthModels}.kt`
- `AppVersionConfig.VERSION_NAME` — generated into `shared/build/generated/runtime-config/kotlin/com/nuvio/app/core/build/AppVersionConfig.kt`
- `SupabaseProvider.client` — `shared/src/commonMain/kotlin/com/nuvio/app/core/network/SupabaseProvider.kt`
- `SyncClientIdentity.currentClientId()` — `shared/src/commonMain/kotlin/com/nuvio/app/core/sync/SyncClientIdentity.kt`

**Steps:**

1. `cd NuvioMobile && git show b3f22a6b` to see the exact upstream diff (also check `8937dc7b`, which is mostly Android manifest/compliance stuff — skip its Android-only parts). Treat the Kotlin as the spec.

2. Create `shared/src/commonMain/kotlin/com/nuvio/app/core/auth/DeviceSessionRegistration.kt` — port the file verbatim from upstream's `composeApp/src/commonMain/kotlin/com/nuvio/app/core/auth/DeviceSessionRegistration.kt` (shown in full below so you don't need to re-fetch it). One naming decision: upstream hardcodes `CLIENT_NAME = "Nuvio Mobile"` — change this to `"Nuvio tvOS"` so registered sessions are identified correctly per platform.

```kotlin
package com.nuvio.app.core.auth

import co.touchlab.kermit.Logger
import com.nuvio.app.core.build.AppVersionConfig
import com.nuvio.app.core.network.SupabaseProvider
import com.nuvio.app.core.sync.SyncClientIdentity
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.rpc
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlin.time.Duration.Companion.minutes
import kotlin.time.TimeMark
import kotlin.time.TimeSource

private const val CLIENT_NAME = "Nuvio tvOS" // was "Nuvio Mobile" upstream — identify this platform correctly
private val REGISTRATION_INTERVAL = 15.minutes

internal data class DeviceClientMetadata(
    val deviceName: String,
    val platform: String,
)

internal expect fun currentDeviceClientMetadata(): DeviceClientMetadata

object DeviceSessionRegistration {
    private val log = Logger.withTag("DeviceSessionRegistration")
    private val registrationMutex = Mutex()
    private var lastRegistration: TimeMark? = null

    suspend fun registerIfAuthenticated(force: Boolean = false): Boolean {
        val authState = AuthRepository.state.value as? AuthState.Authenticated ?: return false
        if (authState.isAnonymous) return false

        return registrationMutex.withLock {
            if (!force && lastRegistration?.elapsedNow()?.let { it < REGISTRATION_INTERVAL } == true) {
                return@withLock true
            }

            val metadata = currentDeviceClientMetadata()
            val params = buildDeviceRegistrationParams(
                installationId = SyncClientIdentity.currentClientId(),
                clientVersion = AppVersionConfig.VERSION_NAME,
                metadata = metadata,
            )

            try {
                SupabaseProvider.client.postgrest.rpc("register_current_device", params)
                lastRegistration = TimeSource.Monotonic.markNow()
                true
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                log.w(error) { "Device session registration failed" }
                false
            }
        }
    }
}

internal fun buildDeviceRegistrationParams(
    installationId: String,
    clientVersion: String,
    metadata: DeviceClientMetadata,
): JsonObject = buildJsonObject {
    put("p_installation_id", installationId)
    put("p_client_name", CLIENT_NAME)
    put("p_client_version", clientVersion)
    put("p_platform", metadata.platform)
    put("p_device_name", metadata.deviceName)
}

internal fun formatDeviceName(
    manufacturer: String,
    model: String,
    fallback: String,
): String {
    val normalizedManufacturer = manufacturer.trim()
    val normalizedModel = model.trim()

    return when {
        normalizedModel.isBlank() -> fallback
        normalizedManufacturer.isBlank() -> normalizedModel
        normalizedModel.startsWith(normalizedManufacturer, ignoreCase = true) -> normalizedModel
        else -> "$normalizedManufacturer $normalizedModel"
    }
}
```

3. Add the `appleMain` actual (single actual serves both iOS and tvOS, per the fork's established pattern — see `SyncClientIdentityStorage.apple.kt` for precedent). New file `shared/src/appleMain/kotlin/com/nuvio/app/core/auth/DeviceSessionRegistration.apple.kt`:

```kotlin
package com.nuvio.app.core.auth

import platform.UIKit.UIDevice

internal actual fun currentDeviceClientMetadata(): DeviceClientMetadata {
    val device = UIDevice.currentDevice
    val deviceName = device.name
        .trim()
        .ifBlank { device.localizedModel.trim() }
        .ifBlank { "Apple device" }
    val platform = "${device.systemName()} ${device.systemVersion}".trim()

    return DeviceClientMetadata(
        deviceName = deviceName,
        platform = platform,
    )
}
```
   Note: on tvOS, `UIDevice.currentDevice.name` typically returns a generic value like "Apple TV" rather than a user-assigned name (unlike iOS) — that's expected and fine, it's still meaningful device metadata. `UIDevice` is available on tvOS so this compiles and runs as-is; no tvOS-specific branch needed.

4. Skip the Android actual — this fork doesn't build for Android (per `[[nuvio-tvos-build-setup]]`, no Android SDK configured in Christian's env), but add it anyway for compile parity with the rest of the codebase's expect/actual convention IF other expects in `shared/androidMain` are consistently stubbed. Check one existing example (e.g. `SyncClientIdentityStorage.android.kt`) — if the convention is "always add the android actual even though it's unbuildable here," mirror upstream's `composeApp/src/androidMain/kotlin/com/nuvio/app/core/auth/DeviceSessionRegistration.android.kt` verbatim into `shared/src/androidMain/kotlin/com/nuvio/app/core/auth/DeviceSessionRegistration.android.kt`:

```kotlin
package com.nuvio.app.core.auth

import android.os.Build

internal actual fun currentDeviceClientMetadata(): DeviceClientMetadata {
    val deviceName = formatDeviceName(
        manufacturer = Build.MANUFACTURER.orEmpty(),
        model = Build.MODEL.orEmpty(),
        fallback = "Android device",
    )
    val osVersion = Build.VERSION.RELEASE.orEmpty()
        .trim()
        .ifBlank { Build.VERSION.SDK_INT.toString() }

    return DeviceClientMetadata(
        deviceName = deviceName,
        platform = "Android $osVersion",
    )
}
```

5. **Swift call site.** tvOS has no Compose `App()` to hook `LaunchedEffect` into, so this needs two small Swift additions mirroring upstream's two call sites (auth-state settle + foreground):
   - `NuvioMobile/iosApp/NuvioTV/Screens/AuthViewModel.swift`: in the `stateWatcher` callback (where `AuthState.Authenticated` is handled, see `func start()`), after the state settles to authenticated/non-anonymous, kick off `Task { await DeviceSessionRegistration.shared.registerIfAuthenticated(force: true) }`. Only needs to fire once per successful sign-in, not every emission — check how the existing watcher already distinguishes state transitions before adding.
   - `NuvioMobile/iosApp/NuvioTV/ContentView.swift`: in the existing `.onChange(of: scenePhase)` block (already calls `SyncManager.shared.requestForegroundPull(...)` on `newPhase == .active`), add a sibling call: `Task { await DeviceSessionRegistration.shared.registerIfAuthenticated() }` (no `force`, so it self-throttles to once per 15 min like upstream).
   - Kotlin `suspend fun` bridges to Swift as an `async` function callable from a `Task { }` — confirm the exact generated signature via Xcode autocomplete on `DeviceSessionRegistration.shared.registerIfAuthenticated` once the framework relinks; may need `try? await` or a completion-handler variant depending on how KMP exports `suspend fun` here (check how `AuthRepository.shared.initialize()` or another existing suspend call is bridged in this codebase for the established pattern — grep for `.registerIfAuthenticated\|await.*Repository.shared` isn't present yet, so look at how e.g. `addAddon(rawUrl:completionHandler:)`-style suspend bridging is handled elsewhere and pick the matching idiom).

6. Build verify (from `[[nuvio-tvos-build-setup]]`): `./gradlew clean :shared:compileKotlinIosSimulatorArm64 :shared:linkDebugFrameworkTvosSimulatorArm64 :composeApp:compileKotlinIosSimulatorArm64 :composeApp:iosSimulatorArm64Test -Pnuvio.android.distribution=full`, then relink BOTH slices before an on-device build: `./gradlew :shared:linkDebugFrameworkTvosArm64 :shared:linkDebugFrameworkTvosSimulatorArm64 -Pnuvio.android.distribution=full`.

7. Device test: sign in with a real (non-guest) Nuvio account on the Apple TV, confirm no crash/regression, and — if there's any way to inspect the `device_sessions`-equivalent table or an in-app "your devices" screen (mobile side) — confirm a "Nuvio tvOS" entry appears. If there's no visibility into the backend table, this is fine to ship without visual confirmation; the RPC call itself is the deliverable and failures are caught + logged, never surfaced to the user (see the `catch (error: Throwable)` in `registerIfAuthenticated`).

## Not applicable this run (composeApp/Android-only, confirmed via diffstat + file inspection)

- `19f216be`/`8937dc7b`'s `AndroidManifest.xml`, `AppFeaturePolicy.android.kt`, `PlayerEngine.android.kt`, `PlayerNowPlayingController.android.kt` changes — Android-only foreground-service/manifest compliance work, no `shared/` or Swift equivalent needed.
- `AppFeaturePolicy.kt` gained one new flag, `mediaPlaybackForegroundServiceEnabled` (Android foreground-service concept, doesn't exist on tvOS). **Optional, not required:** if you want the fork's `shared/core/build/FeaturePolicyProvider.kt` `FeaturePolicy` interface to stay a 1:1 mirror of upstream's `AppFeaturePolicy` for future-proofing, add `val mediaPlaybackForegroundServiceEnabled: Boolean` to the interface + `= false` to `DefaultFeaturePolicy`. Nothing currently reads this flag on tvOS, so skipping it is also fine — flagging as a nice-to-have, not a gap.
- `00cc0121`/`6f4c69f5` "clip CardDepthEffect sheen overlay to shape path" — `composeApp/src/commonMain/kotlin/com/nuvio/app/core/ui/CardDepthEffect.kt`, pure Compose Modifier, N/A to native SwiftUI.
- `a4e886fb`/`d5991c75`/`ec63003f` image-based subtitle rendering fixes — both changed files (`PlayerEngine.android.kt`, `PlayerNowPlayingController.android.kt`) are Android-only; tvOS's player is the separate MPVKit/libmpv Swift implementation, unaffected.
- `88d3cbdf` version bump, `iosApp/Configuration/Version.xcconfig` — mobile's own version file, not shared.

## Also not yet re-checked this run (no expected change, same as every prior check)

- MPVKit tags (last known: still `nuvio.2`, no `nuvio.3` as of 2026-07-25's check).
- The `simkl` branch (`44fc3fa6` → `26e7b23f` this fetch) — still not merged into `cmp-rewrite` mainline, out of scope until it merges.

## Suggested execution (model/token efficiency)

- Item 1 is one mechanical Kotlin port (spec given verbatim above, no design work) + one small Swift integration requiring a look at existing suspend-bridging idioms in this codebase. Sonnet tier, single session — the Swift bridging step needs judgment (picking the right async idiom), not appropriate for a haiku-tier blind port.
- Review + build verify + device test: main session, per the checklist in step 6–7 above.

# Nuvio tvOS Code Review Report

**Review date:** July 10, 2026  
**Target:** Current working tree under `NuvioMobile`, with emphasis on the native tvOS application, tvOS/Apple shared code, player integration, networking, plugins, persistence, and Xcode configuration  
**Review type:** Read-only static review; no application source files were changed  
**Review dimensions:** Security and privacy, functional correctness, lifecycle and concurrency, tvOS platform behavior, performance, accessibility, build configuration, and testing

## Executive summary

The review found one critical credential exposure and several high-impact security and correctness risks. The most urgent issue is a live-looking TorBox credential embedded in a Swift source file that can be compiled into the tvOS application. It should be revoked and rotated immediately.

The next priorities are the unauthenticated Remote Setup service, unsigned remotely updated plugin code, the global App Transport Security exception, Remote Setup lifecycle races, nested detail-navigation state races, unbounded decoded artwork caching, and a Release configuration that points to a debug Kotlin framework.

No source changes were made during this review.

| Severity | Count |
| --- | ---: |
| Critical | 1 |
| High | 7 |
| Medium | 7 |
| Low | 1 |
| Coverage/configuration notes | 2 |

## Recommended response order

1. Revoke and rotate the exposed TorBox credential.
2. Prevent `DebugConfig.swift` and its Quick Install behavior from entering production builds.
3. Authenticate Remote Setup and stop returning secret-bearing URLs.
4. Require integrity verification for remote plugin code and constrain plugin networking.
5. Remove the global ATS exception from Release builds.
6. Fix Remote Setup start/stop and failure cleanup.
7. Isolate detail-screen loads so one screen cannot clear another screen's request.
8. Correct the Release SharedCore framework path and add archive validation.
9. Bound and downsample artwork caching.
10. Add a native tvOS test target covering the critical lifecycle and navigation paths.

---

## Critical findings

### CR-001: Debrid credential embedded in compiled source

**Locations**

- `NuvioMobile/iosApp/NuvioTV/Screens/DebugConfig.swift:8-11`
- `NuvioMobile/iosApp/NuvioTV/Screens/AddonsView.swift:55-59`

**Description**

`DebugConfig.swift` warns against committing a real key but contains a populated TorBox manifest URL with a UUID-like debrid credential. `AddonsView` exposes a Quick Install button that submits this URL to the addon repository.

The file is ignored by Git, but it is present in the synchronized Xcode source tree. Being ignored does not prevent Xcode from compiling it. A credential compiled into the application can be recovered using ordinary application-string inspection, and anyone with access to the workspace can also read it directly.

**Impact**

- Unauthorized use of the associated TorBox account or quota.
- Credential leakage from a local, ad hoc, TestFlight, or production build.
- Accidental redistribution whenever a build is shared.

**Recommended remediation**

1. Revoke and rotate the credential immediately.
2. Clear the value from local source.
3. Remove the production-visible Quick Install path.
4. If this developer convenience is retained, compile it only under `#if DEBUG` and inject its value from an ignored, debug-only configuration that is not copied into the application bundle.
5. Add secret scanning to local checks and CI.

---

## High-severity findings

### HI-001: Remote Setup exposes secret-bearing configuration without authentication

**Locations**

- `NuvioMobile/iosApp/NuvioTV/Screens/RemoteSetupServer.swift:121-151`
- `NuvioMobile/iosApp/NuvioTV/Screens/RemoteSetupServer.swift:193-197`
- `NuvioMobile/iosApp/NuvioTV/Screens/RemoteSetupViewModel.swift:155-176`
- `NuvioMobile/iosApp/NuvioTV/Screens/AddonsView.swift:4-5`

**Description**

Remote Setup opens a plain TCP listener on predictable ports 8080 through 8089. Every LAN client can request `/api/state`; no session secret, bearer token, peer check, or pairing proof is required.

The state response contains complete addon manifest URLs and badge-pack source URLs. The application itself documents that addon URLs may contain debrid API keys.

On a guest, shared, or hostile LAN, another device can scan these ports and retrieve the configuration while Remote Setup is active.

**Impact**

- Theft of debrid credentials embedded in manifest URLs.
- Disclosure of installed addons, configuration, home rows, device name, and imported badge sources.
- Increased exposure when combined with the global cleartext-transport exception.

**Recommended remediation**

- Generate a high-entropy, single-session pairing secret and include it in the QR URL.
- Validate the secret on every route, including the landing page, state, apply, and status routes.
- Redact credentials, query values, and token-bearing path segments from all returned URLs.
- Expire the session automatically and stop listening when the setup screen closes or the app backgrounds.
- Consider authenticated local peer discovery or TLS rather than unauthenticated HTTP.

### HI-002: Remote Setup can resume listening after the user stops it

**Locations**

- `NuvioMobile/iosApp/NuvioTV/Screens/RemoteSetupServer.swift:78-85`
- `NuvioMobile/iosApp/NuvioTV/Screens/RemoteSetupServer.swift:116-151`
- `NuvioMobile/iosApp/NuvioTV/Screens/RemoteSetupViewModel.swift:85-95`

**Description**

`attemptStart` creates a local `NWListener` candidate but does not assign it to the server's `listener` property until the candidate reaches `.ready`. If the user presses Stop or navigates away before readiness, `stop()` sees `listener == nil` and cannot cancel the candidate.

The candidate can later become ready, store itself as the active listener, and invoke the completion handler. The view model can then republish the URL and QR code even though the user stopped Remote Setup.

**Impact**

- Unexpected network service exposure after an explicit Stop action.
- Remote Setup can remain reachable after leaving its screen.
- The UI and actual listener state can diverge.

**Recommended remediation**

- Retain the starting listener immediately.
- Add a start-generation or cancellation token checked by every state callback and completion.
- Cancel and clear both starting and ready listeners in `stop()`.
- Ignore late callbacks from superseded start attempts.
- Test Start → immediate Stop and Start → immediate navigation-away sequences.

### HI-003: Unsigned remote plugin code executes with unrestricted networking

**Locations**

- `NuvioMobile/shared/src/tvosMain/kotlin/com/nuvio/app/features/plugins/TvOsPluginRepository.kt:63-71`
- `NuvioMobile/shared/src/tvosMain/kotlin/com/nuvio/app/features/plugins/TvOsPluginRepository.kt:328-395`
- `NuvioMobile/shared/src/tvosMain/kotlin/com/nuvio/app/features/plugins/runtime/PluginRuntime.kt:128-156`
- `NuvioMobile/shared/src/tvosMain/kotlin/com/nuvio/app/features/plugins/runtime/network/FetchBridge.kt:23-66`

**Description**

Stored plugin repositories are automatically refreshed. Manifest-directed JavaScript is downloaded and evaluated without a verified signature, immutable digest, or pinned publisher identity. Absolute HTTP and HTTPS code URLs are accepted.

The plugin runtime exposes a fetch bridge that permits arbitrary URLs, methods, headers, and request bodies. This creates a high-trust remote-code execution boundary without corresponding integrity or network-isolation controls.

**Impact**

A compromised repository, publisher account, hosting service, DNS path, or cleartext network connection could replace plugin code and then:

- Exfiltrate plugin-visible configuration or identifiers.
- Probe loopback, LAN, private, and link-local services.
- Send requests using secrets stored or managed by the plugin.
- Consume unbounded response, CPU, or memory resources.

**Recommended remediation**

- Accept HTTPS plugin repositories and assets only.
- Require signed manifests and code using a pinned publisher key, or require a cryptographically verified immutable digest.
- Require explicit user confirmation when publisher identity or executable code changes.
- Declare and enforce allowed network origins per plugin.
- Block loopback, private, link-local, multicast, and metadata-service ranges unless a narrowly defined capability requires them.
- Restrict dangerous methods and headers and impose request, response, execution-time, and memory quotas.

### HI-004: App Transport Security is globally disabled

**Location**

- `NuvioMobile/iosApp/NuvioTV/Info.plist:5-10`

**Description**

`NSAllowsArbitraryLoads` is set to `true`, disabling the normal App Transport Security requirement across the tvOS application.

**Impact**

Cleartext requests can be intercepted or modified. Depending on the destination, affected data can include plugin JavaScript, addon manifests and responses, artwork, metadata, API-key-bearing requests, and media URLs.

This materially increases the exploitability of unsigned plugin updates and secret-bearing addon URLs.

**Recommended remediation**

- Remove the global ATS exception from Release builds.
- Enforce HTTPS for plugin repositories, addon manifests, metadata services, and API traffic.
- If a LAN development exception is truly necessary, isolate it to a debug-only configuration and scope it as narrowly as Apple permits.

### HI-005: Nested detail screens race through a shared global repository

**Locations**

- `NuvioMobile/iosApp/NuvioTV/Screens/DetailView.swift:70-71`
- `NuvioMobile/iosApp/NuvioTV/Screens/DetailView.swift:266`
- `NuvioMobile/iosApp/NuvioTV/Screens/DetailView.swift:355`
- `NuvioMobile/iosApp/NuvioTV/Screens/DetailViewModel.swift:48-89`

**Description**

Every Detail view model observes and loads through `MetaDetailsRepository.shared`. When the source detail screen disappears during a push to another title, its `stop()` method unconditionally clears that global repository.

The destination detail can start its request before the source screen's disappearance callback runs. The source then clears or cancels the destination's state. Both view models also observe the same unkeyed current state.

**Reproduction path**

1. Open a title detail screen.
2. Select a title from More Like This, a collection, or another nested detail link.
3. During the push transition, the previous screen disappears and clears the global repository.

**Impact**

- Intermittent blank detail screens.
- Destination loads that remain stuck or are cancelled.
- Incorrect title state being shown in the destination.

**Recommended remediation**

- Key repository state and requests by title identifier.
- Give each load an ownership or generation token, and clear it only if the caller still owns the active request.
- Prefer a per-screen loader or immutable cached detail records over one unkeyed global current-detail state.

### HI-006: Decoded artwork cache can exhaust Apple TV memory

**Location**

- `NuvioMobile/iosApp/NuvioTV/DesignSystem/CachedAsyncImage.swift:67-105`

**Description**

The shared `NSCache` limits only the number of `UIImage` objects to 400. It has no decoded-byte cost limit. Downloads are fully buffered and decoded at their source dimensions before insertion, with no response status, MIME, content-length, or pixel-dimension validation.

A 4K RGBA image can occupy roughly 32 MB decoded. Even much smaller poster and backdrop images can make a 400-image cache exceed a memory-constrained Apple TV process budget.

**Impact**

- Memory pressure and application termination during long catalog browsing.
- Large individual responses can create transient memory spikes before caching.
- Malicious or malformed image endpoints can amplify resource use.

**Recommended remediation**

- Add an appropriate `totalCostLimit` for tvOS.
- Insert images using a decoded-byte cost such as `bytesPerRow × height`.
- Downsample with ImageIO to the actual rendered dimensions before decoding.
- Reject unsuccessful HTTP responses, unexpected MIME types, oversized payloads, and unreasonable pixel dimensions.

### HI-007: Release configuration links against the debug SharedCore framework

**Locations**

- `NuvioMobile/iosApp/iosApp.xcodeproj/project.pbxproj:754-759`
- `NuvioMobile/iosApp/iosApp.xcodeproj/project.pbxproj:796-815`

**Description**

Both Debug and Release configurations search only the Kotlin `tvosArm64/debugFramework` and `tvosSimulatorArm64/debugFramework` directories, while the target links `SharedCore`.

**Impact**

- Release archives may fail when the debug framework is absent.
- A production archive may contain a debug-built SharedCore with different optimization, assertions, logging, or runtime behavior.
- App Store artifact validation becomes less predictable.

**Recommended remediation**

- Point Release at the correct Kotlin release framework directories.
- Prefer an Xcode build phase or supported Kotlin Gradle integration that assembles and embeds the correct framework for the active configuration and SDK.
- Add a clean Release archive check to CI and verify that the embedded binary is built with release settings.

---

## Medium-severity findings

### ME-001: Negative Content-Length can crash the Remote Setup parser

**Location**

- `NuvioMobile/iosApp/NuvioTV/Screens/RemoteSetupServer.swift:256-271`

**Description**

The HTTP parser accepts `Content-Length` through `Int(...) ?? 0` but does not reject negative values. A negative length satisfies `available >= contentLength`, then produces a body range whose end is before its start.

**Impact**

An unauthenticated LAN client can potentially trigger an invalid-range failure and terminate the application while Remote Setup is running.

**Recommended remediation**

- Accept exactly one valid, nonnegative, bounded content length.
- Reject malformed, negative, conflicting, duplicated, or over-limit values with a 400/413 response.
- Add parser tests for negative lengths, integer overflow, duplicate headers, truncated bodies, and oversized requests.

### ME-002: Failed Remote Setup startup leaks observers and disables sleep

**Locations**

- `NuvioMobile/iosApp/NuvioTV/Screens/RemoteSetupViewModel.swift:41-85`
- `NuvioMobile/iosApp/NuvioTV/Screens/RemoteSetupViewModel.swift:86-115`

**Description**

`start()` disables the global idle timer and installs five state watchers before listener readiness is known. If binding fails or an IP address is unavailable, the completion only sets `startFailed`; it does not restore the idle timer or cancel the watchers.

Because `serverURL` remains nil, Retry is allowed. A retry overwrites the stored watcher references without cancelling the previous watchers, leaving the earlier subscriptions alive.

**Impact**

- Screensaver and sleep remain disabled while Settings stays open.
- Repeated retries accumulate observers and duplicate work.
- Old observers can no longer be cancelled through the overwritten references.

**Recommended remediation**

- Introduce explicit stopped, starting, running, and failed states.
- Centralize teardown and invoke it on every failure path.
- Enable the idle timer only once the listener is ready, or restore it immediately on failure.
- Prevent retries while a prior attempt is unresolved.

### ME-003: Remote Setup proposals enable memory and UI denial of service

**Locations**

- `NuvioMobile/iosApp/NuvioTV/Screens/RemoteSetupServer.swift:161-171`
- `NuvioMobile/iosApp/NuvioTV/Screens/RemoteSetupServer.swift:219-235`

**Description**

Every POST creates a `PendingChange`. Older pending changes are marked rejected but remain in the dictionary indefinitely. Request bodies may approach the one-megabyte connection limit, and there is no authentication, rate limit, expiry, or per-peer quota.

Every accepted proposal also replaces the on-TV confirmation prompt.

**Impact**

- An LAN peer can continuously allocate retained proposals.
- Confirmation alerts can be repeatedly replaced, interfering with normal use.
- Memory consumption grows for the lifetime of the server.

**Recommended remediation**

- Keep only the current proposal and a small bounded status history.
- Cap proposal JSON well below one megabyte.
- Expire proposals and status records.
- Require the pairing token described in HI-001 and rate-limit submissions.

### ME-004: Trakt scrobbling can start after playback has closed

**Locations**

- `NuvioMobile/iosApp/NuvioTV/Screens/MPVPlayerView.swift:252-259`
- `NuvioMobile/iosApp/NuvioTV/Screens/MPVPlayerView.swift:548-581`
- `NuvioMobile/iosApp/NuvioTV/Screens/MPVPlayerView.swift:968-975`

**Description**

Starting a Trakt scrobble first builds a scrobble item asynchronously. If the player disappears before that completion returns, `viewDidDisappear` calls Stop while no item exists. The late completion then stores the item and starts scrobbling after playback is already gone. Deinitialization does not provide a final scrobble stop.

**Reproduction path**

Start a stream and immediately press Menu under slow metadata or network conditions.

**Impact**

- Stale playing status on Trakt.
- Incorrect progress or viewing history.
- A scrobble session that never receives the expected Stop event.

**Recommended remediation**

- Track player visibility or a playback-session generation identifier.
- Check it in the asynchronous completion before starting the scrobble.
- Cancel outstanding creation when supported.
- Add an idempotent final cleanup in teardown/deinitialization.

### ME-005: Alternate-source loading can reuse stale episode streams

**Locations**

- `NuvioMobile/iosApp/NuvioTV/Screens/NextEpisodeAutoPlay.swift:128-147`
- `NuvioMobile/iosApp/NuvioTV/Screens/NextEpisodeAutoPlay.swift:156-184`

**Description**

`loadSources()` starts a new load through a shared repository before replacing the watcher and does not clear the old `episodeStreamsState`. StateFlow can immediately emit its previous value, which is accepted without checking the requested video, season, or episode.

If the new request fails before emitting a terminal state, old sources can remain selectable and be combined with the current episode metadata.

**Impact**

- Playback can open the wrong episode or movie URL.
- The alternate-sources panel can display stale results.

**Recommended remediation**

- Clear local source state before loading.
- Subscribe before triggering the request.
- Tag state with the request identity and discard mismatched emissions.
- Give each request a generation token and ignore prior generations.

### ME-006: Long-lived credentials are stored in plaintext preferences

**Locations**

- `NuvioMobile/shared/src/appleMain/kotlin/com/nuvio/app/features/debrid/DebridSettingsStorage.apple.kt:67-83,187-192`
- `NuvioMobile/shared/src/appleMain/kotlin/com/nuvio/app/features/trakt/TraktAuthStorage.apple.kt:6-14`
- `NuvioMobile/shared/src/appleMain/kotlin/com/nuvio/app/features/addons/AddonPlatform.apple.kt:22-40,50-57`

**Description**

Debrid API keys, Trakt authorization data, and full secret-bearing manifest URLs are written to `NSUserDefaults`. Preference plist storage does not provide Keychain access-control semantics.

**Impact**

Secret material is more exposed in application-container extraction, diagnostics, or backups than it would be in Keychain storage.

**Recommended remediation**

- Store tokens and API keys in Keychain using a device-only accessibility class such as `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, or a stricter class if background access is unnecessary.
- Store only non-secret metadata and opaque references in preferences.
- Migrate existing values and delete the legacy preference entries after successful migration.

### ME-007: Skip Intro and Play Next lack accessible controls

**Locations**

- `NuvioMobile/iosApp/NuvioTV/Screens/MPVPlayerView.swift:858-880`
- `NuvioMobile/iosApp/NuvioTV/Screens/MPVPlayerView.swift:1150-1167`

**Description**

The player consumes directional and Select presses to perform transport, skip, track, and Up Next behavior. Skip and Up Next prompts are rendered as visual overlays rather than focusable, labeled controls, and no named accessibility actions are provided.

**Impact**

VoiceOver, Switch Control, and other accessibility users may not discover or invoke Skip Intro and Play Next. Consuming generic direction presses can also interfere with standard assistive navigation.

**Recommended remediation**

- Implement focusable Buttons where feasible.
- Otherwise expose clearly named `.accessibilityAction` operations and announcements.
- Preserve standard transport and focus semantics.
- Add VoiceOver, Switch Control, and full-keyboard regression tests.

---

## Low-severity finding

### LO-001: libmpv log callback force-unwraps C pointers

**Location**

- `NuvioMobile/iosApp/NuvioTV/Screens/MPVPlayerView.swift:1009-1013`

**Description**

The log callback force-unwraps `level` and `text` before converting them with `String(cString:)`.

**Impact**

A malformed or unexpected libmpv callback containing a null pointer would terminate playback or the application.

**Recommended remediation**

Optional-bind both pointers and supply safe fallback values. Avoid assuming third-party C callbacks always satisfy non-null invariants unless those invariants are guaranteed by the linked version's API contract.

---

## Testing and configuration observations

### TC-001: No native tvOS XCTest or UI-test target

The Xcode project defines application and extension targets but no native NuvioTV XCTest or UI-test target.

Highest-value initial tests are:

- Remote Setup HTTP parser boundary and malformed-input tests.
- Start → immediate Stop and failed-start cleanup tests.
- Nested Detail → More Like This navigation races.
- Player open/close loops and late Trakt completion.
- Next-episode alternate-source request identity.
- Siri Remote focus traversal and focus restoration.
- Menu, Play/Pause, directional seek, and track-panel behavior.
- VoiceOver actions for Skip Intro and Play Next.
- Repeated catalog scrolling under memory metrics.
- Top Shelf cold-start deep links and profile gating.
- Clean Release archive verification.

### TC-002: All tvOS targets require tvOS 27.0

**Locations**

- `NuvioMobile/iosApp/iosApp.xcodeproj/project.pbxproj:710`
- `NuvioMobile/iosApp/iosApp.xcodeproj/project.pbxproj:743`
- `NuvioMobile/iosApp/iosApp.xcodeproj/project.pbxproj:785`
- `NuvioMobile/iosApp/iosApp.xcodeproj/project.pbxproj:827`

Every NuvioTV and Top Shelf configuration sets `TVOS_DEPLOYMENT_TARGET = 27.0`.

This may be intentional, so it is not classified as a definite defect. If the intended audience includes Apple TVs on tvOS 26 or earlier, the target should be lowered and newer APIs should be protected with availability checks.

---

## Verification performed

- Reviewed the current working tree, including the nested `NuvioMobile` checkout and ignored local source present in the Xcode synchronized group.
- Inspected native SwiftUI screens, view models, navigation, Remote Setup, image loading, the mpv player wrapper, Next Episode behavior, Info.plist, entitlements, Xcode configurations, and relevant Apple/tvOS Kotlin storage and plugin code.
- Confirmed that Remote Setup configuration writes require explicit on-TV confirmation; no direct unauthenticated configuration-write bypass was claimed.
- Confirmed that Remote Setup is user-started rather than permanently listening.
- Attempted Xcode destination/build verification. The installed Xcode environment did not have the required tvOS platform runtime. Xcode reported the connected `Living Room` device as ineligible because tvOS 26.5 support was not installed, so a clean build or runtime test could not be confirmed.

## Review limitations

This was a static review, not a complete penetration test or device-based QA pass. Dynamic validation remains necessary for network reachability, plugin isolation, focus behavior, player teardown, memory pressure, Top Shelf launches, and the navigation races described above.

No application source files were modified as part of this review.

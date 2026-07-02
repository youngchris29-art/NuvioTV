# Wiring the tvOS app to the Kotlin framework

## 1. Build the framework for tvOS
From the repo root on your Mac:
```bash
# Spike route (framework comes from composeApp):
./gradlew :composeApp:linkDebugFrameworkTvosSimulatorArm64
# Clean route (framework comes from :shared):
./gradlew :shared:linkDebugFrameworkTvosSimulatorArm64
```
The `.framework` lands under `build/bin/tvosSimulatorArm64/debugFramework/`.

## 2. Add the tvOS target in Xcode
- Open `iosApp/iosApp.xcodeproj` (or a new workspace).
- **File → New → Target → tvOS → App**, SwiftUI lifecycle, name `NuvioTV`,
  bundle id `com.nuvio.media.tv`.
- Add the Swift files from this folder to the new target.

## 3. Link the Kotlin framework (mirror how iosApp does it)
The existing iOS target builds the framework via a **Run Script Build Phase** calling
`./gradlew … embedAndSignAppleFrameworkForXcode`. Copy that phase into the `NuvioTV`
target and point `KOTLIN_FRAMEWORK_BUILD_TYPE`/`baseName` at `SharedCore`. Then:
- Build Settings → **Framework Search Paths** → the tvOS framework output dir.
- General → **Frameworks, Libraries, and Embedded Content** → add `SharedCore.framework`.

## 4. Add SKIE (recommended) for Swift async/Flow
In `libs.versions.toml` add the SKIE plugin + apply it in the framework module. SKIE
turns Kotlin `suspend` into Swift `async` and `Flow` into `AsyncSequence`, so the Stores
in `Stores/` can `for await` over repository streams with no manual callback bridging.

## 5. Run
Select the **Apple TV** simulator, build `NuvioTV`, fix the first errors, report back.

> The Swift files here are a deliberately small vertical slice (Home → poster grid →
> details/play) to prove the pipeline. They reference shared types by their likely names
> (`HomeRepository`, `HomeCatalog`, …) — adjust to the actual generated Kotlin headers,
> which Xcode surfaces once the framework is linked.

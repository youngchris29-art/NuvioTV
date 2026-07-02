# Phase 0 Scaffolding — apply on your Mac

These files are a **starting point**, not a finished build. They can't be compiled in
the cloud sandbox (Apple targets need Xcode), so treat them as templates to drop into a
fresh clone of `NuvioMobile` and iterate from. Read `../docs/tvos-port-plan.md` first.

## Order of operations

1. **Clone & verify baseline**
   ```bash
   git clone https://github.com/NuvioMedia/NuvioMobile.git
   cd NuvioMobile
   git submodule update --init --recursive   # pulls MPVKit
   ./scripts/run-mobile.sh ios               # confirm a known-good iOS build
   ```

2. **Add tvOS targets to a shared framework.** Two routes:
   - **Fast spike (recommended first):** add the tvOS targets directly to the existing
     `composeApp` Gradle, but build a **logic-only framework** by excluding Compose from
     the tvOS source set. See `gradle/composeApp-tvos-targets.kts.snippet`. This gets a
     `SharedCore`-style framework out the door without the full module extraction.
   - **Clean architecture (do after the spike works):** create a real `shared` Gradle
     module and relocate the Compose-free packages into it. See
     `gradle/shared-build.gradle.kts` and `gradle/settings-additions.kts.snippet`.

3. **Create the tvOS app in Xcode.** New Xcode target → **tvOS App** (SwiftUI lifecycle),
   product name `NuvioTV`. Then add the Swift files under `tvosApp/` and link the
   Kotlin framework. See `tvosApp/INTEGRATION.md`.

4. **Build for the Apple TV simulator**, fix the first errors, report back.

## What's here

```
scaffolding/
├── README.md                              ← this file
├── gradle/
│   ├── composeApp-tvos-targets.kts.snippet  ← add tvOS targets (spike route)
│   ├── shared-build.gradle.kts              ← clean shared module build file
│   └── settings-additions.kts.snippet       ← register :shared
├── kotlin/
│   └── Platform.tvos.kt                      ← example tvOS `actual` (template)
└── tvosApp/
    ├── INTEGRATION.md                        ← Xcode linking steps + SKIE setup
    ├── NuvioTVApp.swift                      ← @main entry
    ├── Shared.swift                          ← long-lived repository instances (no DI in this repo)
    ├── Stores/HomeStore.swift                ← StateFlow → ObservableObject pattern
    ├── Views/HomeView.swift                  ← focus-engine home screen
    ├── Views/PosterCard.swift                ← focusable poster w/ parallax lift
    └── Views/PlayerView.swift                ← AVPlayer playback surface
```

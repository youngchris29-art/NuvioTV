# Nuvio tvOS Port — Architecture & Roadmap

> Goal: ship a native **tvOS (Apple TV)** app at feature parity with NuvioMobile, by
> reusing the existing shared Kotlin business logic and building a new **SwiftUI**
> frontend designed for the focus engine and Siri Remote.
>
> Status: planning + Phase 0 foundation. Builds happen on your Mac (Xcode 16+).

---

## 1. What we're working with

NuvioMobile is **not** a React Native app (despite the prompt). It's a **Kotlin
Multiplatform + Compose Multiplatform** project — the README calls it "the current
KMP rewrite of the original React Native app."

Facts established from the codebase:

| Area | Detail |
|---|---|
| Shared code | `composeApp/` — **~95,700 LOC**, 365 Kotlin files, **25+ feature modules** |
| UI | Compose Multiplatform (`commonMain`), shared across Android + iOS |
| Targets today | `androidTarget`, `iosArm64`, `iosSimulatorArm64` |
| Android player | AndroidX Media3 (ExoPlayer) + MPV (`mpv-android-lib`) |
| iOS player | AVFoundation + MPVKit (git submodule) + Metal layer |
| Backend/services | Supabase (postgrest/auth/functions), Ktor 3.4.1, kotlinx-serialization |
| Ecosystem | Stremio addon system, TMDB, Trakt, MDBList, debrid (Premiumize), IntroDB |
| Toolchain | Kotlin 2.3.0, Compose MP 1.11.1, AGP 9.2.0, coil3 |
| iOS bridge | `iosApp/` Xcode project; native Swift already wraps Compose (custom tab bar, player bridge, live activities) |

**Key separability finding (this is what makes the port viable):**

- All **48 `*Repository` files are Compose-free.**
- `core/network`, `core/storage`, `core/sync`, `core/auth` are Compose-free.
- **226 of 365 shared files import no Compose at all** — the entire data/domain layer.
- **139 files** are the Compose UI (screens + components) — these we do **not** reuse.
- There are **73 `expect`/`actual`** platform-glue declarations needing a tvOS `actual`.

So the domain/data layer lifts cleanly into a UI-free shared framework; the touch UI
gets replaced with purpose-built SwiftUI.

---

## 2. Why "native SwiftUI + shared logic" (chosen approach)

Two paths were considered:

**A. Experimental Compose-on-tvOS** — add tvOS Kotlin targets and try to render the
existing Compose UI on Apple TV. Rejected because:
- Compose Multiplatform has **no official tvOS support**; it's unsupported/fragile.
- The UI is touch-designed. tvOS needs the **focus engine** + D-pad navigation, which
  Compose-on-tvOS does not model. We'd be fighting two unsupported problems at once.
- The player (MPVKit/Metal) does not carry to tvOS cleanly.

**B. Native SwiftUI frontend + shared Kotlin logic (CHOSEN)** — reuse the proven
domain/data layer as a UI-free `shared` KMP framework, write a new SwiftUI app built
around the tvOS focus engine and `AVPlayer`. This is how serious tvOS apps are built,
the codebase already has a native-Swift bridge pattern to follow, and it isolates the
two unsupported problems (Compose-on-tvOS, MPV-on-tvOS) out of the critical path.

---

## 3. Target architecture

```
┌──────────────────────────────────────────────────────────────┐
│  tvosApp/  (NEW — native, this project's deliverable)          │
│  SwiftUI + the tvOS focus engine + AVKit/AVPlayer              │
│   • Screens: Home, Catalog, Details, Search, Library,         │
│     Streams picker, Player, Settings, Profiles, Addons …      │
│   • "Stores" (ObservableObject) wrapping shared repositories  │
│   • Swift async/await over Kotlin suspend (KMP-NativeCoroutines)│
└───────────────▲──────────────────────────────────────────────┘
                │ imports SharedCore.framework (Obj-C/Swift interop)
┌───────────────┴──────────────────────────────────────────────┐
│  shared/  (NEW Gradle module — UI-free)                       │
│  Lifts the Compose-free domain/data layer out of composeApp:  │
│   • features/*/  repositories, models, parsers, services      │
│   • core/network, core/storage, core/sync, core/auth, format  │
│  Targets: android, iosArm64, iosSimulatorArm64,               │
│           tvosArm64, tvosSimulatorArm64  ← NEW                 │
│  Deps: ktor, kotlinx-serialization, supabase, kermit (NO Compose)│
└───────────────▲──────────────────────────────────────────────┘
                │ (existing apps keep working)
┌───────────────┴───────────────┐   ┌──────────────────────────┐
│ composeApp/ (existing)        │   │ androidApp/, iosApp/      │
│ Compose UI for phone/tablet → │   │ (unchanged)               │
│ now depends on shared/        │   └──────────────────────────┘
└───────────────────────────────┘
```

The existing phone apps keep shipping unchanged; `composeApp` simply consumes the new
`shared` module instead of holding the logic directly.

---

## 4. The five technical pillars

### 4.1 Shared-core extraction (`shared/` module)
Move the Compose-free packages out of `composeApp/commonMain` into a new `shared`
module. Because repositories already import no Compose, this is mechanical: relocate
files, fix package-internal visibility, and split the Gradle dependency block so
`shared` pulls only ktor/serialization/supabase/kermit. `composeApp` then declares
`implementation(projects.shared)`.

### 4.2 tvOS Kotlin/Native targets
Add `tvosArm64()` and `tvosSimulatorArm64()` to `shared`. Provide `actual`
implementations for the ~73 `expect` declarations. Most can be created as a shared
`appleMain`/`darwinMain` source set so iOS and tvOS reuse one implementation (Darwin
APIs: `NSUserDefaults`, `NSFileManager`, `CommonCrypto`, Ktor Darwin engine). Only the
handful that touch iOS-only UIKit/AVAudioSession need a tvOS-specific variant.

### 4.3 Swift ↔ Kotlin concurrency bridge
Kotlin `suspend` functions and `Flow` are awkward from Swift. Adopt
**KMP-NativeCoroutines** (or SKIE) so repositories expose Swift `async`/`AsyncSequence`.
Wrap each repository in a SwiftUI `@MainActor` "Store" (`ObservableObject`) that the
views observe.

### 4.4 Focus-engine UI (the real design work)
tvOS UX is fundamentally different from mobile:
- Everything is **focus-driven** (no touch). Use `@FocusState`, `.focusable()`,
  `.focusSection()`, and lazy grids/stacks that the focus engine can traverse.
- **10-foot layouts**: larger type, generous spacing, poster rows that scroll
  horizontally, hero headers, the parallax "lift" on focused posters.
- **Siri Remote**: menu/back semantics, play/pause, swipe scrubbing in the player.
- Reuse Nuvio's **visual language** (dark theme, accent `#1E88E5`, poster art, section
  layouts) but rebuilt as native tvOS components.

### 4.5 Player
Use **`AVPlayer` / `AVPlayerViewController`** (AVKit) as the primary tvOS player — it
gives focus-aware transport controls, the native scrubbing UI, and HLS/DASH support for
free. MPV/MPVKit on tvOS is a later, optional enhancement for exotic codecs/subtitles
(libass). Map the existing stream-resolution logic (addons → URLs → debrid) straight
through from `shared`; only the playback surface is new.

---

## 5. Phased roadmap to full parity

Each phase ends in something runnable on the Apple TV simulator on your Mac.

**Phase 0 — Foundation (this session's scaffolding + your first build)**
- [ ] Add `shared` module skeleton + tvOS targets (Gradle).
- [ ] Create `tvosApp` Xcode project (SwiftUI, tvOS target) linking `SharedCore`.
- [ ] Get an empty SwiftUI screen running on the tvOS simulator.
- [ ] Wire one real call (e.g., TMDB/home catalog) end-to-end to prove the bridge.

**Phase 1 — Browse & discover**
- [ ] Home (continue watching, catalog rows, hero) with focus navigation.
- [ ] Catalog grid + Search.
- [ ] Title Details (metadata, seasons/episodes, cast, ratings).

**Phase 2 — Playback**
- [ ] Streams picker (addons + debrid resolution).
- [ ] AVPlayer playback screen + transport, resume/watch-progress writes.
- [ ] Subtitles + audio track selection (AVPlayer-native first).

**Phase 3 — Accounts & ecosystem**
- [ ] Profiles, Supabase auth/sync, Trakt linking & scrobble.
- [ ] Addon management UI, MDBList, settings.

**Phase 4 — Parity & polish**
- [ ] Library/collections, watch history, notifications, updater.
- [ ] Localization (the repo already ships ~20 locales — reuse the string resources).
- [ ] Top-shelf extension, app icon/layered art, TestFlight for tvOS.

> Downloads/offline and Live Activities are mobile-centric; on tvOS they're likely
> **out of scope** (no offline-first expectation on Apple TV). Flag for your decision.

---

## 6. Risks & open questions

- **Compose-free guarantee:** a few "service" files may transitively touch Compose
  (`remember`, `State`); these surface at extraction and get refactored to plain
  Kotlin. Low risk given repositories are already clean.
- **MPV on tvOS:** defer. AVPlayer covers the common cases; MPV is a stretch goal.
- **Supabase/Ktor on tvOS:** Ktor Darwin engine supports tvOS; Supabase-kt should
  compile to tvOS targets — to be confirmed on first `shared` build.
- **Concurrency bridge choice:** KMP-NativeCoroutines vs SKIE — pick one early
  (recommend SKIE for ergonomic Swift `async`/`Flow`, fewer annotations).
- **Build environment:** the cloud sandbox can't compile Apple targets. All Xcode/
  Gradle-Kotlin-Native builds run on your Mac; I produce code + exact commands.
- A separate **`tapframe/NuvioTV`** (React Native TV) project exists upstream — worth a
  look for UX reference, but our port reuses *this* KMP logic, not that code.

---

## 7. Immediate next steps

1. On your Mac: `git clone https://github.com/NuvioMedia/NuvioMobile.git` and confirm it
   builds for iOS (`./scripts/run-mobile.sh ios`) so we have a known-good baseline.
2. Apply the Phase 0 scaffolding in `/scaffolding` (see `scaffolding/README.md`).
3. Open the new `tvosApp` in Xcode, select the **Apple TV** simulator, and build.
4. Report the first compile errors back here — we iterate target-by-target, then
   feature-by-feature down the Phase 1 list.

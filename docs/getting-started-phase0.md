# Phase 0 — Step-by-Step Build Guide

A hands-on walkthrough to get the Nuvio codebase building and a tvOS (Apple TV) target
running on your Mac. Work top to bottom. Each step has the **command**, **what you
should see**, and **if it fails** notes. When something breaks, copy the error back to
me and we'll sort it before moving on.

> Conventions: lines starting with `$` are things you type in **Terminal** (don't type
> the `$`). "the folder" = wherever you keep the project.

---

## Step 0 — Prerequisite check (5 min)

Open **Terminal** (Cmd-Space → type "Terminal" → Return) and run these one at a time:

```bash
$ xcodebuild -version
$ git --version
$ java -version
```

**What you should see**
- `xcodebuild` → `Xcode 16.x` (any 16 is fine). If it errors, open Xcode once and let
  it install components, then retry.
- `git` → any version (`git version 2.x`).
- `java` → a version line showing **17 or higher** (e.g. `openjdk version "17..."`).

**If `java` fails** ("command not found") — Gradle needs a JDK 17+. Install one:

```bash
# If you have Homebrew (check with: brew --version)
$ brew install temurin@21
# No Homebrew? Install it first from https://brew.sh, then run the line above.
```

After installing, close and reopen Terminal and run `java -version` again. Tell me the
output if you're unsure — JDK setup is the most common snag.

**Also confirm Xcode command-line tools are pointed at the full Xcode:**

```bash
$ xcode-select -p
```
Should print `/Applications/Xcode.app/Contents/Developer`. If it prints a
`CommandLineTools` path instead, run:
```bash
$ sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

---

## Step 1 — Get the code (5–15 min depending on network)

Pick a home for the project and clone it **with submodules** (the player engine MPVKit
is a submodule — skipping it breaks the iOS build):

```bash
$ cd ~/Developer        # or wherever you keep projects; mkdir -p ~/Developer first
$ git clone https://github.com/NuvioMedia/NuvioMobile.git
$ cd NuvioMobile
$ git submodule update --init --recursive MPVKit
```

> ⚠️ Note we init **only `MPVKit`** (not a bare `--recursive`). The repo references an
> `libass-android` submodule that was never declared in `.gitmodules`, so a plain
> `git submodule update --init --recursive` fails with
> `fatal: No url found for submodule path 'libass-android'`. That library is Android-only
> and irrelevant to the iOS/tvOS build, so we skip it by naming the `MPVKit` path.

**What you should see** — `git clone` prints progress then "done"; the submodule command
checks out `MPVKit`. Confirm with:
```bash
$ ls MPVKit
```
It should NOT be empty.

**If submodules are slow/large** — that's normal (MPVKit ships prebuilt binaries). Let it
finish.

---

## Step 2 — Baseline build, so we know the environment is healthy (15–40 min first time)

Before touching tvOS, prove the existing app compiles. This also warms up Gradle and
downloads dependencies (slow the first time, fast after).

**First create `local.properties`** (required — the build's config-generator task expects
this file to exist, even empty, or it fails with "specifies file … which doesn't exist"):

```bash
$ touch local.properties
```

Then a pure-Kotlin compile of the shared code for iOS simulator — fastest way to catch
toolchain problems:

```bash
$ ./gradlew :composeApp:compileKotlinIosSimulatorArm64
```

**What you should see** — lots of "Downloading…" the first time, then `BUILD SUCCESSFUL`.

**If it fails** — copy the last ~30 lines to me. Usual causes: wrong JDK (Step 0), or a
missing `local.properties`. If it complains about missing config keys, create an empty
`local.properties` in the repo root:
```bash
$ touch local.properties
```
(The build fills in blank API keys for things like Trakt/Supabase; the app still
compiles, some online features just stay inert until keys are added.)

Optional but reassuring — open the iOS app in Xcode and run it once:
```bash
$ open iosApp/iosApp.xcodeproj
```
In Xcode: pick an **iPhone simulator** at the top, press **Cmd-R**. First build is slow.
If it launches, your whole toolchain is good. (This is just a confidence check — close it
after.)

---

## Step 3 — Add the tvOS Kotlin targets (the "spike" route)

We'll start with the fast route from `scaffolding/gradle/composeApp-tvos-targets.kts.snippet`:
add tvOS targets to the existing `composeApp` module so it can emit a logic framework for
Apple TV. (The cleaner `:shared` module split comes later — see the plan doc.)

1. Open the project in your editor (Xcode, or `Antigravity`, or whatever you like):
   ```bash
   $ open -a Xcode composeApp/build.gradle.kts
   ```
2. Find the block that defines the iOS targets — search for:
   ```
   val iosTargets = listOf(
       iosArm64(),
       iosSimulatorArm64()
   )
   ```
3. **Directly below that list**, paste the `tvosTargets` block from
   `scaffolding/gradle/composeApp-tvos-targets.kts.snippet` (the `val tvosTargets = …`
   part and the `tvosTargets.forEach { … }` loop).
4. Save.

5. Back in Terminal, try to compile the shared code for tvOS:
   ```bash
   $ ./gradlew :composeApp:compileKotlinTvosSimulatorArm64
   ```

**What you should expect** — this is the **first real test of the port**, and it may NOT
succeed cleanly. The likely error is Compose symbols not resolving for tvOS (because
`commonMain` still pulls Compose, which has no tvOS support). That's expected and is our
signal to move to the clean `:shared` module split.

👉 **Whatever happens here, copy the result to me** — success or the error block. The
errors literally tell us which files need to move into `:shared`, and I'll give you the
exact file-move list for Step 4.

---

## Step 4 — (If Step 3 surfaces Compose errors) split out the `:shared` module

We do this together once we see Step 3's output. The outline:

1. Create a `shared/` folder with the `build.gradle.kts` from
   `scaffolding/gradle/shared-build.gradle.kts`.
2. Register it in `settings.gradle.kts` (see `scaffolding/gradle/settings-additions.kts.snippet`).
3. Move the Compose-free packages (all `*Repository`, `*Model`, parsers, `core/network`,
   `core/storage`, `core/sync`, `core/auth`, etc.) from `composeApp/src/commonMain` into
   `shared/src/commonMain`. I'll generate the precise list so we move them in safe batches
   and recompile after each.
4. Add `implementation(projects.shared)` to `composeApp`.
5. Build the framework:
   ```bash
   $ ./gradlew :shared:linkDebugFrameworkTvosSimulatorArm64
   ```
   Output lands in `shared/build/bin/tvosSimulatorArm64/debugFramework/SharedCore.framework`.

---

## Step 5 — Create the tvOS app target in Xcode

1. Open the Xcode project:
   ```bash
   $ open iosApp/iosApp.xcodeproj
   ```
2. **File → New → Target…** → choose the **tvOS** tab → **App** → Next.
3. Product Name: `NuvioTV` · Interface: **SwiftUI** · Language: **Swift** · Bundle ID:
   `com.nuvio.media.tv`. Create it.
4. In the new `NuvioTV` group, delete the auto-generated `ContentView.swift` and the
   default App file, then drag in the Swift files from `scaffolding/tvosApp/`
   (`NuvioTVApp.swift`, `Shared.swift`, `Stores/`, `Views/`). When prompted, check
   **"Copy items if needed"** and add them to the **NuvioTV** target.
5. Link the Kotlin framework — follow `scaffolding/tvosApp/INTEGRATION.md` Step 3
   (copy the iOS target's "embed framework" run-script phase onto NuvioTV, pointed at
   `SharedCore`).

---

## Step 6 — Build for the Apple TV simulator

1. At the top of Xcode, click the scheme/device selector and choose **NuvioTV** as the
   scheme and an **Apple TV** simulator (e.g. "Apple TV 4K").
2. Press **Cmd-R**.

**What you should see (Phase 0 goal)** — the app launches in the tvOS simulator showing
the tab bar and an empty/loading Home. It won't have real data until we wire addons in
Phase 1 — that's the next milestone, not a bug.

**When you hit the first compile errors** (very likely — the Swift files reference Kotlin
types by their probable names), copy them to me. Xcode shows the real generated Kotlin
header names once the framework is linked, and I'll correct the Swift to match.

---

## What "done with Phase 0" looks like

- `./gradlew :shared:linkDebugFrameworkTvosSimulatorArm64` succeeds.
- `NuvioTV` builds and launches on the Apple TV simulator.
- One real call (home/catalog) returns data through the shared framework.

Then we move down the Phase 1 list in `tvos-port-plan.md`: Home → Catalog/Search →
Details, with focus navigation.

---

## Quick troubleshooting reference

| Symptom | Likely cause | Fix |
|---|---|---|
| `java: command not found` | No JDK | Install Temurin 17/21 (Step 0) |
| Gradle: "Unsupported class file major version" | Wrong/old JDK | Use JDK 17–21, not 8/11 |
| `MPVKit` folder empty / iOS link errors | Submodules not pulled | `git submodule update --init --recursive MPVKit` |
| `fatal: No url found for submodule path 'libass-android'` | Undeclared Android-only submodule | Init only MPVKit: `git submodule update --init --recursive MPVKit` |
| `generateRuntimeConfigs … specifies file 'local.properties' which doesn't exist` | Missing `local.properties` | `touch local.properties` in repo root |
| tvOS compile: "unresolved reference: androidx.compose…" | Compose isn't tvOS-compatible | Expected → do Step 4 (`:shared` split) |
| Swift: "cannot find type 'HomeRepository'" | Framework not linked / name differs | Link framework (INTEGRATION.md); send me the real header names |

> Reminder: I can't compile Apple targets from here, so you're my eyes — paste outputs
> and errors as you go and I'll keep us moving step by step.

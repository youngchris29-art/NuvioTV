# Upstream port plan — 2026-10-05

Upstream NuvioMedia/NuvioMobile `cmp-rewrite`: `966a52b9` → `c2127769` (5 non-merge commits). Fork shared/ MDBList library files are byte-identical to upstream 966a52b9 (verified), so the patch below applies cleanly.

## Item 1 — MDBList "choose which lists appear in the library" (upstream a9797ff8, #2171) — RECOMMENDED, MEDIUM
Shared Kotlin (mechanical port into `NuvioMobile/shared/src/commonMain/kotlin/com/nuvio/app/features/mdblist/`):
1. `MdbListLibraryModels.kt`: add `hiddenListKeys: Set<String> = emptySet()` to `MdbListLibrarySnapshot`; add `visibleTabs()`, `visible()`, `listOptions()`; add `data class MdbListLibraryListOption(key, name, visible)`.
2. `MdbListLibraryRemote.kt`: skip downloading hidden lists in sync; drop hidden keys for lists deleted upstream.
3. `MdbListLibraryService.kt`: `listOptions` flow; use `visible()/visibleTabs()` in projection, tabs, snapshot, find, membership; add `setListVisible()` + `setListVisibleAsync()`.
4. Port `MdbListLibraryServiceTest.kt` additions (+44 lines) to `shared/src/commonTest`.
Fastest path: `git -C NuvioMobile show a9797ff8 -- composeApp/.../mdblist/ composeApp/src/commonTest/.../mdblist/ | sed 's#composeApp/src/commonMain#shared/src/commonMain#g; s#composeApp/src/commonTest#shared/src/commonTest#g' | git apply` (check the commonTest path mapping first).
tvOS SwiftUI (new work, upstream UI is Compose and not portable): add a "Library lists" row in Settings > Services (MDBList section, `ServicesSettingsPane.swift` / `SettingsViewModel.swift`, shown only while MDBList connected) opening a focusable list of toggles (one per `listOptions`, Watchlist excluded) that calls `MdbListLibraryService.setListVisibleAsync`. Add strings to `Localizable.xcstrings` (upstream en keys in values/strings.xml: 5 new strings). Check `LibraryViewModel.swift` still reads tabs via the service (hidden lists should vanish from Library tabs, TitleHoldMenu add-to-list picker, DetailView membership).
Verify: jvm tests + K/N tests + NuvioTVTests; sim check that hiding a list removes it from Library and the hold-menu picker, and re-showing loads its items.
Also: pt / pt-BR strings not needed (fork i18n handled separately).

## Not applicable
- `c2127769` fix(p2p) torrent cache path + `a0733ea4` nuvio engine 0.1.4: P2P engine lives in composeApp (`iosFull`/Android), not in fork's shared/ and tvOS has no P2P engine. Revisit only if P2P is ever adopted.
- `e22baece` letterbox zoom on hero trailer: Android/Compose only (Android surface + TabletDetailHero).
- Merge commits.

## Decision for Christian
Item 1 is optional feature parity; worth doing only if you use multiple MDBList lists.

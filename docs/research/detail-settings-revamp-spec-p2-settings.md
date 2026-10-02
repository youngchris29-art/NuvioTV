P2 Settings implementation spec: "Native Split + Explainer" (NuvioTV, branch claude/detail-settings-revamp, base 5f2d5cd3)

Paths are relative to `NuvioMobile/iosApp/NuvioTV/` unless stated otherwise. This was a read-only session: nothing was edited and nothing was built. Three facts about the repo that the work split depends on:
- The Xcode project uses `PBXFileSystemSynchronizedRootGroup` (9 groups). New `.swift` files are picked up automatically and no pbxproj edit is needed.
- The unit tests use `XCTest` with `@testable import NuvioTV`.
- `Localizable.xcstrings` keys are the English text (1,033 keys, no comments). `populate-localizable-xcstrings.py` collects keys from the compiler-emitted `.stringsdata`.

---

## A. `SettingsCategory` rewrite (`Screens/SettingsView.swift:321-356`)

**Persisted raw values: none.** `selectedCategory` is plain `@State` at `ContentView.swift:40` and is not written to UserDefaults. A grep finds no other `SettingsCategory` or `settingsCategory` reference outside `SettingsView.swift` and `ContentView.swift`. No migration is needed. `settings_style` (`SettingsView.swift:90`, `AppearanceSettingsPane.swift:47`) is unchanged.

```swift
enum SettingsCategoryGroup: CaseIterable {
    case you, look, watch, system
    var title: String { /* "You" / "Look" / "Watch" / "System" via String(localized:) */ }
    var categories: [SettingsCategory] { SettingsCategory.allCases.filter { $0.group == self } }
}

/// Order here is the root-list order.
enum SettingsCategory: String, CaseIterable, Identifiable, Hashable {
    case accountProfiles, services, appearance, homeScreen, detailPage,
         player, sources, subtitlesAudio, about, developer
    var id: String { rawValue }
    var group: SettingsCategoryGroup { ... }
    var title: String { ... }   // String(localized:), stays in SettingsView.swift
    var icon: String { ... }
    // subtitle and summary: LocalizedStringResource, defined in SettingsDescriptions.swift (one copy file)
}
```

| # | case | group | SF Symbol | title | subtitle (draft) | summary (draft; final copy in W3-A) |
|---|---|---|---|---|---|---|
| 0 | accountProfiles | You | `person.crop.circle` | Account & Profiles | Nuvio account, server and Remote Setup | Sign in or out of your Nuvio account and choose which server this Apple TV talks to. Remote Setup lets you manage add-ons, Home rows and keys from a phone browser. |
| 1 | services | You | `link` | Services | Trakt, Simkl, MDBList and debrid | Connect the tracking services that record what you watch, and the debrid services that turn cached torrents into direct streams. Connections are per profile. |
| 2 | appearance | Look | `paintbrush` | Appearance | Theme, posters, card depth and badges | Pick the accent colour, typeface and navigation style, and shape how posters and cards look across the app. Stream badge packs are managed here too. |
| 3 | homeScreen | Look | `house` | Home Screen | Hero, rows and trailer previews | Choose what the top of Home shows and which catalogs appear as rows, in what order. Trailer previews on focus are set here too. |
| 4 | detailPage | Look | `film` | Detail Page | Layout, trailers and sections | Choose the title page layout, how trailers behave, and which sections appear under the main details. Episode spoiler protection is here too. |
| 5 | player | Watch | `play.rectangle` | Player | Default player, skipping, video and buffering | Control how playback starts and behaves: the default player, intro skipping, frame-rate matching, Dolby Vision handling and buffering. |
| 6 | sources | Watch | `square.stack.3d.up` | Sources | Auto-play, filters, metadata and plugins | Decide which streams are picked and shown, where metadata and ratings come from, where your library and progress are stored, and which plugins and search catalogs run. |
| 7 | subtitlesAudio | Watch | `captions.bubble` | Subtitles & Audio | Subtitle style and preferred languages | Set how subtitles look and which audio and subtitle languages are chosen automatically when playback starts. |
| 8 | about | System | `info.circle` | About | Version, build and device | The exact version, build and commit running on this Apple TV. Include these when you report a bug. |
| 9 | developer | System | `hammer` | Developer | Diagnostics and A/B switches | Diagnostic readouts and test switches used when chasing a bug report. Leave them alone unless you've been asked to capture something. |

New UI strings:
- Category titles: "Account & Profiles", "Services", "Detail Page", "Player", "Sources", "Subtitles & Audio", "Developer".
- Group headers: "You", "Look", "Watch", "System".
- "Appearance", "Home Screen" and "About" reuse existing keys.

---

## B. Navigation

### B1. `ContentView.swift` (W1-B touches only these sites)

- **:34-40.** Replace `@State private var settingsCategory: SettingsCategory = .accountServices` (keep the doc comment, reworded) with:
  ```swift
  @State private var settingsPath: [SettingsCategory] = []          // open pane; survives the .id() remount
  @State private var settingsLastCategory: SettingsCategory? = nil  // root focus restore after pop/remount
  ```
- **:102.** `settingsCategory: $settingsCategory,` becomes `settingsPath: $settingsPath, settingsLastCategory: $settingsLastCategory,`.
- **:326-329 (`MainTabView`).** Replace `@Binding var settingsCategory: SettingsCategory` with `@Binding var settingsPath: [SettingsCategory]` and `@Binding var settingsLastCategory: SettingsCategory?`.
- **:396-400.** `SettingsView(selectedCategory: $settingsCategory, …)` becomes `SettingsView(path: $settingsPath, lastCategory: $settingsLastCategory, pendingThemeSwatchFocus: …, pendingAppearanceRowFocus: …)`.
- **:144.** In the comment, "Settings category" becomes "Settings path".

Use a typed `[SettingsCategory]`, not `NavigationPath`: it is Equatable and its depth is at most 1. The state lives above `.id("\(appTheme.paletteKey)|\(sidebarStyle)|\(uiFont)")` (:146). After a theme, navigation or typeface change, the rebuilt `NavigationStack(path:)` starts with `[.appearance]` already in the path and shows Appearance directly, with no push animation. Appearance's existing consumers then restore focus: `ThemePickerRow.onAppear` (AppearanceSettingsPane:406-413) and the pane's `.onAppear` (:144-155). test43 covers this.

Optional, not required: clear `settingsPath = []` in the `onChange(of: entered)` else-branch (:192). Today the category is not reset on a profile switch either, so this is left out by default.

### B2. `SettingsView.swift` new shape (W1-B rewrites the whole file except the alerts)

```swift
struct SettingsView: View {
    // unchanged: @StateObject model, trakt, simkl, debrid, remote, plugins, badges (:54-60);
    // @EnvironmentObject auth; the five confirm @States (:62-68)
    @Binding var path: [SettingsCategory]
    @Binding var lastCategory: SettingsCategory?
    @Binding var pendingThemeSwatchFocus: String?
    @Binding var pendingAppearanceRowFocus: String?

    var body: some View {
        NavigationStack(path: $path) {
            SettingsRootView(path: $path, lastCategory: $lastCategory)
                // FEAT-30: on the ROOT view, inside the stack, exactly as today (:112-118).
                // Pushed panes are stack destinations, not descendants of this view, so
                // this onExitCommand never sees their Menu press.
                .sidebarMenuReveal()
                .background(Theme.Palette.background.ignoresSafeArea())
                .navigationDestination(for: SettingsCategory.self) { category in
                    SettingsPaneScaffold(category: category) { paneContent(category) }
                }
        }
        .onAppear { /* unchanged :121-128 */ }      // stays on the NavigationStack:
        .onDisappear { /* unchanged :129-137 */ }   // pushing a pane must NOT stop the VMs
        // all six .alert modifiers unchanged (:138-204)
    }

    @ViewBuilder private func paneContent(_ category: SettingsCategory) -> some View { /* B5 / H */ }
}
```

Delete `detailPane`, `pane`, `categorySidebar` and `sidebarSelection` (:207-318), plus `focusedCategory`, `sidebarFocus` and `settingsStyle` (:85-90), which move to the root view. Rewrite the focus-graph doc comment (:14-52) to match B3 and B4.

### B3. `SettingsRootView` (NEW `Screens/Settings/SettingsRootView.swift`)

```swift
struct SettingsRootView: View {
    @Binding var path: [SettingsCategory]
    @Binding var lastCategory: SettingsCategory?
    @AppStorage("settings_style") private var settingsStyle = "default"
    @FocusState private var focusedCategory: SettingsCategory?
    @State private var explained: SettingsCategory = .accountProfiles   // seeded from lastCategory in onAppear
    @Namespace private var rootFocus
}
```

**Layout.** A `VStack(alignment: .leading, spacing: Theme.Spacing.md)`:
- `Text("Settings")` in `Theme.Font.screenTitle` / `textPrimary`, with the padding from today's :96-100.
- Then `GeometryReader { HStack(spacing: Theme.Spacing.xl) { … } }`:
  - Left: `SettingsExplainerColumn(systemImage: explained.icon, title: explained.title, text: Text(explained.summary))`, `.frame(width: max(400, geo.size.width / 3))`. Omitted entirely when `settingsStyle == "minimal"`.
  - Right: the `List`.

**List.**
```swift
List {
    ForEach(SettingsCategoryGroup.allCases, id: \.self) { group in
        SettingsSection(group.title) {
            ForEach(group.categories) { category in
                Button { lastCategory = category; path = [category] } label: { rowLabel(category) }
                    .focused($focusedCategory, equals: category)
                    .prefersDefaultFocus(category == (lastCategory ?? .accountProfiles), in: rootFocus)
                    .accessibilityLabel(Text(category.title))          // keeps app.buttons["Appearance"] etc. resolving
                    .accessibilityHint(Text(category.subtitle))
                    .accessibilityIdentifier("settings_category_\(category.rawValue)")
            }
        }
    }
}
.focusScope(rootFocus)
.environment(\.settingsUsesNativeList, true)
.accessibilityIdentifier("settings_root_list")
.onChange(of: focusedCategory) { _, c in if let c { explained = c } }   // keep the last value when focus leaves to the tab bar
```

**Row label.**
- Default style: `SettingsRowLabel(title: category.title, subtitle: String(localized: category.subtitle), systemImage: category.icon)`. This reuses the kit's accent glyph and platter flip. It has no `descriptionID`; the root explainer is driven by `@FocusState`.
- Minimal style: `SettingsRowLabel(title:, subtitle:)` with no icon. See open question J-9.

### B4. Menu and focus behaviour

- **Push.** The `Button` sets `path = [category]`. Focus lands on the pane List's first focusable row (default focus of a newly pushed view).
- **Menu inside a pane.** Uses the system default: the `NavigationStack`'s UINavigationController pops one level. The pane and scaffold must install no `onExitCommand` and no `.sidebarMenuReveal()`. This is the same mechanism `SettingsLinkRow` sub-pages rely on today (`SettingsRowViews.swift:354-355`, `SettingsView.swift:48-52`). Sub-pages (Custom Posters, Server connection) are value-less `NavigationLink`s inside the path-bound stack. That is allowed: they push on top without appearing in `path`, and Menu pops them first.
- **Pop focus return.** tvOS focus memory usually restores the row. The fallback is the `prefersDefaultFocus(category == lastCategory)` + `.focusScope(rootFocus)` pair: on re-entry the scope's preferred focus is the category the user opened. The same mechanism lands focus correctly after a theme remount followed by Menu.
- **Menu at the root.**
  - Sidebar mode: `.sidebarMenuReveal()` reveals the sidebar (SidebarOverlay.swift:762-809). A second Menu goes to the system default.
  - Tabs mode: the modifier is structurally absent and the system default applies (focus to the tab bar, then exit).
  - This is unchanged from today.
- **Coexistence.** The modifier is on the root content view. Destinations are siblings in the UIKit nav controller, so the root's `onExitCommand` is not in a pane's responder chain. The stack's pop wins inside panes, in both modes. Device-pass item 17 verifies this.

### B5. Interim pane switch (W1-B; keeps the build green until W2 lands)

```swift
// INTERIM (W1-B). Main session replaces this after W2-B and W2-C (see H).
switch category {
case .accountProfiles: Group { accountServicesPane; AdvancedSettingsPane(remote: remote) }
case .services: accountServicesPane            // the existing AccountServicesSettingsPane(...) call from :224-233
case .appearance, .detailPage: AppearanceSettingsPane(model:, badges:, pendingThemeSwatchFocus:, pendingAppearanceRowFocus:)
case .homeScreen: HomeScreenSettingsPane(model: model)
case .player, .subtitlesAudio: PlaybackSettingsPane(model: model)
case .sources: ContentSourcesSettingsPane(model: model, plugins: plugins)
case .about, .developer: AboutSettingsPane()
}
```

---

## C. `SettingsPaneScaffold` (NEW `Screens/Settings/SettingsPaneScaffold.swift`)

```swift
struct SettingsPaneScaffold<Content: View>: View {
    let category: SettingsCategory
    @ViewBuilder let content: () -> Content
    @StateObject private var explainer = SettingsExplainerModel()
    @AppStorage("settings_style") private var settingsStyle = "default"
    // body: VStack(alignment: .leading, spacing: Theme.Spacing.md) {
    //   Text(category.title)  screenTitle / textPrimary, same padding as the root title, id "settings_pane_title"
    //   GeometryReader { HStack(spacing: Theme.Spacing.xl) {
    //     if settingsStyle != "minimal" {
    //       SettingsPaneExplainer(model: explainer, category: category)
    //         .frame(width: max(400, geo.size.width / 3))
    //     }
    //     List { content() }
    //       .environment(\.settingsUsesNativeList, true)
    //       .environment(\.settingsExplainer, explainer)
    //       .frame(maxWidth: .infinity)
    //   } }
    // }
    // .background(Theme.Palette.background.ignoresSafeArea())
    // .accessibilityIdentifier("settings_pane_\(category.rawValue)")
}

/// The ONLY view that observes the model, so a focus change re-renders this column, never the List.
private struct SettingsPaneExplainer: View {
    @ObservedObject var model: SettingsExplainerModel
    let category: SettingsCategory
    // focused != nil → SettingsExplainerColumn(systemImage: entry.systemImage ?? category.icon,
    //                                           title: entry.title,
    //                                           text: Text(SettingsDescriptions.text(for: entry.id)))
    // focused == nil → (category.icon, category.title, Text(category.summary))
}

/// Shared by root and pane. Non-focusable. Accent symbol on an opaque in-content tile
/// (HIG contract: opaque Palette.surface* for in-content fills; accent allowed as an identity moment).
struct SettingsExplainerColumn: View {
    let systemImage: String; let title: String; let text: Text
    // VStack(alignment: .leading, spacing: Theme.Spacing.lg):
    //   RoundedRectangle(cornerRadius: Theme.Radius.card).fill(Theme.Palette.surfaceElevated)
    //     .frame(width: 240, height: 240)
    //     .overlay(Image(systemName:).resizable().scaledToFit().frame(width: 120, height: 120)
    //              .foregroundStyle(Theme.Palette.accent))
    //     .accessibilityHidden(true)
    //   Text(title)  Theme.Font.sectionTitle, textPrimary, id "settings_explainer_title"
    //   text         Theme.Font.body, textSecondary, id "settings_explainer_body"
    //   Spacer()
    // .frame(maxHeight: .infinity, alignment: .top)
    // No custom animation. If one is added later, gate it on Reduce Motion.
}
```

- **Minimal style.** `settings_style == "minimal"` hides the explainer column on both the root and the panes, so the List takes the full width. It also drops the root icons. The model is still injected, which costs nothing.
- **Pushed sub-pages.** `CustomPostersSettingsView` and `ServerConnectionView` are stack destinations, not descendants of the scaffold's List. They get no `settingsExplainer` environment value, so their kit rows no-op, and they keep their own layout.
- **Glass.** The scaffold uses none (HIG contract).

---

## D. Description plumbing

### D1. `SettingsExplainerModel.swift` (NEW, W1-B)

```swift
@MainActor final class SettingsExplainerModel: ObservableObject {
    struct Entry: Equatable { let id: SettingsDescriptionID; let title: String; let systemImage: String?; let owner: UUID }
    @Published private(set) var focused: Entry?
    func didFocus(_ e: Entry) { if focused != e { focused = e } }
    /// Deferred one runloop turn, so the next row's didFocus (same focus transaction) lands first.
    /// Without this the pane summary flashes between rows.
    func didBlur(owner: UUID) {
        DispatchQueue.main.async { [weak self] in if self?.focused?.owner == owner { self?.focused = nil } }
    }
}

private struct SettingsExplainerKey: EnvironmentKey { static let defaultValue: SettingsExplainerModel? = nil }
extension EnvironmentValues { var settingsExplainer: SettingsExplainerModel? { get set } }

struct SettingsDescriptionModifier: ViewModifier {
    let id: SettingsDescriptionID?; let title: String; let systemImage: String?; let explicitFocus: Bool?
    @Environment(\.isFocused) private var envFocused
    @Environment(\.settingsExplainer) private var explainer
    @State private var owner = UUID()   // shared ids (swatches, catalog rows) need a per-instance owner
    func body(content: Content) -> some View {
        let focused = explicitFocus ?? envFocused
        content
            .onChange(of: focused, initial: true) { _, now in
                guard let id, let explainer else { return }
                now ? explainer.didFocus(.init(id: id, title: title, systemImage: systemImage, owner: owner))
                    : explainer.didBlur(owner: owner)
            }
            .onDisappear { explainer?.didBlur(owner: owner) }   // a conditional row removed while focused
    }
}

extension View {
    func settingsDescription(_ id: SettingsDescriptionID?, title: String, systemImage: String? = nil,
                             focused: Bool? = nil) -> some View { modifier(SettingsDescriptionModifier(...)) }
}
```

**Where `\.isFocused` is populated.** It is only populated on the focusable control and its descendants (HomeScreenSettingsPane:404-412 documents this). The modifier must therefore sit inside the control's label:
- `SettingsRowLabel` is the label of Toggle, Menu (inside `LabeledContent`), NavigationLink and Button. That is exactly where the existing `SettingsAccentTint` already reads `\.isFocused` successfully (SettingsRowViews:80-95, used in picker values :315 and glyphs :139). So `SettingsRowLabel` is a valid read site for every kit row.
- For a TextField there is no label descendant. Pass `focused:` from a `@FocusState`.
- Anywhere else (an ancestor of the control), the modifier is inert and falls back to the pane summary. That is safe.

**Why an environment object rather than a PreferenceKey** (see PLAN CONFLICTS J-1). Preferences do not reliably propagate out of tvOS `List` cells, which are UIKit-hosted, or out of `Menu` labels. The environment does cross those boundaries; `settingsRowIsFocused` and `settingsUsesNativeList` already depend on it. Writes happen in `onChange`, never during body evaluation.

### D2. Kit edits (`Screens/Settings/SettingsRowViews.swift`, W1-B)

Every new parameter defaults to `nil`, so all existing call sites still compile.

| Type (line) | Edit |
|---|---|
| `SettingsRowLabel` (:110-157) | Add `var descriptionID: SettingsDescriptionID? = nil` after `iconTint` (:114). Apply `.settingsDescription(descriptionID, title: title, systemImage: systemImage)` to the `HStack` (:133), next to the existing `.environment(\.colorScheme…)` (:155). |
| `SettingsToggleRow` (:255-274) | Stored `descriptionID`. `init(title:subtitle:isOn:descriptionID: = nil)` (:260). Pass it into `SettingsRowLabel` (:268). |
| `SettingsPickerRow` (:280-321) | `init(title:subtitle:selection:options:descriptionID: = nil, label:)`, placed before `label` (:287-299). Pass it at :317. |
| `SettingsValueRow` (:328-350) | `init(title:value:subtitle:systemImage:descriptionID: = nil, focusable: Bool = false)` (:334). When `focusable`, add `.focusable()` to the `LabeledContent`. This is the inert-anchor pattern AboutSettingsPane:545 already uses; Select does nothing (J-2). Pass the id to the label. |
| `SettingsLinkRow` (:356-381) | `init(title:subtitle:systemImage:descriptionID: = nil, destination:)` (:362). Pass it at :378. |
| `SettingsActionRow` (:387-410) | `init(title:subtitle:systemImage:descriptionID: = nil, action:)` (:393). Pass it at :407. |
| `SettingsDestructiveRow` (:414-439) | Same as Action (:420). Pass it at :436. |
| `DebridKeyEntryRow` (:448-477) | Add `var descriptionID: SettingsDescriptionID? = nil` between `placeholder` (:450) and `onSave` (:451), so trailing-closure call sites still compile. Add `@FocusState private var fieldFocused: Bool` + `.focused($fieldFocused)` on the TextField (:460), and `.settingsDescription(descriptionID, title: placeholder ?? providerName, systemImage: "key", focused: fieldFocused)` on the HStack (:456). Inside the Save `Button` label (:471), add `.settingsDescription(descriptionID, title: String(localized: "Save Key"), systemImage: "checkmark")`. |

The plan says "six kit row inits"; there are seven, plus `SettingsRowLabel` itself.

### D3. Catalog: `SettingsDescriptions.swift` (NEW, W1-B)

```swift
enum SettingsDescriptionID: String, CaseIterable {
    case accountSignInOut = "account.signInOut"
    // … every id in table E …
}

enum SettingsDescriptions {
    /// Exhaustive switch: the compiler guarantees every id has copy.
    static func text(for id: SettingsDescriptionID) -> LocalizedStringResource {
        switch id {
        case .accountSignInOut: return LocalizedStringResource("TODO")   // W3-A writes the real text
        // …
        }
    }
}

extension SettingsCategory {
    var subtitle: LocalizedStringResource { switch self { … } }   // drafts from table A
    var summary: LocalizedStringResource { switch self { … } }
}
```

- Use explicit `LocalizedStringResource("English text")` so the compiler emits it to `.stringsdata`. The key is the English text, matching the catalog convention. Verify extraction during W3-B; the fallback is `String(localized:)` with a `String` return type (J-12).
- Display with `Text(resource)` and `String(localized: resource)`.
- Every W1-B placeholder is the same literal, "TODO". That creates one throwaway catalog key, which W3-A replaces.

### D4. Unit test design (`NuvioTVTests/SettingsDescriptionsTests.swift`, NEW)

1. **`testEveryIDHasNonEmptyCopy`.** For each case, `String(localized: SettingsDescriptions.text(for:))` is non-empty.
2. **`testNoPlaceholderCopy`.** No entry equals "TODO". W1-B writes it with `throw XCTSkip("enabled by W3-A")`; W3-A removes the skip.
3. **`testEveryIDIsUsedAndOnlyKnownIDsAreUsed`** (source scan; this is the concrete enumeration mechanism):
   - Root: `URL(fileURLWithPath: #filePath)` → `../../NuvioTV/Screens/Settings/`. Simulator tests run on the host, so the repo path is readable.
   - Read every `*.swift` file and apply the regexes `descriptionID:\s*\.(\w+)` and `settingsDescription\(\s*\.(\w+)`.
   - Map case names with `String(describing: id)`.
   - Assert `Set(allCases names) == used`. The "unknown id" direction is already compile-checked; the "unused copy" direction is what this catches.
   - Rule for authors: ids must be literal `.caseName` at the call site, never computed. A helper such as `autoSkipRow(…, id:)` takes the literal at its call site.
   - W1-B ships this with `XCTSkip` until W2 and W3-A have wired every row; whoever finishes the wiring removes the skip.
4. **`SettingsCategoryTests.swift`:**
   - `allCases` order equals the 10-case list in A.
   - `group` mapping matches A. Each group's categories are contiguous in `allCases`. `SettingsCategoryGroup.allCases == [.you, .look, .watch, .system]`.
   - `title`, `subtitle` and `summary` are non-empty.
   - `UIImage(systemName: icon) != nil` for each category.

---

## E. Complete row-to-pane table

Abbreviations for source files: AS = AccountServicesSettingsPane, ADV = AdvancedSettingsPane, APP = AppearanceSettingsPane, PB = PlaybackSettingsPane, CS = ContentSourcesSettingsPane, AB = AboutSettingsPane, HS = HomeScreenSettingsPane, SB = StreamBadgesSection, MLC = MdbListActivationCard.

"K" = kit row (gets `descriptionID:`). "C" = custom row: it either gets the modifier at the stated site or falls back to the pane summary. "—" = non-focusable (caption, value row or readout); no id, summary fallback.

Ids are written without the enum: `account.signInOut` is case `accountSignInOut`. For case names, camel-case the raw value and drop the dots.

### Account & Profiles (W2-B, NEW `AccountProfilesSettingsPane.swift`)

Signature: `init(remote: RemoteSetupViewModel, confirmingSignOut: Binding<Bool>, confirmingUseOfficial: Binding<Bool>)`. It uses `@EnvironmentObject auth` and `@StateObject server = ActiveServerObserver()` (moved from AS:14).

| Section | Row (source) | Kind | id |
|---|---|---|---|
| Account | Sign In to Nuvio (AS:34) / Sign Out (AS:42) | K Action / Destructive | account.signInOut |
| Server | Server value (AS:110) | — | — |
| Server | Connect to Another / Self-Hosted Server (AS:117, pushes ServerConnectionView) | K Link | account.connectServer |
| Server | Use Official Server (AS:127) | K Destructive | account.useOfficialServer |
| Remote Setup | caption (ADV:21), QR + URL block (ADV:27-47) | — | — |
| Remote Setup | Stop Remote Setup (ADV:48) / Start Remote Setup (ADV:56) | K Action | account.remoteSetup |

### Services (W2-B, NEW `ServicesSettingsPane.swift`)

Signature: `init(trakt:, simkl:, debrid:, confirmingTraktDisconnect: Binding<Bool>, confirmingSimklDisconnect: Binding<Bool>, debridDisconnectId: Binding<String?>)`. It owns `@StateObject mdblist = MdbListViewModel()` and `@State confirmingMdbListDisconnect` (AS:16-17). Keep `.onAppear { debrid.revalidateConnected() }` (AS:101). Move these private types verbatim: `SimklSyncNowRow`, `SimklSyncInfoRow`, `SimklAnimeIdOptions`, `TraktActivationCard`, `SimklActivationCard`, `DebridActivationCard` (AS:471-698), and `prepareLimitLabel` (AS:384).

Section order: Trakt, Simkl, MDBList, More Like This, Debrid (the order today, minus Account and Server).

| Section | Row (source) | Kind | id |
|---|---|---|---|
| Trakt | not-configured caption (AS:142), intro (AS:162), error (AS:173) | — | — |
| Trakt | Disconnect Trakt (AS:147) / Connect Trakt (AS:166) | K | services.trakt |
| Trakt | TraktActivationCard Cancel (AS:604) | K Action | services.activationCancel |
| Simkl | captions (AS:193, :243, :265), errors (:216, :254) | — | — |
| Simkl | Disconnect Simkl (AS:198) / Connect Simkl (AS:247) | K | services.simkl |
| Simkl | Sync Now (SimklSyncNowRow, kit at AS:499) | K (pass id through the wrapper) | services.simklSyncNow |
| Simkl | How Syncing Works (SimklSyncInfoRow, kit at AS:528) | K | services.simklSyncInfo |
| Simkl | Anime ID Preference (AS:225) | K Picker | services.simklAnimeId |
| Simkl | SimklActivationCard Cancel (AS:647) | K | services.activationCancel |
| MDBList | "Not configured" value (AS:275), errors | — | — |
| MDBList | Disconnect (AS:281) / Connect MDBList (AS:307) | K | services.mdblist |
| MDBList | MdbListActivationCard Cancel (MLC; W2-B adds the id there) | K | services.activationCancel |
| More Like This | Source (AS:77) | K Picker (simkl VM) | services.moreLikeThisSource |
| Debrid | intro (AS:335), caption (:363), progress (:420), failure (:437) | — | — |
| Debrid | `<Provider>` Session expired (AS:399) / Connected (AS:407) / Connect `<Provider>` (AS:452) | K | services.debridProvider |
| Debrid | DebridActivationCard Cancel (AS:688) | K | services.activationCancel |
| Debrid | Dismiss (AS:441) | K | services.debridDismiss |
| Debrid | DebridKeyEntryRow (AS:459) | K | services.debridKey |
| Debrid | Resolve Streams with Debrid (AS:345) | K Toggle | services.debridResolve |
| Debrid | Prepare Links for Instant Playback (AS:356) | K Picker | services.debridPrepare |
| Debrid | Preferred resolver (AS:370) | K Picker | services.debridResolver |

### Appearance (W2-B, trim `AppearanceSettingsPane.swift`)

The signature is unchanged. Delete the Detail rows APP:292-336 and their storage: :35-44 (`detail_trailer_autoplay`, `detail_poster_backdrop`, `detail_trailer_background`, `detail_trailer_duration`, `detail_action_icons_only`), `trailerDurationOptions` (:79-84) and `episodeRatingsOptions` (:85-94). These move to the Detail Page pane.

| Section | Row (source) | Kind | id |
|---|---|---|---|
| Theme | caption (:161) | — | — |
| Theme | ThemePickerRow swatches (:165) | C: `.settingsDescription(.appearanceTheme, title: String(localized: "Theme"))` inside `SwatchLabel.body` (:435), so all 7 swatches share it | appearance.theme |
| Theme | Accent Focus Ring (:182) | K | appearance.accentFocusRing |
| Theme | Ring Takes Poster Color (:191) | K | appearance.ringPosterColor |
| Theme | Depth Takes Poster Color (:200) | K | appearance.depthPosterColor |
| Theme | No Zoom on Focus (:212) | K | appearance.noZoomOnFocus |
| Theme | OLED True Black (:222) | K | appearance.oledBlack |
| Theme | Settings Style (:234) | K | appearance.settingsStyle |
| Theme | Navigation (:244, keep id `appearance_row_navigation` + `.focused`) | K | appearance.navigation |
| Theme | Typeface (:258, keep `appearance_row_typeface`) | K | appearance.typeface |
| Poster Style | Size (:495) | K | appearance.posterSize |
| Poster Style | Corners (:501) | K | appearance.posterCorners |
| Poster Style | Hide Titles (:508) | K | appearance.hideTitles |
| Poster Style | Landscape Rows (:513) | K | appearance.landscapeRows |
| Poster Style | Reset to Defaults (:519) | K | appearance.posterReset |
| Poster Style | Hide Hero Artwork While Browsing (:287) | K | appearance.hideHeroArtwork |
| Custom Posters | Custom Posters link (:340) | K | appearance.customPosters |
| Card Depth | captions (:563, :593) | — | — |
| Card Depth | Card Depth (:567) | K | appearance.cardDepth |
| Card Depth | Edge (:574) | K | appearance.cardDepthEdge |
| Card Depth | Sheen (:580) | K | appearance.cardDepthSheen |
| Card Depth | Edge Coverage (:586) | K | appearance.cardDepthCoverage |
| Card Depth | per-surface toggles (:596) | K (shared) | appearance.cardDepthSurface |
| Card Depth | Reset to Defaults (:605) | K | appearance.cardDepthReset |
| Stream Badges | caption (SB:18, copy edit in G), empty text (SB:42), status (SB:81) | — | — |
| Stream Badges | File Size Badges (SB:23) | K | appearance.badgesFileSize |
| Stream Badges | Show Add-on Logo (SB:28) | K | appearance.badgesAddonLogo |
| Stream Badges | Badges Above Title (SB:33) | K | appearance.badgesAboveTitle |
| Stream Badges | pack row: Set Active (SB:64) and trash (SB:68) chip buttons | C: modifier on each button label | appearance.badgePack |
| Stream Badges | BadgeUrlEntryRow (SB:79): TextField + Import button | C: `focused:` variant on the field, modifier on the Import label | appearance.badgeImport |

### Home Screen (unchanged pane; W1-B wires ids in `HomeScreenSettingsPane.swift` as the Gate-1 proof)

| Row (source) | Kind | id |
|---|---|---|
| Upcoming Episodes (HS:58) | K | home.upcoming |
| empty-state text (HS:67), location captions (:287, :296) | — | — |
| Refresh Add-ons (HS:87) | K | home.refreshAddons |
| Show Hero (HS:102) | K | home.showHero |
| Nuvio-Style Hero (HS:124) | K | home.nuvioStyleHero |
| Hero Sources disclosure (HS:153) | C: `SettingsDisclosureRow` gets `descriptionID` and passes it to its `SettingsRowLabel` (HS:360) | home.heroSources |
| HeroSourceRow (HS:163) | C: pass it through `HeroSourceRowLabel` → `SettingsRowLabel` (HS:453) | home.heroSource |
| Trailers on Focus (HS:174) | K | home.trailersOnFocus |
| Trailer Location (HS:277) | K | home.trailerLocation |
| Autoplay Hero Trailer (HS:192) | K | home.heroTrailerAutoplay |
| Show Catalog Type in Titles (HS:200) | K | home.catalogType |
| Catalogs disclosure (HS:220) | C (same as Hero Sources) | home.catalogs |
| CatalogSettingRow (HS:230) | C: pass it to `SettingsRowLabel` at HS:484 | home.catalog |

### Detail Page (W2-B, NEW `DetailPageSettingsPane.swift`)

Signature: `init(model: SettingsViewModel)`.

| Section | Row (source) | Kind | Storage | id |
|---|---|---|---|---|
| Layout | **Detail Layout** (NEW): Cinematic / Classic | K Picker | `@AppStorage("detail_layout")` String, default `"cinematic"`, values `"cinematic"` / `"classic"` (must match P1) | detail.layout |
| Layout | Icon-Only Detail Buttons (APP:319) | K | `detail_action_icons_only` = false | detail.iconOnlyButtons |
| Layout | Poster in Detail Background (APP:313) | K | `detail_poster_backdrop` = true | detail.posterBackdrop |
| Trailers | Auto-Play Trailer on Detail (APP:292) | K | `detail_trailer_autoplay` = true | detail.trailerAutoplay |
| Trailers | Background Trailer on Detail (APP:299) | K | `detail_trailer_background` = true | detail.trailerBackground |
| Trailers | Trailer Duration, shown only if background trailer is on (APP:305-312) | K | `detail_trailer_duration` = 0 | detail.trailerDuration |
| Trailers | Trailer Sound by Default (PB:83-96; keep the `HeroTrailerAudioState.shared.setMuted(value: !newValue)` side effect) | K | `trailer_audio_default_on` = false | detail.trailerSound |
| Episodes | Episode Ratings (APP:327) | K | `model.episodeRatingsVisibility` (synced) | detail.episodeRatings |
| Episodes | **Hide Spoilers in Unwatched Episodes** (NEW) | K | proposed `detail_hide_spoilers` = false. **W1-C owns this key; it must match.** | detail.hideSpoilers |
| Sections (footer: "Episodes always shows.") | Studio Logos | K | `detail_section_logos` = true | detail.sectionLogos |
| | Parental Guide | K | `detail_section_parental` = true | detail.sectionParental |
| | Ratings | K | `detail_section_ratings` = true | detail.sectionRatings |
| | Cast | K | `detail_section_cast` = true | detail.sectionCast |
| | Collection | K | `detail_section_collection` = true | detail.sectionCollection |
| | Trailers & Extras | K | `detail_section_trailers` = true | detail.sectionTrailers |
| | More Like This | K | `detail_section_more_like_this` = true | detail.sectionMoreLikeThis |
| | Comments | K | `detail_section_comments` = true | detail.sectionComments |
| | About | K | `detail_section_about` = true | detail.sectionAbout |

**The `detail_section_*` names are proposals and must match P1's keys.** The main session reconciles them before W2-B starts. Recommendation: P1 defines a shared `enum DetailSectionKeys` (static let strings) in a Detail-owned file, and this pane reads the keys from there instead of using literals. Keep the existing row labels verbatim, because test04 matches on "Auto-Play Trailer on Detail" and "Poster in Detail Background".

### Player (W2-C, NEW `PlayerSettingsPane.swift`)

Signature: `init(model: SettingsViewModel)`. Move `DefaultPlayerRow` (PB:317-360), `bufferLabel` / `readaheadLabel` (PB:243-261) and `autoSkipRow` (PB:235, gains an `id:` parameter) verbatim.

| Section | Row (source) | Kind | id |
|---|---|---|---|
| Playback | Default Player (DefaultPlayerRow, kit at PB:335) | C wrapper → K (pass id) | player.defaultPlayer |
| Playback | Skip Intro (PB:32) | K | player.skipIntro |
| Playback | Auto-Skip Intros / Recaps / Outros / Movie Credits (PB:40-47) | K | player.autoSkipIntro, player.autoSkipRecap, player.autoSkipOutro, player.autoSkipCredits |
| Playback | Episode Shuffle (PB:49) | K | player.episodeShuffle |
| Playback | Pause Info Card (PB:100) | K | player.pauseInfoCard |
| Video | Match Content Frame Rate (PB:55) | K | player.matchFrameRate |
| Video | Enhanced Video Renderer (PB:60) | K | player.enhancedRenderer |
| Video | Native player (Dolby Vision & HDR) (PB:65) | K | player.nativeDolbyVision |
| Video | Keep Profile 7 FEL on mpv (PB:71) | K | player.p7FelMpv |
| Buffering | Streaming Buffer (PB:106) | K | player.streamingBuffer |
| Buffering | Network Readahead (PB:112) | K | player.networkReadahead |
| Buffering | caption (PB:118) | — | — |
| Next Episode (footer from PB:146) | Preload Next Episode Sources (PB:148) | K | player.preloadNextEpisode (J-3) |

### Sources (W2-C, NEW `SourcesSettingsPane.swift`)

Signature: `init(model: SettingsViewModel, plugins: PluginsViewModel)`. It absorbs every CS section. Move `SourceSettingOptions` (PB:268-298), `librarySourceLabels` / `watchProgressSourceLabels` (CS:139-150) and `PluginRepoEntryRow` (CS:339-376). Wrap the pane body in `Group` (7 sections).

| Section | Row (source) | Kind | id |
|---|---|---|---|
| Auto-Play Source (footer PB:128) | Auto-Play Best Source (PB:130) | K | sources.autoPlayBest |
| | Cached Sources Only (PB:135) | K | sources.autoPlayCachedOnly |
| Source Filters (header renamed from "Sources"; footer PB:158) | Sort Sources (PB:160) | K | sources.sort |
| | Minimum Resolution (PB:166) | K | sources.minResolution |
| | Dolby Vision (PB:173) | K | sources.dvFilter |
| | HDR (PB:179) | K | sources.hdrFilter |
| | Cached Sources Only (PB:188) | K | sources.cachedOnlyFilter |
| Metadata (TMDB) | captions (CS:14, :39, :54) | — | — |
| | TMDB Enrichment (CS:19) | K | sources.tmdbEnrichment |
| | Remove Personal API Key (CS:28) / DebridKeyEntryRow (CS:36) | K | sources.tmdbKey |
| | TMDB Release Dates (CS:44) | K | sources.tmdbReleaseDates |
| | Metadata Language (CS:58) | K | sources.tmdbLanguage |
| Ratings (MDBList) | captions (CS:70 and :98, copy edits; :93, :112) | — | — |
| | MDBList Ratings (CS:75) | K | sources.mdblistRatings |
| | Remove API Key (CS:84) / DebridKeyEntryRow (CS:103) | K | sources.mdblistKey |
| Library & Watch Progress | caption (CS:159, copy edit) | — | — |
| | Library Source (CS:164) | K | sources.librarySource |
| | Watch Progress Source (CS:174) | K | sources.watchProgressSource |
| Search Sources | Recent Searches (CS:193) | K | sources.recentSearches |
| | Hide Discover (CS:207) | K | sources.hideDiscover |
| | captions (CS:218, :224), fan-out text (CS:249) | — | — |
| | per-catalog toggles (CS:232) | K (shared) | sources.searchCatalog |
| Plugins | caption (CS:260), status (:276), empty (:283) | — | — |
| | Enable Plugins (CS:265) | K | sources.pluginsEnabled |
| | PluginRepoEntryRow (CS:274) | C: `focused:` variant on the field, modifier on the Install label | sources.pluginRepoAdd |
| | repo trash chip (CS:299) | C: modifier inside the trash label | sources.pluginRepo |
| | scraper toggles (CS:313) | K | sources.pluginScraper |
| | Refresh Plugins (CS:326) | K | sources.pluginsRefresh |

### Subtitles & Audio (W2-C, NEW `SubtitlesAudioSettingsPane.swift`)

Signature: `init(model: SettingsViewModel)`. Move `SubtitleAppearanceControls` (PB:368-468) and `SubtitleColorSwatch` (PB:473-495). The pane body for the Subtitles section keeps PB:197-211 (including the "Loading subtitle settings…" fallback text).

| Section | Row (source) | Kind | id |
|---|---|---|---|
| Subtitles | preview (PB:435), "Text Color" caption (PB:452) | — | — |
| Subtitles | Text Color swatches (PB:393) | C: modifier inside `SubtitleColorSwatch.body` | subtitles.textColor |
| Subtitles | Size (PB:404) | K | subtitles.size |
| Subtitles | Background (PB:411) | K | subtitles.background |
| Subtitles | Bold (PB:418) | K | subtitles.bold |
| Subtitles | Outline (PB:423) | K | subtitles.outline |
| Subtitles | Strip SDH Subtitles (PB:428) | K | subtitles.stripSdh |
| Audio & Subtitle Language | caption (PB:215) | — | — |
| Audio & Subtitle Language | Audio (PB:219) | K | subtitles.audioLanguage |
| Audio & Subtitle Language | Subtitles (PB:225) | K | subtitles.subtitleLanguage |

### About (W2-C, trim `AboutSettingsPane.swift` to AB:174-199, the AB:346 Fonts row and the static helpers AB:689-720)

All rows are `SettingsValueRow(..., focusable: true)` (J-2).

| Row (source) | id |
|---|---|
| Version (AB:176) | about.version |
| Build (AB:180) | about.build |
| Commit (AB:184) | about.commit |
| tvOS (AB:188) | about.tvos |
| Device (AB:192) | about.device |
| Source (AB:196) | about.source |
| Fonts (AB:346) | about.fonts (J-3) |

### Developer (W2-C, NEW `DeveloperSettingsPane.swift`)

- **Move verbatim:** every property in AB:9-119 except the About statics; `detailScrollAndTrailerTuningRows` (AB:121-167); `trailerZoomCacheCount` (AB:169-172); `.onAppear` (AB:679-683); and `.onChange(of: streamDiagnostics)` (AB:686).
- **Body:** one `SettingsSection(String(localized: "Diagnostics"))` containing AB:201-677 in the same order, minus the six value rows and Fonts.
- **AX ids are byte-identical:** `hero_probe_lines`, `hero_probe_blob`, `tab_bar_probe_lines`, `stream_probe_lines`, `trailer_probe_lines`, `trailer_probe_blob`, `collection_frame_probe_lines`, `collection_frame_blob`, `settle_probe_lines`, `settle_probe_page_N`, `settle_probe_blob`, `tab_bar_state_probe_lines`, `tab_bar_state_probe_page_N`, `tab_bar_state_probe_blob`.
- **Launch-arg live read:** keep `if collectionFrameProbe || CollectionFocusFrameProbe.enabled` (AB:427) exactly. It is the only readout today that ORs in a live read; the others stay as they are (J-8).

| Row (source) | Kind | id |
|---|---|---|
| Hero Paint Diagnostics (AB:201) + readout (:209) | K / — | dev.heroPaint |
| Tab Bar Diagnostics (AB:247) + readout (:264) | K / — | dev.tabBarDiag |
| Hard Top Scroll Edge (A/B) (AB:258) | K | dev.hardTopEdge |
| Stream Diagnostics (AB:295) + readout (:303) | K / — | dev.streamDiag |
| Focus Mode / No Zoom on Focus / Accent Focus Ring values (AB:329-340) | — | — |
| Trailer Diagnostics (AB:356) + readout (:364) | K / — | dev.trailerDiag |
| Trailer zoom cache value (AB:399) | — | — |
| Reset trailer zoom cache (AB:406) | K | dev.trailerCacheReset |
| Detail Scroll A/B (AB:125) | K | dev.detailScrollAB |
| Detail Scroll Probe (AB:134) | K | dev.detailScrollProbe |
| Trailer Max FPS (A/B) (AB:142) | K | dev.trailerMaxFps |
| Trailer Buffer (A/B) (AB:152) | K | dev.trailerBuffer |
| Trailer Letterbox Probe Off (A/B) (AB:162) | K | dev.trailerLetterbox |
| Collection Frame Probe (AB:417) + readout (:430) | K / — | dev.collectionProbe |
| Clear (AB:464) | K | dev.collectionProbeClear |
| Collection Focus A/B (AB:469) | K | dev.collectionAB |
| Row Settle Diagnostics (AB:491) + paged readout (:498-562, focusable pages, no id) | K / — | dev.rowSettle |
| Tab Bar Geometry Diagnostics (AB:571) + pages (:579-619) | K / — | dev.tabBarGeometry |
| No Zoom Row Reach (A/B) (AB:625) | K | dev.noZoomReach |
| Row Edge Fade (AB:637) | K | dev.rowEdgeFade |
| Short Row Floor (A/B) (AB:661) | K | dev.shortRowFloor |
| Tab Bar Scroll Link (A/B) (AB:671) | K | dev.tabBarScrollLink |

Total: about 128 description ids plus 10 summaries.

---

## F. ViewBuilder child counts (10-child ceiling)

A conditional `if`/`else` counts as one child. Kit-internal composites (`PosterStyleControls`, `CardDepthControls`, `SubtitleAppearanceControls`, `StreamBadgesSection`) each count as one child of their section.

| Pane | Section | Children | Nesting needed |
|---|---|---|---|
| Account & Profiles | Account | 1 (if/else) | — |
| | Server | 3 | — |
| | Remote Setup | 2 (caption + if/else) | — |
| Services | Trakt / Simkl / MDBList | same as AS today (≤ 3 top level; Simkl's connected branch has 6 inside the if) | — |
| | More Like This | 1 | — |
| | Debrid | 4 | — |
| Appearance | Theme | **10** (unchanged, at the ceiling; add nothing) | — |
| | Poster Style | **2** (was 9) | — |
| | Custom Posters / Card Depth / Stream Badges | 1 each | — |
| Detail Page | Layout | 3 | — |
| | Trailers | 4 | — |
| | Episodes | 2 | — |
| | Sections | 9 | none (adding a 10th section toggle fits; an 11th needs a `Group`) |
| Player | Playback | 5 (DefaultPlayer, Skip Intro, `if` with 4 auto-skips, Episode Shuffle, Pause Info Card) | drop PB's `Group`s; the `if` is one child |
| | Video | 4 | — |
| | Buffering | 3 | — |
| | Next Episode | 1 | — |
| Sources | Auto-Play Source | 2 | — |
| | Source Filters | 5 | — |
| | Metadata (TMDB) | 6 | — |
| | Ratings (MDBList) | 3 | — |
| | Library | 1 (`librarySection`) | — |
| | Search | 1 (`searchSourcesSection`) | — |
| | Plugins | 1 (`pluginsSection`) | — |
| | pane body | 7 sections | wrap in `Group` as CS:12 does |
| Subtitles & Audio | Subtitles | 1 (if/else) | — |
| | Language | 3 | — |
| About | About | 7 | — |
| Developer | Diagnostics | 4 (hero toggle, hero readout, Group A AB:246-350 minus Fonts, Group B AB:355-677) | Group A drops from 10 to 9 children (Fonts removed). Group B and its inner Group stay exactly as today. |
| Root | per group | ≤ 3 (`ForEach`) | — |

---

## G. Cross-reference string edits (W2-C unless noted)

| File:line | Old | New |
|---|---|---|
| `Screens/StreamsViewModel.swift:168` | "…Reconnect in Settings → Account & Services → Debrid." | "…Reconnect in Settings → Services → Debrid." |
| `Screens/StreamsViewModel.swift:249` | "Connect one in Settings → Account & Services → Debrid, or turn on “Resolve Streams with Debrid”." | "Connect one in Settings → Services → Debrid, or turn on “Resolve Streams with Debrid”." |
| `Screens/StreamsViewModel.swift:265` | "Add one in Settings → Content Sources → Addons." | "Add one in the Add-ons tab." (J-6: add-ons were never in Settings) |
| `Screens/StreamPickerView.swift:749` | "…Connect one in Settings → Debrid." | "…Connect one in Settings → Services → Debrid." |
| `Screens/StreamPickerView.swift:809` | same as :749 | same as :749 |
| `Screens/StreamPickerView.swift:1159` | "Connect an account in Settings." | "Connect an account in Settings → Services → Debrid." |
| `Screens/CloudLibraryUI.swift:61` | "…reconnect in Settings → Debrid." | "…reconnect in Settings → Services → Debrid." |
| `Screens/ServerConnectionViewModel.swift:204` | "…Use “Use Official Server” in Settings to switch back." | "…Use “Use Official Server” in Settings → Account & Profiles to switch back." |
| ContentSources `:70` → Sources pane (W2-C) | "Connect MDBList in Account & Services, or add a free API key…" | "Connect MDBList in Services, or add a free API key…" |
| ContentSources `:98` → Sources pane (W2-C) | "Connect MDBList in Account & Services, or enter a key." | "Connect MDBList in Services, or enter a key." |
| ContentSources `:159` → Sources pane (W2-C) | "…Connect Trakt, Simkl, or MDBList in Account & Services first…" | "…Connect Trakt, Simkl, or MDBList in Services first…" |
| `StreamBadgesSection.swift:18` (**W2-B**, see J-5) | "Tip: Remote Setup (Advanced) lets you…" | "Tip: Remote Setup (Account & Profiles) lets you…" |

Every new string goes to W3-B for translation. Stale old keys stay in the catalog harmlessly, because the populate script preserves existing entries.

Doc comments only (optional, no copy impact): ServerConnectionView.swift:4-5, SettingsViewModel.swift:62/92/100/104, and other "Settings → Playback" comments.

---

## H. Work split

### W1-B (Sonnet). Runs concurrently with W1-A (owns `DetailView.swift` and `Screens/Detail/*`) and W1-C (owns `EpisodesSection.swift`); no overlap.

**Owns:**
- NEW `Screens/Settings/SettingsRootView.swift`
- NEW `Screens/Settings/SettingsPaneScaffold.swift` (includes `SettingsExplainerColumn`)
- NEW `Screens/Settings/SettingsExplainerModel.swift` (model, environment key, modifier)
- NEW `Screens/Settings/SettingsDescriptions.swift` (full id enum from E with "TODO" copy; category subtitles and summaries from A)
- `Screens/SettingsView.swift` (whole file)
- `Screens/Settings/SettingsRowViews.swift` (D2 only)
- `Screens/Settings/HomeScreenSettingsPane.swift` (id wiring only)
- `ContentView.swift` (B1 sites only)
- NEW `NuvioTVTests/SettingsCategoryTests.swift`, `NuvioTVTests/SettingsDescriptionsTests.swift`

**Ordered edits:**
1. `SettingsDescriptions.swift` (the enum is needed by every later step).
2. `SettingsExplainerModel.swift`.
3. `SettingsRowViews.swift`: the D2 rows, top to bottom.
4. `SettingsPaneScaffold.swift`.
5. `SettingsRootView.swift`.
6. `SettingsView.swift`: the enum at :321 (A), then the body (B2), then the interim switch (B5), then the doc comment.
7. `ContentView.swift`: :34-40, then :102, then :326-329, then :396-400.
8. HomeScreen ids.
9. Tests.

**Do not touch:** any other `*SettingsPane.swift`, `StreamBadgesSection.swift`, `CustomPostersSettingsView.swift`, `Localizable.xcstrings`, `DetailView.swift`, `Screens/Detail/*`, `EpisodesSection.swift`, or UI tests.

### W2-B (Sonnet). Disjoint from W2-C.

**Owns:**
- NEW `AccountProfilesSettingsPane.swift`, `ServicesSettingsPane.swift`, `DetailPageSettingsPane.swift`
- DELETE `AccountServicesSettingsPane.swift` (everything moved) and `AdvancedSettingsPane.swift`
- `AppearanceSettingsPane.swift` (trim + ids)
- `StreamBadgesSection.swift` (copy + ids)
- `MdbListActivationCard.swift` (Cancel id)

**Order:**
1. Create AccountProfiles from AS:31-54, AS:104-135 and ADV:11-66.
2. Create Services from AS:56-97 and AS:137-698.
3. Create DetailPage: rows from APP:292-336 and PB:83-96, plus the new rows. Its `@AppStorage` keys carry the defaults in E.
4. Delete the two old files.
5. Trim Appearance.
6. StreamBadges.

Wire `descriptionID:` as each row is written: the enum exists after W1-B, which saves W3-A a pass. Do not touch `PlaybackSettingsPane.swift`; W2-C deletes the Trailer Sound row along with that file.

### W2-C (Sonnet)

**Owns:**
- NEW `PlayerSettingsPane.swift`, `SourcesSettingsPane.swift`, `SubtitlesAudioSettingsPane.swift`, `DeveloperSettingsPane.swift`
- DELETE `PlaybackSettingsPane.swift` and `ContentSourcesSettingsPane.swift` (all content moved)
- `AboutSettingsPane.swift` (trim)
- `StreamsViewModel.swift`, `StreamPickerView.swift`, `CloudLibraryUI.swift`, `ServerConnectionViewModel.swift` (G edits only)

**Order:** Player, then Sources, then SubtitlesAudio, then Developer (copy AB first), then trim About, then delete the two files, then G.

### Main session, after W2-B and W2-C land (before the Gate-2 build)

Replace the B5 interim switch with:

```swift
@ViewBuilder private func paneContent(_ category: SettingsCategory) -> some View {
    switch category {
    case .accountProfiles: AccountProfilesSettingsPane(remote: remote, confirmingSignOut: $confirmingSignOut, confirmingUseOfficial: $confirmingUseOfficial)
    case .services: ServicesSettingsPane(trakt: trakt, simkl: simkl, debrid: debrid, confirmingTraktDisconnect: $confirmingTraktDisconnect, confirmingSimklDisconnect: $confirmingSimklDisconnect, debridDisconnectId: $debridDisconnectId)
    case .appearance: AppearanceSettingsPane(model: model, badges: badges, pendingThemeSwatchFocus: $pendingThemeSwatchFocus, pendingAppearanceRowFocus: $pendingAppearanceRowFocus)
    case .homeScreen: HomeScreenSettingsPane(model: model)
    case .detailPage: DetailPageSettingsPane(model: model)
    case .player: PlayerSettingsPane(model: model)
    case .sources: SourcesSettingsPane(model: model, plugins: plugins)
    case .subtitlesAudio: SubtitlesAudioSettingsPane(model: model)
    case .about: AboutSettingsPane()
    case .developer: DeveloperSettingsPane()
    }
}
```

`auth` reaches the panes through the environment; `.environmentObject(auth)` at ContentView:111 propagates into stack destinations. W2 deletes files the interim switch references, so this swap must happen before the first build after W2.

### W3-A

- Writes the copy for every `SettingsDescriptionID` and the 10 summaries and subtitles.
- Wires any ids W2 skipped.
- Removes the two `XCTSkip`s in `SettingsDescriptionsTests`.

---

## I. Test migration

**Root walk order** (focusable rows from the top; section headers are not focusable):
0 Account & Profiles, 1 Services, 2 Appearance, 3 Home Screen, 4 Detail Page, 5 Player, 6 Sources, 7 Subtitles & Audio, 8 About, 9 Developer.

Root `Button`s carry `accessibilityLabel(title)`, so `app.buttons["Appearance"]` and `app.cells["Appearance"]`, and therefore the existing `moveToSidebarRow`, keep resolving at the root.

### New helpers

Add one copy per file that has its own private `openTab`: NuvioTVUITests, FixtureSetupTests, PinnedRowSettleRegimeTests, HeroOffLaunchTests, HeroFolderSwapTests, HeroLogoFocusTests, TabBarScrollLinkTests, ScratchServerSwitchTests.

```swift
@discardableResult
private func openSettingsCategory(_ app: XCUIApplication, named title: String, raw: String) -> Bool {
    openTab(app, named: "Settings")          // existing helper; ends with one Down into content
    // The path persists across tab switches: pop any open pane (Menu only while the root is absent;
    // never Menu at the root, which reveals the sidebar or exits).
    for _ in 0..<3 where !app.descendants(matching: .any)["settings_root_list"].exists {
        remote.press(.menu); pause(1.2)
    }
    if !moveToSidebarRow(app, .down, named: title, max: 12) { _ = moveToSidebarRow(app, .up, named: title, max: 12) }
    remote.press(.select); pause(1.5)
    return app.descendants(matching: .any)["settings_pane_\(raw)"].waitForExistence(timeout: 4)
}

private func openDeveloper(_ app: XCUIApplication) -> Bool {
    openSettingsCategory(app, named: "Developer", raw: "developer")
}
```

### `walkToRowByTreeIndex` (NuvioTVUITests:2774-2884)

- Callers pass `sidebarMaxX: 0`. The explainer has no `Cell`s, so every cell with `minX > 20` belongs to the pane List.
- Replace the sidebar-recovery branch (:2822-2830) with: "if `settings_root_list` exists, call `openSettingsCategory(app, named: category, raw:)`". This needs a title-to-raw lookup table in the test file.
- Delete every `press(.right)` that followed a sidebar Select. Push lands on the first row. Right is a no-op on rows, but on the swatch row it would move one swatch.

### Per-test notes

**Appearance pane head is unchanged.** Theme section, then Poster Style Size / Corners / Hide Titles. So:
- FixtureSetup `walkFromSwatchesToSizeRow` stays Down ×7 (Fixture:250).
- `walkFromSwatchesToHideTitlesRow` stays Down ×9 (Fixture:309).
- test53's Down ×5 is unchanged.

| Test (file:line) | Migration |
|---|---|
| test00z (NuvioTVUITests:587) | `openSettingsCategory("Home Screen")`; drop the Appearance + Down ×1 + Right. The up-walk to Show Hero is unchanged. |
| test04 (:630) | `openSettingsCategory("Detail Page")`; walk to "Auto-Play Trailer on Detail" then "Poster in Detail Background" (`sidebarMaxX: 0`, category "Detail Page"). Home Screen leg: replace :686-694 (Left, Up-anchor, Down ×3, Right) with Menu (pops to root, focus on Detail Page), then Up ×1 (Home Screen, index 3), then Select. Rest unchanged. |
| test05 (:710) | Unchanged counts: cold root default focus is index 0, so Down ×2 reaches index 2, Appearance ("Darstellung"); Select pushes; Down ×3 scrolls. |
| test07, 09, 11, 12, 13, 18, 26, 27, 28, 30, 32, 36 (Appearance walkers at :756, :840, :982, :900, :930, :1206, :3164, :2703, :2662, :2581, :2432, :3225) | Replace `moveToSidebarRow(…"Appearance")` + Select + Right with `openSettingsCategory("Appearance")`. Any `sidebarX` becomes 0. Any Left-to-sidebar move becomes Menu. test13's `press(.left, times: 8)` at :948 is a swatch walk; keep it. |
| test16 (:1086) | Appearance leg unchanged (Accent Focus Ring, Hide Hero Artwork). Content Sources leg: Menu, then `openSettingsCategory("Sources")`, then `walkToRowByTreeIndex("Recent Searches", 0, "Sources")` instead of Down ×10. Search now sits behind about 15 focusable rows (Auto-Play 2, Filters 5, TMDB 4, MDBList 2–3, Library 2). |
| test25 (:1850) | `openSettingsCategory("Home Screen")`. The pane is unchanged, but entry now lands on the first row (Upcoming Episodes) instead of the row nearest the sidebar Y. Re-check its fixed counts against a first-row start. |
| test29 (:2617) | `openContentSources()` becomes `openSettingsCategory("Sources")`; `ensureToggleRow(... sidebarMaxX: 0, category: "Sources")`. |
| test35 (:3028) | `openSettingsCategory("Account & Profiles")`; walk to "Connect to a Self-Hosted Server" (one Down from Sign In/Out, because the Server value row is not focusable). Update the failure string. |
| test40 (:3576) | **Rewrite as a root/pane/pop graph.** On entry, assert `settings_root_list` exists and `settings_category_accountProfiles` exists. Down ×9: Developer cell focused. Up ×1: About. Select: `settings_pane_about` exists. Menu: `settings_root_list` exists AND `app.cells["About"]` hasFocus (pop focus return). Menu again (tabs mode): app is foreground and `app.buttons["Settings"]` exists. |
| test43 (:4102) | `openSettingsCategory("Appearance")`, then `moveFocus(.right → Emerald)`. After the remount, additionally assert `settings_pane_appearance` exists (path restored). Replace the `43d` Left with Menu and assert `app.cells["Appearance"].hasFocus`. Relaunch leg: `openSettingsCategory` then `moveFocus(.left → Crimson)`. |
| test45 (:4186) | `openSettingsCategory("Home Screen")`; walk with `sidebarMaxX: 0`. |
| test53 (:7095) | `openSettingsCategory("Appearance")`, drop Right; Down ×5 unchanged. |
| test54 (:7135) | `openDeveloper` replaces About + Right. The blob walk (max 20) loses six non-focusable rows above it, so the same or fewer presses are needed. |
| `readHeroProbeAboutPane` (NuvioTVUITests:2145), HeroFolderSwap:155, HeroLogoFocus:168, HeroOffLaunch test31D:230, TabBarScrollLink `walkAndReadPane`:124 | Replace `app.buttons["About"]` + `moveFocus(.down)` + Right with `openDeveloper(app)`. Blob readers are unchanged. |
| FixtureSetup `selectHideTitles` / `selectPosterSize` (:339, :369) | `openSettingsCategory("Appearance")`, drop Right; climb and counts unchanged. |
| PinnedRowSettleRegime `selectPosterSize` (:436-460) | Same; keep the XCTSkip text but say "root category". |
| ScratchServerSwitch `openAccountPane` (:178) | `openSettingsCategory("Account & Profiles")`; return 0. |

### New UI tests (main session assigns the next free numbers)

1. **Root push/pop.** For Services, Detail Page and Developer: open, assert `settings_pane_<raw>`, Menu, assert the same root cell has focus.
2. **Explainer follows focus.**
   - Root: focus Services → `settings_explainer_title` reads "Services"; Down → "Appearance".
   - Home Screen pane (ids wired in W1-B): on the first row the title reads "Upcoming Episodes" and the body is not the summary; Down → "Show Hero" (or "Refresh Add-ons" when there are no catalogs).
   - Settings Style Minimal (`-settings_style minimal`): `settings_explainer_title` is absent.
3. **Developer readouts with `-debug.*` args.** Launch with `-debug.collectionFrameProbe YES` (and `-debug.homeHeroProbe YES`), `openDeveloper`, assert `collection_frame_probe_lines` / `hero_probe_blob` exist after walking.
4. **Theme change keeps the pane.** Folded into test43, as above.

### New unit tests

`SettingsCategoryTests` and `SettingsDescriptionsTests`, as in D4.

---

## J. Risks, PLAN CONFLICTS, open questions

**PLAN CONFLICTS**

1. **PreferenceKey vs environment model.** The plan says the focused row "publishes its id upward through a PreferenceKey". Preferences do not reliably cross tvOS `List` cell or `Menu` label hosting. The spec uses an environment-injected `SettingsExplainerModel`, written from `onChange(of: isFocused)`, with the same read site and the same behaviour. Only the transport differs.
2. **About becomes a pane with no focusable row.** After the move, About holds six `SettingsValueRow`s, and value rows are non-focusable by design (SettingsRowViews:325-327). That breaks the BUG-47 requirement that every pushed pane has a focusable row (SettingsView:42-46). The spec's fix: `SettingsValueRow(focusable: true)` (inert `.focusable()`, the same pattern as AB:545) on the About rows. This also gives them explainer descriptions.
3. **Two rows missing from the plan's re-sort table.**
   - "Next Episode › Preload Next Episode Sources" (PB:144-153) → spec puts it in **Player**.
   - "Fonts — Open Sans licence" (AB:346, currently in the diagnostics `Group`) → spec puts it in **About**, because it is an attribution, not a diagnostic.
4. **"Six kit row inits".** There are seven (Toggle, Picker, Value, Link, Action, Destructive, DebridKeyEntry). Value is not focusable unless `focusable: true`. DebridKeyEntry has no `SettingsRowLabel` and needs the `focused:` variant.
5. **StreamBadges `:18` copy.** The plan lists it with W2-C's cross-reference edits, but `StreamBadgesSection.swift` belongs with Appearance. It is assigned to **W2-B** so file ownership stays disjoint.
6. **StreamsViewModel:265 copy.** "Settings → Content Sources → Addons" never existed; add-ons live in the Add-ons tab. The new copy points there.

**Risks**

7. **Detail and spoiler keys** (`detail_layout`, `detail_section_*`, `detail_hide_spoilers`) must match P1 and W1-C. The main session reconciles them before W2-B. Recommended: a shared constants enum owned by the Detail side.
8. **Debug readouts.** `@AppStorage<Bool>` does not coerce the launch-arg string "YES". Only the collection readout ORs in a live read today (AB:427). The hero, settle and tab-bar-state readouts are gated on their `@AppStorage` toggle and move unchanged. The spec does not add new OR clauses; that would change behaviour.
9. **TabBarScrollLinkTests `walkAndReadPane`** reads `tab_bar_state_probe_blob` right after entering, without walking. It depends on the lazy List materialising a row deep in the pane. Developer removes six rows above it, which helps but does not guarantee it. Watch at Gate 3.
10. **Pre-existing HIG and focus debts, not fixed here (follow-ups):**
    - `PluginRepoEntryRow` (CS:355) and `BadgeUrlEntryRow` (SB:106) wrap a TextField in `.glassEffect`, against the contract's "glass never wrapping focusable content".
    - Plugin scraper toggles (CS:312) and badge pack chips (SB:46-75) put several focus targets in one List row (the HomeScreen 2026-08-30 one-focus-target class).
11. **Pane restore.** After the `.id()` remount, the pane appears without a push and ThemePickerRow's programmatic focus must land in it. test43 is the gate. Value-less `NavigationLink` sub-pages are not restored after a remount; acceptable, since no remounting control lives on a sub-page.
12. **String extraction.** Verify `LocalizedStringResource("…")` literals reach `.stringsdata` and the populate script in W3-B. If not, switch the catalog's return type to `String` with `String(localized:)`.
13. **Path persistence.** The path survives tab switches and profile switches, so re-entering Settings shows the last pane. This matches today's category persistence. `openSettingsCategory` handles it with Menu-until-root.

**Open questions for Christian or the main session**

14. **"Account & Profiles" has no profile rows.** Switching profile lives in the Profile tab. Keep the name as decided (D8), or call it "Account"?
15. **Minimal style root rows.** The spec keeps title + subtitle with no icon. Today's Minimal shows the title only. Which?
16. **Detail Page row labels.** Keep "…on Detail" in the labels for now (test04 matches on them), or rename in W3-A and update test04?

---

### Critical files for implementation
- /Users/christianturnbull/Claude/Projects/Nuvio tvOS/NuvioMobile/iosApp/NuvioTV/Screens/SettingsView.swift
- /Users/christianturnbull/Claude/Projects/Nuvio tvOS/NuvioMobile/iosApp/NuvioTV/Screens/Settings/SettingsRowViews.swift
- /Users/christianturnbull/Claude/Projects/Nuvio tvOS/NuvioMobile/iosApp/NuvioTV/ContentView.swift
- /Users/christianturnbull/Claude/Projects/Nuvio tvOS/NuvioMobile/iosApp/NuvioTV/Screens/Settings/AboutSettingsPane.swift
- /Users/christianturnbull/Claude/Projects/Nuvio tvOS/NuvioMobile/iosApp/NuvioTVUITests/NuvioTVUITests.swift (helpers :302, :2774; test40 :3576; test43 :4102)
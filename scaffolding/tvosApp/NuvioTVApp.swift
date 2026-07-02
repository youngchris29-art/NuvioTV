import SwiftUI
import SharedCore   // the Kotlin framework (baseName = "SharedCore")

@main
struct NuvioTVApp: App {
    init() {
        // One-time shared init (no DI framework in this repo — see Shared.swift).
        Shared.start()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .preferredColorScheme(.dark)   // Nuvio is dark-first
        }
    }
}

/// Top-level tvOS tab bar. tvOS renders this as the focusable top tab strip.
struct RootTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Text("Home") }

            // Phase 1+: Catalog, Search, Library, Settings …
            Text("Search")
                .tabItem { Text("Search") }
            Text("Library")
                .tabItem { Text("Library") }
            Text("Settings")
                .tabItem { Text("Settings") }
        }
    }
}

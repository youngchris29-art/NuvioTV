import SwiftUI

/// tvOS Home: vertically stacked horizontal poster rows, fully focus-driven.
/// Demonstrates the core 10-foot pattern; Phase 1 fills in hero + continue-watching.
struct HomeView: View {
    @StateObject private var store = HomeStore()
    @State private var selected: HomeStore.MediaItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 48) {
                if store.isLoading && store.rows.isEmpty {
                    ProgressView().padding(.top, 120)
                }

                if let error = store.errorText {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.headline)
                }

                ForEach(store.rows) { row in
                    VStack(alignment: .leading, spacing: 16) {
                        Text(row.title)
                            .font(.title2.weight(.semibold))
                            .padding(.leading, 8)

                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 32) {
                                ForEach(row.items) { item in
                                    Button {
                                        selected = item   // → DetailsView (Phase 1)
                                    } label: {
                                        PosterCard(title: item.title, url: item.posterURL)
                                    }
                                    .buttonStyle(.card)   // tvOS focus lift/parallax
                                }
                            }
                            .padding(.horizontal, 8)
                        }
                    }
                    // Keep focus traversal contained within a row before moving down.
                    .focusSection()
                }
            }
            .padding(60)
        }
        // Phase 1: fetch enabled addons from the addon repository and pass them in.
        .task { await store.start(addons: []) }
        // Phase 1: .fullScreenCover(item: $selected) { DetailsView(item: $0) }
    }
}

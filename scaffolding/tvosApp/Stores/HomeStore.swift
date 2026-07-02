import Foundation
import SharedCore

/// Bridges the Compose-free Kotlin `HomeRepository` to SwiftUI.
///
/// The Kotlin repository is **reactive**: it exposes `val uiState: StateFlow<HomeUiState>`
/// and you call `refresh(addons:force:)` to drive it. With SKIE, a Kotlin `StateFlow`
/// surfaces in Swift as an `AsyncSequence`, so we just `for await` over `uiState` and
/// republish into SwiftUI `@Published` properties.
@MainActor
final class HomeStore: ObservableObject {

    struct Row: Identifiable {
        let id: String
        let title: String
        let items: [MediaItem]
    }
    struct MediaItem: Identifiable {
        let id: String
        let title: String
        let posterURL: URL?
    }

    @Published var rows: [Row] = []
    @Published var isLoading = false
    @Published var errorText: String?

    private let repository: HomeRepository

    init(repository: HomeRepository = Shared.home) {
        self.repository = repository
    }

    /// Start observing the repository's state, then trigger a refresh.
    /// `addons` must come from the addon repository (Phase 1 wiring).
    func start(addons: [ManagedAddon]) async {
        repository.refresh(addons: addons, force: false)

        // SKIE turns `uiState: StateFlow<HomeUiState>` into an AsyncSequence:
        do {
            for try await state in repository.uiState {
                self.isLoading = state.isLoading
                self.errorText = state.errorMessage
                self.rows = mapSections(state)   // map HomeUiState → [Row]
            }
        } catch {
            self.errorText = String(describing: error)
        }
    }

    /// Adapt the Kotlin `HomeUiState` (sections of catalog items) into view rows.
    /// Field names below are placeholders — align them with `HomeModels.kt`.
    private func mapSections(_ state: HomeUiState) -> [Row] {
        state.sections.map { section in
            Row(
                id: section.id,
                title: section.title,
                items: section.items.map {
                    MediaItem(id: $0.id,
                              title: $0.name,
                              posterURL: URL(string: $0.posterUrl ?? ""))
                }
            )
        }
    }
}

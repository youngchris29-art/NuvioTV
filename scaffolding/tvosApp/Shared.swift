import Foundation
import SharedCore

/// NOTE: this repo has **no DI framework** (no Koin). Repositories are plain Kotlin
/// classes you construct directly and hold onto. They're **stateful + reactive** —
/// e.g. `HomeRepository` owns its own coroutine scope, exposes
/// `val uiState: StateFlow<HomeUiState>`, and you drive it by calling
/// `refresh(addons:force:)`. So the bridge's job is just to own long-lived instances.
///
/// `HomeRepository.refresh(...)` needs the user's enabled addons, which come from the
/// addon repository. Construct that first and feed its addon list in (Phase 1 wiring).
enum Shared {
    /// Long-lived singletons. Construct lazily; match the real Kotlin constructors,
    /// which Xcode reveals once SharedCore.framework is linked.
    static let home = HomeRepository()          // adjust to real constructor args
    // static let addons = AddonRepository(...)
    // static let details = DetailsRepository(...)

    /// If the shared module ends up needing one-time startup (Supabase client, logging),
    /// do it here and call once from NuvioTVApp.init.
    static func start() { /* one-time shared init, if any */ }
}

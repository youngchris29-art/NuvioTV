# Nuvio tvOS — Claude Code project notes

## Upstream sync status (auto-checked daily against NuvioMedia/NuvioMobile)

A scheduled task diffs this fork's `NuvioMobile` submodule (`upstream` remote = `github.com/NuvioMedia/NuvioMobile`, branch `cmp-rewrite`) against upstream daily and logs actionable ports to `docs/upstream-port-plan-YYYY-MM-DD.md`. Latest run: **2026-08-17**, see `docs/upstream-port-plan-2026-08-17.md`.

**Current open action items:**

- **[MEDIUM, needs a product decision, not a mechanical port] Self-hosted server discovery** (upstream commits `ddc28dc8`/`cc20e716`, new 2026-08-16). Upstream added a full flow letting mobile/desktop users point the app at a self-hosted Supabase-compatible backend via a `/.well-known/nuvio` discovery document. Entirely in `composeApp/` (Compose UI + composeApp-local business logic) — zero `shared/` changes, so nothing to mechanically port. tvOS currently hardcodes to the official backend (`shared/.../SupabaseProvider.kt`, fork-native) with no self-hosting concept at all. Decide scope before implementing — see the 2026-08-16 doc for the full port plan (which pure-domain pieces are portable, what needs new tvOS-native SwiftUI design).
- **[LOW, needs a product decision, not a mechanical port] Subtitle minimum font size** (upstream commit `d50f84fc`). Upstream lowers the iOS mobile subtitle-size floor from 12sp to 6sp. tvOS uses a different native subtitle renderer (`iosApp/NuvioTV/Screens/SubtitleVTT.swift`, not the KMP `PlayerEngine.ios.kt` this fix touches), and 10-foot UI arguably wants a *larger* minimum, not smaller. Don't port as-is — decide tvOS's own range next time player styling gets a pass.
- **TMDB Discover exclusion filters — UI half only** (upstream commit `0fc4616b`). The shared plumbing (filter fields + Discover query builder + serialization test) was ported 2026-08-13 (`7dac9a67`); what remains is upstream's `CollectionEditorScreen.kt` + strings hunks for the mobile editor, and new tvOS SwiftUI exclusion controls — tvOS has no dedicated collection-editor screen yet (`CollectionsUI.swift` is browse-only by design), so that side needs new UI design. Until then the fields are reachable only via imported JSON (additive/default-null, no risk to existing collections).
- **[LOW, mechanical, no urgency] `shared/AppLanguage.kt` enum missing `ARABIC` entry** (upstream `3c0ab547`, new 2026-08-17). Upstream's composeApp added Arabic to its language enum + a `values-ar/strings.xml` resource file; this fork's Compose-free twin in `shared/.../settings/AppLanguage.kt` (extracted during `tvos-shared-extraction`) doesn't have the new entry. Inert today — tvOS has no in-app language-picker UI consuming this enum — but worth syncing opportunistically alongside other shared/ work so the drift doesn't compound. See `docs/upstream-port-plan-2026-08-17.md` for the exact diff.

**Ported 2026-08-13:** addon cache-control / force-refresh (upstream `981b8bc7` → fork `a040293a`, incl. Android OkHttp cache + Compose call sites this fork's composeApp consumes, and tvOS Swift wiring) and TMDB exclusion-filter shared plumbing (upstream `0fc4616b` → fork `7dac9a67`). See the addendum in `docs/upstream-port-plan-2026-08-13.md` — including the empirical finding that tvOS's Ktor Darwin client never *serves* from NSURLCache (the header still matters for CDN/addon-server caches), and the three deliberate fork divergences kept in the cache-control port.

As of 2026-08-17, `upstream/cmp-rewrite` advanced `cc20e716` → `d2db97a9` (12 commits) — all Arabic/Bulgarian localization (composeApp Compose resources, tvOS uses a separate hand-maintained `Localizable.xcstrings` with only 5 of upstream's ~21 locales ported, by design) or an Android-only mpv local-file-URI fix (`PlayerEngine.android.kt`, not shared with tvOS's native player path). Only actionable fallout is the trivial `AppLanguage.kt` enum drift noted above. `upstream/copilot/refactor-project-structure` remains stale/abandoned, and `upstream/simkl` is still fully merged into `cmp-rewrite` (zero unique commits). Submodule pointer drift from prior runs remains resolved — pinned pointer matches actual HEAD.

For full day-by-day history of what's been checked and what landed, see `docs/upstream-port-plan-*.md` (2026-07-25 onward) — each file's "Verification" section confirms whether prior items landed.

## Repo layout

- Outer repo (this folder) = fork wrapper: docs, scaffolding, design assets, the `NuvioMobile` submodule.
- `NuvioMobile/` = the actual KMP + native tvOS app (submodule, tracks `tvos-shared-extraction` branch on `origin` = `youngchris29-art/NuvioMobile`).
- `NuvioMobile/shared/` = Compose-free Kotlin business logic shared across platforms — this is what upstream ports land in.
- `NuvioMobile/iosApp/NuvioTV/` = native SwiftUI tvOS frontend.

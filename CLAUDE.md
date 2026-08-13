# Nuvio tvOS — Claude Code project notes

## Upstream sync status (auto-checked daily against NuvioMedia/NuvioMobile)

A scheduled task diffs this fork's `NuvioMobile` submodule (`upstream` remote = `github.com/NuvioMedia/NuvioMobile`, branch `cmp-rewrite`) against upstream daily and logs actionable ports to `docs/upstream-port-plan-YYYY-MM-DD.md`. Latest run: **2026-08-13**, see `docs/upstream-port-plan-2026-08-13.md`.

**Current open action items:**

- **[LOW, needs a product decision, not a mechanical port] Subtitle minimum font size** (upstream commit `d50f84fc`). Upstream lowers the iOS mobile subtitle-size floor from 12sp to 6sp. tvOS uses a different native subtitle renderer (`iosApp/NuvioTV/Screens/SubtitleVTT.swift`, not the KMP `PlayerEngine.ios.kt` this fix touches), and 10-foot UI arguably wants a *larger* minimum, not smaller. Don't port as-is — decide tvOS's own range next time player styling gets a pass.
- **TMDB Discover exclusion filters — UI half only** (upstream commit `0fc4616b`). The shared plumbing (filter fields + Discover query builder + serialization test) was ported 2026-08-13 (`7dac9a67`); what remains is upstream's `CollectionEditorScreen.kt` + strings hunks for the mobile editor, and new tvOS SwiftUI exclusion controls — tvOS has no dedicated collection-editor screen yet, so that side needs new UI design. Until then the fields are reachable only via imported JSON (additive/default-null, no risk to existing collections).

**Ported 2026-08-13:** addon cache-control / force-refresh (upstream `981b8bc7` → fork `a040293a`, incl. Android OkHttp cache + Compose call sites this fork's composeApp consumes, and tvOS Swift wiring) and TMDB exclusion-filter shared plumbing (upstream `0fc4616b` → fork `7dac9a67`). See the addendum in `docs/upstream-port-plan-2026-08-13.md` — including the empirical finding that tvOS's Ktor Darwin client never *serves* from NSURLCache (the header still matters for CDN/addon-server caches), and the three deliberate fork divergences kept in the cache-control port.

As of 2026-08-13, `upstream/cmp-rewrite` moved for the first time in 3 checks (5 new commits, `f9ad843b` → `0d6e30e4`) and `upstream/copilot/refactor-project-structure` remains a stale/abandoned branch — no other pending ports beyond the two items above plus the carried-forward TMDB item.

For full day-by-day history of what's been checked and what landed, see `docs/upstream-port-plan-*.md` (2026-07-25 onward) — each file's "Verification" section confirms whether prior items landed.

## Repo layout

- Outer repo (this folder) = fork wrapper: docs, scaffolding, design assets, the `NuvioMobile` submodule.
- `NuvioMobile/` = the actual KMP + native tvOS app (submodule, tracks `tvos-shared-extraction` branch on `origin` = `youngchris29-art/NuvioMobile`).
- `NuvioMobile/shared/` = Compose-free Kotlin business logic shared across platforms — this is what upstream ports land in.
- `NuvioMobile/iosApp/NuvioTV/` = native SwiftUI tvOS frontend.

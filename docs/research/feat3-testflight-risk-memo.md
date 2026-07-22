# FEAT-3 research: TestFlight / App Store risk for NuvioTV

**Verdict: conditional go — not as currently configured.** (Research memo, 2026-07-22.)

## Key findings

- **"Union for iOS" could not be verified** as a specific app — treat that name as unconfirmed secondhand recall. The real, well-documented precedent is **Stremio**: removed from the Apple App Store; the stripped-down **Stremio Lite** (no bundled torrents, no community-addon list — cut specifically for review) launched on tvOS Oct 2025 and was **itself removed ~Jan 2026**, no official reason. Stremio now ships a full-featured sideloadable IPA instead. Kodi has never been accepted at all (addon architecture is categorically incompatible with review).
- **Same-ecosystem signal:** a "Nuvio Media" app reportedly launched on the iOS App Store early July 2026 and was removed mid-July; the App Store listing (id6762262229) now 404s (checked directly). Surrounding reporting is low-trust affiliate blogs — corroborated only by the 404.
- **Guideline pressure points:** 5.2.2 (must prove authorization for third-party content on request — impossible for arbitrary community indexers), 5.2.3 (debrid resolution reads as facilitating unauthorized media access), 2.3.1 (review notes/screenshots must honestly disclose functionality — a "generic media app" framing with visible debrid/addon settings is a fast rejection and the escalation path to account action if repeated).
- **TestFlight is not a safe harbor:** lighter review, but same policy judgment ("rejected by TestFlight → most likely rejected by App Review"). A single rejection is low-stakes; **account termination comes from patterns** (repeated resubmission, misleading metadata, rights-holder complaints), not one bounce. Internal testers (≤100, own Apple IDs) effectively bypass review.

## Top risks, ranked

1. **Debrid integration (RD/TorBox)** — the single biggest flag.
2. **User-added addon/indexer architecture** — the pattern itself (Kodi/Stremio) is the trigger, regardless of what's preinstalled.
3. **Metadata/review-notes mismatch (2.3.1)** — fastest route from "rejection" to "account risk."
4. mpv player: low risk. 5. Supabase sync: low risk.

## Recommended configuration (if pursuing TestFlight)

- **Internal TestFlight only** (own Apple IDs, ≤100) = lowest risk, review effectively bypassed; OR
- External TestFlight with a **separate clean bundle ID/target**: debrid compiled out behind a build flag (not UI-hidden), zero preloaded addon URLs, submitted honestly as a generic media client (Stremio Lite / VortX pattern). Full-featured build stays on GitHub-release sideload — which is where every comparable project (Stremio full, VortX, Ferrite, bobsupra/NuvioTVOS) settled.

## Suggested Reddit framing (for FEAT-3 status update)

> Looked deep into the TestFlight question. Short version: the exact architecture we use (community addons + debrid) is what got Stremio pulled from the App Store twice — even their stripped "Lite" tvOS version was removed in January. TestFlight review applies the same rules, so a full-featured public TestFlight is a real risk to the developer account. Plan: keep the full-featured build on GitHub sideload, and explore a limited internal TestFlight and/or a stripped "clean" build (no debrid, no preloaded sources) for broader TestFlight distribution.

Full sources: Stremio blog posts, troypoint, Apple review guidelines (1.2/2.3/4.2/5.2.x), Apple dev-forum termination threads, VLC/Kodi precedents — see agent transcript; key URLs inline above.

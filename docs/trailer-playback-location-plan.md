# Trailer Location: poster morph vs hero playback (FEAT-25 round one) — 2026-08-21

**Status:** built + pushed on NuvioMobile branch `claude/trailer-playback-location`
(commit `6b84fbe8`, based on the beta.14 head `dcd84a69`). **Sim-build CI GREEN** —
`tvos-sim-build.yml` run 32531337429 succeeded end-to-end on that commit (2026-08-21,
~19 min), so the branch compiles for tvOS Simulator including both test targets.
**Codex gate still owed from the Mac** — the outer-repo submodule pointer stays at
`dcd84a69` until that gate is clean.

## What it is

The round-one half of FEAT-25 (the reporter's original hero-or-thumbnail ask): a
device-local setting `trailer_playback_location` (`"poster"` default / `"hero"`),
surfaced as a "Trailer Location: Poster / Hero" chip row under Trailers on Focus in
Settings > Home Screen. With `hero` selected in a pinned hero layout (Nuvio-Style
Hero on, or Show Hero off), the focused poster no longer morphs into an inline
trailer tile — the trailer plays in the hero backdrop, which already follows focus.
Classic layout and Search keep the poster morph; a Settings caption explains each
fallback (classic layout; zero hero sources).

## How it works (all in NuvioMobile)

- `HomeView.swift`: `heroFocusTrailerMode` (settings + a single-flip
  hero-surface-seen latch), `heroFocusTrailerActive`, `heroTrailerActive` (the one
  Bool `HomeHeroBackdrop` consumes — the FEAT-25 `syncTrailer` machinery is reused
  unchanged); shared cover gates hoisted into `heroTrailerSharedGatesOpen`;
  `debug_hero` probe gains `tloc=`/`hph=` fields; a `[TrailerPipeline]
  trailerLocation` mode line logs at mount and on flips.
- `BrowseComponents.swift`: `trailerPlaysInHero` environment key;
  `CatalogRowView.inlineTrailersActive` suppresses the morph under it (Search
  defaults false).
- `HomeScreenSettingsPane.swift`: chip row + two fallback captions.
- `Localizable.xcstrings`: 5 new keys x de/es/fr/it/vi; `debug_hero` key renamed
  with its source string.
- `NuvioTVUITests.swift`: `test37TrailerLocationHero` (hero leg asserts no morph +
  `tloc=h` + `hph` past idle; poster control leg asserts the morph; peak-width
  oracle so a morph-then-collapse cannot false-pass).

## Review record (in-session pre-commit loop, 6 rounds, all actionable fixed)

r1 zero-hero fallback hole + probe dedupe flip-flop; r2 test frame-read race +
cover-gate duplication; r3 focus-panel seed churn; r4 hero-empties latch (BUG-42
evidence) + stale xcstrings debug key; r5 mount-time double log + morph-collapse
test oracle; r6 zero-hero-source Settings caption + mid-morph-snap documentation.
**Recorded keeps:** `controlRow`/`chip` pane-local copy (established pattern); no
play/pause handler for CW/Upcoming-focused hero trailers (matches the FEAT-25 v1
keep); latched suppression after a permanent mid-session hero-source loss
(self-heals at relaunch; documented in code).

## Device-pass checklist (Christian, before the pointer bump)

1. Codex gate on the Mac (`--base dcd84a69 --scope branch`), rounds until clean.
2. `test37TrailerLocationHero` + `test01InlineTrailerDwell` on the sim.
3. Hero location feel: browse posters — trailer starts in the hero ~1.2s after
   focus rest (0.2s commit + 1s dwell); poster never morphs; Search still morphs.
4. Mute: play/pause on the focused catalog card toggles hero-trailer audio (no
   glyph on the hero — FEAT-25 v1 keep). CW/Upcoming-focused hero trailers have no
   play/pause (recorded keep — judge whether v1 acceptable).
5. FEAT-25 coexistence: Autoplay Hero Trailer ON + location hero — focus plays the
   focused title, unfocus hands back to the carousel title after grace + dwell;
   same-title handoff continues seamlessly.
6. Coverage: Detail push / tab switch silences the hero trailer; return re-dwells.
7. Classic layout fallback (Nuvio-Style off): poster morph, caption in Settings.
8. Cold-launch race: focus a poster before the hero fan-out lands — the one-time
   latch flip may snap an in-flight morph closed (documented keep) — judge feel.

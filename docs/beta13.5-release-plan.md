# NuvioTV 0.3.0-beta.13.5 — hotfix release plan (2026-08-20)

One-day hotfix batch assembled from three converging inputs: u/mrStevenx3's same-day beta.13
review (`p4to4kj`, including its **attached video**, frame-analyzed — stills in
`docs/research/p4to4kj-video-evidence/`), the 08-20 upstream check (SDH stripping ready), and
the two open GitHub issues. Full working plan + progress:
`~/.claude/plans/lets-make-a-plan-rustling-hinton.md`. Tracker rows updated in
`docs/beta-feedback-tracker.md` (08-20 midday video-pass entry).

## Scope (all built 2026-08-20 unless noted)

| Item | What shipped |
|---|---|
| BUG-67 (P2, regression) | Trailer pick + Trailers & Extras ordering: Metadata Language now the dominant tier (`HeroTrailerSelector.kt` `metadataLanguagePriority`, `TmdbMetadataService.kt` bucket sort). Restores pre-BUG-63 French behavior, keeps English fallback. 5 shared tests updated/green. |
| BUG-65 (P2) | Appearance pane focused-contrast fix — **probe-driven** (test36 measures the ring row's platter/dark-text bands; fix lands after the probe verdict). Swatch focus tint per the reporter's suggestion. |
| BUG-32 + UX-15 (P2/P3) | Detail-page pass: corner token (`posterStyle.cornerRadius`) + `.posterButtonShape()` on SeasonPosterCard / EpisodeThumbCard / TrailerThumbCard; "Episodes" heading moved below the season selector **and localized** (was a raw string — explains the unaccented "Episodes" in his French video); `CardCaptionFocusDrop` clearance on all three captions. Birth checklist appended to `docs/design/hig-hybrid-contract.md`. |
| BUG-64 (P2) | No code: video shows his demo ran ring ON + **No Zoom OFF** (t=160.5 still) where zoom is by design; `CardFocusMode.resolve` guard verified correct; test32 already pins ring+No-Zoom still. Reply asks which config/screen still zooms for him. |
| BUG-68 (P3) | Verified live: TMDB has **no French bio** for Harold Perrineau (their own FR page serves English) — app already requests FR + falls back. App-side sliver fixed: "Known for" department value localized (`PersonDetailView.swift`). |
| BUG-42 (P1) | No fifth blind fix. New **Settings → About → Hero Paint Diagnostics**: probe lines mirror into a persisted per-launch ring buffer rendered in the pane — tester photographs a cold-launch capture. |
| BUG-66 + BUG-30 (P1) | One investigation, device-coupled — clip + session-length ask in the reply; device soak on the pass. No blind fix (six banned rounds stand). |
| SDH stripping (upstream PR #1751) | Full parity: `SubtitleSdhFilter` in shared commonMain (+6 tests), `stripSdh` through models/storage (apple+android)/repository/sync payload, tvOS MPV `sub-filter-sdh(-harder)`, PlaybackSettingsPane toggle + xcstrings, composeApp toggle/strings/`PlayerEngine.android.kt` filtering. |
| GitHub #2 (konrepo) | Root cause: tvOS players never passed addon `behaviorHints.proxyHeaders` (mobile does). Threaded: shared `sanitizePlaybackHeaders` (upstream rules) → `PlaybackContext.requestHeaders` → mpv `http-header-fields` (upstream serialization, clear-on-empty) + FFmpeg `headers` option in MediaProbe/RemuxSession (AVPlayer fetches only from loopback, so FFmpeg is the right injection point). Note: addon's own series catalogs currently return `{"metas":[]}` server-side; external players can't receive headers (no transport). |
| GitHub #1 (ozdek) | No code: his crash log IS `__CFPREFERENCES…TOO_MUCH_DATA__`, fixed by `becb24b3` (beta.10; ancestry-checked NOT in beta.9, his last build). Reply drafted asking retest. |

Parked/deferred by product decision (2026-08-20): Supporter Perks v1 (backlog), subtitle
min-font-size (next player-styling pass). CLAUDE.md open-items list corrected accordingly.

## Reply drafts (post only after approval)

`docs/research/reddit-drafts-2026-08-20-beta13-review-reply.md` — Reddit reply to `p4to4kj`
(incl. BUG-42 diagnostics instructions, BUG-64 config question, BUG-66 clip ask, Nando
no-videos finding) + GitHub #1 and #2 replies.

## Known issue found during gating (NOT a beta.13.5 blocker, pre-existing)

**test24CatalogGridFocusRestore fails on the current sim environment — including on a clean
HEAD (beta.13-shipped code) checkout run 2026-08-20** (worktree arbitration: fails 2× on the
working tree with a cast-card label, and on clean HEAD with an EMPTY focused label — popping a
pushed page from the detail cast row returns to the top of the detail with focus reset). Since
the same code was green in the beta.13 gate on 08-18/19, this is fixture or runtime drift
(candidate: the FA87 fixture's damaged sign-in state from the 08-19 server-switch testing),
not a regression from this batch. Every other UI test passes (73 green). Investigate
separately; the UX-13 behavior deserves a device spot-check on the pass.

## Gates before cut

1. Shared Kotlin tests — ✅ 438/438 (incl. 6 SDH + 5 trailer-language).
2. Sim app build — ✅ BUILD SUCCEEDED (Debug, tvOS sim).
3. test26 + test36 Appearance probes → BUG-65 fix → re-run both.
4. Codex review loop until clean (direct + unsandboxed invocation).
5. l10n: xcstrings sync for new keys (Episodes, Hero Paint Diagnostics + subtitle, department
   names, SDH toggle already translated by hand).
6. Full sim suite (was 54 tests; now +test36).
7. Device pass (irreducibly manual): tab bar both failure modes + long-session soak (BUG-66),
   corners on square setting across detail page, White-theme + Émeraude Appearance focus,
   season selector heading/caption, SDH toggle on an SDH-subtitled stream, khmerhub KhmerTV
   channel with the header fix, About diagnostics capture flow, French trailer check on
   "72 Hours" / "Drop Game".
8. README + screenshots, then `scripts/release-beta.sh` with tag `tvos-v0.3.0-beta.13.5`
   (verify the script accepts the four-part suffix; hotfix-style Reddit block).

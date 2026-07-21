# NuvioTV Beta Feedback Tracker

Live tracker of bug reports and feature requests from the beta announcement thread.
Updated automatically once a day by a scheduled Claude task; safe to edit by hand
(status changes, notes) — the daily run only appends/updates items, it never removes
manual edits.

- **Source thread:** [I built a native Apple TV app for Nuvio. Beta testers wanted!](https://www.reddit.com/r/Nuvio/comments/1v26ebw/i_built_a_native_apple_tv_app_for_nuvio_beta/) (r/Nuvio, posted 2026-07-21, 39↑ / 35 comments at last check)
- **Last checked:** 2026-07-21 ~07:08 UTC
- **Newest comment seen (watermark):** `oytpn8z` @ 2026-07-21T06:46:30Z — daily run only needs to classify comments newer than this
- **Fetch mechanism:** Apify actor `harshmaur/reddit-scraper` via MCP (`startUrls` = thread URL, `crawlCommentsPerPost: true`). Direct reddit.com JSON and the in-app browser are both blocked from this machine — don't waste time retrying them.

## Priority scheme

| Priority | Meaning |
|---|---|
| **P0** | Crash / data loss / app unusable — drop everything |
| **P1** | Degrades core experience (playback, login, navigation) for many users |
| **P2** | Annoying but has a workaround, or affects a subset of users |
| **P3** | Polish / nice-to-have |

Statuses: `New` → `Investigating` → `In progress` → `Fixed (unreleased)` → `Shipped` / `Declined` / `Watching`

## Now / Next / Later

| Now (urgent + important) | Next (important) | Later |
|---|---|---|
| BUG-2 initial playback lag | FEAT-1 QR-code login | UX-1 hero poster visibility |
| — | FEAT-2 collapsible/dropdown source list (fixes BUG-5) | DOC-1 auto-resign guide |
| — | BUG-3 slow swipe-up player menu · BUG-4 white focused-link state | — |

---

## Open bugs

| ID | Pri | Status | Report | Reporter / link | First seen |
|---|---|---|---|---|---|
| BUG-2 | P1 | New | Player is laggy for the first ~minute of playback, then smooths out. Likely the remux pipeline warming up — reporter didn't say which stream type; ask for codec/DV details when following up. | u/time_continuum — [comment](https://www.reddit.com/r/Nuvio/comments/1v26ebw/i_built_a_native_apple_tv_app_for_nuvio_beta/oytlka6/) | 2026-07-21 |
| BUG-3 | P2 | New | Swipe-up player menu (subtitles/audio) is slow to appear; fine once open. | u/time_continuum — [same comment](https://www.reddit.com/r/Nuvio/comments/1v26ebw/i_built_a_native_apple_tv_app_for_nuvio_beta/oytlka6/) | 2026-07-21 |
| BUG-4 | P2 | Acknowledged | Focused link/source rows render white-on-white and are unreadable (screenshot in comment). You replied you'd make the focused state more readable. | u/time_continuum — [same comment](https://www.reddit.com/r/Nuvio/comments/1v26ebw/i_built_a_native_apple_tv_app_for_nuvio_beta/oytlka6/) | 2026-07-21 |
| BUG-5 | P2 | Acknowledged | All indexers/sources load at once in a row and the app lags until they finish. Folded into FEAT-2 (dropdown/organized source view) — fixing one fixes the other. | u/time_continuum — [same comment](https://www.reddit.com/r/Nuvio/comments/1v26ebw/i_built_a_native_apple_tv_app_for_nuvio_beta/oytlka6/) | 2026-07-21 |

## Open feature requests

| ID | Pri | Status | Request | Reporter / link | First seen |
|---|---|---|---|---|---|
| FEAT-1 | P1 | New | QR-code login at first launch instead of typing credentials with the Siri Remote. High value for every sideload user; reporter uses Signulous. | u/Ginosaure — [comment](https://www.reddit.com/r/Nuvio/comments/1v26ebw/i_built_a_native_apple_tv_app_for_nuvio_beta/oytpn8z/) | 2026-07-21 |
| FEAT-2 | P1 | Acknowledged | Dropdown / grouped view for indexers in the stream picker instead of one long auto-loading row (also resolves the BUG-5 lag). You replied you'd look into a more organized indexer view. | u/time_continuum — [comment](https://www.reddit.com/r/Nuvio/comments/1v26ebw/i_built_a_native_apple_tv_app_for_nuvio_beta/oytlka6/) | 2026-07-21 |

## UX feedback / design decisions

| ID | Pri | Status | Item | Reporter / link | First seen |
|---|---|---|---|---|---|
| UX-1 | P2 | Watching | Hero carousel poster only appears when the hero is focused — reporter assumed it was broken ("hero posts don't work"). Current behavior is intentional (your preference), but at least one user read it as a bug. Consider always-visible posters or a setting; revisit if more reports come in. | u/time_continuum — [comment](https://www.reddit.com/r/Nuvio/comments/1v26ebw/i_built_a_native_apple_tv_app_for_nuvio_beta/oytlka6/) | 2026-07-21 |
| DOC-1 | P3 | New | Sideloadly 7-day auto-resign confused a tester (asked "how do I do that?"). Add a short auto-resign walkthrough (Sideloadly anisette/auto-refresh setup) to the release-notes install guide. | u/Sapir28 — [comment](https://www.reddit.com/r/Nuvio/comments/1v26ebw/i_built_a_native_apple_tv_app_for_nuvio_beta/oyt7t8e/) | 2026-07-21 |

## Resolved

| ID | Pri | Status | Report | Resolution | Reporter / link |
|---|---|---|---|---|---|
| BUG-1 | P0 | Fixed — verify in wild | App crashes after adding Nuvio account, then crash-loops at the profile selector on every launch. | Coroutine guards shipped in `tvos-v0.3.0-beta.2`; reporter confirmed fixed via DM. Underlying enrichment error ("Remote metadata resolution failed") still unidentified — keep watching logs and the thread for recurrences. | u/Physical-Lab-9203 — [comment](https://www.reddit.com/r/Nuvio/comments/1v26ebw/i_built_a_native_apple_tv_app_for_nuvio_beta/oytfb7u/) |

## Watch list (not actionable for tvOS)

- **Chromecast on Nuvio mobile** — u/Naive_Complex_8389 [asked](https://www.reddit.com/r/Nuvio/comments/1v26ebw/i_built_a_native_apple_tv_app_for_nuvio_beta/oytdyef/) about adding Chromecast to Nuvio itself (mobile, not this port). Out of scope here; could point them at the upstream repo.
- **Competing port: bobsupra/NuvioTVOS** — now uses [AetherEngine](https://github.com/superuser404notfound/AetherEngine), which per your own comparison covers a few formats NuvioTV doesn't yet. Track as competitive input for player format coverage.
- **Positive signal worth keeping:** Dolby Vision decoding called out as the reason NuvioTV is a tester's favorite way to use Nuvio (u/Physical-Lab-9203); "app is really smooth", addon enable/disable and catalog toggles praised (u/time_continuum); "your version is my favorite so far" (u/Ginosaure).

## Update log

- **2026-07-21** — Tracker created. Initial sweep of all 35 comments: 5 bugs (1 already resolved in beta.2), 2 feature requests, 2 UX/docs items, 3 watch-list notes.
- **2026-07-21 (07:08 UTC re-check)** — No new comments since watermark `oytpn8z` (06:46:30Z). Thread still at 35 comments; nothing to classify.

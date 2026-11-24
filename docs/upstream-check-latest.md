# Upstream check — latest (rolling)

Overwritten by the `nuvio-upstream-check` scheduled task on every run. The dated reports it also writes (`docs/upstream-port-plan-YYYY-MM-DD.md`, `docs/nuviotv-android-upstream-port-plan-YYYY-MM-DD.md`) stay local and are gitignored; this file is the only tracked record and carries the baselines the next run starts from.

- **Run:** 2026-11-24
- **NuvioMobile baseline** (`NuvioMedia/NuvioMobile` `cmp-rewrite`): `bd9506cc8` — dated report `docs/upstream-port-plan-2026-11-24.md`
- **NuvioTV Android baseline** (`NuvioMedia/NuvioTV` `dev`): `9e5af3d6c` — dated report `docs/nuviotv-android-upstream-port-plan-2026-11-24.md`

## NuvioMobile — 2026-11-24

Upstream `NuvioMedia/NuvioMobile` (`cmp-rewrite`): `642f6e031` -> `bd9506cc8` (fetched 2026-11-24). 22 non-merge commits, about half translations. Fork tip checked: `c5c51abd3`. **New baseline: `bd9506cc8`.**

| # | Item (upstream commits) | Verdict | Files | Effort |
|---|---|---|---|---|
| 1 | Skip addon cloud push for guest (anonymous) sessions (`c72103eca`): `shouldPushAddonsToServer(authState)` checked before and after the 500 ms debounce | PORT. The fork's `pushToServer` only blocks unhydrated authenticated pushes (`shouldBlockUnhydratedAddonPush`); an anonymous session still pushes. Add the same guard, keep it a pure tested function. Touches the identity root: Codex design round first. | `shared/.../addons/AddonRepository.kt` (+ test) | S |
| 2 | Format badge for subtitle tracks (ASS, PGS, VobSub, DVB) instead of the codec in the title (`6c7386681`, plus `SubtitleSelectionModel`, iOS bridge exposes track codec) | PORT (design call). `subtitleFormatBadgeForCodec(codec)` is pure and portable; the fork has no `SubtitleFormatBadge`. Needs a badge in the tvOS subtitle picker on mpv and Aether, and track titles without the codec. | `shared/.../player/SubtitleAudioModels.kt`, `iosApp/NuvioTV` subtitle picker, mpv/Aether bridge | M |
| 3 | Series type restored for JS plugins only (`f14ff2b97`, `44835b62b`, `c5dc94c0a` final shape: `jsPluginMediaType`) | CHECK. Fork already has `shared/.../plugins/PluginMediaType.kt`; diff it against upstream's final version, and confirm custom Stremio media types survive in `AddonTransportUrls`/`StreamsRepository`. | `shared/.../plugins/PluginMediaType.kt`, `AddonTransportUrls.kt`, `StreamsRepository.kt` | S |
| 4 | Cap Android addon text responses (`ba573755b`) | SKIP. Android `AddonPlatform.android.kt` only. Worth a look at the Apple `AddonPlatform` for an unbounded body read. | n/a | n/a |
| 5 | Shrink long addon name in the synced chip (`a0da4691e`) | SKIP. Compose UI only. | n/a | n/a |
| 6 | Subtitle font size max 60 on Android (`2e2154856`, `dec0f3286`) | SKIP. Android range only; iOS stays 6..40. | n/a | n/a |
| 7 | Traditional Chinese, Vietnamese, French strings, AppLanguage (`37c2e1aa8`, `e0f49bb36`, `4d1453ce9`, `64db6aad6` and others) | SKIP for code. Translation source: zh-Hant could seed the fork's xcstrings if the fork adds that language. | n/a | n/a |
| 8 | Media3 AAR update, version bump, store-beta.json (`3e63c3ab8`, `4ec93635a`, `bd9506cc8`) | SKIP. Android/store packaging. | n/a | n/a |

Recommended: items 1 and 2. Item 3 is a short check. The carry-over from 2026-11-21 stays open: Trakt library refresh queue fix (`103c5e07a`, M, Codex design round first).

## NuvioTV Android — 2026-11-24

Upstream `NuvioMedia/NuvioTV` (`dev`): `7097af17f` -> `9e5af3d6c`. 35 non-merge commits (shallow fetch). Commit messages read; no Kotlin diffed. **New baseline: `9e5af3d6c`.**

| # | Item (upstream commits) | tvOS verdict | Effort |
|---|---|---|---|
| 1 | Format badge for styled/image subtitles instead of the codec; track label as built-in subtitle title (`4db6cbabd`, `8efa5ca57`) | PORT with NuvioMobile item 1 of the same day (`6c7386681`): same feature, one change. | M |
| 2 | Separate subtitle style for ASS/SSA; nuvio-libass v0.0.14; auto-sync fixes for legacy ASS codec IDs (`8ce69c2a1`, `1a1871023`, `2ed752298`, `80b1b33db`) | CHECK. The fork has a styled-subtitles setting on Aether; a separate ASS style is a new setting idea only. Auto-sync is Android-only. | S |
| 3 | Usenet HUD rows and streaming-type line in the player HUD (`f57709996`, `742dfbe29`, `f867fae32`, `c3af0fed9`, `fd344881b`, `79c787796`) | SKIP. Needs the Usenet engine; no tvOS equivalent. | n/a |
| 4 | Blu-ray: LPCM clips and DTS-HD tracks; audio-track key not opening over disc titles (`927e81575`, `928244de2`, `8b6ac91b1`) | SKIP. ExoPlayer Blu-ray work. | n/a |
| 5 | Home covers: bound concurrent collection cover fetches, disk-cached covers bypass the network queue, reuse loaded covers for focus glow (`9f753b3b1`, `61e54f7d0`, `98264d32f`) | CHECK on a device pass: compare the fork's collection cover loading under many collections. | S |
| 6 | Details: draw background once and only the visible hero gradient (`54c505452`); trailer on details opened from More like this (`558d65df7`) | CHECK. Compare with the fork's Detail trailer from a More like this entry. | S |
| 7 | Debrid: match ampersand filename variants (`4b71d71ae`) | CHECK. Compare the fork's debrid filename matching for `&` vs `and`. | S |
| 8 | Launcher Continue Watching channel sync; collection editor focus; Hungarian/Usenet translations (`02a9afc85`, `bf210ec51` and others) | SKIP. Android launcher, Android focus, resource strings. | n/a |

No ports from this repo on its own; item 1 rides with the NuvioMobile subtitle badge. Items 5-7 are checks only. The 2026-11-23 checks (season search retry, ASS sizing, Skip Intro fade, Details rows) and the 2026-11-21 checks stay open.

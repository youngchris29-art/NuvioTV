# FEAT-5 spike: external-player handoff on tvOS (Infuse / VLC)

**Verdict: FEASIBLE, with caveats** — solid for Infuse; VLC unconfirmed on tvOS until tested on hardware. (Research spike, 2026-07-22.)

## Findings

- tvOS supports `UIApplication.shared.open(url)` / custom URL schemes app-to-app the same as iOS — confirmed by Apple staff on the dev forums ([thread 18271](https://developer.apple.com/forums/thread/18271), [thread 26795](https://developer.apple.com/forums/thread/26795)). No generic "send to player" API exists; the target app must implement a scheme handler.
- **Infuse**: Firecore documents x-callback-url playback on Apple TV since Infuse 7.6.2 (Oct 2023) — [API docs](https://support.firecore.com/hc/en-us/articles/215090997-API-for-Third-Party-Apps-Services), [community thread](https://community.firecore.com/t/add-x-callback-url-schemes-on-apple-tv/34181). Format: `infuse://x-callback-url/play?url=<encoded>&filename=<name>&sub=<encoded>` (+ optional `position`, `x-success`/`x-error` callbacks into `nuviotv://`).
- **VLC**: `vlc-x-callback://x-callback-url/stream?url=<encoded>` is documented for iOS only; tvOS behavior unverified ([VideoLAN forum](https://forum.videolan.org/viewtopic.php?t=120695), fetch bot-blocked). Plain `vlc://` just rewrites to `http://` — not useful. Ship Infuse first; test VLC on hardware before exposing a button.
- App Review: standard sanctioned x-callback-url usage; no tvOS guideline blocks it.

## Implementation notes (beta.5)

1. `Info.plist`: add `LSApplicationQueriesSchemes` = [`infuse`, `vlc-x-callback`] (required or `canOpenURL` silently returns false).
2. Hook point: `StreamPickerView.play()` (~:304-345) where the resolved playable `URL` exists, branching *before* `PlayerEngineRouter`.
3. Gate button visibility on `canOpenURL` at view-appear so testers without Infuse never see a dead button.
4. Pass `filename` (title) and subtitle URL when available; consider `position` for resume handoff.

## Draft Reddit reply

> Good news — this is doable, at least for Infuse. tvOS supports the same URL-scheme handoff iOS does, and Infuse has a documented `infuse://x-callback-url/play?url=...` API that works on Apple TV (added in Infuse 7.6.2). Planning an "Open in Infuse" option that hands off the stream URL directly, with the button only showing if Infuse is installed. VLC's scheme support is documented on iOS but unconfirmed on the tvOS build, so VLC is TBD pending testing — Infuse ships first.

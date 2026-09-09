# Reddit draft — reply to u/iquibr's post `1wbmlhe` ("Building a native tvOS client for my own Apple TV")

Parent: <https://www.reddit.com/r/Nuvio/comments/1wbmlhe/building_a_native_tvos_client_for_my_own_apple_tv/>

**Status: DRAFT, NOT POSTED (2026-09-09).** Written for u/youngchris2989 to post as a top-level
comment. SlopMonster **5/5 CLEAN** (`python3 scripts/deslop/deslop.py`, 519 words of visible copy (trimmed from a 638-word first draft at Christian's request; the dropped material, the subtitle-delay refetch hack and the contextualActions re-animation note, stays in the citations above)).
The rival-model cleanse was **skipped**: the `codex` CLI is not installed in this cloud session.
Paste-ready as written: no em dashes, straight quotes. Sweeps: our own comment once posted,
log-don't-file; this is not the beta thread (`1v26ebw`), so its watermark is unaffected.

## Context

u/iquibr (also the author of a Tizen fork, per the thread) posted a write-up of a personal native
SwiftUI tvOS client on Nuvio (Apple TV 4K 3rd gen, tvOS 27, built against the tvOS 18 SDK) and asked
three questions of anyone else on tvOS:

1. Anyone using AVKit's own player chrome rather than custom controls? How do subtitle and audio-track selection behave?
2. How does a build like this hold up on an Apple TV HD?
3. A decent way to profile SwiftUI focus behaviour, short of logging every focus change by hand?

The thread's commenters pointed them at the competing bobsupra/NuvioTVOS port; nobody has answered
the questions. Every claim below was checked against the current submodule (`c41fb67c`) or the
docs before it went in:

- AVKit chrome: `NativePlayerScreen.swift` (`contextualActions` :306, `customInfoViewControllers` removed :251, `allowedSubtitleOptionLanguages` :279), `NativePlaybackCoordinator.swift` (`setMediaSelectionCriteria` :274/:281 once per item :269, subs gate :429, delay hack :864-884, bitmap info row :1112-1123), `SubtitleVTT.swift:4-12` (EXT-X-MEDIA renditions), `PlayerPanelHost.swift:76-93` (Menu in `pressesBegan`), `PlayerEngineRouter.swift:33-72` (mpv routing), `docs/tvos-hybrid-player-plan.md:12-15`.
- Apple TV HD: `project.pbxproj` `TVOS_DEPLOYMENT_TARGET = 26.0` (all tvOS configs); floor decision `docs/research/appstore-edition-research-2026-07-26.md:199`; memory `docs/tvos-hybrid-player-plan.md:161` and `StreamBadges.swift:239`; tester hardware AppleTV11,1 / 4K 3rd gen throughout the tracker. Note: `INSTALL.md:7` still says "Apple TV HD or Apple TV 4K running tvOS 26+", which is impossible for the HD; worth a separate one-line fix.
- Focus: `SidebarOverlay.swift:647,680` (`UIFocusSystem` dead-end check + `didUpdateNotification`), `DetailView.swift:44-46,190-193` (`debug_ux6` AX probe and why), `RowLeadingEdgeTests.swift:108-122,233-236`, `NuvioTVUITests.swift:438-447`, `AboutSettingsPane.swift:110,414` (diagnostics toggles), `CollectionFocusFrameProbe.swift:11-16`, `BrowseComponents.swift:1593,2666` (sim vs device rest), `DetailView.swift:1231-1236` and `SettingsView.swift:42-52` (the two pitfalls offered back).

Deliberately left out: nothing about beta builds or a download link (their post says it is a personal build and they are not distributing), and no pitch to collaborate; the commenters already made that ask and the reply reads better as a peer answer.

---

## The draft

> I maintain one of the other native tvOS ports (https://github.com/youngchris29-art/NuvioTV, SwiftUI over Nuvio's Kotlin core), so I've hit the same three walls. Answers in order.
>
> **AVKit's own chrome.** Yes, our native engine keeps AVPlayerViewController's transport bar, and subtitle and audio selection through the system menus works well as long as every track is in a media selection group before playback starts. That "before" is the whole trick. AVPlayer can't open MKV, so we remux with an FFmpeg stream copy to a local HLS playlist, and add-on subtitles go into the master as EXT-X-MEDIA WebVTT renditions. AVKit reads the master once, so a subtitle that arrives after the first frame never shows up in the picker. We gate playback on the subtitle fetch, with a timeout, for that reason. Three more things that bit us:
>
> * Set preferred languages with setMediaSelectionCriteria once per item. Apply it again later and it overrides the user's manual pick.
> * Bitmap subtitles (PGS, VobSub) are dropped without a word, so we show an info row saying why. customInfoViewControllers renders as an "Info" pill under the seek bar on tvOS 26, so we draw our own panel instead.
> * A Menu press the player doesn't consume pops the fullScreenCover it lives in, and onExitCommand on cover content never fires on tvOS. We intercept Menu in pressesBegan on a host controller.
>
> Anything AVPlayer refuses (AV1, VP9, two-layer Dolby Vision profile 7, some audio) goes to a libmpv engine with custom controls, so we ended up with both.
>
> **Apple TV HD.** Honest answer: no idea, and I'd like to hear from anyone who tries. Our deployment target is tvOS 26 and the HD stopped at 18, so it can't install our build, and every tester we have is on a 4K. You're on the 18 SDK, so you might be the one who finds out. What I'd watch is memory. Our remux path plateaus around 630 to 650 MB on a 4K playing a 2160p Dolby Vision remux, against a per-process jetsam ceiling near 2 GB. The HD has 2 GB total.
>
> **Profiling focus.** No silver bullet, but three things got us off hand logging:
>
> * On device, UIFocusSystem.focusSystem(for: window).focusedItem == nil is our dead-end detector, and UIFocusSystem.didUpdateNotification lets you watch every focus move from one place without touching each view.
> * On the simulator, don't trust hasFocus. The tvOS 27 runtime never reports it reliably, and a Button's hasFocus stays false while the Cell wrapping it is what flips. We put an invisible Text with an accessibilityIdentifier on screen that carries state (anchor, scrolling, geometry, a sequence counter) and have XCUIRemote-driven UI tests read it off one app.snapshot() walk.
> * For testers on release sideloads, the same probes are toggles in the About pane, so they can turn one on and send a photo.
>
> The sim's focus engine also rests differently from hardware on an over-tall focusable frame, so some focus bugs only exist on the device.
>
> One for your list: a row without .focusSection() needs near-perfect horizontal alignment, or the engine reports no upward candidate at all. That one took us a while to see.

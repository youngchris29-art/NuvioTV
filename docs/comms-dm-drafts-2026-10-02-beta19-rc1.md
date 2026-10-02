# DM draft, beta.19-rc1 (2026-10-02)

To: u/mrStevenx3 (Reddit chat)
Status: SENT 2026-10-02 1:30 PM ET via the ego-browser chat session (one bubble, 1,687 chars, filebin link + commit 5f2d5cd3 verified in the bubble text).
Lint: 5/5 CLEAN (deslop.py, first pass, 245 words of copy)
Cleanse skipped: Codex usage limit.
Build 133, commit `5f2d5cd3`, tag `tvos-v0.3.0-beta.19-rc1`. IPA 27,601,572 B (sha256 2f47c7f0f6ad8535…), copy `~/Downloads/NuvioTV-beta19-rc1.ipa`; litterbox 500ed on six attempts and catbox stored a 0-byte object, so filebin (expires 2026-10-09T17:01Z) is primary and gofile the backup, both verified at the full size.

---

```
Hi Steven, thanks for the beta 18 verdict. beta.19-rc1 answers it.

https://filebin.net/nuviotv-beta19-rc1-bf1ed601/NuvioTV-beta19-rc1.ipa
(filebin, good until Oct 9; backup: https://gofile.io/d/fgzqIy9C). Build 133. Settings, About should show commit 5f2d5cd3.

Your list:
- The title bounce and the one second settle are fixed.
- Up from the first row now goes into the hero.
- Soft row edge fade runs to the screen edge.
- The folder header stays in a fixed spot when you scroll.
- Meta lines are heavier, the description page has a glass synopsis panel and a darker scrim, and Open Sans is a bit smaller.
- Tab bar: it is now linked to Home's rows explicitly. About, "Tab Bar Scroll Link" is on by default.
- New: Depth Takes Poster Color, off by default.

Also new, all off or Auto by default:
- Settings, Playback, Next Episode, "Preload Next Episode Sources": off.
- Account Services, Debrid, "Prepare Links for Instant Playback": Off (0 to 5).
- About, Trailer Max FPS and Trailer Buffer: Auto. Trailer Letterbox Probe Off: off. Leave them unless I ask.
- About, Trailer Diagnostics now has a playback line. If a trailer stutters, send a photo of it.

One change for everyone: dismissing the up-next card no longer blocks autoplay if the episode plays to the end.

I am not ignoring your detail view redesign request, the Netflix / Apple TV style description page. I am looking into it currently.

From you: the two Tab Bar Geometry photos, labelled which is pane A and which is pane B.

Merci!
```

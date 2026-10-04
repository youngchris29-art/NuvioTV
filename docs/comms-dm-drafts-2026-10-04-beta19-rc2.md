# DM draft, beta.19-rc2 (2026-10-04)

To: u/mrStevenx3 (Reddit chat)
Status: DRAFT, not sent. Send only on Christian's go.
Build 134, commit `7e71ba87`, tag `tvos-v0.3.0-beta.19-rc2`. IPA 28,201,295 B (sha256 162cfea0a0830e8f…), copy `~/Downloads/NuvioTV-beta19-rc2.ipa`, litterbox (72 h, until ~2026-10-07 06:50 ET), content-length verified.
Lint: 5/5 CLEAN on each bubble (deslop.py; one rule-of-three reshaped in bubble 1). Cleanse skipped: Codex usage limit (until 10-29).

Answers his beta.19-rc1 verdict (DM 2026-10-02, 5:09 PM ET, plus the 6:39 PM and 3:22/3:29 AM notes); no reply to that verdict was sent before this. Carries the Detail + Settings revamp (merged 2026-10-03, his Netflix / Apple TV style description page request) and the rc1 verdict fix batch. Two bubbles: the build, then his questions.

---

Bubble 1:

```
Hi Steven, beta.19-rc2 is up. It answers your rc1 verdict and has the new description page you asked for.

https://litter.catbox.moe/3asje5.ipa
(good for 3 days, until Oct 7)
Build 134. Settings, About should show commit 7e71ba87.

The description page is new: a cleaner layout with the logo, ratings and a short synopsis up top, and the details at the bottom. To compare with the old one: Settings, Detail Page, Detail Layout, Classic. Also new in Detail Page: a switch for each section (all on), Hide Spoilers in Unwatched Episodes (off), and a Start Over button when you have progress. Settings is regrouped, and the right side explains the focused row. The diagnostics moved from About to a Developer section.

Your list:
- The hero no longer shows two titles: the old one fades out first.
- Trailers keep working after you come back from Infuse.
- Inline trailers start about 1 s after the row stops. Settings, Home Screen, Trailer Start Delay: Automatic, or 1, 2 or 3 s.
- The trailer card keeps the poster colour ring, and moving off mid-animation leaves no gap or ghost logo.
- Sharper art on a 4K TV: 4K backdrops, bigger posters, full-size logos. The hero sharpens about a second after you stop.
- Row edge fade is rebuilt. It now covers every row on the description page, Episodes included, and Search and the collection page have it too. Settings, Appearance, Row Edge Fade: Soft cost a few frames on my Apple TV, so the default is Off. If you had picked Soft before, you keep it.
- Collection page: the title rises and stays, with the chips under it.
- Auto-Play Best Source picks the best link: resolution, then HDR or Dolby Vision, then cached, then file size. So a bigger REMUX can win over a WEB-DL with Atmos.
- "Preparing Dolby Vision" only shows for Dolby Vision files.
- The description page labels and status are translated, the dark wash is lighter, and the glass stays the same when you scroll.
- Tab bar half visible: I could not get it on my TV. If you still see it: Settings, Developer, Tab Bar Rest Fix. Try Relink, relaunch, then Snap to Top. Off by default.

Also fixed: a crash when leaving the player after several sources failed in a row, and "0m" or "N/A" on films that are not out yet.
```

Bubble 2:

```
Your questions:
- Prepare Links for Instant Playback: with AllDebrid on fiber the gain is small. It only skips the 1 to 3 s link step when you press Play on one of the first few links after the list has been open a few seconds, and it uses your link allowance. Fine to leave it Off.
- Trailer Max FPS, Trailer Buffer and the Letterbox switch: leave them on Auto unless I ask.
- Open Sans has no size control: the system font follows the tvOS text size, but Open Sans is a font we ship, and the layout is measured at its normal size.
- Dolby Vision and Atmos: Dolby Vision plays in the built-in player. Atmos only survives in Dolby Digital Plus. TrueHD and DTS become 5.1, so Infuse is the better player for those.
- The striped Netflix tile is an animated cover, not a bug.

One question back: is Settings, Video and Audio, Match Content, Dynamic Range on?

Merci!
```

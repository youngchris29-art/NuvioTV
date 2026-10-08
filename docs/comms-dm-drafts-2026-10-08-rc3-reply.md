# DM draft: reply to Steven's beta.19-rc3 verdict + 10-08 follow-ups (2026-10-08)

Context: his rc3 verdict (DM 2026-10-06 2:11 + 2:20 PM ET, two videos), the Wako "Soon - New Home" link
(10-07 10:03 PM), the Classic Show Hero on/off photos (10-08 11:03 AM) and the rail-hidden ask (11:06 AM).
Triage: `docs/steven-beta19-rc3-verdict-2026-10-06.md`. Nothing built yet; the "next build" lines are the
mechanical items from the record's batch order (D1, S8, S7, C1, S3, the folder logo collision, BUG-154's
folder line, FEAT-62). The design calls (wash shape, speed, add-on name, logo placement) are told as
"looking at it". Reply via Reddit chat, two bubbles. SlopMonster: lint 5/5 (707 words); Codex cleanse SKIPPED (refresh token expired 10-08, `codex login` needed). NOT SENT.

---

Bubble 1:

Hey Steven, thanks for the videos. Both were worth the download: the first one showed me three things I could not have found from the description alone.

What I found, in your order:

- Black square on the description page: the logo slot shows a grey loading surface for about a second before the logo lands. It will show the title text instead. Next build.
- Logos missing on the trailer tiles: it is not French vs English trailers. The tile only draws the logo the catalog sends with the title, so titles from TMDB-based rows fall back to text, while the big art at the top finds a logo through TMDB. The tile will use the same path. Next build.
- Top bar inside collections: both cases are on the list, the bar staying after Back on the old Home, and the bar never hiding on a one-row collection on the new one. Next build.
- Row headings too high, and the collection logo climbing under the top bar: both next build.
- Add-on name on every row heading: that is on purpose on the new Home, and it does not follow the "catalog type" switch. I will make it optional.
- Rows in English: those catalogs send English text. The official app pulls the French title and synopsis from TMDB; the new Home will do the same.
- Black poster in your Top 10 series row (slot 3 from 2:30 on): seen, on the list with the other weekend items.
- Fog on the ambient background, the blur reaching both sides, the animation speed, where the collection logo should sit: noted, looking at those. The blur-only-on-the-lower-part idea is a good one.
- OLED darkening late, and the collection hero looking soft: I could not see either on the phone video. A photo of the collection page at rest would help.
- First scroll stuttering on Monstre: the page is heavier (four episode cards, cast, four trailers, suggestions), so that one is a profiling job.
- The Apple TV app / Fusion logo that fades in at the top on the first scroll: I like it. It goes with the darker area behind the synopsis and the easier way to the full text, as one pass on the description page.

The flicker with Fade on is the known cost of that mode. It dropped frames on my Apple TV too, which is why it ships off. Leave it off.

Bubble 2:

On the old Home: the no-bounce part is the new Home's structure, so it does not carry over. The longer synopsis is what you found yourself this morning. With Show Hero off, the panel gives you four lines and the source count. With Show Hero on, the hero has to leave room for the row under it, so the text gets two lines, one with zoom. I will add the source count to the hero version. The line count stays tied to that room.

Sidebar on the first row: the rail has Always Visible and Hide While Browsing, and the second brings it back at the top of a page on purpose. A third mode, hidden until you press Left on the first card or Menu, is a small change. Next build.

And thanks for the Wako clip. The hero carousel on page one, then one row per page with the text under the big card, is the same vertical scheme as the new Home. The text-under-the-card placement is the option you asked for earlier; I have it noted for the new Home.

Talk soon.

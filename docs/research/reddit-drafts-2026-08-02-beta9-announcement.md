# Reddit drafts, 2026-08-02: beta.9 announcement + UX-7 reply

Posting notes:
- Post the announcement as a new top-level comment on the beta thread; post the reply directly to `p12cg5v` (u/mrStevenx3's video comment).
- Automod: avoid "torrent" and the two debrid-service names that tripped Rule 6 before. These drafts are already clean. Use the markdown editor, straight quotes only.
- No em dashes anywhere (matches your posted style).

---

## Draft 1: beta.9 announcement (top-level comment)

**Beta 9 is up** (build 105): https://github.com/youngchris29-art/NuvioTV/releases/latest

This one is almost entirely your feedback, and it is the biggest batch so far. Everything below was tested on a real Apple TV before release.

Fixed:

- Card shape, card depth, edge coverage and corners apply again, instantly, including right after switching profiles. This was two separate bugs stacked on top of each other.
- White-on-white text is gone everywhere we could find it: the Settings panes, the stream list badges (including custom regex badges), and a few icons. Every theme, focused or not.
- Hero paging left works now, by click or by swipe, both directions, with wrap-around.
- A trailer expanding on the last poster in a row slides fully into view instead of getting cut off.
- Cold starts are faster. It turns out the artwork disk cache had never actually worked in any beta, so every launch re-downloaded everything. Fixed.
- Marking a fully watched series as unwatched works again.
- Pressing Menu from deep in the Home page jumps you back to the top.

New:

- **Settings -> About.** Version, build number and exact release tag. When something looks off, you can now tell me exactly which build you are on. This build says 0.3.0 (105). This should fix the "did the fix actually land for you?" loop for good.
- **Search Sources** (Settings -> Content Sources): pick exactly which catalogs power search.
- Trailer controls: how long the background trailer plays (30s / 1 min / 90s / always) with a smooth fade back, and whether trailers start with sound.
- Icon-only detail buttons and a minimal Settings style, both optional.
- Detail pages now dim toward black as you scroll down into the details.

Two honest notes:

- **Trailer quality:** some of you were right that trailers look soft, and it was not all one bug. One real quality-selection bug is fixed in this build. The rest is a YouTube-side change that caps many newer videos at low resolution for third-party apps. A proper fix for that part is in active development.
- **Known issue:** after scrolling down Home and walking back up with the directional pad, the top tab bar can re-appear partially cut off until you move focus through it. Cosmetic, and pressing Menu to jump to the top never triggers it. Being worked on.

As always, sideload with a free Apple ID (instructions in the release). If you retest something, check Settings -> About first and include the build number. Thanks especially to u/mrStevenx3, whose 15-point review and follow-up video drove most of this release.

---

## Draft 2: reply to u/mrStevenx3 (`p12cg5v`)

You are right, and I owe you an answer on the hero feature first, because you have asked for it more than once and I kept answering everything around it.

**Yes, I am building it.** What you described: the focused movie's own backdrop on the right, title and description on the left, updating live as you move focus between posters, like your Lucy screenshot. Not a rotating hero, the actual focused title. It is now the top item on my list for the next beta. The "Hide Hero Artwork While Browsing" toggle exists because two testers asked for opposite hero behaviors, but I agree it is not what you want. What you want is better, and it makes that whole toggle argument disappear.

On the rest, beta 9 just went up and your video paid for itself several times over:

- The **white-on-white regex badges** you showed in the stream list: fixed.
- The **cropped trailer at the end of a row**: fixed, it slides into view now.
- **Build numbers:** you could not find one because the app genuinely never showed it anywhere, which was my bug, not yours. There is now a Settings -> About screen with the version, build and release tag. This build reads 0.3.0 (105). If you tell me that number with future reports, the "did the fix land for you" guessing ends forever.
- **Trailer quality:** you were right that it is every trailer, and that clue mattered. Two separate problems. One was a real bug in how the app picked the stream quality, fixed in beta 9. The other is on YouTube's side: many newer videos no longer offer third-party apps a proper high-resolution stream, which caps them around 360p no matter what the app does. I am actively working on a way around that, and it is my top technical priority after the hero.
- **GIF smoothness:** your video is exactly what I needed and I am still working on this one. Once you are on beta 9, tell me if it feels any different along with the About build number, and I will take it from there.

The language barrier is no problem at all, by the way. Your videos and screenshots have been more useful than most written reports. Thanks for sticking with this.

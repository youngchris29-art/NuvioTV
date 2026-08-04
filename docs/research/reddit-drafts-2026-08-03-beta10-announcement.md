# Reddit draft, 2026-08-03: beta.10 announcement

**POSTED 2026-08-03 night as `p1khg3l`** (https://www.reddit.com/r/Nuvio/comments/1v26ebw/comment/p1khg3l/) — text below went out verbatim via the markdown editor.

Posting notes:
- Post as a new top-level comment on the beta thread once the tvos-v0.3.0-beta.10 release is live on the public repo.
- Consider a short direct reply to u/mrStevenx3 pointing at the hero section of this comment (their `p12cg5v` ask is the headline; they said it was their daily-driver blocker).
- Automod: avoid "torrent" and the two debrid-service names that tripped Rule 6 before. This draft is already clean. Use the markdown editor, straight quotes only.
- No em dashes anywhere (matches your posted style).
- A short screen recording of the pinned hero following focus would land well here, same as the beta.6 video did. Reddit comments accept direct mp4 upload.

---

## Draft: beta.10 announcement (top-level comment)

**Beta 10 is up** (build 106): https://github.com/youngchris29-art/NuvioTV/releases/latest

This is the hero update. u/mrStevenx3 has been describing this layout since their "Lucky" screenshot several betas ago, and it is now real, and it goes further than the original ask:

- **The hero follows your focus.** As you move between posters, the hero swaps to that title: backdrop on the right, title and description on the left, updating live. Not a rotating carousel showing something unrelated, the actual movie you are on. This is on for everyone, no setting needed.
- **The hero is pinned.** With **Nuvio-Style Hero** turned on (Settings -> Home Screen), the hero no longer scrolls away. It stays at the top of the screen while only the rows scroll underneath, so the focused title's artwork and description are always in view, no matter how deep you browse. The pinned layout is a slightly more compact hero so a full poster row always fits below it.
- **See All moved into the rows.** The full-catalog link is now a card at the end of each row instead of a button floating next to the title. Scrolling up and down the Home page feels a lot more predictable because of it.

I want to be honest about the work behind this one: the first build of the pinned hero passed every automated test and then fell apart on a real Apple TV, because the TV's focus engine rests scroll positions differently than any simulator. It took eight rounds of build, test on the living room TV, fix, repeat to get rows, titles and captions resting cleanly at every scroll position. If you find a spot where something still gets cut off at the top or bottom of the screen, tell me exactly where and I will chase it.

Also new:

- **Trailer thumbnails on the detail page.** The Trailers & Extras row now shows proper 16:9 preview images instead of text rows.
- **Accent Focus Ring** (Settings -> Appearance, off by default): the focused poster gets a ring in your accent color instead of the standard lift, if that is your thing.
- **1080p trailers are actually in this build.** The workaround for YouTube capping third-party apps at low resolution landed after the beta 9 cut, which is why beta 9 still looked soft. This build carries it.

Fixed, mostly from u/mrStevenx3's 11-point beta 9 review:

- **Search Sources works now.** It shipped broken in beta 9: your selection was ignored and wiped after every search, and the first row was white-on-white. All three parts fixed. Sorry about that one, it was tested too late in the cycle.
- **The GIF row stutter.** Third time reporting this one, so I will not oversell it: the actual cause (image decoding and cache teardown on the main thread, around every scroll step) is fixed in this build, and it held up smooth on real hardware in the exact scenario from your video. Tell me if your Services row agrees.
- Actor pages no longer auto-scroll down and trap you there.
- The card depth effect stays inside the artwork on every poster, not just some of them.
- Collection tiles respect your corner setting before focus, not only after.
- The profile picker starts with your main profile focused.
- Focus trailers fill the card instead of playing letterboxed.

As always: sideload with a free Apple ID, instructions in the release notes. If you retest anything, Settings -> About should read **0.3.0 (106)**, include that number with your report. Thanks again to u/mrStevenx3 for the review and the videos that drove most of this, and to everyone still testing.

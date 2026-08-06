# beta.10 review reply to u/mrStevenx3 — draft (conversational + bullets, no em dashes)

**✅ POSTED 2026-08-05 12:48:37Z** as [`p1ugx2g`](https://www.reddit.com/r/Nuvio/comments/1v26ebw/i_built_a_native_apple_tv_app_for_nuvio_beta/p1ugx2g/),
a direct reply to `p1q89ph`, at Christian's explicit instruction. Posted through **ego-browser**
(the Claude-in-Chrome extension was not connected, and the release script's OAuth token is scoped
`read edit`, so it cannot create comments). Route: `old.reddit.com`, whose plain markdown textarea
posts the body verbatim with no rich-text conversion. Verified three ways: the textarea content
hashed byte-identical to this file before submitting (sha256 `d30c8faf5141ccd7`), the thread JSON
showed exactly one new comment with `parent_id = t1_p1q89ph` and length 5238, and the public Atom
feed then returned it — so it is publicly visible and automod passed. The text below is the
as-posted version, unchanged.

**One snag worth remembering:** the first submit attempt died with `CDP request timed out:
Input.dispatchMouseEvent`. **Nothing posted** — confirmed against the thread JSON before retrying,
which is the check that matters, because a blind retry there would have double-posted. The retry
used a DOM-level `btn.click()` instead of a synthetic mouse event and worked first time. Prefer
the DOM click for old.reddit form submits.

**Was: post as** a direct reply to u/mrStevenx3's 16-point beta.10 review (`p1q89ph`)
https://www.reddit.com/r/Nuvio/comments/1v26ebw/i_built_a_native_apple_tv_app_for_nuvio_beta/p1q89ph/

**Automod notes:** no debrid brand names, no "torrent", low filter risk. No backticks, no em
dashes in the body. Composer gotchas as usual (verify the expanded composer before typing;
validation lags ~3-6s).

**Language note:** the reporter reads via a translator. Short sentences, plain words, no
idioms, no jokes that depend on wordplay.

**Grounding:** every claim below is backed by the frame-by-frame pass on their video
(`docs/research/p1q89ph-video-evidence/`, analysed 2026-08-05). The four asks at the end are
exactly the four things the video could NOT settle, so this reply should not need a follow-up
round of clarifying questions.

**Deliberate choices worth checking before posting:**
- It leads with the two failures (search, highlight) rather than the wins. That matches how
  bad the second-failed-fix looks from their side, and they have earned it.
- It tells them about BUG-45, the blank Settings row we found in their own video. That is
  free credibility for the "please keep filming" ask, which is the highest-yield behaviour
  this tester has.
- It does NOT promise dates. Same as every prior reply.
- It does not re-ask for a typed build number. They filmed the About screen instead, which is
  better, so the reply asks for that as the new habit.

---

Thank you for this review, and thank you especially for the video. Sixteen points, and it is the most useful thing anyone has sent me in this beta. I went through the whole clip frame by frame.

Two things it gave me before I even reached your list:

- **You filmed the About screen.** That answered the build question without you having to type anything: 0.3.0 (106), commit d7ad446f, tvOS 26.5, Apple TV 4K second generation. Filming that screen is all I need from now on. It also means I finally know your hardware, which matters for the speed items below.
- **I found a bug in your video that you did not report.** When you open Settings, the selected row in the left menu goes completely blank. White text on a white background, again. You never mentioned it, probably because it comes back as soon as you move away. I would not have found it without your clip.

**First, the two I got wrong.**

- **Search sources: still broken, and this is the second time I told you it was fixed.** You are right, and I am not going to explain it away. Your video did show me one half clearly. The text on the focused search chip is grey on a nearly white background, so my fix did reach that row and then used the wrong colour. That part I can fix properly now. The other half, deselected catalogs still appearing in results, I still cannot see. Both of your videos show the search screen, but neither one shows a search actually being typed. I am not going to guess at it a third time, so there is an ask about this below.
- **Poster highlight, top only: still wrong for you.** This one is strange and I want to be honest about it. I fixed it, I checked it on my own Apple TV, and on my TV it is correct. It is still wrong on yours. That points at your setup rather than the drawing code, most likely the setting never reaching the screen at all. So I am going to add a check for that instead of changing how it is drawn for a seventh time.

**Confirmed from your video. These are all being fixed.**

- **The untranslated films and the hero not being smooth are the same bug.** Your video caught it. The hero shows The Devil's Mouth with English text, and one second later it fades into La Bouche du Diable with French text. The same film, twice. The hero shows the catalog's own text first and then replaces it with the translated version. When that second step arrives late you see the swap, and when it never arrives you get English. One fix for both problems.
- **Focus zooming only the inside of the poster: I caused this.** Fixing your top only highlight last build meant clipping the artwork, and that changed how focus looks everywhere. I will put the whole card zoom back. You have now told me twice that Nuvio does not zoom posters at all, so I will add that as an option too.
- **Collection backgrounds missing:** confirmed. In your video they are plain coloured rectangles with only the name on them. No image at all.
- **GIF quality:** thank you for confirming they are smooth now, that took three builds. The quality drop is my fault. To stop the freezing I put a memory limit on each GIF, and I set it too low, so they are being shrunk too far. I will raise it without bringing the freezing back.
- **Genres instead of the catalog list in search:** agreed, and it is easier than I thought. Your genre row is already there, directly under the catalog row. So this is just removing the catalog list.
- **The play and mute icons on the trailer:** agreed, removing them. You are right that the setting replaced them.
- **The language badge in the light theme:** confirmed, small fix.
- **Not being able to scroll back to the top of the description:** confirmed. It is the same family as the actor page problem you found last time. Part of that screen has nothing above it for the focus to move to.
- **Description scrolling feeling choppy:** I believe you, and I am going to measure it rather than guess. Three separate things changed on that screen last build.
- **An option to turn off the scrolling hero and keep the description:** yes. You have described this three times now and I finally understand it properly. You do not want a rotating banner at all. You want the film you are on. I tied those two settings together in this build and that was the wrong call. I will separate them.

**Four things I need from you.**

1. **The catalog titles that disappear.** This is the one thing I could not find anywhere in your video. Which row was it, was Nuvio Style Hero on or off, and roughly how far down did you scroll before coming back up?
2. **The search filter.** Please type one search while only two or three catalogs are selected, and film the results. That is the exact piece both videos are missing.
3. **The white focus outline showing grey.** Which screen was that on, and do you have Accent Focus Ring switched on in Appearance? I measured the outline in your video and it looked white to me, so I am looking in the wrong place.
4. **The trailers that still have black bars.** In your video the ones on the home screen fill the card correctly. Is it the full screen player, or the new trailer images on the film page?

Sixteen points, a video, and the build number. Thank you. This is the review that made the next build.

---

**After posting:** mark the reply posted on the tracker (BUG-31, BUG-33, BUG-35 through
BUG-45, FEAT-15, UX-8, UX-9, UX-12), and set the next sweep to watch for the four answers
above. The two that unblock real work are (1) the catalog title repro and (2) the filmed
search, since both items are currently stalled on evidence rather than on effort.

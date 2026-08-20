# Drafts, 2026-08-20: reply to u/mrStevenx3's beta.13 review (`p4to4kj`) + GitHub issue replies

Status: **ALL THREE POSTED 2026-08-20 (approved by Christian in-session).**
- Reddit reply: [`p4vpqik`](https://old.reddit.com/r/Nuvio/comments/1v26ebw/i_built_a_native_apple_tv_app_for_nuvio_beta/p4vpqik/), child of `p4to4kj` — posted via ego-browser on old.reddit.com, textarea byte-verified against this draft before submit, publicly confirmed via the comment's Atom feed. Route note for next time: the first submit attempt via CDP mouse click timed out (no post happened — verified before retrying); a page-JS `button.click()` landed it. The reply form is `#commentreply_t1_<id>`, NOT the first `form.usertext` in the thing (that's the comment's own body form).
- GitHub #1: https://github.com/youngchris29-art/NuvioTV/issues/1#issuecomment-5360406224
- GitHub #2: https://github.com/youngchris29-art/NuvioTV/issues/2#issuecomment-5360406341

Automod check: no flagged vocabulary (no debrid brand names, no torrent terms), clean for
r/Nuvio Rule 6. Note: the header above this line is internal; only the sections below get
posted. Em dashes removed and register loosened per Christian's 08-20 request.

---

## 1. Reddit reply to `p4to4kj`

Thanks for putting beta.13 through its paces the same day it shipped. And thank you for the
video. Honestly, it ended up being worth more than a dozen written reports. I went through it
frame by frame and it confirmed four of your points exactly as you described them, plus it
answered two things I never could have figured out from words alone.

Here's what's already fixed for the next build (a small hotfix, 0.3.0-beta.13.5):

- **French trailers playing in English (72 Hours, Drop Game):** found it. The beta.13 trailer
  fix widened the lookup so there's always an English fallback, but the sorting still let an
  official English trailer beat a French one. Your language now wins outright. Your two titles
  are literally the test cases now.
- **White-on-white in Appearance:** your video showed me the exact spot, the highlighted
  "accent focus ring" row washing out (around 2:13 in your clip). That row's contrast is fixed,
  the color swatches got a clearer focus ring too, and there's an automated check on it this
  time.
- **Square corners:** season posters, trailer thumbnails, and episode stills all follow the
  Corners setting now. I swept the whole detail page instead of patching one tile, and added a
  rule to the checklist so new surfaces can't ship without it again.
- **Season selector:** the "Episodes" heading moved below the season row. Fun fact, it was
  also the one piece of text on that screen that ignored your language setting, which is why
  it never showed as "Épisodes". Both fixed. And the season label no longer hides under the
  zoomed poster.
- **Actor descriptions in English:** I checked TMDB directly on this one. For the actors on
  FROM's page, TMDB simply has no French biography at all. Their own website shows the same
  English text on its French pages. The app already asks for French and falls back, so this
  is a gap in TMDB's data rather than a bug on our side. That little "Acting" label under the
  name was ours though, and it's localized now.
- Bonus from upstream: a **Strip SDH Subtitles** toggle (hides [sound cues] and speaker labels
  in subtitles). You'll find it in Playback settings.

Two things I could use your help with:

- **The ring + zoom:** here's the thing your clip shows. At the very end, in the settings
  shot, "No Zoom on Focus" is off. With that toggle off, focused cards zoom by design, ring
  or no ring. So my question is: do you normally run No Zoom ON, and still see posters zoom
  when the ring is enabled? If so, on which screen? Our automated check for exactly that combo
  (ring on, No Zoom on) shows the posters holding still, so a screen name or one more short
  clip would tell me what's different on your box.
- **The top bar (both problems, the stuck-visible one and the clipped one):** I'm treating
  these as one investigation now. You've been describing the stuck bar since the start and I
  kept reading it as a design request. That one's on me. When it next gets stuck, could you
  film it and tell me roughly how long the app had been running? That time factor is the best
  clue there is.

And for the duplicated hero: beta.13.5 adds **Settings → About → Hero Paint Diagnostics**.
Turn it on, quit and reopen the app, and when you see the doubled hero, a short log shows up
right under the toggle. A photo of that screen tells me exactly which mechanism fires on your
box. My test devices flat out refuse to reproduce this, so your Apple TV is the only place
the answer exists.

Thanks again for offering the Collections JSON. Whenever you get to it, DM it as a file or
pasted text, whichever is easier, and if the export gives you any trouble I'll walk you
through it.

One more thing on "Nando entre dos mundos": I looked it up on TMDB and that film has no
videos at all in their database, in any language. So there's genuinely no trailer to play.
But if the app shows you a trailer button there anyway and it just spins, tell me, because
showing nothing would be the right behavior and that part would be ours to fix.

---

## 2. GitHub issue #1 (ozdek, "Crashes after logging in")

First off, I'm sorry for the silence here. The Reddit beta thread got all my attention and
this issue tracker didn't. That's my mistake, and it stings extra because your crash log had
the whole answer in it.

Your log shows the exact crash: `__CFPREFERENCES_HAS_DETECTED_THIS_APP_TRYING_TO_STORE_TOO_
MUCH_DATA__`. With 10,000+ watched items, the app was writing your watched history into the
system preferences store, and the OS kills the process outright once that store grows past
its limit. It hit on login, right after your library synced down. Your hunch about it being
a storage issue was exactly right.

The good news: this was fixed in **beta.10** (2026-08-04). Watched history, watch progress,
and four other unbounded stores moved out of preferences into regular files. Your last
comment was on beta.9, literally one build before the fix landed.

Could you try the latest build (beta.13, on the Releases page)? With a library your size,
you're the best possible test of this fix, and I'd really like to close the loop. If it still
crashes, another log like the one you attached before will find whatever's left.

---

## 3. GitHub issue #2 (konrepo, "Some video no stream")

Thanks for the manifest link. Being able to poke at the addon directly made this one
diagnosable.

Found a real bug on our side: streams from your addon (and any addon whose sources need
specific HTTP headers, like a Referer) never played because the tvOS player just ignored the
headers the addon asks for. Nuvio iOS passes them along, which is why the same addon works
there. That's fixed in the next release (0.3.0-beta.13.5): both players now send the addon's
requested headers.

Two things I noticed while testing, worth mentioning:

- Your addon's series catalogs (SundayDrama and the others) are currently returning empty
  from the server (`{"metas":[]}`), so I couldn't test "Prean Neary Chan Sne" end to end.
  That part looks like the addon's scraper or host rather than the app. The KhmerTV live
  channels do respond, and those are what the header fix mainly helps.
- Some of your live TV sources are plain HLS from fairly slow hosts, so buffering there can
  be the source itself. If specific channels still buffer after the update, name them and
  I'll look at those individually.

I'll comment again when the release with the fix is up.

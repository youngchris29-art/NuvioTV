# beta.8 review verdicts reply to u/mrStevenx3 — draft (rev 2, conversational + bullets, no em dashes)

**✅ POSTED 2026-08-01 (just after midnight)** — as a direct reply to `p0rd3tw`, via Christian's logged-in Chrome at his request. Markdown editor, bullets rendered correctly, passed the automod filter first try. The text below is the as-posted version.

**Was: post as** direct reply to u/mrStevenx3's "MAJOR FEEDBACK" comment (`p0rd3tw`)
https://www.reddit.com/r/Nuvio/comments/1v26ebw/i_built_a_native_apple_tv_app_for_nuvio_beta/p0rd3tw/

**Automod notes:** no "torrent"/debrid-brand content, low filter risk. No backticks, no em
dashes. Composer gotchas as usual (verify expanded composer before typing; validation lags
~3–6s).

---

Alright, went through your whole list. Honestly, this review basically became the roadmap for the next beta. Here's where everything landed:

- **Card shape / depth / edge coverage:** Fixed, and you actually caught two separate bugs here. A bunch of per-profile display settings weren't reloading after you picked your profile, so your changes saved fine but the screen kept using defaults. And on top of that, the redesign was letting the system force its own corner rounding over your Corners setting. Both are fixed now. One thing to know: that subtle shine on the focused card when depth is off? That's the tvOS focus effect, not the depth setting. That one's the OS and it stays.

- **Settings text hard to read:** Fixed. This turned out to be your White theme again. A few spots painted the accent color right on top of the focus highlight, which obviously doesn't work when your accent IS white. They flip to a dark label on focus now, same trick as the Play button fix from beta.6. You have a real talent for finding these, this is the third white-on-white bug you've caught.

- **"Hero visual only on focus":** So this one actually works, I tested both states. The thing is, what you described wanting is the toggle turned ON. With it on, the artwork only shows while the hero is highlighted and fades out when you move down into the rows. Give that a try. And yeah, I'm renaming it, because you're the second person it's confused.

- **Hero left navigation:** Fixed, and your report was actually too kind. Left paging wasn't "two presses", it was completely dead. The system was silently eating the press, and that snap-back you saw was just the peek animation settling. One press per page now, both directions, and it wraps around from the first slide to the last.

- **Getting back to the top:** Fixed. From anywhere down the page, just press Menu (back). It jumps you straight to the top with the hero highlighted, and one more press up puts you on the tab bar. Same as Netflix and the TV app do it.

- **Slower cold start:** Fixed, and thank you for this one especially. Your report sent me digging and I found something embarrassing: the artwork disk cache has never worked. Not in beta.8, not in any build ever. Every cold start re-downloaded every single poster, and beta.8 just added enough extra startup work to make it noticeable. Now that the cache actually caches, the next beta should start faster than anything I've shipped so far. Genuinely one of the most valuable reports of the whole beta.

- **GIFs still choppy + trailers still low quality:** These two I need your help with. Both fixes did ship in beta.8, so either my fix only covers part of the problem or your content is hitting a different path than what I tested. Two quick things: can you check Settings > About shows build 104? And can you name one specific collection row where GIFs still stutter, plus one specific title with a low-quality trailer? I'll trace those exact ones instead of guessing.

On your feature ideas (settings style presets, trailer length + smoother return, icon-only buttons, per-catalog search, default trailer sound, caption spacing, background dim on scroll): all written down, and a few are strong candidates for the beta after next. And the hero layout you originally asked for, where focusing a title collapses the row above with info on the left and artwork on the right? I know the current Nuvio-Style Hero isn't that. It's tracked as its own item now, not closed.

Thanks for the most thorough review this beta has ever gotten. The next build is better in about ten different ways because of it.

---

**After posting:** mark the reply posted on the tracker (BUG-22/23/24/25/26/27 rows + the
BUG-19/UX-4c ask), and the next sweep watches for: build-104 confirm, the GIF row + trailer
title, and their reaction to the BUG-24 explanation.

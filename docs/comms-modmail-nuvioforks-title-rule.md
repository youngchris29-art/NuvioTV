# Modmail to r/NuvioForks: broken title rule

Status: SENT 2026-09-29 through the logged-in session (new-Reddit compose form, authorized by Christian). The form cleared on Send; the message listings return nothing for this session, so delivery is confirmed only by that. Reply expected in the Reddit inbox.
SlopMonster: 5/5. Codex cleanse skipped (local codex CLI misconfigured; short piece).

- **To:** r/NuvioForks modmail (mod: u/KforKaptain)
- **Subject:** Title rule blocks every release post, including tagged titles

## Body

Hi, thanks for setting this sub up. I maintain NuvioTV, the Apple TV fork whose thread was removed from r/Nuvio last week, and I'm trying to repost it here.

I can't submit it. The title rule ("Title must begin with a platform tag") blocks the Post button for every title I try, including ones that follow it.

What I tested today in the new Reddit post editor on desktop:

* Flair "Drop / Release", title `[tvOS] NuvioTV: a native Apple TV app built on Nuvio's core`: blocked.
* Flair "Drop / Release", title `[Android TV] Nuvio-Lite v1.2 - Fix`, which is the example from the rule itself: blocked.
* Flair "Work in Progress", title `[tvOS] NuvioTV beta`: blocked.
* Flair "Help / Questions", same title: allowed.

So the rule fires under the two release flairs no matter what the title says. My guess is that the pattern in the rule never matches, maybe because the square brackets need escaping.

Could you take a look? I'd rather wait and post under "Drop / Release" than pick another flair to get around it. The post is a text post with the source link, the IPA link and a section on what the fork changes from upstream, per rule 3.

Thanks,
Christian (u/youngchris2989)

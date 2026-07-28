# beta.6 announcement draft (r/Nuvio beta thread)

Matches the beta.3/4/5 voice: bold intro, bullets crediting reporters by username, plain
technical explanations, honest about what isn't verified, ends with a call for reports.
This one is almost entirely u/mrStevenx3's list — say so up front.

---

**beta.6 is up!** This one is mostly working through u/mrStevenx3's beta.5 review — thank you for the most detailed feedback this thread has had:

* **Wide posters and titles work together now** — if you use the wide 16:9 rows, the focused card no longer grows over the title underneath it (the scale-up now moves the card *and* its title as one piece). You can turn titles back on. And the **tilt/lift effect got a real rework**: it's stronger and anchored at the card's bottom edge, so the card visibly "stands up" toward you — on wide cards the old version was honestly too subtle to notice, which I suspect is most of why you never saw it. One thing to check if you *still* don't see it: tvOS Settings → General → Accessibility → **Reduce Motion** disables the 3D tilt on purpose (the scale-up stays). I'd love to know if that toggle was on.
* **Hero fixes** — hero pages show proper title logo artwork much more often now (a lot of catalogs don't ship logo art with their listings, so the app now falls back to the same artwork source the detail pages use). And the translation half of your report: the hero's title, synopsis and genres come from whatever metadata source feeds the catalog, and those simply don't localize on their own — but **if you add a free TMDB API key** (Settings → Content Sources → Metadata) the hero now fetches all of that **in your language**, including the language-matched logo. There's also a new **Metadata Language** setting right below it — "Device" follows your Apple TV's language automatically, or pick one of 12.
* **German is fully translated** — the 82 remaining German strings from the beta.5 notes are done; nothing should fall back to English anymore. Wenn irgendwo noch etwas komisch klingt: sagt Bescheid.
* **Custom badges no longer squeeze out the stream details** — badges that don't fit collapse into a "+N" chip instead of pushing the size/quality info off the row. Badges and details aren't an either/or anymore.
* **White theme: the Play button is readable again** — same class of bug as the white-on-white rows from beta.3, one more surface found and fixed.
* **"See All" on big addon catalogs** — u/mduckett99's Marvel catalog that cut off after a screenful: rows now show See All whenever the catalog actually has more items, so the full catalog is reachable. Chronological order preserved.
* **Home rows shouldn't scramble anymore** — u/DotAffectionate3955's mixed-up collections: found it. The Home screen wasn't registering your catalog list on launch (only the Settings screen did), so with a catalog-heavy addon like AIOMetaData the row order could collapse — and in the worst case the scrambled order got saved to your account. That's fixed, but since you were the one who could reproduce it: does the order survive a force-quit and relaunch now, *without* opening Settings first? That's the case that used to break.
* **New welcome & sign-in screens** — first-run flow redesigned with the new logo mark and glass buttons. You'll only see it signed out, so most of you won't — but it's there.

On the **profile-screen crash** (the PIN report from u/Overall_Stuff5982): still open, and I won't pretend this build fixes it — I set a PIN on a real cloud profile and hammered every path I could think of on two tvOS versions without a single crash, so it needs something specific to your setup that I haven't found yet. Replying to you directly with a couple of questions.

Grab it from the [releases page](https://github.com/youngchris29-art/NuvioTV/releases/latest) — same sideload process, accounts and settings survive the update. Keep the reports coming; this build is proof they get acted on.

---

**Posting notes (not part of the comment):**

- Post as a top-level comment on the beta thread, same as previous betas.
- **Reply directly to u/mrStevenx3** (`ozss8t7`) — five of their items shipped at once; don't make them find the announcement. Short version:

  > beta.6 is up and it's mostly your list: wide posters + titles fixed, badges collapse to "+N" instead of eating the stream details, White-theme Play button fixed, hero title logos, and — with a free TMDB key in Settings → Content Sources — the hero text/logo now comes in your language (there's a new Metadata Language setting too; catalog sources themselves just don't localize, so the key is the way). The tilt effect also got a real rework — stronger and bottom-anchored, the old one was genuinely too subtle on wide cards. Two questions: (1) is Reduce Motion on in your tvOS accessibility settings? It intentionally disables the tilt, and it'd explain your beta.4/5 reports perfectly. (2) Which tvOS version are you on? Would love to hear how the wide-poster layout feels with titles back on.

- **Reply directly to u/Overall_Stuff5982** (`p00odfr`) — the BUG-11 questions:

  > Thanks for the PIN detail — that's the most useful clue so far. I set a PIN on a real cloud profile and couldn't crash it (correct PIN, wrong PIN, cancel, even the server lockout path, on two tvOS versions), so I need your help narrowing it: (1) does it force-close when you *tap* the profile, or after you *enter* the PIN? (2) which tvOS version? (3) do profiles without a PIN open fine? If you can grab the crash report it names the exact line for me: Settings → General → Privacy & Analytics → Analytics Data, look for entries starting "NuvioTV".

- **Reply to u/DotAffectionate3955** (`ozhe3j8`) with the row-order confirm ask (it's in the main comment, but they may miss it): force-quit + relaunch *without* opening Settings — did the order hold?
- **Reply to u/mduckett99** (`ozrhgz5`): See All shipped, chronological order preserved — is the full Marvel catalog reachable now?
- The "catalog sources don't localize, TMDB key is the way" framing is deliberate — same honest-constraint posture as beta.5's All-Debrid caveat.
- If length is a problem on old Reddit, the welcome-screens bullet is the safest cut, then White theme (it's small and mrStevenx3 gets it in the direct reply anyway).

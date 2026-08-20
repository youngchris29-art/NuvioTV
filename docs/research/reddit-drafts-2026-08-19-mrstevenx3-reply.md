# Reddit draft, 2026-08-19: reply to u/mrStevenx3's beta.12 review (p4afwfo)

Status: BLOCKED BY r/Nuvio COMMENT GUIDANCE (see the beta13 announcement draft doc for the full forensics; bullets 1-2 and the closing line individually ACCEPT, the rest unresolved when rate-limiting set in). Post as a direct reply to `p4afwfo`, separate from (and ideally right after) the
beta.13 announcement comment. House rules: no em dashes, straight quotes, no debrid service
names. Honest claims only; BUG-38 is explicitly NOT fixed.

---

Your review basically wrote beta 13's worklist, so here is the point-by-point. Beta 13 is up
(build 109, releases/latest):

- **Trailers dying with a Metadata Language set: fixed, and your repro cracked it.** Flipping
  the language was the key: lookups quietly failed for titles whose localized metadata carried
  no trailer entries. Trailers now fall back across languages, and changing the language no
  longer leaves a stale window. On my Apple TV with Francais forced, ten previously dead titles
  all play.
- **The letterbox: found it, and it was embarrassing.** The zoom you have been reporting since
  UX-9 was actually being computed correctly the whole time, and then never rendered - the
  video layer sat where the zoom could not reach it. That is fixed, the measured zoom is also
  learned per title and survives relaunch now, and a new reveal gate keeps the artwork up until
  the crop decision is made from real frames, so a letterboxed first frame never flashes. Cover
  art with bars baked into the image gets detected and cropped too. Your side-by-side video vs
  Fusion is what kept this on the board; on my TV trailers fill the cards now. If any title
  still shows bars for you, name it and I will chase that specific one.
- **Hero double-commit: fixed.** The hero commits its artwork once on a cold launch; verified
  over repeated cold launches with the trace on.
- **GIF smoothness: you were right about the trade.** The sharpness work was dropping frames.
  It now keeps every original frame and gives back a little resolution instead - cadence first.
- **The focus ring over the poster edge: fixed.** With No Zoom on, the art insets inside the
  ring instead of the ring painting over it.
- **Season posters: shipped.** The season selector is a row of 2:3 season art now, selected
  season outlined in the accent color.
- Also in this build, two of your older asks: **the title/logo stays on the trailer tile** when
  you run Hide Titles, and **Hide Discover** lives in Settings.
- **Collection covers (BUG-38): not fixed, and I need your help to finish it.** I tried a
  smarter title-logo rule this cycle and it made things worse on curated folders (doubled
  wordmarks), so it was reverted. What would settle it: export your Collections JSON from the
  phone app and share it - this build also logs exactly what every folder tile chose and which
  keys it does not recognize, so your payload plus one log line is the whole answer.
- **On the top pill bar** (since it came up again): it stays. It is the native tvOS tab bar, it
  already minimizes as you scroll like Apple's own apps, and Menu from deep in a page jumps
  back to the top. Rebuilding it custom is the Android-port feel this app exists to avoid.
- **No Zoom on Focus: closing it on your confirmation** - thanks for retesting that one.

Thank you for the structured review format with the video - genuinely the most useful single
comment this thread has had.

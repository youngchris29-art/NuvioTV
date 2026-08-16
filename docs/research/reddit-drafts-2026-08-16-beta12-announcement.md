# Reddit draft, 2026-08-16: beta.12 announcement

Status: **DRAFT — not posted.** Release is live on both repos (`tvos-v0.3.0-beta.12`, build 108,
`2a8c387c`). The post-body "Latest build" block still says beta 11 — swap it for
`tvos-beta12-reddit-block.md` (gallery post: new-reddit Markdown editor via ego-browser, as for
beta.11) before or right after posting this comment.

Posting notes:
- Top-level comment on the beta thread. Automod: no "torrent", no debrid service names.
- No em dashes, straight quotes, markdown editor.
- u/tiyeuedm asked for Vietnamese by DM — named here because they also asked publicly-ish
  (DM only; if in doubt, drop the name and keep "a tester who asked by DM").
- Publicly promised items to close explicitly: BUG-53 (pinned title clip, promised to
  u/mrStevenx3) and UX-9 (letterbox zoom). UX-9's measured zoom actually shipped in beta.11
  (`aeff3b64`); beta.12 adds the diagnostics that say WHY a source keeps the floor. Do NOT claim
  a new UX-9 fix here — say what is true.
- BUG-58: no matching surface exists (Appearance has no pushed colour screen) — ask which
  screen/how reached. BUG-59: footage showed the phone camera cropping, not the app — ask which
  title if it recurs.
- FEAT-21 (VidHub, u/Ginosaure): honest known-issue note, verified byte-exact on device.

---

## Draft: beta.12 announcement (top-level comment)

**Beta 12 is up** (build 108): https://github.com/youngchris29-art/NuvioTV/releases/latest

Headliners:

- **Vietnamese.** The whole app is now in Tiếng Việt when your Apple TV is, and "Vietnamese"
  is in the metadata, audio and subtitle language lists. A tester asked for this by DM
  (u/tiyeuedm, thank you); while the pipeline was open, French, Spanish, German and Italian
  caught up on every string added since they first shipped.
- **The pinned-hero title clip is fixed.** u/mrStevenx3, this is the one I promised: on the two
  leftmost cards of a row the focus lift was covering the row title, and the title jumped
  between rows. Rows sit a little airier now so the lift always clears the title, and the title
  glides instead of snapping. Verified on hardware with the remote in hand.
- **Search -> See All shows what you searched.** Expanding a search row's See All was returning
  the addon's unfiltered catalog, or an empty grid for search-only catalogs like Stremio Catalog
  Plus. The query travels with the request now. Same build: collection folder grids remember
  your position when you back out of a title, like See All grids already did.
- **No Zoom on Focus covers every tile.** u/mrStevenx3 was right that the zoom persisted with the
  toggle on: it only reached poster and wide cards, and See All cards, episode cards and the
  detail-page trailer thumbnail still zoomed. All of them honor it now.

Trailers, honestly: the "trailers stop until I reinstall" report matched exactly one thing in
the app that survives a restart and dies with a reinstall, which was that trailer extraction was
keeping YouTube's identity cookies and a disk cache between launches. That is gone; the trailer
path is stateless now. A 15 minute soak on my Apple TV stayed alive, and this build logs where
in the pipeline a trailer dies if it ever does for you, so a log pull will name it.

Also new or fixed:

- **Sharper collection GIFs on 4K.** The animated tiles were being decoded at roughly a quarter
  of the tile's real resolution because of a memory budget that assumed square frames. They now
  decode at HD-parity resolution or better and give up a few frames instead of pixels. Sharper
  on my 4K panel without getting choppy; long GIFs still cannot be full-resolution on any sane
  memory budget, so "sharper", not "pixel-perfect".
- **White theme:** the Settings sidebar's focused row was drawing white-on-white; it draws a
  dark label now. Stream badge colours also match the phone exactly (an 8-digit colour code was
  being read in the wrong byte order).
- **Metadata Language = Français:** the hero commits once, already French, no English-then-French
  swap, and rows localise their captions as they scroll into view. If a caption stays English,
  check TMDB: for a fair number of titles the official French title IS the English one.
- **Collections:** a collection's configured backdrop artwork now renders on its tile (it synced
  fine, it just was never drawn).
- **VidHub in the player list.** u/Ginosaure, it is in Settings -> Playback -> Default Player and
  the stream long-press menu, built to VidHub's own integration docs and verified on device that
  the exact documented URL arrives. The catch: VidHub's current Apple TV build ignores it and
  opens to its home screen, on every variant of their API. I have reported it to Oka Apps; when
  they fix their side it will start working here with no update needed.
- Ported from Nuvio mobile: watched-state storage compaction (fixes an out-of-memory on very
  large libraries), faster Trakt watched sync, a Simkl "completed series" fix, and add-on
  cache-control on manual refresh.

Two asks: u/mrStevenx3, the "colour-selection screen in Appearance with a black background"
report, I cannot find a screen that matches. The theme picker is inline and the subtitle preview's
black card is deliberate (it simulates video). Which screen and how do you reach it? And the
letterboxed focus trailer, if you see it again, which title? Your clip showed the card filled
edge to edge, so I want to catch it on the title where it happens.

As always: sideload with a free Apple ID, instructions in the release notes. If you retest
anything, Settings -> About should read **0.3.0 (108)**, include that number with your report.
Thanks to u/mrStevenx3, u/Ginosaure and u/tiyeuedm for the reports behind most of this build.

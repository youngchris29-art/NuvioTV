**Latest build: beta 11 (build 107)**

- **Simkl integration** — connect in Settings → Accounts & Services with a short PIN code; movies and episodes scrobble to Simkl as you watch (anime included, resolved through Simkl's own ID mapping), and a **Sync Now** button pushes/pulls on demand.
- **Your provider keys now sync** — debrid and TMDB API keys follow your Nuvio account to any Apple TV you sign in on. Also fixed underneath: credential pushes from the Apple TV were silently failing before this build.
- **The See All Back-crash is fixed** — the tvOS 27 report: backing out of expanded search results no longer ejects you to the Apple TV home screen. See All grids also **remember your position** when you back out of a title now.
- **Focus zoom is whole-card again** — no more zoom-inside-a-frozen-edge with the title swallowed underneath. And if you prefer a calmer shelf, the new **No Zoom on Focus** option (Settings → Appearance) marks the focused card with a border and shadow instead of scaling.
- Plus: a White-theme contrast sweep, collections artwork fixes (first-item covers, smoother GIF tiles, title logos, no more doubled wordmarks on service covers), the pinned hero no longer double-swaps its text/artwork on load, and trailer pipeline hardening.

Settings -> About should read 0.3.0 (107), beta tag tvos-v0.3.0-beta.11.

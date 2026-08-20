# POSTED 2026-08-20 (live post body verified on fresh reload: new block present, old gone, gallery intact). Route: the API creds for scripts/update-reddit-beta-post.py were not available in-session, so this went through ego-browser on NEW reddit (shreddit) — old.reddit has no edit control for gallery posts. Gotchas for next time: shreddit-composer ignores programmatic textarea mutation (a JS value-set + Save silently saves nothing) AND its Save button ignores JS .click(); the working recipe is real focus, setSelectionRange over the old block, typeText the replacement, then a trusted coordinate click on Save.

**Latest build: beta 13.5 (build 110)**

A quick hotfix built straight from the beta.13 review (thank you for the video, it did half the debugging):

- **Non-English trailers come back** - with a Metadata Language set, your language now wins the trailer pick outright. 72 Hours and Drop Game are the test cases.
- **White-on-white in Appearance fixed** - the focused rows in Settings -> Appearance read dark-on-white reliably now, and the theme swatches wear a proper focus ring on every theme, White included.
- **Strip SDH Subtitles** - new toggle in Settings -> Playback that hides [sound cues], (asides) and speaker labels from text subtitles, in both players. Ported from Nuvio mobile.
- **Addon streams that need special headers play now** - sources whose CDN checks a Referer or User-Agent used to spin forever on tvOS while working on iOS. Fixed.
- **Square corners everywhere on the detail page** - season posters, trailer thumbnails and episode stills all follow the Corners setting now.
- **Season selector polish** - the Episodes heading moved below the posters (and finally translates), and season labels no longer hide under the zoomed poster.
- **Hero Paint Diagnostics** - Settings -> About has a new toggle for the doubled-hero report: turn it on, relaunch, and photograph the little log that appears. That photo is exactly what I need.

Settings -> About should read 0.3.0 (110), beta tag tvos-v0.3.0-beta.13.5.

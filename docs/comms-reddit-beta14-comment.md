beta 14 (build 111) is up: https://github.com/youngchris29-art/NuvioTV/releases/latest

What's new:

* Trailer Location (Settings > Home Screen, under Trailers on Focus): pick Poster or Hero. With Hero, a focused poster stays put and its trailer plays in the hero banner. Play/pause on the poster still toggles the sound.
* Autoplay Hero Trailer (off by default): the featured title in the hero plays its trailer with no focus needed, and hands over when you focus a poster.
* Collection folders now open with their configured backdrop and title logo as the page header.
* Bigger season posters on the series page, the same size as More Like This.
* Settings > About gains tab bar and focus diagnostics for the "ring re-enables zoom" and tab bar reports.
* Search source chip text is readable again in every theme.

u/mrStevenx3: thank you for the collections JSON, it settled that one. The tiles on Home were already showing your cover images exactly as configured (the gradients with the genre name are the covers themselves). What was missing were the backdrop and title logo for each folder, which no Nuvio app rendered before. Open any Genres folder on beta 14 and you should see them as the page header. Trailer Location and Autoplay Hero Trailer are both your asks from the last two rounds, so those are worth a look too. Also, if you still see the doubled hero artwork on a cold launch, Settings > About > Hero Paint Diagnostics and a photo of that pane is exactly what I need.

A few open questions for anyone on beta 14:

* Colour picker: the white on white in Appearance shipped fixed in 13.5. Does it look right to you now?
* Choppy description scrolling: three builds have landed since the report. Is it smooth now, or still stuttering?
* Trailers: TMDB has no videos at all for "Nando entre dos mundos", so no trailer there is correct. Does that title show a loading spinner, or a clean no-trailer state?
* Row titles clipped in pinned mode: I still can't reproduce it. A photo or screenshot of the clipped state would let me move on it.
* u/StudioKentin: following up on the questions from the 13th. Which build were you on, did the bar get stuck visually or did the app stop responding, and did it happen while scrolling back up to Home?

Settings -> About should read beta.14 (build 111).

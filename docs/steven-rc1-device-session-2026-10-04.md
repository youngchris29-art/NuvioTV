# beta.19-rc1 fix batch: device session (Living Room Apple TV, **Test profile**)

**When:** 2026-10-04, with Christian at the remote. About 35 minutes.

**Build:** a dev build of the batch tip, installed as `com.youngchris29.NuvioTV`. I start every launch from the Mac with `--console`, so the probe lines stream to me. Photos are only needed where a step says so.

**Pick "Test" at the profile picker every time.** Never "Chris".

Each part says what I launch, what you do, and what decides the outcome.

---

## 1. Tab bar fix decision (T1, BUG-66). Three cold launches, about 6 min

Your Test profile normally uses the sidebar navigation, which hides the system tab bar. These three launches add `-sidebar_style tabs` so the bar is back, for these launches only.

I launch with `-sidebar_style tabs -debug.tabBarStateProbe YES -debug.homeScrollProbe YES -debug.pinnedRowSettleProbe YES -debug.tabBarRestFix N`, once each for N = 0, 1 and 2.

**You, each time:**
1. Pick Test.
2. Leave focus on the hero for 5 s.
3. Press Down once to the first row and wait 3 s.
4. Tell me whether the tab bar looks fully shown, fully hidden, or **half shown**.
5. On the N = 2 launch only, then press Right twice and wait 3 s.

**What decides it:** the probe's `st=` / `off=` / `ins=` values, read against the decision table in spec B §T1. Whichever fix variant cures a half-shown bar becomes the default in a one-line follow-up. If the bar never goes half-shown on your TV, both variants stay off, and Steven gets a build with both named.

## 2. Edge fade frame time (F.5, FEAT-54). Two cold launches, about 8 min

**Before you start:**
- Set Poster Size to Large in Settings, Test profile.
- Turn inline trailers on, with Trailer Location: In Row.

I launch with `-debug.collectionFrameProbe YES -debug.frameSamplerSteadyS 2`, first with `-row_edge_fade off`, then with `-row_edge_fade soft`.

**You, each time:**
1. Press Down 10 times, then Up 10 times (about 1 per second).
2. On one catalog row, press Right 8 times, then Left 8 times.
3. Rest on a poster until its trailer plays, then wait 15 s.

**What decides it:** Soft stays the default only if, in every phase:
- its median p95 frame time is within 1.0 ms of Off's;
- its dropped frames are within max(2, 10 %) of Off's.

Otherwise the default ships as Off, and Soft stays one tap away in Appearance.

## 3. Trailers after Infuse (B1, BUG-131). About 5 min

I launch with `-debug.trailerProbe YES`.

**You:**
1. Rest on a Home poster until its trailer plays.
2. Open a title and play it in Infuse for about 30 s.
3. Go back to NuvioTV.
4. Rest on two posters: one whose trailer already played, and a new one.

**Pass:** both trailers play. The console should show either `health … alive=1` (the listener survived) or `dead` → `rebuild` → `ready` (it was rebuilt).

## 4. The device pass. About 15 min, one launch with `-debug.homeHeroProbe YES -debug.artworkProbe YES`

**Home and trailers:**
1. Walk 10 rows down and back up at Large, then at Medium+:
   - the hero never shows two titles at once (the old text fades out before the new text fades in);
   - there's no stale hero after leaving a folder;
   - there's no hero with no title or logo.
2. Inline trailer on a poster:
   - it starts only after the row has stopped, about 1 s;
   - the playing card's ring keeps the poster colour;
   - moving off mid-morph leaves no gap and no ghost logo.
3. Settings → Home Screen → **Trailer Start Delay**: Automatic is the default. Try 3 s and check the wait, then set it back.
4. Trailer Location: Hero. A row card's trailer plays in the hero, and Play/Pause toggles its sound.

**Sharpness:**

5. Open *The End of Oak Street*. The Detail backdrop, poster and logo look sharp on the 4K TV. Photograph it the way Steven did. About 1 s after you stop on a Home title, the hero art and logo sharpen through a short cross-fade, with no jump.

**Rows and folders:**

6. Row edges fade gradually into the screen edge on Home, Detail rows (including Episodes) and Search. The first card isn't faded until the row scrolls. Appearance → Row Edge Fade switches Soft / System / Off.
7. Folder page:
   - Install a collection in Test first; I'll give you a JSON.
   - Open a folder and scroll down: the title rises and stays, and the chips stay under it.
   - Back restores focus.
   - Remove the collection afterwards.

**Detail:**

8. The Cinematic scrim is lighter; compare against your memory of Oak Street and *Monstre*. Glass on the chips and buttons doesn't change while scrolling.

**Playback:**

9. Auto-Play Best Source (if your Test profile has a debrid source): *Lizzie Borden* picks the highest-resolution HDR/DV link, not the first one listed.
10. The player caption says "Preparing playback…" on a non-DV file, and "Preparing Dolby Vision…" only on a DV file.

**Memory:** across the whole session, the `[ArtworkStore] pools` line keeps `avail` at 400 MB or more. If it doesn't, the image pools are halved before the cut.

---

## After the session

- Set T1's default leg and, if needed, F's default (one constant each).
- Fix anything found.
- Re-gate.
- Merge and cut on Christian's go. The release notes say:
  - every new setting and its default;
  - that Auto-Play Best breaks ties by file size (so a REMUX can beat a WEB-DL with Atmos);
  - that Soft is the default fade (or Off, if F.5 fails).

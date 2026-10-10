# Steven's beta.19-rc3 verdict — DM 2026-10-06 + two videos

Read 2026-10-07 morning from the Reddit chat room (ego-browser space `reddit chat steven`, id 10). Two DMs
(2:11 PM and 2:20 PM ET on 10-06, 19 h before the read), two Smash links. No photos this time: the two
image attachments on the bubbles are the Smash link-preview card. Both videos downloaded to `~/Downloads`
(`IMG_8901.mov`, 545 MB, 3:56, 4K30; `IMG_8902.mov`, 61 MB, 0:30), kept OUT of the repo. Named frames in
`docs/research/steven-beta19-rc3-videos-2026-10-06/` (TV-cropped, 1600 px wide; file names carry the
video and the second). Smash links expire ~10-13.

Build under test: beta.19-rc3, build 135 (`65074a19`): Stage & Strip Home, Library L1, Search S1.

## His DMs, verbatim

> Hi Chris,
>
> Here is my feedback. I'll split it into two parts.
>
> Old home screen:
>
> * When you enter a collection, select a movie, and then go back, the menu bar at the top remains visible.
> * It would also be nice to have the same interface as the home screen inside the collections.
>
> New home screen interface:
>
> I'll be honest: for now, I don't really like the way it looks. It may be a matter of personal preference, but it's also partly because of the issues I'm going to list below:
>
> * The animations feel slow, and overall the interface feels less responsive.
> * The add-on name remains displayed all the time, regardless of whether the "Show catalog type in title" option is enabled or not.
> * The titles of each row are positioned much too high.
> * The ambient background is a good idea in theory, but I don't really like the result. There is too much fog, and since the hero takes up the entire screen in the new interface, you get blurred background images on both sides. I think the blur should only be applied to the lower part of the hero.
> * With the OLED theme, there is still a delay where the background suddenly becomes darker.
> * The collection logos are positioned much too high.
> * When you enter a collection, the top bar remains permanently visible when there is only one row. Also, the catalog logo is placed at the very top-left of the screen. I think it would be better to place it in the top-right or bottom-right corner.
> * Inside collections, the logos are not displayed on the thumbnails for French trailers. However, movies that have English trailers display the logo correctly.
> * The hero is stretched and blurry, just like before. So inside collections, we don't get a proper 4K-quality display.
> * Some of my rows are displaying the synopsis and titles in English.
>
> In the description:
>
> * When it is displayed for the first time, a black square appears before the title is shown.
> * The animation when first scrolling down is stuttery.
>
> Positive points:
>
> There is no bounce effect in the new interface, and the synopsis is displayed across many more lines. It would be really nice to have these two improvements on the old home screen as well.
>
> For now, I still prefer the old home screen over the new one.
>
> I'll show you a video of your application first, and then the inside of the collections from the official Nuvio.
>
> You'll also be able to see the flickering I get when scrolling to the right in the video. However, this only happens when I enable the "Fade" scrolling mode.
>
> Link vidéo : https://fromsmash.com/VVGfCakP2M-dt

> Regarding the fact that the animation during the first swipe down is sometimes choppy, it seems to depend on the movie. For example, on War Machine, the animation is smooth, whereas on Monster: The Lizzie Borden Story, it is much more choppy.
>
> I also wanted to ask if, while you're modifying the description, it would be possible to add the animation that is present in the official Apple TV app and in Fusion: when you swipe down for the first time, the logo gradually appears. I'll show you exactly what I mean in the video. https://fromsmash.com/B-W3w6VWad-dt

## Video 1 (IMG_8901, 3:56) — what he shows, by second

| From | What is on screen |
|---|---|
| 0–30 | Classic Home (Coyote vs Acme hero, Genres row), Down through Infirmary / The Arena / Services de Streaming, into the Netflix collection (Classic grid, chips Tout / Nouveaux films / …), opens The Walking Dead. |
| 26, 48 | Back from the Detail page into the Netflix grid: **the top tab bar is now visible over the grid** (it was not before the push). Item C1. |
| 31.8–34 | Spider-Man: Homecoming Detail push. Text title for one frame, then a **grey rounded block in the logo slot for ~0.8 s**, then the logo. Item D1. `v1-031.8-034.2-detail-logo-placeholder-sheet-0.2s.jpg`. |
| 50–62 | Settings › Écran d'accueil: Disposition Classique → Stage; the pane shows Arrière-plan d'ambiance ON, Emplacement de la bande-annonce "Dans la rangée", Délai 1 s, "Afficher le type de catalogue dans les titres" ON, Catalogues 7 sur 15. |
| 62–96 | Stage Home walk: Action genre folder, Infirmary, Vultures, À vie (in-row trailer), Cellular, The Arena, War, Walt Disney folder. Row headings read "Nouveaux films · The Movie Database Addon", "Top 10 des films · Top 10 FR ▫" (a small blank square after Top 10 FR, the add-on's icon?). Items S2, S3. `v1-066-…`. |
| 92–100 | Walt Disney collection (Stage layout): tab bar + Modifier at the top, the **Walt Disney logo at the very top-left, partly behind the tab bar**; Hocus Pocus. Items S6, S7. `v1-092-…`. |
| 100–146 | Netflix collection (Stage layout, rows Nouveaux films / Nouvelles séries / Séries les mieux notés / Action (films) / Action (séries)). Death of the Pastor's Wife, Breaking Bad, Avatar, Arcane carry **English** names, meta and synopsis (item S10). In-row trailer tiles: War Machine and Jurassic World show the **name as text**, Breaking Bad and Arcane show the **logo** (item S8). `v1-118-…`, `v1-138-…`. |
| 146–160 | Monstre: l'histoire de Lizzie Borden Detail (the stuttery first scroll, item D2), Episodes / Casting / trailers / À voir aussi / À propos. |
| 160–195 | Back on Stage Home, "Top 10 des séries · Top 10 FR": **slot 3 is a black card for the rest of the video** (the weekend's "portrait poster vanishes after the fade"; at 90 s that slot still had its poster). Not a Stranger trailer tile = text, Monstre tile = logo. `v1-174-…`. |
| 196–236 | Google TV home → **official Nuvio (Android TV)**: Home with the Infirmary hero, Studios row, Netflix folder; inside the Netflix collection the NETFLIX logo sits large at the top-left with no tab bar, each focused item swaps in its own logo + meta line (Film · Comédie · 1h 5m · date, M18 | SORTI | IMDb 5.0) + synopsis **in French** ("La mort de la femme du pasteur"), row heading right above the posters, in-row trailer tile with the logo (Animal Control, Outer Banks). `v1-218-…`, `v1-232-…`. |

The "Fade" flicker he mentions is Row Edge Fade = Soft (default Off since rc2; F.5 failed on hardware). Not
re-triaged.

## Video 2 (IMG_8902, 0:30) — the Detail logo ask

Apple TV app, Silo, then Fusion, Sorcières Academy (three times). The hero (logo bottom-left, synopsis,
Play) scrolls up and off on the first Down; as it leaves, a **compact centred logo fades in at the top of
the episodes area** and stays there as the page's header (above the Season pills). That is the animation he
wants on the Detail page. `v2-002-…`, `v2-002.6-…`, `v2-017.5-…`, `v2-018.5-…`.

## Triage

Code read at `0c10ca4a4` (`tvos-shared-extraction`). "Verified" = the frame shows it and the code says why.

### Bugs

| # | Item | Status | Where / why | Shape |
|---|---|---|---|---|
| D1 | Detail: grey block before the logo | **VERIFIED, root-caused** | `DetailCinematicHero.logoSlot` draws `CachedAsyncImage` for the logo, and that view shows `ShimmerView` (a flat surface + sweep) while the file downloads; in a 600×180 slot that is his "black square". Classic's `DetailView.header` has the same shape. | Logo slots get a loading view that is the title text (what `failure:` already does), or nothing. One parameter on `CachedAsyncImage` (`loading:`), two call sites. Small. |
| C1 | Classic collection grid: tab bar visible after Back from a Detail page | **VERIFIED on video**, not root-caused | Classic folder page (BrowseComponents / FolderDetailView). Before the push the bar is hidden by scroll; the pop restores the bar (the tab shell's hysteresis resets) and the grid never reports a scroll again. | Re-assert the hidden state on reappear, or report the grid's offset once on pop. |
| S7 | Stage collection: tab bar stays visible with one row | **VERIFIED on video** | `reportsScrollToTabBar` is wired into `StripPager` (a page turn hides the bar). A one-row folder never turns a page, so the bar never hides. | Hide on the first move inside the row too, or hide when the strip mounts with the folder's own logo risen. |
| S8 | Trailer tile shows the name as text on some items | **VERIFIED, root-caused** (not French vs English) | `InlineTrailerTitleOverlay` resolves `heroLogoURL(for:)`: `item.logo`, else metahub for `tt…` ids, else nil → text. Items with a TMDB id and no `logo` in the preview (his TMDB-sourced rows: War Machine, Jurassic World, Not a Stranger, The Arena) get text, while the Stage above them resolves the same title's logo through `TitleLogoStore`. Breaking Bad / Arcane / Monstre carry a preview logo, so the tile shows one. | Route the tile overlay through the same resolver the Stage uses (TitleLogoStore), with the text fallback kept. |
| S2 | Add-on name on every row heading | **VERIFIED, by design** | `StageCopy.headingAddon` (W2-A §5): Stage catalog headings always carry the add-on's name ("Popular · Cinemeta"). It ignores "Show catalog type in title" (that setting adds the TYPE). He reads it as that toggle being broken. | Product call: gate the suffix on the same toggle, give it its own toggle, or drop it. |
| S3 | Row headings sit too high above the posters | **VISIBLE** (`v1-066`) | `StripGeometry`: heading, md 16, the shelf's lg 24 top padding, plus the lift room. On his 65" the gap reads as ~a third of a poster. Official Nuvio puts the heading right above the row (`v1-218`). | Trim the heading-to-shelf gap in the strip (geometry constant), check the focus lift still clears. |
| S5 | OLED: the background darkens late | not reproduced here | With OLED True Black the wash is dimmed; his report is that the dim lands a beat after the swap. Likely the wash image arriving after the stage text swap. | Check `AmbientWashLayer` dim timing against the stage's commit; dim the previous wash on the swap, not on arrival. |
| S9 | Folder page hero blurry / stretched, "no 4K" | UNVERIFIED (phone video can't show it) | Home's stage got I1's per-view decode sizes; `FolderRowsPage`'s stage may still use the folder mosaic / an older decode path. | Confirm the folder stage's decode size and source (`FolderStageLogoLayer`'s sibling art layer); align with Home. |
| S10 | Some rows in English (name, meta, synopsis) | **VERIFIED** (`v1-100` Pastor's Wife on tvOS vs `v1-224` official Nuvio in French) | The Stage prints the catalog preview as the add-on sends it. Netflix-style catalogs ship English. Official Nuvio localizes the preview through TMDB. Detail already gets French via TMDB enrichment. | A localized-preview fetch for the Stage's focused item (TMDB title + overview by the app language), cached; `shared/` has the TMDB plumbing. Medium. |
| D2 | Detail first scroll stutters on some titles (Monstre yes, War Machine no) | reported, title-dependent | BUG-41 class. Monstre's page is heavier (4 episode cards + cast + 4 trailers + À voir aussi + About). | Profile the Monstre page on the sim (`-debug` BUG-41 knobs); the heavy rows are the suspects. |
| weekend | Portrait poster goes black after the fade | **VERIFIED** (`v1-174`, slot 3 of Top 10 des séries black from ~150 s on, present at 90 s) | Already on the list (his weekend DM). The tile that loses its poster is one the in-row trailer ran on, or a neighbour. | Repro leg: play a trailer in a portrait row, leave, come back; watch `CachedAsyncImage` release / the morph's abort path. |

### Design / product calls

| # | Item | Note |
|---|---|---|
| S1 | "Animations feel slow, less responsive" | The strip's row glide (0.51–0.73 s per click on hardware, a2) plus the stage swap dwell (~0.5 s) and the old-text-out-then-new-text-in sequence. Tuning: shorter glide, swap dwell 0.3 s, or a Settings speed row. His reference (official Nuvio, 196–236 s) moves the row with no glide at all. |
| S4 | Ambient wash: too much fog, blurred art at both sides; blur only the lower part of the hero | The wash fills the screen behind a stage whose art is already full-bleed. Options: wash only below the stage art's bottom edge, lower the wash opacity, or default Ambient Background Off. |
| S6 | Collection logo too high / top-left under the tab bar; wants top-right or bottom-right | `FolderStageLogoLayer` docks the logo in the stage slot and rises it to 60 % above the stage block on the first move, which puts it under the tab bar in Top Tabs mode. Official Nuvio keeps the catalog logo large at the top-left with no tab bar there. Fix the collision first (never rise into the bar's band); placement is his taste. |
| C2 / F | Classic Home wants the Stage's two wins (no bounce, more synopsis lines) and the Rows layout inside collections | The bounce fix is the strip's structure; it does not port to Classic's pinned rows. More synopsis lines on Classic's hero is a geometry change (hero-off panel 3 lines today). The Rows folder layout exists; it is tied to Home Layout = Stage. Product call. |
| FEAT | Detail: compact centred logo fades in at the top as the hero scrolls off (Apple TV app, Fusion) | New. The Cinematic layout already has a fixed logo slot and a Down/Up hero exit; this is a pinned header that appears on the first Down. |

He prefers Classic for now. Positive: no bounce in Stage, longer synopsis.

### Not in this verdict

Nothing on the rail (he did not switch it on), nothing on Library L1 or Search S1.

## Suggested batch order

1. D1 (small, visible on every Detail open), S8, S7, C1, S3 — mechanical.
2. S2 + S6 + S4 + S1 — a Stage polish pass, needs Christian's calls on S2's gate, the logo placement, the wash.
3. S10 — localized previews on the Stage (shared + Swift).
4. The Detail header logo FEAT with the owed darker-synopsis-area and full-synopsis-affordance items from the weekend, as one Detail pass.
5. S5, S9, D2, the black poster — repro first.

## 2026-10-08 follow-up (read 11:15 AM ET, three new messages)

**10-07 10:03 PM ET:** a second Wako link, r/wako "Soon - New Home" (`1uad0w3`, 36 s screen recording of
Wako's upcoming Home). Downloaded with `yt-dlp` (kept out of the repo); frames in
`docs/research/wako-new-home-2026-10-08/`. What it shows: a top tab strip (For You / Movies / TV Shows /
Anime + icons); page one is a hero carousel (logo, meta chips, 2-line synopsis, "Voir le détail", page dots);
every row below is the fixed-slot row from the 10-05 reference: the focused card is a big landscape tile
pinned at the left with the logo over it, the posters sit to its right, the meta line + a 2-line synopsis sit
UNDER the card, one row per page, the next heading dimmed and peeking at the bottom. Same vertical scheme as
Stage & Strip; the text-under-the-card placement is his earlier "synopsis below the tile" ask.

**10-08 11:03 AM ET + four photos** (`docs/research/steven-beta19-rc3-photos-2026-10-08/`): "When I enable
the hero, the text is displayed on two lines (or on one line when I enable zoom on focus), and the number of
sources in a collection isn't displayed. However, when I disable it, the synopsis appears on more lines, and
the number of sources is displayed." The photos are **Classic Home with the Rail on** (he is back on Classic,
as he said, and now runs Navigation: Rail):

| Photo | Mode | What it shows |
|---|---|---|
| 1 Infirmary | Show Hero ON | hero with "Voir le film", synopsis cut to ONE line (zoom on), trailer card playing in the row |
| 2 Action folder | Show Hero ON | "Ouvrir le dossier" button, no "Genres · 8 sources" line |
| 3 Aventure folder | Show Hero OFF | hero-off panel: "Genres" + "Aventure · 8 sources" (rc14's BUG-119 `folderHeroDescription`), no button |
| 4 Infirmary | Show Hero OFF | hero-off panel: FOUR synopsis lines, no button |

Explanation (code): the Classic hero-ON info panel budgets its synopsis by the rt4 pinned-row geometry
(2 lines at his size, 1 once the zoom hold takes its 6 pt), and its folder state is the "Open Folder" CTA
with no description; `folderHeroDescription` is only wired into the hero-OFF panel. Not a bug in the sense
of a defect, a parity gap: hero-ON could carry the folder line under the CTA, and the line budget is the
known W4/rt4 trade (hero height vs the row fitting the viewport). Logged BUG-154.

**10-08 11:06 AM ET:** "the sidebar always remains visible on the first line, which may be intentional. But
perhaps hiding it on the first line and making it appear when clicking the left/back button could be a good
idea." The rail has two modes (`NavigationChrome.RailVisibility`: Always Visible, Hide While Browsing), and
Hide While Browsing brings the rail back at the top of a page by design. His ask is a third mode: hidden at
rest everywhere, revealed by Left from the first card or Menu (both reveal paths already exist). Logged
FEAT-62.

Reply DM still owed; it now also answers these three.

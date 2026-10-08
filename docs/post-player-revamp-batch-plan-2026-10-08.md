# Post-player-revamp batch plan: upstream ports + Steven's rc3 verdict (2026-10-08)

**Status: DRAFT, awaiting Christian's go. Nothing built.** Written in a cloud session (no Xcode) from the records:
`docs/steven-beta19-rc3-verdict-2026-10-06.md`, the tracker rows BUG-144…154 / FEAT-60…62 / UX-16, the rc2
weekend list (`docs/comms-dm-drafts-2026-10-05-rc2-ack.md`), `docs/upstream-port-plan-2026-10-0{3,5,7}.md`,
upstream `NuvioMedia/NuvioMobile` `cmp-rewrite` read directly at `78e6373a` (0.5.8-beta, the 10-08 check's
end), and the submodule at `11944d02e` (`tvos-shared-extraction`, player P2 merged). Code facts below are
file:line on that tip.

This plan starts **after the player revamp's P5 merges** (`docs/player-revamp-plan-2026-10-06.md`: P1 merged
10-07, P2 merged 10-08, P3 spike next, then P4, P5, one rc). It does not touch the player batches. The one
scheduling question it raises is where Batch A sits relative to the post-P5 cut (D0 below).

---

## 0. Where this sits

| | |
|---|---|
| Player revamp today | P1 + P2 merged (`11944d02e`). P3 (preview frames, spike first), P4 (native parity), P5 (auto-sync, audio, post-play, per-show speed) still to run. Release model (10-06): one rc after P5 carrying Search & Discover + P1–P5. Checkpoint: if P3 has not merged by **10-16**, an interim rc with Search & Discover + P1 + P2. |
| Rough dates (assumption, not a promise) | P3 10-09…11, P4 10-11…13, P5 10-13…15, regression pass + rc (build 136) ≈ 10-16…17. This plan's batches run ≈ 10-17 → 10-28, its own rc (build 137) at the end. Codex returns 10-29, so the last review round can be a Codex round; everything before it is Opus read-only rounds, as for P1/P2. |
| Comms state | Steven's rc3 reply DM is DRAFTED (`docs/comms-dm-drafts-2026-10-08-rc3-reply.md`, lint 5/5) and NOT SENT. It promises "next build" for D1 / S8 / S7 / C1 / S3 / the folder-logo collision / the Classic folder line / the rail Hidden mode. See D0. |
| Standing rules that apply | Fresh local clone of the submodule per batch (never a worktree); branch off `tvos-shared-extraction`; stage by explicit paths (MPVKit symlink); Opus review rounds until CLEAN; gates jvm / K/N / composeApp / NuvioTVTests / Debug + Release sim (`-collect-test-diagnostics never` on UI runs); device pass on a dev build in the **Test** profile; fast-forward on Christian's go; outer pointer bump + record commit; tracker / CLAUDE.md / memory updates; SlopMonster 5/5 on every DM and release note. |

---

## 1. Inventory

### 1a. Upstream, unported as of `78e6373a` (10-08)

The 10-08 window `b8801eb4 → 78e6373a` has **0 changes under `shared/`** (verified: `git diff --stat b8801eb4..78e6373a -- shared` is empty). Everything below lives in upstream's `composeApp/` with a `shared/` extraction on our side.

| # | Upstream | What | tvOS state (verified) | Size |
|---|---|---|---|---|
| U1 | `d8ce7258` (#2196, kernexshadow; "Port of NuvioMedia/NuvioTV#3881") | MDBList lists get **Recently released / Oldest released** sorts (one cached oldest-first release order per list, release-year fallback); list items are requested **without a sort** so MDBList returns the owner's saved order and that becomes the provider order; cached lists reload once after the order change and on a manual refresh. 19 files, +248/−79, 7 test files. | `shared/.../library/LibraryDisplaySettings.kt` enum is `DEFAULT, ADDED_DESC, ADDED_ASC, TITLE_ASC, TITLE_DESC` (no RELEASED_*); every touched Kotlin file exists in `shared/` except `LibrarySavedContent.kt`, whose 4 lines are Compose string labels (ours live in `LibraryGridPolicy.sortLabel`). Library L1's Sort pill (`LibraryView.swift:253`, `LibraryViewModel.swift:243` via `availableLibrarySortOptions`) will list the new options automatically once the enum has them. Sort option storage is device-local, profile-scoped (`AccountDataStores.kt:203`), not synced, so no cross-device enum risk. | MEDIUM, mechanical |
| U2 | `94976222` (#2115, deejay189393) | Streams whose only playable field is **`ytId`** are kept by the parser and resolved on the device with the trailer extractor (one URL with video + audio: the HLS master, else the best progressive file); auto-play still skips them; the resolved URL is never saved for "reuse last link"; builds without in-app trailer playback open the watch page instead. | `shared/.../streams/StreamParser.kt:33` drops a stream with no `url`/`infoHash`/`externalUrl`/`clientResolve`; `StreamModels.kt:114` `hasPlayableSource` has no `ytId`. `shared/.../trailer/InAppYouTubeExtractor.kt` exists (tvOS's trailer path) but has no single-URL entry point; the fork has no `TrailerPlaybackResolver.kt` (tvOS resolves trailers in Swift: `TrailerLocalHLS.swift` + the extractor). `StreamAutoPlaySelector.kt:169` already filters on `playableDirectUrl`, so ytId-only streams stay out of auto-play by construction. No tester has reported it. | LOW–MED |
| U3 | PR #2081 `feat/servers` (merged `416d97d8`, 10-08) | **Jellyfin / Emby media servers**: 104 files, +6,647/−209, all `composeApp/` (commonMain +4,783 across 77 files, commonTest +1,672). New `features/servers/*` (models, provider, repository, storage expect/actual, sync, catalog, matcher, playback, streams, watched, user-state projection), `mediabrowser/` client + mapper + provider, `jellyfin/` + `emby/` providers, `core/sync/MediaServerSync.kt`, `library/LibraryServerContent.kt`, `player/PlayerScreenRuntimeServerTracks.kt`, three Compose settings pages + a sign-in sheet, `strings_servers.xml`. Follow-up commits inside the PR: watch-progress import toggle, server play method in stream info, burned-in image subtitles when transcoding, no transcode for high-bitrate/HEVC, server libraries in Library, servers kept out of tracker libraries. | No `shared/` footprint at all; nothing on tvOS. A product call, not a port. | LARGE (see D1) |
| U4 | 10-07 doc, optional | tvOS "forward buffer duration" setting (`AVPlayerItem.preferredForwardBufferDuration`). | Nothing. | Decline unless a tester asks. |
| U5 | 10-03 doc, optional (`81863d34`, #2137) | "Intro skipped to M:SS" 1.4 s toast on auto-skip. | tvOS auto-skip is silent (`NativePlayerScreen.swift` `.auto` seek, `MPVPlayerView.swift` `seekAbsolute(_:kind: .auto)`); the plan in the 10-03 doc is still valid. | LOW, ~1–2 h (D11) |

Checked and **not** ports (the 10-08 window): `6d05d234` "stop treating api keys as expiring links" is inside the servers PR but general; the fork's `shared/.../streams/PlaybackUrlCredentials.kt` already matches upstream's post-fix list (no `apikey`/`api_key`), so nothing to do. `278886e1` resets a next-episode preload flag in composeApp's player runtime; tvOS's own engine resets `preloaded` on the next episode (`NextEpisodeAutoPlay.swift:377`). Croatian i18n (#2169), tablet hero alignment (#2190), version bump, store publish: N/A. Hygiene: CLAUDE.md cites `docs/upstream-port-plan-2026-10-08.md` but no branch carries that file; it is probably sitting untracked on the Mac ("untracked docs are a smell"): commit it.

### 1b. Steven: rc3 verdict (10-06), follow-ups (10-07/08), rc2 weekend list (10-05)

Verdict record: `docs/steven-beta19-rc3-verdict-2026-10-06.md` (items D1/D2, C1/C2, S1…S10, FEAT). He runs **Classic with the Rail on** today; prefers Classic; the Stage's wins for him are no bounce and the longer synopsis.

| ID | Item | Triage | Fix shape (code facts) | Size |
|---|---|---|---|---|
| BUG-152 (D1, P2) | Detail "black square" in the logo slot before the logo | root-caused | `CachedAsyncImage` shows `ShimmerView` while loading (`DesignSystem/CachedAsyncImage.swift:141`); it has a `failure:` builder (`:59`) but no `loading:`. `DetailCinematicHero.swift:197-214` `logoSlot` and Classic `DetailView.swift:1751` use it for the logo. Add `loading:` (default = shimmer) and pass the title text in every `CachedAsyncImage`-backed **logo** slot: Detail Cinematic + Classic, plus the trailer-tile overlay if it goes through `CachedAsyncImage`. `TitleLogoHeader` (folder logo) runs its own `ImageURLChain` loader with the title text underneath, and the Stage draws a preloaded image (`HeroLogo`, `StageView.swift:222`), so it has no shimmer and needs nothing. | S |
| BUG-149 (S8) | Trailer tile shows the name as text on TMDB-id items | root-caused | `InlineTrailerTitleOverlay` (`InlineTrailerCard.swift:2651`) takes `heroLogoURL(for:)` once at init (`:2662`); no `TitleLogoStore` path. Route it through `TitleLogoStore.shared.logoURL(for:)` + `lookupIfNeeded` on mount and observe the store so the logo lands when the lookup finishes; text fallback kept. | S |
| BUG-148 (S7) | Stage collection page: tab bar never hides with one row | verified | `StripPager.swift:195` links the content scroll view to the bar on Home only ("nil on the folder page"); a one-row folder never pages. See A3: make the Stage folder page **immersive** (bar hidden from the push, like Detail), which also removes the logo/bar collision (UX-16 (3)). Official Nuvio shows no bar on a collection page. | S |
| BUG-144 (C1) | Classic collection grid: tab bar visible after Back from Detail | verified on video, not root-caused | `CollectionsUI.swift:1426` reports only a Bool (`contentOffset.y > 8`) for the Edit-Filters chip, not to the bar; the bar minimises on its own via tvOS 26's `.automatic` + the content-scroll link (`TabBarVisibility.swift:104-120`, "never toggle visibility for scrolling"); Detail's pop resets it expanded and the grid never moves again. Same cure as BUG-148: the Classic folder page becomes immersive on push (bar hidden until pop). Fallback if that reads wrong on device: re-link the grid's scroll view on reappear. | S |
| BUG-146 (S3) | Stage row headings too high above the posters | visible | `StripGeometry.catalogRowHeight` (`StripGeometry.swift:177-183`): heading + `md` 16 + the shelf's `lg` 24 top padding + lift room. Trim to heading + `md` + `sm` 12 (or 8), re-derive the page height, keep the focus lift clear (`heroPinnedRowFocusLiftAllowance`), update `StripGeometry` tests and the probe. | S |
| BUG-145 (S2) | Add-on name on every Stage heading, ignores "Show catalog type in title" | by design, reads as broken | `StageCopy.headingAddon` (`StageCopy.swift:139-144`) always appends the add-on name; callers in `StripRowViews` / `DiscoverRowsPlan` / `BrowseComponents`. Gate it on the existing `showCatalogType` toggle (`HomeScreenSettingsPane.swift:260`) — D2. | S |
| UX-16 (3) / S6 | Collection logo too high, top-left under the tab bar | verified | `FolderStageLogoLayer` (`FolderRowsPage.swift:433-464`) rises to 60 % above the stage block on the first move. With the folder page immersive (A3) there is no bar to collide with; the rise target stays the stage block top. Placement (top-right / bottom-right) is taste — D5. | S (rides A3) |
| BUG-154b → **BUG-155** | Classic Show Hero ON: no "Genres · 8 sources" line on folders; 1–2 synopsis lines | parity gap | Hero-ON panel's folder state is the "Open Folder" CTA (`HomeView.swift:6442`) with no description; `folderHeroDescription` is wired only into the hero-OFF panel (`FolderRowsPlan.swift:258`, `HomeRowPreviews.swift:46`). Add the line under the CTA in `Theme.Font.meta`, 1 line. The synopsis count is the rt4 budget (`synopsisLineLimit`, `:6426`): stays, per the DM. **Tracker: the number BUG-154 is used twice** (this row and the P2 click-roll arbiter fix `11944d02e`); renumber this one to BUG-155 (D10). | S |
| FEAT-62 | Rail: a Hidden mode (reveal on Left from the first card / Menu only) | logged | `NavigationChrome.RailVisibility` has `always` / `whileBrowsing` (`NavigationChrome.swift:36`); `RailVisibilityRule.shown` (`:261-271`) already returns shown for `holdsFocus` / `revealed`. Add `.hidden`: shown only through those two inputs; the reserved leading inset collapses (the B4 keyboard shape); Appearance row gains the value. Reveal paths exist (`movementDidFailNotification` at `NavigationRail.swift:407`, Menu). | S |
| BUG-151 (S10) | Stage prints English name / meta / synopsis for English-metadata catalogs | verified | `StageCopy.make` reads `item.name` / `item.description_` as the add-on sent them (`StageCopy.swift:49`); Classic's hero does the same (`HomeView.swift:442`). **The data is already fetched:** `TitleLogoStore.lookupOne` calls `TmdbMetadataService.fetchPreviewEnrichmentChecked` (`TitleLogoStore.swift:284`), whose `TmdbPreviewEnrichment` carries `localizedTitle`, `description`, `genres`, `logo`, `backdrop` (`TmdbMetadataService.kt:1626`), in the TMDB language setting; the store keeps only the logo. Gap: the lookup runs only for logo-less items (`isLookupCandidate`, `:173`), so Breaking Bad (has a logo) never gets localized copy. Shape: a second lookup gate "copy wanted" (TMDB on, app/TMDB language ≠ `en`, item has a TMDB/IMDb id), keep title + overview in the store entry, `StageCopy` and the Classic hero prefer them. No new Kotlin. | M |
| BUG-147 (S5) | OLED True Black: ambient wash darkens a beat after the swap | not reproduced | The OLED dim is a constant group opacity (`AmbientWashLayer.swift:422`, 40 %), so the "late darkening" is the cross-fade from the previous wash to the new one landing after the stage text swap (the probe line already counts it: `late=<n>` at `:89-94`). Repro on the device with OLED on and the probe; fix = start the old wash's fade on the stage commit, not on the new bitmap's arrival. | S–M (repro first) |
| BUG-150 (S9) | Folder page stage art blurry / stretched on 4K | unverified | Home's stage goes through `StageArtLayer` → `HeroCrossfadeImage` (`StageView.swift:62-73`, I1's full-bleed decode). Confirm the folder page's art source (`FolderRowsPlan`: folder backdrop vs the mosaic) and that the same decode size reaches it; a photo of the collection page at rest is asked in the DM. | S (confirm first) |
| BUG-153 (D2) | Detail first scroll stutters on heavy pages (Monstre) | title-dependent | BUG-41 class. Profile on FA87 with `debug.detailScrollProbe` / `debug.detailScrollAB` (`DetailView.swift:239-321`); suspects: 4 trailer tiles + cast + episode cards mounting on the first Down. Fix shape: mount the heavy rows after the hero exit lands (a `StripMountWindow`-style window for Detail sections). | M (profile first) |
| weekend | Portrait poster goes black after the in-row trailer fade (`v1-174`, Top 10 des séries slot 3) | verified on video | Stage portrait row, a tile the in-row trailer ran on or its neighbour. Repro leg on the sim with the R2 knobs (`debug.trailerMorph*`, `InlineTrailerCard.swift:426-436`): play, leave, return; suspects: the byte-sized image cache evicting the poster after I1's large decodes, or the morph's abort path leaving `.none` with no poster candidate. | M (repro first) |
| UX-16 (1) / S1 | Stage "animations feel slow" | taste + numbers | Strip glide 0.5 s (`StageStripTuning.pageSeconds`, `StripGeometry.swift:284-288`, knob `debug.stripPageSeconds` 0.3…1.0) + stage swap 0.45 pause / 0.15 out / 0.20 in (`swapTiming`, knobs `debug.stageSwapPause` etc.). Device A/B with the knobs first (0.35 / 0.30), then defaults — D4. | S after the A/B |
| UX-16 (2) / S4 | Ambient wash: too much fog, blur at both sides; blur only the lower part | taste | The wash is a full-screen quad behind a full-bleed stage (`AmbientWashLayer.swift:408-422`). Options: mask the wash to below the art's bottom edge, lower its opacity, or default Ambient Background off — D3. | S–M |
| FEAT-61 / C2 | Classic: no-bounce, longer synopsis, Rows collections under Classic | product | No-bounce is the strip's structure (does not port to pinned rows). Longer synopsis = hero geometry (BUG-155's budget). Rows folder layout exists and is tied to Home Layout = Stage (`FolderRowsPlan`, `CollectionsUI`): a "Collections Layout: Follow Home / Rows / Grid" setting decouples it — D6. **Tension to decide:** the Stage plan's step 6 ("after one or two betas with Stage confirmed, delete Classic's pinned mode, ≈ 5,000 lines") vs the one tester preferring Classic. | M |
| FEAT-60 | Detail: compact centred logo fades in at the top on the first Down (Apple TV app / Fusion) | new | Cinematic has the fixed 180 pt logo slot and the Down/Up hero exit (`DetailRowAnchor.heroExit`, `DetailRowAnchor.swift:190`). Add a pinned header (`TitleLogoHeader`, compact height `heroLogoSlotHeightPinned`) above the sections, 0.25 s fade in on hero exit, out on return; Classic untouched. | M |
| weekend (Detail) | Darker area behind the synopsis + poster bottom; full-synopsis affordance hard to find | logged 10-05 | Cinematic scrim values live in `DetailScrim` (`DetailView.swift:3096`, `cinematicVertical*`, radial); Classic's 560 pt glass panel (BUG-127, `DetailScrim.panel*`) is a ready shape for a local panel under the teaser. The 4-line teaser (`DetailSynopsisTeaser`, `DetailCinematicLayout.swift:138`) opens the sheet on select but shows no hint: add a trailing "More" glyph/caption when truncated. Tests: `DetailScrimCinematicTests` floors. | S–M |
| weekend | Library flicker A/B against Row Edge Fade | logged 10-05 | His "flicker when scrolling right" is Row Edge Fade = Soft (F.5 failed on hardware, default Off). The DM tells him to leave it off. No build item unless he reports it with Fade off. | — |

### 1c. Adjacent, owed anyway (not this plan's scope; listed so the cut does not miss them)

- Translation pass (~30 English-only strings from Library L1 + real plural keys) before a public cut (`docs/library-l1-grid-plan-2026-10-04.md:44`). Batch A/B/C add strings in 6 languages as they go; the L1 debt is its own small task.
- FEAT-56 SenPlayer external player: **committed publicly** on GitHub #5 ("in a coming build"); one spec in `ExternalPlayerPlatform.apple.kt` + an `LSApplicationQueriesSchemes` entry; resume / subtitles / return need a device test. ~half a day. Suggest riding Batch D.
- BUG-130 (carry the Detail background trailer's position into the full-screen cover), BUG-143 (network-aware rejected-link memory), BUG-129 (Sources tab vs up-next watcher): unscheduled, Christian's calls.
- Player P2 carried items (baked-bar aspect, 1080p harvest timing) belong to P3/P4.
- Upstream-report candidates queue (batch 10's nine, Search & Discover's two, BUG-141/142, the 08-30 four): a comms task for a quiet day, not a build.

---

## 2. Decisions for Christian

| # | Question | Recommendation |
|---|---|---|
| **D0** | Where does Batch A (Steven's mechanical items, ≈ 1 day) sit relative to the post-P5 rc? The drafted DM says "next build" for them. | **Run Batch A between P5's merge and the rc cut** (its own branch, its own Opus rounds, folded into the same regression pass). The rc then keeps the DM's promises. If the 10-16 checkpoint fires an interim rc first, Batch A can also go into that one. Otherwise soften the DM to "a coming build" before sending. |
| **D1** | Jellyfin / Emby (U3). | **Park.** It merged upstream 10-08 (0.5.8-beta) with 30 commits of fixes inside the PR already; let it settle one or two upstream releases. If wanted: a separate project after this plan, started with a half-day spike (extract `features/servers/*` + `mediabrowser/*` + `core/sync/MediaServerSync.kt` into `shared/` behind an `expect` `ServerStorage` for apple, compile on K/N, count what tvOS UI it needs: Settings › Services › Media Servers (URL + sign-in), a Library source, server streams in the picker, watched sync). Estimate 1.5–2 weeks with waves. Not in this plan. |
| **D2** | BUG-145: gate the add-on suffix on "Show catalog type in title", give it its own toggle, or drop it. | **Gate on the existing toggle** (the DM says "I will make it optional"). The setting's description text gains "and the add-on name on the new Home". |
| **D3** | UX-16 wash shape. | **Mask the wash to below the stage art's bottom edge** (the art region unwashed, the strip region washed) and trim the wash opacity (A/B 1.0 vs 0.8 on device). Keep Ambient Background on by default. Decide after the A/B, with his "blur only the lower part" in mind. |
| **D4** | UX-16 speed. | **Device A/B with the existing knobs** (`-debug.stripPageSeconds 0.35`, `-debug.stageSwapPause 0.3`), Christian + Steven's reading; adopt as defaults if both prefer. No new Settings row unless opinions split; then "Stage Motion: Standard / Quick". |
| **D5** | Collection logo placement. | **Fix the collision only** (immersive folder page, A3); placement stays top-left, large, as official Nuvio draws it. No corner option. |
| **D6** | FEAT-61 Classic. | **(a)** BUG-155's folder line, yes. **(b)** A "Collections Layout" setting (Follow Home / Rows / Grid) so Classic users get the Rows folder page: yes, Batch B. **(c)** No-bounce: tell him no. **And:** keep Classic alive until he and the Reddit testers have had the Stage for two public builds; the Stage plan's deletion step waits. |
| **D7** | BUG-151 localized copy. | **Yes, both surfaces** (Stage and Classic hero), reusing the FEAT-42 enrichment. TMDB-on only; one lookup per focused item, cached per TMDB language scope. |
| **D8** | FEAT-62 rail Hidden mode default. | Add the mode; **default stays Always Visible**. |
| **D9** | FEAT-60 + the Detail weekend items as one Detail pass (Batch C). | Yes. Cinematic only; Classic Detail stays byte-identical until its planned deletion. |
| **D10** | Tracker BUG-154 collision. | Renumber the Classic hero-ON row to **BUG-155**; the P2 arbiter row keeps 154 (its fix commit names it). |
| **D11** | U5 auto-skip toast. | Include in Batch C (≈ 1–2 h, player-side, no Settings row). Or decline; nothing depends on it. |
| **D12** | U2 ytId streams. | **Port**, Batch D. It is parity with upstream and the shape is small; the risk is the YouTube extraction's `LOGIN_REQUIRED` days (same as trailers), handled with the existing failure alert + "Try Next Source". |
| **D13** | MDBList device check. | U1's device pass needs an MDBList account connected in the **Test** profile (the L1 pass skipped MDBList for that reason). Christian's call whether to connect his MDBList to Test for one session. |

---

## 3. Batches

Order: **A ∥ D1** (two clones; disjoint files) → **C ∥ D2** → **B** (after the device A/Bs and his reply) → cut. Each batch is a submodule branch off the `tvos-shared-extraction` tip of the day, fast-forwarded on Christian's go, with the outer pointer bumped and a record commit; no cut between batches except as D0 decides.

### Batch A: Steven's mechanical items (≈ 1 day build, 2 Opus rounds, 1 device pass)

Branch `claude/steven-rc3-a` (clone `~/Claude/Projects/NuvioMobile-rc3-a`).

| # | Item | Files | Notes |
|---|---|---|---|
| A1 | BUG-152 logo loading state | `DesignSystem/CachedAsyncImage.swift` (new `loading:` builder on both inits, default `ShimmerView`; the BUG-41 convenience inits unchanged), `Screens/Detail/DetailCinematicHero.swift` `logoSlot`, `Screens/DetailView.swift:1751` Classic header, `InlineTrailerTitleOverlay` if it uses `CachedAsyncImage` (`TitleLogoHeader` and the Stage's `HeroLogo` load their own images: not affected) | Loading = the same title text the `failure:` builder draws. Unit: a `CachedAsyncImage` phase test if the view exposes one; UI: the Detail open leg asserts the `debug_detail_hero` probe never shows a shimmer id in the logo slot. |
| A2 | BUG-149 tile logo via `TitleLogoStore` | `Screens/InlineTrailerCard.swift` (`InlineTrailerTitleOverlay` observes `TitleLogoStore.shared`, `lookupIfNeeded([item])` on mount, URL = store → `heroLogoURL` → text) | Keep the metahub guess for `tt…` ids. UI leg: a TMDB-id fixture item with no preview logo shows a logo after the lookup (fixture simulator has TMDB on). |
| A3 | BUG-148 + UX-16 (3): Stage folder page immersive | `Screens/FolderRowsPage.swift`, `DesignSystem/TabBarVisibility.swift` (`immersiveHidden` path, the Detail-push shape), `Screens/Home/StripPager.swift:195` | Bar hidden from the push until pop (no reshow on the page, per the round-4 rule). In Rail mode the rule already hides the rail on immersive under Hide While Browsing; Always Visible keeps it, as on Detail. The logo's rise target stays the stage block top. Device: Menu pops to Home with the bar restored; a folder opened from the Stage, from Classic, and from Discover. |
| A4 | BUG-144 Classic folder grid | `Screens/CollectionsUI.swift` (same immersive treatment on push) | Fallback (only if the device pass dislikes a bar-less grid): re-link the grid's scroll view to the bar on reappear. |
| A5 | BUG-146 heading gap | `Screens/Home/StripGeometry.swift` (`catalogRowHeight`, `collectionRowHeight`), `StripGeometryTests`, `StageStripProbe` expectations | Heading + `md` + `sm`. Re-check the focus lift at Large with zoom on and titles on (the lift allowance is separate from the padding, so it should hold). |
| A6 | BUG-155 Classic folder line under the CTA | `Screens/HomeView.swift` hero-ON panel (near `ctaTitle`, `:6442`) | `folderHeroDescription` in `Theme.Font.meta`, 1 line; folders have no synopsis, so the slot is free. Unit: the panel's line-budget test gains a folder case. |
| A7 | FEAT-62 rail Hidden mode | `DesignSystem/NavigationChrome.swift` (`RailVisibility.hidden`, `RailVisibilityRule.shown`, `reservedLeadingInset`), `DesignSystem/NavigationRail.swift`, `Screens/Settings/AppearanceSettingsPane.swift` (value + description), `Localizable.xcstrings` (6 languages) | Rule table test: hidden → shown only with `holdsFocus` or `revealed`; Search keyboard case unchanged. UI leg: Left from the first card reveals, Right hides again. |
| A8 | Strings + tracker | xcstrings for the new rail value and the setting description; tracker rows → BUILT; BUG-154 → BUG-155 renumber (D10) | |

Gates: NuvioTVTests, Debug + Release sim, the Stage / folder / rail UI legs. Device pass (Test profile, dev build): 1. Open any Detail: title text, then the logo, no grey block (Cinematic and Classic). 2. Stage row with a TMDB-only title: the trailer tile shows the logo. 3. Stage folder with one row: no tab bar; Menu returns with the bar. 4. Classic folder grid → Detail → Back: no bar over the grid; Menu restores it on Home. 5. Headings sit just above the posters at Large / Medium+, zoom on, no overlap on the lift. 6. Classic Show Hero ON, focus a folder: "Genres · N sources" under Open Folder. 7. Rail = Hidden: nothing at rest, Left from the first card reveals, Menu reveals, Right hides.

### Batch B: Stage polish + localized copy + the repro items (≈ 3 days incl. device A/Bs)

Branch `claude/steven-rc3-b`. Starts with a **device A/B session** (Christian, Test profile) on the existing knobs before any default changes: glide 0.5 vs 0.35, swap pause 0.45 vs 0.30, wash opacity 1.0 vs 0.8, wash masked below the art (new knob `-debug.washBelowArt`).

| # | Item | Files | Notes |
|---|---|---|---|
| B1 | BUG-145 suffix gated (D2) | `Screens/Home/StageCopy.swift` (`headingAddon(title:addonName:enabled:)`), callers in `StripRowViews` / `DiscoverRowsPlan` / `BrowseComponents`, `HomeScreenSettingsPane` description | `StageCopyTests` gain the gate cases. |
| B2 | UX-16 (2) wash shape (D3) | `DesignSystem/AmbientWashLayer.swift` (mask / opacity), `Screens/Home/StageView.swift` (`StageArtMask` stays) | Behind the knob until the A/B; then the default. The wash probe line gains `mask=`. |
| B3 | UX-16 (1) speed (D4) | `Screens/Home/StripGeometry.swift` `StageStripTuning` defaults | Only the numbers, unless D4 wants the row. |
| B4 | BUG-147 OLED late darkening | `DesignSystem/AmbientWashLayer.swift` model (fade the outgoing wash on the stage commit) | Repro first with OLED on and the probe (`late=`); if `late` never climbs, it is the stage art's own cross-fade and the fix moves to `HeroCrossfadeImage`'s timing. |
| B5 | BUG-151 localized copy (D7) | `DesignSystem/TitleLogoStore.swift` (entry keeps `localizedTitle` + `description`; second gate `wantsCopy`), `Screens/Home/StageCopy.swift` (`make` prefers them), `Screens/HomeView.swift:442` (Classic hero), `Screens/Home/HomeRowPreviews.swift` | No Kotlin change (`fetchPreviewEnrichmentChecked` already returns both fields in the TMDB language). Cache scope is already per TMDB settings token. Budget: the lookup is one TMDB call per focused item, same as FEAT-42. Tests: `TitleLogoStoreTests` for the copy gate; a UI leg with the TMDB language set to `fr` on the fixture. |
| B6 | BUG-150 folder art | `Screens/FolderRowsPlan.swift` / `FolderRowsPage.swift` art source + decode | Confirm, then align with Home's `StageArtLayer`. His collection-page photo (asked in the DM) decides whether there is anything beyond that. |
| B7 | Weekend: black portrait poster after the fade | repro leg first (`-debug.trailerMorphAbortAfterWideMs`, a Stage portrait row); then `InlineTrailerCard.swift` / `CachedAsyncImage.swift` | Fix after the repro; if the cache is the cause, pin the morphing tile's poster for the morph's lifetime. |
| B8 | FEAT-61 (b): Collections Layout setting (D6) | `Screens/Home/HomeLayout.swift` / `FolderRowsPlan.swift` / `CollectionsUI.swift` (`FolderDetailView` picks Rows when the setting says so, independent of Home Layout), `HomeScreenSettingsPane` row "Collections: Follow Home / Rows / Grid", default Follow Home | Device-local key; the Rows page under Classic gets A3's immersive treatment too. |
| B9 | BUG-153 Detail stutter | profile on FA87 (`debug.detailScrollProbe`), then a mount window for Detail's heavy sections in `DetailView.swift` | Could move to Batch C if the fix is Detail-only; listed here because it is a repro item. |

Gates: NuvioTVTests, Debug + Release, Stage / folder / Discover legs, `AmbientWash` and `StageCopy` tests. Device pass (Test profile): 1. Headings carry the add-on name only with "Show catalog type in title" on. 2. Wash sits below the art, no blurred art at the sides, OLED on and off. 3. Glide and swap at the adopted numbers, Reduce Motion still cuts. 4. OLED on: no late darkening on a 10-row walk (probe `late=0`). 5. French TMDB language: a Netflix-catalog row shows the French title and synopsis on the Stage and on the Classic hero. 6. Folder page art sharp on a 4K folder with a backdrop. 7. Top 10 portrait row: play the in-row trailer on slot 3, leave, come back: poster intact. 8. Classic Home + Collections Layout = Rows: a folder opens as Rows. 9. Monstre Detail: first Down smooth (probe frames ≤ the War Machine numbers).

### Batch C: Detail pass (≈ 1.5 days)

Branch `claude/detail-c`. Cinematic layout only (D9).

| # | Item | Files | Notes |
|---|---|---|---|
| C1 | FEAT-60 compact logo header on hero exit | `Screens/Detail/DetailCinematicLayout.swift` (header slot), `Screens/DetailView.swift` (hooks on `DetailRowAnchor.heroExit` / return), `DesignSystem/TitleLogoHeader.swift` (compact variant), `DetailRowAnchorTests` | 0.25 s fade in as the hero leaves on the first Down; fades out on the Up that returns the hero; title text when there is no logo; respects Reduce Motion (cut). Classic untouched. |
| C2 | Weekend: darker area behind the synopsis + poster bottom | `DetailScrim` cinematic values (`cinematicVerticalBottom`, `cinematicRadial*`) or a local panel under the teaser reusing `DetailScrim.panel*` | `DetailScrimCinematicTests` grid floors updated; a sim capture before/after for the record. |
| C3 | Weekend: full-synopsis affordance | `DetailCinematicLayout.swift` teaser (`DetailSynopsisTeaser`): trailing "More" glyph when `synopsisTruncated`, a focus-time caption "Press to read" | `.defaultFocus` still lands on Play (F18). |
| C4 | U5 auto-skip toast (D11) | `Screens/Player/SkipSegmentPlanner` decision carries the segment type; `NativePlayerScreen.swift` + `MPVPlayerView.swift` `.auto` seek paths show a 1.4 s toast "Intro skipped to M:SS"; strings | Planner tests extended; never on chip, scrub or chapter seeks. |

Gates: NuvioTVTests (`DetailScrimCinematicTests`, `DetailRowAnchorTests`, planner tests), Debug + Release, the Detail UI legs (test77–84 family). Device pass (Test profile): 1. Open Silo-like series, first Down: hero leaves, compact logo fades in at the top and stays as the header; Up returns the hero and the header fades. 2. Synopsis area readable over a bright backdrop; poster bottom not washed. 3. The teaser shows a More hint on a long synopsis; select opens the sheet. 4. Auto-skip intro: one toast, no focus change.

### Batch D: upstream ports (≈ 2.5 days across two sub-branches)

**D1 · U1 MDBList release-date sort** (branch `claude/upstream-mdblist-sort`, shared + Swift labels).

1. Apply `d8ce7258` to `shared/`: `library/LibraryDisplaySettings.kt` (enum `RELEASED_DESC/ASC`, `availableLibrarySortOptions` per source, `effectiveLibrarySortOption` fallback rule, the two comparators, `libraryReleaseYear`), `library/LibraryProviderOrders.kt`, `mdblist/MdbListLibraryDecoder.kt`, `MdbListLibraryModels.kt` (snapshot `itemsOrder`), `MdbListLibraryProjection.kt`, `MdbListLibraryRemote.kt` (`synchronize(reloadItems:)`, `items(key, sort, order)` without a sort by default), `MdbListLibraryService.kt`, `MdbListLibrarySorter.kt` (release order cache), `tracking/TrackingLibrarySorter.kt`; port the seven test files into `shared/commonTest`. Diff line by line: `MdbListLibrarySorter.kt` and `MdbListLibraryDecoder.kt` carry the fork's batch-11 newest-first port (`0e8b51bb`) and may have drifted.
2. The DEFAULT comparator for MDBList changes (upstream drops the fork's "MDBList DEFAULT = newest added first" special case in favour of the provider's saved order). Check against batch 11's device-passed behaviour (MDBList Library newest-first): with upstream, "newest first" is `ADDED_DESC`, and DEFAULT is the owner's saved order. Release notes must say so.
3. `LibrarySavedContent.kt` does not exist in the fork: its two labels go to `LibraryGridPolicy.sortLabel` ("Recently Released" / "Oldest Released", 6 languages).
4. Manual refresh: find the Library's refresh action in `LibraryViewModel.swift` / `LibraryRepository` and pass `reloadItems = true` so a sort saved on mdblist.com is picked up (the commit's third bullet).
5. Snapshot storage: an older `MdbListLibrarySnapshot` without `itemsOrder` must decode (default null → one reload); check the fork's storage payload decoder.
6. Gates: jvm, K/N, composeApp (the enum is shared with the phone build), NuvioTVTests. Device (D13): MDBList in Test → a list's Sort pill offers Recently / Oldest Released; DEFAULT follows the order saved on mdblist.com; a manual refresh after changing the saved sort re-sorts; Trakt / Simkl lists do not offer the release sorts.

**D2 · U2 ytId-only streams** (branch `claude/upstream-ytid`, shared + Swift).

1. `shared/`: `StreamModels.kt` (+`ytId`, `youTubeIdToResolve`, `hasPlayableSource` includes it), `StreamParser.kt` (keep the stream, read `ytId`), new `streams/YouTubeStreamResolver.kt` (upstream's shape; `inAppPlaybackEnabled` from `FeaturePolicyProvider`), `trailer/InAppYouTubeExtractor.kt` (+`extractSingleUrl` = the HLS master when present, else the best progressive; port `selectSingleUrlManifest` and the `singleUrl` branch of `extract`), tests: `StreamParserTest` cases, `InAppYouTubeExtractorSingleUrlTest`, a `YouTubeStreamResolverTest`. tvOS has no `TrailerPlaybackResolver.kt`; the resolver takes the extractor's function directly.
2. tvOS: the stream picker's select path (`StreamPickerView.swift` / `StreamsViewModel.swift`) and the player's Sources list (`MPVPlayerView` Playback tab, `NextEpisodeAutoPlay` episode list) call `YouTubeStreamResolver.resolve` before building `PlaybackContext`; a "Resolving video…" state on the picker row; failure → the existing failure alert + Try Next Source; the resolved URL is session-only (never `lastSourceUrl`); the rejected-link memory keys the stream as `yt:<id>`. Row badge "YouTube". Both engines play an HLS master (mpv via its hls demuxer, AVPlayer natively; the loopback remux path is not involved).
3. Auto-play: `StreamAutoPlaySelector` filters on `playableDirectUrl`, so ytId-only streams stay out; add a test that pins it.
4. Gates: jvm, K/N, composeApp, NuvioTVTests; a UI leg with a fixture add-on emitting a ytId-only stream. Device: an add-on that emits ytId-only streams (the PR #2115 reporter's add-on, or a YouTube-backed Stremio add-on installed in Test): the stream shows, plays on mpv and on native, "Try Next Source" on a dead id; Auto-Play Best never picks it.

**D3 · FEAT-56 SenPlayer** (rides D2's branch, ≈ half a day): one spec in `ExternalPlayerPlatform.apple.kt` (`senplayer://x-callback-url/play?url=…`, title, start time, subtitle, `x-success`), `LSApplicationQueriesSchemes`, the External Player picker row; device: hand-off, return position. Answer GitHub #5 after the cut.

**D4 · hygiene**: commit `docs/upstream-port-plan-2026-10-08.md`; the next daily check should list U3 as "parked by decision D1" so it stops re-flagging it.

### Batch E: cut + comms

1. **Now (before any build):** send Steven's rc3 reply DM, with the "next build" lines adjusted per D0; it already answers the Wako clip, the hero on/off photos and the rail ask.
2. After A–D merge: full regression pass on the Living Room ATV (Test profile) = the player plan's post-P5 checklist + the per-batch device lists above (Home Stage and Classic, folders both layouts, rail three modes, Detail both layouts, Library with MDBList sorts, a ytId stream, SenPlayer hand-off).
3. `scripts/cut-rc.sh` → build 137 (or the next free number), tag `tvos-v0.3.0-beta.19-rcN`, IPA on litterbox + filebin + gofile, size verified, outer pointer bumped.
4. Release notes with `--prev-tag` = the post-P5 rc: a section per batch; every new setting with its default (Collections Layout = Follow Home, Rail = Always Visible with Hidden available, add-on name follows "Show catalog type in title", wash + speed defaults as adopted); MDBList DEFAULT = the order saved on mdblist.com, newest-first = Added (newest). Strip the generated commit list.
5. Steven's DM (SlopMonster 5/5), bubbles per area, with asks: a collection page photo at rest (BUG-150), OLED on walk (BUG-147), the Stage at the new speed, the rail in Hidden, the Detail header fade, and whether the French copy lands on his Netflix rows.
6. Tracker: rows → SHIPPED; FEAT rows for Collections Layout and the rail Hidden mode; BUG-155 renumber; CLAUDE.md + memory.

---

## 4. Agent roster (estimate)

| Batch | Specs / critique | Execution | Review | Device |
|---|---|---|---|---|
| A | 1 Opus spec (A3/A4 immersive rule + A7 rail rule), no critique | 3 agents (A1+A2, A3+A4+A5, A6+A7+A8) | 2 Opus rounds | 1 pass, 7 steps |
| B | 1 Opus spec (wash + copy gate), 1 critique | 3 agents (B1+B2+B3, B4+B5, B6+B7+B8), B9 main session | 2–3 Opus rounds | A/B session + 1 pass, 9 steps |
| C | 1 Opus spec | 2 agents (C1, C2+C3+C4) | 2 Opus rounds | 1 pass, 4 steps |
| D | none (upstream diffs are the spec) | 2 agents (D1, D2+D3) | 2 Opus rounds; the last one Codex if 10-29 has passed | 1 pass each (D13 for D1) |

≈ 7–9 working days end to end, two clones at a time at most, one build at a time.

---

## 5. Risks

- **One rc carrying P1–P5 + Search & Discover + Batch A** is already a six-area pile for Steven; adding A keeps his promises but lengthens the DM. Split by area, per-batch device records make a "feels wrong" note bisectable.
- **A3/A4 immersive folder pages** change a behaviour Steven did not ask about on Home-launched folders in Tabs mode (bar gone until pop). It matches official Nuvio and fixes two of his bugs in one move, but the device pass decides; the fallback (re-link the scroll view on reappear) is kept in the spec.
- **BUG-146's geometry trim** touches the strip's page height, which every Stage UI leg and the probe pin; expect a test-expectation sweep.
- **BUG-151** adds one TMDB request per focused item on English-metadata rows; it is the same budget FEAT-42 already spends for logos, and it is TMDB-on only.
- **U1's DEFAULT change** alters MDBList list order for anyone who liked newest-first on DEFAULT (batch 11); the pill still offers Added (newest). Say it in the notes.
- **U2 depends on YouTube extraction**, which fails on `LOGIN_REQUIRED` days (seen 10-03/10-05 from the Mac); the device pass must include a dead id and the failover path.
- **Codex is out until 10-29**; Opus rounds are the review record, as for P1/P2.
- **The Classic-deletion step** in the Stage plan and FEAT-61 pull in opposite directions; D6 holds the deletion until the Stage has two public builds of tester feedback.

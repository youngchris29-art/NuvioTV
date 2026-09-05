# Steven's beta.17 verdict — batch plan (2026-09-04)

## Context

u/mrStevenx3's beta.17 (build 116) verdict arrived by Reddit chat on 2026-09-04 00:20 with two videos
(`~/Downloads/IMG_8455.mov` = beta.17 walkthrough, `~/Downloads/IMG_8456.mov` = Omni + official Nuvio
comparison). Verbatim in `docs/steven-beta17-feedback-2026-09-04.md`; tracker rows filed in
`docs/beta-feedback-tracker.md` (BUG-87..93 new, BUG-41 re-opened, BUG-81/86/FEAT-29 still broken,
FEAT-30/31 re-raised). Reply sent 10:16 ET (`docs/comms-dm-drafts-2026-09-04.md`) with two asks:
Hero Paint Diagnostics photo (BUG-86) and whether the title bounce also happens at Medium (BUG-87).

Product constraints set by Christian for this batch:
- **The doubled hero (BUG-86) must be fixed for real.** Three prior "fixes" (BUG-42, BUG-71, BUG-86)
  each fixed something in our setup and not his. No beta ships until the fix is proven against
  HIS variables, not ours.
- Every task is delegated to an agent by model (see delegation table); the main session keeps
  verification, device passes and the merge decisions.

_(Sections below are filled in as the exploration agents report.)_

## Video evidence

Frames live in the session scratchpad (`scratchpad/frames-8455/`, `scratchpad/frames-8456/`); the
implementation step copies the named evidence frames into `docs/research/steven-beta17-video-evidence/`
(frames only, never the MOV — reddit-feedback-tracker precedent).

### IMG_8456.mov — Omni + official Nuvio reference (113 s) — what he wants, as shown
- **FEAT-30 (Omni sidebar):** floating top-left rounded translucent panel inside the safe area, NOT
  edge-anchored, NOT full-height. Collapsed = one pill with the current section (`⌂ Home`, ~13 % screen
  width). On focus it grows downward (~0.2 s) into Home / Search / Library / Settings, icon + label
  (~19 % × 31 % of screen). **Pure overlay: nothing behind it reflows.** Hidden entirely while browsing
  rows; summonable from mid-page. Omni exposes `Sidebar Style: Apple (Tabs) / Custom (Sidebar)`; he
  switches to Tabs, looks 15 s, switches BACK to Sidebar = preference statement.
  Evidence: `seq2-omni-sidebar-01..12.png`, `ref-omni-t21.png`, `ref-sbval-t48.0.png`.
- **BUG-92 reference (Nuvio inline trailer):** continuous white stroke (~1.7 % of card height), thin dark
  inner gap, video clipped to matching inner radius, never overflows or squares the corners. Focus is
  two-stage: border on the portrait poster first, then the card widens to 16:9 **at the same row height**
  (~2.9× width, neighbours slide right), never lifts, title logo composited bottom-left inside the card.
  Evidence: `ref-nuvio-t76.png` (close-up), `ref-nuvio-t68.png`, `ref-nuvio-t91.png`.
- **FEAT-29 reference:** focusing a collection card puts a LARGE collection logo in the hero: wordmark
  ≈ 0.2–0.35 × poster height, ≈ 0.75 × card width, left third of the hero, backdrop = poster mosaic of
  that collection. The label printed on the card itself is small (≈ 0.10 × card height). Evidence:
  `zoom-nuvio-collection-t96.png`, `zoom-nuvio-netflixlogo-t100.png`.
- **BUG-87 reference:** in both apps nothing moves on focus. Nuvio: no captions on Home rows, card does
  not lift or scale, row headers static, only the hero block repaints in place. Omni: caption in a reserved
  band under the focused card, next row header does not shift. Evidence: `seq-nuvio-focus-01/05/08.png`.
- **BUG-90 reference:** Nuvio's collection/brand logos are fully drawn in every settled frame; per-title
  hero logo trails the metadata by ~0.1–0.3 s (metadata leads, logo follows) — so "instant" for
  collections, near-instant for titles.
- Also shown: Nuvio's coloured glow behind the focused card sampled from its art; right-anchored hero,
  no buttons, cross-fade ~0.2 s.

### IMG_8455.mov — beta.17 walkthrough (146 s)
Settings inferred from the footage: French, dark theme, Large (6 posters across), No Zoom ON (focused card
same size as neighbours), ring OFF (neutral white border), Card Depth on, inline trailer autoplay on.
Settings screen never opened; no Trailers & Extras row, no Drop Game / Les Condés detail page shown.

**BUG-86 "doubled hero" = THREE distinct, frame-verified phenomena (I checked the key frames myself):**
- **(A) Cold-launch double build.** t≈0.85 Home paints: hero *Elize, Surgie de l'Ombre* (text title → logo at
  1.43), first row **"Top 10 des films"** fully loaded. t≈1.93 (**1.1 s later**) **abrupt full rebuild**: hero
  title becomes text *The Runner* (→ COUREUSE logo), first row becomes **"Nouveaux films"** with **grey skeleton
  cards again**, Elize backdrop still up then cross-fades. Two complete Home builds inside 2.3 s. Not reproduced
  when returning to Home from Search (t≈97). ⇒ This is a `headChanged=1` second publish with a re-ordered first
  section — a partial-catalog first publish, NOT the enrichment hold (revises H1's ranking; see below).
  Evidence: `bug86a-seq-t170-223.png`, `bug86a-seq-t223-276.png`, `bug86a-heroTitleOverlap-t200.png`.
- **(B) Title text and logo image drawn superimposed** on EVERY hero change, 4–10 frames (0.13–0.33 s):
  "The Runner"+COUREUSE (t 2.13), "The Last Sunrise"+DERNIER LEVER DE SOLEIL (t 28.5), "Walt Disney" text +
  script logo (t 50.6), "GIGN"+GIGN (t 100.9). = `HeroLogo` Text→Image under `withAnimation(.easeIn(0.25))`
  cross-fading both (H4). This is also BUG-90.
- **(C) Backdrop lags the text swap by 0.3–0.5 s** — old backdrop under new title/genres/synopsis, then
  cross-fade (t 1.93–2.25, t 63.55–63.80). Text is driven by `displayHero` instantly; `HeroCrossfadeImage`
  fades over 0.3 s with no coordination.
- Related: hero synopsis renders EMPTY ~0.4 s after the genre line, then pops in and pushes the row title
  down (t 28.0–28.37, `bug87-heroBlock-t28-29.png`) — enrichment overlay landing late (H1's real footprint).
- Related: hero lags focus by up to ~1 s and stops updating during fast scrolling (`hi_t34.png`, `sec_040.png`).

**BUG-86b collection background resize (t 50.33→51.2, `bug86b90-t5035/5060/5085/5120.png`,
`bug86b-bgGrow-t5070-5137.png`):** flat solid BLUE block (right 55 %) ~0.2 s → fully BLACK ~0.2 s → Disney
poster mosaic pops in LARGER and offset right → shrinks/slides into place over ~0.45 s. Three visual states in
half a second. Matches H2 (cover-as-fallback, then backdrop) plus a scale-in animation on the mosaic.

**BUG-87 (title bounce):** no sustained idle oscillation captured. What IS shown: row title + row block shift
vertically in stages because the hero block above changes height (empty→filled synopsis, text→logo title:
`launch_64.png` t 63.5–63.7), and "Services de Streaming" drawn DOUBLED mid-move (`bug89-prevRowSlivers-t5670.png`).
⇒ his "constantly trying to move back" is most likely the pinned-title corrector chasing a hero block whose
height keeps changing (synopsis pop-in, logo swap, folder-hero swaps) — the hero commit fix is upstream of it.
**BUG-88 (scroll glitch):** STRONG. Poster captions/logos drawn twice with ~40 px horizontal offset while a row
scrolls; cards appear as two semi-transparent different posters superimposed (cross-fade ghosting); static chrome
in the same frames is sharp ⇒ compositing, not camera blur. `hi_t34.png`, `bug88-posterGhost-t12942.png`.
**BUG-89 (last row):** STRONG. With "Services de Streaming" focused as last row, 4–5 thin coloured bars persist
above its title at the Genres cards' x-positions for SECONDS (`bug89-crop-t40.png`, `bug89-crop-t44.png`); mid-
transition the six Genres cards remain as half-height rectangles (`col_025.png`). Also: the collection mosaic
backdrop is NOT clipped to the hero region — poster fragments visible between/beside row cards (`hi_t40.png`).
**BUG-90:** plain "Walt Disney" text alone ~0.24 s, then text+logo superimposed 2 frames, then logo (`bug86b90-t5060.png`).
**BUG-91:** STRONG. Close-up t 5–15: visible empty band between artwork and the translucent card frame on the
top and left edges of every card (`hi_t7.png`, `hi_t9.png`, `hi_t13.png`).
**BUG-92:** VISIBLE. `hi_t118.png` (verified): inline trailer on the GIGN card sits offset — dark band between the
border and the video's top edge, video meets/passes the bottom border, GIGN overlay logo at the border edge;
`hi_t145.png`: the 16:9 trailer card overlaps the neighbouring OASIS poster.
**BUG-81:** NOT confirmed by this video (only a full-screen trailer from the detail button, correctly scaled).
**BUG-41:** not in this video. **FEAT-29:** VISIBLE — Walt Disney logo ~155 px wide in a 1920 frame vs ~230 px
for the text placeholder and ~380 px for a movie hero logo in the same slot.
Extra: collection background flashes a solid colour block before the mosaic; skeleton cards reappear at the
right edge during fast horizontal scroll (`home_002.png`).

## Doubled hero (BUG-86) — pipeline map and fix strategy

Paths under `NuvioMobile/`: `HV` = `iosApp/NuvioTV/Screens/HomeView.swift`, `HR` =
`shared/src/commonMain/kotlin/com/nuvio/app/.../home/HomeRepository.kt`, `HVM` = `HomeViewModel.swift`.

### Key structural finding
There is **no spatial double** in a single `HomeView` — every hero layer (`HomeHeroBackdrop`, `HomeHeroScrim`,
`HeroCrossfadeImage`) has exactly one call site, and the two `heroCarousel` call sites are mutually exclusive.
The tester's "displayed twice" is **temporal**: the hero commits, then re-commits seconds later with a different
payload. His own 08-05 frame showed the English synopsis crossfading under the French one — the whole hero
payload committed raw, then localized. All three prior fixes attacked artwork/remount symptoms and none touched
the payload double-commit. Every in-house gate (`test31HeroCommitsOnce`) is satisfied by that bug: it only rejects
`fallbackCached(hadArt=1) → primary` adjacency and never checks `primary → primary` for the same item.

### CORRECTED root cause after the cold-launch trace (supersedes the ranking below)
The video's t≈1.93 rebuild is a **partial-catalog first publish followed by the launch sync burst**, not the
enrichment hold:
1. Per-batch publish omits catalogs not yet loaded (`HR:350`); Swift `rebuildRows()` (`HVM:442-489`) orders
   rows from `settingsItems`, which is empty until `syncCatalogs` runs, so first paint shows whichever
   catalog loaded first ("Top 10 des films") on top.
2. `SyncManager.runOrderedProfileSync` (`SyncManager.kt:114-186`) then lands: Addons pull → new addon
   signature → second `syncCatalogs` + `refresh(force:)` (`HVM:514-547`); Collections → `syncCollections` →
   `applyCurrentSettings()` (`HCS:197-205`); HomeCatalogSettings → `applyFromRemote` (`HCS:664-705`)
   rewrites every `order`, republishes, `applyCurrentSettings()` again ⇒ rows reorder ("Nouveaux films"
   first) and NEW rows mount with cold poster URLs ⇒ skeletons.
3. The hero head is dropped through four holes: **A** `keepFrom` (`HR:386`) loses `previousStillReleased`
   once `isLoading == false && awaitingFirstRefresh == false`; **B** `refresh()` prunes `cachedSections`
   synchronously (`HR:117`) before setting `isLoading = true` (`HR:158`), so any concurrent publish evaluates
   against a pruned cache and drops the head, then `heroRandom` reseeds from `requestKey.hashCode()`
   (`HR:359`); **C** `hideUnreleasedContent` from the server (`HCS:668`) release-filters the head out;
   **D** `normalizePreferences` re-picks the two hero-source slots in the new order (`HCS:410-421`,
   default-true `:679`). `stableHeroSelection` (`HeroSelection.kt:53-64`) protects the head only against
   newcomers, never against the head's own section vanishing. There is NO gate waiting for hero-source
   catalogs; `FIRST_REFRESH_GRACE_MS` only serves collection-only profiles.
4. Why the sim never shows it: no signed-in sync burst (`SyncManager.kt:570-577`), one seeded addon ⇒ one
   signature change ⇒ every publish is `isLoading = true` ⇒ Hole A never opens; test31 never asserts
   `headChanged` (contract stated at `HV:2013-2014`, oracle never written).
The enrichment hold (H1) is real but produces the SECONDARY symptoms: empty synopsis then pop-in (raw publish
at the 2 s timeout, overlay served only on the next natural publish, `HR:645-661`), and the late localized logo
URL (`HR:488-492`). H2 (folder cover-as-fallback) and H4 (HeroLogo Text↔Image cross-fade, `HV:2742-2770`,
default opacity transition under `withAnimation`) are confirmed by the video. H3 (unconditional sync republish)
is the delivery vehicle of step 2.

### DESIGN (Wave H — the hero commit protocol) — decided
Two more holes found during design: **Hole E** — `cacheKey = "$key|$descriptorSignature"` mixes in VOLATILE
addon state (`displayTitle`, `enabled`, `isRefreshing`, `errorMessage`, `HomeCatalogDefinitions.kt:73-76`),
so a server-supplied addon name or a refresh flag flip prunes ALL of that addon's sections (`HR:117`) and forces
a network re-fetch = the skeleton rebuild in the video, independent of ordering; and the `onAddonsChanged`
signature (`HVM:532`) is ORDER-sensitive, so a server re-sort forces a full re-fetch. Also: the folder "mosaic
pops in larger then shrinks" is `.animation(.easeInOut(0.4), value: heroFocused || focusedItem != nil)` at
`HV:545` on the whole backdrop Group animating the `scaledToFill` geometry change from square cover to 16:9.

**Architecture: one identity commit (Kotlin), one paint commit (Swift), immutable afterwards.**
```
HomeRepository.HeroCommitGate         HomeViewModel.HeroCommitCoordinator      HomeView.HeroArtResolver
Idle → Armed → Released               pending → prefetch head art →            target → presented
waits: hero-source catalogs loaded/   commit heroItems + rows ONCE;            (item, backdrop, logo)
failed ∧ launch sync settled ∧        later publishes with same head+hash      swapped in ONE withAnimation;
enrichment done | 4 s timeout;        are DROPPED                              never Text↔Image cross-fade
then FREEZES payloads, PINS head
```
Post-commit invariants the code enforces: (1) the head changes only on user Hero Sources change, Show Hero
off, the head's origin catalog leaving `currentDefinitions` (user removed/disabled the addon), or `clear()` —
never on sync, reorder, prune, reseed, enrichment or hold expiry; (2) committed payloads (`name`, `logo`,
`banner`, `description`, `genres`) are immutable for the session except a one-time silent gap-fill of an EMPTY
description/genres (no artwork/title repaint); (3) Swift paints a hero only when backdrop AND logo are cached
or a deadline passed, text+logo+backdrop change in one transaction; (4) rows publish once, in final order, at
the same commit.

**K1 — `HR`, `HeroSelection.kt`, `HomeCatalogDefinitions.kt`, `HomeModels.kt`, new `HeroCommitGate.kt` +
`HomeLaunchBurstSim.kt` + tests (2 days):**
- New pure `decideHeroGate(HeroGateInputs) -> HeroGateDecision` (reasons `all|heroOff|reset|timeout|noSources`):
  sources ready = every key in `heroSourceKeys ∩ knownDefinitionKeys` has an outcome AND (no unknown persisted
  key OR no manifests pending); sync ready = `LaunchSyncState ∈ {NotApplicable, Settled}`; enrichment ready =
  `heroItemsAwaitingEnrichment(candidate).isEmpty()`; `!candidateEmpty ∧ all three → release "all"`.
  `HERO_COMMIT_GATE_TIMEOUT_MS = 4_000` from `refresh()` (the burst landed ~2 s after load start; 5 sequential
  RPCs + 4 parallel ≈ 1–2.5 s on home Wi-Fi; `gate=released:timeout` is visible in the photo so a slow network
  is diagnosable, never silent). Guest/signed-out ⇒ `NotApplicable`, no wait.
- `HR` state after `:110`: `heroGateState`, `heroGateArmedAtMs`, `heroGateReleaseReason`, `catalogOutcomes`,
  `committedHeadKey`, `committedHeroPayloads`, `heroItemOrigins`, `gateInputsJob`. `HomeUiState` gains
  `heroGateReleased: Boolean = false`, `heroGateReason: String? = null` (`HomeModels.kt:45-50`).
- `refresh()` (`HR:112-219`): key `cachedSections` by `definition.key` not `cacheKey` (Hole E; update `:164-166`,
  `:183-185`, `:350`, `:362`; `requestKey` keeps the cacheKey join); wrap prune + `isLoading` in
  `synchronized(heroSelectionLock)` (Hole B); arm the gate on the first catalog-bearing refresh; record per-key
  `Loaded|Failed` outcomes in the batch loop (`:182-191`); schedule the single gate timeout; start one collector
  on `LaunchSyncSignal.state` + `AddonRepository.uiState.map{pendingManifests}` that re-publishes on change.
- `publishCurrentStateLocked()` (`HR:334-447`): `keepFrom` no longer conditional on `isLoading` — an item is
  retained while its ORIGIN catalog is still in the definition set (`heroItemOrigins`), release filter kept
  (Hole C semantics: only a truly unreleased head leaves, logged `heroHeadDropped reason=unreleased`); head pin:
  if `committedHeadKey` is present in `keepFrom` it goes back to index 0 (Hole D re-picks reorder positions 1–7
  only); collection fallback also waits on `heroGateState == Armed`; while Armed and not released, publish the
  PREVIOUS heroItems AND sections (rows held too) and schedule enrichment; on Armed→Released freeze
  `committedHeroPayloads = heroItems.associate { key to it.withTmdbEnrichment(tmdb) }` (timeout ⇒ raw frozen),
  publish with `heroGateReleased = true`; after release serve committed items from the frozen map (identity-equal
  ⇒ StateFlow equality suppresses no-ops), newcomers go through the existing 2 s hold; gap-fill once for empty
  description/genres. `armHeroEnrichmentHold` returns while Armed; enrichment completion does a full publish
  while Armed. `resetHeroSelection*` clears the pin/frozen map; `clear()` resets everything.
- `HomeCatalogDefinitions.kt:73-76`: drop `displayTitle/enabled/isRefreshing/errorMessage` from the descriptor
  signature (guard test must still pass). `applyCurrentSettings()` idempotency via a settings+tmdb+gate+keys
  signature (skip identical publishes once Released).
- `heroRankingDebug` append-only: `gate= hold= sync= sources=k/n head= prune=`.
- **Burst simulation** `HomeLaunchBurstSim` (inert unless armed; Swift `-debug.homeLaunchBurstSim YES`, honoured
  only with `-debug.homeHeroProbe YES`): fail the first hero-source catalog's first fetch, delay enrichment
  2.5 s, then 1 s after first publish run in order: forced refresh with a changed addon `userSetName` (prune
  path), `applyFromRemote` with reversed orders + `hideUnreleasedContent = true`, collections re-emission. No
  server writes (verify `CollectionSyncService.observeLocalChangesAndPush`, wrap step 3 in
  `isSyncingFromRemote` if needed). On UNFIXED code this deterministically yields a `rows` reorder, `paint …
  same=1`, a hash change, and `inRows=0 → inRows=1 headChanged=1` — the red baseline.
- commonTest: `HeroCommitGateTest` (decision table), `HeroSelectionTest` additions (pure `pinCommittedHead`:
  survives empty pool / re-picked pool, dropped only when origin gone or truly unreleased).

**K2 — `HCS`, `SyncManager.kt`, new `LaunchSyncSignal.kt`, `ProfileSettingsSync.kt` + tests (1 day, lands FIRST):**
- `HCS.heroSourceKeys(): Set<String>` = persisted `heroSourceEnabled` keys (an addon whose manifest is still
  loading is included by stored key); nothing persisted ⇒ first `HERO_SOURCE_SELECTION_LIMIT` definitions in
  display order.
- `applyFromRemote` (`HCS:664-705`): signature-before/after check, skip `applyCurrentSettings()` when unchanged;
  Hole D: unknown remote keys default `heroSourceEnabled = false` when the local selection is already full;
  `normalizePreferences` (`HCS:407-430`) walks stored-true entries FIRST before the cap. `syncCollections`
  (`HCS:197-205`): same change check.
- `LaunchSyncSignal { Idle, NotApplicable, Running, Settled }`: `startFullProfilePull` early returns ⇒
  `NotApplicable`; before `runOrderedProfileSync` ⇒ `Running`; after its try/finally ⇒ `Settled` regardless of
  failed steps; `cancelAccountSync` ⇒ reset. Foreground pulls never touch it.
- `applyFeatureUnlessUnchanged` extended to all 11 remaining features (credential features compared stripped,
  force-apply when the blob carries credentials; string payloads trimmed; JsonObject/Boolean compares) +
  `ProfileSettingsSyncNoOpSuppressionTest` cases per shape.

**S1 — `HVM`, new `HomeHeroCommit.swift` + `HeroCommitCoordinatorTests` (1 day):** `HeroCommitCoordinator`
(`committedHeadKey`, `committedHash` = FNV-1a of `banner|logo|name`, `artTimeout 1.5 s`, `prepare()` awaits
backdrop+logo of the head via `ArtworkStore.fetch`, prefetches the other 7 + first 4 rows × 7 posters).
`homeWatcher` (`HVM:216-259`): hold `heroItems`/`sections` while `!heroGateReleased` (hero-off profiles publish
sections immediately); same head + same hash ⇒ assign sections only, never re-assign `heroItems`; same head +
different hash ⇒ log `hashChanged=1`, still no repaint (a red flag in the photo, not a repaint); new head ⇒
prepare then assign heroItems + sections + `rebuildRows()` in one main-actor turn. New probe lines `commit …
art= waited= first=`, `rows … n= first=`; `publish` gains `hash= gate=`. `onAddonsChanged` signature sorted
(set semantics). Arm the burst sim after `AddonRepository.initialize()`.

**S2 — `HV` only (2 days):** `HeroPresentation` + `HeroArtResolver` (`present(target:isFolder:)`: cached
backdrop+logo ⇒ commit synchronously in one `withAnimation(.easeInOut(0.3))`; else keep the previous
presentation, fetch both, commit once when both land or `laterSwapDeadline 400 ms` / `folderDeadline 1.5 s`
passes; a late logo for an already-presented item is dropped); `displayHero` stays the TARGET, every renderer
(`HV:525-535`, `HV:1061-1066`) reads `resolver.presented`; auto-advance waits on `resolver.isIdle`.
`HeroCrossfadeImage(image:identity:)` init; `paint` gains `url= same=`. `HeroLogo` stateless
`(item:image:)`, `.id(item.id)` + `.transition(.identity)`, no `.task`, no inner `withAnimation` — the whole
presentation cross-fades once at the `HomeHeroForeground` level. `HeroPageDots` always mounted with opacity
(slot exists from frame one; keeps Wave 10 pinned geometry byte-identical). Folder hero: `poster: nil` in
`folderHeroPreview` (`HV:1283-1304`), prefetch ALL folders' backdrop+logo at row `.onAppear` (drop `prefix(8)`),
delete the `.animation(…, value: heroFocused || …)` at `HV:545` and animate opacity only via `onChange`.
Synopsis gap-fill lands with `.animation(nil)`. `headMaxLines` 16 → 24.

**S3 — `NuvioTVUITests.swift`, `HomeHeroProbeBufferTests.swift`, `AboutSettingsPane.swift` subtitle (1 day):**
test31 rewritten in three legs, `pause(6.0)` before reading About: **A** plain probe launch — one `vm start`, exactly
one `commit first=1`, zero `headChanged=1`, zero `hashChanged=1`, zero `same=1` on paint/present, the publish
before the first commit has `gate=released:all` and `sync ∈ {settled, na}`, one `rows` line in 5 s, existing
fallback→primary check kept; **B** `+ -debug.homeLaunchBurstSim YES` — same assertions PLUS at least one
`publish` after `commit` (burst ran) all with `headChanged=0 hashChanged=0`, no commit/present/paint after the
first commit before focus moves (**red today, green after**); **C** focus a folder tile 3 s, back, Search, back
— folder `present` has `backdrop != none`, `logo != text` when the folder has one, `same=0`, one `paint` per
`present`.

**The photo contract (Steven's About pane, 90 s after a cold launch, no input):** exactly one `publish` with
`n>0` before the first `commit`; `gate=released:all` (never `timeout` on his Wi-Fi); zero `headChanged=1`,
`hashChanged=1`, `same=1`, `art=timeout`; at most one `rows` line in 5 s; later sync-driven `publish` lines
only if the settings signature changed, carrying `headChanged=0 hashChanged=0` with no commit/present/paint
after them. Failing signatures per hole are enumerated in the design report (prune-driven `headChanged=1` with
`prune>0`; `inRows=0 → inRows=1`; `hashChanged=1`/`same=1` = raw-then-enriched; `commit` after a `publish`
with `sync=running` = burst not gated; a second `rows` line with a different `first=` = row rebuild).

**Order:** K2 → K1 ∥ S2 → S1 → S3 → sim gate (test31 A/B/C red-then-green) → Codex rounds on `HR` and `HV` →
device pass (below) → rc to Steven → his photo → public beta.

### Original ranked hypotheses (kept for the record; H1/H2/H3/H4 all remain part of the fix surface)
- **H1 ★★★★★ — enrichment hold timeout = raw commit then enriched re-commit.** `HR:503-513`
  `heroItemsAwaitingEnrichment` returns all 8 heroes when TMDB is on with a key + French; `HR:521-536` arms a
  **2 s** hold (`HERO_ENRICHMENT_HOLD_TIMEOUT_MS`, `HR:913`); on timeout `HR:530-534` publishes RAW (paint #1);
  enrichment lands ~3 s, overlay filled (`HR:619-622`) but hero republish suppressed (`HR:640-645`); the next
  natural publish (catalog batch `HR:194-199`, fan-out end `HR:208-211`, grace lift `HR:260-263`, settings sync
  `HR:276-279`) runs `withTmdbEnrichment` (`HR:433`) → new `banner` URL + French name for the same item →
  `HVM:241` writes `heroItems` unconditionally → `HeroCrossfadeImage.task(id:)` re-fires (`HV:2177`) → primary
  crossfade at `HV:2291` (paint #2). Aggravator: every `refresh()` resets the hold (`HR:125`) and
  `onAddonsChanged` (`HVM:514-547`) forces refresh per ready-addon change → multiple cycles per launch (matches
  his 22.3 s / 44.1 s double `publish n=8` photo). Dev never reproduces: sub-2 s enrichment, or TMDB off ⇒ no hold.
- **H2 ★★★★☆ — folder hero paints the cached COVER, then the backdrop.** `folderHeroPreview` (`HV:1283-1304`)
  sets `poster = coverImageUrl` as fallback + `banner = heroBackdropUrl` as primary; the cover is already in
  `ArtworkStore` (it is the tile), and a cached fallback on a non-first paint commits **with no grace**
  (`HV:2225-2237`; the 150 ms `laterSwapGrace` guards fetched fallbacks only, `HV:2307-2316`). Backdrop prefetch
  fires on the same focus event and only for `folders.prefix(8)` (`HV:946-951`, `HV:1263`). A square cover
  scaled-to-fill into 16:9 then replaced by the 16:9 backdrop = "backgrounds resize and move back into place".
- **H3 ★★★☆☆ — every cloud pull republishes the hero unconditionally.** `HomeCatalogSettingsRepository.applyFromRemote`
  ends with `publish(); persist(); applyCurrentSettings()` with no change check (`:702-704`); only 3 of 14 features in
  `ProfileSettingsSync.applyRemoteBlob` got the H-1B no-op suppression (`:546/:557/:568` vs `:576-660`). This is the
  delivery vehicle for H1's second commit "a couple of minutes after launch".
- **H4 ★★★☆☆ — HeroLogo is a two-state paint (Text → Image)** `HV:2739-2771`, folder hero logos start cold because
  `FolderTile` suppresses the logo overlay when a cover exists (`CollectionsUI.swift:394-397, 508-521`). This IS
  BUG-90 and part of the "two-stage hero" impression.
- H5 theme `.id()` remount on a genuinely different account theme (`ContentView.swift:105`); H6 trailer layer with
  a title-keyed cached zoom over the still (`TrailerHeroPlayerView.swift:840-886`) = BUG-81 family; H7 tab-subtree
  insert-before-remove — low.

### Instrumentation gaps to close FIRST (so his next photo is decisive)
1. `publish` probe line lacks a head **payload hash** (banner URL + name) — raw→enriched re-commit is invisible.
2. `crossfade` probe line (`HV:2382-2419`) lacks the **URL**; `primary(hadArt=1)` over an existing `primary` is the
   H1 signature and is indistinguishable today.
3. No probe line for `holdHeroPublish` / `heroEnrichmentHoldExpired` — add `hold=held|expired|clear` to
   `heroRankingDebug` (`HR:79-80`).
4. `test31` must reject `primary → primary` same-item adjacency and any second `publish` whose head payload hash
   differs with `headChanged=0`.

### Fix strategy (the "absolute fix" bar)
The fix must make the hero **commit once with its final payload** regardless of enrichment latency, sync timing, or
addon fan-in, and must be provable on the device with the tester's variables (French, TMDB on, Large, Nuvio-style
hero ON, Autoplay Hero Trailer, Fusion folders, cloud sync minutes after launch). Concretely:
- **A. Identity-stable hero commit (H1):** never publish a raw hero for an item that is still awaiting enrichment
  when the enriched payload can still arrive; when the hold expires, publish raw but **freeze the artwork/name**
  for that hero identity for the session (enrichment updates text fields only via a separate, non-repainting
  channel, or is dropped for the hero slot). Alternative considered: raise the timeout — rejected, a timeout is
  never a guarantee. Also stop `refresh()`/`onAddonsChanged` from re-arming the hold once the hero has painted.
- **B. Folder-hero fallback discipline (H2):** for `nuvio.folder` heroes, never commit the poster/cover as a
  fallback; hold the previous hero until the backdrop is cached (prefetch all folders, not `prefix(8)`, and
  prefetch at row appear, not first focus), and conceal → reveal only when the primary is ready.
- **C. No-op sync suppression everywhere (H3):** change-check in `applyFromRemote` before `applyCurrentSettings`,
  and extend `applyFeatureUnlessUnchanged` to all 14 features.
- **D. Logo prewarm (H4/BUG-90):** prefetch folder title logos with the cover, render the text fallback only after
  a short deadline, never Text→Image swap when the logo is cached.
- **E. Gate:** `test31` hardened per gap 4 + a new device-side diagnostic contract: one `paint first=1`, zero
  same-item repaints, zero `hold=expired`, over a cold launch with sync arriving — the plan's release gate below
  requires this photo from Steven's own TV before the beta is cut.

## Row geometry family (BUG-87 / 88 / 89 / FEAT-29) — root causes

Files: `BC` = `iosApp/NuvioTV/Screens/BrowseComponents.swift` (`PinnedRowTitle` :122, belt
`PinnedRowTitleTracking` :753-1210, corrector `PinnedRowSettle` :1448-2310), `HV`, `CollectionsUI.swift`,
`DesignSystem/Theme.swift`, `DesignSystem/PosterCard.swift`.

### Why the sim is green and Steven's TV loops (derived, high confidence)
The focus engine centres a link frame that does not fit; the link frame at Large is
`artwork 403.3 + 175.5 = 578.8 pt` against a rows viewport of `455 + 68.3 compression = 523.3` — **55.5 pt
over**. Wave 10 sized the compression against the ARTWORK (`BC:583-587`), not the link frame. The engine's
centred rest lands at margin **−3.8**, inside the ±4 dead zone **by 0.2 pt** — a coincidence, not a fixpoint.
Hardware parks ~75 pt deeper (BUG-66 family, documented `margin=-99` device vs `-25` sim) ⇒ far outside ⇒ the
corrector fires on every rest.

### The unbounded loop (BUG-87)
`settlePlan` (`BC:1975-2243`): `deficit == 0` **refunds** `consecutiveNudges = 0` (`BC:2126-2133`; also
`BC:2194`, `BC:2223`), so the 2-nudge budget only brakes consecutive FAILURES. A landed correction is motion
(`BC:1855-1859`) → re-arm → the engine re-reveals the frame back toward its own rest → motion → correct → ∞.
The session self-disarm (2 verification MISSes, `BC:2013-2016`) can never accumulate while the user moves:
`invalidateEpoch` nils `pendingVerification` on every focus change (`BC:1767`) and any reflow VOIDs it
(`BC:2002`). The belt cannot mask it because at the corrected rest the title is fine (`showAgain`), so the
user sees the title MOVE, never disappear — his exact wording. Independent second defect: `protectedBottom`
(`BC:1486-1489`) ignores the shelf's own 24 pt bottom padding (`BC:2794`), so every downward correction at
Large lands ~11.5 pt short then `standDown("bound")` (`BC:2219`) — the "almost, give up, engine moves it,
almost…" cadence. Amplifier: a motionless sample still arms when nothing is armed (`BC:1856`), so lazy row
realization (`contentHeight` change) triggers corrections with no scroll on a row-heavy Home.
Also: the hero block's height changes (empty→filled synopsis, text→logo swap, folder-hero swaps) each shift
the rows — the hero commit fix (above) removes those inputs.

### BUG-88
Same root mid-scroll: each horizontal focus step is a vertical reveal on an unsatisfiable frame → offset
jitter → the title re-animates its 0.22 s slide (`BC:958`) and/or crosses the belt's asymmetric hysteresis
(arm `intrusion > 4`, recover `≤ 0`, `BC:557-558`) → 0.2 s opacity blink. The video's doubled poster captions
are the row cross-fading under that jitter. Poster captions themselves (`PosterCard.swift:585-598`,
`CardCaptionFocusDrop` :487-504 = 0 in still mode) are not the mover.

### BUG-89
The last row is the one row EXEMPT from the canonical rest (`endOfContent` `BC:2193-2198`, upward-no-room
`BC:2223-2225` return `targetY: nil`). Band of previous row visible = `vh − 60 − lastRowHeight`; a collection
folder row with square tiles at Large is 471.9 pt (hidden titles: 436.9) vs the 511.3 needed ⇒ 39–74 pt of
the previous row's caption/artwork stays visible — exactly "Services de Streaming" as last row under "Genres".
Wave 10 created the contrast (every other row now hides its predecessor). Lever: `rowsInsets(pinned:)` bottom
(`HV:1177-1178`) must guarantee trailing range ≥ `vh − lastRowHeight + 48`. Also the collection mosaic backdrop
is not clipped to the hero region (video).

### FEAT-29 (regression)
The collection logo he means is the HERO logo (hero follows focused folder → `folderHeroPreview` `HV:1283-1304`
→ `HeroLogo` in the pinned logo slot). Wave 10's `logoSlotGive = min(compression, 32)` (`HV:2503-2506`) takes
the FIRST 32 pt out of the logo slot: **110 → 78 pt at Large**, 110 at Medium — matches "Medium is slightly
larger" exactly. Lever: spend compression on the synopsis first (`HV:2503-2510` order swap; synopsis give 36
covers 36.3 of the 68.3, logo loses only 32.3 → still worth re-floor-ing `heroLogoSlotHeightPinned`), and size
the folder-hero logo independently of the title-hero slot (reference: official Nuvio ≈ 0.2–0.35 × poster
height ≈ 80–140 pt at Large).

### DESIGN (Wave G — row geometry) — decided
**Correction to the premise:** the sim's Large rest is recorded at margin **+22** (`3c39c677`: the sim engine
TOP-anchors a too-tall frame and the corrector pulls 22 → 0, no re-reveal); the device's recorded `margin=-99`
at `vh=455` (`tests:4095`) is `vh − H + 24` to within 1 pt ⇒ hardware **BOTTOM-anchors** on up-walks. The
"75 pt deeper park" is anchoring, not a constant, and no point target with a ±4 dead zone can hold both.
Rejected: (B) re-key compression to the link frame (needs 112–124 pt, hero → ~240 pt, and the engine's rest for
a fitting frame is "minimal scroll", not margin 0 — moves the fight); (C) disable at Large (sim +22 cuts the
caption under the fold, device −31.5 puts the title 5.5 pt on the art → belt hides titles on every up-walk,
BUG-89 stays).

**Chosen: A as a legibility BAND, never refunded, pull-back aware, no motionless arming.** In `settlePlan`:
```
bandLow  = −clearance.focused                       // BUG-84 edge: title bottom at the focused art top
bandHigh = min(48, 48 + vh − lockupExtent − 8)      // previous row above the clip edge AND caption inside the fold
inBand   = bandLow−2 ≤ margin ≤ bandHigh+2
target   = margin < bandLow ? min(bandLow+deadZone, mid) : max(bandHigh−deadZone, mid)
deficit  = inBand ? 0 : |margin − target| ; bandHigh < bandLow ⇒ standDown("unsatisfiable") (belt owns it)
```
Large (No Zoom): band [−26, 4.5]; from above +24 → one nudge 23.5 (same rest Wave 10 produced, BUG-84 holds);
from below −31.5 → one nudge 9.5 (today: wants 31.5, clamped by the 24 pt `protectedBottom` error, lands −11.5,
`bound`, loop). Medium band [−26, 9.5]: from below −26.5 = inside slack → 0 nudges. Small: both rests inside →
0 (today 24–28.5 every row). A park 75 pt deeper than sim (−53): one nudge 31 → −22; if the engine pulls back,
the pull-back detector stands the row down, the belt hides the title within ~0.25 s, and nothing re-fires
until the user moves; two pull-backs ⇒ session disarm. Worst case on a fighting device: one 0.5 s
nudge-and-return per row for two rows, then static. Today: unbounded.

Edits, all `BC` unless noted (Agent 1 owns BC):
1. Band target replaces `BC:2091-2110`; delete `canonicalMarginTarget` (`BC:1568-1571`); `err`/`deficit`
   fields keep their spellings (err = signed distance to target, 0 in band); empty band ⇒ `standDown(…,
   "unsatisfiable")` before `BC:2135` but AFTER the `debug.pinnedSettleDisarm` guard (test48 leg A premise).
2. Wall-clock budget + pull-back detector: statics next to `BC:1583-1621` (`correctionsFired: [row: [Date]]`,
   `lastCorrection`, `pullBacks`, `pullBackDisarmed`, `settleSeq`); constants next to `BC:1555-1567`
   (`correctionWindow 8 s`, `maxCorrectionsPerWindow 2`, `pullBackTolerance = deadZone`,
   `maxPullBacksPerSession 2`). Budget gate replaces `BC:2165-2168` → `standDown("budget")`. Pull-back check
   after the verification block (`BC:2020`): same row, landed within `deadZone` of `fromMargin`, < 2 s ⇒
   `PULLBACK` log + `standDown("pullback")`, ≥ 2 ⇒ `DISARMED-PULLBACK`. `invalidateEpoch` clears
   `lastCorrection` only; `resetHostScopedState` clears both.
3. `protectedBottom` (`BC:1486-1489`) = `rowBottom − 44 − Spacing.lg(24)` (the three uniform-card shelves carry
   `.padding(.vertical, lg)`: `BC:2794`, `HV:1803`, `UpcomingRow.swift:56`; collection rows already pass
   `focusedLockupExtent`). Must ship WITH 1+2 (alone it makes today's loop worse).
4. `BC:1856` → `guard isMove else { return nil }` (epoch/late-clearance/belt re-arms untouched).
5. New `EnvironmentValues.pinnedRowIsLast` (key next to `BC:21-31`) read by `PinnedRowSettleTracking`
   (`BC:2334-2378`) into `Measurement`.
6. `debug_pinned` append-only new tokens after `deficit=`: `bandLo= bandHi= inBand= rowH= last= prevHidden=
   corrN= pull= pbDisarm= seq= armSrc=`; suffixes `budget=1`, `unsat=1`. Header doc `BC:1301-1447` rewritten;
   `Theme.swift:487-499` dead-zone doc updated.

**BUG-89 (Agent 2: `HV:914-980`, `HV:1175-1196`, `CollectionsUI.swift:122-141`):** `rowsInsets(pinned:)`
bottom = `max(60, vh − lastRowHeight + 48 + deadZone + 8)` with `vh = 455 + pinnedHeroCompression` (static,
Wave 10 rule) and `lastRowHeight` from `model.rows.last` (catalog: artwork + caption 43.5 if shown + 180;
collection: new `static CollectionRowView.pinnedRowHeight(collection:style:)` = `shelfMinHeight` arithmetic +
24 + 12). Large: hidden-title square-tile collection last row → 146; captions → 111; catalog last row → 60
(unchanged). Set `.environment(\.pinnedRowIsLast, row.id == model.rows.last?.id)` on the `ForEach` row.

**FEAT-29 (Agent 3: `HV:2486-2613`, `HV:2728-2773`, `Theme.swift:465-485`):** folder heroes get a merged box
in `nuvioLayout` (`logoSlot + 16 + 32 + 16 + synopsisSlot`, panel height identical by construction, outer
frame unchanged ⇒ rows cannot reflow) rendering `HeroLogo(item:, maxHeight: Theme.Size.heroFolderLogoSlotHeight)`
with a new `heroFolderLogoSlotHeight = 160` (+ release-inert `debug.heroFolderLogoHeight` knob for the device
bisect); gives become synopsis-first for all heroes (`min(compression, 36)` then logo; folder heroes: synopsis
give up to 72 with a 0 floor so the logo give is 0 at Large). Numbers: 78/110/110 → 160/160/160 (0.40/0.48/0.58
× poster height; a 2:1 wordmark 156 → 320 px wide at Large). `HeroLogo` gains `maxHeight` used at `HV:2747`.
Inside-collection title untouched.

**Tests (Agent 4: `NuvioTVUITests.swift`):** test47 gate 3 → per step `inBand == 1`, `beltFaded == 0`,
`pull == 0`, spread ≤ 5 within same-`rowH` groups; **new gate 4 (BUG-87)**: sample `debug_pinned` every 0.5 s
for 5 s idle → `max−min(margin) ≤ 4`, `pull == 0`, `pbDisarm == 0`, distinct `seq` ≤ 2, `corrN` non-increasing,
`protB ≤ vh + 2`; missing `seq=` = XCTFail. Optional gate 5 (BUG-88): 3 Rights, `inBand == 1`, `corrN` grew ≤ 1.
test48 leg B: walk down until `last=1`, assert `prevHidden == 1`, `inBand == 1`, `beltFaded == 0` (fixture: add a
hidden-title square-tile collection as the LAST Home row on FA87 so it is not vacuous). test48 leg A unchanged.

**Device pass (Steven's config, Christian's ATV):** Large, No Zoom ON, ring OFF, Card Depth ON, Nuvio-style hero,
French, CW + Upcoming + ≥2 catalogs + ≥3 folder rows with a hidden-title square-tile collection LAST; launch
`-debug.homeScrollProbe YES`, pull `log show … "[HomeScrollProbe]"`. Steps: idle-10 s photo pairs per row (one
`nudge=` max, no `PULLBACK`/`DISARMED`, `beltFaded=0`); up-walk (`margin≈-31 inBand=0` → one `nudge≈9` →
`inBand=1`); 10 Rights/Lefts in a catalog and a folder row (`corrN ≤ 1`, no blink/ghosting — if ghosting
persists, BUG-88 has a separate compositing half); last row `last=1 prevHidden=1`; FEAT-29 wordmark ≈160 pt at
all three sizes and rows do not move on folder-hero swap; repeat two rows at Medium (Steven's question).
Merge order 1 → 2 → 3 → 4; Debug + Release builds; test45–48.

### Reuse
`debug_pinned` (append-only), `debug.homeScrollProbe`, `debug.pinnedSettleDisarm` + `debug.pinnedHeroCompressionOff`
(test48 leg A premise must stay reachable), `verifyViewportBudget` (`BC:624-634`), test47 gate 3 (extend: sample
the same row over ~5 s idle, assert margin drift ≤ dead zone = BUG-87 as an assertion), test48 leg B (add the
last-row assertion = BUG-89), test44/46 untouched (test44 still walks into the title band — known).

## Remaining items — root causes and levers

`PC` = `DesignSystem/PosterCard.swift`, `ITC` = `Screens/InlineTrailerCard.swift`, `THP` =
`Screens/TrailerHeroPlayerView.swift`, `DV` = `Screens/DetailView.swift`, `CDS` = `DesignSystem/CardDepthStyle.swift`.

### BUG-91 — No Zoom + Card Depth gap (root cause ~95 %)
`ringInset` (`PC:168-170`) returns 4 whenever No Zoom is on, focused or not. `PosterCard` shrinks the artwork
by 2×4 (`PC:552`), clips it (`PC:563`), re-frames to the outer size (`PC:564`) and THEN attaches
`.nuvioCardDepth` (`PC:568`) — so the depth rail (`CDS:238-249`) traces the OUTER rect: a 4 pt empty band on
every edge of every card at rest. `LandscapeCard` identical (`PC:669→671`). The other 4 band sites (TileFocusLift,
CastCard, FolderTile, InlineTrailerCard) scale the whole composited tile so their rail follows the art.
**Lever:** attach `nuvioCardDepth` to the inset artwork BEFORE the outer re-frame (radius `cornerRadius − inset`),
in both PosterCard and LandscapeCard; this also fixes the coverage-mask denominator (`CDS:268-281`). Do NOT
collapse the band at focus time (that reintroduces the Wave 7 pop, `PC:153-167`).

### BUG-93 — zoom ON + ring ON cuts posters / borders titles (high confidence)
`CardFocusButtonStyle` (`PC:87-100`) swaps to `StillCardButtonStyle` only in still mode; the zoom branch is bare
`.borderless` (`PC:95-98`). In `.manualScale` (ring on) `CardArtworkSystemLift` is a no-op (`PC:473`), so no
hover effect is declared on the artwork and `.borderless` falls back to its default treatment at the LABEL's
bounds = artwork + caption (`.posterButtonShape` `PC:29-41`) ⇒ the platter/outline wraps poster AND title
("border around the titles", the BUG-54 symptom text `PC:443-447`). The system lift compounds with the manual
1.12 (`PC:325`) ⇒ ~1.25 ⇒ clipped at the pinned rows' hard clip edge (`HV:988`), whose Large budget has zero
slack and assumes a 20 pt lift (`Theme.swift:407`) while ring mode charges ~27 pt (`BC:344-365`).
**Lever:** a `RingCardButtonStyle` (press feedback only, mirror of `StillCardButtonStyle` `PC:58-64`) for
`.manualScale`, keep the manual 1.12, then make `focusLiftAllowance` and `heroPinnedRowFocusLiftAllowance` agree.
**Gate to add:** ring-mode companion of `test46` (rise == manual scale rise, no platter).

### BUG-92 — inline trailer overflows the poster edge
Precondition: with Trailer Location = hero + pinned hero, the Home inline morph is suppressed
(`BC:2659-2673`), yet the video shows the morph on Home rows ⇒ **verify his Trailer Location** (the video's
hero shows no trailer playing while a poster trailer plays, consistent with Location = poster) before touching
code. Tile geometry (`ITC:877-1028`): per-axis `.scaleEffect(x: 0.98884, y: 0.98017)` AFTER the clip
(`ITC:974`) distorts the video and de-concentres its corners from the ring drawn at true bounds
(`ITC:1015-1027`); `.shadow(radius 22, y 10)` on the outermost layer (`ITC:1028`) paints outside the ring;
`TrailerPlayerUIView.clipsToBounds` is rectangular (`THP:159`), so the rounded corners depend on SwiftUI's
mask surviving over the hosted `AVPlayerLayer`; the morph widens 268.9 → 717 pt at Large over 0.35 s
(`ITC:1050-1053`, `ITC:339`) overlapping the trailing neighbour until `expansionChanged`'s corrective scroll
(`BC:2860-2895`). The verified frame (`hi_t118.png`) shows the video offset downward inside the ring = the
zoom transform not centred in the clipped surface.
**Lever (match official Nuvio):** uniform band by insetting the FRAME by `ringWidth` instead of per-axis
scaling; explicit inner `RoundedRectangle(cornerRadius − ringWidth)` clip on the video so it is concentric; move
the shadow behind the tile or drop it; keep the row height fixed (already true) and verify the `AVPlayerLayer`
transform is centred after `setCropZoom` (`THP:82-89`).

### BUG-81 — trailer zoom persists on HIS device only
Wave 6 code is present and correct. Differentiators, ranked: (1) French-preferred clip selection
(`DetailViewModel.swift:152-156`, `ITC:543-544`) = different encodes with different bar geometry than our
en-US pass; (2) `streamIdentity` (`THP:818-828`) keys `direct:` URLs on `id`+`itag` — googlevideo rotates itag
per extraction ⇒ perpetual token mismatch ⇒ cold re-measure at the parity floor every play; (3) VERIFY mode's
`final-clamped` escape (`THP:1146-1153`) leaves a bad cached entry untouched for 30 days; (4) plays too short
for a final (≥3 samples over ≥0.95 s, `THP:1109`). NOT confirmed by his video (only a full-screen trailer,
correctly scaled).
**Levers:** (a) make VERIFY's clamped branch evict or re-floor instead of keeping the entry; (b) key `direct:`
identity on the videoId only (drop `itag`); (c) a diagnostic ask: `debug.trailerProbe` cannot be set on a
sideload, so add a Settings > About "Trailer Diagnostics" ring buffer like the hero probe, exposing
`persisted-hit token=match|mismatch`, `final-clamped`, `abandoned` — his next photo decides.

### BUG-41 — description scroll choppy on some titles
Page = five full-screen layers under one ScrollView (`DV:170-357`): backdrop, poster-backdrop with a
`LinearGradient` mask, **a live `AVPlayerLayer` hero trailer** (`DV:182-193`), scrim, and `ScrollDimOverlay`
(`DV:19-42`, full-screen animated alpha blend, 0.12 s after each of ~17 quantized steps). Liquid-glass chips
(0–10 `.glassEffect` capsules, `DV:564-585`, `DV:948`) and 3–5 glass buttons in a `GlassEffectContainer`
(`DV:591`) re-sample whatever is behind them; over a playing trailer that is every video frame. Title-dependent
variables: whether a trailer resolved, chip count, series `EpisodesSection` (two more unclipped shelves), cast
count via raw `AsyncImage` (`DV:509, 1231, 1284`, no cache, main-thread decode). Matches his 08-22 "smooth once
past the trailer/episodes" (= past the 400 pt dim saturation).
**Levers:** the shipped A/B (`debug.detailScrollAB` 1 = dim off, 2 = glass chips off, 3 = both; the button styles
and container are NOT covered — add leg 4) is unusable by a sideloader; fix candidates in order: (1) freeze the
dim overlay to a non-animated, `drawingGroup`-free layer or step it on the scroll transaction instead of
animating; (2) pause/hide the hero trailer once the dim crosses ~0.5 (it is invisible anyway); (3) swap the three
raw `AsyncImage` sites to `CachedAsyncImage`; (4) glass chips → flat material when a trailer is playing.
**Repro pair:** Drop Game (series? has trailer) vs Les Condés — confirm on sim with `debug.detailScrollProbe`.

### DESIGN (Wave F — focus / trailer / scroll) — decided
Corrections from the design pass's own pixel reads: (i) BUG-92's "video offset" is NOT a transform bug
(`layoutSubviews` scales about the centre by construction); the ~8 pt dark band is the 4 pt reserved band
(showing page background) + ~4 pt of residual letterbox from an under-applied crop, and the bottom half is
hidden because `InlineTrailerTitleOverlay` (`ITC:1085-1128`) draws at the OUTER bounds. (ii) `streamIdentity`
`direct:` keys on `host+path+id+itag` (`THP:826`) and the googlevideo HOST rotates per extraction
(`TrailerLocalHLS.swift:286-292`) ⇒ every direct play is a token mismatch. (iii) `hi_t145` overlap is the 22 pt
shadow in the 28 pt gap and/or mid-morph capture — unconfirmed, device pass checks at rest.

**A — BUG-91 + BUG-93 (`PC`, `CDS` comment/DEBUG AX id, tests; lands FIRST):**
- BUG-91: in `PosterCard` (`PC:551-568`) and `LandscapeCard` (`PC:660-671`) attach `.nuvioCardDepth(
  RoundedRectangle(cornerRadius: max(0, r − inset)), surface:)` to the INSET artwork before the outer re-frame;
  ring overlay and lift stay on the outer frame; do not touch `ringInset`. Large/No Zoom: rail rect 260.9×395.3
  r 8, ring inner edge coincident. Ring off + zoom on: byte-identical. Coverage-mask denominator becomes the
  artwork height (fractions unchanged → `CardDepthRailTests` mirrors stay valid).
- BUG-93: `RingCardButtonStyle` (mirror of `StillCardButtonStyle`, `PC:48-64`); `CardFocusButtonStyle`
  (`PC:87-100`) reads `accent_focus_ring` and takes `lift: CardButtonLift` (`.card` default / `.plain`): still →
  Still+`focusEffectDisabled`; ring && `.card` → Ring+`focusEffectDisabled`; else `.borderless`. Six `.plain`
  one-liners where the label owns no manual treatment: `DetailView.swift:739, 995`, `BC:2774`,
  `CollectionsUI.swift:232`, `EpisodesSection.swift:49, 100`. Effective ring-mode rise = **20 pt at every size**
  (system lift is a constant rise, `Theme.swift:393-399`): replace `cardSystemLiftScale` (`PC:190`) with
  `cardFocusLiftRise = heroPinnedRowFocusLiftAllowance` + `cardLiftScale(artworkHeight:) = 1 + 40/h`
  (Large 1.0992); `.manualScale` branch of `CardFocusTreatment` (`PC:312-326`) becomes a no-op; the scale +
  black shadow move into `CardArtworkFocusLift` (renamed from `CardArtworkSystemLift`, `PC:461-477`) so ring and
  artwork scale in one SwiftUI layer (FEAT-14 graveyard respected); `CardCaptionFocusDrop` (`PC:487-504`)
  returns 20 for both zoom modes. **Handshake with Wave G (BC owner):** `focusLiftAllowance` (`BC:342-365`)
  `.manualScale` branch → `heroPinnedRowFocusLiftAllowance`; delete `cardManualLiftScale` (`BC:371`) and
  `cardLockupCaptionChrome` (`BC:383`); doc `BC:313-341`. Probe reads `lift=20` in both zoom modes, 0 in still.
- Gates: **test49RingModeRiseMatchesAllowance** (ring on + zoom on, test46 machinery, `rise == 20 ± 2.5`,
  no-platter luma sub-check left of the caption); **test50DepthRailHugsArtworkInStillMode** (DEBUG AX ids
  `card_depth_rail` on `CardDepthOverlay` `CDS:177-194` and `poster_artwork`; assert rail frame == artwork frame
  ± 0.5, width == button − 8; and == button width in the default config); re-run test44/46.

**B — BUG-92 (`ITC:917-1030`, new `NuvioTVTests/InlineTrailerTileGeometryTests.swift`):** precondition
confirmed by the video (morph on Home ⇒ his Trailer Location is Poster; in-tile logo ⇒ Hide Labels ON) — ask
him to confirm both in one line anyway. Replace per-axis `.scaleEffect` (`ITC:924-928, 974`) with a frame
inset via pure `InlineTrailerTileGeometry.inner(outer:band:cornerRadius:)` (band = `ringBandActive ? 4 : 0`,
inner radius `max(0, r − band)`); ZStack{art; player}.frame(inner).clipShape(inner r) → title overlay INSIDE
the inset (pass inner size) → outer frame → ring `strokeBorder` at the outer edge (unchanged). Drop the
`.shadow` (`ITC:1028`) when `ringBandActive`, keep it otherwise. Large: expanded outer 717×403.3, inner
(4,4,709,395.3) r 8; poster state inner identical to PosterCard's inset artwork so the morph starts concentric;
row height fixed. `AVPlayerLayer` needs no change; C adds a `layer … dx= dy=` probe line (expected 0/0). Gates:
unit tests for the geometry helper; DEBUG AX `debug_trailerTile outer= inner= band= rOut= rIn=` + a sim check
(forced morph via `debug.trailerSmokeVideoId`) asserting `inner == outer − 8`, `rIn == rOut − 4`, and identity
in the default config.

**C — BUG-81 + Trailer Diagnostics (`THP`, new `TrailerZoomProbe.swift`, `ASP`, `Localizable.xcstrings`,
unit tests):** (1) VERIFY + final-clamped (`THP:1146-1153`) → `TrailerZoomCache.remove(for:)` + log
`final-clamped … evicted=1` (leave this play's crop alone); (2) VERIFY + insufficient (`THP:1109-1128`) →
`Entry.verifyMisses: Int?` (blob v2 unchanged), evict at 3, confirm/correct reset to 0; (3) `streamIdentity`
(`THP:818-828`) direct URLs → `direct:id=<id>` only; repack unchanged (follow-up if diagnostics show mismatch
on consecutive repack plays); (4) surface names `hero|inline|full` + `attach` line. **Release-safe buffer**
`TrailerZoomProbe` (`debug.trailerDiagnostics`, 40 tail lines, `StreamProbe.swift` pattern) funnelling all 15
`[TrailerZoom]` NSLog sites; required lines: `attach surface= clip= lang= src= tok=`, `persisted-hit
token=match|mismatch cached= this=`, `interim`, `final measured= applied=`, `final-clamped evicted=`,
`insufficient verifyMisses=`, `abandoned`, `verify-confirmed|corrected`, `reveal reason=`, `layer dx= dy=`.
About pane: toggle + 1 Hz readout (`trailer_probe_lines`), "Trailer zoom cache: N entries", "Reset trailer zoom
cache" button; also the BUG-41 "Detail Scroll A/B: Off/1/2/3/4" picker and a live `debug.detailScrollProbe`
toggle (C is the single owner of ASP + strings). Photo discrimination: `token=match` + `verify-confirmed 1.3x`
on an over-zoomed clip ⇒ measurement wrong for that clip; `mismatch` every play ⇒ identity churn; `final-clamped`
/repeated `insufficient` ⇒ the escapes; `abandoned floor kept` ⇒ not the crop at all.

**D — BUG-41 (`DV`, `DesignSystem/CachedAsyncImage.swift`, new `DetailScrollProbeTests.swift`):** (1)
`ScrollDimOverlay` (`DV:19-42`) takes `trailerActive`; animate only when no trailer, else step at the 0.05
quantum; (2) `trailerDimmedOut` hysteresis (≥ 0.5 on, < 0.3 off) added to the hero-trailer condition at
`DV:182` — the player is dismantled once invisible under the scrim; (3) `AsyncImage` → `CachedAsyncImage` at
`DV:509/1231/1284` with a new optional failure view parameter (header logo must fall back to text); (4)
`detailChipBackground` (`DV:565-571`) flat while a trailer plays; (5) A/B leg 4 = leg 3 + `.bordered`/
`.borderedProminent` at `DV:604-700` + plain `HStack` instead of `GlassEffectContainer` (`DV:591`), `leg` a live
read; (6) `CADisplayLink` hitch counter under `DetailScrollProbe`: `[BUG41] hitches=N frames=M maxGap=ms`.
Sim: `debug_ux6 dark= trailer= glass= ab=` asserts (trailer/glass drop past `dark ≥ 500`, glass back below 300),
body-eval growth ≤ 1 per press; smoothness itself is device-only (legs 0–4 + hitch counter on Drop Game).

**Order:** A first (its six `.plain` one-liners touch other owners' files), then B, C, D and Wave G in parallel.
Fixed contracts: `debug.trailerDiagnostics` (Bool, live), `debug.detailScrollAB` (Int 0–4, live),
`debug.detailScrollProbe`, `TrailerZoomProbe.log(_:)`, `InlineTrailerTileGeometry.inner(...)`,
`cardFocusButtonStyle(lift:)`.

**Device pass 1 (French, Large, No Zoom ON, ring OFF, Card Depth Full then Top, Hide Labels ON, Trailer
Location Poster):** rail on the picture edge, no gap; focused ring flush outside the rail, zero rise; trailer
tile ring/video/logo concentric, no halo, right neighbour intact at rest; About shows `layer dx=0 dy=0`,
`attach surface=inline`; his zoomed title: hero loop 10 s + one row clip → About photo, reset cache, replay,
second photo; Drop Game description with hitch counter, legs 0–4 via About; folder/cast/episode tiles unchanged.
**Device pass 2 (No Zoom OFF, ring ON):** ~20 pt rise with the ring riding the art, no title outline, no clipped
poster top, row title clears (`lift=20`); trailer tile concentric with ring; `.plain` sites keep native lift;
ring OFF again ⇒ byte-identical default.

### FEAT-30 — Omni-style sidebar (product call owed)
No custom tab bar exists; `ContentView.swift:267-320` is a plain tvOS-26 `TabView` with six `Tab`s and
`.tabBarImmersiveHide()` (`TabBarVisibility.swift:158-184`); `.tabViewStyle` never called. Options: (a)
`.sidebarAdaptable` one-liner — Apple's sidebar, not Omni's pill, and lands on BUG-66's surface; (b) keep TabView
for hosting, permanently hide the bar, add an overlay pill in a ZStack with `@FocusState` expand + `.focusSection`
+ `.focusScope` so Left from column 0 reaches it (closest to Omni; 2–3 days + device focus rounds); (c) replace
TabView (loses per-tab state; rejected). "Hidden while browsing" signal exists (`immersiveHidden`,
`reportsScrollToTabBar`). ⚠️ `heroPinnedRowsViewportBudget = 455` is measured against the current bar chrome —
replacing the bar re-opens the Large compression arithmetic. Setting: device-local `@AppStorage`
"Sidebar style: Apple (Tabs) / Custom (Sidebar)". 4 strings × 5 languages.

### FEAT-31 — Open Sans (feasible, 1–2 days device-local)
All typography = 7 `Theme.Font` tokens (`Theme.swift:162-177`, 370 of 411 `.font` sites; 53 stragglers, 14 of
them `.system(size:)` mostly harness text). No `UIAppFonts`, no font files in the repo. Work: bundle Open Sans
Regular/SemiBold/Bold (SIL OFL), `UIAppFonts` in `NuvioTV/Info.plist`, tokens become computed via
`Font.custom(_:size:relativeTo:)` (keeps text-style scaling; ship real weight files, never synthesize), a
`FontStyleModel` mirroring `AppThemeModel` behind the existing `.id(appTheme.themeName)` rebuild boundary
(hoisted `@State`s at `ContentView.swift:33-47` stay above it), audit the 53 stragglers, Appearance pane row,
2 strings × 5 languages. Sync = device-local first (`inline_trailers_enabled` precedent).

## Product decisions (Christian, 2026-09-04)
- **FEAT-30 sidebar: DEFERRED** to its own wave after this beta (tell Steven it is on the list, no date).
- **FEAT-31 Open Sans: DEFERRED** (tracked; revisit with the sidebar wave).
- **Packaging: ONE rc with Waves H + G + F, Steven first.** Public beta only after his hero-diagnostics photo
  passes the contract above. Cost guardrail: never more than 3 agents in flight; ask before any fan-out beyond
  that (memory `usage-cost-guardrails`).

## Delegation table (one owner per file; main session keeps merges, builds, Codex loops, device passes)

| Wave / agent | Model | Owns (submodule paths) | Deliverable |
|---|---|---|---|
| H-K2 | Sonnet | `shared/.../home/HomeCatalogSettingsRepository.kt`, `core/sync/SyncManager.kt`, new `core/sync/LaunchSyncSignal.kt`, `core/sync/ProfileSettingsSync.kt`, their tests | `heroSourceKeys()`, change-checks, Hole D slot protection, launch-sync signal, no-op suppression ×11 |
| H-K1 | Opus | `shared/.../home/HomeRepository.kt`, `HeroSelection.kt`, `HomeCatalogDefinitions.kt`, `HomeModels.kt`, new `HeroCommitGate.kt`, `HomeLaunchBurstSim.kt`, tests | gate state machine, Holes A/B/C/E, head pin, frozen payloads, burst sim, commonTest |
| H-S2 | Opus | `iosApp/NuvioTV/Screens/HomeView.swift` | `HeroArtResolver`/`HeroPresentation`, stateless `HeroLogo`, dots slot, folder-hero discipline, probe fields |
| H-S1 | Sonnet | `Screens/HomeViewModel.swift`, new `Screens/HomeHeroCommit.swift`, `NuvioTVTests/HeroCommitCoordinatorTests.swift` | coordinator, rows hold, sorted addon signature, burst arming |
| H-S3 | Sonnet | `NuvioTVUITests/NuvioTVUITests.swift` (test31 only), `NuvioTVTests/HomeHeroProbeBufferTests.swift`, `Settings/AboutSettingsPane.swift` (subtitle string only) | test31 legs A/B/C |
| G-1 | Opus | `Screens/BrowseComponents.swift` (+ `Theme.swift:487-499` doc) | band target, budget + pull-back, `protectedBottom`, no motionless arming, `pinnedRowIsLast`, probe tokens; ALSO the Wave F handshake (`focusLiftAllowance` manual branch → constant, delete `cardManualLiftScale`/`cardLockupCaptionChrome`) |
| G-2 | Sonnet | `HomeView.swift:914-980, 1175-1196` (rows region ONLY — must not touch H-S2's hero region; sequence AFTER H-S2 merges), `Screens/CollectionsUI.swift:122-141` | BUG-89 trailing inset, `pinnedRowIsLast` env, `pinnedRowHeight` |
| G-3 | Sonnet | `HomeView.swift:2486-2613, 2728-2773` (hero foreground region — sequence AFTER H-S2 merges, or fold into H-S2's brief), `Theme.swift:465-485` | FEAT-29 merged folder-hero box, `heroFolderLogoSlotHeight = 160`, synopsis-first gives |
| G-4 | Sonnet | `NuvioTVUITests.swift` (test47/test48 only; sequence after H-S3) | gate 3 rewrite, gate 4 idle-drift, gate 5, leg B last-row |
| F-A | Opus | `DesignSystem/PosterCard.swift`, `CardDepthStyle.swift` (comment + DEBUG AX id), `NuvioTVUITests.swift` (test49/test50; after G-4), six `lift: .plain` one-liners (`DetailView.swift:739,995`, `BrowseComponents.swift:2774`, `CollectionsUI.swift:232`, `EpisodesSection.swift:49,100`) — **lands before B/C/D/G-1 branch** | BUG-91 rail inside the band, BUG-93 `RingCardButtonStyle` + 20 pt rise |
| F-B | Sonnet | `Screens/InlineTrailerCard.swift`, new `NuvioTVTests/InlineTrailerTileGeometryTests.swift`, `TrailerSoakTests.swift` | BUG-92 concentric tile |
| F-C | Sonnet | `Screens/TrailerHeroPlayerView.swift`, new `Screens/TrailerZoomProbe.swift`, `Settings/AboutSettingsPane.swift` (after H-S3), `Localizable.xcstrings`, new unit tests | BUG-81 VERIFY escapes + identity, Trailer Diagnostics, About pickers for D |
| F-D | Sonnet | `Screens/DetailView.swift`, `DesignSystem/CachedAsyncImage.swift`, new `NuvioTVUITests/DetailScrollProbeTests.swift` | BUG-41 dim stepping, trailer dim-out, cached images, flat chips, leg 4, hitch counter |
| Haiku | — | tracker rows, `docs/research/steven-beta17-video-evidence/` frame copies, comms drafts (SlopMonster loop) | bookkeeping |

Schedule (≤ 3 agents in flight): **Day 1** H-K2, F-A, G-1 → **Day 2** H-K1, H-S2, F-B → **Day 3** H-S1, F-C,
F-D → **Day 4** G-2, G-3, H-S3 → **Day 5** G-4, sim gates, Codex → **Day 6** device passes → rc.
Each agent brief = the wave section above verbatim + the file-ownership line + "report edit points, test
results, and every deviation". Agent-verified ≠ device-verified (memory `agent-delegation-playbook`).

## Verification and release gate

**Build/test gates (main session, after every merge):** `./gradlew :shared:jvmTest` (+ the new home/sync
suites), `:shared:tvosSimulatorArm64Test`, Debug AND Release sim builds (Release catches DEBUG-scope leaks;
`debug_scope_audit.py`), UITests: test31 A/B/C, test44, test45, test46, test47 (gates 1–5), test48 A/B, test49,
test50, DetailScrollProbeTests, TrailerSoak profiles; `NuvioTVTests` unit bundles. Codex review loop until clean
on `HomeRepository.kt`, `HomeView.swift`, `BrowseComponents.swift`, `PosterCard.swift` (`--base` scoped).

**Red-before-green proof:** test31 leg B must FAIL on `cf2f674e` with the burst sim armed (record the failing
lines in the plan doc) and PASS after Wave H. test47 gate 4 must be shown to fail with `debug.pinnedHeroCompressionOff`
+ the old code path on the sim (historical-geometry archaeology, as test48 leg A does).

**Device pass on Christian's Living Room ATV, Steven's configuration** (French system language; TMDB on with
key, Français, artwork + basic info; Large; No Zoom ON; ring OFF; Card Depth ON; Nuvio-style hero ON; Hero
Trailer Autoplay ON; Trailer Location Poster; Hide Labels ON; two hero-source catalogs from two addons; ≥3
Fusion collections with cover + backdrop + logo, one hidden-title square-tile collection as the LAST row; signed
in; a SECOND device on the same account reorders Home Rows, toggles Hide Unreleased and renames one addon before
every cold launch so the pull carries a real delta):
1. Hero (Wave H): About > Hero Paint Diagnostics ON, force-quit, Wi-Fi on, cold launch, no input 90 s, photo →
   must match the photo contract; then folder focus 5 s, back, Search, back, second photo (`present same=0`,
   folder `backdrop`/`logo` resolved, no extra `commit`). Repeat once under Network Link Conditioner 3G and
   accept `gate=released:timeout` only there.
2. Rows (Wave G): `-debug.homeScrollProbe YES` via devicectl launch args; idle photo pairs per row, up-walk,
   10 Rights/Lefts, last row `last=1 prevHidden=1`, FEAT-29 wordmark ≈160 pt at all sizes; repeat two rows at
   Medium; grep the log for `PULLBACK|DISARMED|BUDGET MISMATCH|compression CAPPED`.
3. Focus/trailer/scroll (Wave F) pass 1 (No Zoom ON, ring OFF) and pass 2 (No Zoom OFF, ring ON) exactly as
   listed in the Wave F design; Trailer Diagnostics photo on his zoomed title; Drop Game legs 0–4 hitch counts.
4. Regression: BUG-82/83/84/78 spot checks; Small/Medium hero and rows look; Search/Library/Detail tiles.

**Release sequence:** all gates green → outer/submodule pointer bump → build detached
(`nohup xcodebuild … NUVIO_BETA_TAG=tvos-v0.3.0-beta.18-rc1`) → `scripts/release-beta.sh --skip-build`
(dry-run still builds — memory `beta-track-status`) → unsigned IPA to catbox → DM Steven (SlopMonster 5/5,
explicit go-ahead before posting): what changed per item, the two photos to take (Hero Paint Diagnostics 90 s
after cold launch; Trailer Diagnostics after his zoomed title), and the Medium question → **public beta.18
ONLY after his hero photo meets the contract**. If his photo shows `gate=released:timeout`, tune the timeout
and re-cut; any `headChanged=1`/`same=1`/`hashChanged=1` blocks the release. Tracker: BUG-86/87/88/89/90/91/
92/93/41/81, FEAT-29 rows updated with commit ids; FEAT-30/31 marked deferred with the reply text.

**Bookkeeping in the implementation session:** copy the named evidence frames from the scratchpad into
`docs/research/steven-beta17-video-evidence/` (never the MOV), append the CORRECTED root causes to the tracker
rows (BUG-86 = partial-catalog first publish + sync burst + five holes, not the enrichment hold; BUG-87 =
anchoring, not a 75 pt constant), and record the design docs' full text under `docs/steven-beta17-batch-plan-2026-09-04.md`.

## Implementation outcome (2026-09-04 evening)

All work uncommitted on submodule branch `claude/steven-beta17` (off `cf2f674e`). Agents delivered per-wave code; main session merged branches. Tests (JVM + tvOS native) green. Codex review and device pass still owed.

### Per-agent deliverables

| Wave | Agent | Model | Owns | Deliverable | Tests / Notes |
|---|---|---|---|---|---|
| H-K2 | Sonnet | `shared/.../HomeCatalogSettingsRepository.kt`, `SyncManager.kt`, new `LaunchSyncSignal.kt`, `ProfileSettingsSync.kt` + tests | `heroSourceKeys()`, change-checks, Hole D slot protection, launch-sync signal, no-op suppression ×11 | JVM green; ProfileSettingsSyncNoOpSuppressionTest cases per shape |
| H-K1 | Opus | `HomeRepository.kt`, `HeroSelection.kt`, `HomeCatalogDefinitions.kt`, `HomeModels.kt`, new `HeroCommitGate.kt`, `HomeLaunchBurstSim.kt` + tests | gate state machine, Holes A/B/C/E, head pin, frozen payloads, burst sim, commonTest | JVM green; HeroCommitGateTest (decision table), HeroSelectionTest (pinCommittedHead); test31 leg B fails on old code as expected |
| H-S2 | Opus | `HomeView.swift` | `HeroArtResolver`/`HeroPresentation`, stateless `HeroLogo`, dots slot, folder-hero discipline, probe fields | Sim green; test31 leg C PASS |
| H-S1 | Sonnet | `HomeViewModel.swift`, new `HomeHeroCommit.swift`, `HeroCommitCoordinatorTests.swift` | coordinator, rows hold, sorted addon signature, burst arming | Sim green; test31 legs A/B PASS |
| H-S3 | Sonnet | `NuvioTVUITests.swift` (test31 only), `HomeHeroProbeBufferTests.swift`, `AboutSettingsPane.swift` (subtitle only) | test31 legs A/B/C | test31 A/B/C PASS (B fails on `cf2f674e` as red baseline) |
| G-1 | Opus | `BrowseComponents.swift` + `Theme.swift:487-499` doc; Wave F handshake | band target, budget + pull-back, `protectedBottom`, no motionless arming, `pinnedRowIsLast`, probe tokens; manual `focusLiftAllowance` branch → constant | JVM green; test47 gate 4 idle-drift ready |
| G-2 | Sonnet | `HomeView.swift:914-980, 1175-1196` (rows only), `CollectionsUI.swift:122-141` | BUG-89 trailing inset, `pinnedRowIsLast` env, `pinnedRowHeight` | Sim green; test48 leg B ready |
| G-3 | Sonnet | `HomeView.swift:2486-2613, 2728-2773` (hero foreground), `Theme.swift:465-485` | FEAT-29 merged folder-hero box, `heroFolderLogoSlotHeight = 160`, synopsis-first gives | Sim green; 160 pt wordmark measured at Large |
| G-4 | Sonnet | `NuvioTVUITests.swift` (test47/48 only) | test47 gate 3 rewrite, gate 4 idle-drift, gate 5, leg B last-row | test47/48 gates ready; test45/46 untouched green |
| F-A | Opus | `PosterCard.swift`, `CardDepthStyle.swift` (comment + DEBUG AX id), six lift: .plain sites, `NuvioTVUITests.swift` (test49/50) | BUG-91 rail inside the band, BUG-93 `RingCardButtonStyle` + 20 pt rise | test49 `rise == 20 ± 2.5`; test50 rail == artwork frame ± 0.5 |
| F-B | Sonnet | `InlineTrailerCard.swift`, new `InlineTrailerTileGeometryTests.swift`, `TrailerSoakTests.swift` | BUG-92 concentric tile via `InlineTrailerTileGeometry.inner()` | Unit tests green; `layer dx=0.00 dy=0.00` on sim |
| F-C | Sonnet | `TrailerHeroPlayerView.swift`, new `TrailerZoomProbe.swift`, `AboutSettingsPane.swift` (after H-S3), `Localizable.xcstrings` + unit tests | BUG-81 VERIFY escapes (evict/strike), identity by videoId only, Trailer Diagnostics buffer + About pickers for F-D | 13 unit tests green; About toggles `trailer_probe_lines` + Reset button |
| F-D | Sonnet | `DetailView.swift`, `CachedAsyncImage.swift`, new `DetailScrollProbeTests.swift` | BUG-41 dim stepping (no animation when trailer active), trailer dim-out hysteresis, cached images, flat chips, leg 4, hitch counter | `CADisplayLink` hitch counter active; legs 0–4 + hitch carrier ready |

### Corrected root causes

**Wave H (BUG-86 doubled hero):**
- **Partial-catalog first publish + launch-sync burst**, not enrichment hold alone. Per-batch publish omits catalogs not loaded, so first paint shows whichever catalog loaded first. `SyncManager.runOrderedProfileSync` then lands with addons → signature → second `syncCatalogs` + refresh, collections, home-catalog settings re-sort and republish. Hero head drops through five holes: A) `keepFrom` loses `previousStillReleased` too early; B) `refresh()` prunes cache before `isLoading=true`; C) `hideUnreleasedContent` release-filters the head out; D) `normalizePreferences` re-picks slots in new order; E) `cacheKey` mixes volatile addon state. The sim never shows it: no signed-in sync burst, one seeded addon. **Fix:** `HeroCommitGate` waits for hero-source catalogs loaded/failed ∧ `LaunchSyncSignal` settled ∧ enrichment done | 4 s timeout, then releases, freezes payloads, pins head to index 0 through reorders.

**Wave G (BUG-87 title bounce + BUG-88/89 geometry):**
- **Hardware BOTTOM-anchors focus frame vs sim TOP-anchors.** Focus engine centres a link frame that does not fit; at Large the frame is 578.8 pt against 523.3 pt viewport — 55.5 pt over. Wave 10 sized compression against artwork, not link frame. The engine's rest lands at margin -3.8, inside the ±4 dead zone by 0.2 pt — a coincidence, not a fixpoint. Hardware parks 75 pt deeper ⇒ far outside ⇒ corrector fires on every rest. Corrector was refunding budget on landed corrections (deficit == 0 → `consecutiveNudges = 0`), so 2-nudge budget only braked consecutive FAILURES, not consecutive attempts — landed motion → re-arm → frame pulls back → motion → ∞. **Fix:** legibility band (never margin 0; targets `bandLow` from title-overlap, `bandHigh` from previous-row visibility + caption) with session-scoped pull-back detector (one row, landed within deadZone of origin, < 2 s → stand down, ≥ 2 → session disarm). Never-refunded 8 s/2-correction budget per session, no arming on motionless samples. BUG-89 trailing inset from last-row height arithmetic per size/style (catalog 60/146/111 pt).

### Still owed before rc

1. **Fixture setup:** Large (from current Medium), one hidden-title square-tile collection as last Home row (for test48 leg B).
2. **Full gate run:** test31 A/B/C, test44, test45, test46, test47 (gates 1–5), test48 A/B, test49, test50, DetailScrollProbeTests, all TrailerSoakTests profiles.
3. **Codex review:** HomeRepository.kt, HomeView.swift, BrowseComponents.swift, PosterCard.swift (`--base` scoped, clean target).
4. **Commit:** all branches merged into `tvos-shared-extraction`, pointer bumped, pushed.
5. **Device pass:** Christian's Living Room ATV, Steven's configuration (French, Large, No Zoom ON, ring OFF, Card Depth ON, Nuvio hero, Trailer Location Poster, Hide Labels ON, 2+ hero-source catalogs, 3+ Fusion collections + last hidden-title square-tile, signed in, second device sync delta); steps per Wave H/G/F design; Photo contract for Hero Paint Diagnostics 90 s after cold launch, no input: `gate=released:all` (never `timeout` on Wi-Fi), one `commit first=1`, zero `headChanged=1`/`hashChanged=1`/`same=1`/`art=timeout`.
6. **Release sequence:** rc → DM Steven with what-changed + photo contract → his photo → public beta.18 ONLY if photo passes.


### Follow-ups landed later on 2026-09-04 (all uncommitted on `claude/steven-beta17`)

| Agent | What it found / did | Gate |
|---|---|---|
| H-K1b (Opus) | test31 leg A showed `gate=released:timeout` with every input ready. Cause: `drop(1)` on both gate-input StateFlow collectors discarded the readiness transition under load; the batch-publish interval starved re-evaluation; the manifest-pending predicate was over-broad. Fixed; probe gains `gateWait=`. | JVM 658 |
| F-C2 (Sonnet) | Repack token mismatch on every relaunch. Folded the itag out of the repack identity, then PROVED with one pinned video that the googlevideo `id=` query item is a per-request token, so neither `direct:id=` nor the repack content identity can ever match. | 12 unit tests |
| F-C3 (Opus) | The real BUG-81 identity: `TrailerPlaybackSource.videoId` stamped by the Kotlin extractor, `TrailerVideoIdRegistry` in `TrailerLocalHLS`, zoom identity `yt:<videoId>` for every surface. Sim proof: second launch `persisted-hit token=match` + `verify-confirmed` for both clips. | JVM 663, NuvioTVTests 52, Debug + Release |
| Parallel session (Christian's chip) | Extractor `extractYouTubeVideoId` top-level helper + 5 tests; stood down from the rest on request. | 17 trailer tests |
| G-4 (Sonnet) | test44 re-based to rise equality (20.0 / 20.0), test46 left-edge sub-check diagnostic-only (shadow-inflated button frame), test47 gates 3/4/5 + test48 legs A/B written. Not yet run on Large data. | test44/46 pass, 47/48 skip at Medium |
| Cross-agent review (Opus, read-only) | P1: a `timeout`/`reset`/`noSources` release with an EMPTY hero froze the rows for the session. P2: coalesced launch pull never marks `LaunchSyncSignal`; `AuthRepository.state` not a gate observer; `noSources` early release leaves slow-addon profiles unpinned; `present same=1` logged on the allowed text-only refresh. P3: `%d entries` vs runtime `%lld entries`. Ring style does not change AX exposure; the AX frame merely stops moving (render-only `scaleEffect`), which is why G-4's focused-button walk failed deterministically. | – |
| Swift fix pass (Opus) | `HeroPublishRoute` (hold / noHero / evaluateHead) replaces the holding guard; `same=1` only on a real image swap; xcstrings key renamed. | HeroCommitCoordinatorTests 16, test31 A/B green |
| Kotlin fix pass (Opus) | `adoptCoalescedLaunchPull` attaches the settle to the in-flight job; third gate collector on `AuthRepository.state`; `Released(noSources)` re-arms on the first catalog-bearing refresh (pin + frozen payloads cleared, `rearm=` probe field). | JVM 675 |

Corrected state machine: `Idle → Armed → Released(reason)`; `Released(noSources) → Armed` on a catalog-bearing refresh; every other reason is final until `clear()`.

### Late evening 2026-09-04: fixture, Codex round 1, Kotlin/Native

- **FA87 fixture set to Large through the real Appearance UI** (`FixtureSetupTests.testSetPosterSizeLarge`; `testSetPosterSizeMedium` restores). Card Depth ON, Hide Titles OFF. Every Large-only gate then passed on real data: test47 fresh-launch (`pull=0 inBand=1`, zero idle drift over 5 s, clean horizontal walk), test48 (`last=1 prevHidden=1` reached at row 32; walk ceiling raised 14 to 40), test44 (19.5 pt vs 20), test46, test49, test50. Trap found: XCTest orders `-only-testing` methods alphabetically and a test launching without `forceFreshLaunch` reuses the previous test's process; test47 now forces a fresh launch. Trap found: `SettingsPickerRow` composes no accessibility label, so the Poster Size row is reached by a fixed offset from the theme swatches.
- **Kotlin/Native**: `tvosSimulatorArm64Test` 703 tests, 0 failures, after renaming two test functions whose backtick names contained commas (Kotlin/Native rejects them; the JVM does not).
- **Codex round 1** (working tree): 2 P1 + 5 P2, all confirmed and fixed. Swift: the cancelled hero-commit task could still commit (generation bump + cancellation check), same-head publishes restarted the 1.5 s art wait before the first commit (pending head absorbed, latest state committed), carousel tails never refreshed (`tail=1` proved live on the fixture), `first_hero` marked before paint, `heroPayloadSignature` incomplete (rating excluded on evidence: not rendered). Kotlin: profile switch could settle the new gate with the old profile's signal (signal claimed synchronously at request time + completion handler, mutators synchronized; the in-block `markRunning` could steal tracking back and was removed), collection folder contents absent from the `syncCollections` no-op check (content digest added, kept out of `uiState.signature`). NuvioTVTests 64, JVM 683.
- Codex round 2 and the final gate script (Debug, Release, unit bundle, eleven UI targets) running at the time of writing.
- **Final gate run (pre-Codex-r2 tree, 21:00):** Debug + Release green, NuvioTVTests 64 green, UI 14/15 with leg C's expected skip; **test31 leg A failed once on `gate=released:timeout gateWait=sources sources=2/2`**. Simulator log: `addonsChanged ready=9` at 2.8 s, `ready=10` at 5.1 s, `ready=11` at **14.0 s**; the gate armed at 2.8 s and timed out at 6.8 s because the eleventh addon's manifest (a persisted hero source) was still in flight. Leg B one minute later had all eleven cached and released on `all`. The timeout was honest (one slow addon server) and the head stayed pinned (`headChanged=0` on every later publish). Decision: the leg A oracle accepts `timeout` ONLY when `gateWait=sources` and an `addonsChanged` lands after the timeout; `gateWait=-|sync|enrich` still fail. The same rule applies to Steven's photo: a `timeout gateWait=sources` line followed by one `commit first=1` and no `headChanged=1` is a slow add-on, not a regression.
- **Codex round 2** (settled tree): 2 P1 + 2 P2. Kotlin fixed: the gate is decided before `heroItems` is chosen (a collection fallback resolved while Armed is committed instead of an empty hero; empty catalog heroes could previously only end on `timeout`), all-off hero sources distinguished from none-stored, running slot budget for unknown remote keys (JVM 696, K/N 716). Swift (in progress): hold `rebuildRows()` from the collections and settings watchers until the first commit.
- **Codex round 2 Swift fix landed:** `RowsGate` (pure, in `HomeHeroCommit.swift`) — every `rebuildRows()` caller (home watcher, collections watcher, settings watcher) now goes through `requestRowsRebuild()`, which drops and counts requests until the first commit or `noHero` publish opens the gate and performs ONE rebuild with the latest sections + collections + settings; pre-gate collection rows are held too (they are the rows the video shows moving). Safety escape: a profile with no enabled add-on manifest loaded and none fetching opens the rows gate (nothing will ever call refresh). Probe: ` rowsGate=<open|held>` on every `rows` line, ` heldRebuilds=<n>` once on open. Leg B proof: first `rows` line `rowsGate=open heldRebuilds=4` at 6123 ms, commit at 6124 ms, zero `rowsGate=held` lines across three legs. Note for later: the leg B reorder oracle compares only the first three row ids of consecutive `rows` lines, so it is weaker than it reads.
- **Codex round 3 + full gate re-run on a quiet machine (leg A oracle: `timeout` accepted only with `gateWait=sources` and a later `addonsChanged`) in progress at the time of writing.**
- **Codex round 3** (settled tree): 2 P1 + 2 P2, all fixed. `HeroCommitCoordinator.prepare` now parks on a continuation fed by unstructured fetch tasks (`HeadArtPrewarm`) and returns at the first of settled / deadline / cancellation, so the 1.5 s budget is hard (the previous `withTaskGroup` + `cancelAll()` awaited children that `ArtworkStore.fetch` never cancels); head backdrop + logo are fetched first and through a new `ArtworkStore.FetchAdmission.head` front-of-queue seam before any bulk prefetch; the detail trailer dismounts at dim 0.80 and remounts below 0.55 (was 0.5 / 0.3, visibly early); the hidden-labels fallback row height no longer adds the caption chrome. Follow-up in progress: `HeroArtResolver.present` carried the identical unenforced-deadline pattern (presentation, not commit) and `DetailScrollProbeTests` still encoded the 0.5 latch. The second gate run: Debug, Release, 70 unit tests green; its UI section was voided by a mid-edit compile error and re-runs on the settled tree.
- **Gate run 3 (post-Codex-round-3 tree, resolver hard deadline in):** Debug + Release green, NuvioTVTests 76 green, UI 15 targets: 14 pass, leg C skip, 0 failures. JVM 696, Kotlin/Native 716.
- **Codex round 4 blocked by the ChatGPT usage limit until 2026-09-05 00:44 ET** (two runs returned "Reviewer failed to output a response"; the companion log carries the usage-limit error). Stand-in: a read-only internal review of the post-round-3 delta (the beta.15 quota-gap precedent). It found 4 P2s, all real: `teardownPipeline()` left pending-commit state so a bare release/acquire could route `.absorb` forever with the rows gate open; the `present same=1` flag was provably unreachable (the refreshed presentation copied the current bitmaps), so half of test31's repaint oracle was vacuous and the one same-identity path that repaints TEXT (the English-under-French shape in the video) logged nothing; the add-on escape could open the rows gate while the Kotlin gate was armed; catalog-less-but-not-add-on-less profiles held their rows for the full 5 s first-refresh grace. P3s: `heroRankingDebug` read at log time after the main-thread hop (false-pass direction; snapshot into `HomeUiState`), rows-reorder oracle sees only three ids (`rowsHash=`), leg C present/paint count vs ring-buffer elision, head admission LIFO. Fix agents dispatched; Codex round 4 runs post-commit as a branch review after the reset.
- **Internal-review fixes landed.** Swift: `resetHeroCommitState()` runs from `teardownPipeline()` and `stop()`; `HeroArtResolver.isVisibleRepaint` defines `same=1` as a field the viewer is already reading (name, releaseInfo, first three genres, description) being replaced at a stable identity, never a nil-or-empty value being filled in, and artwork is not a term because that branch cannot move it; the add-on rows-gate escape requires no catalog-bearing refresh yet; the `rows` line carries `rowsHash=` and per-row `order=` digests (ids were ~2.4 KB per line, too long for the About pane) and test31 compares the full-list relative order; leg C's paint count tolerates ring-buffer elision. Kotlin: the idle gate path shares the 4 s budget and `FIRST_REFRESH_GRACE_MS` now equals it (a 5 s grace would have left the release depending on an incidental publish and could re-hold a resolved collection hero); `HomeUiState.heroRankingDebugSnapshot` is stamped at publish time as a body property (a constructor parameter would break the exported ObjC initializer and defeat StateFlow equality) and the Swift probe reads it first. NuvioTVTests 81, JVM 702, Kotlin/Native 722; test31 legs A/B green with every `present` line `same=0`. Gate run 4 on the final tree in progress.

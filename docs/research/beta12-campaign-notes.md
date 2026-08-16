# beta.12 campaign — working notes (started 2026-08-10)

Running log of diagnoses and decisions per wave. Plan: `~/.claude/plans/lets-build-a-plan-elegant-frost.md`.

## Commit ledger (final)
- Waves 4–5: `923400df` — trailer stateless sessions (ephemeral cookie/cache isolation for extraction + sidx fetches), zoom-probe bail/abandon diagnostics, BUG-35 visibility-driven row localization. Codex gate: 4 rounds (hold-expired suppression swallowed row republishes → sections-only CAS update; teardown-abandoned probes now log; disabled-output gate; lost-update race → `_uiState.update`), clean.
- Waves 6+8: `f1a54014` — upstream ports 1–5 (Simkl null, StoredWatchedPayload OOM compaction, TraktWatchedShowSnapshotRepository, cacheResult param, autoplay-fallback plumbing+behavior) + FEAT-21 VidHub (/play modernization, Info.plist, resume/subtitles in handoff). Port agent: 331 shared tests 0 failures; divergence decisions documented in its report (shouldPersistWatchedSource shim kept, sibling-expansion stays removed, fork renames honored).
- Wave 7: `8576301f` + `0d7ecd38` — Vietnamese 217/217 shared + 585-key Localizable 100% × 5 languages (incl. the 71-key catch-up the pipeline surfaced for fr/es/de/it).
- Codex gate over waves 6–8 (`--base HEAD~2`): clean first pass (reviewer independently validated catalog JSON + format specifiers).
- Device pass: `docs/research/beta12-device-pass-checklist.md` (10 sections, knob launch-arg syntax included).

## Commit ledger
- Wave 0: `cabbed73` — trailer probes, gates line, BUG-39 scale-aware GIF ceiling, BUG-38 backdrop render. Codex gate 0: 1 finding, fixed, clean.
- Wave 1: `0554cc4b` — BUG-61 eased slide (sim A/B verified: 2 snap oscillations → 0), BUG-53/60 `debug.pinnedTitleMaxSlide` device knob. Codex gate 1: 3 rounds (mount flash; device knob unreachable via Mac defaults → launch-arg route; **.offset feedback loop settling half-clipped → all offsetting back inside visualEffect**), clean.
- Wave 2: `fe16a831` — BUG-48 query threading (+ pinning test) + UX-14 detach/resume with input-fingerprint identity. Codex gate 2: **9 rounds** (task re-key; genuine-exit teardown → live-input fingerprint; cancellation-flag race → CancellationException invisible to failure path; profile-select + account-wipe fan-outs gain FolderDetailRepository.clear(); overbroad identity narrowed to RetainedInputs incl. hideUnreleasedContent, excl. isRefreshing/sibling folders; publication race → loadJobsLock + registeredJob ownership guard + LAZY start), clean. tvosSimulatorArm64Test green throughout.

## Waves 6–8 progress (2026-08-10 late)
- Wave 6 item 1 (Simkl `pullFullyWatchedSeriesKeys` → null): DONE, verbatim upstream `0c6c6ed8`.
- Wave 6 item 4 (`MetaDetailsRepository.fetch(cacheResult:)`): DONE incl. both Swift call sites (K/N ObjC export has no default params — callers must pass it explicitly).
- Wave 6 items 2–3 (StoredWatchedPayload OOM compaction + Trakt snapshot repo): delegated to a port agent working hunk-by-hunk against the fork's diverged files; compiles+tests gate its completion.
- Wave 6 item 5 (autoplay-fallback setting): NOT started — do after the port agent finishes (PlayerSettingsRepository/Storage are near its file set; avoid collisions).
- Wave 7: Shared.xcstrings vi 217/217 (216 harvest + 1 overlay `vi.json`); pbxproj knownRegions +vi; scripts updated; populate ran (584 keys now, 71 NEW since last pass — fr/es/de/it owe ~67 each too); two translation agents producing part files in build/mt (vi 458 + gap languages). After merge: rebuild → re-populate → the new "Vietnamese" LanguageOptions label needs its 5 translations in a follow-up part file.
- Wave 8: DONE in code — Info.plist `open-vidhub` + comment, VidHub buildUrl modernized to `/play` (filename/position/sub), ExtPlayerProbe array, `openExternally` now passes real resumePositionMs (same progressForVideo lookup + >10s floor as MPV) and the stream's addon subtitles (SubtitleInput). Testing is device-only (canOpenURL false in sim).

## Wave 0 findings

### Trailer pipeline probes (BUG-55 blocking task) — DONE
`InlineTrailerCard.swift`: probe lines at `focusChanged(true)` (`focus key=`), dwell-fire (`dwell fired key=`), and every `expand()` outcome (`expand branch=resolved|resolvedStaleToken|miss`, `expand skip=alreadyFinished|unavailable|transient`) — all behind `TrailerProbe.enabled`. A dwell that never arms or an expand that early-returns is no longer invisible.
`TrailerDebugProbes.swift` + `BrowseComponents.swift`: `InlineTrailerGateProbe` logs `[TrailerPipeline] gates inlineTrailersEnabled=… systemAutoplay=…` on every state CHANGE, deliberately NOT behind the probe knob (≤2 lines/session; it's the line that explains a no-trailers session in a log pull nobody armed).

### BUG-39 (GIF sharpness) — mechanism confirmed in code, first fix applied
The tracker's points-vs-pixels hypothesis is right in outcome, wrong in mechanism: `targetDecodePixelCeiling` DOES multiply by screen scale, but then clamps to `maxFramePixelSize = 400` as a PIXEL cap — so on a scale-2 (4K) panel every tile decodes at ~half its backing store (Medium 220×330pt tile → 660px needed, 400px delivered). Fixed: the cap is now a POINT budget × capped scale (400px HD / 800px 4K), byte-identical on HD. The 12 MiB `maxDecodedBytesPerGif` budget still hard-bounds memory (enforced running total), so only short GIFs (<~12 frames) gain full resolution.
**Second layer, needs device data**: for ≥20-frame GIFs the BUDGET (not the cap) binds sharpness — `framePixelCeiling`: 60-frame GIF → 229px regardless of any ceiling. Truly fixing those requires trading unique frames for resolution (delay-folding subsampling machinery already exists) and/or raising the per-GIF budget. Added `[GifDecode] side= ceiling= sourceFrames= keptFrames= bytes=` probe (knob `debug.gifDecodeProbe`) — the device pass should report real collection-GIF frame counts before that trade is tuned.

### BUG-56 (trailer sound default) — static analysis complete, sim repro pending (Wave 4)
All three `setMuted` sites are correct-by-design (launch seed in `NuvioTVApp.swift:27`, pane onChange, full-screen-dismiss restore in `DetailView.swift:271`). The inline card's player is `TrailerHeroPlayer`, whose `attach()` seeds from `HeroTrailerAudioState` and watches the flow — with the toggle ON the code path is sound. Leading hypothesis: the reporter's same-evening uninstall+reinstall (BUG-46) reset `trailer_audio_default_on` (and `inline_trailers_enabled`) to OFF with the container; "reverts after navigating away and back" matches the full-screen-dismiss restore with default OFF after a manual play/pause unmute. Sim repro with toggle ON (Wave 4) decides; if it passes, BUG-56's "fix" is comms + possibly a settings-survival story for sideload updates, not code.

### BUG-55/46 persisted-state audit — prime suspect found
App-authored trailer state is ALL memory-only (`TrailerResolutionCache`, `TrailerLocalHLS` tokens, `InlineTrailerCoordinator` latch) — nothing the tracker's enumeration named actually persists. What DOES persist: the extraction stack (`TrailerExtractionPlatform.apple.kt:39`) uses `HttpClient(Darwin)` with the DEFAULT NSURLSession configuration → **persistent shared cookie jar (`NSHTTPCookieStorage`) + disk `URLCache`**. YouTube sets identity cookies (VISITOR_INFO1_LIVE etc.) on watch-page fetches; a rate-limit/bot flag on that identity:
- survives app restart (cookies+cache are container files) ✅ matches "restart no longer clears it"
- dies with uninstall+reinstall ✅ matches the temporary fix
- returns the same evening under heavy browsing (fresh identity re-flagged) ✅
- never reproduces in the sim (fresh container, low request volume) ✅
- explains BUG-46's resolved-then-black camera evidence (googlevideo throttling a flagged identity mid-stream) ✅
**Wave 4 fix**: give the extractor an ephemeral session (no persistent cookies, no disk cache) via Ktor Darwin `engine { configureSession { … } }`; visitorData is already re-scraped per watch page and sent explicitly as `x-goog-visitor-id`, so no functionality depends on the cookie jar. The device container dump (checklist item 3) remains the confirmation: look for youtube/googlevideo cookies in `Library/Cookies` and cache entries in `Library/Caches`.

### BUG-38 (collection covers) — root cause: write-only fields
No shared→tvOS mapping exists (tvOS consumes Kotlin types directly); nothing is dropped in mapping. The configured fields EXIST and sync (`Collection.backdropImageUrl` — user-configurable in mobile's editor, persisted, synced) but have **zero render sites in any client**; `CollectionFolder.heroBackdropUrl`/`heroVideoUrl` are declared and referenced nowhere else. Genre/discover folders never get `coverImageUrl` minted (`coverMetadataSourceTypes` omits DISCOVER/LIST), which is why the positional `FolderCoverResolver` fallback shows. Fix (Wave 0/1-adjacent, small): render `folder.heroBackdropUrl` → `collection.backdropImageUrl` ahead of `fallbackCoverUrl` in `CollectionsUI.swift:170-174` precedence. Residual risk to note in tracker: cloud key names might not match Kotlin property names (`ignoreUnknownKeys=true` swallows silently) — ask the reporter for their offered config capture to confirm the artwork lands in `backdropImageUrl` at all. Separate hazard filed for later: `CollectionCatalogResolver`'s `substringBefore(",")` fallback can bind a genre folder to the wrong catalog (the literal "wrong collection" the reporter described).

### BUG-43 (white language badge) — diagnosis complete: the guard never touches the fill, and three escape paths exist
The tracker's live question ("does this badge take that branch at all?") answered: `c29da28b`'s guard only picks a FOREGROUND; every unfocused branch keeps `bg: .pack` and `resolvedBackground` paints the pack `tagColor` hex verbatim (`StreamBadges.swift:218-221`) — a light pack fill is a white pill in every branch, and the shipped fix just made dark text on it more legible. Three concrete escapes:
1. **Image badge (most likely)**: packs are authored image-first (mobile renders only `imageURL` badges); `body` routes to `imageChip` whose fill (`filled ? Color(hexString: badge.tagColor) : …`, `StreamBadges.swift:42-49`) never calls the decision function at all.
2. **Explicit `textColor` distance escape**: guard is `abs(fgLum-bgLum) < 0.3`; white text on a mid-luminance fill passes untouched.
3. **8-digit hex parsed RGBA on tvOS vs ARGB on mobile/packs** (`Theme.swift:375-380` vs `StreamBadgeChip.kt:155-163`): `#FFxxxxxx` opaque colors become alpha≈0.1 ghosts on tvOS — a real cross-platform parsing bug feeding garbage luminance into the guard.
Also: the BUG-43 UITests hand-mirror the decision function and assert `bg == .pack` as EXPECTED — green tests coexist with the white badge by construction. Wave 3 fix shape: (a) fix 8-digit hex to ARGB on tvOS, (b) clamp/darken light pack fills on the dark picker (background decision, not just fg), (c) give `imageChip`'s filled background the same clamp, (d) rewrite the tests against rendered colors, not decision sources.

## Wave 2 (BUG-48 + UX-14) — implementation notes

### BUG-48 — query threading, exactly per the tracker sketch
`CatalogTarget.Addon` gains `search: String? = null` (data class → request identity/equality, incl. UX-13 restoration keying via `CatalogRequest`, distinguishes queries automatically); `CatalogRepository.fetchPage` passes it to `fetchCatalogPage` (whose `search` param already existed); `SearchRepository.toSection()` sets it via a new internal pure `SearchCatalogRequest.toCatalogTarget()` so a common test can pin the threading without network. Audit results: Home/FolderDetail `Addon` constructions keep `search=null` (unchanged behavior); mobile's `CatalogRoute` carries only a `launchId` (target stays in-memory — no route serialization impact); `CatalogTargetKind` enum has zero consumers (vestigial); search section keys already embed the lowercased query (BUG-33 work), so ForEach identity and UX-13 keys were already query-distinct. New test: `see all targets carry the search query` in `SearchSourceFilterTest`.
Prediction to verify in-sim and note for testers: Stremio Catalog Plus See All now shows the actual search results; Bingecat shows searched (not unfiltered) titles.

### UX-14 — FolderDetail pop-back scroll reset
Mechanism exactly as the DM-pass suspected: `FolderDetailViewModel.stop()` (fires on cover, not just exit) called `FolderDetailRepository.clear()`, so pop-back re-ran `initialize()` from scratch. Fix mirrors UX-13's contract: new `FolderDetailRepository.detach()` (cancel jobs, keep state) called from Swift `stop()`; `initialize()`'s existing same-key early-return preserves items → lazy grid keeps scroll. Added `resumeInterruptedTabLoads()` on the early-return path so a tab whose load was cancelled mid-cover doesn't spin forever (restarts state-says-loading/job-is-dead tabs; skips the "All" aggregate; `reset` only when the tab has no items). Mobile's route-pop `clear()` (App.kt:346) untouched.

## Wave 3 (theme tokens) — implementation notes

### BUG-45 — sidebar label now driven by the sidebar's own @FocusState
The zero-glyph measurement decodes as: env-based `rowAccentTint` resolving the ACTIVE branch (accent) while focused — and the sidebar is the one surface where focused == selected always (focus live-selects), so on the White theme (accent F5F5F5 ≈ platter white at video exposure, luma 221 both, range 3 ✓) the label vanishes completely. Chips survive because `ChipButtonStyle` sets the label color at STYLE level (its own env read provably works — the platter itself renders). Fix: `SettingsView.categorySidebar` colors the label from `focusedCategory` (the same `@FocusState` that drives the pane preview) — deterministic, cannot disagree with the platter. Open question for the device pass: whether `@Environment(\.isFocused)` misbehaves in OTHER `rowAccentTint` call sites (Écran d'accueil toggle rows) — not swept blind; needs a White-theme Settings walk with screenshots.

### BUG-43 — root cause was the 8-digit hex convention, fixed at the parser
`Theme.Palette.luminance(fromHexString:)` + `Color(hexString:)` read 8-digit hex as RRGGBBAA while every producer (badge packs, synced avatar colors) authors Android/Compose AARRGGBB (mobile: `6 -> FF+hex, 8 -> hex`). `#FFxxxxxx` opaque colors became ~10%-alpha ghosts AND fed alpha-as-red luminance into the BUG-28/43 guards — why `c29da28b` "didn't take". Fixed both parsers to ARGB (all call sites parse cross-platform strings, audited). Also fixed the image-chip fallback text computing contrast against `tagColor` when the chip isn't filled (actual bg is the dark row). Test mirror updated + 3 new pins (ARGB dark/light luminance + end-to-end guard trip). NOT done (deliberate): no clamping of light pack fills — mobile renders the same fills unclamped, and with correct parsing the fill parity IS the fix; if the tester's badge is a genuinely light-authored 6-digit fill it will now look identical to mobile, which is the standard the report measures against.

### BUG-58 — cannot locate the reported surface; needs reporter clarification
"Colour-selection screen in Appearance with black background": the Appearance pane's theme picker is inline (no screen); the subtitle-appearance preview's black card is DELIBERATE (simulates video). No pushed colour screen exists in Appearance. Tracker reply should ask which screen/how reached (or await their next video). No blind fix shipped.

### Sim-input note (affects later waves)
osascript key events stopped reaching the Simulator mid-session — the Claude desktop app holds frontmost and `Simulator.app` activation doesn't stick (headless boot, no window). All remaining in-sim UI verification must go through the XCUIRemote/UITest harness (headless-safe) or wait for an interactive window. BUG-45's visual confirm folded into the suite run + device pass.

## Wave 1 findings

### BUG-61 — FIXED and sim-verified
`PinnedRowTitleTracking` now measures the slide via `onGeometryChange` into local state and applies it as an explicitly eased offset (`easeOut 0.22s`, Reduce Motion → instant, first measurement seeds without animating). Frame-by-frame video analysis of row-to-row hops on the new build: the incoming title converges 344→291px (quarter-res) over ~13 decelerating frames — the old build's single-frame ~33pt snap is gone. Settled probe numbers byte-identical to baseline (slide 8 at the focused top row, 0 elsewhere; histogram matches `docs/research/bug60-bug61-sim-repro-2026-08-10`).

### BUG-53/60 — sim CANNOT close these; device calibration knob added
Confirmed empirically: at sim rests the parked title clears the art (screenshots), and the leftmost-focused-card occlusion does not reproduce — the persistent forms need the device's 40–67pt rest error, exactly as the tracker said. The band algebra is zero-sum (static margin + art clearance = reach 72 − title ~40 = 32pt regardless of title placement), the default lift is the SYSTEM `.hoverEffect(.highlight)` (own composited layer — no z-order fix from inside the hierarchy), and reach >72 is the banned dial. Shipped: `debug.pinnedTitleMaxSlide` runtime override so the device pass can bisect the clip-vs-ride-over trade live without rebuilds. The candidate structural fix if the device pass wants more (hoisting titles out of the scroll clip so they float into the empty band under the pinned hero) is a beta.13-sized rework — noted, not attempted.

### BUG-57 — parked to Wave 3; prefs-injection A/B is INVALID for this setting
Two attempts to A/B `card_depth_style_payload_2` via prefs injection produced pixel-identical Top-vs-Full renders with no visible treatment at all — even after fixing the cfprefsd ordering (terminate app FIRST, then `simctl spawn defaults write`, then launch; writing the plist while the app runs gets clobbered at terminate). Remaining explanation: profile settings sync restores the account's `enabled=false` over the injected payload at launch. Wave 3 must A/B via the Settings UI walk (or disable sync for the run). Methodology note kept for every future payload-key injection.

## Post-pass addendum (2026-08-15) — BUG-39 frame-vs-resolution trade, folded into beta.12

Section 4's device data (`side=200 ceiling=782 sourceFrames=90 keptFrames=78 bytes=7113600`)
exposed two things beyond "the budget binds": (1) the planner assumed SQUARE frames (`side² × 4`),
so a landscape tile's 200×114 px frames used only 59% of the 12 MiB budget; (2) resolution was
always sacrificed first — straight to the 200 px floor — before a single frame was dropped, with no
notion of a sharpness floor. Shipped as NuvioMobile `85c357f9` (Codex gate: clean first pass;
`GifDecodePlanTests` mirror 14/14; test06/test22 focus walks green with the change built):
- `AnimatedGifDecoder.GifDecodePlanner` — pure-Swift, aspect-aware (container properties; ceiling
  capped at the source's long edge because ImageIO thumbnails never upscale), tiered: all frames at
  the full backing store → all frames down to `preferredMinSide` = 1 px/pt (HD parity) → drop
  frames evenly down to `minKeptFrames` = GIF duration ÷ 12 cs (~8 fps floor, from the file's own
  delays) → shrink to 200 px → drop more frames. Kept frames still absorb skipped frames' delays, so
  total duration is unchanged in every tier.
- Row-stride estimate uses 32-byte alignment; verified against real
  `CGImageSourceCreateThumbnailAtIndex` output for six source shapes × six sides — never undercounts,
  and reproduces the device's 91,200 bytes/frame exactly (so the reporter's GIF is ~1.75:1).
- `decodeBudgetBytes(scale:)`: 12 MiB × (1 + 0.5 × (cappedScale − 1)) → 12 MiB HD (byte-identical),
  18 MiB 4K — half the pixel-proportional growth, sized to the 4K box's extra RAM. Row worst case
  now 270 MiB on 4K (15 × 18); the LazyHStack unmount + NSCache still bound it in practice.
- Predicted for the measured GIF: 328×187 × 75 frames on 4K (2.7× pixels/frame), 270×154 × 75 on HD.
- Probe line extended (`preferred= minKept= source= budget=`); device re-read is checklist §11.
- The sim cannot exercise the real decoder (no GIF-covered tile on the sim account's Home; probe
  armed via `simctl spawn defaults write` + test06/test22 walk produced zero `[GifDecode]` lines) —
  the mirror tests + the macOS ImageIO stride script are the automated evidence; §11 is the manual.

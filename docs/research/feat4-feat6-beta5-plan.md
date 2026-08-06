# FEAT-4 (Localization) + FEAT-6 (All-Debrid) — beta.5 implementation plan

Planned 2026-07-24. Scouted by 2 Haiku explore agents + All-Debrid API docs fetch.
Companion context: `NuvioMobile/Docs/badges-debrid-streampicker-scout.md` (debrid stack, 2026-07-06).

**Recommended order: FEAT-6 first** (small, isolated, shared-Kotlin + framework rebuild),
**then FEAT-4** (touches most Swift files, and its final catalog pass will also capture any
new FEAT-6 strings). Separate branches, both land on the beta.5 track.

---

## FEAT-6 — Direct All-Debrid integration (u/Ginosaure)

### Current state

- Provider registry `shared/.../features/debrid/DebridProvider.kt:29-87` has **TorBox,
  Premiumize, Real-Debrid** (Real-Debrid `visibleInUi = false`, ApiKey-only). No All-Debrid
  code anywhere in the repo or upstream `cmp-rewrite`.
- The whole stack is shared KMP: `DebridApiClients.kt`, `DebridApiModels.kt`,
  `DebridProviderApis.kt`, `DebridFileSelectors.kt`, `DirectDebridResolver.kt`,
  `DebridSettingsRepository.kt`. Storage is per-platform
  (`DebridSettingsStorage.apple.kt:240-248` + `.android.kt` key mapping).
- tvOS settings UI (`iosApp/NuvioTV/Screens/DebridViewModel.swift`) auto-lists
  `DebridProviders.visible()` and already implements both device-code polling and manual
  key entry — **a new provider appears in the UI with zero Swift changes.** Android
  Compose settings page likewise auto-includes it.

### All-Debrid API facts (docs.alldebrid.com, fetched 2026-07-24)

- Base `https://api.alldebrid.com/v4` (some endpoints `/v4.1`), JSON
  `{status: success|error, data}`. Rate limit 12 req/s, 600/min. Since Jan 2025 no
  agent-name parameter required.
- **PIN flow** (maps 1:1 onto the existing DeviceCode auth pattern):
  `GET /v4.1/pin/get` → `{pin, check, user_url}`; poll `POST /v4/pin/check` until user
  approves → returns permanent apikey. ~600 s expiry. Plus plain apikey auth
  (`Authorization: Bearer`).
- **Magnet resolve**: `POST /v4/magnet/upload` (magnet or bare infoHash → id +
  `ready` bool) → `POST /v4.1/magnet/status` (statusCode 4 = Ready) →
  `POST /v4/magnet/files` (file tree with links) → `POST /v4/link/unlock` for the
  direct-download URL.
- ⚠️ **No standalone cache-check endpoint** — All-Debrid removed instant-availability
  checks; cache status is only revealed by `ready` after actually uploading the magnet.

### Design decisions (proposed)

| Decision | Choice | Why |
|---|---|---|
| Auth | DeviceCode (PIN flow) + manual key fallback | Identical UX to TorBox/Premiumize on TV; PIN flow is exactly the existing pattern |
| Capabilities | `ClientResolve` + `LocalTorrentResolve` | Click-time keyless-addon resolve works (upload → files → unlock) |
| `LocalTorrentCacheCheck` | **Omit** | No bulk cache endpoint; annotating 44 sources would mean 44 magnet uploads (abusive, rate-limited). Consequence: no "Instant" badge pre-annotation for AD — rows still resolve on click, cached magnets return `ready` immediately |
| CloudLibrary | Defer | Keep beta.5 scope minimal; AD magnet list could back it later |
| Cleanup | Delete uploaded magnet after link fetch (`magnet/delete`) — optional, decide during impl | Avoid cluttering the user's AD dashboard |

### Work items

1. **Provider + API client + models + provider API** (shared commonMain):
   `DebridProvider.kt` (define + register), `DebridApiClients.kt` (`AllDebridApiClient`:
   pin/get, pin/check, user validate, magnet upload/status/files, link/unlock),
   `DebridApiModels.kt` (DTOs), `DebridProviderApis.kt` (`AllDebridProviderApi`:
   validateApiKey, startDeviceAuthorization, redeemDeviceAuthorization,
   resolveClientStream, local torrent resolve), `DebridFileSelectors.kt` (video-file pick
   from the files tree), `DirectDebridResolver.kt:228-242` (local-resolve switch case).
   Mirror the TorBox implementation end-to-end.
2. **Storage keys**: `DebridSettingsStorage.apple.kt` + `.android.kt` provider-key mapping.
3. **Rebuild SharedCore framework** (memory: tvos-sharedcore-framework-build), build
   NuvioTV. Watch the KMP enum-bridging gotcha (lowercase entry names in Swift).
4. **Verify in sim** (no account needed): All-Debrid row appears in Settings → Debrid;
   PIN screen shows code + URL and polls; bogus manual key → validation error;
   torrent row click with no key → MissingApiKey toast.
5. **Full resolve verification — needs an All-Debrid account** (open decision below).

### Verification gap — decision for Christian

You don't appear to have an All-Debrid account. Options:
- **(a)** 7-day free trial or cheap sub (~€3/mo) → verify resolve end-to-end yourself.
- **(b)** Ship auth-flow-verified-only in beta.5 and ask u/Ginosaure (the requester, has
  AD) to confirm resolve — frame it in the release notes as "All-Debrid support, please
  confirm". Lower cost, slower loop, small risk of shipping a broken resolve path.
- Recommendation: **(a)** — resolve paths have burned us before (BUG-9), and the trial is free.

---

## FEAT-4 — Localization (u/mrStevenx3, u/Ginosaure — 2 independent requests)

### Current state — much better than expected

- tvOS target: 71 Swift files, ~19.5k lines, **~158 user-facing literals** (113 `Text("`,
  33 `Label("`, 11 `Button("`, 1 `.navigationTitle(`) plus an unknown tail of
  interpolations/String-typed text. No catalogs, `knownRegions = (en, Base)` only.
- **The shared module already has a localization seam built for exactly this**:
  `shared/.../core/i18n/StringProvider.kt` — a `StringKey` enum (~215 keys, mirroring
  Compose Resources ids 1:1) + `LocalizedStrings.provider` holder. Doc comment: *"tvOS
  leaves it null and uses fallbacks"* — i.e. tvOS goes localized by **installing a
  provider at startup**. All shared-emitted text (debrid toasts, month names, Trakt/
  collections errors, media-type labels…) routes through it already.
- **The phone app ships 22 locales** in `composeApp/src/commonMain/composeResources/`
  (~1,900 translated strings each): fr 1925, it 1938, es 1889, de 1215, pt, pt-BR, nl,
  pl, ja, tr, vi, el, he, hu, cs, sk, ro, bg, nb, id/in. Every StringKey id already has
  professional-quality translations sitting in those files. Plus the orphaned
  `Strings HR.xml.txt` (Croatian, 1859 strings) at repo root.
- SwiftUI `Text("literal")` is `LocalizedStringKey`-backed: with a String Catalog and
  compiler extraction enabled, the existing literals auto-populate the catalog at build
  time — most of the 158 need **no code change**.

### Strategy

Two string populations, two mechanisms:

**A. Shared-emitted strings (free translations, all langs):**
1. Implement `SharedStringProvider` in Swift; install into `LocalizedStrings.provider`
   at app startup. Maps `StringKey` → `NSLocalizedString(key.name, table: "Shared")`,
   formats positional args.
2. Write a one-shot Python harvest script: for each target locale, read the
   composeResources `strings.xml`, extract the ~215 StringKey ids, **convert Android
   format specifiers (`%1$s`, `%d`) to iOS (`%1$@`, `%lld`)**, emit `Shared.xcstrings`.
   Deterministic — no model tokens per language.

**B. tvOS-native Swift strings:**
1. Add `Localizable.xcstrings` to the NuvioTV target; pbxproj: `knownRegions` + catalog
   reference + `SWIFT_EMIT_LOC_STRINGS = YES`.
2. Sweep the 71 files for **non-literal** user-facing text (String-typed vars, ternaries,
   concatenation, alert strings) → convert to `String(localized:)`. Literals stay as-is.
3. Build → catalog auto-populates. Then translate:
   - First pass, free: exact-English-match against the mobile `values/strings.xml` ids →
     harvest existing translations (Settings/labels overlap heavily).
   - Remainder (~100–150 keys × language): machine-translate with terminology seeded
     from the mobile files (Addons, Debrid, Continue Watching…), one agent per language.

### Language scope (recommendation)

Ship **fr, es, de, it** in beta.5 (requester languages + thread demographics). The
harvest makes shared strings nearly free for all 22, but declaring a locale whose tvOS
chrome is untranslated gives a half-English UI — expand after beta.5 once the pipeline
is proven. (de mobile coverage is partial at 1215/1988 — English fallback per-string
is fine in beta.)

### Work items

1. Infra: catalog + pbxproj + `SharedStringProvider` + install hook (careful, fragile).
2. Harvest script + generate `Shared.xcstrings` for fr/es/de/it.
3. Non-literal sweep across 71 files (biggest: MPVPlayerView 2019 ln, SettingsView 1728
   ln w/ 35 Texts, DetailView 795 ln; batch by screen cluster).
4. English-match harvest + machine-translate remainder into `Localizable.xcstrings`.
5. Verify: build with `-AppleLanguages (fr)` etc.; sim screenshot sweep (Home, Settings,
   Detail, StreamPicker, player OSD) per language; check 10-ft truncation/overflow;
   u/Ginosaure as French reviewer in the beta.5 thread.

### Known wrinkles

- Interpolated `Text("Found \(n) sources")` auto-extracts as format keys — fine; but
  plural handling needs `^[n](inflect: true)` or explicit variants only where it matters.
- Locale selection follows the Apple TV system language — no in-app picker in scope
  (matches mobile behavior).
- The BUG-9 empty state and any FEAT-6-new strings must be in the final catalog pass —
  another reason FEAT-6 lands first.

---

## Execution + model assignments (token plan)

| # | Task | Model | Rationale |
|---|---|---|---|
| 0 | Scouting (done) | 2× Haiku explore | ~147k subagent tokens total |
| F6-1 | Shared Kotlin All-Debrid impl (items 1–2) | **Sonnet agent** | Pattern-mirroring TorBox; well-mapped touch list |
| F6-2 | Diff review of F6-1 | **Fable (main)** | Resolver switch + auth edge cases are the risk |
| F6-3 | Framework rebuild, build, sim verify | **Fable (main)** | Established workflows, mostly Bash/sim driving |
| F4-1 | Catalog + pbxproj + SharedStringProvider | **Fable (main)** | pbxproj edits are fragile; small volume |
| F4-2 | Harvest script + xcstrings generation | **Sonnet agent** | Mechanical scripting, deterministic output |
| F4-3 | Non-literal string sweep | **2–3 Sonnet agents** (parallel, batched by screen cluster) | Mechanical but code-modifying; Haiku too risky |
| F4-4 | MT of remainder | **4 Haiku agents** (one per language, terminology-seeded) | Short UI strings w/ glossary; Sonnet spot-check on fr (requester-visible) |
| F4-5 | Per-language sim verification | **Fable (main)** | Screenshot judgment calls |

Rough shape: FEAT-6 ≈ one session; FEAT-4 ≈ one to two sessions.

## Open decisions

1. **All-Debrid test account**: trial/sub (recommended) vs. tester-verified via u/Ginosaure.
2. **beta.5 language set**: fr/es/de/it (recommended) vs. all 22 mobile locales.
3. FEAT-6 magnet cleanup (`magnet/delete` after unlock): decide during implementation.

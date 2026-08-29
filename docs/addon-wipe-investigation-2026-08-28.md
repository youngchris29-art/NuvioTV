# Addon-wipe investigation — 2026-08-28

**Reporter:** u/mrStevenx3 (Reddit DM, 2026-08-28). Clean install of beta.15 (build 113),
QR sign-in to his Nuvio account. Launch #1: all addons visible. Closed and reopened the app:
**all addons deleted — locally AND on his Nuvio account — except Cinemeta.** Photo confirms the
Addons page with only `https://v3-cinemeta.strem.io/manifest.json` installed.

**Status: ROOT CAUSE IDENTIFIED (code-read confirmed on released `c37d4784`; not yet reproduced live).**

## Mechanism — a three-part compound

### 1. The Cinemeta seed fires on a not-yet-hydrated empty state

[`HomeViewModel.swift:477-485`] `onAddonsChanged` — when the addon state is empty and `didSeed`
is false, it calls `AddonRepository.addAddon(cinemeta)`. There is **no auth check and no
"has the first server pull happened" check**. On a clean install + sign-in, local `AddonStorage`
is empty, so `initialize()` leaves the state empty and the FlowWatcher replay delivers that empty
state → the seed fires while the account's real addon list is still in flight.

### 2. `addAddon` → `pushToServer()` is an unguarded full-replace

[`AddonRepository.kt`] `pushToServer()` snapshots `_uiState` and calls the `sync_push_addons`
RPC, which **replaces the account's whole addon set**. `pulledFromServer` exists but is **never
consulted before pushing** — so a push composed from a never-hydrated state (= just the seeded
Cinemeta) replaces the account's full list with `[Cinemeta]`.

### 3. beta.15 moved the addons pull from 1st to 4th in the ordered sync — this flipped the race

- beta.14.5 (`386eabfd`): `runOrderedProfileSync` ran **Addons first** — the pull essentially
  always applied server state before the seed's push could land.
- `3cfbe086` (sync-reliability port, 08-24): moved ProfileSettings + ProviderCredentials ahead
  of Addons.
- `670583d6` (BUG-75, 08-26): inserted TrackingSourceSettings ahead as well → Addons is now
  behind **three sequential network RPCs**.

The seed path needs one manifest fetch (~100-400ms) + 500ms debounce from Home-appear.
The pull path needs three sequential Supabase RPCs + the addons SELECT. The seed now
reliably beats the pull's *state application* on real hardware.

### Steven's exact timeline, explained

**Launch #1 (clean install + sign-in):**
1. Profile entry → `pullAllForProfile` starts (3 RPCs before addons).
2. Home appears → empty replay → seed → `addAddon(Cinemeta)` appends to still-empty state →
   `persist([Cinemeta])` → debounced push payload captured = `[Cinemeta]`.
3. Addons SELECT reads the server *before* the push lands → returns his full list →
   `pullFromServer` applies + persists the full list → **he sees all his addons** ✓
4. The seed's push lands *after* the SELECT → **server is now `[Cinemeta]`** — silently.

**Launch #2:**
1. Local storage has the full list → no seed, Home looks fine briefly.
2. Full sync → addons pull returns `[Cinemeta]` → `pullFromServer` **replaces** local state and
   persists it. The preserve-local guard (`pullFromServer` lines ~180-206) only triggers when the
   server list is completely **empty** — one Cinemeta row defeats it.
3. **"It deleted all my add-ons (even on my Nuvio account), except Cinemeta!"** — exact match.

### Why the device pass missed it
The device fixture (FA87) and all sim fixtures are long-signed-in with populated local addon
storage — the seed can never fire there. The vulnerable path is exactly clean-install + sign-in,
which no gate covers.

## Blast radius
- Every **clean install + sign-in** on beta.15 risks silently wiping the account's addon list.
- Same race on any first sign-in on a new device, and after any local-storage wipe.
- tvOS-only (the seed lives in native `HomeViewModel.swift`); mobile Compose has its own flow.

## FIX BUILT 2026-08-28 — submodule branch `claude/addon-wipe-fix`, commit `8f4e92e4` (unpushed, merge decision owed)

Implements directions 1+2 below exactly (direction 3 not taken — the guard makes the order
irrelevant for this bug): `serverPullSettled` StateFlow + `seedingAllowed()` +
`pushToServer()` unhydrated-guard in `AddonRepository`; seed gate + settled-retry watcher in
`HomeViewModel`; 10 pure-function tests (`AddonSyncGuardsTest`). Codex settled round 3:
P1 fixed (inner `runCatching` swallowed CancellationException — a profile-switch cancel could
mark the new profile's gate settled; now rethrown), P2 declined-documented (pre-hydration user
mutations are non-authoritative by design — that shape IS the bug; fresh accounts still migrate
local→server via the existing migration branch). Gates: jvm 542 / tvOS-native 554 / sim build
green. Not yet on a device; not yet released. Steven must stay on 14.5 until a build ships.

## Sibling audit (2026-08-28, same session) — the same unguarded full-replace shape elsewhere

Ranked; #1 FIXED (below), #2-#5 still follow-up work:
1. **`ProfileSettingsSync` — FIXED 2026-08-28, commit `ca9f2cf6` on `claude/addon-wipe-fix`.**
   `completedInitialPull` token gate mirroring `TrackingSourceSettingsSyncService`: settle =
   applied / remote-matches-local / legacy-seeded / provably-empty namespace (fresh accounts must
   settle or they could never push); decode-failure, features-less, thrown-fetch, and inconclusive
   (thrown) legacy lookups do NOT settle. Settle token captured at pull start, revalidated against
   the live (user, profile) at mark time AND under the mutex before any deferred push. A gated
   emission is remembered by signature and re-pushed token-pinned after settle; an edit the remote
   apply overwrote is deliberately not resurrected (in-code rationale — restoring a captured
   pre-settle payload would re-push unhydrated defaults, the exact wipe shape). Codex settled
   round 8 — its rounds 4-7 found five real races in the gate itself (mark-time identity capture,
   profile-axis validation, deferred-push identity pinning, settle/record collector race,
   stale-echo skip-signature), all fixed; +6 pure-function tests (`ProfileSettingsPushGateTest`).
   Gates: jvm 548 / tvOS-native / sim build green.
2. **`HomeCatalogSettingsSyncService` — wipe hole.** `completedInitialPull`/`cachedSharedSettings`
   never cleared on account wipe (no `clearAccountState()`); sign-out→sign-in same user/profile
   leaves the guard satisfied over freshly-emptied local state. Also explains (non-destructively)
   Steven's "catalogs auto-added to my home page": `normalizePreferences()` auto-creates
   enabled=true rows per installed addon's catalogs, which ride the next user push into the blob.
3. **`CollectionSyncService` — no hydration guard at all**, and its pull swallows failures so the
   ordered sync records success. One user edit pre-hydration full-replaces the collections blob.
4. **`TvOsPluginRepository.pushToServer` — no guard of any kind** (no auth/pulled/profile check);
   also hard-codes `enabled=true` and omits `putSyncOriginClientId()` (no echo suppression).
5. **`ProfileRepository.pushProfiles` — no `isLoaded` precondition** (low: needs a user profile
   edit after a swallowed pull failure).
Safe models confirmed: `TrackingSourceSettingsSyncService` (the pattern to copy),
`ProviderCredentialSync` (baseline-diff), the per-item delta adapters (library/watched/progress).

## Fix directions (as originally proposed)
1. **Deep fix (must-have):** `AddonRepository.pushToServer()` refuses to run for authenticated,
   non-anonymous sessions while `!pulledFromServer` — a full-replace push must never be composed
   from a never-hydrated state. (Consider the same guard for `persist()` clobbering local from a
   never-hydrated state, and audit sibling repositories — HomeCatalogSettings, collections,
   plugins — for the same unguarded-full-replace shape.)
2. **Seed gate:** `HomeViewModel.onAddonsChanged` should not seed when signed in until the first
   addon pull has settled (success OR definitive failure) — e.g. expose/await
   `pulledFromServer`/a sync-settled signal instead of seeding on first empty replay.
3. **Optional:** restore Addons earlier in `runOrderedProfileSync` (it was first for a reason);
   at minimum document that the seed race is load-bearing on this order.

## Recovery for affected users
A 14.5 device that still has the full local list will push it back up on **any addon mutation**
(toggle an addon off/on — full-replace works in our favor here). Steven's 14.5 install should
restore his account list this way; confirmed advice sent was "re-add on 14.5", the toggle trick
is cheaper.

## Related but separate (from the same DM thread, still open)
- Removing auto-added catalogs from the menu → **big white screen** (likely HomeCatalogSettings
  removal crash — not investigated yet).
- New Settings menu: icons overlap text.
- His earlier beta.15 regression list (top bar, doubled hero, poster-text overlap "worse") —
  contradicts the device pass; needs his clean-install video.

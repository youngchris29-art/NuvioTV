# Upstream port plan — 2026-08-30

## Upstream movement

`upstream/cmp-rewrite` (`github.com/NuvioMedia/NuvioMobile`) **moved** again:
`6318f0e4` → `e68cbb08` (fetched fresh today). Seven real commits plus a
self-merge:

- `354d14ee` i18n(el): translate sign-in with link strings (nosvasedis, 2026-08-29 12:44 +0300)
- `f338e560` merge PR #1813 (i18n/el-auth-link) — no additional content
- `793c665c` feat(store): automate sideload source updates (tapframe, 2026-08-29 17:44 +0530)
- `501c61d9` fix(tmdb): use multiplatform map insertion (tapframe, 2026-08-29 18:00 +0530)
- `0b97ec4d` bump version
- `c52cb381` chore(store): publish 0.4.12
- `b86932b9` feat(player): apply member gradients to player accents (tapframe, 2026-08-29 20:28 +0530)
- `e68cbb08` fix(android): adjust launcher icon scale (tapframe, 2026-08-29 21:49 +0530)

All seven read in full (`git show`, not just messages). None require a tvOS
port.

## Commit-by-commit

**`354d14ee` — i18n(el) sign-in-with-link strings.** Ten new Greek strings in
`composeApp/src/commonMain/composeResources/values-el/strings.xml` for the
mobile "sign in with a code" flow added by `388e613c` (assessed 2026-08-29 as
not applicable — tvOS's `TvLoginRepository.kt` QR flow already covers this).
Pure translation follow-up to an already-not-applicable feature. No action.

**`793c665c` — store automation.** New GitHub Actions workflow
(`update-store-source.yml`), a Python script (`scripts/update-store-source.py`),
and `store.json` for automating Android sideload-source updates, plus a tweak
to `android-release.yml`. Build/release tooling for the Android sideload
channel — no equivalent concept on tvOS (App Store / TestFlight only). No
action.

**`501c61d9` — TMDB multiplatform map insertion, already independently fixed
in the fork.** Upstream swaps `titles.putIfAbsent(id, text)` for
`titles.getOrPut(id) { text }` in
`composeApp/.../tmdb/TmdbMetadataService.kt`'s `englishDiscoverTitlesById`/
`englishCreditTitlesById` — `putIfAbsent` is JVM-only and doesn't exist in
common Kotlin stdlib. Checked
`shared/src/commonMain/kotlin/com/nuvio/app/features/tmdb/TmdbMetadataService.kt`
(the fork's own shared/ port of this logic, landed in the 2026-08-28
upstream-batch6 CJK-fallback port): it **already avoids `putIfAbsent`**, with
an explicit comment at line 1640/1666 — *"Fork deviation: `MutableMap.putIfAbsent`
is JVM-only — it does not exist in the common-stdlib..."* — because `shared/`
targets iOS/tvOS natively via KMP and would have failed to compile otherwise.
The fork fixed this before upstream did. No action needed;
**upstream-report candidate** (11th, joining the three already unfiled from
2026-08-26/28 — see CLAUDE.md open items).

**`b86932b9` — player member-gradient accents.** Applies membership-tier
gradient theming (`ThemeColors`, `accentBrush()`) to the parental-guide
overlay accent bar and the player progress-track fill in
`composeApp/.../player/{ParentalGuideOverlay,PlayerControls}.kt`. This is a
follow-on to **Supporter perks v1**, which Christian parked as a backlog item
on 2026-08-20 (park decision: "build nothing until it's re-raised"). Entirely
`composeApp/`, nothing in `shared/`. No action — stays parked, but flag that
upstream keeps extending this feature (now touches the player, not just
profile/settings surfaces), for whenever it's re-raised.

**`0b97ec4d` / `c52cb381` — version bump + store publish (0.4.12).** No
content. No action.

**`e68cbb08` — Android launcher icon scale.** 70 binary `.webp` mipmap assets
resized, Android-only. No action.

**`f338e560`** — merge commit for the i18n PR, no additional diff.

## Everything else: re-verified against current `shared/` state

No new upstream content landed in `shared/`, so the two 2026-08-28 batches
still flagged **device-pass owed** in CLAUDE.md were spot-checked again for
regression, not re-audited in full (already confirmed present two runs
running):

- `claude/upstream-batch6` — `InAppYouTubeExtractor.kt` still has
  `PREFERRED_SEPARATE_CLIENT = "visionos"`; `TmdbMetadataService.kt` still has
  `aggregate_credits`.
- `claude/subtitle-engine` — `grep -rl AddonSubtitleStartupMode shared/src`
  still empty.

No regressions. Device passes remain a manual QA step, not a coding task, so
not repeated as an action item here.

## Action items for Claude Code

**None.** Nothing that landed upstream today applies to tvOS. One new
upstream-report candidate logged (`501c61d9` vs. the fork's pre-existing
`getOrPut` fix — see CLAUDE.md).

Untouched/carried, no change:
- **[LOW, spot-check only]** Player pause-description staleness — verify next
  time the tvOS player/pause-overlay UI gets touched.
- **[PARKED/DEFERRED by product decision]** Supporter perks v1 (upstream keeps
  building this out — now includes player accents via `b86932b9`), subtitle
  minimum font size — no action until re-raised.

## Verification method

- `git fetch upstream` in `NuvioMobile/`, diffed `6318f0e4..upstream/cmp-rewrite`.
- Read every new commit's full diff (`git show <sha>`) rather than trusting
  commit messages — including the two that looked like one-line/binary
  changes.
- Grepped/read current `shared/` file contents (`TmdbMetadataService.kt`
  around the CJK-fallback functions) to confirm the fork's own fix predates
  and covers upstream's `501c61d9`, rather than assuming from the commit
  message alone.
- Spot-checked (grep, not full re-audit) that the two 2026-08-28 batches
  still flagged device-pass-owed show no regression in current `shared/`.

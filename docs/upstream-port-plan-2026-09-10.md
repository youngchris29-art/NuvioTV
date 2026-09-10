# Upstream port check — 2026-09-10

Upstream (`NuvioMedia/NuvioMobile`, branch `cmp-rewrite`) moved: `83c409c4` → `e3779428`, 1 commit, no merges. Read in full via `git show`.

## Submodule pointer check

No drift. Outer pointer, `origin/tvos-shared-extraction`'s fetched tip, and this sandbox's local submodule checkout all agree at `c41fb67c` (tag `tvos-v0.3.0-beta.18-rc8-...`, build 124).

## Zero action items this run

- **`e3779428`** "chore(store): publish 0.4.15" — `store.json` only (10 lines added), a version-bump/store-publish commit with no app code touched.

## Carried open item (unchanged from 2026-09-09)

### [MEDIUM] Disable Play button when no playback source is available

Still unbuilt as of this check — re-verified `grep -rn "canPlay\|hasCompatiblePlaybackSource\|PlaybackAvailability\|isPlayEnabled\|playDisabled\|canStream"` against `iosApp/NuvioTV/` still returns nothing, and `DetailView.swift`'s Play button still has no `.disabled()` gating. Full writeup, port shape, and file-level detail unchanged — see `docs/upstream-port-plan-2026-09-09.md`. Summary: upstream commit `972109f9` added `PlaybackAvailability.kt` (composeApp) that pre-computes whether a title has any playable source (enabled addon manifest support, enabled JS plugin scraper, embedded stream, or matching download) and greys out/disables Play instead of letting the user land on an empty Streams screen. Every dependency (`AddonRepository`, `MetaDetailsRepository`, `DownloadsRepository`, tvOS's own `TvOsPluginRepository`) already exists in `shared/` — only the Compose `remember`/`collectAsStateWithLifecycle` wrapper has no tvOS equivalent needed. Ready for Claude Code to pick up; not built this run.

## Verification note

The single new commit was read via full `git show` diff (not the commit-message title). Submodule pointer re-verified by fetching both `upstream/cmp-rewrite` and `origin/tvos-shared-extraction` fresh rather than trusting the prior note.

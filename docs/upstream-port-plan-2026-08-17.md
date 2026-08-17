# Upstream port check — 2026-08-17

## Summary

`upstream/cmp-rewrite` (`NuvioMedia/NuvioMobile`) advanced from `cc20e716` to `d2db97a9` — 12 new commits, all localization or Android-only:

```
d2db97a9 Merge PR #1711 — Add Arabic translation
43616480 Merge PR #1733 — Update Bulgarian translations + new strings
2b09061f Merge PR #1745 — fix/mpv file uri
f257cbe4 fix(android): render local mpv files compatibly
73e120e3 fix(android): convert file URIs before loading media
a69de422 Update Bulgarian translations + new strings added
42b8dd4a Add Arabic locale to Android config
3c0ab547 Update AppLanguage.kt (adds ARABIC entry)
1a3f15e3 / c00b3152 / f4f09927 / cf672ac3  Add Arabic translation (values-ar/strings.xml, iterated)
```

`upstream/copilot/refactor-project-structure` unchanged (`cbc9fc4f`) — still stale/abandoned. `upstream/simkl` re-checked: still fully merged into `cmp-rewrite` (merge-base == simkl HEAD `e4911b77`), zero unique commits.

Fork state at check time: outer `main` HEAD `1767618` (native player swipe-down panel docs), submodule `NuvioMobile` HEAD `35ae5d91` on `tvos-shared-extraction`, pinned pointer matches actual HEAD — no drift.

## Verification: did the 2026-08-16 open items land / change?

No — all three remain open and unchanged (none of today's 12 commits touch the relevant files):

1. **Self-hosted server discovery** (upstream `ddc28dc8`) — still MEDIUM, still a product-decision item, still zero `shared/` footprint on upstream's side. No new upstream activity on this since 08-16.
2. **Subtitle minimum font size** (upstream `d50f84fc`) — `shared/.../SubtitleAudioModels.kt` still unbounded `fontSizeSp: Int = 18`. Unchanged.
3. **TMDB Discover exclusion filters — UI half** (upstream `0fc4616b`) — `CollectionsUI.swift` still browse-only by design. Unchanged.

## New this check: everything is mobile/Android-only, one small exception

**Arabic + Bulgarian localization** (upstream `1a3f15e3` et al., `a69de422`) — entirely in `composeApp/src/commonMain/composeResources/values-{ar,bg}/strings.xml` and `composeApp/src/androidMain/res/xml/locale_config.xml`. This is Compose Multiplatform resource infrastructure that tvOS does not use — tvOS's native SwiftUI frontend has its own separate localization system, a single `iosApp/NuvioTV/Localizable.xcstrings` String Catalog, currently populated for only 5 locales (de, es, fr, it, vi) as a deliberate, hand-maintained subset — not a 1:1 mirror of composeApp's ~21 locales. Confirmed via grep: no in-app language-picker screen on tvOS consumes a language enum at all (`AppearanceSettingsPane.swift` has no such control). **No action.**

**mpv file-URI fix** (upstream `73e120e3`/`f257cbe4`) — both commits touch only `PlayerEngine.android.kt` (an Android `actual`), fixing local-file playback quirks specific to Android's mpv integration. tvOS's native player path (`iosApp/NuvioTV` native AVPlayer/custom engine, per the recent info-panel work) doesn't share this file. **No action.**

**One loose end worth a mechanical fix regardless:** upstream's `composeApp/.../settings/AppLanguage.kt` gained an `ARABIC("ar", ...)` entry (`3c0ab547`). This fork extracted a Compose-free twin of that enum into `shared/src/commonMain/kotlin/com/nuvio/app/features/settings/AppLanguage.kt` during `tvos-shared-extraction` (code-only, no `labelRes` — the Compose-resource binding lives separately in `composeApp/.../AppLanguageLabels.kt`, kept on the composeApp side). That shared enum is currently missing `ARABIC`. It's consumed by `TvOsThemeSettingsStore.kt`/`ThemeSettingsStore.kt`/`ThemeSettingsRepository.kt` as part of a bundled settings model, but since tvOS has no language-picker UI, this drift is inert today — it doesn't block anything, it's just definitional drift between fork and upstream that'll compound with each new upstream locale.

## Action items for Claude Code

1. **[LOW / mechanical, no urgency] Sync `shared/AppLanguage.kt` enum with upstream.** Add `ARABIC("ar")` to `shared/src/commonMain/kotlin/com/nuvio/app/features/settings/AppLanguage.kt` to match upstream's `composeApp/.../AppLanguage.kt`. If a corresponding `composeApp/.../AppLanguageLabels.kt` entry is required to keep that `when` exhaustive on the fork's composeApp side (unused by tvOS but still compiled as part of the KMP module), add `AppLanguage.ARABIC -> Res.string.lang_arabic` there too — that needs the `values-ar/strings.xml` resource file ported alongside it (upstream's is 2160 lines, straight copy). Since tvOS itself has no language-picker UI, this is pure hygiene — safe to batch with the next unrelated shared/ touch rather than doing it standalone.
2. **[MEDIUM / decision needed, carried forward] Self-hosted server discovery** (upstream `ddc28dc8`) — see 2026-08-16 doc for the full port plan. No change this run; still awaiting Christian's scope decision.
3. **[LOW / decision needed, carried forward] Subtitle minimum font size** (upstream `d50f84fc`) — decide tvOS's own floor next time player styling gets attention. `iosApp/NuvioTV/Screens/SubtitleVTT.swift`.
4. **[LOW, carried forward] TMDB Discover exclusion filters — UI half** (upstream `0fc4616b`) — new tvOS SwiftUI exclusion controls needed; shared query builder already wired (`7dac9a67`).

## Next scheduled check

Re-fetch `upstream/cmp-rewrite`, diff past `d2db97a9`. Backlog unchanged in priority order: self-hosted server discovery (item 2, needs scope decision — highest value), subtitle-floor decision (item 3), TMDB exclusion-filter UI half (item 4), AppLanguage enum sync (item 1, trivial, do opportunistically). Today's upstream activity was unusually light and mobile/Android-specific — no new tvOS-relevant gaps opened.

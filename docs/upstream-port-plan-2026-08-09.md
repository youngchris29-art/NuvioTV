# Upstream port check — 2026-08-09 (scheduled)

## Headline: zero actionable items. Nothing to port this run.

Fork state checked this run: outer repo `main` at `7cc4259` (docs-only commits since last check — draft/announcement tracker updates, no code). Submodule `NuvioMobile` HEAD `f9e4ae56` on `tvos-shared-extraction`, matches outer repo's pinned submodule pointer — clean, in sync.

`upstream/cmp-rewrite` (NuvioMedia/NuvioMobile) moved `3ac0a14c` → `ca7e54a4` (10 commits since 2026-08-08 — busier than the prior two 0/1-commit days). **Every commit in the range is translation/locale-only**, confirmed via full diffstat across the whole range:

```
composeApp/src/androidMain/res/xml/locale_config.xml       |   2 +-
composeApp/.../composeResources/values-el/strings.xml      | 209 +++++++++++++++------
composeApp/.../composeResources/values-nl/strings.xml      | 177 +++++++++++++++++
composeApp/.../composeResources/values-sk/strings.xml      |  78 ++++++++
4 files changed, 405 insertions(+), 61 deletions(-)
```

Breakdown: Greek (el) translation completion + Simkl-string fixes (3 commits, incl. one Copilot-autofix touch-up), Dutch (nl) string additions/reorder (1 commit), Slovak (sk) new Simkl strings (1 commit), plus the merge commits tying those PRs in. `locale_config.xml` only registers the new locale entries for Android.

**Why this is fully N/A for tvOS:** all four touched files live under `composeApp/src/*/composeResources/` — Compose Multiplatform's string-resource system, which the tvOS fork does not use at all (native SwiftUI app with its own `.strings`/localization pipeline, per [[nuvio-tvos-remaining-scope]]). Nothing in `shared/src/commonMain` changed. No action needed, no localization parity work implied — tvOS's Simkl feature strings are already handled independently in the Swift layer.

`upstream/copilot/refactor-project-structure` still stale at `cbc9fc4f` (last upstream commit unchanged for weeks) — confirmed abandoned again, no action.

---

## Action items this run

None.

---

## Checked, not applicable

- Full 10-commit range `3ac0a14c..ca7e54a4` on `cmp-rewrite` — 100% i18n/locale strings (Greek, Dutch, Slovak), zero `shared/` or logic changes. See breakdown above.
- `copilot/refactor-project-structure` — no new commits, still abandoned.

---

## Next scheduled check

Re-fetch `cmp-rewrite`, diff past `ca7e54a4`. No queued follow-up work from this run — clean slate.

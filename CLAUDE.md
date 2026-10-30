# Nuvio tvOS — Claude Code rules

History, run logs, releases and open action items: `docs/status.md` (moved out 2026-10-19). Daily upstream check: `docs/upstream-check-latest.md` (tracked, overwritten daily); its dated reports stay local. Keep this file rules-only.

## Repo layout
- Outer repo (this folder): fork wrapper on `main` — docs, scripts, the `NuvioMobile` submodule.
- `NuvioMobile/`: the KMP + native tvOS app on `tvos-shared-extraction` (`origin` = `youngchris29-art/NuvioMobile`; `upstream` = `NuvioMedia/NuvioMobile` `cmp-rewrite`, diffed daily by a scheduled task).
- `NuvioMobile/shared/`: Compose-free Kotlin; upstream ports land here. `NuvioMobile/iosApp/NuvioTV/`: SwiftUI tvOS frontend.

## Standing instructions
The shared rules (no sends without a go, no cuts unless told, ask before planning, model delegation) live in `~/.codex/AGENTS.md`, loaded globally by both tools. Project-specific additions:
- Comms drafts go in `docs/comms-*.md`, marked NOT SENT (local only, never tracked).
- `docs/` is gitignored except an allowlist in `.gitignore` (status, the rolling upstream check, the README's two reference docs, the rig doc, the iPad release watch, `docs/design/`). Plans, reviews, specs, comms, evidence, sweeps and dashboards never enter the repo; add a tracked doc only by editing the allowlist. `marketing/` lives at `~/Claude/Projects/nuvio-marketing` (not git). Working material removed on 2026-10-27 is archived at `~/Claude/Archive/nuvio-2026-10-27/`.
- Batch work records delegation rounds and findings in the batch doc.
- Release notes and tester DMs name every new setting and its default.

## Build and gates (in `NuvioMobile/`)
- Kotlin: `./gradlew :shared:jvmTest :shared:tvosSimulatorArm64Test :composeApp:iosSimulatorArm64Test`
- Sim builds (Debug + Release): `xcodebuild -project iosApp/iosApp.xcodeproj -scheme NuvioTV -configuration Release -destination 'platform=tvOS Simulator,id=FA87E9B6-F28D-4DF9-84E4-A5A4C5DBFC4E' -derivedDataPath iosApp/build/DerivedData` (the FA87 id, never `generic/platform=tvOS Simulator`: Release has no `ONLY_ACTIVE_ARCH`, so the generic destination links x86_64 against the arm64-only SharedCore and fails; 2026-10-22).
- NuvioTVTests + UI legs on the fixture sim (`FA87E9B6-…`): `xcodebuild test -scheme NuvioTVTests` (unit) / `-scheme NuvioTVUITests -only-testing:NuvioTVUITests/<Class>` (legs) `… -derivedDataPath iosApp/build/DerivedDataUITests -collect-test-diagnostics never` (the `NuvioTV` scheme has no testables: "not configured for the test action"), Bash sandbox OFF (sandboxed: exit 70 "Failed to prevent system sleep"; without the flag UI legs hang ~10 min).
- Device build: `-destination 'platform=tvOS,id=00008110-001A6DCE0AF2201E' -derivedDataPath iosApp/build/DerivedDataDevice -allowProvisioningUpdates -allowProvisioningDeviceRegistration 'PRODUCT_BUNDLE_IDENTIFIER=$(PRODUCT_BUNDLE_IDENTIFIER_$(TARGET_NAME):default=$(inherited))' PRODUCT_BUNDLE_IDENTIFIER_NuvioTV=com.youngchris29.NuvioTV PRODUCT_BUNDLE_IDENTIFIER_NuvioTopShelf=com.youngchris29.NuvioTV.NuvioTopShelf` — the concrete Living Room destination plus `-allowProvisioningDeviceRegistration` is required since 2026-10-29: the free team's device list was empty and `generic/platform=tvOS` fails with "Your team has no devices from which to generate a provisioning profile" (xcodebuild registers the box itself with the flag). The override is mandatory: the free team cannot sign `com.nuvio.media.NuvioTV`, and without it the build installs as a second app while the rig launches the old one (2026-10-27). 7-day free-team profile; delete stale `youngchris29` profiles when it expires. Install with `devicectl device install app`, launch via `scripts/device/console.sh` or `atv.sh launch`.
- Gated = all of the above green on the tip plus the relevant UI legs, then a device pass in the Test profile.
- Keep only those three dirs plus `tvos-ipa` under `iosApp/build/`; delete one-off build dirs and `.xcresult` bundles once their gate is recorded.

## Release chain
1. Feature branch in a local clone of the submodule (never a worktree); review loop to CLEAN; gates green.
2. Fast-forward into `tvos-shared-extraction`, push, delete the branch (local + `origin`) and the clone.
3. Bump the outer pointer: `git add NuvioMobile`, commit, push outer `main`.
4. Cut only on Christian's explicit go: `scripts/cut-rc.sh beta.<n>-rc<m>` (preflight, build bump + tag, push, pointer commit, Release build, package, upload; `--preflight` checks only, `--from build|upload` resumes). Public betas: `NuvioMobile/scripts/release-beta.sh`.
5. Tester DM through the copy rule, sent only on his go.

## Device testing profile (standing, 2026-10-02)
All device testing runs in the app's **"Test" profile** ("Test 2" on the Living Room box), never the synced daily-use "Chris" profile: passes, repros, installing a tester's add-ons or collections. Name the profile before any device step; remove tester payloads afterwards. If a pass needs "Chris", say so and get his go first. Dev builds under `com.youngchris29.NuvioTV` share the account. Remote rig (`scripts/device/*.sh`, credentials in `~/.config/nuviotv-device/`): `docs/device-rig-2026-10-15.md`. Pre-flight before any pass or install: `scripts/device/ready.sh` (`--walk` adds the app/console/profile gate).

## Branch hygiene
- Outer `origin` carries `main` only. Cloud sweeps never commit or branch; delete any `claude/*` branch once it is an ancestor of `main`.
- Submodule `origin` holds `tvos-shared-extraction` and `cmp-rewrite` (stale mirror). Fork tags are `tvos-*`; never push upstream's `0.x` tags.
- Never `git worktree add`/`remove` on the submodule (`core.worktree` resolves back to `.git/modules/NuvioMobile`); a stray one is removed with `rm -rf` + `git worktree prune`. Isolated work goes in a clone `~/Claude/Projects/NuvioMobile-<task>`, landed with `git fetch <clone> <branch>:<branch>`; in a clone MPVKit is a symlink over the gitlink, so stage by explicit paths, never `git add -A`.
- Delete a side clone once its branch is fast-forwarded in. `~/Claude/Projects/NuvioMobile-ios-sideload` is not one of these: it is the standing upstream checkout for the iPad sideload (see below), detached at a release tag, never committed or pushed.
- Commit the `docs/*.md` the checks and sweeps write.

## iPad sideload (standing, 2026-10-25)
Upstream's iOS app (`NuvioMedia/NuvioMobile`, the `iosApp` scheme) runs on Christian's iPad from a side clone at `~/Claude/Projects/NuvioMobile-ios-sideload`, built with his free team and installed as `com.nuvio.media.Nuvio` (app + Downloads widget). `scripts/ios/refresh-ipad.sh` (hourly 10:00–22:00 via `~/Library/LaunchAgents/com.youngchris29.nuvio-ipad.plist`, real work at most once a day) checks out the newest release tag, re-points signing, fetches the pinned Nuvio Engine xcframework into `~/Claude/Projects/nuvio-engine` (upstream's `scripts/prepare-ios-dependencies.sh`), mints fresh 7-day profiles, builds the **full** flavor (`NUVIO_IOS_DISTRIBUTION=full`; the default `appstore` flavor has no P2P engine and shows "This stream type is not supported" on every torrent stream) and installs when a new release exists or the profile has under 2 days left. `scripts/ios/check-release.sh` watches releases, notifies, and appends notes to `docs/ios-release-watch.md` (commit it like the other check docs). Config and state: `~/.config/nuvio-ipad/` (never in git; the clone's `local.properties` is a copy of the submodule's). The iPad must be unlocked on the same Wi-Fi for the install; the job retries each hourly slot. Manual: `scripts/ios/refresh-ipad.sh --dry-run` to see the decision, `--force` to rebuild now.

## Beta-feedback sweeps (standing, rewritten 2026-10-27)
The tracker is the database of the Tester Feedback dashboard artifact `https://claude.ai/artifact/UcBu7mTfKqyiW9dnywnYXX` (`items/<ID>`, `meta/sweep`, `meta/procedure`, `log/`, `marks/`), read and written with `ArtifactData`; no files, no commits, no sweep branches. The procedure is `meta/procedure`; its editing copy is the local, gitignored `docs/beta-feedback-sweep-instructions.md` (edit, then write it back). Runs: two cloud routines (morning 12:00 UTC, evening 23:00 UTC) and the local DM check (`nuviotv-reddit-dm-check`, `scripts/reddit/fetch-dms.sh --since <meta/sweep.dm_last_checked> --summary` from this checkout; the dedicated clone is gone). The old file dashboard (artifact `0d62393a…`) is retired and never republished. No run sends a DM or posts anywhere. Interactive triage writes the same database (`updated_by: interactive`).

## Knowledge graph (graphify, standing, 2026-10-26)
`NuvioMobile/graphify-out/` (gitignored; tree-sitter code graph of the submodule, no LLM, `graphify` CLI via uv) is the first stop for any codebase question, run from the submodule: `cd NuvioMobile && graphify query "<question>"` / `explain "<symbol>"` / `path "<A>" "<B>"` / `affected "<symbol>"` (those forms are pre-allowed in `.claude/settings.json`). The PreToolUse hook there nudges toward the graph before Bash/Grep/Read/Glob and carries `GRAPHIFY_OUT=NuvioMobile/graphify-out` inline because it runs at this root; never export that variable in a shell, it breaks graphify inside `NuvioMobile/`. Same-named Swift/Kotlin symbols are refused as ambiguous: pass `<file path>::Symbol`.
- Freshness: local git hooks in the submodule (post-commit/checkout/merge/rewrite) rebuild the graph; after a fast-forward from a clone or `git pull`, run `graphify update .` in `NuvioMobile/` (free). Never `/graphify .` on this outer folder: the semantic pass over `docs/` is a paid subagent fan-out; point it at a curated subset if ever.
- Upstream port triage: before dismissing a `cmp-rewrite` hunk in `shared/`, `graphify explain "<symbol>"` lists every `composeApp`/`appleMain`/`NuvioTV` consumer (the grep-before-dismissing rule, now one call).
- Review loop and cuts: `scripts/graph-impact.sh <base-sha>` maps a batch's diff to communities; put its table in the batch doc and the review brief, and read "graph is stale" as an update reminder, not a finding.
- Labels: communities were named once by `graphify label .` (claude-cli, subscription). `--resolution` / `--exclude-hubs` change membership and invalidate labels, so re-cluster deliberately and relabel after.

## Codex review (standing, 2026-10-01)
`.claude/skills/codex-review/tools/review.sh --repo NuvioMobile --base <sha-before-the-work>` (exit 0 CLEAN / 3 findings / 2 no verdict). Run unsandboxed, never piped; loop review → fix → re-review on the same `--base` until CLEAN, documenting declines. Pass `--model gpt-5.6-terra`: the resolver's top pick `gpt-6-luna` is refused on this ChatGPT account (400 model_not_found). The account's usage limit is exhausted until 2026-11-28; while Codex is out, an Opus read-only review agent stands in.

## Copy rule (standing, 2026-09-03)
Every user-facing draft (Reddit, DMs, README/INSTALL, release notes, GitHub text) goes through SlopMonster first: lint `python3 scripts/deslop/deslop.py <file>` → rewrite to 5/5 keeping every fact → cleanse with `~/.claude/skills/slopmonster/tools/cleanse.sh` when `codex` is available (diff every hunk, restore dropped facts) → re-lint; present at 5/5 with the score. No scorer tricks; legal/DMCA and quoted third-party text are never rewritten.
- **No internal jargon in user-facing text (standing, 2026-10-30):** release notes, GitHub replies, Reddit posts and replies, README lines and tester DMs never carry tracker IDs (`BUG-`, `FEAT-`, `UX-`, `DOC-`, `POL-`), commit SHAs, tip/cut vocabulary or batch names ("Wave 4", "Direction C", "S4"). Those stay in the batch doc, `docs/status.md` and the tracker. `deslop.py` flags tracker IDs (score capped at 4/5); an `<!-- internal -->` marker in a comms file ends the scored part, so facts checks and status entries go below it.

# Upstream port plan — 2026-08-29

## Upstream movement

`upstream/cmp-rewrite` (`github.com/NuvioMedia/NuvioMobile`) **moved** for the
first time since 2026-08-27: `1b84ee47` → `6318f0e4` (fetched fresh today).
One real commit plus a self-merge:

- `388e613c` "feat(auth): add six-character login codes" (tapframe,
  2026-08-28 19:46 +0530)
- `6318f0e4` — merge commit, no additional content

## New commit: six-character mobile login codes — NOT applicable to tvOS

`388e613c` touches only `composeApp/`:

- `composeApp/src/commonMain/composeResources/values/strings.xml`
- `composeApp/src/commonMain/kotlin/com/nuvio/app/core/auth/DeviceLinkAuthRepository.kt` (new)
- `composeApp/src/commonMain/kotlin/com/nuvio/app/features/auth/AuthScreen.kt`
- `composeApp/src/commonMain/kotlin/com/nuvio/app/features/auth/DeviceLinkAuthSection.kt` (new)

Nothing under `shared/` changed, so this isn't the usual "looks
composeApp-only but shared/ is an extraction" trap — verified by reading the
new file directly. What it does: adds a "sign in with a code" option to the
**mobile/desktop email-password AuthScreen** — the app requests a 6-character
code (`start_device_login_session` RPC, `device_type: "mobile"`), the user
approves it on `nuvio.tv/link` (or `<backend>/link` self-hosted) from another
device, and the app polls/exchanges the same way TV login already does.

tvOS doesn't need this. Its own `TvLoginRepository.kt`
(`shared/src/commonMain/kotlin/com/nuvio/app/core/auth/TvLoginRepository.kt`)
already implements the superior 10-foot-UI equivalent — QR-code sign-in via
`start_tv_login_session` → `poll_tv_login_session` → `tv-logins-exchange`,
i.e. the same polling/exchange RPCs this new mobile flow reuses. The new
`start_device_login_session` RPC is a separate, additive backend entry point
for mobile-initiated codes; it doesn't replace or change anything
`TvLoginRepository` calls, so there's no backend-compatibility risk either.
**No port needed. No action item.**

## Everything else: re-verified against current `shared/` state

No other upstream content is new, so this run re-checked (by reading file
contents, not trusting prior notes) that the two big batches CLAUDE.md logged
as merged on 2026-08-28 are actually present in the submodule's current
working tree (`tvos-shared-extraction` @ `c705c7aa`):

- **Upstream 6-item batch** (`claude/upstream-batch6`) — confirmed landed:
  `InAppYouTubeExtractor.kt` uses `PREFERRED_SEPARATE_CLIENT = "visionos"`
  and has `isDefaultAudioTrack`; `TmdbMetadataService.kt` has
  `aggregate_credits`; `SimklMutationReceipt.kt`'s `stringValue()` has the
  explicit `JsonNull` guard.
- **HIGH subtitle/player-engine batch** (`claude/subtitle-engine`) —
  confirmed landed: `grep -rl AddonSubtitleStartupMode shared/src` is empty
  (only the legacy sync-purge key string remains, as designed).

Both branches are still flagged in CLAUDE.md as **device-pass owed** — that's
a manual QA step, not something a Claude Code session can port, so it isn't
repeated as an action item here.

## Action items for Claude Code

None. Nothing new landed upstream that applies to tvOS, and everything
previously flagged as unported has since been merged (device pass still
owed, tracked separately in CLAUDE.md, not a coding task).

Untouched/carried, no change:
- **[LOW, spot-check only]** Player pause-description staleness — verify
  next time the tvOS player/pause-overlay UI gets touched (not upstream-code
  driven, `MPVPlayerView` is native).
- **[PARKED/DEFERRED by product decision]** Supporter perks v1, subtitle
  minimum font size — no action until re-raised.

## Verification method

- `git fetch upstream cmp-rewrite` in `NuvioMobile/`, diffed `1b84ee47..upstream/cmp-rewrite`.
- Read the new commit's full diff (`git show 388e613c`) rather than trusting the commit message.
- Grepped/read current `shared/` file contents for the four previously-open items to confirm merge, not relying on branch names or commit messages.

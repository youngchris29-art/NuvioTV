# Reddit draft — reply to u/napes22 (`p7w0syf`)

Covers **BUG-94**: playback failing on every stream, plus a question about switching to Infuse.

Parent: <https://www.reddit.com/r/Nuvio/comments/1v26ebw/i_built_a_native_apple_tv_app_for_nuvio_beta/p7w0syf/>

**Status: POSTED 2026-09-05T20:49:09Z** as
[`p81ihg4`](https://www.reddit.com/r/Nuvio/comments/1v26ebw/i_built_a_native_apple_tv_app_for_nuvio_beta/p81ihg4/),
u/youngchris2989 — verbatim, from a logged-in machine, confirmed by the 2026-09-05 evening sweep's
Reddit feed read. SlopMonster **5/5 CLEAN** (`python3 scripts/deslop/deslop.py`, 208 words in the
final paste-ready form). The rival-model cleanse was **skipped**: the `codex` CLI is not installed
in this cloud session.

**Why it is still unposted: this session cannot post it.** Posting on this thread goes through the
logged-in web session's classic write endpoint (`/api/comment` with the page modhash) driven from an
ego-browser task space, which is how `p7nbyk8` and `p6fempv` were posted. That runs on Christian's
machine. This is a cloud container: no Reddit credentials in the environment, no ego-browser, and no
logged-in session to borrow a modhash from. The API-credential path was already recorded as
unavailable in the shell when the beta.17 comment went up. So the reply is finished and paste-ready,
and it needs one action on a logged-in machine.

---

## The draft

**Paste-ready as written**: no em dashes, straight quotes, per the house Reddit posting style used
for the beta.15 and beta.17 comments. 1,197 characters.

> Sorry about that. That's not normal, and I'd rather find the cause than route you around it.
>
> On Infuse: you can already use it. Settings > Playback > Default Player lists Infuse, VLC, Outplayer and VidHub. But if every stream fails, handing the same stream to Infuse will usually fail there too. The app has to resolve a playable link before any player is involved, and "all streams" normally means the failure is happening before playback rather than in the player, so switching would hide it rather than fix it.
>
> Four things and I can narrow this down:
>
> * **Build number.** Settings > About. A photo of that screen is ideal. Latest is 0.3.0 (116).
> * **Add-ons.** Which ones you have installed and enabled, under Settings > Content Sources.
> * **Debrid.** Do you have Real-Debrid, TorBox or AllDebrid linked, and does it still show as connected? An expired or signed-out debrid account is the most common reason everything fails at once.
> * **How it fails.** Instantly, or after a spinner? And do you get a list of sources at all, or is the list empty?
>
> That last one splits the problem in half: sources listed but none of them play is a different bug from no sources arriving in the first place.

---

## Why the reply asks instead of answers

**The report carries nothing to reproduce from.** One line, no build number, no add-on or debrid
list, no title named, no instant-versus-spinner detail. A first reply that named a cause would be
inventing one. This is also a first-time voice on the thread, the 22nd distinct commenter, so there
is no prior context to lean on.

**"All streams" is the shape of a source-resolution failure, not a player failure.** Every source
failing at once is what an empty or broken add-on list, an expired debrid account, or a network that
cannot reach the source hosts looks like from the user's seat. A player bug would normally take out
some streams and not others — a container, a codec, a particular host. That reasoning is why the
reply leads with the diagnostic split (sources listed but dead vs. no sources arriving) rather than
with a fix.

**The Infuse question has a real answer, and it is "yes, and it won't help".** FEAT-5 shipped
Infuse, VLC and Outplayer with a Default Player dropdown under Settings → Playback in beta.4;
FEAT-21 added VidHub in beta.12. So the feature they are asking for exists. But the handoff passes a
resolved link to the external player — if resolution is what is failing, Infuse receives the same
nothing. Saying only "yes, it's in Settings" would send them down a dead end and cost a round trip.

**Every settings path named here is one this repo has already verified.** Settings → About (FEAT-13,
filmed by a tester twice), Settings → Playback → Default Player (FEAT-5's shipping note),
Settings → Content Sources (used in the verified `p61pnyh` draft). The debrid question deliberately
does **not** name a pane: provider sign-ins live under Account & Services, but the submodule is not
checked out in this session, so the draft asks whether debrid shows as connected rather than
directing them to a path it cannot confirm.

**The build-number ask is phrased as a photo.** The watch-list note from 2026-08-10 records that
this thread's testers answer "which build?" by filming the About pane rather than typing a number.
Asking for the screen matches how they already report.

## What the answers discriminate

| Their answer | Reading |
|---|---|
| No add-ons installed or enabled | Config, not a defect. The fix is their add-on list, and it argues for a clearer empty state. |
| Add-ons fine, debrid expired or signed out | Config, and worth checking whether the app surfaces that failure legibly or just says "playback failed". |
| Sources list arrives, nothing plays | A real playback or link-resolution bug. The titles and the add-on names say which. |
| Source list empty or errors | Add-on manifest or network. Overlaps the delayed-manifest work that landed in upstream batch 7 (beta.17) — worth knowing whether they are on 116 or older. |
| Build older than 116 | Ask for the upgrade first; several playback-adjacent fixes have shipped since 113. |

## Related rows worth checking it against before calling it new

- **BUG-71** — cold-launch behaviour on 113+, retest publicly re-asked 08-28, still unanswered.
- **BUG-62** — stuck playback from u/StudioKentin, build number owed since 08-13.

Neither is confirmed related. Both are unanswered asks about playback on recent builds, so a third
report with actual detail could close more than its own row.

# Beta feedback sweep — canonical procedure

This file is the single source of truth for the daily beta-feedback sweeps. Both runs follow it:

- **Morning sweep** — cloud Routine ("NuvioTV morning feedback sweep — 8am ET", fires 12:00 UTC;
  created 2026-08-21, replacing the old local scheduled task on Christian's machine).
- **Evening sweep** — cloud Routine ("NuvioTV Reddit feedback sweep — 7pm ET", fires 23:00 UTC).

The morning sweep is deliberately an hour after the Daily GitHub Issue Check Routine (11:00 UTC)
so the two never race each other on the same GitHub state.

Where a sweep's own prompt and this file differ, **this file wins** — which is why behaviour
changes land here rather than in the two Routines' prompt boxes. (Both prompts open by telling the
run to read this file first, so a change here reaches both sweeps on their next firing with no UI
edit.) **New 2026-08-24: every sweep now merges its branch into `main` as it lands — see §6.** As of 2026-08-21 the sweep
covers **two sources**: the Reddit beta thread *and* the GitHub repo (issues + pull requests).
GitHub was added after issue #1 sat 27 days without a reply while the Reddit thread got all the
attention (see `docs/issue-triage-plan-2026-08-21.md` §6.3).

## 1. Reddit thread check

1. Fetch the thread's public Atom feed:
   `https://www.reddit.com/r/Nuvio/comments/1v26ebw/i_built_a_native_apple_tv_app_for_nuvio_beta/.rss`
   using a unique descriptive User-Agent such as `nuviotv-beta-feedback-tracker/1.0` (a generic
   Mozilla UA gets 403'd).
2. If reddit.com is unreachable from the environment (network policy), **do not guess or
   fabricate feed content**. Note the blocked fetch in the digest and continue with the GitHub
   check below — a blocked Reddit fetch no longer aborts the whole sweep, but it must never be
   silently papered over.
3. Compare against the watermark (newest comment id + timestamp) recorded in
   `docs/beta-feedback-tracker.md`'s header. Comments at or before the watermark are already
   processed.

## 2. GitHub check (issues + pull requests)

Repo: `youngchris29-art/NuvioTV`. Use whatever GitHub access the session has, in this order of
preference: GitHub MCP tools → `gh` CLI → unauthenticated public API via WebFetch
(`https://api.github.com/repos/youngchris29-art/NuvioTV/issues?state=open` — this endpoint
returns PRs too; a `pull_request` key marks them).

1. **Open issues:** for each, check for comments newer than the sweep's last run.
   - A new issue → a tracker row like any other feedback source (priority, bucket, status),
     with the issue URL noted in the row and the reporter's GitHub handle as the who.
   - A new comment on an existing issue → update its row exactly as a Reddit reply would.
   - An issue awaiting *our* reply (retest ask, close-or-confirm, requested info) is a
     **comms-owed item** and must appear in the digest until posted.
2. **Open pull requests:** note number, title, branch, mergeability/CI state, and what is
   blocking. Surface them in the digest. **The sweep never merges, closes, or pushes to a PR**
   — it only reports.
3. If GitHub is unreachable, say so in the digest — never skip the check silently.
4. The digest's **GitHub line is mandatory** even on a quiet day: `GitHub: quiet (2 open
   issues unchanged, 0 PRs)` beats omission, because omission is indistinguishable from
   the pre-2026-08-21 behavior of not looking.

## 3. Tracker + dashboard update

New items or changes from **either source** →

- `docs/beta-feedback-tracker.md`: append/update item rows, header bullets, update log.
  Never remove manual edits — the daily run only appends/updates.
- `docs/beta-feedback-dashboard.html`: the ITEMS array in its bottom `<script>` (one 7-field
  entry per tracker row: id, priority, arrow up/down on priority change, bucket
  [open|waiting|unreleased|shipped|closed|declined], short stable title, "State · qualifier"
  status label, one-sentence note), the ~5 header pills, the "Latest sweep" digest (push the
  previous digest into the Archive as a new details entry), and the Now/Next/Waiting lanes.
  Tiles and counts derive from ITEMS at runtime — **never hand-edit numbers in markup**.
- GitHub-sourced rows live in the same ITEMS array and the same tracker tables as Reddit rows;
  they are distinguished by the issue link in the row, not by a separate silo.

## 4. Republish the dashboard

Republish with the Artifact tool: file `docs/beta-feedback-dashboard.html` **with** url
`https://claude.ai/code/artifact/0d62393a-48c8-4bf9-ba1e-43a996052abf` (WebFetch that url first
if the tool asks; keep the 📺 favicon). **Never publish without the url.**

## 5. Quiet run

A run is quiet only when **both** sources held still: Reddit watermark unchanged **and** no new
GitHub issue/PR activity. Then: update only the last-checked lines in both files, commit
`sweep: quiet run YYYY-MM-DD`, skip the republish. Activity on either source makes it a normal
run for both files. **A quiet run still merges to `main` per §6** — the republish is what a quiet
run skips, never the merge.

## 6. Commit, then merge to `main` — every sweep, as it lands

Commit tracker + dashboard (+ anything else the run touched) together and push to the session's
designated branch.

**Then merge that branch into `main` and push `main`. This is not optional, and it applies to
quiet runs too.** Christian authorised this standing on 2026-08-24; it is the explicit permission
the session's default "never push to a branch other than your designated one" rule asks for, and
it is scoped to exactly this: merging a sweep's own commits into `main`. It does not authorise
pushing anything else to `main`, force-pushing, or rewriting history.

### Why this step exists

Each scheduled sweep is handed a *fresh* `claude/*` designated branch and clones `main`. Before
this rule, sweeps committed there, pushed, and nothing ever merged back — so `main` froze while
sibling branches accumulated the real history, and each new session started blind to the previous
one. On 2026-08-24 the morning sweep found `main` frozen at `50cb163` since 08-22 with **four**
unmerged sweep branches, and found concrete damage: the 08-23 *evening* run had re-derived the
tracker header from the 08-22 state because its checkout could not see that morning's run. A day
of history was one stale clone away from being lost. Merging on landing is what stops that.

### The merge

```
git push -u origin <designated-branch>
git fetch origin main
git checkout main && git merge --no-ff <designated-branch> && git push origin main
git checkout <designated-branch>
```

**Classifier fix (2026-08-28):** every one of these commands is now explicitly
allowlisted in the checked-in `.claude/settings.json` (Christian approved and
created it by hand after five classifier-blocked merges, 08-24 → 08-28). Cloud
clones inherit it, so the merge should no longer be blocked. If a merge is
*still* refused despite the allowlist, that is a new finding — name it in the
digest, and fall back to the documented hand-fold route (file-level three-way
fold committed as a normal commit + a row in the do-not-re-merge table below)
rather than leaving the branch stranded.

Use `--no-ff` so each sweep stays one identifiable commit range in `main`'s history.

**On conflict** (only possible if `main` moved while the sweep ran) the two files conflict
predictably, and the resolution is mechanical:

- **Header lines** (`Last checked`, `Newest comment seen`, the dashboard's `Last checked` pill) —
  take the *newer* run's text, and make sure the older run's text survives in that line's
  `— *Prior:*` chain.
- **Update log entries / dashboard digest** — keep **both** sides. These are append-only; losing
  one is the exact failure this rule exists to prevent.
- **Item rows / the ITEMS array** — keep both sides' edits unless they touch the same field of the
  same id, in which case the newer run wins.

If a conflict is *not* mechanically resolvable that way, **stop, leave `main` untouched, and say
so in the digest** — never force-push, and never drop a side to make the merge go through.

### Absorb orphaned sweep branches

While on `main`, also pick up any sweep work stranded on earlier branches. A remote branch counts
as an **orphaned sweep branch** only if *every* commit it carries that is not already in `main`:

1. has a message beginning `sweep:`, **and**
2. touches nothing outside `docs/beta-feedback-tracker.md` and `docs/beta-feedback-dashboard.html`.

That test deliberately excludes release and feature branches — never merge one of those on the
sweep's initiative. Merge qualifying branches **oldest first**, before merging the current run,
resolving conflicts by the rules above, and list what you absorbed in the digest. If nothing
qualifies, say so and move on.

**Passing the two-part test is necessary, not sufficient — audit the branch's content before
merging it.** A branch can qualify and still be *superseded*, in which case merging it drags
`main` backwards. Check whether its changes are already present in `main` (or in the current
run's branch) by some other route — a reconciliation commit, a cherry-pick, a hand-fold — and if
they are, **skip it and say so**, rather than merging it for the sake of a tidy graph.

**Delete absorbed branches from the remote as part of absorbing them** (`git push origin
--delete <branch>`). A deleted branch cannot be resurrected by a later sweep, which retires
the risk the old "do NOT re-merge" table existed to guard. That table (six branches absorbed
between 08-22 and 08-28, four of them via hand-fold or supersession rather than a plain merge)
was retired on 2026-08-28 when Christian had all fourteen accumulated `claude/*` sweep branches
deleted from the remote — every one verified either fully merged (0 unmerged commits) or
documented-absorbed first. A sweep's own designated branch is the one exception: leave it —
the platform owns its lifecycle.

### Report it

The digest and the commit message both state the merge outcome — `merged to main (<sha>)`, or
`merge blocked: <reason>` when it could not complete. A sweep that could not merge is a finding
worth a notification, not a silent skip: a frozen `main` is invisible until someone goes looking,
which is how it went unnoticed for two days.

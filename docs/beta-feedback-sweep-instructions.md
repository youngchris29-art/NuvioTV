# Beta feedback sweep — canonical procedure

This file is the single source of truth for the daily beta-feedback sweeps. Both runs follow it:

- **Morning sweep** — local scheduled task on Christian's machine.
- **Evening sweep** — remote Routine ("NuvioTV Reddit feedback sweep — 7pm ET", fires 23:00 UTC).

Where a sweep's own prompt and this file differ, **this file wins**. As of 2026-08-21 the sweep
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
run for both files.

## 6. Commit

Commit tracker + dashboard (+ anything else the run touched) together and push to the session's
designated branch.

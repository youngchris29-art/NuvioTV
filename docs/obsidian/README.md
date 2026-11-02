# Obsidian vault: frontmatter schema

`docs/` is an Obsidian vault. Open the `docs/` folder itself (not the outer repo), so `NuvioMobile/` and the build folders stay out of the index. `.obsidian/` is covered by the `docs/**` ignore and never enters git.

This folder holds the schema (this file), one template per note type (`templates/`) and the saved views (`bases/`). The notes themselves stay local and gitignored, as before.

## One-time setup in Obsidian

1. Open folder as vault → `~/…/NuvioTV/docs`.
2. Settings › Core plugins: turn on **Templates** and **Bases**.
3. Settings › Templates › Template folder location: `obsidian/templates`.
4. Settings › Files and links: **Automatically update internal links** OFF. Scripts read tracked docs by path (`status.md`, `upstream-check-latest.md`, `ios-release-watch.md`, `device-rig-2026-10-15.md`); never rename those.

## Rules

- Every new note under `docs/` that has a `type` below starts with that frontmatter block. Old notes are backfilled only when touched.
- Keys are snake_case. Dates are `YYYY-MM-DD`. SHAs are short (9 chars), submodule SHAs unless the key says `outer_`.
- Links to other notes in frontmatter are quoted wikilinks: `batch: "[[batch-upstream-1031]]"`. Paths to folders (evidence) are plain strings.
- An empty list (`[]`) means "none", checked. A missing key means "not recorded".
- The body keeps its existing conventions: the NOT SENT marker on comms drafts and the `<!-- internal -->` marker stay where they are. The frontmatter mirrors them; it does not replace them.
- `deslop.py` scores frontmatter as copy (it has no frontmatter handling), so a comms note's frontmatter carries no tracker IDs or SHAs; those go in the linked batch note.

## Types

### `batch` — `batch-*.md`

| Key | Values | Meaning |
| --- | --- | --- |
| `type` | `batch` | |
| `date` | date | Day the batch started |
| `state` | `planned` · `in-progress` · `landed` · `cut` · `released` | `landed` = fast-forwarded into `tvos-shared-extraction` and pushed, not cut |
| `base` | SHA | `tvos-shared-extraction` before the batch |
| `tip` | SHA | Tip after landing (empty until landed) |
| `outer_pointer` | SHA | Outer commit that bumped the pointer |
| `release` | `beta.<n>` or `beta.<n>-rc<m>` | Set when cut; empty before |
| `items` | list | Tracker IDs and upstream refs in the batch |
| `new_settings` | list of `"Path › Name = Default"` | `[]` when the batch adds none (release notes and DMs read this) |
| `review` | `open` · `clean` | Codex or stand-in loop result |
| `gates` | `pending` · `green` · `red` | All gates on the tip |
| `device_pass` | `not-run` · `partial` · `pass` · `fail` | Rolled up from the device-pass notes |
| `plan` | URL | Claude Doc plan, if any |
| `comms` | list of wikilinks | Comms drafts for this batch |
| `device_passes` | list of wikilinks | Device-pass notes |
| `evidence` | path | `research/…` folder |

### `comms` — `comms-*.md`

| Key | Values | Meaning |
| --- | --- | --- |
| `type` | `comms` | |
| `date` | date | Drafted |
| `state` | `not-sent` · `sent` · `dropped` | Mirrors the NOT SENT marker |
| `channel` | `github` · `reddit` · `dm` · `release-notes` · `readme` | |
| `target` | string | Issue number, Reddit thread or comment id, DM recipient |
| `deslop` | 0–5 | Last `deslop.py` score |
| `cleansed` | `true` · `false` | Codex cleanse done |
| `release` | `beta.<n>` | Release it announces or ships with |
| `batch` | wikilink | |
| `sent` | date | Empty until sent; set only after Christian's go |
| `sent_ids` | list | Comment or message ids once posted |

### `device-pass` — `device-pass-*.md`

| Key | Values | Meaning |
| --- | --- | --- |
| `type` | `device-pass` | |
| `date` | date | |
| `profile` | `Test` · `Test 2` | Never `Chris` without his go |
| `box` | string | e.g. `Living Room` |
| `build` | `Debug` · `Release` · `both` | |
| `tip` | SHA | Build under test |
| `batch` | wikilink | |
| `result` | `pass` · `partial` · `fail` | |
| `passed` | list | Step ids that passed |
| `not_run` | list | Step ids not run (with the reason in the body) |
| `failed` | list | Step ids that failed |
| `for_christian` | list | Feel/look checks left for him |
| `evidence` | path | |

### `owed` — `owed-*.md` (one note per open ask)

| Key | Values | Meaning |
| --- | --- | --- |
| `type` | `owed` | |
| `who` | string | Tester handle or person |
| `what` | string | One line |
| `where` | string | Issue, thread or DM |
| `asked` | date | |
| `state` | `open` · `done` · `dropped` | |
| `item` | string | Tracker ID, if any |
| `batch` | wikilink | |

### `decision` — `decision-*.md`

| Key | Values | Meaning |
| --- | --- | --- |
| `type` | `decision` | |
| `date` | date | |
| `state` | `decided` · `deferred` · `reversed` | |
| `decided_by` | string | Usually `Christian` |
| `summary` | string | One line |
| `batch` | wikilink | |
| `supersedes` | wikilink | Earlier decision it replaces |

## Saved views (`bases/`)

| File | Shows |
| --- | --- |
| `landed-not-cut.base` | Batches with `state: landed`, oldest first: the next release notes |
| `comms-not-sent.base` | Comms with `state: not-sent`, grouped by channel |
| `device-not-run.base` | Device passes that are not a clean pass, with `not_run` / `failed` / `for_christian` |
| `owed.base` | Open `owed` notes, oldest ask first |
| `decisions.base` | Every decision, newest first |

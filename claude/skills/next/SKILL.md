---
name: next
description: Pick the next task from the project's work-item source, plan its implementation, and execute the plan once approved.
disable-model-invocation: true
allowed-tools: EnterWorktree, ExitWorktree, Bash(.claude/workspace/provision run:*)
---

A tree holds at most one task, and no task another tree or person has already claimed is picked without the user's say-so (`claude/CLAUDE.md` § Work items, *One task per tree*). The first section below enforces the first half before anything is selected; *Skip claimed items* enforces the second.

## What this tree already holds

An optional argument may follow the command: `$ARGUMENTS`.

Before selecting anything, find out whether the tree this task would be worked in is already bound. That is the session's own tree when it is a linked worktree (`git rev-parse --path-format=absolute --git-dir --git-common-dir` prints two different paths), or when it is the main checkout of a project that describes no isolation (`~/.claude/skills/workspace-tree.md` step 2), since the work stays in place there. In the main checkout of a project that isolates, skip this section: the task gets a tree of its own, and an item the main checkout's own marker names is handled in *Skip claimed items* and `workspace-tree.md` step 3.

Run `sh ~/.claude/skills/task-marker.sh get`. Exit 1 (no marker) means nothing is bound: go on to selecting. With a marker, this tree already holds that item, and no other task starts here:

- **No argument** — resume the marked item: select it, say that it is resumed from this tree's marker, and skip the selection below.
- **An argument that matches the marker's item** (compared as *Check that this tree is free* compares them) — resume it the same way.
- **An argument naming a different item** — stop and report the bound item, with nothing selected, claimed or written. Finishing it (`/ship`), or clearing a stale marker, is the user's call; a second task means a second tree.

A resumed item is not trusted on the marker's word: *Check that this tree is free* verifies it against its source before anything is claimed, as it does for every resume.

## Selecting the task

- **If an argument is given**, treat it as a hint to find a *specific* work item, and select the one that best matches it. The hint may be a task number/ID, a filename, or text describing the task — interpret it against whatever source the project uses (a matching line in `TODO.md`, a per-task filename or its contents, an issue key or summary in the tracker).
- **If no argument is given**, select the *first* unclaimed task, however "first" is defined by the source: the first content line in `TODO.md`, the lowest-numbered or lowest-sorting per-task file, or the top of the tracker's order.

### Skip claimed items

An item is **claimed** when its source shows someone working it — a state past the queue (In Progress, In Review, or the source's equivalent) or an assignee, anyone's — or when another tree's marker names it. `sh ~/.claude/skills/task-marker.sh list` prints every tree's marker in this repository, one line each: `<this>`, tree path, `SOURCE`, `ID`, `TITLE`, tab-separated. Run it once, before selecting, and match its lines against items as *Check that this tree is free* compares them. By `<this>`:

- **`-`** — another tree's marker: a claim by that tree. One exception, when an argument names the item: the tree `workspace-tree.md` step 5 would enter for this item — `.claude/worktrees/<name>` under the main checkout, `<name>` derived from the item as that step says — is this item's own, and entering it resumes it there rather than opening a second tree.
- **`*`** — the session's own tree. In a linked worktree, or where the project works in place, *What this tree already holds* has dealt with it. In the main checkout of a project that isolates, it is the main checkout's own binding, from work started in place: the item it names is not someone else's claim, so it is neither passed over nor taken over, and `workspace-tree.md` step 3 works it in place.
- **`!`** — a tree whose directory is gone, its marker left behind until `git worktree prune` removes it. It claims nothing: report it, with that command, and let the item's state in its source decide.

Then:

- **No argument** — pass over every claimed item and take the first one that is not. Report each item passed over, with why: its state, its assignee, or the tree whose marker names it. If every candidate is claimed, report them and stop: there is nothing to do.
- **An argument naming a claimed item** — never take it silently. Another tree's marker naming it, other than the item's own tree above → stop and name that tree: it is working the item, and two trees on one item is what the rule forbids; it is resumed from a session opened in that tree. Claimed only in its source → report the state and assignee and ask (`AskUserQuestion`) whether to take it over; the claim may be someone else's work, or left behind by a tree removed without finishing it.

A project's own rules still bind where they are stricter: where they cap In Progress across all the project's trees (one at a time, say) and that cap is reached, stop and report the item In Progress rather than claim another.

A caller that resolved the item already and skips the selection (`/mill`) settles the claim itself before calling.

The markers are this machine's only: a claim made in another clone shows only in a tracker. `TODO.md` and per-task files have no claim state at all, so for them a marker is the whole claim; a Backlog.md board's claim is made on the tree's branch and stays invisible to every other tree until that branch is integrated. For all three, the markers are the only claim another tree on this machine can see, and a tree working such an item without a marker cannot be seen at all. A project's own selection rule still takes precedence (*Determine the work-item source*) — lumus, for one, resumes in-flight work assigned to you that no tree's marker names.

## Determine the work-item source

First consult the project's own Claude instructions and documentation (CLAUDE.md, AGENTS.md, docs/, READMEs). If they name a source for work items or describe how the next task is chosen, follow that — it takes precedence over everything below.

Otherwise, discover which of these sources the project uses and select the task from it:

- **A `TODO.md` file** — content lines are the tasks. The first content line is:

  !`grep -v -e '^#' -e '^-' -e '^>' -e '^$' TODO.md 2>/dev/null | head -1`

  (`-` lines are completed/checklist items; `#`, `>`, and blank lines are structure.) With an argument, pick the content line that matches the hint instead.

- **A directory of per-task files** (e.g. `docs/plan/`) — each file is one work item. Order them by the project's convention (filename prefix, date, or numeric order); if none is apparent, sort by filename. Take the first when no argument is given, or the file whose name/contents match the hint. Read the file to get the task.

- **A Backlog.md board** (a `backlog/config.yml` at the project root, or CLAUDE.md naming Backlog.md) — with no argument, take the first task in the To Do column *by board position*: `backlog task list --status "To Do" --sort ordinal --plain`, first unclaimed entry. (`--sort ordinal` makes the selection follow the board's own top-to-bottom order — the same order drag-and-drop reordering sets — rather than the default id sort, so moving a task to the top of the To Do column makes it the next pick.) With an argument that looks like a task ID (with or without the project's prefix), view it directly: `backlog task view <id> --plain`; otherwise match the hint via `backlog search "<hint>" --plain`. Follow the project's Backlog instructions (`backlog instructions overview` and the guides it points to) for statuses, assignee, and recording the plan.

- **An MCP connection to an issue tracker** (e.g. Jira) — if such an MCP server is connected, query it for the top open issue in the tracker's order, or for the issue matching the hint when an argument is given.

These are examples, not an exhaustive list. If more than one source exists and the project's documentation doesn't disambiguate, ask the user which to use. If no source yields an actionable task, tell the user there is nothing to do and stop.

## Enter the task's tree

Once a task is chosen — also when a caller already resolved it and skipped the selection above — and before the check below that the tree is free and before planning anything, follow the *Entering* part of `~/.claude/skills/workspace-tree.md` (steps 1–6), naming the tree as its step 5 says. It puts the session in a tree of its own: a new one in a project that isolates, or the one it is already in when it was started in a linked worktree — or it leaves the session in the main checkout, in place, where the project describes no isolation, the task is already underway there, or the repository has no `origin` default branch. This comes first because the marker is per tree and is written on plan approval: a tree entered later would leave the task bound to the main checkout. If the session is already in plan mode, enter the tree there, before drafting the plan. Everything below runs in whichever tree that leaves the session in. The *Preparing* part (step 7) waits for approval (*Plan and execute*); if the user abandons the task at the plan gate instead, leave the tree as that file's *Dropping the work before it starts* says.

## Check that this tree is free

Run this in the tree the step above left the session in, before planning anything: `sh ~/.claude/skills/task-marker.sh get`. It repeats *What this tree already holds* for the tree the task actually landed in — a new tree, a resumed one, or a marker that changed since. Exit 1 (no marker) means the tree is free. A marker naming the chosen task means this tree already holds it — resumed in this tree, re-entered by name from the main checkout, or worked in place there. Compare like with like, as `/ship` does: ids ignoring a project prefix the source treats as optional, and for `todo`, whose `ID` is only a slug, the marker's `TITLE` against the task line. The marker is advisory (`claude/CLAUDE.md` § Work items), so verify it first, whichever way the task got here: run `sh ~/.claude/skills/task-marker.sh check` and read the item in its source. A mismatch (exit 3), or an item that is in its terminal state or no longer in its source, means the marker is stale: stop and report it, with nothing claimed — clearing it is the user's call. An item now assigned to someone else gets the takeover question from *Skip claimed items*: carry on only if the user takes it over, and stop otherwise. Whenever you carry on, reuse the marker's `ID` in the bind step below so it refreshes rather than refuses. In a tree `workspace-tree.md` reported **resumed** — one that already held work — no marker is not free: that work may be anything that shares the tree's name, so stop before claiming and ask (`AskUserQuestion`) whether it is this task's earlier attempt, to carry on with, or something else; on *something else*, leave the tree with `ExitWorktree` action `keep` and stop, naming it, as `workspace-tree.md` step 5 says. A marker naming a **different** item means this tree is still on that one: stop and report it, with nothing claimed or written. It is either unfinished work or a stale marker, and which one is the user's call. Checking here rather than at the bind step is what keeps a refusal from leaving the new task claimed in its source with nothing bound to it.

## Plan and execute

Enter plan mode and plan the implementation of the selected task. If the task already carries an implementation plan, treat it as a likely-outdated prescription — mine it for useful details, but draft a fresh plan from the current state of the codebase. Where the project's documented lifecycle requires opening steps (e.g. recording the plan on the task and activating it), the plan must include them. The plan must include a final step that hands the task on in its source, matched to that source:

- **`TODO.md`** — remove the task line itself and any adjacent blank lines so no double linebreaks are left behind. Do NOT commit TODO.md after removing the entry. In a tree, the file may not be there at all: a `TODO.md` the project does not track (`git ls-files --error-unmatch TODO.md` fails — gitignored, say) exists only in the main checkout, which the isolated session cannot write. Then this step is not in the plan: say so, and `/ship` removes the line from the main checkout after it pushes (its § 5 already removes one that is still there). The same goes for an untracked per-task file.
- **Per-task file** — delete or move the file per the project's convention (e.g. into a `done/` directory) if the documentation specifies one; otherwise delete it.
- **Backlog.md board** — follow the project's documented task lifecycle if it defines one, stopping where it says to stop; otherwise move the task to its review status if the board has one, and leave it In Progress if not. **Never move it to Done here.**
- **Issue tracker** — transition the issue to its review state if the tracker has one, and leave it In Progress if not. **Never close it here.**

The terminal move on a board or tracker belongs to the Finish gate — `/ship`, after the change is committed and pushed — which resolves the task from the marker below and refuses one already Done. A change finished any other way (a hand `/commit`) leaves the task for the user to close.

Where `workspace-tree.md` step 5 entered a tree (created, reused or resumed), the plan's **first** step is that file's *Preparing* part (step 7, `provision run`) — preceded by the base guard's reset when step 6 deferred it because the session was already in plan mode — ahead of everything else, the claim included.

The plan must also bind this tree to the task, with `sh ~/.claude/skills/task-marker.sh set --source <kind> --id <id> --title <title>`. Place that step **immediately after** the one that claims the task — moves it to In Progress — and never before it, so on a source with a claim state a marker cannot exist without a claim behind it. A source with no claim state (`TODO.md`, per-task files) binds as the first implementation step instead. The marker is what `/ship` resolves its Finish gate from and clears after pushing, so it outlives the final hand-on step above; leave it in place. Per source:

- **`TODO.md`** — `--source todo`, `--id` a short slug of the task line, `--title` the line itself. The slug is only a label; the line in `TITLE` is what identifies the task.
- **Per-task file** — `--source file`, `--id` the filename.
- **Backlog.md board** — `--source backlog`, `--id` the task id.
- **Issue tracker** — `--source` the tracker's name as a lowercase token (`linear`, `jira`), `--id` the issue key.

The tree-free check above means `set` should not find a different item bound. If it does anyway (exit 2) — the marker changed since — stop, report the item it names, and return the task just claimed to its previous state so it is not left In Progress with nothing bound to it. Never pass `--force` without the user's say-so.

Once the user approves the plan via `ExitPlanMode`, implement it — including the final step that hands the task on in its source.

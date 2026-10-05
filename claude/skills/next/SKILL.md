---
name: next
description: Pick the next task from the project's work-item source, plan its implementation, and execute the plan once approved.
disable-model-invocation: true
---

## Selecting the task

An optional argument may follow the command: `$ARGUMENTS`.

- **If an argument is given**, treat it as a hint to find a *specific* work item, and select the one that best matches it. The hint may be a task number/ID, a filename, or text describing the task — interpret it against whatever source the project uses (a matching line in `TODO.md`, a per-task filename or its contents, an issue key or summary in the tracker).
- **If no argument is given**, select the *first* task, however "first" is defined by the source: the first content line in `TODO.md`, the lowest-numbered or lowest-sorting per-task file, or the top of the tracker's order.

## Determine the work-item source

First consult the project's own Claude instructions and documentation (CLAUDE.md, AGENTS.md, docs/, READMEs). If they name a source for work items or describe how the next task is chosen, follow that — it takes precedence over everything below.

Otherwise, discover which of these sources the project uses and select the task from it:

- **A `TODO.md` file** — content lines are the tasks. The first content line is:

  !`grep -v -e '^#' -e '^-' -e '^>' -e '^$' TODO.md 2>/dev/null | head -1`

  (`-` lines are completed/checklist items; `#`, `>`, and blank lines are structure.) With an argument, pick the content line that matches the hint instead.

- **A directory of per-task files** (e.g. `docs/plan/`) — each file is one work item. Order them by the project's convention (filename prefix, date, or numeric order); if none is apparent, sort by filename. Take the first when no argument is given, or the file whose name/contents match the hint. Read the file to get the task.

- **A Backlog.md board** (a `backlog/config.yml` at the project root, or CLAUDE.md naming Backlog.md) — with no argument, take the first task in the To Do column *by board position*: `backlog task list --status "To Do" --sort ordinal --plain`, first entry. (`--sort ordinal` makes the selection follow the board's own top-to-bottom order — the same order drag-and-drop reordering sets — rather than the default id sort, so moving a task to the top of the To Do column makes it the next pick.) With an argument that looks like a task ID (with or without the project's prefix), view it directly: `backlog task view <id> --plain`; otherwise match the hint via `backlog search "<hint>" --plain`. Follow the project's Backlog instructions (`backlog instructions overview` and the guides it points to) for statuses, assignee, and recording the plan.

- **An MCP connection to an issue tracker** (e.g. Jira) — if such an MCP server is connected, query it for the top open issue in the tracker's order, or for the issue matching the hint when an argument is given.

These are examples, not an exhaustive list. If more than one source exists and the project's documentation doesn't disambiguate, ask the user which to use. If no source yields an actionable task, tell the user there is nothing to do and stop.

## Check that this workspace is free

Run this whenever a task has been chosen — also when a caller already resolved it and skipped the selection above — and before planning anything: `sh ~/.claude/skills/task-marker.sh get`. Exit 1 (no marker) means the workspace is free. A marker naming the chosen task means this workspace already holds it — carry on, and reuse the marker's `ID` in the bind step below so it refreshes rather than refuses. Compare like with like, as `/ship` does: ids ignoring a project prefix the source treats as optional, and for `todo`, whose `ID` is only a slug, the marker's `TITLE` against the task line. A marker naming a **different** item means this workspace is still on that one: stop and report it, with nothing claimed or written. It is either unfinished work or a stale marker, and which one is the user's call. Checking here rather than at the bind step is what keeps a refusal from leaving the new task claimed in its source with nothing bound to it.

## Plan and execute

Enter plan mode and plan the implementation of the selected task. If the task already carries an implementation plan, treat it as a likely-outdated prescription — mine it for useful details, but draft a fresh plan from the current state of the codebase. Where the project's documented lifecycle requires opening steps (e.g. recording the plan on the task and activating it), the plan must include them. The plan must include a final step that hands the task on in its source, matched to that source:

- **`TODO.md`** — remove the task line itself and any adjacent blank lines so no double linebreaks are left behind. Do NOT commit TODO.md after removing the entry.
- **Per-task file** — delete or move the file per the project's convention (e.g. into a `done/` directory) if the documentation specifies one; otherwise delete it.
- **Backlog.md board** — follow the project's documented task lifecycle if it defines one, stopping where it says to stop; otherwise move the task to its review status if the board has one, and leave it In Progress if not. **Never move it to Done here.**
- **Issue tracker** — transition the issue to its review state if the tracker has one, and leave it In Progress if not. **Never close it here.**

The terminal move on a board or tracker belongs to the Finish gate — `/ship`, after the change is committed and pushed — which resolves the task from the marker below and refuses one already Done. A change finished any other way (a hand `/commit`) leaves the task for the user to close.

The plan must also bind this workspace to the task, with `sh ~/.claude/skills/task-marker.sh set --source <kind> --id <id> --title <title>`. Place that step **immediately after** the one that claims the task — moves it to In Progress — and never before it, so on a source with a claim state a marker cannot exist without a claim behind it. A source with no claim state (`TODO.md`, per-task files) binds as the first implementation step instead. The marker is what `/ship` resolves its Finish gate from and clears after pushing, so it outlives the final hand-on step above; leave it in place. Per source:

- **`TODO.md`** — `--source todo`, `--id` a short slug of the task line, `--title` the line itself. The slug is only a label; the line in `TITLE` is what identifies the task.
- **Per-task file** — `--source file`, `--id` the filename.
- **Backlog.md board** — `--source backlog`, `--id` the task id.
- **Issue tracker** — `--source` the tracker's name as a lowercase token (`linear`, `jira`), `--id` the issue key.

The workspace-free check above means `set` should not find a different item bound. If it does anyway (exit 2) — the marker changed since — stop, report the item it names, and return the task just claimed to its previous state so it is not left In Progress with nothing bound to it. Never pass `--force` without the user's say-so.

Once the user approves the plan via `ExitPlanMode`, implement it — including the final step that hands the task on in its source.

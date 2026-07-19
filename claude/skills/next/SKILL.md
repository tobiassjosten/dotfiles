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

- **An MCP connection to an issue tracker** (e.g. Jira) — if such an MCP server is connected, query it for the top open issue in the tracker's order, or for the issue matching the hint when an argument is given.

These three are examples, not an exhaustive list. If more than one source exists and the project's documentation doesn't disambiguate, ask the user which to use. If no source yields an actionable task, tell the user there is nothing to do and stop.

## Plan and execute

Enter plan mode and plan the implementation of the selected task. The plan must include a final step that marks the task done in its source, matched to that source:

- **`TODO.md`** — remove the task line itself and any adjacent blank lines so no double linebreaks are left behind. Do NOT commit TODO.md after removing the entry.
- **Per-task file** — delete or move the file per the project's convention (e.g. into a `done/` directory) if the documentation specifies one; otherwise delete it.
- **Issue tracker** — transition the issue to its done/closed state via the MCP connection.

Once the user approves the plan via `ExitPlanMode`, implement it — including the final step that marks the task done in its source.

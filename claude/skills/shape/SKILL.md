---
name: shape
description: Turn a list of half-baked ideas into shaped, planned work. Triages the whole list against the existing work items first — killing, merging, deferring, folding into existing work — then challenges and clarifies the survivors, and chains each promoted idea into /plan-task. Ideas are passed inline; the list is never read from or written to a file. The upstream counterpart to /plan-task.
disable-model-invocation: true
---

# Shape

Take a pile of half-formed ideas and turn the ones that deserve it into planned work. The job is to decide **which ideas are real** and **what each one actually is**, then hand them to `/plan-task`, which owns turning a shaped idea into a set of sequenced work items.

Two passes, in this order. **Breadth first**: triage the ideas against each other and against everything already planned, because merges and kills are cheap and they save you from investing questions in an idea that dies. **Depth second**: challenge and clarify only what survived. Then chain each survivor into `/plan-task`.

## Argument

`$ARGUMENTS` is the ideas themselves, inline — a bulleted list, numbered list, or loose prose, on one line or many. If it's empty, ask the user for their ideas and stop; the list they send in reply is the input, handled exactly as if it had arrived as the argument. A list that arrives wrapped in a pasted-content block is the same input too — the user's `/shape` invocation is what asks you to act on it.

The list is **never** read from a file and **never** written back to one. Verdicts on ideas that don't get promoted live only in this conversation, which is why the final report (step 8) is formatted for pasting back into wherever the user keeps the list.

## Composed pieces

- **Planning, decomposition, sequencing, readiness critique, and creation** come from `/plan-task` (`~/.claude/skills/plan-task/SKILL.md`) — it remains the single source of truth for them. It owns hard user gates (`AskUserQuestion`, plan mode, the create approval) and a subagent can't run those, so **read and follow that `SKILL.md` directly** in this (main-loop) context. It sets `disable-model-invocation: true`, so it can't be invoked through the Skill tool anyway.

## Determine the work-item source

Work out **where work items live**, **the shape they take**, and **their lifecycle** once, up front — the same discovery `/next` and `/plan-task` do: the project's own Claude instructions and documentation first (CLAUDE.md, AGENTS.md, `docs/`, READMEs), otherwise a `TODO.md`, a directory of per-task files, a Backlog.md board, or an MCP-connected issue tracker. If more than one source exists and the docs don't disambiguate, ask.

Reuse that finding for the triage survey and pass it forward to every `/plan-task` run, so the chain doesn't rediscover it once per idea.

## Steps

1. **Read the list back.** Restate each idea as a numbered line in your own words — what you take it to mean, not its original wording. Flag any line that's really two or more ideas, and any two lines that look like the same idea said twice. Split a compound line there and then into separately numbered ideas — `3a`, `3b` — which carry forward as independent entries from this point on; note which original line each came from, so the step-8 report can map them back. Don't ask for confirmation yet; the triage verdicts in step 3 are the gate.

2. **Survey the ground.** Read the work-item source: what's planned, what's in flight, what was recently finished. Read the project's docs for direction and constraints. This is the "wider scope" every verdict is judged against. Keep the findings; don't dump them on the user.

3. **Triage the whole list.** Give every idea exactly one verdict plus a one-line reason — a line split in step 1 is several ideas here, and each part gets its own verdict:

   - **Promote** — worth doing, goes to `/plan-task`.
   - **Merge** — the same idea as another listed one, or a fragment of it; name which, and which absorbs which.
   - **Fold** — already covered by, or belongs inside, an existing work item; name the item.
   - **Defer** — real but not now; state the trigger that should revive it, not just "later."
   - **Kill** — state the reason: solved already, solves a problem the project doesn't have, cost clearly exceeds value, or contradicts a documented direction.

   Stay cheap here — no codebase investigation, no per-idea interrogation. Present the verdicts as a table and let the user overturn any of them. **This is a gate**: proceed on their say-so, not before. If nothing survives triage, there is nothing to deepen — skip to step 8 and report. That is a successful run, not a failed one.

4. **Challenge the survivors.** Now go deep, one promoted idea at a time. Press each on the points in *The challenge* below. Ask via `AskUserQuestion`, batched per idea, and only where the answer would change the work — an idea the survey already settled needs no question. Demoting is still legal here: an idea that can't survive its own questions goes back to the step-3 table as a Kill, Fold, Defer, or Merge. Say so and move on. If every survivor is demoted here, skip to step 8 and report — as in step 3, that is a successful run, and steps 5–7 need at least one brief to be meaningful.

5. **Shape each survivor into a brief.** One brief per promoted idea: the problem and who has it, the smallest version that delivers most of the value, explicit non-goals, the constraints that bind it, how you'd know it worked, and its dependencies on other promoted ideas or existing work items. A brief is the *input* to a task, not a task — no acceptance criteria, no decomposition, no implementation plan. That's `/plan-task`'s job and duplicating it here is how the two drift apart.

6. **Order and approve.** Present every brief with the order to plan them in, driven by the dependencies found in step 5. Get the user's explicit go-ahead for the whole set. **Nothing reaches the work-item source before this.** If they withhold it, revise the briefs and re-present; if they'd rather not proceed at all, skip to step 8 and report.

7. **Chain into `/plan-task`.** For each promoted idea in that order, follow `~/.claude/skills/plan-task/SKILL.md` with the brief as its `$ARGUMENTS`. `/plan-task` is the route regardless of size — a brief that resolves to a single task still goes through it and simply yields a one-item set. Scale its ceremony to the brief, but don't file around it.

   Pass forward what's already settled — the work-item source, the shape its items take, and its lifecycle, the survey from step 2 and the overlap verdicts from step 3, and the decisions from step 4 — so `/plan-task` targets its investigation instead of re-interrogating the user on questions this skill already answered. Its own gates are real gates: surface the plan, wait for approval, and never write to the source before its create step. Tasks created for earlier ideas are existing work by the time a later idea is planned, so treat them as such — and if `/plan-task`'s duplicate guard resolves an idea into existing work or ends its run, record that outcome for step 8 and continue with the next idea. If the user rejects the plan for one idea, that idea returns to unplanned and the chain continues with the next. If the user stops the chain, stop and go to step 8.

8. **Report.** One block, formatted for pasting back into wherever the list lives: every original idea, its verdict, and its one-line reason. Report a line split in step 1 under its original line, one sub-entry per part with its own verdict, so every input line is still findable. Every promoted idea carries an explicit outcome: the identifiers or links of the tasks it became, or — where step 7 produced none — *promoted, not planned (plan rejected)*, *promoted, not planned (set not approved)*, *promoted, not planned (folded into existing work)*, *promoted, not reached (chain stopped)*, or *promoted, not planned (<reason>)* for any other run that ended without creating tasks. A promoted idea never appears with a blank outcome. Close with an optional **Gaps** section for anything the survey turned up that nobody listed (per the rule below) — clearly separated, so it reads as a note rather than a verdict. This is the only durable record of the ideas that weren't promoted — make it complete enough to stand alone.

## The challenge

Challenging is the point of the depth pass. Push on:

- **Problem vs. solution.** The idea is usually stated as a solution. What's the problem behind it? Is that problem real, current, and the user's?
- **The null option.** What actually happens if this never gets built? If the honest answer is "nothing much," that's a Kill or Defer.
- **Smallest useful version.** Which part carries most of the value? YAGNI applies — prefer clean, narrow scope over speculative generality.
- **Prior art.** Does the project, its stack, or a tool already in use solve this? Reusing an existing pattern beats a new one.
- **What it forecloses.** What does this make harder later? What does it commit the project to?
- **Success signal.** How would the user know it worked? An idea with no observable outcome is usually underspecified, not unmeasurable.
- **Fit.** Does it pull in the direction the project's documentation says it's going? If not, that's worth saying plainly.

Push on real grounds, once, and say what you actually think. When the user has heard the objection and decided anyway, that's their call — record it and proceed with the full idea.

## Rules

- Never add ideas the user didn't list. A gap you spot during the survey is worth *mentioning* in the report's Gaps section; it is not an idea to shape.
- Never silently drop an idea. Every line in the input gets a verdict in the output.
- Kill and Defer are successful outcomes. A run that kills four of six ideas did its job.
- Keep it proportionate: scale the ceremony, never the gate. Two ideas warrant a one-line verdict each, presented as a short list rather than a table — but the step-3 gate still stands.
- Honor every project hard rule and gate — plan approval before any file change, and never commit or push without explicit instruction.

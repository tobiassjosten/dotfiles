---
name: ship
description: Gate the outstanding change on verification (lint/tests/build must be green) and then a fanned-out code review — skipped when /polish already converged on exactly this diff — and, only if both pass, commit it via /commit and advance its task to its terminal state (where the source has one). A red check, any Issue, or a defect-level Nitpick stops the ship and flags it; preference-level polish rides along as advisory and does not block. Pass `review` (`/ship review`) to force the review even after a convergence. The counterpart to /forge on the far side of the commit boundary.
disable-model-invocation: true
---

# Ship

Take the change already sitting in the working tree and send it out the door — but only if it passes two gates first. First **verify** it is green (lint, tests, build); reviewing or shipping broken code is pointless. Then **review** it with the fan-out of parallel `code-reviewer` roles — unless `/polish` already recorded convergence on this exact diff — the same base and the same working tree — in which case that record stands in for the review. If verification is red, or the review surfaces a **blocking finding** — any Issue, or a Nitpick marked `(defect)` (cosmetic but *wrong*) — **stop and flag it**; do not fix, do not commit. A green change whose only review findings are `(preference)` polish passes through to `/commit` — those nits ride along as advisory rather than blocking — after which the associated task is advanced to its Done/terminal state.

This is the automated far half of your workflow: `/forge` selects, implements, review-hardens, and leaves a task **In Review**; `/ship` re-checks quality at the last moment, commits, and closes the task out. It is a **gate and a finalizer, not a fixer** — when it stops, fixing is the user's call (`/polish`, manual edits, etc.). It gates on what is genuinely *wrong* — the defect bar — which is exactly the bar `/polish` converges on. So when `/polish` has already recorded convergence on this exact diff, a second full review would only re-sample the same change; `/ship` trusts the record and skips it. That rests on `/polish` recording only a diff its own full fan-out read: a clean round that applied fixes does not converge there, precisely so the record never names a tree no review saw. The record names a *diff* — base and snapshot both — because either half can move on its own: an edit changes the tree, and `git reset --soft` or a branch checkout changes the base while leaving every file untouched. A change to either brings the review back.

## Argument

An optional argument may follow the command: `$ARGUMENTS`. The only accepted value is `review`, which runs the review even when a convergence record matches this diff. Anything else is an error — say so and stop, without verifying, reviewing or committing. A forcing argument that fails *open* would ship unreviewed on a typo, which is the wrong direction for a gate that ends in `git push`.

## Composed pieces

This skill only adds orchestration on top of existing pieces — they remain the single source of truth:

- **The green-baseline check** — which verification checks to run — comes from `~/.claude/skills/verify-core.md` (shared with `/polish`). This skill's disposition on a red check is to stop the ship, not to fix.
- **Reviewing** follows `~/.claude/skills/review-fanout.md` in full mode — parallel `code-reviewer` agents, coverage-checked and merged — against the shared bar in `~/.claude/skills/review-core.md`. Do not inline `/review`, which is interactive and fixes; `/ship` needs a non-interactive verdict and never fixes. The fan-out's review ledger (`$(git rev-parse --absolute-git-dir)/review/ledger.md`) tells it what is already settled and whether `/polish` converged on this exact diff.
- **Committing** comes from `/commit` (`~/.claude/skills/commit/SKILL.md`): it groups the outstanding changes into atomic Conventional Commits, pushes, and rebases on a rejected push. It sets `disable-model-invocation: true`, so it can't be invoked through the Skill tool — **read and follow that `SKILL.md` directly** in this (main-loop) context.
- **Task lifecycle** — `/commit` is deliberately barred from the tracker, and `/forge` defers moving a task to Done to the project's **Finish gate**. `/ship` *is* that gate: after a successful commit it advances the task per the project's documented lifecycle, generically over the work-item source (the same sources `/next` enumerates).

## Procedure

### 1. Precondition — there must be something to ship

Ask the snapshot, not `git status`: there is something to ship when `sh ~/.claude/skills/review-diff.sh --tree` differs from `git rev-parse -q --verify 'HEAD^{tree}'` (a repo with no commits is shippable too). If the two hashes match, there is nothing to commit — tell the user and stop. (This agrees with the script's own outstanding test by construction. `git status` answers a different question — it honours `status.showUntrackedFiles=no` and reports a dirty submodule whose gitlink has not moved — so a precondition built on it both blocks changes the fan-out would have reviewed and passes trees the fan-out then treats as clean. One case still diverges: an unborn `HEAD` over an empty tree — a repo with no commits, or a `--orphan` checkout with nothing in the worktree — reads as shippable here and the fan-out then reports `MODE: none`, in which case there is nothing to ship, so stop there.) `/ship` gates and commits the *outstanding* change; it does not review a clean branch diff the way `/review` does.

### 2. Verification gate — get to green first

Reviewing or shipping broken code is pointless. Before the review, determine and run the verification set per `~/.claude/skills/verify-core.md`.

- **Any check red → stop and flag.** Report which checks failed and their output; do **not** review, commit, or touch the task tracker. Getting the change green is the user's call (fix it, or run `/polish`, then `/ship` again). This is a normal, expected exit — not a failure of the skill.
- **All green → proceed to step 3.**

### 3. Review gate — one review or a convergence record, defect bar

**First, check for a convergence record.** Get the current snapshot with `sh ~/.claude/skills/review-diff.sh --tree` and the current base with `git rev-parse -q --verify 'HEAD^{tree}'` (empty when there is no `HEAD` yet, in which case no record can match — review), and look in the ledger for a `converged:` entry whose `tree=` matches the first **and** whose `from=` matches the second. Both must match: the change under review is a diff, and the snapshot alone survives anything that moves `HEAD` without touching files — a `git reset --soft HEAD~3` would otherwise let this gate skip the review and push three commits nobody read. If such an entry is there and the user did not pass `review`, **skip the review**: the gate passes on the strength of that record, with no findings to report. Say so in the summary, naming the entry. Skip the review **only** when a `converged:` entry matches both hashes and the user did not pass `review`. In every other case — no ledger, no `converged:` entry in it, either hash different, or `review` passed — run the fan-out.

**Otherwise, run the fan-out** in full mode per `review-fanout.md`. It returns one merged list — Issues then Nitpicks, each carrying a `(defect)` / `(preference)` marker and a fix — plus the plan and coverage. An **incomplete** review (a reviewer that never finished after its retry) cannot pass the gate: name the missing role, then present the § 6 Summary with **Gate** *stopped on an incomplete review* — no verdict was reached, nothing was committed — and close by saying that re-running `/ship` reviews afresh, or `/polish` first if the missing slice matters.

A single review is sufficient: this skill does not mutate the diff, so there is nothing to re-review.

**Evaluate with the defect bar.** `/ship` gates on what is *wrong*, not on taste. A finding is **blocking** if it is any **Issue**, or a **Nitpick marked `(defect)`** (cosmetic but wrong — a malformed string, an off-by-one, a comment that misstates the code). A finding is **non-blocking** if it is a **Nitpick marked `(preference)`** (a genuine but lateral improvement — extract a helper, rename, reorder). This deliberately differs from `/polish`, whose job is to sweep preferences too; `/ship` is a correctness gate, not a second taste pass, so it will not re-block a freshly-polished change over a fresh preference-level nit. (An Issue always blocks regardless of its marker — Issues are consequential by definition, so err toward blocking.)

- **Any blocking finding → stop and flag.** Present the merged findings verbatim (both sections, one continuous numbering, *including* the `(preference)` Nitpicks so the picture is complete), then the § 6 Summary with **Gate** blocked, and halt. Do **not** fix anything, do **not** commit, do **not** touch the task tracker. Close with a short line telling the user the ship is blocked on the defect(s) and that fixing is theirs to drive (e.g. run `/polish` to loop the fix-review cycle, or fix directly, then `/ship` again). This is the skill's normal, expected exit — not a failure.
- **No blocking findings → proceed to step 4.** If the review surfaced only `(preference)` Nitpicks, they ride along unfixed as advisory — carry them into the summary; do not fix them here (that is `/polish`'s job).

### 4. Commit

The review surfaced no blocking findings (or was skipped on a convergence record). Commit the change by following `~/.claude/skills/commit/SKILL.md` end to end — atomic Conventional Commits, then push (with its fetch-rebase-retry handling on a rejected push). Honor its rules: never `git add -A`/`.`, never amend, never bypass a failing pre-commit hook — if a hook fails, stop and report, and do **not** proceed to the task step (nothing shipped).

Once the push succeeds, delete the whole review directory (`rm -rf "$(git rev-parse --absolute-git-dir)/review"`) and say so in the summary — it holds the user's own `settled:`/`rejected:`/`decided:` calls, so its removal should be no more silent than its writes. The ledger's decisions belonged to the change that just shipped, and stale entries would suppress findings in the next one; the run directories under it hold full diffs of that change, including any untracked file the snapshot picked up, and have no use once it is out the door. Note that this removes the prepared diffs only: `review-diff.sh` snapshots the tree with `git add -A`, so untracked files' contents are also loose objects in `.git/objects`, unreachable but readable until a pruning `git gc`. It is not a secret-scrubbing step.

### 5. Finish gate — advance the task

Only after the commit **and push** succeed. Determine whether the change corresponds to a task in the project's work-item source (the sources `/next` enumerates: `TODO.md`, a per-task-file directory, a Backlog.md board, or an MCP issue tracker). If the project documents a task lifecycle (e.g. `docs/process/task-workflow.md`, CLAUDE.md, Backlog instructions), **follow its Finish gate exactly** — typically: append a final summary note to the task and move it to its terminal state (Done / closed).

- **Backlog.md board** — `backlog task edit <id> --append-notes "…"` then `-s Done`, per the project's documented lifecycle.
- **Issue tracker (MCP)** — transition the issue to its done/closed state.
- **`TODO.md` / per-task file** — these are typically already cleared by `/next` when the task was implemented; only act if the project's lifecycle says otherwise.

If no task is associated, or the source is ambiguous, say so and skip this step rather than guessing — do not invent or move an unrelated task.

### 6. Summary

Present, in the conversation:

- **Verification** — the final pass/fail state of each check in the verification set (named).
- **Gate** — passed (shipped), passed on a convergence record (name the ledger entry — no review ran), blocked, or stopped on an incomplete review (name the missing role; no verdict was reached). Whenever a review ran: give its plan and coverage line (thin coverage is deliberately pushed into the plan line, and a pass is the moment the user is least likely to see it otherwise), and list any `(preference)` Nitpicks it surfaced — on a pass those rode along as advisory and were **not** fixed, so note them for `/polish` or the user. If blocked, add the blocking findings (Issues and `(defect)` Nitpicks) with their count. If a `converged:` entry was present but did not match, say so and name which half moved — the tree (an edit) or the base (a commit, `git reset`, a branch checkout) — so a full review after a converged `/polish` reads as explained rather than as the skip having failed. On the convergence path say plainly that no review ran this time and there are no findings from it; the converging `/polish` run's preference fixes are in that skill's summary, not re-listed here.
- **Review directory** — deleted after the push, naming the path; or, on any exit before that, left in place with its ledger entries, which the user should delete if they are not going to `/ship` this change.
- **Commits** — when shipped, the `git log --oneline` of the new commits and whether the push succeeded (or diverged and needs manual resolution, per `/commit`).
- **Task** — the task advanced to its terminal state, or a note that none applied / it was skipped. On a repo-backed source (a Backlog.md board, a per-task file) that write is an uncommitted change in the working tree, made after the push: say so, so the user knows to commit or revert it rather than meeting it as a surprise on their next run.
- **Remaining steps** — anything that still has to happen before the work is *actually* done, beyond the code that just shipped. Draw from this conversation's main context and the nature of the change itself. For each item, say plainly **what** must happen and **who/where** (you vs. the user vs. another system). This list is the whole reason `/ship` runs in main context rather than being delegated — surface it prominently. If there is genuinely nothing left, say so explicitly ("Nothing outstanding — the shipped commit completes the work") rather than omitting the section.
  - **Blocking** — must happen before the change is safe/complete (e.g. run the migration before this deploys, configure the required secret).
  - **Follow-up** — should happen but doesn't block (e.g. file a ticket for the deferred refactor, update docs elsewhere).

## Rules

- **Defect bar.** Any Issue, or any Nitpick marked `(defect)`, blocks the ship. `(preference)` Nitpicks do **not** block — they are reported as advisory and left for `/polish` or the user. `/polish` converges on this same bar (and additionally fixes the preferences it finds), which is what makes its convergence record trustworthy here.
- **Never fix.** `/ship` is a gate; on any blocking finding it stops and flags, and it never fixes even the preference-level nits it lets ride. Fixing is the user's decision (`/polish` or manual).
- **Order is fixed:** verify → (green) → review or convergence record → (no blocking findings) → commit+push → delete the review directory (and report it) → advance task. Never review broken code, never commit while a defect stands, never advance the task before the commit lands. Verification always runs — a convergence record skips only the review.
- **However this skill ends, name the review directory.** Every exit, from the argument check onward, may have left `$(git rev-parse --absolute-git-dir)/review/` behind — a bad argument, nothing outstanding, a red check, an incomplete review, a blocking finding, a failed pre-commit hook, a push that diverged and needs manual resolution — and the blocking exit is the gate's most common ending. Each of them closes by naming the path, saying whether it was deleted, and telling the user to delete it themselves unless a later `/ship` will. Stale ledger entries silently suppress real findings in the next change, so the directory is never left unmentioned.
- Honor every project Hard Rule and gate (`CLAUDE.md`); the task step follows the project's documented Finish gate.

---
name: ship
description: Gate the outstanding change on verification (lint/tests/build must be green) and then a fanned-out code review — skipped when /polish already converged on exactly this diff, or when the argument says to ship without one — and, only if both pass, commit it via /commit and advance its task to its terminal state (where the source has one). A red check stops the ship, and so does any blocking finding — by default any Issue or defect-level Nitpick; preference-level polish rides along as advisory. Takes an optional free-text argument setting two dials: `review` forces the review even after a convergence, while `now` / `right away` / `immediately` skips it outright (verification still runs); `don't block on nitpicks` / `ignore nitpicks` lowers the bar so that only Issues block. With no argument both keep their defaults, and an argument it cannot confidently read stops the run. The counterpart to /forge on the far side of the commit boundary.
disable-model-invocation: true
---

# Ship

Take the change already sitting in the working tree and send it out the door — but only if it passes two gates first. First **verify** it is green (lint, tests, build); reviewing or shipping broken code is pointless — and verification runs on every path, whatever argument was passed. Then **review** it with the fan-out of parallel `code-reviewer` roles — unless `/polish` already recorded convergence on this exact diff — the same base and the same working tree — in which case that record stands in for the review, or the user asked outright to ship without one (§ *Arguments*). If verification is red, or the review surfaces a **blocking finding** — by default any Issue, or a Nitpick marked `(defect)` (cosmetic but *wrong*) — **stop and flag it**; do not fix, do not commit. A green change with no blocking finding passes through to `/commit` — the non-blocking nits ride along as advisory — after which the associated task is advanced to its Done/terminal state.

This is the automated far half of your workflow: `/forge` selects, implements, review-hardens, and leaves a task **In Review**; `/ship` re-checks quality at the last moment, commits, and closes the task out. It is a **gate and a finalizer, not a fixer** — when it stops, fixing is the user's call (`/polish`, manual edits, etc.). It gates on what is genuinely *wrong* — the defect bar — which is exactly the bar `/polish` converges on. So when `/polish` has already recorded convergence on this exact diff, a second full review would only re-sample the same change; `/ship` trusts the record and skips it. That rests on `/polish` recording only a diff its own full fan-out read: a clean round that applied fixes does not converge there, precisely so the record never names a tree no review saw. The record names a *diff* — base and snapshot both — because either half can move on its own: an edit changes the tree, and `git reset --soft` or a branch checkout changes the base while leaving every file untouched. A change to either brings the review back. The skip dial (§ *Arguments*) is a different animal and rests on nothing: it does not assert that a review happened, it is the user taking the gate off, which is why it is reported as such rather than as a pass.

## Arguments

An optional free-text argument may follow the command: `$ARGUMENTS`. It sets two independent dials — whether the review runs at all, and how strictly its findings are read. With no argument both keep their defaults: review unless a convergence record matches, and the defect bar.

**Review dial** — what step 3 does:

- **default** — no argument. Run the fan-out unless a `converged:` ledger entry matches this exact diff.
- **force** — `review`. Run the fan-out even when a convergence record matches.
- **skip** — `now`, `right away`, `immediately`, `just ship it`, `no review`, `skip the review`. Run no review at all; the gate passes on the user's word alone.

**Blocking bar** — how step 3 reads the findings it got:

- **defects** — the default, and what `only check for defects`, `skip preferences` or `only defects` resolve to. Any Issue blocks, and so does any Nitpick marked `(defect)`. `(preference)` Nitpicks are advisory.
- **issues** — `don't block on nitpicks`, `ignore nitpicks`, `issues only`. Only Issues block; every Nitpick is advisory, the `(defect)` ones included.

There is no dial *above* the default. Blocking on preference-level polish is `/polish`'s bar, and `/polish` fixes those findings rather than stopping on them — which is the useful thing to do with them and not something a gate should be asked to do. Note also that `only check for defects` and `skip preferences` name the default rather than changing it: preference nits never blocked. Their one real effect is on reporting (§ 3).

**Resolve by meaning, not by literal match.** The phrasings above are examples of two intents, not a grammar — `asap` and `without the review` are the skip dial; `nits are fine` and `don't stop for nitpicks` are the `issues` bar. Both dials may appear at once (`/ship now ignore nitpicks`); with the review skipped the bar is simply inert, since there are no findings to weigh, so say that rather than calling it an error.

**Fail closed on everything else.** An argument that does not confidently map to one of those intents is an error: say what was not understood, name the recognized intents, and stop — without verifying, reviewing or committing. That covers a vague `fast` or `quickly` (speed is not consent to skip a gate), a plausible typo like `reviwe` or `nowish`, and `review` together with a skip phrase, which is a contradiction rather than an ambiguity. **Partial understanding is not understanding:** if any part of the argument fails to map, none of it applies — do not run with the half that read cleanly. A forcing argument that fails *open* would ship unreviewed on a typo, which is the wrong direction for a gate that ends in `git push`; a loosening argument that fails open is the same hazard at a smaller angle.

**Resolve first, and say what you resolved.** Do this before § 1, so a bad argument costs nothing and cannot be half-applied by a step that already ran. Then state both dials in one line — e.g. `review: skipped at your request; bar: defects (default)` — the way `/polish` announces its resolved round limits. A phrase that resolved to a default is exactly the case the user needs to see, since nothing else about the run would reveal it.

## Composed pieces

This skill only adds orchestration on top of existing pieces — they remain the single source of truth:

- **The green-baseline check** — which verification checks to run — comes from `~/.claude/skills/verify-core.md` (shared with `/polish`). This skill's disposition on a red check is to stop the ship, not to fix.
- **Reviewing** follows `~/.claude/skills/review-fanout.md` in full mode — parallel `code-reviewer` agents, coverage-checked and merged — against the shared bar in `~/.claude/skills/review-core.md`. Do not inline `/review`, which is interactive and fixes; `/ship` needs a non-interactive verdict and never fixes. The fan-out's review ledger (`$(git rev-parse --absolute-git-dir)/review/ledger.md`) tells it what is already settled and whether `/polish` converged on this exact diff.
- **Committing** comes from `/commit` (`~/.claude/skills/commit/SKILL.md`): it groups the outstanding changes into atomic Conventional Commits, pushes, and rebases on a rejected push. It sets `disable-model-invocation: true`, so it can't be invoked through the Skill tool — **read and follow that `SKILL.md` directly** in this (main-loop) context.
- **Task lifecycle** — `/commit` is deliberately barred from the tracker, and `/forge` defers moving a task to Done to the project's **Finish gate**. `/ship` *is* that gate: after a successful commit it advances the task per the project's documented lifecycle, generically over the work-item source (the same sources `/next` enumerates).

## Procedure

### 1. Precondition — there must be something to ship

(The arguments are already resolved and announced by now, per § *Arguments*; an argument that did not read cleanly stopped the run before this step.)

Ask the snapshot, not `git status`: there is something to ship when `sh ~/.claude/skills/review-diff.sh --tree` differs from `git rev-parse -q --verify 'HEAD^{tree}'` (a repo with no commits is shippable too). If the two hashes match, there is nothing to commit — tell the user and stop. (This agrees with the script's own outstanding test by construction. `git status` answers a different question — it honours `status.showUntrackedFiles=no` and reports a dirty submodule whose gitlink has not moved — so a precondition built on it both blocks changes the fan-out would have reviewed and passes trees the fan-out then treats as clean. One case still diverges: an unborn `HEAD` over an empty tree — a repo with no commits, or a `--orphan` checkout with nothing in the worktree — reads as shippable here and the fan-out then reports `MODE: none`, in which case there is nothing to ship, so stop there.) `/ship` gates and commits the *outstanding* change; it does not review a clean branch diff the way `/review` does.

### 2. Verification gate — get to green first

Reviewing or shipping broken code is pointless. Before the review — and before the commit on a path that skips the review — determine and run the verification set per `~/.claude/skills/verify-core.md`.

- **Any check red → stop and flag.** Report which checks failed and their output; do **not** review, commit, or touch the task tracker. Getting the change green is the user's call (fix it, or run `/polish`, then `/ship` again). This is a normal, expected exit — not a failure of the skill.
- **All green → proceed to step 3.**

### 3. Review gate — one review, a convergence record, or a requested skip

**If the review dial is `skip`, there is no review gate.** Do not look for a convergence record, do not prepare a diff (`review-diff.sh` with no arguments, which is what creates the review directory — the `--tree` query from § 1 is all this path needs), do not spawn reviewers: the user took the gate off, and it passes with no findings. Go to step 4, and carry into the summary that the change shipped **unreviewed** on their instruction — unlike the convergence path, nothing here vouches for the diff. A `review/` directory left behind by an earlier `/polish` or `/review` is untouched by this path but still belongs to this change: step 4 deletes it after the push, and the summary still names it.

**Next, check for a convergence record.** Get the current snapshot with `sh ~/.claude/skills/review-diff.sh --tree` and the current base with `git rev-parse -q --verify 'HEAD^{tree}'` (empty when there is no `HEAD` yet, in which case no record can match — review), and look in the ledger for a `converged:` entry whose `tree=` matches the first **and** whose `from=` matches the second. Both must match: the change under review is a diff, and the snapshot alone survives anything that moves `HEAD` without touching files — a `git reset --soft HEAD~3` would otherwise let this gate skip the review and push three commits nobody read. If such an entry is there and the review dial is not `force`, **skip the review**: the gate passes on the strength of that record, with no findings to report. Say so in the summary, naming the entry. Skip the review on a record **only** when a `converged:` entry matches both hashes and the dial is not `force`. In every other case — no ledger, no `converged:` entry in it, either hash different, or `force` — run the fan-out. `force` overrides this record and nothing else; it is not what the skip dial is measured against.

**Otherwise, run the fan-out** in full mode per `review-fanout.md`. It returns one merged list — Issues then Nitpicks, each carrying a `(defect)` / `(preference)` marker and a fix — plus the plan and coverage. An **incomplete** review (a reviewer that never finished after its retry) cannot pass the gate: name the missing role, then present the § 6 Summary with **Gate** *stopped on an incomplete review* — no verdict was reached, nothing was committed — and close by saying that re-running `/ship` reviews afresh, or `/polish` first if the missing slice matters.

A single review is sufficient: this skill does not mutate the diff, so there is nothing to re-review.

**Evaluate against the resolved bar.** `/ship` gates on what is *wrong*, not on taste. On the default **`defects`** bar a finding is **blocking** if it is any **Issue**, or a **Nitpick marked `(defect)`** (cosmetic but wrong — a malformed string, an off-by-one, a comment that misstates the code), and **non-blocking** if it is a **Nitpick marked `(preference)`** (a genuine but lateral improvement — extract a helper, rename, reorder). This deliberately differs from `/polish`, whose job is to sweep preferences too; `/ship` is a correctness gate, not a second taste pass, so it will not re-block a freshly-polished change over a fresh preference-level nit.

On the **`issues`** bar, only Issues block — a `(defect)` Nitpick joins the preferences as advisory. An **Issue blocks at every bar**, whatever its marker: Issues are consequential by definition, so err toward blocking. The dial moves only what *blocks*. It never reaches the reviewers — their brief and their bar (`review-core.md`) are the same either way — so these are the same findings read more loosely, and anything the lowered bar let past is something the user chose to carry, which the summary says out loud.

- **Any blocking finding → stop and flag.** Present the merged findings verbatim (both sections, one continuous numbering, *including* the non-blocking ones so the picture is complete), then the § 6 Summary with **Gate** blocked, and halt. Do **not** fix anything, do **not** commit, do **not** touch the task tracker. Close with a short line telling the user the ship is blocked on the defect(s) and that fixing is theirs to drive (e.g. run `/polish` to loop the fix-review cycle, or fix directly, then `/ship` again). This is the skill's normal, expected exit — not a failure.
- **No blocking findings → proceed to step 4.** Whatever the review surfaced below the bar rides along unfixed as advisory — carry it into the summary; do not fix any of it here (that is `/polish`'s job).

**Reporting stays complete, with one exception.** Every finding reaches the summary; nothing is dropped merely because it could not block. The exception is a phrasing that explicitly asked to disregard a class — `skip preferences`, `ignore nitpicks` — in which case that class is given as a count rather than a list ("3 preference nitpicks, not listed"). It is still never fixed, and an Issue is never condensed away, whatever the argument said.

### 4. Commit

The review surfaced no blocking findings (or was skipped — on a convergence record, or at the user's request). Commit the change by following `~/.claude/skills/commit/SKILL.md` end to end — atomic Conventional Commits, then push (with its fetch-rebase-retry handling on a rejected push). Honor its rules: never `git add -A`/`.`, never amend, never bypass a failing pre-commit hook — if a hook fails, stop and report, and do **not** proceed to the task step (nothing shipped).

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
- **Gate** — passed (shipped), passed on a convergence record (name the ledger entry — no review ran), passed with no review at all (skipped at the user's request), blocked, or stopped on an incomplete review (name the missing role; no verdict was reached). Name the resolved bar whenever it was not the default. Whenever a review ran: give its plan and coverage line (thin coverage is deliberately pushed into the plan line, and a pass is the moment the user is least likely to see it otherwise), and list the findings it surfaced below the bar — on a pass those rode along as advisory and were **not** fixed, so note them for `/polish` or the user; a class the argument asked to disregard is given as a count instead (§ 3). On a lowered bar, say which of those advisory findings would have blocked at the default — a `(defect)` Nitpick shipped under `ignore nitpicks` is precisely what that argument bought, and the user should see what they bought. If blocked, add the blocking findings with their count. If a `converged:` entry was present but did not match, say so and name which half moved — the tree (an edit) or the base (a commit, `git reset`, a branch checkout) — so a full review after a converged `/polish` reads as explained rather than as the skip having failed. On the convergence path say plainly that no review ran this time and there are no findings from it; the converging `/polish` run's preference fixes are in that skill's summary, not re-listed here. On the **skip** path say the same — no review ran — and add why: the user asked to ship now, so, unlike the convergence path, nothing vouches for this diff and any `converged:` entry in the ledger was never consulted.
- **Review directory** — deleted after the push, naming the path; or, on any exit before that, left in place with its ledger entries, which the user should delete if they are not going to `/ship` this change.
- **Commits** — when shipped, the `git log --oneline` of the new commits and whether the push succeeded (or diverged and needs manual resolution, per `/commit`).
- **Task** — the task advanced to its terminal state, or a note that none applied / it was skipped. On a repo-backed source (a Backlog.md board, a per-task file) that write is an uncommitted change in the working tree, made after the push: say so, so the user knows to commit or revert it rather than meeting it as a surprise on their next run.
- **Remaining steps** — anything that still has to happen before the work is *actually* done, beyond the code that just shipped. Draw from this conversation's main context and the nature of the change itself. For each item, say plainly **what** must happen and **who/where** (you vs. the user vs. another system). This list is the whole reason `/ship` runs in main context rather than being delegated — surface it prominently. If there is genuinely nothing left, say so explicitly ("Nothing outstanding — the shipped commit completes the work") rather than omitting the section.
  - **Blocking** — must happen before the change is safe/complete (e.g. run the migration before this deploys, configure the required secret).
  - **Follow-up** — should happen but doesn't block (e.g. file a ticket for the deferred refactor, update docs elsewhere).

## Rules

- **Defect bar by default.** Any Issue, or any Nitpick marked `(defect)`, blocks the ship. `(preference)` Nitpicks do **not** block — they are reported as advisory and left for `/polish` or the user. `/polish` converges on this same bar (and additionally fixes the preferences it finds), which is what makes its convergence record trustworthy here. The argument can lower the bar one step, to Issues only (§ *Arguments*), and can skip the review outright; neither changes what the reviewers do, and both are named in the summary.
- **Never fix.** `/ship` is a gate; on any blocking finding it stops and flags, and it never fixes even the preference-level nits it lets ride. Fixing is the user's decision (`/polish` or manual).
- **Order is fixed:** resolve the arguments → verify → (green) → review, convergence record or requested skip → (no blocking findings) → commit+push → delete the review directory (and report it) → advance task. Never review broken code, never commit while a blocking finding stands, never advance the task before the commit lands. **Verification always runs** — a convergence record and the skip dial both skip only the review, and no argument bypasses a check.
- **An argument that does not read cleanly stops the run** before verification, and never applies in part (§ *Arguments*). Dials only ever loosen what blocks or skip the review; none of them makes `/ship` fix, amend, or push past a failing check.
- **However this skill ends, name the review directory.** Every exit, from the argument check onward, may have left `$(git rev-parse --absolute-git-dir)/review/` behind — a bad argument, nothing outstanding, a red check, an incomplete review, a blocking finding, a failed pre-commit hook, a push that diverged and needs manual resolution — and the blocking exit is the gate's most common ending. Each of them closes by naming the path, saying whether it was deleted, and telling the user to delete it themselves unless a later `/ship` will. Stale ledger entries silently suppress real findings in the next change, so the directory is never left unmentioned.
- Honor every project Hard Rule and gate (`CLAUDE.md`); the task step follows the project's documented Finish gate.

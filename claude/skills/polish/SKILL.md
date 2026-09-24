---
name: polish
description: Harden the outstanding change with fanned-out reviews — parallel area and lens reviewers per round — fixing every finding by class with tests and a delta check after each round of fixes, until M consecutive rounds find no defects and have nothing left to fix (so all M read the same tree) or N rounds are spent. Accepts two optional numeric arguments (e.g. `/polish 5` or `/polish 5 2`): first is the round limit N (default 3), second is the consecutive-clean threshold M (default 1). Leaves the change reviewed, green, and uncommitted, and records convergence so /ship can skip a redundant re-review.
disable-model-invocation: true
---

# Polish

Take the change already sitting in the working tree and harden it until nothing a strict senior developer would call *wrong* remains — and fix every improvement found along the way. Each round is one complete, fanned-out review; each round of fixes is checked by a cheap delta review before the next round. This skill does not select, plan, or implement work, and it does not touch a task tracker. **Never commit** — the change is left reviewed and green for the user to `/commit` or `/ship`.

**Arguments.** Up to two may follow the command: `$ARGUMENTS`. Both are optional and both must be positive integers if provided:
- **First — round limit (N):** maximum number of full review rounds. Default: **3**.
- **Second — consecutive-clean threshold (M):** how many consecutive rounds must find no defects **and apply no fixes** to end the loop — so all M read the same tree. Default: **1**.

Resolve both before proceeding, and say the resolved values before the first round (e.g. "up to 3 rounds, ending on 1 round that finds no defects and applies no fixes") — the defaults are not what a user who has seen an older version expects. More than two arguments, a non-positive-integer argument, or M > N is an error — say so and stop.

Why the defaults are low: a fanned-out round covers the whole change, and every round of fixes is delta-checked, so a clean round is strong evidence on its own. Repeating identical full reviews mostly buys a different random sample of nitpicks. Note that a clean round which still applied fixes does not converge, and resets the counter (the *Decide* step in § 3) — the next round reviews the fixed tree — so a run that starts with preference nitpicks costs two rounds even at M=1. Use `/polish 4 2` (N first, then M) when you want an independent confirmation on top of that — `/polish 3 2` leaves no slack: a run that spends round 1 dirty needs both remaining rounds to come back clean *and* fix-free, so any second round of fixes exhausts N before M is met.

## Composed pieces

- **Reviewing:** `~/.claude/skills/review-fanout.md`, full mode, each round. Bar: `~/.claude/skills/review-core.md`.
- **Fixing:** `~/.claude/skills/review-fix.md` — snapshot, confirm, fix by class, test, re-verify, delta check.
- **Verification set:** `~/.claude/skills/verify-core.md`. On a red check, fix the change until green.
- **Ledger:** `review-fanout.md` § *The review ledger* — read by every reviewer; written here for escalation outcomes, rejected findings, decisions and convergence. It lives at `$(git rev-parse --absolute-git-dir)/review/ledger.md`, outside the tree, and belongs to this one change.

## Procedure

### 1. Precondition — there must be something to polish

Ask the snapshot, not `git status`: the tree is outstanding when `sh ~/.claude/skills/review-diff.sh --tree` differs from `git rev-parse -q --verify 'HEAD^{tree}'` (a repo with no commits at all is outstanding too). `git status` answers a *different* question — it honours `status.showUntrackedFiles=no` and reports a dirty submodule whose gitlink has not moved — so a precondition built on it both blocks changes the fan-out would have reviewed and passes trees the fan-out then treats as clean. This agrees with the script's own outstanding test by construction. (It is not identical to its every exit: an unborn `HEAD` over an empty tree — a repo with no commits, or a `--orphan` checkout with nothing in the worktree — reads as outstanding here, and the fan-out then reports `MODE: none`. Treat that the same way: there is nothing to polish, so stop and give the § 4 Summary marked *stopped before the loop*.)

If the tree is not outstanding, stop and give the § 4 Summary marked *stopped before the loop*: `/polish` hardens the change in the working tree, and on a clean tree `review-diff.sh` selects the branch diff instead (or, on the main branch, reports nothing to review), so the loop would review and then **edit** already-committed code. Reviewing a clean branch is `/review`'s job.

### 2. Green baseline

Determine and run the verification set per `verify-core.md`. If anything is red, fix **the change** until all pass. A check that was already red before this change and cannot be brought green within its scope is not `/polish`'s to repair: report it as pre-existing and stop, giving the § 4 Summary marked *stopped before the loop* (no rounds to list). This is an ending outside the loop's three. Widening into unrelated code to reach green would break this skill's own first Rule.

### 3. Rounds — up to N

Keep a consecutive-clean counter, starting at 0. For each round:

1. **Review.** Run the fan-out in full mode. An **incomplete** review (a role that never finished after its retry, per `review-fanout.md`) is not a round: do not fix it, do not count it against `N`, and do not dispose of it as clean or dirty. Stop the loop there and go straight to the § 4 Summary, marked neither converged nor capped — name the missing role, carry the findings the roles that did report found (classified against the ledger as in step 2, but fix nothing), and give the verification state and the Ledger line as usual. Never record convergence on a review that was never complete. (If the missing role's slice matters more than the wall-clock, re-running `/polish` after the stall is the user's call, not an unbounded retry here.)

2. **Classify.** A finding is **open** unless a *live* ledger entry already covers it — one whose `base=` equals this round's `FROM` (see `review-fanout.md` § *The review ledger*); an entry from an earlier change suppresses nothing. The round is **clean** when it has **no open defects** — no Issues and no `(defect)` Nitpicks. This is the same bar `/ship` gates on. Open `(preference)` Nitpicks do not make a round dirty, but they still get fixed.

3. **Confirm, then escalate the judgment calls once, batched.** Confirm the open findings first (per `review-fix.md` step 1) so the batch is complete: a finding that turns out to be wrong is rejected and recorded, not escalated, and confirmation is what surfaces the flip-flops and scope expansions that would otherwise arrive too late. Then put every genuine trade-off, ambiguous intent, scope expansion, and finding that would reverse an earlier decision to the user in a single `AskUserQuestion` for the round. Record each answer in the ledger (`settled:` when left as-is, `decided:` for a choice), stamped with `base=` the `FROM` from this round's `meta.txt` so the entry expires with the change it belongs to. Anything determinable from the code or docs is decided autonomously — note the inference in the summary. A judgment call that only appears later, while fixing or in the delta check, waits for the next round's batch rather than opening a second prompt.

4. **Fix everything else** per `review-fix.md` — every open finding, Issues and Nitpicks alike: snapshot, fix by class, pin behaviour with tests, write claims yourself, keep docs aligned. Then re-verify and run the delta check (up to 3 fix → check cycles). If the round had nothing open to fix, skip this step entirely.

5. **Decide.** A round **converges** only when three things hold: its review was clean, it applied no fixes, and the verification set is green. The dispositions below test the first two; green is an invariant rather than a check here, since § 2 establishes it and step 4 restores it after every round that applied fixes. The first two are what make the record honest — the reviewed tree and the current tree are then the same tree, which is exactly what `/ship` reads the record to mean. Match exactly one of the four round dispositions below, in this order; then apply the round-limit check that follows them.
   - **Delta check still reporting findings** after its 3 cycles (per `review-fix.md`) → checked first, and it overrides the branches below: the round is dirty whatever its review said. Reset the counter to 0, carry those findings forward, and never record convergence.
   - **Clean round that applied no fixes** → increment the counter. If it reached M: append a `converged:` entry in `review-fanout.md`'s ledger format, with `tree=` and `from=` taken from that round's `meta.txt` — the exact diff the fan-out read — and exit the loop.
   - **Clean round that applied fixes** whose delta check came back clean (the preference nitpicks a clean round still sweeps) → reset the counter to 0 and continue to the next round, which reviews the fixed tree. The counter measures consecutive reviews that found nothing wrong *with the tree as it now stands*; this round reviewed a tree that no longer exists, so it is not one of them. (It is not a dirty round either — say so in the summary.) Letting it increment would make `M` inert: at `M=2` the confirming round would be spent on the pre-fix tree, which is the opposite of what asking for a second opinion buys.
   - **Dirty round** → reset the counter to 0 and continue.

   Then, whichever matched: if the loop did not exit on convergence above and that was round **N**, stop. Do not claim convergence, carry the open findings into the summary, and say explicitly when the tree was delta-checked but never re-reviewed.

Track per round: the plan and coverage line, finding counts (Issues / Nitpicks, defects / preferences), what was fixed (including the extra locations each class sweep found), what was rejected and why, each escalation and its outcome, and each delta check's result.

### 4. Summary

- **Rounds** — one line per round: plan size, findings (Issues/Nitpicks, defects/preferences), fixes (with sweep extras), rejections, escalations and decisions, delta-check result. Say which ending applied: converged, hit the cap, stopped on an incomplete review, or stopped before the loop (nothing to polish, or a pre-existing red check outside the change's scope). List open findings for the cap and the stall; a pre-loop ending has no rounds to list, so say that instead.
- **Final round** — every item the final round surfaced, one condensed line each (category, file:line, gist), marked fixed / rejected / settled / open. On a pre-loop ending there is no final round; say so. A converged final round applied no fixes — that is what convergence means here — so any items it did surface were all rejected or settled; list those, since a rejection is exactly what the user may want to overturn. Then point at the last round that did apply fixes, if there was one, for the preference sweeps the loop made on its way there.
- **Verification** — each check in the set and its state. On the § 1 pre-loop exits the set was never determined, so say that instead; on the § 2 red-baseline exit, name the check that was red.
- **Ledger** — the path, every entry this run appended (`settled:`, `rejected:`, `decided:`, `converged:`), and any pre-existing entries the rounds ignored as belonging to an earlier change. The ledger silently suppresses matching findings in every later review, so neither its writes nor its suppressions are ever invisible.
- **Next step** — on convergence: the change is reviewed and green; the next step is `/ship`, which reuses the convergence record and skips its own review, or `/commit`, which commits *and pushes* but does no review and no task update. On the cap: the open findings listed above still stand, and `/ship` will block on any defect among them. On a stalled review: the stalled round fixed nothing, the findings its completed roles reported still stand, and re-running `/polish` reviews the same tree again. On a pre-loop ending: nothing was reviewed or fixed — if there was nothing outstanding, there is nothing to harden and a committed change belongs to `/review`; if the baseline was red, repair the named check outside this change's scope and run `/polish` again. In every case the ledger belongs to this change alone: `/ship` deletes it (with the rest of `$(git rev-parse --absolute-git-dir)/review`) after it pushes. After any other ending — a hand `/commit`, or an abandoned change — tell the user to delete that directory themselves, or stale entries will suppress real findings in the next change.

## Rules

- Fix autonomously within the change's scope; escalate judgment calls; when unsure whether something is inferable, ask.
- Fix by class, never by instance. A finding that recurs in a new location means the previous sweep was incomplete — widen the search, don't just patch the new spot.
- The round limit is a hard ceiling; never "one more round".
- **However this skill ends, name the review directory.** Every exit — the argument check, the precondition, a `MODE: none` stop, a pre-existing red baseline, any of the three loop endings — names `$(git rev-parse --absolute-git-dir)/review/` if it exists, says whether anything was written to it, and says who deletes it. A ledger left there suppresses findings in any delta-mode round and in every review of a change made on the same `HEAD`, so it is never left unmentioned.
- **Never commit or push.**

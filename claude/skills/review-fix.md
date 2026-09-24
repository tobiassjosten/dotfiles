# Applying review findings (shared core)

How `/review` and `/polish` turn findings into changes. The goal: each fix leaves **no instance** of its problem behind and **introduces nothing new**, so the next review does not spend a round on either. Which findings to fix is the invoking skill's decision — `/review` fixes what the user picks, `/polish` fixes everything.

## Before fixing: snapshot

Record the working-tree snapshot before touching anything: `sh ~/.claude/skills/review-diff.sh --tree`. After fixing, the delta check (see below) reviews exactly what changed since this snapshot.

## For each finding

1. **Confirm it.** A finding is a hypothesis. Read the code it points at and confirm the problem is real. If it is wrong — the reviewer misread the code, or the external behaviour it asserts is not what the official docs say — do not apply it: append a `rejected:` entry — with what you verified and against what — to the ledger in `review-fanout.md`'s format, whose `base=` is the change's full-mode `FROM` (never a delta run's, which would expire the entry at the next round), and report the rejection in your summary.
2. **Check it against earlier decisions.** If applying it would reverse a fix or decision made earlier for this change — in the ledger, or earlier in this session — do not flip-flop. That is a judgment call for the invoking skill's escalation step. A judgment call that only surfaces here — a flip-flop, or the scope expansion in step 7 — is left unfixed and handed back: `/polish`, which escalates once per round before fixing, carries it into the next round's batch and reports it open if the loop ends first; `/review`, which is interactive and has no next round, asks the user. Either way, do not quietly decide it. Record the outcome in the ledger, in `review-fanout.md`'s format and with its `base=` stamp (the change's full-mode `FROM`): `settled:` when the user chose to leave the finding as-is, `decided:` when they chose between options.
3. **Fix the whole class, not the instance.** Before editing, search for every other occurrence of the same root cause: the same wrong wording (`git -C <Repo root> grep -n -i -I -F --no-color --untracked -e '<term>'`, since `git grep` searches only the current directory and below (hence `-C`) and only tracked files (hence `--untracked`, or a file the change added but has not staged is skipped); `-e` keeps a term that starts with `-` — a flag name — from being read as an option; and `-F` keeps one containing `.`, `*` or `[` from being read as a regex, which would over-match or fail outright and leave the class sweep short; and the single quotes because the term came out of the diff, so it must be quoted before it reaches the shell at all — a term holding `$(…)`, a backtick, `;` or `|` would otherwise run a command the diff chose (pass it in a variable if it contains a single quote)), the same retired term, the same code pattern, the same missing-test shape in sibling functions. Fix them all in this pass. For a rename or retired concept, sweep code, comments, docs, templates and examples.
4. **Pin behaviour with a test.** Where the project has a runner, every fix that changes behaviour gets a test in the same pass that would fail if the fix were reverted — asserting the full outcome (the whole output line, the stored state, the error), not a prefix or "no error" — and every new test is written as carefully as production code. Where the project has none, name the cheapest pin that would fit instead of building a harness nobody asked for.
5. **Write claims yourself.** For comments, docs and messages, write wording that you have checked against the code — do not paste a reviewer's suggested text unverified. Avoid quantifiers ("only", "never", "always") unless you have confirmed them. Match the file's existing conventions, including hard-wrapping.
6. **Keep docs aligned.** If the fix changes behaviour, update every doc that describes it (README, `docs/`, CLAUDE.md, help text, example configs) in the same pass.
7. **Stay in scope.** Adjacent problems in code you touched may be fixed when the fix is clear and proportionate (the scout rule). Unrelated subsystems and large refactors are scope expansion — escalate, don't do.

## After fixing: re-verify, then delta check

If nothing was applied — every finding was rejected, or there was nothing to fix — skip both steps: there is no delta to check, and `review-diff.sh --since <the unchanged snapshot>` reports `MODE: none`.

1. Re-run the verification set from `verify-core.md`; fix until green.
2. Run the fan-out in **delta mode** against the snapshot (`review-fanout.md`). Treat its findings exactly like the original ones — they are problems the fixes created or left behind. Repeat fix → re-verify → delta check until the delta check is clean, at most **3** times; if it still finds problems after that, stop and report them as open.

The delta check is cheap (one reviewer over a small diff, two if the round of fixes was large) and it is what stops a round of fixes from becoming the next round's findings.

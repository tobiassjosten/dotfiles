# Lens: delta (check a round of fixes before the next full review)

You review only what changed since the snapshot named in your prompt (`Mode: delta (since <tree>)`) — a round of fixes just applied to a larger change. The full change was reviewed moments ago; your job is to catch what the fixes themselves got wrong, cheaply and immediately, so the next full review does not spend a round on it.

## Procedure

1. Read `full.diff` in the review directory — in delta mode it contains only the fixes. If your prompt gave you **owned files** (a large delta split between two delta reviewers), read only those files' `files/<path>.diff` instead, and scope every step below to them; those paths are repo-relative, so resolve them against the `Repo root` in your prompt to read a file itself. Read the surrounding code of every hunk. If `meta.txt` lists a changed path under `NO-CONTENT:`, its diff carries no content (git suppressed it — the file is binary, or carries a `-diff` attribute) — open the file directly when it is text, or note it as a non-reviewable binary; a fix to such a file has no hunks and would otherwise pass unseen. You are not given the original findings list — that is deliberate, so you check the fixes rather than confirm them; the `Notes` line may say in a sentence what they addressed.
2. For each hunk, check:
   - **Regressions** — did the edit break control flow around it (a removed or moved line that something else relied on, a new step that changes what an implicit fall-through reaches, a changed signature with an unupdated caller)?
   - **Claims** — is every comment, doc line or message the fix wrote actually true of the code? Fix wording is often pasted from a review suggestion and is itself a hypothesis; verify it, especially quantifiers ("only", "never", "always").
   - **Completeness** — did the fix address every location of its root cause? Grep for the same wording, pattern or term across the repo with `git -C <Repo root> grep -n -i -I -F --no-color --untracked -e '<term>'` (`-C <Repo root>` because `git grep` searches only the current directory and below, and your shell may be anywhere; `-e` so a term that starts with `-`, like a flag name, is a pattern rather than an option; `-F` because a term you derived can contain `.`, `*` or `[` and would otherwise be read as a regex — an unbalanced `[` makes git grep fail outright; and the single quotes because the term came out of the diff, so it must be quoted before it reaches the shell at all, since one holding `$(…)`, a backtick, `;` or `|` would otherwise run a command the diff chose (pass it in a variable if it contains a single quote)): a plain `git grep` searches only tracked files, and a round of fixes often adds new ones, so it would report a partial sweep as complete.
   - **Tests** — does every behaviour the fix changed have a test that would fail if the fix were reverted? Is any new test asserting the full outcome rather than a prefix or "no error"? Calibrate as `~/.claude/skills/review-lenses/tests.md` does: where the project has no test runner, do not report a missing test as such — report one only where the fix's correctness hinges on it *and* a cheap pin that fits the project exists, and name that pin. The skill that reads your findings fixes every one of them, so an unconditional demand here is how a project acquires a test harness nobody asked for.
   - **Style** — does the fix match the surrounding code and the file's wrapping convention?
3. Report only findings in or caused by the delta. Do not re-review the rest of the change.

## Coverage line

`Coverage: role=lens:delta; hunks checked <n>/<n>`

Over your owned files when you were given some, over the whole delta otherwise; say which.

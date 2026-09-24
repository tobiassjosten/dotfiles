# Lens: tests (behaviour ↔ test map)

Your job is to make sure every behaviour the change introduces or alters is pinned by a test, and that no existing test was weakened. Do it as a **map**, not an impression.

## Procedure

Check `meta.txt` for a `NO-CONTENT:` list first: each of those paths has a diff that carries no content (git suppressed it — the file is binary, or carries a `-diff` attribute). Read the file directly when it is text — comparing it against the base yourself — rather than from the diff, and count the behaviours you map that way in `behaviours mapped`. Note a genuine binary as non-reviewable rather than reading it into your context, and say next to the count that the path was not reviewable as text.

1. **List the behaviours.** From the diff, enumerate each new or changed behaviour at the level a test would assert: a branch in a function, an error path, a boundary, a user-visible output line, a returned value or status, a state write. Include behaviours added by earlier review rounds' fixes — they are part of the change too.
2. **Map each to a test.** For each behaviour, find the test that would fail if it regressed. Read the test: does it actually assert the behaviour, or only something adjacent (a prefix of the output, "no error", the happy path of a two-branch condition)? A behaviour with no test, or only a test that would still pass if it broke, is a finding.
3. **Read touched tests for damage.** For every test the diff modifies or deletes: what can it no longer catch? Loosened assertions, deleted cases, new skips, assertions against what a mock was told to return.
4. **Check contract pins.** Where the project names cross-file contracts (CLAUDE.md, rules files) and one side is code and the other is config, templates or another language, is there a test that fails on a one-sided change (e.g. pinning a wire field name or key)?
5. **Judge test quality** only for tests the change adds: unclear names, duplicated setup that hides intent, wall-clock or order dependence (flaky), a test that exercises a different path than its name claims.

Untestable-by-design code (a workflow YAML nothing executes locally, a startup script) is not a finding by itself — but if the change's correctness hinges on it, say so as a `testing` Issue with the cheapest available pin (a render-and-parse test, a golden file, a contract-constant test).

**Calibrate to the project's tooling**, the same way `~/.claude/skills/verify-core.md` does. In a project with no test runner at all — a pure config tree, a directory of vendored snapshots — "every behaviour needs a test" would make every behaviour a finding, and the skill that fixes findings would then invent a test framework nobody asked for. There, do not report the absence of tests as such: report a `testing` finding only where the change's correctness genuinely hinges on an unexercised behaviour **and** a cheap pin exists that fits the project, and name that pin. Say in your coverage line that the project has no test tooling, so the caller can tell a calibrated review from a skipped one.

## Coverage line

`Coverage: role=lens:tests; behaviours mapped <n> (untested <n>); touched tests read <n>/<n>`

`touched tests read` is checkable against the test files in `stat.txt`. Add `— project has no test tooling` whenever that is the case; it is what tells the caller a count is calibration rather than a skipped procedure.

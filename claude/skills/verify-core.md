# Verification (shared core)

Shared procedure for establishing that a change is **green** — its applicable checks (typically build, lint, type-check, tests) pass — before a skill acts on it. It defines *which checks to run*; the invoking skill decides *what to do with the result* (fix to green, block the ship, …).

## Determine the verification method once, at the start

- **If the project defines one, use it exactly.** Look for a mandated set of checks in `CLAUDE.md`, contributing/developer docs, a `Makefile` (`make lint`/`make test`/…), CI config (`.github/workflows/`, `.gitlab-ci.yml`, pre-commit hooks), or task-runner scripts (`package.json`, `justfile`, `Taskfile`). A project's stated checks win — run all of them, including project-specific ones (mutation testing, size/complexity budgets, install steps), and honor any conditions they state (e.g. only for changes under a given path).
- **If the project defines none, infer what fits its nature** from the toolchain and apply the standard checks for it — typically lint/format, type-check, the test suite, and a build. For example: Go → `go build ./...`, `go vet`, `go test ./...`, `gofmt`/linter; Node/TS → the lint, typecheck, test, and build scripts in `package.json`; Rust → `cargo build`, `cargo clippy`, `cargo test`; Python → the configured linter/formatter (ruff/black), type checker (mypy/pyright), and `pytest`. Scale to what exists — skip a category the project has no tooling for rather than inventing one, and don't fabricate targets that aren't there.

Record which checks you settled on. The invoking skill refers back to this same set — to re-verify after applying fixes, to gate on, and to name each check and its pass/fail state in its summary.

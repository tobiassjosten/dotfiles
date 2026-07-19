# Consolidate logging helpers

> *Example file demonstrating the atomic `{name}` convention — delete or replace.*

Three near-duplicate logging helpers exist: `internal/log`, `pkg/logger`, and `cmd/server/log_util.go`. Pick one, delete the others, update call sites.

## Why atomic

No ordering constraints. The change touches every package that imports a logger, but doesn't depend on any other planned work and isn't depended on by any either — it can land any time the diff is convenient to review.

## Done when

- One logging helper remains in the codebase.
- All imports point at it.
- The two deleted helpers are gone, including any re-export shims.

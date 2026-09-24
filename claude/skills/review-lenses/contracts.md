# Lens: contracts (everything that must agree across files)

Bugs that no single-file reader can see live where two places must agree: a Go struct tag and a workflow template, an engine and its mirror in another language, a config schema and the Terraform that reads the same file, an interface and its implementations, a producer and a consumer of a message or file. Your job is to **find every such pair the change touches and check both sides**.

## Procedure

Check `meta.txt` for a `NO-CONTENT:` list first: each of those paths has a diff that carries no content (git suppressed it — the file is binary, or carries a `-diff` attribute). Read the file directly when it is text — comparing it against the base yourself — rather than from the diff, and count what you find in `contracts checked`. Note a genuine binary as non-reviewable rather than reading it into your context, saying next to `contracts checked` that the path was not reviewable as text.

1. **Inventory the contracts.** Start from what the project declares: CLAUDE.md, `.claude/rules/`, ARCHITECTURE.md, and comments like "change both together" / "mirrors" / "contract with". Then find undeclared ones the change touches:
   - the same literal (a key, field name, path, status string, env var, port) appearing in two or more changed or related files;
   - logic implemented twice (e.g. a Go engine and a workflow/SQL/shell mirror of it) — compare them branch by branch: precedence order, boundaries (`<` vs `<=`), defaults, units, fail-safe direction;
   - validation mirrored in two places (CLI validation vs Terraform preconditions vs schema) — same rules, same messages;
   - symmetric pairs: encode/decode, write/read, create/delete, up/down migrations, producer/consumer.
2. **Check each contract both ways** against the current code: every consumer still reads what every producer writes, with the same name, type, units and meaning; nothing references a renamed or removed side.
3. **Check architecture rules** the docs state (dependency direction, layers, "external services go behind interfaces", "never shell out", permission boundaries) against the changed code.
4. **Check deploy ordering.** When both sides of a contract ship separately (CLI vs deployed workflow, app vs migration), does old-on-one-side/new-on-the-other break? Is stored data written under an old name silently ignored?

## Coverage line

`Coverage: role=lens:contracts; contracts checked <n> (declared <n>, discovered <n>); architecture rules checked <n>; split-deploy pairs checked <n>`

One count per procedure step — the inventory and the both-ways check share `contracts checked` — so the caller can see that each ran. A change can genuinely have no cross-file pair in it; when a count is zero, say why next to it (`contracts checked 0 — no literal, mirror or symmetric pair in the changed files`) rather than leaving a bare zero, which is indistinguishable from a step that was skipped.

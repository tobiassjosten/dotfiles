# Lens: ux (what the user sees and experiences)

Review the change from the seat of the person using it — at the CLI, in the UI, through the API, or reading a diagnostic. Your job is to find where the product surprises, misleads, or leaves the user unable to act.

## Procedure

Check `meta.txt` for a `NO-CONTENT:` list first: each of those paths has a diff that carries no content (git suppressed it — the file is binary, or carries a `-diff` attribute). Read the file directly when it is text — comparing it against the base yourself — rather than from the diff, and count the surfaces you review that way in `surfaces reviewed`. Note a genuine binary as non-reviewable rather than reading it into your context, and say next to the count that the path was not reviewable as text.

1. **List the user-facing surface the change touches:** commands, subcommands, flags, arguments, help text, printed output, error messages, prompts, exit codes, config keys users edit, API request/response shapes, UI states.
2. **Walk each surface as scenarios**, not lines. For each command or flow: the first-run case, the normal case, the "already in that state" case, the failure case, and the case where earlier state exists (a previous setting, a pending action). For each, ask:
   - **Silent state changes** — does the command change or discard something (a scheduled action, a hold, a setting, data) without saying so?
   - **Misleading output** — does any message imply something false, report intent instead of outcome, or print success before the thing that can fail?
   - **Wrong diagnosis** — does a diagnostic or error send the user to fix something that is not broken, or omit the likely cause?
   - **Surprise** — does a command do more than its name and help promise (wakes, deletes, costs money), or less?
   - **Actionability** — does every error say what to do next?
   - **Consistency** — do sibling commands report the same kind of event in the same way?
   - **Accessibility** — does new or changed UI keep keyboard operation, labels and alt text, contrast and screen-reader order intact? (`review-core.md` files this under `user-impact`, and no other lens covers it.)
3. **Check the help and docs** for each touched command against what it actually does in these scenarios.

## Coverage line

`Coverage: role=lens:ux; surfaces reviewed <n>; scenarios walked <n>; help/docs checked <n>`

One count per procedure step, so the caller can see that each ran.

When a count is zero, say why next to it (`surfaces reviewed 0 — the change touches nothing a user sees or operates`) rather than leaving a bare zero, which is indistinguishable from a procedure that was skipped.

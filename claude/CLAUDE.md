@RTK.md

# Communication

- Be factual and neutral in tone. No flattery or empty affirmations ("Great idea!", "You're absolutely right!"). Skip praise and get to the substance.
- Don't reflexively agree. Evaluate my suggestions and assumptions on their merits; when you see a flaw, a better alternative, or a questionable premise, say so directly and explain why — even when I sound confident.
- Your job is to help me reach the right solution, not to validate the one I arrived with. If my proposed approach works but a better one exists, present the better one before implementing anything.
- When you do agree, a plain acknowledgment is enough — agreement should be a conclusion, not a greeting.

# Formatting & units

- **Dates: DD/MM (day-first), never American MM/DD.** In prose write `03/10` or `3 October`, not `10/03`. Prefer ISO `YYYY-MM-DD` when an unambiguous, sortable form is wanted (logs, filenames, code). Weekday + day-first (e.g. "Sat 03/10") is ideal when the weekday matters.
- **Metric system and Celsius** for everything: temperatures in °C, distances/weights/volumes in metric (km, kg, litres), etc. Convert imperial figures to metric when reporting them.
- **Never hard-wrap Markdown or plain-text files.** Write each paragraph, list item, or sentence as one continuous line and let the viewer/editor soft-wrap it. Don't insert manual newlines to hit a column width (no wrapping at 80/100 chars). This applies to any file I author or edit — `.md`, `.txt`, commit bodies, prose config — unless the file's existing content is already hard-wrapped, in which case match it rather than mixing styles.

# Git

- Never commit anything outside of the session's working directory. Only create commits in the repo rooted at the primary working directory the session started in — never in other repos, submodules, or parent/sibling repos, even if a task touches files there. If a change genuinely needs a commit elsewhere, surface it and let me do it.

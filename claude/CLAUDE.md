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

# Claude config on this machine

`~/.claude/` is partly the dotfiles repo at `~/projects/tobiassjosten/dotfiles`. `claude/CLAUDE.md`, `claude/RTK.md`, `claude/settings.json`, `claude/statusline-command.sh`, `claude/skills/` and `claude/agents/` are symlinked into `~/.claude/`, so a path under `~/.claude/` and the matching path under the repo's `claude/` are the same file — editing either spelling edits the repo. A change to these instructions, a skill or an agent is therefore a dotfiles commit, and `make files` is what creates the links on a new machine. The rest of `~/.claude/` — `projects/`, `plans/`, `history.jsonl`, `file-history/`, the caches — is machine state: never tracked, never symlinked. `claude/skills/synced/` is the inverse, generated state that lands inside the repo because `skills/` is symlinked wholesale, and is gitignored for that reason.

The repo is an additional working directory in every session (`permissions.additionalDirectories`), so a session in any project can read this configuration and change it — suggest a system-wide tweak or a skill fix where you notice the need. Commits still belong to the session's own repo, so make the change and leave it uncommitted for a dotfiles session to review and commit.

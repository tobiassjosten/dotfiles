# Lens: claims (comments, docs and messages vs. the code)

Every sentence that describes the system is a claim that can be wrong. Your job is to **enumerate** the claims the change touches and **verify each one** against the code — not to skim for ones that look off. This is the single largest source of findings on a typical change, and it is only found reliably by enumeration.

## Procedure

Check `meta.txt` for a `NO-CONTENT:` list first: each of those paths has a diff that carries no content (git suppressed it — the file is binary, or carries a `-diff` attribute). Read the file directly when it is text — comparing it against the base yourself — rather than from the diff, and count the claims you verify that way in `claims checked`. Note a genuine binary as non-reviewable rather than reading it into your context, and say next to the count that the path was not reviewable as text.

1. **Collect the claims.** From the whole diff (`full.diff`), list every added or modified:
   - code comment and doc comment;
   - line in a documentation file (README, `docs/`, CLAUDE.md, rules files, example configs, changelogs);
   - user-visible string: help/usage text, error messages, log messages meant for humans, CLI output.

   Then add the **unchanged** doc sentences that describe a symbol, command, flag, config key or behaviour the change modified — grep the docs for each changed name. Unchanged prose about changed behaviour is where drift hides.

   On a docs-only change the plan is areas (one for a small change, up to three for a large one) plus you, plus contracts when the docs describe cross-file contracts — and any other lens whose own trigger fires. If the change is small, read each changed doc file through rather than working from the diff alone.
2. **Verify each claim** by reading the code it describes — the actual current code, not the diff's intent. A claim is wrong if it is false, stale, incomplete in a way that misleads ("does nothing if X" when it also does Y), overclaims ("the only path that …", "never", "always"), or names something that no longer exists. Quantifiers deserve extra suspicion: check every "only", "never", "always", "all", "every", "exactly".
3. **Sweep retired vocabulary.** Read `removed-terms.txt` in the review directory: words the change stopped using that still occur in the tree. For each plausible one, `git -C <Repo root> grep -n -i -I -F --no-color -e '<term>' <TREE> --` — the snapshot hash from `meta.txt`, **not** a bare `git grep`, which searches only tracked files and so silently skips any file the change adds but has not staged. (`-C <Repo root>` because `git grep` searches only the current directory and below, and your shell may be anywhere — without it a term still living elsewhere in the tree reads as retired, and your file counts come out below `still-in=<n>`; `-e` so a term starting with `-` is a pattern rather than an option, which matters for the flags and options you derive below; `--no-color` because a repo may set `color.ui=always`, which colours a pipe too; `-i` and `-I` to match how `still-in=<n>` was computed, so the counts line up; and `-F` because the terms you derive yourself can contain `.`, `*` or `[` and would otherwise be read as a regex — an unbalanced `[` makes git grep fail outright; and the single quotes because the term came out of the diff, so it must be quoted before it reaches the shell at all, since one holding `$(…)`, a backtick, `;` or `|` would otherwise run a command the diff chose (pass it in a variable if it contains a single quote).) A bare `git grep` never returns *more* files than `removed-terms.txt` claims, and returns fewer whenever the change added an unstaged file that matches — so equal counts do not confirm you used the right command. Decide whether each remaining occurrence is a leftover of the old model/name. Also derive terms yourself: every identifier, command, flag, config key or concept the diff renames or removes — grep the same way for the old name across code, comments, docs and templates.
4. **Check the docs-match-code direction** per the shared core: new concepts, commands, flags or config keys that the docs (README, CLAUDE.md, `docs/`) do not mention yet. The other direction — code that violates what the docs prescribe — belongs to `lens:contracts`.
5. **Report by root cause.** The same wrong statement in several places is one finding listing every location. A false claim is a `(defect)`; a comment that is merely redundant or could be clearer is a `(preference)`.

Match the file's existing wrapping convention in any doc fix you suggest.

## Coverage line

`Coverage: role=lens:claims; claims checked <n>; removed-terms reviewed <n>/<n>; derived terms swept <n>; changed doc files read <n>; new concepts checked against the docs <n>`

`removed-terms reviewed` is checkable against `wc -l < removed-terms.txt`; review every line of it, however noisy. `derived terms swept` is step 3's other half — the renames and retired flags you worked out yourself, which is where real leftovers are found, since `removed-terms.txt` only ever holds single `[a-z0-9]` words. A zero there is only honest on a change that renames nothing; say so next to it, as next to any zero count.

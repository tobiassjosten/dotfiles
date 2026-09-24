# dotfiles

Personal macOS development environment, installed by symlinking files from this repo into `$HOME`. It covers the shell (fish), editors (Vim, plus a Neovim setup being trialed), tmux, Hammerspoon automation, git, a set of Homebrew packages, and Claude Code customization (skills, agents, review workflow).

There is no build, and most of what is here is config: "testing" a change means sourcing the file or reloading the affected tool (fish, tmux, nvim, Hammerspoon). Of the few first-party scripts, only `claude/skills/review-diff.sh` — which the `/review`, `/polish` and `/ship` skills and the `code-reviewer` agent depend on — has a test suite; `make check` runs it.

## Requirements

- **macOS.** Config and automation assume a Mac (Homebrew under `/opt/homebrew`, Hammerspoon, iTerm2).
- **Homebrew** is bootstrapped automatically by the `Makefile` if missing.
- After the first install, run `tfenv install latest` once — the `Brewfile` ships `tfenv`, not `terraform`, so there's no `terraform` binary until you do.

## Installation

Clone the repo, then from its root run:

```sh
make          # full setup: files, brews, fish, vim
```

Individual targets:

| Target        | What it does |
|---------------|--------------|
| `make`        | Full setup — runs `files`, `brews`, `fish`, `vim`. |
| `make files`  | (Re)create the `$HOME` symlinks (runs `claude` first to link the Claude subset). Run after adding a new config file. |
| `make brews`  | Install/update Homebrew packages from `Brewfile` (bootstraps Homebrew first). |
| `make fish`   | Register fish in `/etc/shells` and set it as the login shell. |
| `make vim`    | Install Vim plugins (via vim-plug) and vim-go's Go binaries. |
| `make claude` | Link only the Claude Code config subset into `~/.claude/` — the portable part, usable on a bare machine (e.g. a dev VM) without the rest of the toolchain. |
| `make check`  | Syntax-check `claude/skills/review-diff.sh` and run the repo's only test suite, `claude/skills/review-diff.test.sh`, which drives it through every mode in throwaway repos under `$TMPDIR`. Not part of `make`. |

Symlinks use `ln -fs` for files and a `LINK_DIR` macro for directories. The macro guards against a footgun: `ln -fns` only replaces an existing symlink, but if the target is already a real directory it silently creates the link *inside* it instead. **When you add a new config file, add a matching `ln` line to the `files` target in the `Makefile`** — otherwise it never reaches `$HOME`.

## What's inside

### Shell

- `config/fish/config.fish` (→ `~/.config/fish/config.fish`) — the login shell: PATH, aliases, functions, prompt. Includes `__gcloud_config_env`, a `--on-variable PWD` hook that scopes `CLOUDSDK_CONFIG` per git repo so each project's gcloud account/project/ADC stays isolated.
- `zprofile` (→ `~/.zprofile`) — minimal fallback for macOS's default zsh (puts Homebrew on `PATH`, loads nvm). Everything else belongs in the fish config.

### Editors

- `vimrc` + `vim/` (→ `~/.vimrc`, `~/.vim`) — the current Vim setup, using vim-plug. `make vim` installs its plugins. Custom snippets live under `vim/ultisnips/`.
- `config/nvim/` (→ `~/.config/nvim`) — a Neovim setup being trialed (not yet the daily editor), lazy.nvim-based. Plugins are one spec file each under `lua/plugins/`, auto-imported by `lua/config/lazy.lua`; versions pinned in `lazy-lock.json`.

### Terminal multiplexer

- `tmux.conf` + `tmux/` (→ `~/.tmux.conf`, `~/.tmux`) — plugins are vendored under `tmux/plugins/` (tpm, extrakto, tmux-cowboy); helper scripts in `tmux/scripts/`.

### Hammerspoon

- `hammerspoon/Spoons/` — Lua Spoons (`window-sizer`, `pull-requests`, `minecraft-fkeys`). Only the Spoons are symlinked, not the whole Hammerspoon directory.

### Claude Code

- `claude/` (→ `~/.claude/`) — user config: `CLAUDE.md`, `RTK.md`, `settings.json`, `statusline-command.sh` (linked individually), plus `skills/` and `agents/` (each linked as a whole directory). `agents/code-reviewer.md` is a read-only reviewer that is the single generator of review findings. It plays one role at a time, and a review fans out: several of them in parallel, each owning an area (a slice of the changed files) or a lens (claims, tests, contracts, ux, security, delta), coverage-checked and merged into one list. The finding bar lives in `skills/review-core.md`, the orchestration in `skills/review-fanout.md`, the per-role procedures in `skills/review-lenses/`, the fix policy in `skills/review-fix.md` (used by `/review` and `/polish`; `/ship` never fixes), and the diff preparation in `skills/review-diff.sh` (tested by `make check`); `/review`, `/polish` and `/ship` are built from these and differ only in disposition. A per-worktree ledger inside `.git` carries settled, rejected and decided findings — and `/polish`'s convergence record, which lets `/ship` skip a re-review when the diff is unchanged — across rounds and sessions; `/ship` deletes it after pushing, and any other ending needs `$(git rev-parse --absolute-git-dir)/review/` removed by hand. The prepared diff comes from a `git add -A` snapshot, so keep secrets gitignored rather than merely untracked. The rest of `~/.claude/` (session transcripts, history, caches) is machine state and is never tracked or symlinked. `skills/synced/` is the mirror image: Claude Code's plugin-sync state, generated *inside* the repo because `skills/` is symlinked wholesale, and gitignored for that reason.
- `claude/statusline-command.sh` renders two lines: working directory and git state, then model, rate-limit usage against elapsed window time, context usage and cost. A third line is added whenever the instruction currently driving the session can be identified, so it is always clear what stage of the work Claude is at — slash commands in bold, prose dimmed, read back out of the session transcript. It skips turns that don't drive the work (read-only commands like `/tasks` and `/cost`, session plumbing like `/resume`, asides like `/btw`, and bare nudges like "continue") and keeps walking back to the instruction that does. `/clear` ends the search, since nothing before it still applies; when the search finds nothing the line is omitted. A long instruction is clipped to `PROMPT_MAX` (100) characters with an ellipsis. The search covers the last `PROMPT_SCAN_LINES` (2000) lines of the transcript and rereads the whole file only if that window yields nothing. The tunables — `PROMPT_MAX`, `PROMPT_SCAN_LINES`, `PROMPT_SKIP_COMMANDS` and `PROMPT_SKIP_PROSE` — are all at the top of the script.

### Git

- `gitconfig` (→ `~/.gitconfig`) — conditionally includes `gitconfig_stim` (work identity) for repos under `~/projects/stim/`.
- `gitignore` (→ `~/.gitignore`) — global ignore rules.
- `ctags` (→ `~/.ctags`) — universal-ctags configuration.

### Other dotfiles

- `htoprc`, `myclirc` — configs for htop and mycli.
- `dlv/` (→ `~/.dlv`) — Delve (Go debugger) config.
- `default.itermkeymap` — iTerm2 key mappings (import via iTerm2 > Preferences > Profiles (Default) > Keys > Key Mappings).

### Tools

- `Brewfile` — the Homebrew manifest (~50 packages and casks): fish, tmux, vim, ripgrep, bat, tree, gh, jq, go, rust, node, pyenv, tfenv, database CLIs (mycli, pgcli, mysql-client), `rtk`, and more. Casks: ngrok, tailscale. Installed and updated by `make brews`.

## Maintenance

Keep this `README.md` in sync with the repo. Whenever a config area, `make` target, or notable tool is added, removed, or restructured, update the relevant section here in the same change so the README never drifts from what the repo actually contains.

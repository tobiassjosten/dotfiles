# dotfiles

Personal macOS development environment, installed by symlinking files from this repo into `$HOME`. It covers the shell (fish), editors (Vim, plus a Neovim setup being trialed), tmux, Hammerspoon automation, git, a set of Homebrew packages, and Claude Code customization (skills, agents, review workflow).

There is no build or test suite. "Testing" a change means sourcing the file or reloading the affected tool (fish, tmux, nvim, Hammerspoon).

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

- `claude/` (→ `~/.claude/`) — user config: `CLAUDE.md`, `RTK.md`, `settings.json`, `statusline-command.sh` (linked individually), plus `skills/` and `agents/` (each linked as a whole directory). `agents/code-reviewer.md` is a read-only reviewer that is the single generator of review findings; the `/review`, `/polish`, and `/ship` skills delegate to it and differ only in disposition. The rest of `~/.claude/` (session transcripts, history, caches) is machine state and is never tracked or symlinked.

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

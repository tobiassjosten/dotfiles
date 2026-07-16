# CLAUDE.md

## What this is

Personal dotfiles, installed by symlinking files from this repo into `$HOME`. There is no build or test suite; "testing" a change means sourcing the file or reloading the affected tool (fish, tmux, nvim, Hammerspoon).

## Commands

- `make` — full setup: symlinks, Homebrew + Brewfile, fish as login shell, vim plugins
- `make files` — (re)create the symlinks only; run after adding a new config file so it gets linked into `$HOME`
- `make brews` — install/update Homebrew packages from `Brewfile`

**When adding a new config file, add a corresponding `ln` line to the `files` target in the Makefile** — otherwise it never reaches `$HOME`. Use `-fhs` for directories, `-fs` for files.

## Architecture

### Shell

Fish is the login shell; all shell config (PATH, aliases, functions, prompt) lives in `config/fish/config.fish`. The only other shell file is `zprofile`, a minimal fallback for macOS's default zsh (puts Homebrew on `PATH`, loads nvm) — keep it minimal, everything else belongs in the fish config.

### Editors

- Neovim: `config/nvim/` (→ `~/.config/nvim`), lazy.nvim-based; plugins are one spec file each under `lua/plugins/`, auto-imported by `lua/config/lazy.lua`. Versions pinned in `lazy-lock.json`.
- Vim: legacy setup in `vimrc` + `vim/` using vim-plug (`make vim` installs plugins).

### Other pieces

- `tmux.conf` + `tmux/` — plugins are vendored under `tmux/plugins/` (tpm, extrakto, tmux-cowboy); helper scripts in `tmux/scripts/`
- `hammerspoon/Spoons/` — Lua Spoons (only the Spoons are symlinked, not the whole Hammerspoon dir)
- `gitconfig` conditionally includes `gitconfig_stim` (work identity) for repos under `~/projects/stim/`

# CLAUDE.md

## What this is

Personal dotfiles, installed by symlinking files from this repo into `$HOME`. There is no build or test suite; "testing" a change means sourcing the file or reloading the affected tool (fish, tmux, nvim, Hammerspoon).

## Commands

- `make` — full setup: symlinks, Homebrew + Brewfile, fish as login shell, vim plugins
- `make files` — (re)create the symlinks only; run after adding a new config file so it gets linked into `$HOME`
- `make brews` — install/update Homebrew packages from `Brewfile`. Note: `Brewfile` ships `tfenv`, not `terraform` — on a fresh machine run `tfenv install latest` once to get a `terraform` binary.

**When adding a new config file, add a corresponding `ln` line to the `files` target in the Makefile** — otherwise it never reaches `$HOME`. Use `-fs` for files and the `LINK_DIR` macro for directories: `ln -fhs` only replaces an existing symlink — if the target is already a real directory, it silently creates the link inside it instead, which the macro guards against. The inverse also holds: when converting a formerly-symlinked directory into a real directory, `rm` the legacy symlink in the recipe first — both `mkdir -p` and `ln -fs` resolve through an existing symlink and would write into the repo itself.

## Architecture

### Shell

Fish is the login shell; all shell config (PATH, aliases, functions, prompt) lives in `config/fish/config.fish`. The only other shell file is `zprofile`, a minimal fallback for macOS's default zsh (puts Homebrew on `PATH`, loads nvm) — keep it minimal, everything else belongs in the fish config.

**Per-repo gcloud isolation.** `config/fish/config.fish` defines `__gcloud_config_env`, a `--on-variable PWD` hook that scopes `CLOUDSDK_CONFIG` per git repo. On entering a repo it sets `CLOUDSDK_CONFIG` to `~/.config/gcloud/<reponame>` **if that directory exists**, otherwise leaves the global default in place; it only clears a value it set itself. This isolates each project's gcloud account/project/ADC so authing for one doesn't clobber another. To opt a repo in: `mkdir -p ~/.config/gcloud/<reponame>`, then run the gcloud auth sequence with `CLOUDSDK_CONFIG` set to that dir. Keyed on repo basename, so same-named repos collide. When working in a repo that relies on a specific GCP identity, be aware that `gcloud`/Terraform commands pick up this scoped config automatically — don't run `gcloud auth application-default login` against the global config expecting it to apply here.

### Editors

- Neovim: `config/nvim/` (→ `~/.config/nvim`), lazy.nvim-based; plugins are one spec file each under `lua/plugins/`, auto-imported by `lua/config/lazy.lua`. Versions pinned in `lazy-lock.json`.
- Vim: legacy setup in `vimrc` + `vim/` using vim-plug (`make vim` installs plugins).

### Other pieces

- `claude/` — Claude Code user config, symlinked into `~/.claude/` (top-level files individually, `skills/` and `agents/` each as a whole directory). Config here may depend on CLI tools (e.g. `jq` for the statusline, `rtk` for the Bash hook) — add those to `Brewfile` so a fresh `make` produces a working setup. Never symlink or track the rest of `~/.claude/` — it's machine state (session transcripts, history, caches) and must stay local. Some skills are vendored third-party snapshots; the rest are personal. `agents/` holds custom subagent types (e.g. `code-reviewer`, a read-only reviewer the `/forge` skill spawns each review round); the review skills and that agent share the threshold in `skills/review-core.md` and the base-selection logic in `skills/review-diff.sh`.
- `tmux.conf` + `tmux/` — plugins are vendored under `tmux/plugins/` (tpm, extrakto, tmux-cowboy); helper scripts in `tmux/scripts/`
- `hammerspoon/Spoons/` — Lua Spoons (only the Spoons are symlinked, not the whole Hammerspoon dir)
- `gitconfig` conditionally includes `gitconfig_stim` (work identity) for repos under `~/projects/stim/`

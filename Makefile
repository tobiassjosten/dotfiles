DIR := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))

# `ln -fns` only replaces an existing symlink — if the target is already a
# real directory, the link is silently created inside it instead. (`-n` is the
# portable spelling of BSD's `-h`; GNU coreutils `ln` has no `-h`.)
define LINK_DIR
@if [ -d $(2) ] && [ ! -L $(2) ]; then echo "error: $(2) is a real directory — move it aside first"; exit 1; fi
ln -fns $(1) $(2)
endef

.PHONY: all
all: files brews fish vim

# The one script here with behavioural tests: the review skills' diff preparation, which
# /review, /polish, /ship and the code-reviewer agent depend on. The repo's other
# first-party scripts (claude/statusline-command.sh, claude/skills/review-pr/gh-pr.sh,
# tmux/scripts/minimize-sibling-pane.sh) have none — they are checked by running the tool
# that calls them. Not part of `all`.
.PHONY: check
check:
	sh -n $(DIR)/claude/skills/review-diff.sh
	sh $(DIR)/claude/skills/review-diff.test.sh

.PHONY: vim
vim:
	vim -c 'PlugInstall' '+qall'
	vim -c 'GoInstallBinaries' '+qall'

.PHONY: homebrew
homebrew:
	@which brew > /dev/null || (/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" && eval "$$(/opt/homebrew/bin/brew shellenv)" && brew analytics off)

.PHONY: brews
brews: homebrew
	brew update
	brew bundle

.PHONY: fish
fish: brews
	@grep -q -F "/fish" "/etc/shells" || (echo "$$(which fish)" | sudo tee -a /etc/shells > /dev/null)
	@chsh -s $$(which fish)

# Links only the Claude config into ~/.claude — the portable subset usable on a
# bare machine (e.g. a dev VM) without the rest of the dotfiles toolchain. The
# rtk hook self-guards (see claude/settings.json), so rtk is optional here.
.PHONY: claude
claude:
	@missing=""; for t in jq git; do command -v $$t >/dev/null 2>&1 || missing="$$missing $$t"; done; \
	  if [ -n "$$missing" ]; then echo "error: missing required tools:$$missing"; exit 1; fi
	@command -v rtk >/dev/null 2>&1 || echo "warning: rtk not found — Bash hook self-skips; install rtk to restore token savings"
	@mkdir -p ~/.claude
	ln -fs $(DIR)/claude/CLAUDE.md ~/.claude/CLAUDE.md
	ln -fs $(DIR)/claude/RTK.md ~/.claude/RTK.md
	ln -fs $(DIR)/claude/settings.json ~/.claude/settings.json
	ln -fs $(DIR)/claude/statusline-command.sh ~/.claude/statusline-command.sh
	$(call LINK_DIR,$(DIR)/claude/skills,~/.claude/skills)
	$(call LINK_DIR,$(DIR)/claude/agents,~/.claude/agents)

.PHONY: files
files: claude
	@if [ -L ~/.config/fish ]; then rm ~/.config/fish; fi
	mkdir -p ~/.config/fish
	$(call LINK_DIR,$(DIR)/config/nvim,~/.config/nvim)
	$(call LINK_DIR,$(DIR)/vim,~/.vim)
	# fish writes machine state (fish_variables, completions) into ~/.config/fish,
	# so that stays a real directory and only config.fish is linked into it.
	ln -fs $(DIR)/config/fish/config.fish ~/.config/fish/
	ln -fs $(DIR)/ctags ~/.ctags
	$(call LINK_DIR,$(DIR)/dlv,~/.dlv)
	ln -fs $(DIR)/gitconfig ~/.gitconfig
	ln -fs $(DIR)/gitconfig_stim ~/.gitconfig_stim
	ln -fs $(DIR)/gitignore ~/.gitignore
	ln -fs $(DIR)/hammerspoon/Spoons/* ~/.hammerspoon/Spoons/
	ln -fs $(DIR)/htoprc ~/.htoprc
	ln -fs $(DIR)/myclirc ~/.myclirc
	$(call LINK_DIR,$(DIR)/tmux,~/.tmux)
	ln -fs $(DIR)/tmux.conf ~/.tmux.conf
	ln -fs $(DIR)/vimrc ~/.vimrc
	ln -fs $(DIR)/zprofile ~/.zprofile

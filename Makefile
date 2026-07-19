DIR := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))

# `ln -fhs` only replaces an existing symlink — if the target is already a
# real directory, the link is silently created inside it instead.
define LINK_DIR
@if [ -d $(2) ] && [ ! -L $(2) ]; then echo "error: $(2) is a real directory — move it aside first"; exit 1; fi
ln -fhs $(1) $(2)
endef

.PHONY: all
all: files brews fish vim

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

.PHONY: files
files:
	@if [ -L ~/.config/fish ]; then rm ~/.config/fish; fi
	mkdir -p ~/.config/fish
	mkdir -p ~/.claude
	ln -fs $(DIR)/claude/CLAUDE.md ~/.claude/CLAUDE.md
	ln -fs $(DIR)/claude/RTK.md ~/.claude/RTK.md
	ln -fs $(DIR)/claude/settings.json ~/.claude/settings.json
	ln -fs $(DIR)/claude/statusline-command.sh ~/.claude/statusline-command.sh
	$(call LINK_DIR,$(DIR)/claude/skills,~/.claude/skills)
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

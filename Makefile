DIR := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))

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
	mkdir -p ~/.config
	ln -fhs $(DIR)/config/fish ~/.config/fish
	ln -fhs $(DIR)/config/nvim ~/.config/nvim
	ln -fhs $(DIR)/vim ~/.vim
	ln -fs $(DIR)/config/fish/config.fish ~/.config/fish/
	ln -fs $(DIR)/ctags ~/.ctags
	ln -fhs $(DIR)/dlv ~/.dlv
	ln -fs $(DIR)/gitconfig ~/.gitconfig
	ln -fs $(DIR)/gitconfig_stim ~/.gitconfig_stim
	ln -fs $(DIR)/gitignore ~/.gitignore
	ln -fs $(DIR)/hammerspoon/Spoons/* ~/.hammerspoon/Spoons/
	ln -fs $(DIR)/htoprc ~/.htoprc
	ln -fs $(DIR)/myclirc ~/.myclirc
	ln -fhs $(DIR)/tmux ~/.tmux
	ln -fs $(DIR)/tmux.conf ~/.tmux.conf
	ln -fs $(DIR)/vimrc ~/.vimrc
	ln -fs $(DIR)/zprofile ~/.zprofile

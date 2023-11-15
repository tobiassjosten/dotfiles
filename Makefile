DIR := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))

all: brews dirs symlinks vim

dirs:
	mkdir -p ~/.config/fish

vim:
	vim -c 'PlugInstall' '+qall'
	vim -c 'GoInstallBinaries' '+qall'

homebrew:
	which brew || ruby -e "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

brews: homebrew
	brew update
	brew bundle

symlinks:
	ln -fs $(DIR)/ctags ~/.ctags
	ln -fs $(DIR)/dlv ~/.dlv
	ln -fs $(DIR)/gitconfig ~/.gitconfig
	ln -fs $(DIR)/gitconfig_stim ~/.gitconfig_stim
	ln -fs $(DIR)/gitignore ~/.gitignore
	ln -fs $(DIR)/htoprc ~/.htoprc
	ln -fs $(DIR)/myclirc ~/.myclirc
	ln -fs $(DIR)/tmux ~/.tmux
	ln -fs $(DIR)/tmux.conf ~/.tmux.conf
	ln -fhs $(DIR)/vim ~/.vim
	ln -fs $(DIR)/vimrc ~/.vimrc
	ln -fs $(DIR)/xmodmaprc ~/.xmodmaprc
	ln -fs $(DIR)/config/fish/config.fish ~/.config/fish/

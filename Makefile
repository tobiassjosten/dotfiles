DIR := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))

all: brews shell symlinks
	vim "+call minpac#update('', {'do': 'qall!'})"
	gem install bundler
	npm install -g ember-cli

homebrew:
	ruby -e "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

brews: homebrew
	brew update
	# @todo Detect whether homebrew bundle is installed or install it if not.
	brew tap homebrew/bundle
	cd $(DIR) && brew bundle

shell: homebrew
	sh -c "$$(wget https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh -O -)"

symlinks:
	ln -fhs $(DIR)/bash ~/.bash
	ln -fs $(DIR)/bash_logout ~/.bash_logout
	ln -fs $(DIR)/bash_profile ~/.bash_profile
	ln -fs $(DIR)/bashrc ~/.bashrc
	ln -fs $(DIR)/gitconfig ~/.gitconfig
	ln -fs $(DIR)/gitignore ~/.gitignore
	ln -fs $(DIR)/htoprc ~/.htoprc
	ln -fs $(DIR)/profile ~/.profile
	ln -fhs $(DIR)/sh ~/.sh
	ln -fhs $(DIR)/shell ~/.shell
	ln -fs $(DIR)/tmux.conf ~/.tmux.conf
	ln -fhs $(DIR)/vim ~/.vim
	ln -fs $(DIR)/vimrc ~/.vimrc
	ln -fs $(DIR)/xmodmaprc ~/.xmodmaprc
	ln -fhs $(DIR)/zsh ~/.zsh
	ln -fs $(DIR)/zshenv ~/.zshenv
	ln -fs $(DIR)/zshrc ~/.zshrc

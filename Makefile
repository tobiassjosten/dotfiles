DIR := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))

all: homebrew shell symlinks
	vim "+call minpac#update('', {'do': 'qall!'})"

homebrew:
	brew update
	# @todo Detect whether homebrew bundle is installed or install it if not.
	brew tap homebrew/bundle
	cd $(DIR) && brew bundle

shell: homebrew
	sh -c "$$(wget https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh -O -)"

symlinks:
	ln -fs $(DIR)/vim ~/.vim
	ln -fs $(DIR)/bash ~/.bash
	ln -fs $(DIR)/bash_profile ~/.bash_profile
	ln -fs $(DIR)/gitignore ~/.gitignore
	ln -fs $(DIR)/profile ~/.profile
	ln -fs $(DIR)/shell ~/.shell
	ln -fs $(DIR)/xmodmaprc ~/.xmodmaprc
	ln -fs $(DIR)/zshenv ~/.zshenv
	ln -fs $(DIR)/bash_logout ~/.bash_logout
	ln -fs $(DIR)/bashrc ~/.bashrc
	ln -fs $(DIR)/gitconfig ~/.gitconfig
	ln -fs $(DIR)/htoprc ~/.htoprc
	ln -fs $(DIR)/sh ~/.sh
	ln -fs $(DIR)/tmux.conf ~/.tmux.conf
	ln -fs $(DIR)/vimrc ~/.vimrc
	ln -fs $(DIR)/zsh ~/.zsh
	ln -fs $(DIR)/zshrc ~/.zshrc

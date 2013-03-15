ZSH=$HOME/.oh-my-zsh

ZSH_THEME="robbyrussell"

plugins=(git)

source $ZSH/oh-my-zsh.sh

setopt HISTAPPEND HIST_IGNORE_SPACE HIST_REDUCE_BLANKS HIST_VERIFY HIST_IGNORE_ALL_DUPS HIST_IGNORE_DUPS SHARE_HISTORY INC_APPEND_HISTORY EXTENDED_HISTORY

# Aliases.
if [ -f "$HOME/.aliases" ]; then
	. "$HOME/.aliases"
fi

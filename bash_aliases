alias ls='ls --color=auto'

alias grep='grep --color=always --exclude-dir=.svn'
alias fgrep='fgrep --color=always --exclude-dir=.svn'
alias egrep='egrep --color=always --exclude-dir=.svn'
alias pgrep='grep --color=auto'

# Allow ANSI colors.
alias less='less -R'

alias ll='ls -lhF'
alias la='ls -aF'
alias lla='ls -lahF'
alias l='ls -CF'

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ......='cd ../../../../..'
alias .......='cd ../../../../../..'

alias gp='git push'
alias gd='git diff'
alias gc='git commit'
alias gca='git commit -a'
alias gco='git checkout'
alias gb='git branch'
alias gs='git status'
alias grm="git status | grep deleted | awk '{print \$3}' | xargs git rm"
alias gl="git log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"

function f() { find . -iname "*$@*.*" | grep --color "$@"; }

# Start tmux with support for 256 colors.
alias tmux='tmux -2'
alias tm='tmux attach || tmux new'

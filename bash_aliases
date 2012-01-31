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

alias gl='git pull'
alias gp='git push'
alias gd='git diff'
alias gc='git commit'
alias gca='git commit -a'
alias gco='git checkout'
alias gb='git branch'
alias gs='git status'
alias grm="git status | grep deleted | awk '{print \$3}' | xargs git rm"

function f() { find . -iname "*$@*.*" | grep --color "$@"; }

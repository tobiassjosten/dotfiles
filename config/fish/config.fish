set fish_greeting

if status is-interactive
    # Commands to run in interactive sessions can go here
end

fish_add_path -a -m /opt/homebrew/bin/
fish_add_path -a -m ~/go/bin
fish_add_path -a -m ~/.cargo/bin
fish_add_path -a -m /opt/homebrew/opt/mysql-client/bin
fish_add_path -a -m ~/google-cloud-sdk/bin
fish_add_path -a -m ~/.local/bin
fish_add_path -a -m ~/.cap/bin

set -Ux PYENV_ROOT $HOME/.pyenv
fish_add_path $PYENV_ROOT/bin
pyenv init - fish | source

set -gx EDITOR vim
set -gx VISUAL $EDITOR
set -gx PAGER less

alias cat="bat"
alias cdr="cd (git rev-parse --show-toplevel)"
alias k="kubectl"

alias gb="git branch"
alias gd="git diff"
alias gi="git log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
alias gs="git status -s"

alias tm="tmux attach 2> /dev/null || tmux new"

function got
    set pkg ./...
    if count $argv > /dev/null
        set pkg $argv
    end
    gotestsum --format standard-quiet -- $pkg -count 1
end

function goti
    set pkg ./...
    if count $argv > /dev/null
        set pkg $argv
    end
    gotestsum --format standard-quiet -- $pkg -count 1 --tags=integration
end

function gotw
    gotestsum --watch --format standard-quiet \
        --post-run-command "sh -c 'printf \"\\n%100s\\n\\n\" | tr \" \" \"=\"'" \
        -- -count 1
end

function gotb
    set pkg ./...
    if count $argv > /dev/null
        set pkg $argv
    end
    go test -bench=. $pkg
end

set -gx LSCOLORS 'GxFxCxDxBxegedabagaced'

set -gx __fish_git_prompt_color normal
set -gx __fish_git_prompt_char_stateseparator ''
set -gx __fish_git_prompt_showdirtystate
set -gx __fish_git_prompt_color_dirtystate yellow
set -gx __fish_git_prompt_showuntrackedfiles
set -gx __fish_git_prompt_char_untrackedfiles '*'
set -gx __fish_git_prompt_color_untrackedfiles cyan
set -gx __fish_git_prompt_stashstate '*'
set -gx __fish_git_prompt_color_stashstate brblue

function fish_prompt
    set_color yellow
    printf '%s' (prompt_pwd)

    fish_git_prompt

    set_color brwhite
    printf ' > '

    set_color normal
end

functions -q fish_user_key_bindings; or functions -c fish_default_key_bindings fish_user_key_bindings
set -U fish_escape_delay_ms 300
function fish_user_key_bindings
    fish_default_key_bindings
    bind \e. history-token-search-backward
end

source "/Users/tobias.sjosten/google-cloud-sdk/path.fish.inc"

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH

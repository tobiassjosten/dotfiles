set fish_greeting

if status is-interactive
    # Commands to run in interactive sessions can go here
end

fish_add_path -a -m ~/go/bin
fish_add_path -a -m ~/.cargo/bin
fish_add_path /opt/homebrew/opt/mysql-client/bin

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/tobias.sjosten/Downloads/google-cloud-sdk/path.fish.inc' ]; . '/Users/tobias.sjosten/Downloads/google-cloud-sdk/path.fish.inc'; end

alias gb="git branch"
alias gd="git diff"
alias gi="git log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
alias gs="git status -s"

function got
    set pkg ./...
    if count $argv > /dev/null
        set pkg $argv
    end
    gotestsum --format standard-quiet -- $pkg -count 1
end

function gotw
    gotestsum --watch --format standard-quiet \
        --post-run-command "sh -c 'printf \"\\n%100s\\n\\n\" | tr \" \" \"=\"'" \
        -- -count 1
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

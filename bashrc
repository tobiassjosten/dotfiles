# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
[ -z "$PS1" ] && return

# don't put duplicate lines in the history. See bash(1) for more options
# ... or force ignoredups and ignorespace
HISTCONTROL=ignoredups:ignorespace

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "$debian_chroot" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.
if [ -f ~/.bash_aliases ]; then
	. ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if [ -f /etc/bash_completion ] && ! shopt -oq posix; then
	. /etc/bash_completion
fi

# Include Ruby gems in PATH
if [ -d "/var/lib/gems/1.8/bin" ] ; then
    PATH="$PATH:/var/lib/gems/1.8/bin"
fi

# Load RVM function
[[ -s "$HOME/.rvm/scripts/rvm" ]] && . "$HOME/.rvm/scripts/rvm"

# Include PEAR executables in PATH
if [ -x pear ]; then
    PATH="$PATH:`pear config-show|grep bin_dir|awk '{ print $5 }'`"
fi

export SYMFONY="/usr/local/lib/symfony/1.4/lib"

# Configure colors, if available.
if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	c_reset='\[\e[0m\]'
	c_user='\[\033[1;33m\]'
	c_path='\[\e[0;33m\]'
	c_git_clean='\[\e[0;36m\]'
	c_git_dirty='\[\e[0;35m\]'
else
	c_reset=
	c_user=
	c_path=
	c_git_clean=
	c_git_dirty=
fi

# Function to assemble the Git part of our prompt.
git_prompt ()
{
	if ! git rev-parse --git-dir > /dev/null 2>&1; then
		return 0
	fi

	git_branch=$(git branch 2>/dev/null| sed -n '/^\*/s/^\* //p')

	if git diff --quiet 2>/dev/null >&2; then
		git_color="$c_git_clean"
	else
		git_color="$c_git_dirty"
	fi

	echo " [$git_color$git_branch${c_reset}]"
}

# Find Mac/Windows junk and flag it.
junk_check ()
{
  junk_mark=" \[\e[1;31m\]*\[\e[0m\]"
  [[ -f ".DS_Store" ]] && echo "$junk_mark"
  [[ -f ".thumbs" ]] && echo "$junk_mark"
}

# Thy holy prompt.
PROMPT_COMMAND='PS1="\[\e]2;\u@\h:\w\a\]${c_user}\u${c_reset}@${c_user}\h${c_reset}:${c_path}\w${c_reset}$(git_prompt)$(junk_check)\$ "'

. ~/.sh/env
. ~/.sh/login

# ---

# Defend against accidently overwriting files.
set -o noclobber

# Extend $PATH with ~/bin directory.
if [ -d "$HOME/bin" ]; then
	PATH="$HOME/bin:$PATH"
fi

# Improved history.
export HISTFILE="$HOME/.history"
export HISTCONTROL=ignoredups:erasedups:ignorespace
export HISTSIZE=100000
export HISTFILESIZE=200000

# Load xmodmap configuration.
if [ -f "$HOME/.xmodmaprc" ]; then
	xmodmap "$HOME/.xmodmaprc"
fi

# Source .bashrc if running Bash.
if [ -n "$BASH_VERSION" ]; then
	if [ -f "$HOME/.bashrc" ]; then
		. "$HOME/.bashrc"
	fi
fi

. ~/.bash/env

BASH_ENV=

. ~/.bash/login

if [ "$PS1" ]; then
	. ~/.bash/interactive
fi

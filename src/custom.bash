#!/usr/bin/env bash
export PATH="/usr/local/bin:/usr/local/sbin:./node_modules/.bin:$PATH"
export CDPATH=.:~:~/Projects/:~/Library/Application\ Support/

# Ignore duplicate entries in history
export HISTCONTROL=erasedups
# Increases size of history
export HISTSIZE=1000000
export HISTFILESIZE=1000000000
# Ignore matching commands in history
export HISTIGNORE="&:ls:ll:la:l.:pwd:exit:clear:clr:[bf]g:history"

# ctrl-D twice to exit shell (no more accidental exits?)
export IGNOREEOF=1

# Extended pattern matching in bash:
# ? Matches zero or one occurrence of the given patterns
# * Matches zero or more occurrences of the given patterns
# + Matches one or more occurrences of the given patterns
# @ Matches exactly one of the given patterns
# ! Matches anything except one of the given patterns
# example: Get a directory listing of all non PDF and PostScript files in the current directory
# ls -lad !(*.p@(df|s))
shopt -s extglob

# includes dotfiles in pathname expansion
shopt -s dotglob

# Case-insensitive globbing.
shopt -s nocaseglob

# Minor spell correction for cd commands.
shopt -s cdspell

# History is appended to the history file on exit instead of replacing.
shopt -s histappend

# Completion is not attempted on an empty line.
shopt -s no_empty_cmd_completion

# Multiline commands are a single command in history.
shopt -s cmdhist

# When the command contains an invalid history operation (for instance when
# using an unescaped "!" (I get that a lot in quick e-mails and commit
# messages) or a failed substitution (e.g. "^foo^bar" when there was no "foo"
# in the previous command line), do not throw away the command line, but let me
# correct it.
shopt -s histreedit

# Expand "!" history when pressing space
bind Space:magic-space

# Autojump completion
if [ -f `brew --prefix`/etc/autojump ]; then
	. `brew --prefix`/etc/autojump
fi

#
# PYTHON SETTINGS
#

# Add current python version to path:
export PATH="/Library/Frameworks/Python.framework/Versions/Current/bin:$PATH"

# Set python interpreter startup config.
export PYTHONSTARTUP=~/.pythonrc

# pip automatically respects an active virtualenv
export PIP_RESPECT_VIRTUALENV=true

# pip virtualenv base (via virtualenvwrapper)
# export PIP_VIRTUALENV_BASE=$WORKON_HOME

# virtualenvwrapper project home
export PROJECT_HOME="${HOME}/Projects"

# disable virtualenv prompt display
export VIRTUAL_ENV_DISABLE_PROMPT=True

# autoenv
source /usr/local/opt/autoenv/activate.sh

# virtualenvwrapper scripts.
# source virtualenvwrapper.sh

# node version manager (nvm)
[[ -s ~/.nvm/nvm.sh ]] && . ~/.nvm/nvm.sh

# pip completion
_pip_completion()
{
    COMPREPLY=( $( COMP_WORDS="${COMP_WORDS[*]}" \
                   COMP_CWORD=$COMP_CWORD \
                   PIP_AUTO_COMPLETE=1 $1 ) )
}
complete -o default -F _pip_completion pip

# django completion
_django_completion()
{
    COMPREPLY=( $( COMP_WORDS="${COMP_WORDS[*]}" \
                   COMP_CWORD=$COMP_CWORD \
	               DJANGO_AUTO_COMPLETE=1 $1 ) )
}
complete -F _django_completion -o default django-admin.py manage.py django-admin manage startproject startapp

# Intelligent command completion
# complete -d cd pushd rmdir
# complete -u finger mail
complete -v set unset

# Make less the default pager, and specify some useful defaults.
less_options=(
	# If the entire text fits on one screen, just show it and quit. (Be more
	# like "cat" and less like "more".)
	--quit-if-one-screen

	# Do not clear the screen first.
	--no-init

	# Like "smartcase" in Vim: ignore case unless the search pattern is mixed.
	--ignore-case

	# Do not automatically wrap long lines.
	--chop-long-lines

	# Allow ANSI colour escapes, but no other escapes.
	--RAW-CONTROL-CHARS

	# Do not ring the bell when trying to scroll past the end of the buffer.
	--quiet

	# Do not complain when we are on a dumb terminal.
	--dumb
)
export LESS="${less_options[*]}"
unset less_options
export PAGER='less'

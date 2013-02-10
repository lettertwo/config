#!/usr/bin/env bash

# Path to the bash it configuration
export BASH_IT=$HOME/.bash_it

# Lock and Load a custom theme file
# location /.bash_it/themes/
export BASH_IT_THEME='lettertwo'

# Set my editor and git editor
export EDITOR="/usr/local/bin/subl -w"
export GIT_EDITOR=$EDITOR

# Don't check mail when opening terminal.
unset MAILCHECK

# Load Bash It
source $BASH_IT/bash_it.sh

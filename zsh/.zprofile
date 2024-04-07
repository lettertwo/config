#!/usr/bin/env zsh
#
# Executes commands at the start of a login session.
#
# NOTE: This happens __before__ .zshrc in an interactive session.
#

if [[ -f ~/.zprofile ]]; then
    source ~/.zprofile
fi


#!/usr/bin/env zsh
#
# Executes commands at the start of a login session.
#
# NOTE: This happens __before__ .zshrc in an interactive session.
#

# Bootstrap homebrew
if [[ ! -d /usr/local/Cellar ]]; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
  brew bundle
fi

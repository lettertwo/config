#!/usr/bin/env zsh
#
# Executes commands at the start of a login session.
#
# NOTE: This happens __before__ .zshrc in an interactive session.
#

## find homebrew location
for HOMEBREW_BIN in /usr/local/bin/brew /usr/local/Homebrew/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
  if [[ -x "$HOMEBREW_BIN" ]]; then
    break
  fi
done

if [[ -x $HOMEBREW_BIN ]]; then
  eval "$($HOMEBREW_BIN shellenv)"
else
  echo "Homebrew not found!"
fi

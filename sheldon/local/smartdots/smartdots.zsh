#!/usr/bin/env zsh

# from https://github.com/denysdovhan/dotfiles/blob/master/lib/smartdots.zsh

# Quick change directories
# Expands .... -> ../../../
function smartdots() {
  if [[ $LBUFFER = *.. ]]; then
    LBUFFER+=/..
  else
    LBUFFER+=.
  fi
}
zle -N smartdots
bindkey . smartdots

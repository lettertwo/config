#!/usr/bin/env bash

# from https://github.com/denysdovhan/dotfiles/blob/master/lib/smartdots.zsh

# Quick change directories
# Expands .... -> ../../../
smartdots() {
  if [[ $LBUFFER = *.. ]]; then
    LBUFFER+=/..
  else
    LBUFFER+=.
  fi
}
zle -N smartdots
bindkey . smartdots

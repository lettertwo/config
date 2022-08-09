#! /usr/bin/env zsh

# From: https://blog.tarkalabs.com/optimize-zsh-fce424fcfd5
function profzsh() {
  shell=${1-$SHELL}
  ZPROF=true $shell -i -c exit
}

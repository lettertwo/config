#! /usr/bin/env zsh

# From: https://blog.tarkalabs.com/optimize-zsh-fce424fcfd5
function timezsh() {
  shell=${1-$SHELL}
  for i in $(seq 1 10); do /usr/bin/time $shell -i -c exit; done
}

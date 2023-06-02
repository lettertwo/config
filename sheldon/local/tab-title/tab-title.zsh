#! /usr/bin/env zsh

# From https://harrisonpim.com/blog/setting-better-terminal-tab-titles
is_git() {
  [[ $(git rev-parse --is-inside-work-tree 2>/dev/null) == true ]]
}

is_ssh() {
  [[ -n "$SSH_CLIENT" || -n "$SSH_TTY" ]]
}

tab_title() {
  local TITLE
  if is_git; then
   TITLE=$(git rev-parse --show-toplevel)
  else
    TITLE=$(PWD)
  fi

  if is_ssh; then
    print -Pn "\e]0;%n@${${(%):-%2m}#ip-*.} ${TITLE##$HOME(/Code|/.local/share|)/}\a"
  else
    print -Pn "\e]0;${TITLE##$HOME(/Code|/.local/share|)/}\a"
  fi
}
add-zsh-hook precmd tab_title

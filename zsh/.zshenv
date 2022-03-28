#!/usr/bin/env zsh
#
# Executes commands at login pre-zshrc.
#
# Adapted from the prezto/runcoms/zprofile

# Don't load global configs, i.e., /etc/zprofile, /etc/zshrc
setopt no_global_rcs

#
# XDG Base Directories
# https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
#
export XDG_CONFIG_HOME="$HOME/.config"     # configuration files
export XDG_CACHE_HOME="$HOME/.cache"       # non-essential data
export XDG_DATA_HOME="$HOME/.local/share"  # essential portable data
export XDG_STATE_HOME="$HOME/.local/state" # persistant non-portable data

#
# Browser
#

if [[ "$OSTYPE" == darwin* ]]; then
  export BROWSER='open'
fi

#
# Editors
#

if [[ ! -z "$ONIVIM_TERMINAL" ]]; then
  export EDITOR='oni2 --nofork --silent'
  export VISUAL='oni2 --nofork --silent'
elif [[ "$TERM_PROGRAM" == "vscode" ]]; then
  export EDITOR='code --wait'
  export VISUAL='code --wait'
elif [[ $+commands[lvim] ]]; then
  export VISUAL=lvim
  export EDITOR=$VISUAL
elif [[ $+commands[nvim] ]]; then
  export VISUAL=nvim
  export EDITOR=$VISUAL
else
  export VISUAL='vim'
  export EDITOR=$VISUAL
fi

#
# Language
#

if [[ -z "$LANG" ]]; then
  export LANG='en_US.UTF-8'
fi

#
# Paths
#

# Ensure path arrays do not contain duplicates.
typeset -gU cdpath fpath mailpath path

# Set the list of directories that Zsh searches for programs.
# We include common node_modules/.bin locations for convenience.
path=(
  {.,$HOME}/node_modules/.bin
  $HOME/.local/{bin,sbin}
  /usr/local/share/npm/bin
  $HOME/{bin,sbin}
  /usr/local/{bin,sbin}
  /usr/{bin,sbin}
  /{bin,sbin}
  /opt/X11/bin
)
fpath+=$XDG_STATE_HOME/zsh/completions

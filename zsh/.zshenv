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

export PYENV_ROOT="$XDG_DATA_HOME/pyenv"

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
elif [[ ! -z "$NVIM" && $+commands[nvr] ]]; then
  export GIT_EDITOR='nvr --nostart --remote-tab-wait +"set bufhidden=delete"'
  alias nvim='nvr -l'
  export EDITOR='nvim'
  export VISUAL=$VISUAL
elif [[ $+commands[nvim] ]]; then
  export VISUAL='nvim'
  export EDITOR=$VISUAL
else
  export VISUAL='vim'
  export EDITOR=$VISUAL
fi

#
# Paging
#
export LESS="\
  --ignore-case \
  --incsearch \
  --status-column \
  --LONG-PROMPT \
  --RAW-CONTROL-CHARS \
  --HILITE-UNREAD \
  --tabs=2 \
  --no-init \
  --window=-4 \
  --use-color \
  "
export LESS_TERMCAP_mb=$'\E[1;31m'     # begin bold
export LESS_TERMCAP_md=$'\E[1;36m'     # begin blink
export LESS_TERMCAP_me=$'\E[0m'        # reset bold/blink
export LESS_TERMCAP_so=$'\E[01;44;33m' # begin reverse video
export LESS_TERMCAP_se=$'\E[0m'        # reset reverse video
export LESS_TERMCAP_us=$'\E[1;32m'     # begin underline
export LESS_TERMCAP_ue=$'\E[0m'        # reset underline

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

# Run path_helper if available (macOS)
# NOTE: this is normally run in /etc/profile,
# but since we're not loading global configs,
# We're doing this here to ensure that
# paths defined in /etc/paths.d are included.
if [ -x /usr/libexec/path_helper ]; then
  eval `/usr/libexec/path_helper -s`
fi

# Prepend the list of directories that Zsh searches for programs.
# We include project-local (e.g., node_modules)
# and managed (e.g., yarn, cargo) bin locations for convenience.
path[1,0]=(
  {.,$HOME}/node_modules/.bin
  $HOME/.local/{bin,sbin}
  $HOME/.cargo/bin
  $HOME/.yarn/bin
  /usr/local/share/npm/bin
  $PYENV_ROOT/bin
)

fpath+=$XDG_STATE_HOME/zsh/completions

#
# Homebrew
#

## find homebrew location
for HOMEBREW_BIN in /usr/local/bin/brew /usr/local/Homebrew/bin/brew /opt/homebrew/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
  if [[ -x "$HOMEBREW_BIN" ]]; then
    break
  fi
done

if [[ -x $HOMEBREW_BIN ]]; then
  eval "$($HOMEBREW_BIN shellenv)"
  fpath+=$HOMEBREW_PREFIX/share/zsh/site-functions
else
  echo "Homebrew not found!"
fi

# export ZPROF=true

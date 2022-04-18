#!/usr/bin/env zsh
#
# Executes commands at the start of an interactive session.
#

#
# Autoload
#

# Set the Zsh functions to load (man zshcontrib).
autoload -Uz "zargs"
autoload -Uz "zmv"
autoload run-help

#
# Options
#

setopt AUTO_CD                # Auto changes to a directory without typing cd.
setopt AUTO_PUSHD             # Push the old directory onto the stack on cd.
setopt PUSHD_IGNORE_DUPS      # Do not store duplicates in the stack.
setopt PUSHD_SILENT           # Do not print the directory stack after pushd or popd.
setopt PUSHD_TO_HOME          # Push to home directory when no argument is given.
setopt CDABLE_VARS            # Change directory to a path stored in a variable.
setopt MULTIOS                # Write to multiple descriptors.
setopt EXTENDED_GLOB          # Use extended globbing syntax.
setopt NO_BANG_HIST           # Let ! be !
unsetopt CLOBBER              # Do not overwrite existing files with > and >>.
                              # Use >! and >>! to bypass.
unsetopt NOMATCH              # Allow ^ to be used unescaped in args.
                              # See https://github.com/ohmyzsh/ohmyzsh/issues/449#issuecomment-6973425
setopt HIST_FIND_NO_DUPS      # Do not find duplicate command when searching
setopt HIST_EXPIRE_DUPS_FIRST # Trim duplicates from history file first
setopt HIST_IGNORE_SPACE      # Prepend a command with a space to exclude it from history
setopt SHARE_HISTORY          # Share history across zsh sessions

# The file where the history is stored
export HISTFILE="$XDG_STATE_HOME/zsh/history"
# Number of events loaded into memory
export HISTSIZE=10200
# Number of events stored in the zsh history file
export SAVEHIST=10000

# fzf
export FZF_DEFAULT_OPTS="--layout reverse --info inline --height 40%"
export FZF_CTRL_T_OPTS="--preview \"bat --style=numbers --color=always --line-range :500 {}\""
export FZF_DEFAULT_COMMAND='rg --files --no-ignore --hidden --follow --glob "!.git/*"'
export FZF_CTRL_T_OPTS="--preview \"bat --style=numbers --color=always --line-range :500 {}\""
# disable sort when completing `git checkout`
zstyle ':completion:*:git-checkout:*' sort false
# set descriptions format to enable group support
zstyle ':completion:*:descriptions' format '[%d]'
# set list-colors to enable filename colorizing
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
# preview directory's content with exa when completing cd
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'exa -1 --color=always $realpath'
# switch group using `,` and `.`
zstyle ':fzf-tab:*' switch-group 'ctrl-h' 'ctrl-l'
# give a preview of commandline arguments when completing `kill`
zstyle ':fzf-tab:complete:(kill|ps):argument-rest' fzf-flags --preview-window=down:3:wrap

# Use fd instead of the default find command for listing path candidates.
_fzf_compgen_path() {
  fd --hidden --follow --exclude ".git" . "$1"
}

# Use fd to generate the list for directory completion
_fzf_compgen_dir() {
  fd --type d --hidden --follow --exclude ".git" . "$1"
}

# z.lua (smart cd command)
export _ZL_DATA="$XDG_CACHE_HOME/zlua"
export _ZL_MATCH_MODE=1
export _ZL_ROOT_MARKERS=".git,.svn,.hg,package.json"

# nvm
export NVM_AUTO_USE=true

# poetry
export POETRY_CACHE_DIR="$XDG_CACHE_HOME/pypoetry"

# Initialize starship
eval "$(starship init zsh)"

# Initialize aliases
for file in $ZDOTDIR/aliases/*.zsh; do
  source "$file"
done

# Initialize functions
for file in $ZDOTDIR/functions/*.zsh; do
  source "$file"
done

# Initialize sheldon plugins
eval "$(sheldon source)"

# Initialize fzf
source "$BREW_PREFIX/opt/fzf/shell/completion.zsh" 2> /dev/null
source "$BREW_PREFIX/opt/fzf/shell/key-bindings.zsh"
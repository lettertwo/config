#! /usr/bin/env fish

#
# XDG Base Directories
# https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
#
set -q XDG_CONFIG_HOME; or set -Ux XDG_CONFIG_HOME $HOME/.config    # configuration files
set -q XDG_CACHE_HOME; or set -Ux XDG_CACHE_HOME $HOME/.cache       # non-essential data
set -q XDG_DATA_HOME; or set -Ux XDG_DATA_HOME $HOME/.local/share   # essential portable data
set -q XDG_STATE_HOME; or set -Ux XDG_STATE_HOME $HOME/.local/state # persistant non-portable data
mkdir -p $XDG_CONFIG_HOME $XDG_DATA_HOME $XDG_STATE_HOME $XDG_CACHE_HOME

# Fish vars
set -q __fish_cache_dir; or set -Ux __fish_cache_dir $XDG_CACHE_HOME/fish
set -q __fish_plugins_dir; or set -Ux __fish_plugins_dir $__fish_config_dir/plugins
test -d $__fish_cache_dir; or mkdir -p $__fish_cache_dir

# Ensure manpath and infopath exist
set -q MANPATH; or set -gx MANPATH ''
set -q INFOPATH; or set -gx INFOPATH ''

set -qU OS_TYPE; or set -Ux OS_TYPE (uname)

if test "$OS_TYPE" = Darwin
  set -gx BROWSER open
end

#
# Editors
#
if test "$TERM_PROGRAM" = vscode
    # in vscode, use vscode as editor.
    set -gx EDITOR code --wait
    set -gx VISUAL code --wait
else if test -n "$NVIM" && command -v nvr > /dev/null
    # in neovim with nvr available, use nvr as editor.
    set -gx GIT_EDITOR nvr --nostart --remote-tab-wait +"set bufhidden=delete"
    alias nvim='nvr -l'
    set -gx EDITOR 'nvim'
    set -gx VISUAL $VISUAL
else if command -v nvim > /dev/null
    # if neovim is available, use it as editor.
    set -gx VISUAL 'nvim'
    set -gx EDITOR $VISUAL
else
    # otherwise, use vim as editor.
    set -gx VISUAL 'vim'
    set -gx EDITOR $VISUAL
end

#
# Paging
#
set -gx LESS "\
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
set -gx LESS_TERMCAP_mb (set_color -o blue)
set -gx LESS_TERMCAP_md (set_color -o cyan)
set -gx LESS_TERMCAP_me (set_color normal)
set -gx LESS_TERMCAP_so (set_color -r normal)
set -gx LESS_TERMCAP_se (set_color normal)
set -gx LESS_TERMCAP_us (set_color -u magenta)
set -gx LESS_TERMCAP_ue (set_color normal)

# Allow subdirs for functions and completions.
set fish_function_path (path resolve $__fish_config_dir/functions/*/) $fish_function_path
set fish_complete_path (path resolve $__fish_config_dir/completions/*/) $fish_complete_path

# Add more man page paths.
for manpath in (path filter $__fish_data_dir/man /usr/local/share/man /usr/share/man)
    set -a MANPATH $manpath
end

# Add bin directories to path.
fish_add_path --global --prepend  \
  node_modules/.bin \
  $HOME/node_modules/.bin \
  $HOME/.local/{bin,sbin} \
  $HOME/.cargo/bin \
  $HOME/.yarn/bin \
  /usr/local/share/npm/bin \

# Disable new user greeting.
set fish_greeting

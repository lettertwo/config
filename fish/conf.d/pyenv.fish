type -q pyenv || return 1
set -q PYENV_ROOT; or set -Ux PYENV_ROOT $XDG_DATA_HOME/pyenv
cachecmd pyenv init - | source
fish_add_path $PYENV_ROOT/bin

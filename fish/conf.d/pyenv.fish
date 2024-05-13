type -q pyenv || return 1
set -q PYENV_ROOT; or set -Ux PYENV_ROOT $HOME/.pyenv
cachecmd pyenv init - | source
fish_add_path $PYENV_ROOT/bin

type -q pyenv || return 1
set -q PYENV_ROOT; or set -Ux PYENV_ROOT $XDG_DATA_HOME/pyenv
fish_add_path $PYENV_ROOT/bin

# Inlined from:
# cachecmd -- pyenv init - --no-rehash --no-push-path | source
if not contains -- "/Users/eeldredge/.local/share/pyenv/shims" $PATH
    set -gx PATH '/Users/eeldredge/.local/share/pyenv/shims' $PATH
end
set -gx PYENV_SHELL fish

cachecmd pyenv rehash

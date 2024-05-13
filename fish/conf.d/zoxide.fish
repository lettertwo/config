# Initialize zoxide for fast jumping with 'z'.
type -q zoxide || return 1
set -q _ZO_DATA_DIR; or set -Ux _ZO_DATA_DIR $XDG_DATA_HOME/zoxide
cachecmd zoxide init fish | source

type -q fnm || return 1

# NOTE: Cannot cache this command because it generates version-specific symlinks
# which, when cached, will inadvertently make node version changes universal
# to all shells instead of local to the current shell.
fnm env --use-on-cd --version-file-strategy recursive --corepack-enabled --resolve-engines | source

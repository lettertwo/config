#! /usr/bin/env zsh

#
# Git aliases
#

alias g='git'

function () {
  declare -A seen

  # add_alias
  #
  # This function adds a new alias for a Git extension.
  #
  # Globals:
  #   None
  #
  # Arguments:
  #   $1: The alias to add.
  #   $2: The name of the Git extension.
  #
  # Returns:
  #   0: If the alias was added successfully.
  #   1: If the alias could not be added (for example, if an alias with the same name already exists).
  #
  # Example usage:
  #   add_alias my_alias my_extension
  function add_alias() {
    local name=$1

    if [ -z $name ]; then
      # print "Skipping $name; seems empty?"
      return 1;
    fi

    local target=${2-$1}

    if [ -z "${seen[$name]}" ]; then
      # print "Adding alias \"g$name\"=\"git $target\""
      alias "g$name"="git $target"
      seen[$name]=$target
      return 0;
    else
      if [[ $seen[$name] != $target ]]; then
        print -u2 "Alias \"g$name\"=\"git $target\" conflicts with \"g$name\"=\"git $seen[$name]\"!"
      else
        # print "Skipping $name; already added"
      fi
      return 1;
    fi
  }

  # alias all git aliases for even speedier access:
  local config_alias
  for config_alias (
    ${(s/alias./)$(git config --get-regexp alias)}
  ) add_alias $config_alias[(w)1]

  # alias the common git commands
  local common
  for common (
    add
    bisect
    branch
    checkout
    cherry
    cherry-pick
    clone
    commit
    diff
    fetch
    grep
    init
    log
    merge
    mv
    pull
    push
    rebase
    reflog
    reset
    rm
    show
    status
    stash
    switch
    tag
    worktree
  ) add_alias $common


  # alias all installed git-* extensions
  local path_dir git_extension subcommand
  for path_dir in $(echo $PATH | tr ":" "\n"); do
    for git_extension in $(ls $path_dir/git-* 2>/dev/null); do
      subcommand=${${git_extension##*/}#git-}
      add_alias $subcommand
    done
  done

  # cleanup
  unfunction add_alias
}

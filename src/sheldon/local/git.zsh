#
# Git aliases
#

alias g='git'

# alias the common git commands
for c (
  add
  bisect
  branch
  checkout
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
) alias "g$c"="git $c"

# alias all git aliases for even speedier access:
s=`git config --get-regexp alias`
for i ("${(s/alias./)s}") alias "g$i[(w)1]"="git $i[(w)1]"

# cleanup
unset c; unset s; unset i;

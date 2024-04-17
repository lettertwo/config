#! /usr/bin/env zsh

# Chose a worktree to work on
# TODO: autocomplete with worktrees
# TODO: Support discovering worktrees across known locations, not just CWD.
# TODO: Take advantage fzf --history to remember previous worktrees
# TODO: Write this in rust? Inspo: https://github.com/ajeetdsouza/zoxide
function workon() {
  local new verbose
  while getopts ":hvn" opt
  do
    case $opt in
        (*h) print -r -- "workon [-vn] [worktree]

Given no arguments, workon will show an interactive list of worktrees to choose from.

If [worktree] is provided, workon will attempt to switch to that worktree.
If a matching worktree is found, it will be switched to.
If there are multiple matches, an interactive list of the the matching worktrees will be shown.

If no worktree matches are found, or if the -n flag is provided, a new worktree will be created.

Options:
  -h  Show this help message
  -v  Turn the volume up to 11
  -n  Create a new worktree
        "
        return 0
        ;;
      n) new=1 ;;
      v) verbose=1 ;;
      \?) >&2 print -r -- "workon: invalid option: $OPTARG"            ; return 1 ;;
      :)  >&2 print -r -- "workon: missing required argument: $OPTARG" ; return 1 ;;
    esac
  done
  local query=${@[OPTIND++]#_}

  if [[ $new ]]; then
    worktree "$query"
    return
  fi

  local selection=`git worktree list | grep -v \(bare\) | fzf --query=$query --exit-0 --select-1 | cut -d' ' -f1`

  if [[ -n $selection ]]; then
    cd $selection
    return $?
  elif [[ -n $query ]]; then
    worktree "$query"
  else
    >&2 print -r -- "workon: no worktree found matching '$query'"
  fi
  return 1
}

# TODO: Other things we need:
# Ability to easily create a worktree with namespcaing.
# Also see: https://lists.mcs.anl.gov/pipermail/petsc-dev/2021-May/027436.html
#
# The anatomy of the command is:
#
#   `git work tree add --track -b <branch> ../<path> <remote>/<remote-branch>`
#
# we want `<branch>` to exactly match `<remote-branch>`
# We want `<path>` to exactly match `<branch>`
#
# Use case: checking out an existing branch
#
#   `git worktree add --track -b bdo/browser-reporter ../bdo/browser-reporter origin/bdo/browser-reporter`
#
# Use case: creating a new branch
# In this case, we aren't tracking a remote (yet?)
#
#   `git worktree add -b lettertwo/some-thing ../lettertwo/some-thing`
#
# Hooks: on creation, we will often want to copy artifacts from the base worktree (e.g., node_modules, build dirs)
# One approach to this is the `copyuntracked` util that can (perhaps interactively?) copy over
# any untracked or git ignored files. It would be nice if this script was also SCM-aware, in that it could
# suggest rebuilds, or re-running install, etc, if the base artifacts are much older than the new worktree HEAD.
#
# Cleanup:
#
#   `git worktree remove ../lettertwo/some-thing \
  #     && git branch -d lettertwo/some-thing`
#
# Cleanup remote:
#
#   `git worktree remove ../bdo/browser-reporter \
  #     && git branch -d bdo/browser-reporter \
  #     && git push --delete origin bdo/browser-reporter`
function worktree() {
  >&2 print -r -- "not implemented yet: worktree: $@"
  return 1
}

# Copy files that are not tracked by git from one directory to another.
function copyuntracked() {
  local from to dryrun verbose
  while getopts ":hvn" opt
  do
    case $opt in
        (*h) print -r -- "copyuntracked [-vn] <from> <to>

Copy any untracked files in <from> to <to>.

Untracked files are files that are ignored by git, or files that are not in the git index.

This util is a useful complement to a git worktree workflow. Git worktrees provide
a mechanism for maintaining multiple branches of a repository simultaneously, without
having to switch between branches (and using stash to keep WIP stuff around, etc).
See \`man git-worktree\` for more information.

However, one drawback of this approach vs. the traditional branch workflow is that any untracked
artifacts in the working directory, such as installed node modules, build caches, etc.,
have to be recreated or otherwise manually copied over when creating a new worktree.

That's where \`copyuntracked\` comes in!

If possible, copying will be done using \`clonefile\` (\`man clonefile\`),
which is a copy-on-write optimization over a potentially much slower copy operation.

Options:
  -h  Show this help message
  -v  Turn the volume up to 11
  -n  Dry run. Don't actually copy anything, but print out what would be copied.

Positional Arguments (required in order):

  <from> - The source directory. Must be a directory within a git repository.
  <to>   - The target directory. This is expected to be, but not required to be,
           a git worktree of the same repository as <from>.

Examples:

  # Copy untracked files from the main worktree to a feature branch worktree:
  copyuntracked  ./main ./feature-branch
        "
        return 0
        ;;
      v) verbose=1 ;;
      n) dryrun=1 ;;
      \?) >&2 print -r -- "copyuntracked: invalid option: $OPTARG"            ; return 1 ;;
      :)  >&2 print -r -- "copyuntracked: missing required argument: $OPTARG" ; return 1 ;;
    esac
  done

  if (( OPTIND > ARGC )); then
    >&2 print -r -- "copyuntracked: missing <from> argument"
    return 1
  fi
  from=${@[OPTIND++]#_}

  if (( OPTIND > ARGC )); then
    >&2 print -r -- "copyuntracked: missing <to> argument"
    return 1
  fi
  to=${@[OPTIND++]#_}

  if [[ ! -d $from ]]; then
    >&2 print -r -- "copyuntracked: <from> must be a directory: $from"
    return 1
  fi

  if [[ ! -d $to ]]; then
    >&2 print -r -- "copyuntracked: <to> must be a directory: $to"
    return 1
  fi

  git -C $from rev-parse --git-dir > /dev/null 2>&1
  if [[ $? -ne 0 ]]; then
    >&2 print -r -- "copyuntracked: <from> must be a git repository: $from"
    return 1
  fi

  git -C $to rev-parse --git-dir > /dev/null 2>&1
  if [[ $? -ne 0 ]]; then
    >&2 print -r -- "copyuntracked: <to> must be a git repository: $to"
    return 1
  fi

  if [[ $dryrun ]]; then
    >&2 print -r -- "copyuntracked: dry run. not actually copying anything."
    git -C "$from" ls-files -oz --directory | xargs -0 -I{} -n1 echo cp -R -c "$from/{}" "$to/{}"
  elif [[ $verbose ]]; then
    >&2 print -r -- "copyuntracked: copying untracked files from $from to $to"
    git -C "$from" ls-files -oz --directory | xargs -0 -I{} -n1 cp -v -R -c "$from/{}" "$to/{}"
  else
    git -C "$from" ls-files -oz --directory | xargs -0 -I{} -n1 cp -R -c "$from/{}" "$to/{}"
  fi


  return $?
}

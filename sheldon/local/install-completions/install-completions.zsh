#! /usr/bin/env zsh

install-completions() {
  local ttl=h+24
  local dir=${XDG_STATE_HOME:-~/.local/state}/zsh/completions
  local name cmd output result
  while getopts ":ht:d:" opt
  do
    case $opt in
      (*h) print -r -- 'install-completions [-t <ttl>] [-d <dir>] <name> <cmd>

Evaluates `<cmd>` to generate a completion function and caches it as `<name>`.

Options:

  -t <unit><operator><n>
     Define a time to live for the function cache. Defaults to `h+24`.

     The format for `-t` matches the zsh date globbing syntax.

     The `<unit>` can be:
       `M` - months (30 days)
       `w` - weeks
       `d` - days
       `h` - hours
       `m` - minutes
       `s` - seconds

     The `<operator>` can be:
       `+` - Generated more than `<n> <unit>` ago
       `-` - Generated less than `<n> <unit>` ago.

  -d <dir>
     Directory where the completion file will be cached.
     Defaults to `${XDG_STATE_HOME:-~/.local/state}/zsh/completions`.

     This directory should be on the shell `fpath` for `compinit` to find it.

Positional Arguments (required in order):

  <name> - The name of the completion function.
  <cmd>  - Expression to generate a completion function when evaluated.

Examples:

  install-completions graphite gt completion
  install-completions -t w+1 -d ~/.zsh/completions graphite '\'gt completion\'''
        return 0
      ;;
      t)
        ttl=$OPTARG
        if [[ ! $ttl =~ ^[Mwdhms][+-][0-9]+$ ]]; then
          >&2 print -r -- "install-completions: invalid ttl: $ttl"
          return 1
        fi
      ;;
      d)
        dir=$OPTARG
        if [[ ! -d $dir ]]; then
          >&2 print -r -- "install-completions: dir does not exist: $dir"
          return 1
        fi
      ;;
      \?) >&2 print -r -- "install-completions: invalid option: $OPTARG"            ; return 1;;
      :)  >&2 print -r -- "install-completions: missing required argument: $OPTARG" ; return 1;;
    esac
  done

  if (( OPTIND > ARGC )); then
    >&2 print -r -- "install-completions: missing <name> argument"
    return 1
  fi
  name=${dir%/}/_${@[OPTIND++]#_}

  if (( OPTIND > ARGC )); then
    >&2 print -r -- "install-completions: missing <cmd> argument"
    return 1
  fi
  cmd=$@[OPTIND,-1]

  output=$(eval " $cmd" 2>&1)
  result=$?

  if (( $result != 0 )); then
    >&2 print -rl -- "install-completions: error evaluating ${cmd}:" $output
    return $result
  fi

  if [[ ! -f $name ]]; then
    echo $output > $name
  else
    for dump in $name(N.m$ttl); do
      echo $output >! $name
    done
  fi
}


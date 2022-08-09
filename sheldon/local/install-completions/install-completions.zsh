#! /usr/bin/env zsh

install-completions() {
  local ttl=h+24
  local dir=${XDG_STATE_HOME:-~/.local/state}/zsh/completions
  local name cmd output code dryrun update verbose
  while getopts ":hvnft:d:" opt
  do
    case $opt in
      (*h) print -r -- 'install-completions [-vnf] [-t <ttl>] [-d <dir>] <name> [cmd]

Evaluates `[cmd]` to generate a completion function and caches it as `<name>`.

if [cmd] is not provided, waits for `stdin` to provide the contents instead.

Options:

  -v
     More noise.

  -n
     Print the contents of the evaluated completion script to stdout instead of
     writing to disk. If the install would do nothing (`-t` has not expired),
     prints a message to stderr instead.

     With `-f`, forces printing of the contents (ignoring `-t`).

  -f
     Force the installation. The `-t` argument will have no effect.

     With `-n`, forces printing of the contents (ignoring `-t`).

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
  [cmd]  - Expression to generate a completion module when evaluated.
           If not provided, then the contents of the completion module
           are expected to be piped in.

Examples:

  install-completions graphite gt completion

  gt completion | install-completions graphite

  gt completion | install-completions -t w+1 -d ~/.zsh/completions graphite

  install-completions graphite <<- EOF
    #compdef gt
    _gt() { ... }
    compdef _gt gt
  EOF'
        return 0
      ;;
      v) verbose=1 ;;
      n) dryrun=1 ;;
      f) update=1 ;;
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

  if [[ ! $update ]]; then
    if [[ ! -f $name ]]; then
      update=1
    else
      for dump in $name(N.m$ttl); do
        update=1
        break
      done
    fi
  fi

  if [[ $update ]]; then
    if (( OPTIND > ARGC )); then
      read -rd '' output;
      code=0
    else
      cmd=$@[OPTIND,-1]
      output=$(eval " $cmd" 2>&1)
      code=$?
    fi

    if (( $code != 0 )); then
      >&2 print -rl -- "install-completions: error evaluating ${cmd}:" $output
      return $code
    fi

    if [[ $dryrun ]]; then
      print -r -- $output
    else
      echo $output >! $name
    fi
    if [[ $verbose ]]; then
      >&2 print -r -- "install-completions: updated ${name:t}."
    fi
  elif [[ $verbose || $dryrun ]]; then
    >&2 print -r -- "install-completions: ${name:t} is up-to-date ($ttl)."
  fi
}


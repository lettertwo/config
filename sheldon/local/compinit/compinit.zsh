#!/usr/bin/env zsh

autoload -Uz compinit

comprebuild() {
  local zcompdump=${1:-$XDG_CACHE_HOME/zsh/zcompdump}
  rm -f $1:-$zcompdump 2>/dev/null
  compinit -d $zcompdump
}

complist() {
  for command completion in ${(kv)_comps}
    do
      printf "%-32s %s\n" $command $completion
  done | sort
}

function() {
  local zcompdump=${1:-$XDG_CACHE_HOME/zsh/zcompdump}

  if [[ ! -f $zcompdump ]]; then
    echo "rebuilding early"
    comprebuild $zcompdump
    return
  fi

  local rebuild=false
  local zcompdump_mtime=$(date -u -r $(stat -f %m $zcompdump) "+%Y-%m-%dT%H:%M:%SZ")

  if command -v fd >/dev/null 2>&1; then
    # Rebuild compdump whenever any files in $fpath are newer
    for dir in $fpath; do
      if [[ ! -d $dir ]]; then
        continue
      fi

      local newer_files=$(fd . $dir --type f --newer $zcompdump_mtime)
      if [[ -n $newer_files ]]; then
        rebuild=true
        break
      fi
    done
  fi

  # Rebuild compdump whenever it is more than 24 hrs old.
  # based on https://gist.github.com/ctechols/ca1035271ad134841284
  for dump in $zcompdump(N.mh+24); do
    rebuild=true
    break
  done

  if $rebuild; then
    echo "rebuilding"
    comprebuild $zcompdump
  else
    compinit -C -d $zcompdump
  fi
}

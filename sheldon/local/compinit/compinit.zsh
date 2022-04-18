#!/usr/bin/env zsh

autoload -Uz compinit

comprebuild() {
  compinit -d $XDG_CACHE_HOME/zsh/zcompdump
}

# Rebuild comp dump whenever it is more than 24 hrs old.
# based on https://gist.github.com/ctechols/ca1035271ad134841284
for dump in $XDG_CACHE_HOME/zsh/zcompdump(N.mh+24); do
  comprebuild
done

compinit -C -d $XDG_CACHE_HOME/zsh/zcompdump

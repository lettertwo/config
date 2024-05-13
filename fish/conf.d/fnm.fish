type -q fnm || return 1
cachecmd -- fnm env --use-on-cd | source

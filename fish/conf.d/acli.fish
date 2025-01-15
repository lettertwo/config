type -q acli || return 1
cachecmd acli completion fish | source
alias a="acli"

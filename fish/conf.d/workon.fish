# Initialize workon
type -q git-workon || return 1
git workon shell-init fish | source

abbr -a -g gw workon

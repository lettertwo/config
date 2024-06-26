#
# Aliases & Functions
#

# lsd versions of some ls aliases.
alias ls='lsd'
# Lists in one column, hidden files, sorted by extension.
alias l='lsd -1a --extensionsort'
# Lists human readable sizes.
alias ll='lsd -lh --permission octal --git --icon always --extensionsort'
# Lists human readable sizes, recursively.
alias lr='ll -R'
# Lists human readable sizes, hidden files.
alias la='ll -a'
# Lists sorted by size, largest last.
alias lk='ll --sizesort'
# Lists sorted by date, most recent last.
alias lt='ll --timesort --reverse'

# IP addresses
alias ip="dig +short myip.opendns.com @resolver1.opendns.com"
alias localip="ipconfig getifaddr en1"
alias ips="ifconfig -a | grep -o 'inet6\? \(\([0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\)\|[a-fA-F0-9:]\+\)' | sed -e 's/inet6* //'"

# Use bottom instead of top/htop
alias top='btm'
alias htop='btm'

# Use trash instead of rm (macOS only)
if [[ "$OSTYPE" == darwin* ]]; then
  alias rm='trash'
fi

# Use delta instead of diff
alias diff='delta'

# Use bat instead of cat
alias cat='bat'

# Use fd instead of find
alias find='fd'

# Use dust instead of du
alias du='dust'

# Use duf isntead of df
alias df='duf'

# Use tldr instead of help
alias help='tldr'

# Use broot instead of tree
alias tree='broot'

# Use fnm instead of nvm
alias nvm='fnm'

# lazygit
alias lg='lazygit'

# Change dir fast
alias d='dirs -v'
for index ({1..9}) alias "$index"="cd +${index}"; unset index

# Find process listening on a port
function whoson() {
  sudo lsof -nP -i:$1 | grep LISTEN
}

# rage quit!!!
function fuck() {
  if killall -9 "$2"; then
    echo ; echo " (╯°□°）╯︵$(echo "$2"|toilet -f term -F rotate)"; echo
  fi
}
# alias rage quit for current user
alias fu='fuck you'

# Print some stats about zsh usage. Lifted from https://github.com/robbyrussell/oh-my-zsh/blob/20f536c06432a5cda86fc9b5bdf73fd1115cb84d/lib/functions.zsh
function zsh_stats() {
  fc -l 1 | awk '{CMD[$2]++;count++;}END { for (a in CMD)print CMD[a] " " CMD[a]/count*100 "% " a;}' | grep -v "./" | column -c3 -s " " -t | sort -nr | nl |  head -n20
}

# cd to git root directory.
function cdr() {
  cd "$(git rev-parse --show-toplevel)"
}

#
# vim aliases
#
if [[ $+commands[nvim] ]]; then
  alias vi='nvim'
  alias vim='nvim'
  alias vimdiff='nvim -d'
fi

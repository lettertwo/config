# lsd versions of some ls aliases.
abbr -a -g ls 'lsd'
# Lists in one column, hidden files, sorted by extension.
abbr -a -g l 'lsd -1a --extensionsort'
# Lists human readable sizes.
abbr -a -g ll 'lsd -lh --permission octal --git --icon always --extensionsort'
# Lists human readable sizes, recursively.
abbr -a -g lr 'll -R'
# Lists human readable sizes, hidden files.
abbr -a -g la 'll -a'
# Lists sorted by size, largest last.
abbr -a -g lk 'll -S'
# Lists sorted by date, most recent last.
abbr -a -g lt 'll -t -r'

# IP addresses
abbr -a -g ip "dig +short myip.opendns.com @resolver1.opendns.com"
abbr -a -g localip "ipconfig getifaddr en1"
abbr -a -g ips "ifconfig -a | grep -o 'inet6\? \(\([0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\)\|[a-fA-F0-9:]\+\)' | sed -e 's/inet6* //'"

# Use bottom instead of top/htop
abbr -a -g top 'btm'
abbr -a -g htop 'btm'

# Use trash instead of rm (macOS only)
if test (uname) = Darwin
    abbr -a -g rm 'trash'
end

# Use delta instead of diff
abbr -a -g diff 'delta'

# Use bat instead of cat
abbr -a -g cat 'bat'

# Use fd instead of find
abbr -a -g find 'fd'

# Use dust instead of du
abbr -a -g du 'dust'

# Use duf instead of df
abbr -a -g df 'duf'

# Use fnm instead of nvm
abbr -a -g nvm 'fnm'

# lazygit
abbr -a -g lg 'lazygit'

# cd to git root directory.
abbr -a -g cdr 'cd (git rev-parse --show-toplevel)'

# vim aliases
if type -q nvim
    abbr -a -g vi 'nvim'
    abbr -a -g vim 'nvim'
    abbr -a -g vimdiff 'nvim -d'
end


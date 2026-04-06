# lsd versions of some ls aliases.
abbr -a ls lsd --hyperlink=auto
# Lists in one column, hidden files, sorted by extension.
abbr -a l 'lsd -1a --extensionsort'
# Lists human readable sizes.
abbr -a ll 'lsd -lh --permission octal -it --icon always --extensionsort'
# Lists human readable sizes, recursively.
abbr -a lr 'll -R'
# Lists human readable sizes, hidden files.
abbr -a la 'll -a'
# Lists sorted by size, largest last.
abbr -a lk 'll -S'
# Lists sorted by date, most recent last.
abbr -a lt 'll -t -r'

# IP addresses
abbr -a ip "dig +short myip.opendns.com @resolver1.opendns.com"
abbr -a localip "ipconfig getifaddr en1"
abbr -a ips "ifconfig -a | grep -o 'inet6\? \(\([0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\)\|[a-fA-F0-9:]\+\)' | sed -e 's/inet6* //'"

# Use bottom instead of top/htop
abbr -a top btm
abbr -a htop btm

# Use trash instead of rm (macOS only)
if test (uname) = Darwin && type -q trash
    abbr -a rm trash
end

# Use delta instead of diff
abbr -a diff delta

# Use bat instead of cat
abbr -a cat bat

# Use fd instead of find
abbr -a find fd

# Use dust instead of du
abbr -a du dust

# Use duf instead of df
abbr -a df duf

# Use fnm instead of nvm
abbr -a nvm fnm

# lazygit
abbr -a lg lazygit

# cd to git root directory.
abbr -a cdr 'cd (git rev-parse --show-toplevel)'

# vim aliases
if type -q nvim
    abbr -a vi nvim
    abbr -a vim nvim
    abbr -a vimdiff 'nvim -d'
end

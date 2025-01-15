type -q task || return 1
abbr -a -g t task
abbr -a -g ta "task add"
abbr -a -g tan "task add +next"

type -q tasksh || return 1
abbr -a -g tt tasksh

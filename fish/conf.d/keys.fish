# vi mode
set -g fish_key_bindings fish_vi_key_bindings
set -g fish_cursor_insert "line"
set -g fish_cursor_replace "underscore"


bind --mode insert . 'expand_dots'

bind --mode insert \cr 'history_search'
bind --mode insert -k btab 'complete_search'
bind --mode insert \t 'complete_search'
bind --mode insert \e 'cancel_search'

bind --mode insert \cj 'commandline -P; and down-or-search'
bind --mode insert \ck 'commandline -P; and up-or-search'
bind --mode insert \ch 'commandline -P; and commandline -f backward-char'
bind --mode insert \cl 'commandline -P; and commandline -f forward-char'

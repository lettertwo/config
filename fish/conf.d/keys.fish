# vi mode
set -g fish_key_bindings fish_vi_key_bindings
set -g fish_cursor_insert "line"
set -g fish_cursor_replace "underscore"

bind --mode insert . 'expand_dots'

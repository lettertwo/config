# vi mode
set -g fish_key_bindings fish_vi_key_bindings
set -g fish_cursor_insert line
set -g fish_cursor_replace underscore

bind --mode insert . expand_dots

bind -k btab 'kitty @ set-user-vars IS_FISH_PAGER=1; commandline -f complete-and-search'
bind -M insert -k btab 'kitty @ set-user-vars IS_FISH_PAGER=1; commandline -f complete-and-search'
bind -M visual -k btab 'kitty @ set-user-vars IS_FISH_PAGER=1; commandline -f complete-and-search'

bind \t 'kitty @ set-user-vars IS_FISH_PAGER=1; commandline -f complete'
bind -M insert \t 'kitty @ set-user-vars IS_FISH_PAGER=1; commandline -f complete'
bind -M visual \t 'kitty @ set-user-vars IS_FISH_PAGER=1; commandline -f complete'

bind -M insert \e 'kitty @ set-user-vars IS_FISH_PAGER; if commandline -P; commandline -f cancel; else; set fish_bind_mode default; commandline -f backward-char repaint-mode; end'

bind -M insert \cc 'kitty @ set-user-vars IS_FISH_PAGER; commandline -f cancel-commandline'

bind \cd 'kitty @ set-user-vars IS_FISH_PAGER; commandline -f delete-or-exit'
bind -M insert \cd 'kitty @ set-user-vars IS_FISH_PAGER; commandline -f delete-or-exit'

bind -M insert \cj 'commandline -P; and down-or-search'
bind -M insert \ck 'commandline -P; and up-or-search'
bind -M insert \ch 'commandline -P; and commandline -f backward-char'
bind -M insert \cl 'commandline -P; and commandline -f forward-char'

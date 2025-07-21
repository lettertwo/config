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

if test -x $XDG_CONFIG_HOME/kitty/kitty_scrollback_nvim.py
    function _kitty_scrollback_nvim_edit_command_buffer
        kitty @ kitten kitty_scrollback_nvim.py --env "KITTY_SCROLLBACK_NVIM_MODE=command_line_editing" --env "KITTY_SCROLLBACK_NVIM_EDIT_INPUT=$argv[-1]" $KITTY_SCROLLBACK_NVIM_EDIT_ARGS
        # give kitty-scrollback.nvim a chance to get the scrollback buffer
        # from kitty before exiting
        sleep 1
    end

    function kitty_scrollback_nvim_edit_command_buffer
        set --local --export VISUAL _kitty_scrollback_nvim_edit_command_buffer
        edit_command_buffer
        commandline ''
    end

    bind -M insert super-e kitty_scrollback_nvim_edit_command_buffer
    bind -M visual super-e kitty_scrollback_nvim_edit_command_buffer
    bind super-e kitty_scrollback_nvim_edit_command_buffer
end

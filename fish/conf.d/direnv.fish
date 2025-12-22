type -q direnv || return 1

# set -g direnv_fish_mode eval_on_arrow    # trigger direnv at prompt, and on every arrow-based directory change (default)
# set -g direnv_fish_mode eval_after_arrow # trigger direnv at prompt, and only after arrow-based directory changes before executing command
# set -g direnv_fish_mode disable_arrow    # trigger direnv at prompt only, this is similar functionality to the original behavior

direnv hook fish | source

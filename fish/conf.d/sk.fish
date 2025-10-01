type -q sk || return 1

# # set -q FZF_DEFAULT_OPTS; or set -Ux FZF_DEFAULT_OPTS "--layout reverse --info inline"
# set -q FZF_DEFAULT_OPTS; or set -Ux FZF_DEFAULT_OPTS "--layout reverse --info inline --height 80%"
# # set -q FZF_DEFAULT_OPTS; or set -Ux FZF_DEFAULT_OPTS "--layout reverse --info inline --height 40% --no-bold --bind='start:kitty @ set-user-vars IS_FZF' --bind='result:kitty @ set-user-vars IS_FZF'"
# set -q FZF_DEFAULT_COMMAND; or set -Ux FZF_DEFAULT_COMMAND 'rg --files --no-ignore --hidden --follow --glob "!.git/*"'
# set -q FZF_CTRL_T_OPTS; or set -Ux FZF_CTRL_T_OPTS "--height 40% --preview \"bat --style=numbers --color=always --line-range :500 {}\""

cachecmd -- sk --shell fish | source

# if type -q fzf_configure_bindings
#     # COMMAND            |  DEFAULT KEY SEQUENCE         |  CORRESPONDING OPTION
#     # Search Directory   |  Ctrl+Alt+F (F for file)      |  --directory
#     # Search Git Log     |  Ctrl+Alt+L (L for log)       |  --git_log
#     # Search Git Status  |  Ctrl+Alt+S (S for status)    |  --git_status
#     # Search History     |  Ctrl+R     (R for reverse)   |  --history
#     # Search Processes   |  Ctrl+Alt+P (P for process)   |  --processes
#     # Search Variables   |  Ctrl+V     (V for variable)  |  --variables
#     fzf_configure_bindings --directory=\ct --git_log=\cg\cg --git_status=\cg\cs --history=\cr --processes=\cp --variables=\cv
# end

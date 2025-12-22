type -q sk || return 1

set -q SKIM_DEFAULT_OPTIONS; or set -Ux SKIM_DEFAULT_OPTIONS "--reverse --info inline --height 40% --color=dark,\
fg:#FFFFFF,\
bg:#27212E,\
matched:#75DFC4,\
matched_bg:#3E3248,\
current_bg:#3E3248,\
current_match:#EB65B9,\
current_match_bg:#3E3248,\
spinner:#554C47,\
info:#7C6A96,\
prompt:#7C6A96,\
cursor:#75DFC4,\
selected:#FFE25F,\
header:#41B5C5,\
border:#EB65B9"

# Customizable UI Elements
# - fg: Normal text foreground color
# - bg: Normal text background color
# - matched (or hl): Matched text in search results
# - matched_bg: Background of matched text
# - current (or fg+): Current line foreground color
# - current_bg (or bg+): Current line background color
# - current_match (or hl+): Matched text in current line
# - current_match_bg: Background of matched text in current line
# - spinner: Progress indicator color
# - info: Information line color
# - prompt: Prompt color
# - cursor (or pointer): Cursor color
# - selected (or marker): Selected item marker color
# - header: Header text color
# - border: Border color for preview/layout

if test -e "$HOMEBREW_PREFIX/share/fish/vendor_completions.d/skim.fish"
    source "$HOMEBREW_PREFIX/share/fish/vendor_completions.d/skim.fish"
end

if type -q skim_key_bindings
    # - $SKIM_TMUX_OPTS
    # - $SKIM_CTRL_T_COMMAND
    # - $SKIM_CTRL_T_OPTS
    # - $SKIM_CTRL_R_OPTS
    # - $SKIM_ALT_C_COMMAND
    # - $SKIM_ALT_C_OPTS
    # - $SKIM_COMPLETION_TRIGGER (default: '**')
    # - $SKIM_COMPLETION_OPTS    (default: empty)
    skim_key_bindings
end

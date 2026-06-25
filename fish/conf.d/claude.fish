# Claude Code is not XDG-aware; point it at ~/.config/claude (tracked) instead of ~/.claude.
set -q CLAUDE_CONFIG_DIR; or set -Ux CLAUDE_CONFIG_DIR $XDG_CONFIG_HOME/claude

type -q claude || return 1
abbr -a c claude
abbr -a cc 'claude --continue'
abbr -a cr 'claude --resume'

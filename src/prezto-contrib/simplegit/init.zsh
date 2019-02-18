#
# Provides Git aliases and functions.
#
# Commands stolen from:
#   https://github.com/sorin-ionescu/prezto/tree/master/modules/git
#

# Return if requirements are not found.
if (( ! $+commands[git] )); then
  return 1
fi

# Load dependencies.
pmodload 'helper'

# Source module files.
source "${0:h}/alias.zsh"

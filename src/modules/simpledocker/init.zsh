#
# Docker
#
# Return if requirements are not found.
if (( ! $+commands[docker] )); then
  return 1
fi

local DOCKER_COMPLETION_PATH="${0:h}/completion"

if [[ ! -a $DOCKER_COMPLETION_PATH ]]; then
  mkdir -p $DOCKER_COMPLETION_PATH
  curl -L https://raw.githubusercontent.com/docker/compose/$(docker-compose version --short)/contrib/completion/zsh/_docker-compose > "$DOCKER_COMPLETION_PATH/_docker-compose"
  curl -L https://raw.githubusercontent.com/docker/cli/master/contrib/completion/zsh/_docker > "$DOCKER_COMPLETION_PATH/_docker"
fi

fpath=($DOCKER_COMPLETION_PATH $fpath)

zstyle ':completion:*:*:docker:*' option-stacking yes
zstyle ':completion:*:*:docker-*:*' option-stacking yes

# Load dependencies.
pmodload 'helper'

source "${0:h}/alias.zsh"

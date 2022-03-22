#!/usr/bin/env zsh
#
# Executes commands at the start of a login session.
#
# NOTE: This happens __before__ .zshrc in an interactive session.
#

# Bootstrap homebrew
if [[ ! -d /usr/local/Cellar ]]; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
  brew bundle
fi

export BREW_PREFIX="$(which brew | sed 's/\/bin\/brew//')"

# Use brew-installed zsh as the login shell.
if [ "$SHELL" != "$BREW_PREFIX/bin/zsh" ]; then

  # install zsh if not already installed
  if [ -z "$(brew list | grep zsh)" ]; then
    echo "Installing ZSH via Homebrew"
    brew install zsh
  fi

  # include homebrew zsh path in /etc/shells
  if [ -z "$(grep -irn "$BREW_PREFIX/bin/zsh" /etc/shells)" ]; then
    echo "Whitelisting Homebrew installed ZSH"
    sudo -s "echo '$BREW_PREFIX/bin/zsh' >> /etc/shells"
  fi

  # change shell to homebrew zsh
  echo "Changing shell from $SHELL to homebrew-installed zsh"
  chsh -s $BREW_PREFIX/bin/zsh

  if [[ $? != 0 ]]; then
    echo "Setup failed!"
  else
    echo "Restarting your session!"
    exec -l zsh
  fi
fi

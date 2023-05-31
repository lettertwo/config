#!/usr/bin/env zsh
#
# Executes commands at the start of a login session.
#
# NOTE: This happens __before__ .zshrc in an interactive session.
#

## find homebrew location
for HOMEBREW_BIN in /usr/local/bin/brew /usr/local/Homebrew/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
  if [[ -x "$HOMEBREW_BIN" ]]; then
    break
  fi
done

if [[ -x $HOMEBREW_BIN ]]; then
  eval "$($HOMEBREW_BIN shellenv)"

  # Use brew-installed zsh as the login shell.
  if [ "$SHELL" != "$HOMEBREW_PREFIX/bin/zsh" ]; then

    # install zsh if not already installed
    if [ -z "$(brew list | grep zsh)" ]; then
      echo "Installing ZSH via Homebrew"
      brew install zsh
    fi

    # include homebrew zsh path in /etc/shells
    if [ -z "$(grep -irn "$HOMEBREW_PREFIX/bin/zsh" /etc/shells)" ]; then
      echo "Whitelisting Homebrew installed ZSH"
      sudo -s "echo '$HOMEBREW_PREFIX/bin/zsh' >> /etc/shells"
    fi

    # change shell to homebrew zsh
    echo "Changing shell from $SHELL to homebrew-installed zsh"
    chsh -s $HOMEBREW_PREFIX/bin/zsh

    if [[ $? != 0 ]]; then
      echo "Setup failed!"
    else
      echo "Restarting your session!"
      exec -l zsh
    fi
  fi
else
  echo "Homebrew not found! Using default shell."
fi

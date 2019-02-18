#
# Fastlane
#
if (( ! $+commands[fastlane] )); then
  return 1
fi

if [[ ! "$PATH" == */.fastlane/bin* ]]; then
  export PATH="$PATH:$HOME/.fastlane/bin:"
fi

source "$HOME/.fastlane/completions/completion.zsh"

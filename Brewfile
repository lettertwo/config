# Homebrew Bundle
# https://github.com/Homebrew/homebrew-bundle

# brew all teh things
tap "homebrew/core" if OS.mac?
tap "homebrew/bundle" if OS.mac?
tap "homebrew/cask" if OS.mac?
tap "homebrew/cask-drivers" if OS.mac?
tap "homebrew/cask-fonts" if OS.mac?
tap "homebrew/services" if OS.mac?
tap "withgraphite/tap" if OS.mac?
tap "jesseduffield/lazygit"

# CLI Tools
brew "zsh" if OS.mac?
brew "git" if OS.mac?
brew "coreutils" if OS.mac?
brew "tree" if OS.mac?
brew "readline" if OS.mac?
brew "curl" if OS.mac?
brew "wget" if OS.mac?
brew "tldr" if OS.mac?
brew "trash" if OS.mac?
brew "lnav" if OS.mac?

brew "fzf"
brew "sheldon"
brew "ripgrep" # BurntSushi/ripgrep
brew "fd" # sharkdp/fd, replacement for find
brew "bat" # sharkdp/bat, replacement for cat
brew "exa" # ogham/exa, replacement for ls
brew "git-delta" # dandavison/delta, replacement for diff
brew "dust" # bootandy/dust, replacement for du
brew "duf" # muesli/duf, replacement for df
brew "bottom" # ClementTsang/bottom, replacement for top
brew "zoxide" # ajeetdsouza/zoxide, smarter cd

# misc. dev tooling
brew "watchman"
brew "graphviz"
brew "hyperfine"
brew "jq"

# yazi file browser
# NOTE: also requires fd, ripgrep, fzf, zoxide, jq (installed above)
brew "yazi"
brew "ffmpegthumbnailer" # for video thumbnails
brew "unar" # for archive preview
brew "poppler" # for pdf preview

# neovim dependencies
# See https://github.com/neovim/neovim/wiki/Building-Neovim#macos--homebrew
brew "ninja"
brew "cmake"
brew "libtool" if OS.mac?
brew "automake" if OS.mac?
brew "pkg-config" if OS.mac?
brew "gettext" if OS.mac?

# git
brew "gh" if OS.mac?
brew "git-absorb"
brew "git-lfs"
brew "graphite" if OS.mac?
brew "lazygit", args: ["HEAD"]

# node
brew "node"
brew "fnm" # fast node version manager

# python
brew "pyenv"
brew "pyenv-virtualenv"
brew "python"

# No more font patching!
cask "font-symbols-only-nerd-font" if OS.mac?

# Quick Look plugins
cask "syntax-highlight" if OS.mac? # https://github.com/sbarex/SourceCodeSyntaxHighlight

# QMK
cask "qmk-toolbox" if OS.mac? # https://github.com/qmk/qmk_toolbox

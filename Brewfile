# Homebrew Bundle
# https://github.com/Homebrew/homebrew-bundle

tap "jesseduffield/lazygit"
tap "lettertwo/tap"
tap "withgraphite/tap"

# fish shell
brew "fish"
brew "fisher"
brew "starship"

# password manager
cask "1password-cli"

# CLI Tools
brew "readline"
brew "coreutils"
brew "readline"
brew "curl"
brew "wget"
brew "terminal-notifier"
brew "fzf"
brew "ripgrep" # BurntSushi/ripgrep
brew "fd" # sharkdp/fd, replacement for find
brew "bat" # sharkdp/bat, replacement for cat
brew "lsd" # lsd-rs/lsd, replacement for ls
brew "dust" # bootandy/dust, replacement for du
brew "duf" # muesli/duf, replacement for df
brew "bottom" # ClementTsang/bottom, replacement for top
brew "zoxide" # ajeetdsouza/zoxide, smarter cd
brew "toilet" # very important

# misc. dev tooling
brew "awscli"
brew "direnv"
brew "graphviz"
brew "hyperfine"
brew "jq"
brew "lnav"
brew "watchman"

# git
brew "git"
brew "gh" if OS.mac?
brew "git-absorb" if OS.mac?
brew "git-delta" if OS.mac?
brew "git-lfs" if OS.mac?
brew "withgraphite/tap/graphite" if OS.mac?
brew "lazygit", args: ["HEAD"] if OS.mac?
brew "lettertwo/tap/git-workon" if OS.mac?

# neovim dependencies
# See https://github.com/neovim/neovim/wiki/Building-Neovim#macos--homebrew
brew "ninja"
brew "cmake"
brew "libtool"
brew "automake"
brew "pkg-config"
brew "gettext"
brew "tree-sitter-cli"

# lua
brew "luajit"
brew "luarocks"
brew "lua-language-server"
brew "stylua"

# node
brew "node"
brew "fnm" # fast node version manager
npm "corepack"
npm "@github/copilot-language-server"
npm "@mermaid-js/mermaid-cli"

# python
brew "uv"

# No more font patching!
cask "font-symbols-only-nerd-font" if OS.mac?

# Quick Look plugins
cask "syntax-highlight" if OS.mac? # https://github.com/sbarex/SourceCodeSyntaxHighlight

# QMK
# tap "osx-cross/arm"
# tap "osx-cross/avr"
# tap "qmk/qmk"
# cask "qmk-toolbox" if OS.mac? # https://github.com/qmk/qmk_toolbox
# brew "avr-gcc" if OS.mac? # needed for QMK
# brew "arm-gcc-bin" if OS.mac? # needed for QMK
# brew "qmk/qmk/qmk" if OS.mac?

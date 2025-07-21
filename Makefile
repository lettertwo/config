RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;34m
MAGENTA := \033[0;35m
CYAN := \033[0;36m
WHITE := \033[0;37m
END := \033[0m

INFO := $(BLUE)
WARN := $(YELLOW)
ERROR := $(RED)

MACOS := $(shell uname -s | grep Darwin 2> /dev/null)

log = @echo "$(INFO)$(1)$(END)"
err = @>&2 echo "$(ERROR)$(1)$(END)"
done = $(call log,"Done!")
run = @$(1) || (n=$$?; >&2 echo "$(ERROR)Failed!$(END)"; exit $$n)

### ZDOTDIR

define ZDOTDIR
export ZDOTDIR="$$HOME/.config/zsh"
endef

export ZDOTDIR
~/.zshenv:
ifneq ($(ZDOTDIR), "$$HOME/.config/zsh")
	$(call err,"ZDOTDIR misconfigured!")
	$(call log,"Configuring ZDOTDIR...")
	$(call run,echo "$$ZDOTDIR" | tee -a $@ > /dev/null)
	$(call run,echo 'source $$ZDOTDIR/.zshenv' | tee -a $@ > /dev/null)
	$(call done)
endif

### mkdirs

~/.%:
	$(call log,"Creating dir $@...")
	@mkdir -p $@

### laserwave

~/.local/share/laserwave.nvim: | ~/.local/share
	$(call err,"laserwave not found!")
	$(call log,"Installing laserwave...")
	$(call run,git clone git@github.com:lettertwo/laserwave.nvim.git $@)
	$(call done)

.PHONY: update-laserwave
update-laserwave: ~/.local/share/laserwave.nvim
	$(call log,"Updating laserwave...")
	$(call run,cd ~/.local/share/laserwave.nvim && git pull)
	$(call done)

~/.config/kitty/laserwave.conf: ~/.local/share/laserwave.nvim ~/.config/kitty
	$(call run,ln -sf $</dist/kitty/laserwave.conf $@)

~/.config/alacritty/laserwave.yml: ~/.local/share/laserwave.nvim ~/.config/alacritty
	$(call run,ln -sf $</dist/alacritty/laserwave.yml $@)

~/.config/wezterm/colors/laserwave.toml: ~/.local/share/laserwave.nvim ~/.config/wezterm/colors
	$(call run,ln -sf $</dist/wezterm/laserwave.toml $@)

~/.config/bat/themes/laserwave.tmTheme: ~/.local/share/laserwave.nvim ~/.config/bat/themes
	$(call run,ln -sf $</dist/laserwave.tmTheme $@)

~/.config/git/laserwave.gitconfig: ~/.local/share/laserwave.nvim
	$(call run,ln -sf $</dist/delta/laserwave.gitconfig $@)

~/.config/yazi/flavors/laserwave.yazi: ~/.local/share/laserwave.nvim ~/.config/yazi/flavors
	$(call run,ln -sf $</dist/yazi/laserwave.yazi $@)

### homebrew

BREW := $(shell command -v brew 2> /dev/null)

.PHONY: brew
brew:
ifndef BREW
	$(call err,"brew not found!")
	$(call log,"Installing brew...")
	$(call run,curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | /bin/bash /dev/stdin)
	$(call done)
endif

.PHONY: update-brew
update-brew: brew
	$(call log,"Updating brew bundle...")
	$(call run,brew bundle)
	$(call log,"Cleaning up...")
	$(call run,brew cleanup)
	$(call done)

### sheldon

SHELDON := $(shell command -v sheldon 2> /dev/null)

.PHONY: sheldon
sheldon: brew
ifndef SHELDON
	$(call err,"sheldon not found!")
	$(call log,"Installing sheldon...")
	$(call run,brew install sheldon)
	$(call done)
endif

.PHONY: update-sheldon
update-sheldon: sheldon
	$(call log,"Updating sheldon plugins...")
	$(call run,sheldon lock)
	$(call done)

### fish

FISH := $(shell command -v fish 2> /dev/null)

.PHONY: fish
fish: brew
ifndef FISH
	$(call err,"fish not found!")
	$(call log,"Installing fish...")
	$(call run,brew install fish fisher)
	$(call done)
endif

.PHONY: update-fish
update-fish: fish
	$(call log,"Updating fish...")
	$(call run,brew upgrade fish fisher)
	$(call log,"Updating fisher plugins...")
	$(call run,fisher update)
	$(call done)

.PHONY: set-fish-as-default
set-fish-as-default: fish
	$(call log,"Setting fish as default shell...")
	$(call run,echo $$HOMEBREW_PREFIX/bin/fish | sudo tee -a /etc/shells)
	$(call run,chsh -s $$HOMEBREW_PREFIX/bin/fish)
	$(call done)

### bat

BAT := $(shell command -v bat 2> /dev/null)

.PHONY: bat
bat: brew
ifndef BAT
	$(call err,"bat not found!")
	$(call log,"Installing bat...")
	$(call run,brew install bat)
	$(call done)
endif

.PHONY: update-bat
update-bat: bat ~/.config/bat/themes/laserwave.tmTheme
	$(call log,"Updating bat...")
	$(call run,bat cache --build)
	$(call done)

### neovim

NVIM := $(shell command -v nvim 2> /dev/null)

~/.local/share/neovim:
	$(call err,"neovim source not found!")
	$(call log,"Cloning neovim...")
	$(call run,git clone git@github.com:neovim/neovim.git $@)
	$(call done)

# nvim currently requires cmake@3.3.0
# brew doesn't support versioned installs, so a workaround
# is to download the formula for the older version
# and install it locally.
# When the required version changes, we need to:
#   1. update the version number in the target
#   2. update the version number in the cmake phony target
#   3. find the hash corresponding to when the forumla for that version was published
#   4. update the curl URL below with that hash
~/.cache/cmake3.3.0.rb:
	$(call run,curl https://raw.githubusercontent.com/Homebrew/homebrew-core/b46f3ad7db7ff9446d44a4c8eef7ad4f59e83018/Formula/c/cmake.rb -o $@)

.PHONY: cmake
cmake: ~/.cache/cmake3.3.0.rb brew
	$(call log,"Updating cmake...")
	$(call run,ln -sf $< ~/.cache/cmake.rb)
	$(call run,brew install -s ~/.cache/cmake.rb)
	$(call done)

.PHONY: nvim
nvim: ~/.local/share/neovim cmake
ifndef NVIM
	$(call log,"Installing neovim...")
	$(call run,cd $< && make CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_INSTALL_PREFIX="$$HOME/.local" install)
	$(call done)
endif

.PHONY: update-nvim
update-nvim: ~/.local/share/neovim cmake
	$(call log,"Updating neovim...")
	$(call run,cd $< && git fetch --tags --force && git reset --hard tags/nightly)
	$(call run,cd $< && make clean && make distclean && make CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_INSTALL_PREFIX="$$HOME/.local" install)
	$(call log,"Updating Plugins...")
	$(call run,nvim --headless "+Lazy! sync" "+silent w! /dev/stdout" +qa)
	$(call log,"Updating Parsers...")
	$(call run,nvim --headless "+TSUpdateSync" "+silent w! /dev/stdout" +qa)
	$(call log,"Updating Packages...")
	$(call run,nvim --headless "+MasonInstallAll" "+silent w! /dev/stdout" +qa)
	$(call done)


.PHONY update-nvim-plugins:
update-nvim-plugins: nvim
	$(call log,"Updating Plugins...")
	$(call run,nvim --headless "+Lazy! install" "+silent w! /dev/stdout" +qa)
	$(call log,"Updating Parsers...")
	$(call run,nvim --headless "+TSUpdateSync" "+silent w! /dev/stdout" +qa)
	$(call log,"Updating Packages...")
	$(call run,nvim --headless "+MasonInstallAll" "+silent w! /dev/stdout" +qa)
	$(call done)

### luarocks

LUAROCKS := $(shell command -v luarocks 2> /dev/null)

.PHONY: luarocks
luarocks: brew
ifndef LUAROCKS
	$(call log,"Installing luarocks...")
	$(call run,brew install luarocks)
	$(call log,"Configuring luarocks to use lua_version 5.1...")
	$(call run,luarocks config lua_version 5.1)
	$(call done)
else
	$(call log,"Configuring luarocks to use lua_version 5.1...")
	$(call run,luarocks config lua_version 5.1)
	$(call done)
endif

### luajit

LUAJIT := $(shell command -v luajit 2> /dev/null)

.PHONY: luajit
luajit: brew
ifndef LUAJIT
	$(call log,"Installing luajit...")
	$(call run,brew install luajit)
	$(call log,"Configuring luarocks to include luajit...")
	$(call run,luarocks config variables.LUA_INCDIR /usr/local/include/luajit-2.1)
	$(call done)
else
	$(call log,"Configuring luarocks to include luajit...")
	$(call run,luarocks config variables.LUA_INCDIR /usr/local/include/luajit-2.1)
	$(call done)
endif

### nlua

NLUA := $(shell command -v nlua 2> /dev/null)

.PHONY: nlua
nlua: nvim luarocks luajit
ifndef NLUA
	$(call log,"Installing nlua...")
	$(call run,luarocks --local install nlua)
	$(call log,"Configuring luarocks to use nlua...")
	$(call run,luarocks config variables.LUA "$$HOME/.luarocks/bin/nlua")
	$(call done)
else
	$(call log,"Configuring luarocks to use nlua...")
	$(call run,luarocks config variables.LUA "$$HOME/.luarocks/bin/nlua")
	$(call done)
endif

### busted

BUSTED := $(shell command -v busted 2> /dev/null)
.PHONY: busted
busted: nlua
ifndef BUSTED
	$(call log,"Installing busted...")
	$(call run,luarocks --local install busted)
	$(call done)
endif

### kitty

KITTY := $(shell command -v kitty 2> /dev/null)

.PHONY: kitty
kitty: ~/.config/kitty/laserwave.conf
ifndef KITTY
	$(call err,"kitty not found!")
	$(call log,"Installing kitty...")
else
	$(call log,"Updating kitty...")
endif
	$(call run,curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin installer=nightly launch=n)
ifdef MACOS
	$(call run,ln -sf /Applications/kitty.app/Contents/MacOS/kitty "$$HOME/.local/bin/kitty")
	$(call run,rm /var/folders/*/*/*/com.apple.dock.iconcache; killall Dock) #force refresh of dock icons.
endif
	$(call done)

.PHONY: update-kitty
update-kitty: kitty

.PHONY: update-dock-icons
update-dock-icons:
ifdef MACOS
	$(call run,rm /var/folders/*/*/*/com.apple.dock.iconcache; killall Dock) #force refresh of dock icons.
	$(call done)
else
	$(call err,"Not on macOS!")
endif

### wezterm

WEZTERM := $(shell command -v wezterm 2> /dev/null)

.PHONY: wezterm
wezterm: brew ~/.config/wezterm/colors/laserwave.toml
ifndef WEZTERM
	$(call err,"wezterm not found!")
	$(call log,"Installing wezterm...")
else
	$(call log,"Updating wezterm...")
endif
	$(call run,brew install wezterm)
	$(call done)

.PHONY: update-wezterm
update-wezterm: wezterm

### qmk

~/Library/Application\ Support/qmk/qmk.ini:
ifdef MACOS
	$(call err,"qmk config not found!")
	$(call log,"Linking qmk config...")
	$(call run,mkdir -p ~/Library/Application\ Support/qmk/)
	$(call run,ln -sf "$$HOME/.config/qmk/qmk.ini" "$@")
	$(call done)
endif

~/.local/share/qmk_firmware: ~/Library/Application\ Support/qmk/qmk.ini
	$(call err,"qmk_firmware not found!")
	$(call log,"Cloning qmk_firmware...")
	$(call run,qmk setup lettertwo/qmk_firmware --branch lettertwo)
	$(call done)

.PHONY: qmk
qmk: ~/Library/Application\ Support/qmk/qmk.ini ~/.local/share/qmk_firmware

.PHONY: update-qmk
update-qmk: qmk
	$(call log,"Updating qmk_firmware...")
	$(call run,qmk setup lettertwo/qmk_firmware)
	$(call done)

### rust

RUSTC := $(shell command -v rustc 2> /dev/null)

~/.cargo/bin/rustup:
	$(call err,"rustup not found!")
	$(call log,"Installing rustup...")
	$(call run,curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh)
	$(call done)

~/.cargo/bin/cargo-binstall:
	$(call err,"cargo-binstall not found!")
	$(call log,"Installing cargo-binstall...")
	$(call run,curl -L --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | sh)
	$(call done)

~/.cargo/bin/cargo-nextest:
	$(call err,"cargo-nextest not found!")
	$(call log,"Installing cargo-nextest...")
	$(call run,cargo binstall cargo-nextest --secure --no-confirm)
	$(call done)

~/.cargo/bin/cargo-watch:
	$(call err,"cargo-watch not found!")
	$(call log,"Installing cargo-watch...")
	$(call run,cargo binstall cargo-watch --secure --no-confirm)
	$(call done)

.PHONY: rust
rust: ~/.cargo/bin/rustup ~/.cargo/bin/cargo-binstall ~/.cargo/bin/cargo-nextest ~/.cargo/bin/cargo-watch
ifndef RUSTC
	$(call err,"rustc not found!")
	$(call log,"Installing rust stable...")
	$(call run,rustup toolchain install stable)
	$(call log,"Setting default toolchain to stable...")
	$(call run,rustup default stable)
	$(call log,"Installing rust nightly...")
	$(call run,rustup toolchain install nightly)
	$(call done)
endif

### config

.PHONY: update-config
update-config:
	$(call log,"Updating config...")
	$(call run,git pull)
	$(call done)

.PHONY: mkdirs
mkdirs: ~/.cache/zsh ~/.local/bin ~/.local/share ~/.local/state/zsh/completions

.PHONY: install
install: mkdirs ~/.zshenv ~/.local/share/laserwave.nvim brew set-fish-as-default
	@echo ""
	$(call done)
	@echo ""
	@echo "Restart your shell and run $(BLUE)make update$(END) to fetch the latest stuff."
ifdef MACOS
	@echo ""
	@echo "Other useful things to install:"
	@echo "  1password: $(CYAN)https://1password.com/downloads/mac/$(END)"
	@echo "  raycast:   $(CYAN)https://www.raycast.com/$(END)"
	@echo "  rectangle: $(CYAN)https://rectangleapp.com/pro$(END)"
	@echo "  MonoLisa:  $(CYAN)https://www.monolisa.dev/orders$(END)"
	@echo "  NerdFonts (Symbols Only):  $(CYAN)https://github.com/ryanoasis/nerd-fonts/releases/$(END)"
endif

.PHONY: update
update: update-config \
	update-laserwave \
	update-brew \
	update-fish \
	update-bat \
	update-nvim \
	update-kitty

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

~/.local/share/laserwave.nvim:
	$(call err,"laserwave not found!")
	$(call log,"Installing laserwave...")
	$(call run,git clone https://github.com/lettertwo/laserwave.nvim.git $@)
	$(call done)

.PHONY: update-laserwave
update-laserwave: ~/.local/share/laserwave.nvim
	$(call log,"Updating laserwave...")
	$(call run,cd ~/.local/share/laserwave.nvim && git pull)
	$(call done)

~/.config/kitty/laserwave.conf: ~/.config/kitty
	$(call run,ln -sf "$$HOME/.local/share/laserwave.nvim/dist/kitty/laserwave.conf" "$$HOME/.config/kitty/laserwave.conf")

~/.config/alacritty/laserwave.yml: ~/.config/alacritty
	$(call run,ln -sf "$$HOME/.local/share/laserwave.nvim/dist/alacritty/laserwave.yml" "$$HOME/.config/alacritty/laserwave.yml")

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
ifdef MACOS
	$(call run,brew bundle)
else
	$(call run,brew bundle --file=Brewfile-minimal)
endif
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

### neovim

NVIM := $(shell command -v nvim 2> /dev/null)

~/.local/share/neovim:
	$(call err,"neovim source not found!")
	$(call log,"Cloning neovim...")
	$(call run,git clone git@github.com:neovim/neovim.git $@)
	$(call done)

.PHONY: nvim
nvim: ~/.local/share/neovim
ifndef NVIM
	$(call log,"Installing neovim...")
	$(call run,cd ~/.local/share/neovim && make CMAKE_BUILD_TYPE=RelWithDebInfo && make install)
	$(call done)
endif

.PHONY: update-nvim
update-nvim: ~/.local/share/neovim
	$(call log,"Updating neovim...")
	$(call run,cd ~/.local/share/neovim && git fetch --tags --force && git reset --hard tags/nightly)
	$(call run,cd ~/.local/share/neovim && make clean && make distclean && make CMAKE_BUILD_TYPE=RelWithDebInfo && make install)
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
	$(call run,nvim --headless "+Lazy! sync" "+silent w! /dev/stdout" +qa)
	$(call log,"Updating Parsers...")
	$(call run,nvim --headless "+TSUpdateSync" "+silent w! /dev/stdout" +qa)
	$(call log,"Updating Packages...")
	$(call run,nvim --headless "+MasonInstallAll" "+silent w! /dev/stdout" +qa)
	$(call done)

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
	$(call run,curl -L https://sw.kovidgoyal.net/kitty/installer.sh | zsh /dev/stdin)
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
qmk: ~/.local/share/qmk_firmware

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

.PHONY: rust
rust: ~/.cargo/bin/rustup ~/.cargo/bin/cargo-binstall ~/.cargo/bin/cargo-nextest
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
install: mkdirs ~/.zshenv ~/.local/share/laserwave.nvim brew
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
	update-sheldon \
	update-nvim \
	update-kitty

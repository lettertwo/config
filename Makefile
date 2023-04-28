BLACK := \033[0;30m
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

log = @echo "$(INFO)$(1)$(END)"
err = @>&2 echo "$(ERROR)$(1)$(END)"
done = $(call log,"Done!")
run = @$(1) || (n=$$?; >&2 echo "$(ERROR)Failed!$(END)"; exit $$n)

### ZDOTDIR

define ZDOTDIR
export ZDOTDIR="$$HOME/.config/zsh"
endef

export ZDOTDIR
/etc/zshenv:
ifneq ($(ZDOTDIR), "$$HOME/.config/zsh")
	$(call err,"ZDOTDIR misconfigured!")
	$(call log,"Configuring ZDOTDIR...")
	$(call run,echo "$$ZDOTDIR" | sudo tee -a $@ > /dev/null)
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

### homebrew

BREW := $(shell command -v brew 2> /dev/null)

.PHONY: brew
brew:
ifndef BREW
	$(call err,"brew not found!")
	$(call log,"Installing brew...")
	$(call run,curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)
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

### pip3
PIP3 := $(shell command -v pip3 2> /dev/null)

.PHONY: pip3
pip3: brew
ifndef PIP3
	$(call err,"pip3 not found!")
	$(call log,"Installing python...")
	$(call run,brew install python)
	$(call done)
endif

### neovim

NVIM := $(shell command -v nvim 2> /dev/null)

~/.local/share/neovim:
	$(call err,"neovim source not found!")
	$(call log,"Cloning neovim...")
	$(call run,git clone git@github.com:neovim/neovim.git $@)
	$(call done)

.PHONY: nvim
nvim: ~/.local/share/neovim pip3
ifndef NVIM
	$(call log,"Installing neovim...")
	$(call run,cd ~/.local/share/neovim && make CMAKE_BUILD_TYPE=RelWithDebInfo && make install)
	$(call log,"Installing pynvim...")
	$(call run,pip3 install --user --upgrade pynvim)
	$(call done)
endif

.PHONY: update-nvim
update-nvim: ~/.local/share/neovim
	$(call log,"Updating neovim...")
	$(call run,cd ~/.local/share/neovim && git pull)
	$(call run,cd ~/.local/share/neovim && make clean && make distclean && make CMAKE_BUILD_TYPE=RelWithDebInfo && make install)
	$(call log,"Updating pynvim...")
	$(call run,pip3 install --user --upgrade pynvim)
	$(call log,"Updating Plugins...")
	$(call run,nvim --headless "+Lazy! sync" "+silent w! /dev/stdout" +qa)
	$(call done)

### kitty

KITTY := $(shell command -v kitty 2> /dev/null)

.PHONY: kitty
kitty:
ifndef KITTY
	$(call err,"kitty not found!")
	$(call log,"Installing kitty...")
	$(call run,curl -L https://sw.kovidgoyal.net/kitty/installer.sh | zsh /dev/stdin)
	$(call run,ln -sf /Applications/kitty.app/Contents/MacOS/kitty "$$HOME/.local/bin/kitty")
	$(call run,ln -sf "$$HOME/.local/share/laserwave.nvim/dist/kitty/laserwave.conf" "$$HOME/.config/kitty/laserwave.conf")
	$(call run,rm /var/folders/*/*/*/com.apple.dock.iconcache; killall Dock) # force refresh of dock icons.
	$(call done)
endif

.PHONY: update-kitty
update-kitty:
ifndef KITTY
	$(call err,"kitty not found!")
	$(call log,"Installing kitty...")
else
	$(call log,"Updating kitty...")
endif
	$(call run,curl -L https://sw.kovidgoyal.net/kitty/installer.sh | zsh /dev/stdin)
	$(call run,ln -sf /Applications/kitty.app/Contents/MacOS/kitty "$$HOME/.local/bin/kitty")
	$(call run,ln -sf "$$HOME/.local/share/laserwave.nvim/dist/kitty/laserwave.conf" "$$HOME/.config/kitty/laserwave.conf")
	$(call run,rm /var/folders/*/*/*/com.apple.dock.iconcache; killall Dock) #force refresh of dock icons.
	$(call done)

.PHONY: update-dock-icons
update-dock-icons:
	$(call run,rm /var/folders/*/*/*/com.apple.dock.iconcache; killall Dock) #force refresh of dock icons.
	$(call done)

### qmk

~/Library/Application\ Support/qmk/qmk.ini:
	$(call err,"qmk config not found!")
	$(call log,"Linking qmk config...")
	$(call run,mkdir -p ~/Library/Application\ Support/qmk/)
	$(call run,ln -sf "$$HOME/.config/qmk/qmk.ini" "$@")
	$(call done)

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

### config

.PHONY: update-config
update-config:
	$(call log,"Updating config...")
	$(call run,git pull)
	$(call done)

.PHONY: mkdirs
mkdirs: ~/.cache/zsh ~/.local/bin ~/.local/share ~/.local/state/zsh/completions

.PHONY: install
install: mkdirs /etc/zshenv ~/.local/share/laserwave.nvim brew sheldon nvim kitty qmk
	@echo ""
	$(call done)
	@echo ""
	@echo "Be sure to run $(BLUE)make update$(END) to fetch the latest stuff."
	@echo ""
	@echo "Other useful things to install:"
	@echo "  1password: $(CYAN)https://1password.com/downloads/mac/$(END)"
	@echo "  raycast:   $(CYAN)https://www.raycast.com/$(END)"
	@echo "  rectangle: $(CYAN)https://rectangleapp.com/pro$(END)"
	@echo "  clover:    $(CYAN)https://cloverapp.com/download$(END)"
	@echo "  MonoLisa:  $(CYAN)https://www.monolisa.dev/orders$(END)"
	@echo ""
	@echo "    Add nerdfonts to MonoLisa after download (example):"
	@echo "    $(BLUE)mkdir ~/Downloads/MonoLisa/nerdfonts"
	@echo "    $(BLUE)docker run --rm \\"
	@echo "      -v ~/Downloads/MonoLisa/ttf:/in \\"
	@echo "      -v ~/Downloads/MonoLisa/nerdfonts:/out \\"
	@echo "      nerdfonts/patcher -c$(END)"
	@echo ""
	@echo "    It'll take a while. Afterward, just drag them into Font Book!"

.PHONY: update
update: update-config \
	update-laserwave \
	update-brew \
	update-sheldon \
	update-nvim \
	update-kitty \
	update-qmk

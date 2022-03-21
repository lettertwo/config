define XDG_CONFIG
# XDG_CONFIG start
export XDG_CONFIG_HOME="$$HOME/.config"
export XDG_CACHE_HOME="$$HOME/.cache"
export XDG_DATA_HOME="$$HOME/.local/share"
export XDG_STATE_HOME="$$HOME/.local/share"
export ZDOTDIR="$$XDG_CONFIG_HOME/zsh"
# XDG_CONFIG end
endef

export XDG_CONFIG
/etc/zshenv:
ifneq ($(XDG_CONFIG_HOME), "$$HOME/.config")
	@echo Configuring XDG Base Directories...
	@echo "$$XDG_CONFIG" | sudo tee -a $@ > /dev/null
	@if [ "$$?" -ne "0" ]; then echo "Failed!"; exit 1; else echo "Done!"; fi
endif

install: /etc/zshenv update

update:
	brew bundle
	brew cleanup
	sheldon lock

.PHONY:
	install
	update

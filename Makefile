define ZDOTDIR
export ZDOTDIR="$$HOME/.config/zsh"
endef

export ZDOTDIR
/etc/zshenv:
ifneq ($(ZDOTDIR), "$$HOME/.config/zsh")
	@echo Configuring ZDOTDIR...
	@echo "$$ZDOTDIR" | sudo tee -a $@ > /dev/null
	@if [ "$$?" -ne "0" ]; then echo "Failed!"; exit 1; else echo "Done!"; fi
endif

~/.local/state/zsh:
	mkdir -p ~/.local/state/zsh

~/.cache/zsh:
	mkdir -p ~/.cache/zsh

~/.local/share/zsh/completions:
	mkdir -p ~/.local/state/zsh/completions

install: /etc/zshenv ~/.local/state/zsh ~/.cache/zsh update

update:
	brew bundle
	brew cleanup
	sheldon lock

.PHONY:
	install
	update

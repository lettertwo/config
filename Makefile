LINK=ln -shf
SRC=$(CURDIR)/src
CONFIG=$(HOME)/.config

.config/%:
	$(LINK) $(SRC)/$(patsubst .%,%,$@) $(HOME)/$@

.%:
	$(LINK) $(SRC)/$(patsubst .%,%,$@) $(HOME)/$@

link.dotfiles: .gitconfig .gitignore .zshenv .zprofile .zshrc

link.config: .config/kitty/kitty.conf .config/kitty/dracula

install: link.dotfiles link.config

.PHONY:
	link.dotfiles
	link.config
	install

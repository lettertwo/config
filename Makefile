LINK=ln -shf
SRC=$(CURDIR)/src
SHELDON=$(HOME)/.sheldon

.%:
	$(LINK) $(SRC)/$(patsubst .%,%,$@) $(HOME)/$@

.sheldon/%:
	$(LINK) $(SRC)/$(patsubst .%,%,$@) $(HOME)/$@

link.dotfiles: .gitconfig .gitignore .zshenv .zprofile .zshrc .Brewfile

link.config: .config/brew/Brewfile

link.sheldon: .sheldon/plugins.toml .sheldon/local

install: link.dotfiles link.sheldon

upgrade:
	cd ~; brew bundle --global && brew upgrade && brew cleanup; cd -

.PHONY:
	link.dotfiles
	link.sheldon
	install
	upgrade

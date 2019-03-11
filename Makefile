LINK=ln -shf
SRC=$(CURDIR)/src

.%:
	$(LINK) $(SRC)/$(patsubst .%,%,$@) $(HOME)/$@

link.dotfiles: .gitconfig .gitignore .zshenv .zshrc .zplugrc .znocorrect

install: link.dotfiles

.PHONY:
	link.dotfiles
	install

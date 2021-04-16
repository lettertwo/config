LINK=ln -shf
SRC=$(CURDIR)/src

.%:
	$(LINK) $(SRC)/$(patsubst .%,%,$@) $(HOME)/$@

link.dotfiles: .gitconfig .gitignore .zshenv .zshrc .zinitrc .znocorrect

install: link.dotfiles

.PHONY:
	link.dotfiles
	install

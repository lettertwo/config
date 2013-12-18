LINK=ln -sf
SRC=$(CURDIR)/src
VENDOR=$(CURDIR)/vendor


.%:
	$(LINK) $(SRC)/$(subst .,,$@) $(HOME)/$@

link.dotfiles: .gitattributes .gitconfig .gitignore .zshrc .zprofile .zshenv .zsh_nocorrect

link.antigen:
	$(LINK) $(VENDOR)/antigen $(HOME)/.antigen

install: link.dotfiles link.antigen

.PHONY:
	link.dotfiles
	link.antigen
	install

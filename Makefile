LINK=ln -sf
SRC=$(CURDIR)/src
VENDOR=$(CURDIR)/vendor
BIN=$(CURDIR)/bin


.%:
	$(LINK) $(SRC)/$(subst .,,$@) $(HOME)/$@

link.dotfiles: .gitattributes .gitconfig .gitignore .zshrc .zsh_nocorrect

link.antigen:
	$(LINK) $(VENDOR)/antigen $(HOME)/.antigen


link.dotfiles:
	$(LINK) $(BIN)/dotfiles /usr/local/bin/dotfiles

install: link.dotfiles link.antigen

.PHONY:
	link.dotfiles
	link.antigen
	install

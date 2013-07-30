LINK=ln -sf
SRC=$(CURDIR)/src
VENDOR=$(CURDIR)/vendor
BIN=$(CURDIR)/bin


.%:
	$(LINK) $(SRC)/$(subst .,,$@) $(HOME)/$@

custom.aliases:
	$(LINK) $(SRC)/$@.bash $(VENDOR)/bash_it/aliases/$@.bash

custom:
	$(LINK) $(SRC)/$@.bash $(VENDOR)/bash_it/custom/$@.bash

theme.lettertwo:
	$(LINK) $(SRC)/lettertwo.theme.bash $(VENDOR)/bash_it/themes/lettertwo/lettertwo.theme.bash

link.dotfiles: .bash_profile .gitattributes .gitconfig .gitignore .inputrc .tm_properties .zshrc .zsh_nocorrect

link.bash_it: custom custom.aliases theme.lettertwo
	$(LINK) $(VENDOR)/bash_it $(HOME)/.bash_it

link.antigen:
	$(LINK) $(VENDOR)/antigen $(HOME)/.antigen

install: link.dotfiles link.bash_it link.antigen

link.dotfiles:
	$(LINK) $(BIN)/dotfiles /usr/local/bin/dotfiles

bootstrap:
	./bin/bootstrap

.PHONY:
	link.dotfiles
	link.bash_it
	link.antigen
	bootstrap
	install

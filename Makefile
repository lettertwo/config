LINK=ln -sf
SRC=$(CURDIR)/src
VENDOR=$(CURDIR)/vendor


.%:
	$(LINK) $(SRC)/$(subst .,,$@) $(HOME)/$@

custom.aliases:
	$(LINK) $(SRC)/$@.bash $(VENDOR)/bash_it/aliases/$@.bash

custom:
	$(LINK) $(SRC)/$@.bash $(VENDOR)/bash_it/custom/$@.bash

theme.lettertwo:
	$(LINK) $(SRC)/lettertwo $(VENDOR)/bash_it/themes/lettertwo

link.dotfiles: .bash_profile .gitattributes .gitconfig .gitignore .inputrc .tm_properties

link.bash_it: custom custom.aliases theme.lettertwo
	$(LINK) $(VENDOR)/bash_it $(HOME)/.bash_it

install: link.dotfiles link.bash_it

.PHONY:
	link.dotfiles
	link.bash_it
	install

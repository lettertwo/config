LINK=ln -sf
SRC=$(CURDIR)/src

.%:
	$(LINK) $(SRC)/$(subst .,,$@) $(HOME)/$@

custom.aliases:
	$(LINK) $(SRC)/$@.bash $(CURDIR)/bash_it/aliases/$@.bash

custom:
	$(LINK) $(SRC)/$@.bash $(CURDIR)/bash_it/custom/$@.bash

theme.lettertwo:
	$(LINK) $(SRC)/lettertwo $(CURDIR)/bash_it/themes/lettertwo

link.dotfiles: .bash_profile .gitattributes .gitconfig .gitignore .inputrc .tm_properties

link.bash_it: .bash_it custom custom.aliases theme.lettertwo

install: link.dotfiles link.bash_it

.PHONY:
	link.dotfiles
	link.bash_it
	install

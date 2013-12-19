LINK=ln -sf
SRC=$(CURDIR)/src
VENDOR=$(CURDIR)/vendor

.%:
	$(LINK) $(SRC)/$(subst .,,$@) $(HOME)/$@

p.%:
	$(LINK) $(VENDOR)/prezto/runcoms/$(subst p.,,$@) $(HOME)/$(subst p,,$@)

link.dotfiles: .gitattributes .gitconfig .gitignore .zpreztorc .zsh_nocorrect

link.prezto.dotfiles: p.zlogin p.zlogout p.zprofile p.zshenv p.zshrc

link.prezto:
	$(LINK) $(VENDOR)/prezto $(HOME)/.zprezto

install: link.prezto link.prezto.dotfiles link.dotfiles

.PHONY:
	link.dotfiles
	link.prezto
	link.prezto.dotfiles
	install

LINK=ln -sf
SRC=$(CURDIR)/src
VENDOR=$(CURDIR)/vendor
MODULES=$(VENDOR)/prezto/modules
RUNCOMS=$(VENDOR)/prezto/runcoms
PROMPTS=$(MODULES)/prompt/functions

.%:
	$(LINK) $(SRC)/$(subst .,,$@) $(HOME)/$@

p.%:
	$(LINK) $(RUNCOMS)/$(subst p.,,$@) $(HOME)/$(subst p.,.,$@)

link.modules:
	$(LINK) $(SRC)/modules/autoenv $(MODULES)/autoenv

link.prompts:
	$(LINK) $(SRC)/prompt_lettertwo_setup $(PROMPTS)/prompt_lettertwo_setup

link.prezto:
	$(LINK) $(VENDOR)/prezto $(HOME)/.zprezto

link.prezto.dotfiles: p.zlogin p.zlogout p.zprofile p.zshenv p.zshrc

link.dotfiles: .gitconfig .gitignore .zpreztorc .znocorrect

install: link.modules link.prompts link.prezto link.prezto.dotfiles link.dotfiles

.PHONY:
	link.modules
	link.prompts
	link.prezto
	link.prezto.dotfiles
	link.dotfiles
	install

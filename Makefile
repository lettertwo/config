LINK=ln -shf
SRC=$(CURDIR)/src
VENDOR=$(CURDIR)/vendor
MODULES=$(VENDOR)/prezto/modules
RUNCOMS=$(VENDOR)/prezto/runcoms
PROMPTS=$(MODULES)/prompt/functions

.%:
	$(LINK) $(SRC)/$(patsubst .%,%,$@) $(HOME)/$@

p.%:
	$(LINK) $(RUNCOMS)/$(patsubst p.%,%,$@) $(HOME)/$(patsubst p.%,.%,$@)

link.modules:
	$(LINK) $(SRC)/modules/gulp $(MODULES)/gulp
	$(LINK) $(SRC)/modules/simpledocker $(MODULES)/simpledocker
	$(LINK) $(SRC)/modules/simplegit $(MODULES)/simplegit
	$(LINK) $(SRC)/modules/fzf $(MODULES)/fzf
	$(LINK) $(SRC)/modules/fastlane $(MODULES)/fastlane
	$(LINK) $(VENDOR)/zsh-autoenv $(MODULES)/zsh-autoenv

link.prompts:
	$(LINK) $(SRC)/prompt_lettertwo_setup $(PROMPTS)/prompt_lettertwo_setup

link.prezto:
	$(LINK) $(VENDOR)/prezto $(HOME)/.zprezto

link.prezto.dotfiles: p.zlogin p.zlogout p.zshenv p.zshrc

link.dotfiles: .gitconfig .gitignore .zprofile .zpreztorc .znocorrect .tmux.conf

install: link.modules link.prompts link.prezto link.prezto.dotfiles link.dotfiles

.PHONY:
	link.modules
	link.prompts
	link.prezto
	link.prezto.dotfiles
	link.dotfiles
	install

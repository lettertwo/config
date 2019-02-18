LINK=ln -shf
SRC=$(CURDIR)/src
CONTRIB=$(CURDIR)/contrib
VENDOR=$(CURDIR)/vendor
VENDOR_CONTRIB=$(VENDOR)/prezto/contrib
RUNCOMS=$(VENDOR)/prezto/runcoms

.%:
	$(LINK) $(SRC)/$(patsubst .%,%,$@) $(HOME)/$@

p.%:
	$(LINK) $(RUNCOMS)/$(patsubst p.%,%,$@) $(HOME)/$(patsubst p.%,.%,$@)

link.contrib:
	mkdir -p $(VENDOR_CONTRIB)
	$(LINK) $(VENDOR)/prezto-contrib/*/ $(VENDOR_CONTRIB)/
	$(LINK) $(SRC)/prezto-contrib/*/ $(VENDOR_CONTRIB)/
	$(LINK) $(VENDOR)/zsh-autoenv $(VENDOR_CONTRIB)/zsh-autoenv

link.prezto:
	$(LINK) $(VENDOR)/prezto $(HOME)/.zprezto

link.prezto.dotfiles: p.zlogin p.zlogout p.zshenv p.zshrc

link.dotfiles: .gitconfig .gitignore .zprofile .zpreztorc .znocorrect .tmux.conf

install: link.contrib link.prezto link.prezto.dotfiles link.dotfiles

.PHONY:
	link.contrib
	link.prezto
	link.prezto.dotfiles
	link.dotfiles
	install

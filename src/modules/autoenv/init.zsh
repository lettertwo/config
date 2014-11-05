#
# Autoenv
#
# source "$(brew --prefix autoenv)"/activate.sh
source ~/.autoenv/activate.sh

# Make sure autoenv_init runs whenever we cd
chpwd_functions=(autoenv_init $chpwd_functions)

# run it once, just in case we started the session with a .env
autoenv_init

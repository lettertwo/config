#
# Autoenv
#
# source "$(brew --prefix autoenv)"/activate.sh
source ~/.autoenv/activate.sh

# Our own little autoenv tester, cuz the default one is recursive and that kinda sucks.
shallow_autoenv()
{
  typeset target home _file
  target=$1
  home="$(dirname $HOME)"
  _file="$PWD/$AUTOENV_ENV_FILENAME"
  if [[ "$PWD" != "/" && "$PWD" != "$home" && -e "$_file" ]]
  then autoenv_check_authz_and_run "$_file"
  fi
}

# Make sure shallow_autoenv runs whenever we cd
chpwd_functions=($chpwd_functions shallow_autoenv)

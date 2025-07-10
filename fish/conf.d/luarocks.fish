type -q luarocks || return 1
luarocks path --lua-version 5.1 --no-bin | source
fish_add_path $HOME/.luarocks/bin

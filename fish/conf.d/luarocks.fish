type -q luarocks || return 1
# FIXME: Figure out how to speed this up. It makes fish startup 2x slower.
# Using hyperfine fish -i -c exit
# Enabled:
#   Time (mean ± σ):     397.5 ms ±   6.7 ms    [User: 241.5 ms, System: 144.5 ms]
#   Range (min … max):   391.9 ms … 414.2 ms    10 runs
# Disabled:
#   Time (mean ± σ):     199.3 ms ±   4.6 ms    [User: 134.2 ms, System: 70.6 ms]
#   Range (min … max):   193.1 ms … 208.1 ms    14 runs
#
# luarocks path --lua-version 5.1 --no-bin | source
fish_add_path $HOME/.luarocks/bin

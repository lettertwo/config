function fzf
    kitty @ set-user-vars IS_FZF=1
    command fzf $argv
    kitty @ set-user-vars IS_FZF
end

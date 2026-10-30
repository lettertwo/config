function hunk
    kitty @ set-user-vars IS_HUNK=1
    command hunk $argv
    kitty @ set-user-vars IS_HUNK
end

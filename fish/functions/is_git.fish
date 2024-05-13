function is_git
    if test (command git rev-parse --is-inside-work-tree 2>/dev/null)
        return 0
    end
    return 1
end

function is_ssh
    if test -n "$SSH_CLIENT" -o -n "$SSH_TTY"
        return 0
    end
    return 1
end

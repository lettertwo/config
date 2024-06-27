function prompt_pwd

    if is_git
        set wdir (command git rev-parse --show-toplevel 2>/dev/null)
        set gdir (command git rev-parse --git-common-dir 2>/dev/null)
        # use the common ancestor between the two paths
        set pwd (gcd $wdir $gdir)
    else
        set pwd (pwd)
    end

    echo (string replace -r "^$HOME(/Code|/.local/share|)/" "" $pwd)
end

function prompt_pwd
    is_git; and set pwd (command git rev-parse --show-toplevel 2>/dev/null); or set pwd (pwd)
    echo (string replace -r "^$HOME(/Code|/.local/share|)/" "" $pwd)
end

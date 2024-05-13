function nvim
    set status_to_restart 230
    command nvim $argv
    if test $status -eq $status_to_restart
        while true
            command nvim $argv +RestoreLastSession
            if test $status -ne $status_to_restart
                break
            end
        end
    end
end

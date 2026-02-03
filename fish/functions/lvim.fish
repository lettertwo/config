function lvim
    set status_to_restart 230
    NVIM_APPNAME=lvim command nvim $argv
    if test $status -eq $status_to_restart
        while true
            NVIM_APPNAME=lvim command nvim $argv +RestoreSession
            if test $status -ne $status_to_restart
                break
            end
        end
    end
end

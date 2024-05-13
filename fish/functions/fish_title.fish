function fish_title
    set title $argv[1] (prompt_pwd)

    if is_ssh
        set user (whoami)
        set host (hostname | string replace -r "^ip-" "")
        set title "$user@$host $title"
    end

    echo $title
end

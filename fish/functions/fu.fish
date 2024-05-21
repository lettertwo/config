# rage quit!!!
function fu
    if killall -9 $argv[1]
        echo
        echo " (╯°□°）╯︵"(echo $argv[1]|toilet -f term -F rotate)
        echo
    end
end

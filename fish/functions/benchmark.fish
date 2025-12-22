function benchmark \
    --description 'benchmark a shell' \
    --argument-names shellname

    test -n "$shellname" || set shellname fish

    if type -q hyperfine
        hyperfine --warmup 3 "$shellname -i -c exit"
    else
        echo "running $shellname 10 times..."
        for i in (seq 10)
            /usr/bin/time $shellname -i -c exit
        end
    end
end

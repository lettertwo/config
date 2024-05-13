# from: https://github.com/mattmc3/fishconf/blob/9b8d44b/functions/benchmark.fish
function benchmark \
    --description 'benchmark a shell' \
    --argument-names shellname

    test -n "$shellname" || set shellname fish
    echo "running $shellname 10 times..."
    for i in (seq 10)
        /usr/bin/time $shellname -i -c exit
    end
end

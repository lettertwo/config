function gcd -d "Find the common ancestor of two paths"

    if test (count $argv) -ne 2
        echo "Usage: gcd path1 path2"
        return 1
    end

    set sep "/"

    set segments1 (realpath $argv[1] | string split $sep | string match -rv '^$')
    set segments2 (realpath $argv[2] | string split $sep | string match -rv '^$')

    set path1 ""
    set path2 ""

    # We don't want an inifinte loop, so we'll limit the number of iterations
    set iteration 1
    set max_iterations 100

    # Rebuild the two paths from segments until they differ
    while true
        set iteration (math $iteration + 1)
        if test $iteration -gt $max_iterations
            echo "Error: Too many iterations in gcd" >&2
            return 1
        end

        set count1 (count $segments1)
        set count2 (count $segments2)

        # No more segments to process, so we're done
        if test $count1 -eq 0 -a $count2 -eq 0
            break
        end

        if test $count1 -gt 0
            set path1 $path1$sep$segments1[1]
            set segments1 $segments1[2..-1]
        end

        if test $count2 -gt 0
            set path2 $path2$sep$segments2[1]
            set segments2 $segments2[2..-1]
        end

        # If the paths differ, we're done
        if test $path1 != $path2
            break
        end

        set common $path1
    end

    echo $common
end

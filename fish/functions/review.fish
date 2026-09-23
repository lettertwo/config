function review
    # The first arg, unless it is "--", is the review source (stack keyword,
    # a branch, a commit-ish, a range...); everything after an explicit "--"
    # passes through to nvim. Env var rather than --cmd for quoting sanity.
    set -l source
    if set -q argv[1]; and test $argv[1] != --
        set source $argv[1]
        set -e argv[1]
    end
    if set -q argv[1]; and test $argv[1] = --
        set -e argv[1]
    end

    if set -q source
        VIM_APP=review REVIEW_SOURCE=$source nvim $argv
    else
        VIM_APP=review nvim $argv
    end
end

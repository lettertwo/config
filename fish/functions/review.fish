function review
    # First arg names the review kind (uncommitted|stack|...); anything else
    # passes through to nvim. Env var rather than --cmd for quoting sanity.
    if set -q argv[1]; and contains -- $argv[1] uncommitted stack pr ref
        VIM_APP=review REVIEW_KIND=$argv[1] nvim $argv[2..]
    else
        VIM_APP=review nvim $argv
    end
end

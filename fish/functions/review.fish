function review
    # First arg names the review kind (uncommitted|stack|...); anything else
    # passes through to nvim. Env var rather than --cmd for quoting sanity.
    if set -q argv[1]; and contains -- $argv[1] uncommitted stack pr ref
        if test $argv[1] = ref; and set -q argv[2]
            # The ref itself is a git ref, not an nvim file arg.
            VIM_APP=review REVIEW_KIND=ref REVIEW_REF=$argv[2] nvim $argv[3..]
        else
            VIM_APP=review REVIEW_KIND=$argv[1] nvim $argv[2..]
        end
    else
        VIM_APP=review nvim $argv
    end
end

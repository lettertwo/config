function claude-turns -d "List or diff turn snapshots written by claude/turn-snapshot.sh"
    set -l common (command git rev-parse --git-common-dir 2>/dev/null)
    if test -z "$common"
        echo "claude-turns: not inside a git repo" >&2
        return 1
    end
    if not string match -q '/*' -- $common
        set common (realpath $common)
    end
    set -l ledger_dir "$common/claude-turns"

    set -l newest (command ls -t $ledger_dir/*.jsonl 2>/dev/null | head -n1)
    if test -z "$newest"
        echo "claude-turns: no turn ledger under $ledger_dir" >&2
        return 1
    end
    set -l sid (string replace -r '\.jsonl$' '' (path basename $newest))

    if test (count $argv) -eq 0
        jq -r '"\(.seq)  \(.kind)  \(.ts)  " + (.prompt // .reply // "")' $newest
        return 0
    end

    if test $argv[1] != diff
        echo "usage: claude-turns [diff <seq> [<seq2>] [-t]]" >&2
        return 1
    end

    set -l use_difftool 0
    set -l seqs
    for a in $argv[2..-1]
        if test "$a" = -t
            set use_difftool 1
        else
            set -a seqs $a
        end
    end

    set -l a b
    if test (count $seqs) -eq 1
        set b (printf '%04d' $seqs[1])
        set a (printf '%04d' (math $seqs[1] - 1))
    else if test (count $seqs) -eq 2
        set a (printf '%04d' $seqs[1])
        set b (printf '%04d' $seqs[2])
    else
        echo "usage: claude-turns diff <seq> [<seq2>] [-t]" >&2
        return 1
    end

    set -l ref_a "refs/claude/turns/$sid/$a"
    set -l ref_b "refs/claude/turns/$sid/$b"
    if test $use_difftool -eq 1
        command git difftool -t kitty $ref_a $ref_b
    else
        command git diff $ref_a $ref_b
    end
end

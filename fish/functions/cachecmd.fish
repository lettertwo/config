# based on: https://github.com/mattmc3/fishconf/blob/410718f/functions/cachecmd.fish
function cachecmd --description "Cache a command"
    set force false
    set dry_run false
    set cache_dir $__fish_cache_dir

    argparse h/help n/dry-run f/force t/ttl= d/directory= -- $argv; or set code $status

    if test $status -ne 0
        printf "\nUse `cachecmd --help` for more information." >&2
        return 1
    end

    if set -q _flag_help
        printf "\
cachecmd <options> -- [cmd]

Evaluates `[cmd]` and caches its result,
or returns a previously cached result if it is still valid.

Options:

    -h, --help
        Display this help message

    -n, --dry-run
        Print the command to stdout instead of evaluating it.
        Also prints the cache operations that would be performed.

    -f, --force
        Force the evaluation of the `[cmd]`. The `-t/--ttl` argument will have no effect.

    -t, --ttl <unit><operator>[n]
        Define a time to live for the cached result. Defaults to `h+24`.

        The format for `-t/--ttl` matches the zsh date globbing syntax.

        The `<unit>` can be:
        `M` - months (30 days)
        `w` - weeks
        `d` - days (the default unit if not specified)
        `h` - hours
        `m` - minutes
        `s` - seconds

        The `<operator>` can be:
        `+` - Generated more than `<n> <unit>` ago
        `-` - Generated less than `<n> <unit>` ago

        Unlike in zsh, the `+` operator is assumed if not specified.

        Some examples:

            `--ttl 2`    - cached more than 2 days ago
            `--ttl h+12` - cached more than 12 hours ago
            `--ttl w-1`  - cached less than 1 week ago
            `--ttl M1`   - cached more than 30 days ago

    -d, --directory <dir>
        Directory where the result will be cached.
        Defaults to `$__fish_cache_dir`.
"
        return
    end

    if not set -q argv[1]
        printf "\
usage: cachecmd <options> -- [cmd]

A command must be provided. Use `cachecmd --help` for more information." >&2
        return 1
    end

    set -q _flag_force; and set force true
    set -q _flag_dry_run; and set dry_run true
    set -q _flag_directory; and set cache_dir $_flag_directory

    if $dry_run
        echo "[dry] opts: force $force, dry_run $dry_run, cache_dir $cache_dir"
    end

    if not test -d $cache_dir
        echo "Cache directory $cache_dir does not exist"
        return 1
    end

    set ttl (math "24 * 60 * 60") # default ttl is 24 hours (1 day)
    set operator '-gt' # default operator is '-gt' (more than)

    if set -q _flag_ttl
        set _flag_ttl_unit 'd' # default ttl unit is 'd' (day)
        set _flag_ttl_operator '+' # default ttl operator is '+' (more than)

        set _flag_ttl_match (string match -r '([Mwdhms]?)([+-]?)([0-9]+)' -- $_flag_ttl)

        if not set -q _flag_ttl_match
            echo "Invalid ttl: $_flag_ttl"
            return 1
        end

        test -n $_flag_ttl_match[2]; and set _flag_ttl_unit $_flag_ttl_match[2]
        test -n $_flag_ttl_match[3]; and set _flag_ttl_operator $_flag_ttl_match[3]
        set _flag_ttl_time $_flag_ttl_match[4]

        if $dry_run
            echo "[dry] ttl: unit $_flag_ttl_unit, operator $_flag_ttl_operator, time $_flag_ttl_time"
        end 

        switch $_flag_ttl_operator
            case +
                set operator '-gt'
            case -
                set operator '-lt'
            case '*'
                echo "Invalid operator in ttl: $_flag_ttl_operator"
                return 1
        end
                
        switch $_flag_ttl_unit
            case M
                set ttl (math "$_flag_ttl_time * 30 * 24 * 60 * 60")
            case w
                set ttl (math "$_flag_ttl_time * 7 * 24 * 60 * 60")
            case d
                set ttl (math "$_flag_ttl_time * 24 * 60 * 60")
            case h
                set ttl (math "$_flag_ttl_time * 60 * 60")
            case m
                set ttl (math "$_flag_ttl_time * 60")
            case s
                # No conversion needed for seconds
            case '*'
                echo "Invalid unit in ttl: $_flag_ttl_unit"
                return 1
        end
    end

    set cmdname (
        string join '-' -- $argv |
        string replace -a '/' '_' |
        string replace -r '^_' ''
    )

    set cachefile $cache_dir/$cmdname.fish

    set should_refresh $force

    if not $should_refresh; and not test -f $cachefile
        set should_refresh true
        if $dry_run
            echo "[dry] cache file $cachefile does not exist"
        end
    else if not $should_refresh
        if $dry_run
            echo "[dry] checking cache file $cachefile"
        end
        set age (math "$(date +%s) - $(date -r $cachefile +%s)")
        if $dry_run
            echo "[dry] test age: $age $operator ttl: $ttl"
        end
        if test $age $operator $ttl
            set should_refresh true
        end
    end

    if $should_refresh
        if $dry_run
            echo "[dry] Refreshing cache at: $cachefile"
        else
            $argv >$cachefile
        end
    else if $dry_run
        echo "[dry] Using cached result at: $cachefile"
    end
    
    if $dry_run
        echo "[dry] cmd: $argv"
    else
        cat $cachefile
    end
end

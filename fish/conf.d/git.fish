abbr -a -g g git

set -l seen (set -l)
set -l targets (set -l)

function add_abbr
    set -l name $argv[1]
    set -l target $argv[2]

    if test -z $name
        return 1
    end

    if test -z $target
        set target $name
    end

    if contains $name $seen
        set -l index (contains -i $name $seen)
        if test $targets[$index] != $target
            echo "Abbreviation \"g$name\"=\"git $target\" conflicts with \"g$name\"=\"git $targets[$index]\"!" >&2
        end
        return 1
    else
        # echo "abbr -a -g g$name \"git $target\""
        abbr -a -g g$name "git $target"
        set seen $seen $name
        set targets $targets $target
        return 0
    end
end

for config_alias in (git config --get-regexp alias | string match "alias.*" | string replace -r "alias.([^\s]+).*" '$1')
    add_abbr $config_alias
end

for common in add bisect branch checkout cherry cherry-pick clone commit diff fetch grep init log merge mv pull push rebase reflog reset rm show status stash switch tag worktree
    add_abbr $common
end

for path_dir in $PATH
    if test -d $path_dir
        for git_extension in $path_dir/git-*
            # Skip if not a file or doesn't exist
            if not test -e $git_extension; or not test -f $git_extension
                continue
            end
            set subcommand (string replace -r 'git-' '' (basename $git_extension))
            add_abbr $subcommand
        end
    end
end

functions -e add_abbr

if test -e $HOME/.afm-git-configrc
    source $HOME/.afm-git-configrc
end

# Add afm-tools to PATH
if test -e $AFM_HOME/afm-tools/path
    # Add bin directories to path.
    fish_add_path --global --prepend $AFM_HOME/afm-tools/path
end

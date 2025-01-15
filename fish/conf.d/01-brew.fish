#
# Homebrew
#
if not set -qU HOMEBREW_BIN
    for bin in /usr/local/bin/brew /usr/local/Homebrew/bin/brew /opt/homebrew/bin/brew /home/linuxbrew/.linuxbrew/bin/brew
        if test -x $bin
            set -Ux HOMEBREW_BIN $bin
            break
        end
    end
end

if test -x $HOMEBREW_BIN
    cachecmd "$HOMEBREW_BIN" shellenv | source

    # Add homebrew completions
    if test -e "$HOMEBREW_PREFIX/share/fish/completions"
        set -a fish_complete_path "$HOMEBREW_PREFIX/share/fish/completions"
    end
end

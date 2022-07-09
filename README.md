# Config Directory 

AKA "dotfiles"

This repo is designed to be checked out to `$XDG_CONFIG_HOME`.
See [XDG Base Directory Specification] for more.

I try to follow XDG conventions, but this _is_ a mac-centric config.


## Prerequisites and Dependencies

The following are used for managing dependencies and installation.

The install task will attempt to bootstrap these things if they are missing.

- [Homebrew] for most things
- [Sheldon] for zsh things
- [LunarVim] for vim things
- [Kitty] for term things


## Installation

The default `$XDG_CONFIG_HOME` dir is `~/.config`,
and that is where we will install.

> Note that `$XDG_CONFIG_HOME` does not have not to be set yet.
> Installation will attempt to configure it for you, which will
> require admin credentials.

If you have no config dir yet:

```shell
mkdir ~/.config
cd ~/.config
git clone git@github.com:lettertwo/config.git .
make install
```

If you have stuff in `~/.config` already:

```shell
cd ~/.config
git init
git remote add origin git@github.com:lettertwo/config.git 
git fetch
git reset origin/main
git checkout -t origin/main
make install
```

## Updating

An update will do the following:
- pull the latest from lettertwo/config
- update [Homebrew] and installed dependencies 
- update [Sheldon] and installed dependencies
- update [LunarVim] and installed dependencies
- update [Kitty]

```shell
cd ~/.config
make update
```

## Git config

The `git/config` will try to include a `git/user` config file.
I do it this way to avoid having to modify the `git/config` file
with any settings that aren't shareable.

You can add your own user and other settings to `git/user` like this:

```shell
touch ~/.config/git/user
git config --file ~/.config/git/user user.name "Your Name Here"
git config --file ~/.config/git/user user.email "your@email.here"
git config --file ~/.config/git/user credential.helper osxkeychain
```

[XDG Base Directory Specification]: https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
[Homebrew]: https://brew.sh
[Sheldon]: https://sheldon.cli.rs
[LunarVim]: https://www.lunarvim.org/
[Kitty]: https://sw.kovidgoyal.net/kitty/

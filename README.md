# Getting Started

```shell
cd ~/.config/
git clone git@github.com:lettertwo/dotfiles.git .
make install
```

## Updating

```shell
cd ~/.config
git pull
make upgrade
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

# Getting Started

```shell
git clone git@github.com:lettertwo/dotfiles.git
cd dotfiles
make install
```

## Updating

```shell
git pull
make install
```

## Git config

The `.gitconfig` will try to include a `.gituser` config file.
I do it this way to avoid having to modify the `.gitconfig` file
with any settings that aren't shareable.

You can add your own user and other settings to `.gituser` like this:

```shell
touch ~/.gituser
git config --file ~/.gituser user.name "Your Name Here"
git config --file ~/.gituser user.email "your@email.here"
git config --file ~/.gituser credential.helper osxkeychain
```

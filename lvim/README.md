# LazyVim Playground

This is a playground for messing with a "stock"
LazyVim install without affecting the main nvim config.

## Usage

To launch neovim with this config, set the `NVIM_APPNAME` environment variable to `lvim`:

```shell
NVIM_APPNAME=lvim nvim
```

As a convenience, a shell function can be defined.
For example, in `$XDG_CONFIG_HOME/fish/functions/lvim.fish`:

```fish
function lvim
    NVIM_APPNAME=lvim command nvim $argv
end
```

Then `lvim` can be used in place of `nvim` to launch neovim with this config
instead of the default config:

```shell
lvim
```

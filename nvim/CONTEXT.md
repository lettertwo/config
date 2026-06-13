# Neovim Config — Domain Glossary

## App

A focused Neovim mode with a distinct purpose and layout. An app implements the `App`
interface (`name`, optional `load()`, `run(self, args)`, `teardown(self)`) and lives
in `lua/app/<name>/init.lua`. Discovery is file-based; no central registry.

Current apps: `default`, `mergetool`, `scrollback`.

## App Framework

The module (`lua/app/init.lua`, exposed as `_G.App`) that drives the two-phase
lifecycle and provides `App.load()`, `App.launch()`, and `App.quit()`. It is required
from `init.lua` before `plugin/` files auto-source.

## Substrate

Plugins and config that load eagerly for **every app**. Lives in `plugin/*.lua` and
`lua/config/`. Provides capabilities that non-editing apps can plausibly use, with no
behavior that keys off file content or misfires on non-file buffers.

Current substrate plugins: `colorscheme`, `which-key`, `smart-splits`,
`treesitter` (highlighting + parser management only), `mini` (icons + statusline only).

## Default App

The normal editing experience (`lua/app/default/`). Its `load()` method runs during
init (eager phase) and requires all editor plugins and config. Its `run()` method fires
on `UIEnter` and handles lifecycle concerns (dashboard, session restore).

## Load Phase (eager)

`App.load(name)` is called from `init.lua` **during startup**, before `plugin/` files
auto-source and before `UIEnter`. Used by the default app to register `FileType`
autocmds for LSP, completion, and treesitter indenting early enough to catch the first
argv buffer.

## Launch Phase (lifecycle)

`App.launch(name)` fires on `UIEnter`. Calls `app:run()`, which handles layout,
dashboard, and session restore. Also sets up `teardown()` hooks.

## On-Demand Require

Any app may `Config.add()` and `require()` any plugin inside its own `load()` or
`run()` regardless of tier. The substrate/default-app split governs *auto-loading*, not
*availability*. This is how mergetool opts into which-key without which-key being in
every app's mandatory load.

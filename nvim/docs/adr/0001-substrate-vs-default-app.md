# ADR 0001 — Substrate vs Default-App Boundary; Two-Phase App Lifecycle

**Status:** Accepted  
**Date:** 2026-06-22

## Context

The app framework lets Neovim run as different focused apps (`default`, `mergetool`,
`scrollback`, and planned `review`/`debug`). Before this change, every `plugin/*.lua`
file and all of `lua/config/` loaded globally for every app. Lean apps opted out via
two reactive mechanisms: `set eventignore=FileType` at invocation and scattered
`App.is_default()` guards in individual plugins.

This was fragile: adding a fourth app required auditing every global plugin for
potential misfires. It also produced correctness problems — `format_on_save`,
`gitsigns`, `diagnostics`, and `lint` autocmds were registered for mergetool and
scrollback buffers even though those apps never wanted them.

## Decision

### 1. Two tiers: substrate vs default-app

**Substrate** — loads for every app. Criteria: provides a capability a non-editing app
could plausibly use AND has no behavior that activates on file content or fires on
non-file buffers. Lives in `plugin/` (auto-sourced) and `lua/config/`.

**Default-app** — the editor experience. Loaded only when the default app (or a future
editing app) explicitly requires it. Lives in `lua/app/default/plugins/` and
`lua/app/default/`. The default app owns it via `DefaultApp:load()`.

### 2. Two-phase lifecycle

The `App` interface gains an optional `load()` method called by `App.load(name)` during
`init.lua` — before `plugin/` auto-sourcing and before `UIEnter`. The existing `run()`
fires on `UIEnter` as before.

The default app's `load()` registers LSP, completion, treesitter-editing, and all other
editor-experience FileType autocmds during init. This preserves the timing invariant:
autocmds are registered before any buffer's FileType event fires.

### 3. Treesitter split (display vs editing)

Treesitter highlighting (`vim.treesitter.start`) and parser management are substrate —
every code-showing app (mergetool, review, debug) benefits. Textobjects and `indentexpr`
are default-app only.

## Alternatives considered

**Keep everything global, add explicit `App.is_default()` guards per-plugin.** Rejected:
guards stay scattered and everything still loads; the approach is reactive rather than
declarative and doesn't scale to more apps.

**Declarative plugin manifest per app.** Rejected: fights Neovim's `plugin/` auto-source
convention and requires inverting control flow. Premature for a 3-app framework.

## Consequences

- The `set eventignore=FileType` flag in the kitty scrollback invocation can be removed;
  the default-app FileType handlers are no longer registered for lean apps.
- The `App.is_default()` guards in `plugin/mini.lua` (session autosave) and
  `lua/config/snacks/dashboard.lua` are now redundant — the session autosave moved into
  `lua/app/default/plugins/sessions.lua` where it is always in the right context, and
  the dashboard guard is harmless dead code.
- Future apps (review, debug) get syntax highlighting for free (substrate treesitter)
  without needing to opt into it explicitly.
- Future apps that need editing capabilities opt in by calling `Config.add()` +
  `require()` in their own `load()`/`run()` — not by modifying global plugin files.

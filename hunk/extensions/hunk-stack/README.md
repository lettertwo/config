# hunk-stack

A [Hunk](https://hunk.dev) extension for reviewing a stack of changesets. `hunk stack` opens a
review with an outline of the stack in the files pane, next/previous changeset, and a zoom cycle.

The extension replaces the bundled files pane (`replaces: "hunk:files"`) in every session, but only
shows the stack outline when `hunk stack` is active. It also includes the read marks logic from
[hunk-mark-read](https://github.com/meldron/hunk-mark-read) (MIT, vendored with its license in
`src/vendored/mark-read`).

## `hunk stack`

```
hunk stack [hunk diff options]
```

Opens on the changeset the nvim review app opens on: the uncommitted changes when the worktree has
any, else the focus branch. Options such as `--mode` or `--watch` pass through to `hunk diff`.

Hunk seals extension registration before any CLI command runs, so the pane cannot be registered for
`hunk stack` alone. The command instead opens the stack in the process that goes on to host the
delegated review, and the pane draws the outline only when that stack is open.

## Stack sources

Picked per focus branch, in this order: gh-stack (`<git-common-dir>/gh-stack`), Graphite
(`.graphite_metadata.db` through the `sqlite3` CLI), then first-parent `git log` from trunk.

## Zoom

Zoom sets how finely the stack splits into changesets. `combined` is one changeset over the whole
stack, `branch` is one per stack branch, and `commit` is one per first-parent commit. The git-log
fallback has no separate branch zoom. The uncommitted changeset shows at the top of the stack when
the worktree has changes.

## File view

`tree` nests files under directory rows, `grouped` (hunk's narrow-pane list) heads each run of
files in one directory with that directory, and `flat` lists files alone with each one's directory
after its name. `auto` picks tree or grouped by pane width, as hunk does.

## Pane width

```toml
[extension.hunk-stack]
width = 40  # columns, or 0.25 for a quarter of the window
```

A whole number from 1 up is a column count. A number below 1 is a fraction of the window, kept
between 22 and 56 columns. Without `width` the pane matches hunk's files pane: 16% of the window
within those bounds. Dragging the divider overrides either for the session.

## Keys

| Command                            | Default key | Effect                                                                   |
| ---------------------------------- | ----------- | ------------------------------------------------------------------------ |
| `hunk-stack.next-changeset`        | `)`         | Load the next changeset toward the head                                  |
| `hunk-stack.previous-changeset`    | `(`         | Load the previous changeset toward the base                              |
| `hunk-stack.cycle-zoom`            | `I`         | Cycle the zoom, landing on the file you were on                          |
| `hunk-stack.toggle-stack-order`    | `O`         | Flip the outline between head first and base first                       |
| `hunk-stack.cycle-file-view`       | `T`         | Cycle the file view: auto, tree, grouped, flat                           |
| `hunk-stack.toggle`                | `x`         | Mark the selected file read and jump to the next unread file             |
| `hunk-stack.next-unread`           | `X`         | Jump to the next unread file                                             |
| `hunk-stack.toggle-hidden`         | `H`         | Hide or show read files                                                  |
| `hunk-stack.focus-outline-or-left` | `ctrl+h`    | Focus the outline if its pane is open, else the kitty window to the left |
| `hunk-stack.focus-diff-or-right`   | `ctrl+l`    | Focus the diff from the outline, else the kitty window to the right      |

The changeset, zoom, and order commands work only in a `hunk stack` review; elsewhere they say so.
Read marks and the file view work in every review.

`ctrl+h` and `ctrl+l` move between the outline and the diff the way smart-splits moves between nvim
splits, and past either edge to the neighboring kitty window. kitty takes both keys for window
navigation, so they reach hunk only through a passthrough: the `hunk` fish function sets the
`IS_HUNK` user var that `kitty/keybind.conf` matches on. Leaving hunk goes through `kitten @ action`
and needs kitty's remote control socket (`KITTY_LISTEN_ON`).

Clicking a changeset header folds it, and clicking another changeset's file loads that changeset.
In the outline's keyboard mode the diff follows the cursor: a file of the loaded changeset selects
at once, and another changeset's file loads that changeset once the cursor rests on it. Headers
load nothing; expand one with `l` to step into its files. `enter` on a file opens it and focuses
the diff; on a header it folds.

`/` in the outline opens hunk's file filter (`hunk.review.focusFilter`); elsewhere `/` keeps hunk's
meaning. While the filter is set, every changeset with a matching file shows expanded with only its
matches, and the rest are hidden. Listed changesets match the way hunk matches the loaded one, by
path or path before a rename, minus the agent summary they lack. The folds come back when the filter
clears. Loads from the outline leave its folds
as they are. Stepping and zoom open the changeset they load and fold the one they leave, unless
the outline has already set its fold.
Hunk operates on one diff at a time, so switching between changesets goes through hunk's session
daemon (`hunk session reload`), addressed to this window by pid.

## Development

```
bun install
bunx tsc --noEmit
bun test
```

The `hunkdiff`, `react`, and `@opentui/*` dev dependencies are for types only.

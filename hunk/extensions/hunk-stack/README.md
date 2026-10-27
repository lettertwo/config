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

## Keys

| Command                         | Default key | Effect                                                       |
| ------------------------------- | ----------- | ------------------------------------------------------------ |
| `hunk-stack.next-changeset`     | `)`         | Load the next changeset toward the head                      |
| `hunk-stack.previous-changeset` | `(`         | Load the previous changeset toward the base                  |
| `hunk-stack.cycle-zoom`         | `I`         | Cycle the zoom, landing on the file you were on              |
| `hunk-stack.toggle-stack-order` | `O`         | Flip the outline between head first and base first           |
| `hunk-stack.toggle-tree`        | `T`         | Cycle the files pane's projection: auto, tree, flat          |
| `hunk-stack.toggle`             | `x`         | Mark the selected file read and jump to the next unread file |
| `hunk-stack.next-unread`        | `X`         | Jump to the next unread file                                 |
| `hunk-stack.toggle-hidden`      | `H`         | Hide or show read files                                      |

The changeset, zoom, and order commands work only in a `hunk stack` review; elsewhere they say so.
Read marks and the tree toggle work in every review.

Clicking a changeset header folds it, and clicking another changeset's file loads that changeset.
Hunk operates on one diff at a time, so switching between changesets goes through hunk's session
daemon (`hunk session reload`), addressed to this window by pid.

## Development

```
bun install
bunx tsc --noEmit
bun test
```

The `hunkdiff`, `react`, and `@opentui/*` dev dependencies are for types only.

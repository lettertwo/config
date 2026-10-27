# hunk-stack

A [Hunk](https://hunk.dev) extension that marks files read in a review. It includes the read marks
logic from [hunk-mark-read](https://github.com/meldron/hunk-mark-read) (MIT, vendored with its
license in `src/vendored/mark-read`).

The extension replaces the bundled files pane (`replaces: "hunk:files"`) in every session, with a
read marker on each row.

## Keys

| Command                    | Default key | Effect                                                       |
| -------------------------- | ----------- | ------------------------------------------------------------ |
| `hunk-stack.toggle`        | `x`         | Mark the selected file read and jump to the next unread file |
| `hunk-stack.next-unread`   | `X`         | Jump to the next unread file                                 |
| `hunk-stack.toggle-hidden` | `H`         | Hide or show read files                                      |

## Development

```
bun install
bunx tsc --noEmit
bun test
```

The `hunkdiff`, `react`, and `@opentui/*` dev dependencies are for types only.

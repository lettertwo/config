---
name: annotations
description: Address line-anchored annotations left in nvim. User-invoked only.
disable-model-invocation: true
---

`/annotations [path]` — nvim's annotation `send` action types `/annotations` with no argument, since it runs inside the same repo this skill does.

Resolve the feedback file: if `path` is given, use it; otherwise take the newest `feedback-*.md` under `$(git rev-parse --git-dir)/claude-annotations/`.

That file is feedback exported by `nvim/lua/config/annotations/export.lua`: a header (repo, `HEAD`, branch, batch id, and the `Resolutions:` path to write to) followed by one section per annotation:

```
## <file>:<lnum>[-<end_lnum>]  (id: <id>)
```<ft>
<context lines, the annotated ones marked with `>`>
```
<body>
```

For each section:

1. Open `<file>` at `<lnum>` (or `<lnum>`-`<end_lnum>`) and make the change `<body>` asks for.
2. If a section doesn't call for a code change (a question, or something already fine as
   written), leave the code alone: that's `status: "unchanged"`, not a skipped section, and its
   `note` says why nothing changed.
3. Append one row to the `Resolutions:` path from the header, via `jq -cn` (one append per row,
   or one heredoc batching all of them once every section is done):
   `{id, status, note, ts, turn_seq}`. `status` is `"changed"` or `"unchanged"`. `note` is one
   line: what changed, or why nothing did. `ts` is `` `date +%s` ``. `turn_seq` is the `seq` of
   the last row in the most recently modified `*.jsonl` under
   `<git-common-dir>/claude-turns/` for this repo, omitted when no such ledger exists yet. The
   file may already contain rows with `status: "manual"`, written by nvim when the user resolves
   an annotation without ever sending it: leave those alone, they aren't yours to touch.

Do not delete or edit the feedback file itself: it's nvim's export, not a scratch file. Only ever
append to the resolutions file; never edit `annotations.json`.

Reply with exactly one line per annotation id, in the order they appear in the file:

```
<id>: <what changed, or why not>
```

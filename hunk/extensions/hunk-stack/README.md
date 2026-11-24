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

Builds the stack around the checked-out branch and opens on the uncommitted changes when the
worktree has any, else on that branch's changeset. Options such as `--mode` or `--watch` pass
through to `hunk diff`. `hunk stack notes` reads and changes the saved review notes instead (see
[`hunk stack notes`](#hunk-stack-notes)).

A changeset switch reloads the review with only the arguments it is given, so `hunk stack` repeats
`--watch` and `--agent-context` on every switch. `--agent-context` names a sidecar: a JSON file
of agent annotations that Hunk shows beside the diff. Hunk reloads a sidecar only from a file
inside the repository, so one read from stdin or from outside it shows on the first changeset
only, with a notice saying so. View options such as `--mode` are not repeated, since the review keeps its view across a
switch.

An extension can register panes only while Hunk loads it, which is before any CLI command runs,
so the pane cannot be registered for `hunk stack` alone. The command instead reads the stack and then hands its arguments to
`hunk diff` in the same process, so the review that follows runs where the stack is already open.
The pane draws the outline only when a stack is open.

## Stack sources

Picked for the checked-out branch, in this order: gh-stack (`<git-common-dir>/gh-stack`), Graphite
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

## Notes

A file row shows `*N` for the notes on it, as hunk's files pane does: review notes, agent comments,
and `--agent-context` sidecar annotations. Hunk keeps review notes and agent comments in memory for
the life of the process and keys them by path rather than by diff range, and it matches sidecar
annotations by path on every load. So left alone, a note would show in every changeset that touches
its file, at the lines it was written on. The extension corrects this for the notes it saves (see
Where a note goes below). Rows of changesets that are not loaded count the notes on their path as
of the last time the path was loaded.

### Saved notes

Hunk drops its notes when the process exits, so the extension journals each one as it changes
(user notes, agent comments, and replies) and applies them again when a changeset loads. The
journal is one append-only JSONL file per worktree root under
`$XDG_STATE_HOME/hunk-stack/notes/` (`~/.local/state` without it), and files untouched for 30 days
are deleted. `[extension.hunk-stack] persist = false` turns it off along with the read marks. The
folder is not configurable from config, since a repository's `.hunk/config.toml` layers into that
table.

Notes are saved in every review, stack or not. A record from a journal written before notes
carried an origin is dropped when the journal is read.

Hunk has no way for an extension to create a note you can edit, so every note is made through
`hunk session comment apply --stdin` against the extension's own session, the call agents use. That
goes for a restore and for a note you write in the editor below. A restore applies the notes that
start a thread first, then the replies to those, then replies to replies, one call per level,
because the parent of a reply has to exist before the reply does. A note you wrote has the author
`you`, and the journal still records it as yours. A note keeps its summary and its longer rationale
text. It loses rich markup, which Hunk accepts only in a session started with `--experimental`.

#### Writing notes

The extension replaces Hunk's note keys with its own editor, a textarea docked at the bottom of the
review. The config binds three commands to the keys Hunk's built-ins used, and unbinds the
built-ins (`hunk.review.startNote`, `hunk.review.replyToActiveNote`, and
`hunk.review.editActiveNote` set to `false`), since a built-in wins a key both claim:

- `c` (`note-add`) writes a note on the current line. A line outside every hunk is refused, since
  Hunk accepts a note nowhere else.
- `R` (`note-reply`) replies to the thread on the current line, under the thread's first note, so
  threads stay flat. A dialog asks which when several threads sit on the line.
- `E` (`note-edit`) edits a note of yours on the current line, with its text filled in. Hunk cannot
  edit a note made through `comment apply`, so the thread is removed and applied again with the new
  text, replies last, and each note keeps its saved record.

These keys also work on a note card. While a card is active Hunk reports no current line and does
not tell an extension which card it is, so the extension runs the motions that reach a card itself:
the config unbinds `hunk.review.stepDown`, `stepUp`, `nextNote`, and `previousNote` and binds
`step-down` (`j`, `down`), `step-up` (`k`, `up`), `next-note` (`.`), and `previous-note` (`,`),
which run the built-in and predict where it lands from a model of Hunk's rows and cards. On a card,
`R` replies to that card's thread, `E` edits it when it is yours, and `c` writes on its line. Some
moves go unseen: a click on a card, another review command, or a model that disagrees with what
Hunk drew. Then the commands offer the cards beside the last line they saw, or every thread in the
selected hunk. Hunk passes an extension command no count, so these motions take none.

The textarea takes every key while it has focus, so `ctrl+s` saves and `escape` cancels, and either
closes the pane and returns the keys to Hunk. An empty note is not saved, since `comment apply`
rejects a batch with an empty summary. Hunk's own `D` still deletes a note.

#### Origin

Each note stores its origin, the commits of the changeset that was loaded when it was written: one
commit at the commit zoom, the branch's commits (`git rev-list <base>..<head>`) at the branch zoom,
every commit of the stack when combined. A note written on uncommitted changes stores the branch
they sat on instead. Outside `hunk stack` the review itself says what is loaded: a working-tree
`hunk diff` is the uncommitted changes, `hunk show <sha>` is that commit, and `hunk diff <a>..<b>`
is the commits in that range. With no stack to say which branch owns a commit, those commits carry
no branch, so the subject-on-a-branch match below is skipped for them and only the sha and patch
id apply. Re-homing an uncommitted note then searches the 20 newest commits of its branch. A note shows on a loaded changeset that holds every origin commit and has its
line, so a note written on one commit also shows on that commit's branch and on the combined
changeset, and waits on a sibling commit even when the sibling touches the same file.

Each stored commit is `{ sha, patchId, subject, branch }`, with `patchId` from
`git patch-id --stable`. A stored commit matches a changeset's commit by sha, else by patch id (a
rebase kept the patch), else by the same subject on the same branch (an amend changed the patch).
Each step runs only when the one before found nothing, and patch ids are cached by sha. When the
worktree is clean again and a commit on the branch holds the line of an uncommitted note, with the
same text and context, the note's origin moves to that commit.

#### Where a note goes

The journal keeps the text of the line each note was written on, and up to two lines above and
below it. At the saved line with the same text a note stays, whatever surrounds it. Moving to
another line takes both the text and the surrounding lines, so a `}` does not jump to the nearest
other `}`. There is no other fallback. Only lines inside a hunk count, since Hunk accepts a note
nowhere else:

- **Restored**: the changeset holds the origin and the line is in it. The notice reads
  `stack: restored 2 saved notes (1 pending, 3 outdated)`.
- **Pending**: the loaded changeset does not hold the origin, or its file is not in it. It is tried
  again on every load, and is never called outdated.
- **Outdated**: a changeset that holds the origin is loaded, and no line inside a hunk matches. An
  open thread is placed on the saved line when a hunk still spans it, else on the start of the
  file's first hunk, and its author line reads `you (outdated)` (or `<author> (outdated)`). The
  saved anchor does not change, so the thread finds its line again if a later changeset brings it
  back.

Notes Hunk already holds are judged on every load too, since Hunk keeps a note by path and line
number and would otherwise show it at its old line on a changeset where the line moved. A note
Hunk has on a different line than the one it belongs on is removed and applied again on the right
one, with its replies, and the notice reads `stack: moved 1 saved note` when the restore added no
new ones. A note whose origin the loaded changeset does not hold, or whose file is not in it, is
removed from Hunk and stays in the journal as pending. A note already on its line is left alone,
and none is ever applied twice. The notes a restore makes are not journaled as new ones, and nor
are the removals. Removing a restored note yourself removes its saved record. Restored agent notes
follow Hunk's agent-notes toggle (`a`), which the extension cannot switch on for you.

#### Thread status

A thread (its first note and the replies) is `open` or `resolved`. A resolved thread can name the
commit that fixed it, which is stored and matched like an origin commit. Who the thread waits on is
not stored: when the last note is the user's it waits on the agent, otherwise on the user. Status
is a journal entry on the first note's key, and replay takes the last one per key.

A restore skips resolved threads. When one is in the review as it resolves, the next restore
removes it from Hunk (`hunk session comment rm`, replies first, since Hunk will not remove a note
that has replies) without journaling a removal.

#### `hunk stack notes`

```
hunk stack notes list [--json]
hunk stack notes resolve <key> [--commit <sha>]
hunk stack notes reopen <key>
```

These read and write the journal of the current worktree and need no Hunk session or stack. With
no stack source (no trunk branch, say) `list` still gives each thread's origin, status, and who it
waits on, and its placement is empty. `list` prints
every thread with its key, path, line, origin, status, fix commit (and the sha it has now, when the
stack still holds it), who it waits on, its replies, and its placement: each changeset of the stack
at every zoom that holds the origin, and whether the note is shown, outdated, or waiting for its
file there. The `hostIds` of a note are the ids Hunk gave it in the processes that restored it (a
process is named by `pid`, as `hunk session list` shows), for matching a thread to a live note.
`resolve` and `reopen` take the key of a thread's first note and append a status entry, which the
running extension reads on its next restore.

#### The saved-notes dialog

`hunk-stack.show-saved-notes` (`S`) lists every saved note under its status, and `enter` acts on
the chosen row:

- **shown**: jumps the diff to the note's line. A reply jumps to the note it answers.
- **pending**: loads the narrowest other changeset of the stack that holds the note's origin (a
  commit before its branch, a branch before the combined changeset) and lands on the note's file,
  where the note is restored.
- **outdated**: asks before deleting the saved note and the replies under it, and removes them from
  Hunk if they are showing.
- **resolved**: lists each resolved thread once. Choosing one loads it into the diff for this
  session and leaves it resolved in the journal.

When any note is outdated, the first row deletes all of them, after the same question.

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
| `hunk-stack.show-saved-notes`      | `S`         | List saved notes: jump to one, load a pending or resolved one, delete an outdated one |
| `hunk-stack.focus-outline-or-left` | `ctrl+h`    | Focus the outline if its pane is open, else the kitty window to the left |
| `hunk-stack.focus-diff-or-right`   | `ctrl+l`    | Focus the diff from the outline, else the kitty window to the right      |

The changeset, zoom, and order commands work only in a `hunk stack` review; elsewhere they say so.
Read marks and the file view work in every review.

`ctrl+h` and `ctrl+l` move between the outline and the diff the way smart-splits moves between nvim
splits, and past either edge to the neighboring kitty window. kitty takes both keys for window
navigation, so they reach hunk only when kitty is told to let them through:
`fish/functions/hunk.fish` in this repository wraps the `hunk` command and sets the kitty user
variable `IS_HUNK` while it runs, and `kitty/keybind.conf` sends both keys on to a window that has
that variable instead of acting on them. Leaving hunk goes through `kitten @ action`
and needs kitty's remote control socket (`KITTY_LISTEN_ON`).

Clicking a changeset header folds it, and clicking another changeset's file loads that changeset.
In the outline's keyboard mode the diff follows the cursor: a file of the loaded changeset selects
at once, and another changeset's file loads that changeset once the cursor rests on it. Headers
load nothing; expand one with `l` to step into its files. `enter` on a file opens it and focuses
the diff; on a header it folds.

`/` in the outline opens hunk's file filter (`hunk.review.focusFilter`); elsewhere `/` keeps hunk's
meaning. While the filter is set, every changeset with a matching file shows expanded with only its
matches, and the rest are hidden. Hunk's filter matches a file by its path, its path before a
rename, and the summary an `--agent-context` sidecar gives it. Changesets that are not loaded match
by the two paths only, since a sidecar's summaries are read when a changeset loads. The folds come
back when the filter clears.

Loading a changeset from the outline leaves every fold as it is. Stepping and zoom expand the
changeset they load and fold the one they leave, except for a header you folded or expanded
yourself, which stays as you set it.

Hunk operates on one diff at a time, so switching between changesets goes through hunk's session
daemon (`hunk session reload`), addressed to this window by pid.

A `hunk session reload` run from outside the extension, by an agent say, is followed when it loads
a changeset of the stack: `show <sha>` for a commit, or `diff <baseSha>..<headSha>` for a range,
with full SHAs. The extension reads the stack again, so a commit made since the last keypress is
found, and switches to the zoom that lists the changeset. A reload from outside drops `--watch`
and `--agent-context`, so when `hunk stack` was launched with either, the extension loads the
changeset once more with them. A range the stack does not list leaves the outline where it was.

## Development

```
bun install
bunx tsc --noEmit
bun test
```

The `hunkdiff`, `react`, and `@opentui/*` dev dependencies are for types only.

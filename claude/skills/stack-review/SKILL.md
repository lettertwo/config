---
name: stack-review
description:
  Review a branch, a stack, or work-in-progress changes in a live Hunk session. A reviewer with no
  session context reads the diff, each finding is verified against source, and the verified
  findings land as Hunk notes that the user answers in place, followed by gated fix commits. Use
  when the user asks for a review, a tour, or annotations on a diff, and whenever they say they
  left notes in Hunk.
argument-hint: "[deep] [tour | what the notes are for]"
---

`hunk-review` is the command reference for `hunk session *`. Load it first. This skill is the
procedure around those commands: how findings are produced, how they reach the diff the user is
reading, and how a thread gets from a note to a fix the user has seen.

- With no argument, review the stack for defects (sections 3 and 4).
- `deep` replaces the single reviewer with several independent ones. Read [`deep.md`](deep.md)
  before launching anything. It is for invariant-heavy or gotcha-dense diffs.
- `tour` narrates for a reader who has not seen the code: numbered notes (`3/12 ...`) in the order
  that tells the story. Any other argument says what the notes are for (interview questions on a
  submission, say). Both skip section 3: you read the diff and write the notes yourself.

## 1. Find the session, every turn

Run `hunk session list` at the start of every turn that touches Hunk. A restart gives the session a
new id, so an id from an earlier turn is not safe to reuse. Select with `--repo .` when one session
matches the repo, and by id from that list when several do.

`hunk session get` prints the title. A title of the form `<name> <sha>..<sha>` is a `hunk stack`
session, and section 2 applies.

Findings are delivered in Hunk and nowhere else. When `hunk session list` shows no session for the
repo, do not wait for one: ask the user to run `hunk stack`, and start section 3 in the same turn.
Take each branch's range from git: `git merge-base <parent> <branch>` to the branch head, with
each parent found by following [`DISCOVERY.md`](DISCOVERY.md) (gh-stack, Graphite, or the trunk
when there is no stack). Before
posting, compare those ranges with the session title, and review again any changeset whose range
differs.

## 2. `hunk stack` sessions

The hunk-stack extension owns changeset switching. It loads each changeset as an exact
`baseSha..headSha` and matches the loaded range against its outline.

- Reload a stack session only to a changeset the stack lists, with full SHAs:
  `hunk session reload <id> -- show <sha>` for one commit, or
  `hunk session reload <id> -- diff <baseSha>..<headSha>` for a branch's range. The extension
  reads the stack again, finds the changeset at any zoom, and moves the outline and the zoom to
  it. Any other range leaves the outline pointing at a changeset that is no longer on screen.
- Run `hunk session get` after a reload and check that the title shows the range you asked for.
- A reload moves the user's screen. Do it when they are waiting on you (posting a review, showing
  a fix), and not while they are reading.
- The user steps with `(` (toward the base) and `)` (toward the head), and cycles zoom with `I`
  (combined, branch, commit). Read the title again after they say they moved.
- Read a changeset with `git diff <base>..<head>` using the SHAs from the title, so what you read
  is what the user sees.

The extension reads the stack from git again on every step, zoom key, and reload, so new commits
show with no restart. Each branch's base is the exception: it comes from
`<git-common-dir>/gh-stack`, and that file lags a rebase until `gh stack sync` or a push. When a
range shows files that do not belong to the branch, compare the file's `base` for the branch with
`git merge-base` against the parent branch. `gh stack sync` fixes a stale base, and it is the
user's to run.

A session that is not a stack session may be reloaded as `hunk-review` describes.

## 3. Find and verify

Launch one `general-purpose` subagent as the reviewer. It starts with no context from this
session, which is the reason to use one: the main thread usually wrote the code under review. One
reviewer covers every changeset in the stack, base first, unless the user named one.

Give the reviewer:

- Each changeset's name and exact `<base>..<head>` range, to read with `git diff`. It may read
  anything else in the repo (a call site, a test file).
- The paths of the repo's standards docs (`CLAUDE.md`, `CONTRIBUTING.md`, and the like), to read
  for itself.
- The spec, when one resolves: an issue referenced in the commit messages, or a file under
  `docs/`, `specs/`, or `.scratch/` that matches the branch. Without one, spec conformance is not
  a category.
- The categories, most important first. A finding higher on the list outweighs one lower down.
  1. Functional bugs: logic errors, missing guards or awaits, races, stale closures, off-by-ones,
     broken control flow.
  2. Violations of the standards docs, needless complexity, duplicated logic.
  3. Missing tests for new behavior or a bug fix.
  4. Performance, measured where it can be (run the query plan, do not guess at it).
  5. Spec conformance, when a spec was given.
  6. Accessibility, when the diff touches UI markup.
- What to leave out: formatting, style and type nits that lint owns, and anything that affects
  neither correctness nor maintainability.
- The return format, per finding: changeset, file, line on the new side, the text of that line,
  severity, category, description, and a concrete fix where one exists. When a question raised by
  one changeset is answered by code in another, the finding says so and names the file.

Then verify, in this order:

1. List every finding before reading any source yourself, and merge duplicates. Reading first
   turns you into a second reviewer with a veto.
2. Read the source around each finding, trace the logic, and run whatever check the reviewer
   suggested. Mark each one **CONFIRMED** (traced and real), **PLAUSIBLE** (you could neither
   refute it nor fully trace it, as with a runtime condition you cannot reproduce), or
   **dismissed**, with a one-line reason.

## 4. Post

A CONFIRMED finding posts as a statement. A PLAUSIBLE finding posts as a question: its summary
starts with `Question:`. Dismissed findings stay out of Hunk, and chat gets their count with each
one-line reason. A review posts nothing else. Orientation and intent notes belong to `tour`.

Hunk accepts a note only on a line inside a hunk of the loaded changeset. So post one
`comment apply` batch per changeset: reload to each changeset that has findings, head first, and
post its batch, so that the session ends on the changeset nearest the base. Tell the user how
many notes each changeset holds. When a batch fails, fix its cause (usually a line outside a hunk)
and post it again in the same turn.

Order a batch by the order the files appear in the review, then by line. `--focus` lands on the
first item, and that should be the first note the reader meets.

Writing a note:

- One or two sentences in `summary`, with supporting detail in `rationale`.
- Say what the reader would not spot from the diff. In a tour, skip hunks that explain themselves.
- Use the plain verb: "the test asserts", not "the test pins".
- Do not post a guess about the author's intent as a fact. Check it, or ask it as a `Question:`,
  and answer a question yourself first when the repo can answer it.

Notes are prose for a reader, so the voice rules apply.

## 5. Notes persist, and their ids do not

The extension journals every note and reply to one JSONL file per worktree under
`$XDG_STATE_HOME/hunk-stack/notes/` (default `~/.local/state`), and applies them again when a
changeset loads. The journal also holds the review's bookkeeping: each note records the commits of
the changeset it was written on, and each thread is `open` or `resolved`.

- Do not re-apply notes after a restart. The extension already has.
- Every restored note has a new id, and a restored user note lists as an agent note by
  `you (restored)`. Run `comment list --type all --json` again before any `replyTo`, and treat that
  author as the user.
- Read threads with `hunk stack notes list --json`, which needs no session and covers every
  changeset, loaded or not. Each thread has `key`, `path`, `line`, `origin`, `status`, `fix` (the
  commit that closed it), `waitingOn` (`agent` when the user spoke last, `user` when you did,
  `null` once resolved), `placement`, and `replies`. `hostIds` pairs a note with the id Hunk gave it
  in a process; the `pid` is the one `hunk session list` shows for the live session.
- A note shows only on a changeset that holds every commit of its origin and has its line.
  `placement` lists the changesets of the stack that hold the origin, each `shown`, `outdated`, or
  `pending` (the file is not in that diff). A changeset that does not hold the origin is pending
  for the note and is not listed. An open thread whose line is gone from a changeset that holds its
  origin shows beside its old line with `(outdated)` in the author line.
- Resolved threads leave the diff. The user lists them with `S`.

## 6. The user's notes

Hunk does not notify you when the user writes a note. When they say they left notes, or that they
are done with a changeset:

1. Run `hunk stack notes list --json` and take the open threads with `waitingOn` of `agent`. They
   cover every changeset. For the ids to reply to, run
   `hunk session comment list ... --type all --json` on the loaded changeset and match each thread
   by `path`, `line`, and the `pid` in `hostIds`.
2. Reply in Hunk with one `comment apply` batch of `replyTo` items. A reply is short: agree and say
   what changes, or answer the question.
3. In chat, list what you agreed to change, then the items that need a decision from the user.
   Make no edit until they answer.

A reply fails with "no longer available as a reply parent" when the thread's changeset is not
loaded. Reload to a changeset its `placement` lists as `shown`, list that changeset's notes again
for the new ids, and reply there.

## 7. Fixes

Make no fix without a go-ahead, including for a CONFIRMED finding that carries a concrete fix.

- State the plan before editing: which branch each fix lands on, whether that branch has a
  worktree, and any rebase of the branches above it. A rebase of a pushed branch needs its own
  go-ahead.
- Make one fix commit per branch, with a message that says it addresses review notes. Close each
  thread it answers with `hunk stack notes resolve <key> --commit <sha>`. The extension matches
  that commit by sha, then patch id, then subject on the branch, so a later rebase or amend needs
  no update. A resolved thread leaves the diff on the next load.
- Show the fix: reload the session to the first fix commit with `show <sha>`, and name the
  others by SHA and subject. When a fix rebased the branches above it, ask the user for
  `gh stack sync`, since branch zoom is wrong until the gh-stack file records the new bases.

## 8. Close

Report from `hunk stack notes list --json`: the threads still `open` with their `waitingOn`, and
the fix commits by branch. When none are open, say so in one line.

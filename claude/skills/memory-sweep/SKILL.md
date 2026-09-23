---
name: memory-sweep
description: Audit this project's AutoMem store — retire memories whose premise has resolved, split files whose body outgrew their description, and reconcile the index. Use when the memory store needs a pass, or a recalled memory turns out to be stale.
disable-model-invocation: true
---

A memory store decays in two directions. `project` memories describe dated state that resolves
without telling anyone, and any memory's body accretes facts its `description` never advertised —
which matters because that description is the only thing recall decides from. A sweep fixes both and
reconciles the index against the files.

The store is not a repo. There is no branch, no review, and no revert: **every deletion here is
permanent.** The sweep therefore runs in two halves — propose everything, apply nothing, then apply
only what the author approved, file by file.

## Invocation

`/memory-sweep` — the whole store. `/memory-sweep <name-or-glob>` — only matching files, for when a
single recalled memory looked wrong.

## Locating the store

Use the memory directory the system prompt names for this session. Worktrees of one repo share a
single store, so a sweep run from any worktree edits the same files every other worktree loads.
Confirm the resolved path exists before reading anything; if it doesn't, stop and say so rather than
sweeping a neighbouring project's store.

## Pass 1 — index reconciliation

Mechanical, and it runs first because the later passes assume the index is trustworthy. `MEMORY.md`
must hold exactly one pointer line per memory file:

```bash
cd "$STORE"
ls *.md | grep -v '^MEMORY.md$' | sed 's/\.md$//' | sort > /tmp/mem-files.txt
grep -o '(\([a-z_0-9-]*\)\.md)' MEMORY.md | tr -d '().' | sed 's/md$//' | sort > /tmp/mem-indexed.txt
comm -3 /tmp/mem-files.txt /tmp/mem-indexed.txt   # left = unindexed file, right = dangling pointer
```

An unindexed file is invisible to recall. A dangling pointer promises a memory that isn't there. Both
are drift, not judgment calls — there is no verdict to weigh, and one approval covers them all.

## Pass 1b — link integrity

Also mechanical, also no verdict to weigh. `name:` is a kebab-case slug that identifies a memory —
independent of its filename, which drifts freely and never has to match it. `[[links]]` resolve
against those `name:` values, not against filenames:

```bash
cd "$STORE"
grep -h '^name:' *.md | sed 's/^name: *//' | sort -u > /tmp/mem-names.txt
grep -oh '\[\[[^]]*\]\]' *.md | tr -d '[]' | sort -u > /tmp/mem-links.txt
comm -23 /tmp/mem-links.txt /tmp/mem-names.txt   # link targets that resolve to nothing
```

A broken link is usually a rename: find the file whose `name:` is closest to the stale target and
point the link at its current value. Print every rewrite and every remaining unresolved target; a
silent guess is how a link gets pointed at the wrong memory.

## Pass 2 — compound files

Every file, no external lookups. Read each one and compare its body against its own `description` and
`name`. A file is **compound** when the body carries a fact a reader of the index line would not
expect to find — a second convention, a mechanism reference, a lesson about delegation. Dated
`**Added**` / `**Verified**` subsections appended over time are the usual tell.

Two other things surface cheaply in the same read:

- **Mistyped memories.** A `feedback` file that is really an external-mechanics reference wants
  `type: reference`; a `project` file stating a durable rule wants `type: feedback`.
- **Internally superseded claims.** A later dated note in the body that contradicts an earlier one —
  the earlier line goes, and the correction becomes the fact.

## Pass 3 — stale project state

Only `type: project` files, and this is the pass that costs something: each one's premise has to be
checked against the world. Read the memory, name its premise in one sentence, then find evidence:

- **PRs and branches** — `gh pr view <n> --json state,mergedAt`, `git log --oneline --grep=<ticket>`,
  `git branch -r --merged "$(git symbolic-ref --short refs/remotes/origin/HEAD)"`
- **Linear** — the issue's current status; `Done` or `Canceled` closes a premise that was "open"
- **Artifacts** — a plan, RFC, or doc the memory points at: does it still exist, and does it still say
  what the memory claims it says
- **Code** — a file, flag, or symbol the memory names, checked for still being there

When the batch is large, gather this evidence with Explore agents — one per memory, dispatched in a
single message — and keep their raw output out of the main thread. Render the verdicts yourself.

**Absence of evidence is not resolution.** A premise you could not check gets `unverified` and the
file is left exactly as it is. Say which ones those were.

## Verdicts

One per file, and every one cites the evidence that produced it.

| Verdict | Meaning | Action |
|---|---|---|
| `current` | premise still open, description matches body | none |
| `resolved` | the work landed or the question closed | delete file + pointer line |
| `drifted` | partly true; some claims outlived their premise | rewrite body and pointer line |
| `split` | body carries facts the description doesn't advertise | split into N files, N pointer lines |
| `retype` | wrong `type:` for what it holds | rename file, edit `type:`, rewrite pointer line; body kept |
| `unverified` | premise not checkable from here | none, and report it |

## Promotion candidates

A memory that states a convention the whole project follows may belong in the repo's agent docs
instead of the store. **The sweep only ever proposes this.** There is no promotion verdict, no
automatic edit, and nothing deleted in this sweep — both gates below have to hold before it's even
worth raising:

- **The repo has somewhere to put it.** Check for an `AGENTS.md` or `CLAUDE.md` at the repo root, and
  a section it would sit under. No host doc, no proposal.
- **The memory reads as project-wide.** The file's own text is the evidence: a memory saying a
  convention "matches what the rest of the team is doing" is project-wide; one recording what the
  author personally prefers is not. Do not infer team scope from a rule merely sounding general.

Raise these as a short list after the verdict table, each naming the target doc and the sentence in
the memory that makes it project-wide. If the author accepts, the repo edit goes through that repo's
normal branch and review path, and **a later sweep deletes the memory file once that change has
landed** — deleting it first leaves the rule with no home at all.

## Propose, then apply

Present the verdicts as one table — file, verdict, the evidence in a clause — with `current` collapsed
to a count. Name the `unverified` files; the author can often check a premise the sweep could not.
Promotion candidates go in their own list below it, never as table rows, because nothing in the apply
step touches them. Then stop.

**Quote the full body of every file proposed for deletion** before deleting it. A one-line summary is
not enough to approve destroying the only copy. Deletions are approved individually; rewrites,
splits, retypes, and the Pass 1 / Pass 1b mechanical repairs can be approved as a group.

**Back the store up before the first edit** and say where it went. A bulk link rewrite touches every
file at once, and there is no revert here.

```bash
B=/tmp/memory-backup-$(date +%Y%m%dT%H%M%S)
mkdir -p "$B" && cp "$STORE"/*.md "$B"/ && echo "backed up to $B"
```

**Apply in this order.** Each step reads what the one before it wrote:

1. **Filenames** — retypes, deletions, and splits, which together settle which files exist.
2. **Bodies** — the `drifted` rewrites, and the content distributed into split files.
3. **`name:` fields** — assign a fresh kebab-case slug to each new split file; existing files keep
   theirs.
4. **`[[links]]`** — rewritten to the current `name:` values for anything split or retyped.
5. **`MEMORY.md`** — reconciled last, against the files that exist by then.

Diagnosing in a different order is fine; the passes do. A write out of sequence repairs a filename
that a later step then changes.

Splits inherit carefully: each new file gets a `name` and `description` covering only its own fact,
the `type` its content actually wants, and the original's dated verification notes distributed to
whichever new file they belong to. Cross-link the pieces with `[[name]]`.

## The close

Re-run the Pass 1 and Pass 1b commands after applying, and reconcile the type census against what the
verdicts said would change (`grep -h '^  type:' *.md | sort | uniq -c`). A sweep that deletes a file and
forgets its pointer line has manufactured the drift it came to remove — and mid-chain failures in a batch
of edits are silent, so the check is the proof, not the intent.

Report four things: what was deleted, what was rewritten or split, which premises came back
`unverified`, and any promotion candidates left for the author to decide. The `current` count is a
number, not a list.

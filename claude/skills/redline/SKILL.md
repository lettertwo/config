---
name: redline
description: Walk a long document section by section with the author, editing as you go. Use when the ask is to read through, review, or revise a document together rather than rewrite it in one shot.
disable-model-invocation: true
---

A long document gets edited by walking it — one section at a time, in order, with the author in the
loop at every stop. You present, they respond, you draft, you write. The document itself is the
artifact; a **ledger** tracks the walk so it survives compaction and so decisions made at one stop
aren't re-litigated at the next.

A redline pass **edits the document in place** as it goes and finishes with the document changed —
findings handed off for someone else to act on are `/code-review`'s job.

## Invocation

`/redline <path>` — or with no path, the document already under discussion.

**If a ledger already exists for this document, load it and resume** at the first open stop. Say which
stop you're resuming at and how many remain. Never restart a walk that's underway.

## The ledger

Lives at `.scratch/redline-<doc-slug>.md`. Check that `.scratch/` is git-ignored (`git check-ignore
.scratch`); if it isn't, ask the author where the ledger should go rather than committing walk state
to their repo.

```markdown
# Redline: <doc path>

Started <date> · <n> stops · currently at <stop k>

## Standing rules

<!-- doc-wide notes: applied to every remaining stop, then swept over closed ones at the close -->

- <rule> — raised at <stop>

## Stops

1. [x] <heading> (lines a–b) — <one line: what was decided>
2. [ ] <heading> (lines a–b)
...

## Carry-forward

<!-- edits already applied to a later stop, and notes deferred to one -->

- <stop n, heading> — <what was already settled there, and by which stop>
```

Update it at the close of every stop, in the same turn as the edits. A ledger written later is a
ledger that doesn't survive the crash it exists for.

## Charting the stops

Before the first stop, read the document's heading outline and propose a manifest. **Show it to the
author and get approval before walking** — they need to see how long this is.

A **stop** is a run of the document short enough to quote in full — call it 80 lines, and stretch to
100 only when the alternative is a bad seam. Build stops from the heading outline:

- **Merge** a heading whose body is a few lines into its neighbor. A two-line stub is not a
  conversation.
- **Split** anything longer at its subheadings, and if it has none, at paragraph boundaries. There is
  always a seam — prose divides. Never split inside a code fence or a table.
- **Repetitive sections merge past the limit.** Nine task entries built from one template are one
  stop, not nine; the author is reading a pattern, not nine arguments.

Front matter, title blocks, and reference lists ride with the first real section unless there's
something to discuss in them.

## The four beats

Each stop is exactly these, in order. Present ends your turn — the other three follow the author's
response.

### 1. Present

**Quote the section in full.** Every line of it, verbatim — the author is reading along, and a
summary hides exactly the phrasing a redline pass exists to catch. If a stop is too long to quote,
that's a charting error: subdivide it and present the first piece, rather than summarizing. Head the
quote with the heading and line range.

Then give **initial thoughts. Brief.** At most three, ranked by how much they matter, each a couple of
sentences. Every one names a concrete defect or a concrete improvement, with the evidence that makes
it a defect — a grep count, a contradiction with another line, a term used two ways.

**Say so when a section is fine.** Three findings per section is not reading, it's generating. A stop
that produces "no notes from me — this holds up, here's why" is a good stop.

Then stop and wait. Do not edit, do not open a question dialog, do not run ahead to the next section.

### 2. Take notes

The author responds. For each note:

- **Verify it against the document before agreeing.** Grep the term, count the uses, read the
  surrounding lines. Agreement without checking is how a fix gets applied to four of seven instances.
- **If a note conceals a larger defect, say that instead of executing it literally.** "Rename X to Y"
  when X and Y both collide with a third term already in the doc is a different problem than the one
  asked about; report it and recommend the fix that addresses it.
- **If the literal reading would over-apply, name the boundary and get it ratified.** "Remove every
  statement of this shape" usually has a class of exceptions the author didn't mean to catch. Propose
  the split; don't silently under-apply and don't silently over-apply.
- **A note that applies document-wide is a standing rule**, not a section note. Record it under
  Standing rules, apply it to every remaining stop, and sweep the closed ones at the close.

### 3. Draft

For any rewrite longer than a phrase, **show the replacement text and get approval before writing
it.** Replacement text follows the cold-read writing rules. Mechanical substitutions — a term swap,
a heading rename — skip this beat and go straight to writing.

If the author asks for tightening, tighten and re-show. Don't defend the previous draft.

### 4. Write and record

Apply the edits. Then, in the same turn:

- Check the anchors. Renaming a heading breaks every inbound link to it — grep for the old slug
  before renaming, not after. On GitHub, `/` and `&` are stripped but their surrounding spaces each
  become a hyphen, so `A / B` slugs to `a--b`; a slug function that collapses whitespace will report
  false breakage.
- Mark the stop closed in the ledger with one line on what was decided.
- **Append to Carry-forward any edit that landed outside this stop.** This is the whole reason the
  ledger exists. When the walk reaches that section, its carry-forwards get stated as already settled
  before anything else.

Then advance to the next stop's beat 1 — unless the author has said to pause, in which case the
ledger is current and the walk can resume cold.

## Rules that bind the whole walk

- **One stop at a time.** Never present two sections in a turn, never edit a section you haven't
  presented.
- **Never edit outside the current stop** except to apply a standing rule or to fix an anchor the
  current stop's edit broke. Anything else goes to Carry-forward.
- **Scope stays where the author put it.** A defect you notice three sections ahead goes to
  Carry-forward under that stop; mention it to the author once, then let the ledger carry it.
- **The author's notes are the agenda.** Your initial thoughts open the conversation; theirs close it.
  If they skip a finding of yours, it's dropped, not re-raised.

## The close

After the last stop:

1. **Sweep the standing rules** over every section closed before that rule existed. A rule raised at
   stop 9 has nine sections behind it that never saw it.
2. **Verify the document structurally**: fence count is even, every internal anchor resolves, no
   local-path links if the doc is destined for somewhere the paths won't work, tables have consistent
   column counts, no line runs absurdly long against the doc's own wrap width.
3. **Report** the stops walked, the count of edits, the verification result, and — separately — any
   decision you made that the author didn't explicitly rule on, plus anything you deliberately left
   alone. Those two lists are the ones they can't reconstruct themselves.
4. Leave the ledger in place. It's the record of why the document reads the way it does.

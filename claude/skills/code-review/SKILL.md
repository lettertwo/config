---
name: code-review
description:
  Review the changes since a fixed point (commit, branch, tag, or merge-base): several independent
  reviewers — Claude subagents plus Cursor's CLI — examine the identical prompt in parallel, then a
  judge pass cross-references and verifies every finding before it's reported. Use when the user
  wants to review a branch, a PR, work-in-progress changes, or asks to "review since X".
argument-hint: "[low|medium|high|max] [--fix]"
---

Review of the diff between `HEAD` and a fixed point the user supplies, judged by cross-referencing
several independent reviewers rather than trusting any one of them:

- **Reviewers** — one or more Claude subagents plus `cursor-agent` (Cursor's CLI), all given the
  identical review prompt so their findings can be compared rather than blended.
- **Judge** (this session, main thread) — compiles and deduplicates every finding first, only then
  reads the actual source to verify each one, and reports a single ranked list.

**Effort gates the reviewer set** (count, tier mix, recall) — that's the cost lever:

| effort             | reviewers                                                                        |
| ------------------ | -------------------------------------------------------------------------------- |
| `low`              | 1 Claude subagent (no cross-reference; judge verifies directly)                  |
| `medium`           | 1 Claude subagent + `cursor-agent`                                               |
| `high` _(default)_ | 2 Claude subagents (sonnet + opus) + `cursor-agent`                              |
| `max`              | 2 Claude subagents (fable + opus) + `cursor-agent`, higher-recall prompt variant |

When a row calls for multiple Claude subagents, give each a **different model tier** (the `Agent`
tool's `model` param) — identical models share blind spots, so same-model agreement is nearly
worthless as a signal; different tiers are cheap, partially-decorrelated reviewers.

**Arguments:**

- `effort` (optional, default `high`): `low` | `medium` | `high` | `max`.
- `--fix`: apply and commit each CONFIRMED finding that carries a concrete fix as one
  `fix: <specific>` commit, then gate on tests. Default is report-only. (Spec gaps and much
  correctness feedback are missing work, not local edits — those fall through unfixed.)

The issue tracker should have been provided to you — run `/setup-tracking` if
`docs/agents/issue-tracker.md` is missing.

## Process

### 1. Pin the fixed point

Whatever the user said is the fixed point — a commit SHA, branch name, tag, `main`, `HEAD~5`, etc.
If they didn't specify one, ask for it.

Confirm it resolves and the diff is non-empty **before** launching any reviewer — a bad ref or empty
diff should fail here, not inside a subagent:

```bash
git rev-parse <fixed-point>
git diff --stat <fixed-point>...HEAD    # three-dot: compares against the merge-base
git log <fixed-point>..HEAD --oneline
```

### 2. Resolve context

**Spec source** — look for the originating spec, in this order, and stop at the first hit:

1. Issue references in the commit messages (`#123`, `Closes #45`, GitLab `!67`, etc.) — fetch via
   the procedure in `docs/agents/issue-tracker.md`.
2. A path the user passed as an argument.
3. A PRD/spec file under `docs/`, `specs/`, or `.scratch/` matching the branch name or feature.

If none resolves, proceed without one — don't ask the user and don't block. Spec conformance simply
isn't a category in this run's prompt.

**Standards docs** — collect the absolute paths of anything in the repo that documents how code
should be written: `CLAUDE.md`, `CODING_STANDARDS.md`, `CONTRIBUTING.md`, etc. Their contents get
embedded in the prompt below, not just referenced.

### 3. Build the shared review prompt

Construct one `REVIEW_PROMPT` and reuse it **byte-identical** across every reviewer this run
launches — that's what makes their findings comparable rather than artifacts of prompt phrasing.
Embed:

- The diff itself (`git diff <fixed-point>...HEAD`), plus branch/commit metadata (fixed point, HEAD,
  `git log` summary).
- The full text of every standards doc found in step 2.
- The spec text, if a spec source resolved.

Categories, in order of importance — a reviewer works top-down and a finding higher on this list
outweighs one lower down:

1. **Functional bugs** (most important) — logic errors, missing guards/awaits, races, stale
   closures, bad hook deps, off-by-ones, wrong variable usage, broken control flow: anything that
   simply won't work as intended.
2. **Repo-standards violations, KISS, DRY** — violations of the embedded standards docs, overly
   complex solutions where simpler ones exist, duplicated logic that should be extracted.
3. **Missing tests** — new functionality or bug fixes lacking coverage.
4. **Performance** — measure, don't guess: for a suspect query, run it (`EXPLAIN ANALYZE` or the
   stack's equivalent) rather than speculating about the planner; for application code, flag N+1s,
   missing batching, O(n²) loops on large inputs.
5. **Spec conformance** — only a category when spec text is present in the prompt: does the diff
   faithfully implement what was asked?
6. **Accessibility** — only a category when the diff touches UI markup: missing aria labels, heading
   hierarchy, alt text, keyboard navigation, color contrast.

Do not report: code formatting or style (lint's job), minor type nits (also linted), or nitpicks
that don't affect correctness or maintainability.

Each reviewer should return, per finding: file and line, severity (critical/high/medium/low),
category, description, and a concrete suggested fix where one exists.

At `max` effort, append a higher-recall instruction to the prompt (accept more borderline findings;
the judge's verify pass is the filter, not the reviewer's own judgment).

### 4. Launch reviewers in parallel

Per the effort table above, launch every reviewer for this run **at the same time**, all given the
identical `REVIEW_PROMPT`:

- **Claude subagents**: the `Agent` tool, `general-purpose`, with Bash/Read/Grep/Glob so each can
  investigate beyond the diff (trace a call site, check a test file). Set each one's `model` per the
  effort table — never two reviewers on the same tier.
- **`cursor-agent`**: write `REVIEW_PROMPT` to a randomly-suffixed temp file, then run
  non-interactively from the repo root:

  ```bash
  cursor-agent -p --mode plan --output-format text --model <model> "$(cat /tmp/review-prompt-<rand>.txt)"
  ```

  `--mode plan` is mandatory — it's read-only (analyze and propose, no edits or shell writes); bare
  `-p`/`--print` has full write and shell access. Pick `<model>` by running
  `cursor-agent --list-models` and choosing a non-Claude (prefer GPT) entry, so the diversity is
  real; if none resolves, drop `--model` and take the default. At `high` and `max`, pass reasoning
  effort through via the bracket override (e.g. `--model '<model>[effort=high]'`) if the chosen
  model's `--list-models` entry shows it's parameterized; otherwise run it plain.

  If `cursor-agent` is missing or errors, substitute one more Claude subagent at the next tier down
  from the lowest already in use — `medium`/`high` add haiku, `max` adds sonnet — and note the
  substitution in the final report.

### 5. Judge

You are the judge. Two rules, in this order, and not reversed:

1. **Compile and dedupe first.** Collect every finding from every reviewer into one list before
   reading any source code yourself. If you investigate first, you become a fourth reviewer with a
   veto over the other three — biased toward confirming your own read and dismissing theirs. This
   step is pure bookkeeping: group near-duplicate findings, note which reviewer(s) raised each one.
2. **Verify second.** Only now read the actual source around each finding, trace the logic, run the
   query/check a reviewer suggested. Mark each finding:
   - **CONFIRMED** — traced against the source and real.
   - **PLAUSIBLE** — couldn't be refuted, but couldn't be fully traced either (e.g., a runtime
     condition you can't reproduce locally).
   - **dismissed** — false positive, with a one-line reason.

   Don't dismiss a finding just because only one reviewer raised it — the lone dissenter sometimes
   caught the real bug the others missed. And weight agreement by reviewer independence: a match
   between Claude and `cursor-agent`'s non-Claude model is meaningful corroboration; a match between
   two Claude tiers is weaker (correlated errors); it never substitutes for the verify step.

### 6. Report

Call `ReportFindings` once with every CONFIRMED and PLAUSIBLE finding, ranked most-severe first,
each carrying its `verdict` (`CONFIRMED` or `PLAUSIBLE`) and `level` set to this run's effort.

Alongside the tool call, give a prose report:

- An agreement table — reviewer × confirmed finding — showing which reviewer(s) caught each one.
- The dismissed count, with each dismissal's one-line reason.
- A one-line merge recommendation: ready to merge, merge after fixes, or needs rework.

### 7. `--fix`

For each CONFIRMED finding with a concrete fix, apply it as one `fix: <specific>` commit. Then gate
on tests: `~/.claude/bin/cargo-gate test` for Rust workspaces, otherwise the project's own test
command. Re-call `ReportFindings` with an `outcome` per finding (fixed / skipped, with reason). If
the test gate fails, flag the run as "needs manual attention" in the report — the commits stay on
the branch; nothing auto-reverts.

## Why independent reviewers + a sequenced judge

A single reviewer's blind spots are invisible to itself — it can't catch what it isn't looking for.
Running several reviewers on the identical prompt surfaces disagreement, which is signal: an issue
every reviewer independently raises is more likely real than one only stated by the judge's own
first impression. But that only works if the judge stays a judge — reading the code before the
findings are in front of it turns it into a fourth, biased reviewer. Compiling first and verifying
second keeps the judge's one advantage (it alone gets to check against ground truth) without letting
that advantage curdle into a veto.

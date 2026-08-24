---
name: stack-review
description:
  Parallel code review (and optional autofix) of the current branch and every branch stacked upstack
  of it, each scoped to its own parent diff. Runs /code-review's reviewer-and-judge process once per
  branch over a Graphite stack. Use when you want to review (and optionally fix) the current branch
  and its stack. Pass --upstack to skip the current branch and review only descendants.
argument-hint: "[low|medium|high|max] [--upstack] [--fix]"
disable-model-invocation: true
---

Review the current branch and every branch stacked upstack of it. Each branch is reviewed against
its immediate Graphite parent so already-reviewed downstack changes don't reappear as noise.

**This skill is the stack driver for `/code-review`.** It does not define its own review model — the
shared review prompt, the effort→reviewer-set table, and the judge's compile-then-verify rules all
live in [`../code-review/SKILL.md`](../code-review/SKILL.md), which this skill follows once per
branch. Everything here is the stack-specific layer: discovery, worktrees, and the dependent-stack
serialization the single-diff caller doesn't need. If you want to understand what a finding means or
how many reviewers run at a given effort, read `/code-review`.

**Arguments:**

- `effort` (optional, default `medium` — cost scales with branch count): `low` | `medium` | `high` |
  `max`.
- `--upstack`: review only the branches stacked upstack; exclude the current branch.
- `--fix`: apply and commit each CONFIRMED finding as one `fix: <specific>` commit. Default is
  report-only.

---

## Steps

### 0. Preflight

Run in sequence; stop with a clear error message if any check fails.

**a. Require Graphite:**

```bash
command -v gt || { echo "stack-review requires Graphite (gt). Install from https://graphite.dev."; exit 1; }
gt log short 2>&1 | grep -q '\.' || { echo "stack-review: this repo is not tracked by Graphite. Run 'gt init' first."; exit 1; }
```

**b. Detect default branch and guard against reviewing it:**

```bash
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
[ "$CURRENT_BRANCH" = "$DEFAULT_BRANCH" ] && { echo "stack-review: current branch is the default branch ($DEFAULT_BRANCH); nothing to review. Checkout a feature branch first."; exit 1; }
```

**c. Detect repo layout** from `git worktree list --porcelain`:

- If the first entry contains `bare` → **bare+worktree layout** → review worktrees go as siblings of
  the current working tree: `$(dirname $(pwd))/review-<slug>`.
- Otherwise → **normal clone** → review worktrees go under the git common dir:
  `$(git rev-parse --git-common-dir)/stack-review/<slug>`.

**d. Build the existing-worktree map** (branch → path) from the same output — used in step 2.

```bash
git worktree list --porcelain
```

---

### 1. Discover the stack

Follow [`./DISCOVERY.md`](./DISCOVERY.md) — the shared read-only procedure (MCP-preferred, `gt`-BFS
fallback, default-branch filter) that yields the target branches and their parent→child edges. Its
§1 checks are already covered by preflight steps a–b above; skip them.

By default, also prepend the current branch (diff base = `gt parent`). If `--upstack`, skip the
current branch and include only the descendants.

From the parent→child edges, classify:

- **Independent**: no target is an ancestor of another — fixes can parallelize.
- **Dependent**: a target is the parent of another target — fixes must serialize with restack.

---

### 2. Resolve a worktree per target branch

For each target:

1. Check the existing-worktree map from step 0c.
2. Already checked out → **reuse** that path (`userOwned: true`). Don't call `git worktree add`.
3. Not checked out → create at the path from step 0b (`userOwned: false`).

```bash
git worktree add <computed-path> <branch>
```

Track which worktrees you created (only those get removed in step 5).

Build the final list: `[{branch, parent, worktree, label, userOwned}]`.

For each branch also resolve, the way `/code-review` step 2 does:

- **standardsSources**: absolute paths of the standards docs in that branch's worktree
  (`<worktree>/CLAUDE.md`, `<worktree>/frontend/CLAUDE.md`, `CODING_STANDARDS.md`, etc. — only those
  that exist).
- **specSource**: the originating spec for _that branch_, from its own commit messages (issue refs
  via `docs/agents/issue-tracker.md`). Most stack branches won't map cleanly to a spec — leave it
  unresolved and spec conformance is simply not a category for that branch's prompt. Don't force one
  spec across the whole stack.
- **descendants**: the branch names stacked upstack of this one (for the `mayBeAddressedUpstack`
  annotation below).

---

### 3. Parallel review — one shared prompt per branch, one batch of reviewers

For each target branch, build that branch's `REVIEW_PROMPT` the same way `/code-review` steps 2–3 do
(referenced, not duplicated here): that branch's diff (`base...branch` in its worktree), its own
`standardsSources`, and its own `specSource` if one resolved.

Launch reviewers for **all branches at once**, as a single parallel batch rather than branch by
branch:

- All branches' Claude reviewers go out together as one batch of `Agent` tool calls (one or more per
  branch, per the effort→reviewer-set table in `/code-review` — default effort here is `medium`).
- Run `cursor-agent` once per branch, same invocation `/code-review` step 4 specifies (`--mode plan`
  mandatory).

### 4. Judge each branch

Judge each branch independently, on the main thread, following the same two-step rule from
`/code-review` step 5: compile and dedupe that branch's findings before reading any of its source,
then verify each one (CONFIRMED / PLAUSIBLE / dismissed).

While verifying, apply the stack-only annotation: if a CONFIRMED or PLAUSIBLE finding is in a file
that a descendant branch (from `descendants` in step 2) also touches, mark it
`mayBeAddressedUpstack: true` — the fix may already be superseded further up the stack.

---

### 5. Report

Call `ReportFindings` **once**, covering every branch, each finding's `summary` prefixed
`[<branch>]`, ranked most-severe first within the whole set, each with its `verdict` and `level`
(effort).

Alongside, keep the per-branch prose sections:

```
### <branch> (N confirmed, M plausible, K dismissed)
1. **<title>** (<severity>, <verdict>)
   <description>
   File: `<file>` lines <lines>
   [Note: may be addressed upstack in `<branch>`]  ← only when mayBeAddressedUpstack is set
```

#### `--fix` on independent targets

Apply each branch's CONFIRMED findings with a concrete fix as `fix: <specific>` commits directly in
that branch's worktree, then gate on tests (`~/.claude/bin/cargo-gate test` for Rust workspaces, the
project's own test command otherwise). If a branch's test gate fails, do **not** report that
branch's fixes as clean — surface it under "Needs manual attention" with the gate's summary; the
commits are already on the branch (nothing auto-reverts) but need a human look before landing.

#### `--fix` on dependent targets

Apply fixes serially, bottom-up, using each branch's CONFIRMED findings only — those with a concrete
fix (spec gaps usually have none; skip them):

For each branch in topological order (parent before child):

1. If the branch's worktree is user-owned with uncommitted changes → skip it and all descendants;
   record reason.
2. If the branch is in a user-owned worktree → cannot run `gt restack` through it. Surface for
   manual resolution and stop the chain.
3. Otherwise: apply each finding's fix, commit it (`fix: <specific>`), then run:
   ```bash
   gt restack --cwd <worktree>
   ```
4. If `gt restack` conflicts → stop the chain, report conflict for manual resolution.
5. After a successful restack, run the test gate: `~/.claude/bin/cargo-gate test` for Rust
   workspaces (via the nearest `Cargo.toml`/workspace root), otherwise the project's own test
   command. A gate failure doesn't block the chain (dependent stacks must keep serializing) but gets
   flagged under "Needs manual attention" in the final report.

Re-call `ReportFindings` with an `outcome` per finding once `--fix` has run.

---

### 6. Clean up

Remove only the worktrees **you created** (`userOwned: false`):

```bash
git worktree remove <path>
```

Never touch user-owned worktrees. Commits persist on the branch refs after removal.

Print final summary:

```
## Stack review summary

Stack: <current-branch> → [<branch1>, <branch2>, ...]
Layout: bare+worktree | normal clone

### <branch> (N findings, M fixed, K skipped/manual)
- Fixed: <sha> fix: <message>
- Skipped: <title> — <reason>

### Needs manual attention:
- <branch>: <reason>
```

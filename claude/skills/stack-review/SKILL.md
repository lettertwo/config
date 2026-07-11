---
name: stack-review
description: Parallel code review (and optional autofix) of the current branch and every branch stacked upstack of it, each scoped to its own parent diff. Mirrors /code-review but operates over a Graphite stack. Use when you want to review (and optionally fix) the current branch and its stack. Pass --upstack to skip the current branch and review only descendants.
argument-hint: "[low|medium|high|max] [--upstack] [--fix] [--comment]"
---

Review the current branch and every branch stacked upstack of it. Each branch is reviewed against its immediate Graphite parent so already-reviewed downstack changes don't reappear as noise.

**Arguments:**
- `effort` (optional, default `medium`): `low` | `medium` | `high` | `max`
- `--upstack`: review only the branches stacked upstack; exclude the current branch.
- `--fix`: apply and commit each confirmed finding as one `fix: <specific>` commit. Default is report-only.
- `--comment`: post findings as a review comment on each branch's GitHub PR (via `gh`).

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
- If the first entry contains `bare` → **bare+worktree layout** → review worktrees go as siblings of the current working tree: `$(dirname $(pwd))/review-<slug>`.
- Otherwise → **normal clone** → review worktrees go under the git common dir: `$(git rev-parse --git-common-dir)/stack-review/<slug>`.

**d. Build the existing-worktree map** (branch → path) from the same output — used in step 2.

```bash
git worktree list --porcelain
```

---

### 1. Discover the stack

Prefer the `gt` MCP server (registered user-wide, deferred-loaded — see `ToolSearch` for `mcp__gt__*` tools) for structured stack state if it's available in this session. **CLI fallback** (current implementation — used whenever the MCP tools aren't loaded or the query shape isn't covered yet): BFS from the current branch using `gt children` (and `--cwd` to avoid interactive checkout):

```bash
gt children                          # direct children of current branch
gt children --cwd <worktree-for-B>  # children of B once its worktree is resolved
gt parent --cwd <worktree-for-B>    # B's parent (diff base)
```

Collect all descendants. By default, also prepend the current branch (diff base = `gt parent`). If `--upstack`, skip the current branch and include only the descendants.

Filter out any branch whose name matches `DEFAULT_BRANCH` (from preflight step b) — it should never appear, but guards against a misconfigured Graphite repo.

Record parent→child edges and classify:
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

---

### 3. Parallel review — Workflow

Read [./workflow.js](./workflow.js) and pass its contents inline to the Workflow tool, with:

```json
{
  "branches": [ ...list from step 2... ],
  "flags": { "fix": <bool>, "comment": <bool> },
  "effort": "<effort arg>",
  "dependentStack": <bool>
}
```

The workflow runs one review agent per branch in parallel, each diffing against its immediate parent, then an independent adversarial-verify agent that tries to refute each finding before it counts (cuts false positives reaching the report or an autofix commit). When `flags.fix` is true and `dependentStack` is false, it also runs a parallel fix stage on the confirmed findings, followed by a test gate (`cargo-gate test` for Rust workspaces, the project's own test command otherwise) before a branch's fixes are reported clean. When `dependentStack` is true, the workflow reviews and verifies only — fixes are handled in step 4 below.

Resume: the Workflow tool journals every `agent()` call, so an interrupted run can resume from `/workflows` without re-running completed review/verify/fix agents.

---

### 4. Act on results

#### Default: print findings

For each branch:

```
### <branch>

N finding(s) (M rejected on verify):

1. **<title>** (`<kind>`, confidence <N>)
   <description>
   File: `<file>` lines <lines>
   [Note: may be addressed upstack in `<branch>`]
```

Only confirmed (post-verify) findings are numbered and reported. If the workflow rejected any candidate findings during adversarial verify, note the count — don't list them individually unless asked; they were false positives caught before they reached you.

#### `--comment`: post PR comments

Read [./comment-format.md](./comment-format.md) for the exact format and link rules.

For each branch: `gh pr view <branch> --json number` to find the PR. Skip branches with no open PR (note them). Post via `gh pr comment <number>`.

#### `--fix` on independent targets

Handled inside the workflow (stage 3). Collect `applied` / `skipped` per branch from the results and include in the report. If a branch's `testGate.ran` is true and `testGate.passed` is false, do **not** report that branch's fixes as clean — surface it under "Needs manual attention" with the gate's summary; the commits are already on the branch (nothing auto-reverts) but they need a human look before landing.

#### `--fix` on dependent targets

The workflow only ran review + verify. Apply fixes serially, bottom-up, using confirmed findings only:

For each branch in topological order (parent before child):
1. If the branch's worktree is user-owned with uncommitted changes → skip it and all descendants; record reason.
2. If the branch is in a user-owned worktree → cannot run `gt restack` through it. Surface for manual resolution and stop the chain.
3. Otherwise: apply each finding's fix, commit it (`fix: <specific>`), then run:
   ```bash
   gt restack --cwd <worktree>
   ```
4. If `gt restack` conflicts → stop the chain, report conflict for manual resolution.
5. After a successful restack, run the test gate the same way the workflow's Fix stage does: `~/.claude/bin/cargo-gate test` for Rust workspaces (via the nearest `Cargo.toml`/workspace root), otherwise the project's own test command. A gate failure doesn't block the chain (dependent stacks must keep serializing) but gets flagged under "Needs manual attention" in the final report.

---

### 5. Report and clean up

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

If `--comment`, note which PRs received comments and which branches had no PR.

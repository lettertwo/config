---
name: stack-review
description: Parallel code review (and optional autofix) of the current branch and every branch stacked upstack of it, each scoped to its own parent diff. Runs /code-review's shared workflow once per branch over a Graphite stack. Use when you want to review (and optionally fix) the current branch and its stack. Pass --upstack to skip the current branch and review only descendants.
argument-hint: "[low|medium|high|max] [--upstack] [--fix]"
---

Review the current branch and every branch stacked upstack of it. Each branch is reviewed against its immediate Graphite parent so already-reviewed downstack changes don't reappear as noise.

**This skill is the stack driver for `/code-review`.** It does not define its own review model — the multi-axis (Correctness + Standards + Spec) review, the effort→axes gating, the smell baseline, adversarial verify, and the fix/test-gate loop all live in [`../code-review/workflow.js`](../code-review/workflow.js), which this skill invokes with one *review unit per branch*. Everything here is the stack-specific layer: discovery, worktrees, and the dependent-stack serialization the single-diff caller doesn't need. If you want to understand what a finding means or which axes run at a given effort, read `/code-review`.

At this skill's default `medium` effort the axes are **Correctness + Standards** (Spec is off below `high`, and stack branches rarely resolve a spec anyway). Raise to `high` if you want Spec-conformance checked per branch.

**Arguments:**
- `effort` (optional, default `medium`): `low` | `medium` | `high` | `max`
- `--upstack`: review only the branches stacked upstack; exclude the current branch.
- `--fix`: apply and commit each confirmed finding as one `fix: <specific>` commit. Default is report-only.

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

For each branch also resolve, the way `/code-review` steps 2–3 do:
- **standardsSources**: absolute paths of the standards docs in that branch's worktree (`<worktree>/CLAUDE.md`, `<worktree>/frontend/CLAUDE.md`, `CODING_STANDARDS.md`, etc. — only those that exist).
- **specSource**: the originating spec for *that branch*, from its own commit messages (issue refs via `docs/agents/issue-tracker.md`). Most stack branches won't map cleanly to a spec — pass `null` and the Spec axis is skipped for that branch. Don't force one spec across the whole stack.
- **descendants**: the branch names stacked upstack of this one (for `mayBeAddressedUpstack` annotation).

---

### 3. Parallel review — the shared /code-review workflow

Read [`../code-review/workflow.js`](../code-review/workflow.js) — the *same* file `/code-review` runs — and pass its contents inline to the Workflow tool, building **one unit per target branch**:

```json
{
  "units": [{
    "label": "<branch>",
    "worktree": "<worktree>",
    "base": "<parent branch>",
    "head": "<branch>",
    "standardsSources": ["<abs path>", "..."],
    "specSource": null,
    "descendants": ["<upstack branch>", "..."],
    "userOwned": <bool>
  }],
  "flags": { "fix": <bool> },
  "effort": "<effort arg>",
  "dependentStack": <bool>
}
```

Per unit the workflow diffs `base...branch`, runs the effort-gated axes (Correctness always; Standards at `medium`+; Spec at `high`+ when `specSource` resolves) in parallel, adversarially verifies every finding, and — when `flags.fix` is true and `dependentStack` is false — applies confirmed fixes with a test gate (`cargo-gate test` for Rust workspaces, the project's own test command otherwise) before reporting a branch clean. When `dependentStack` is true, the workflow reviews and verifies only; fixes are handled serially in step 4 below.

Resume: the Workflow tool journals every `agent()` call, so an interrupted run can resume from `/workflows` without re-running completed review/verify/fix agents.

---

### 4. Act on results

#### Default: print findings

Each result carries `axesRun` plus `correctness`, `standards` (or `null`), and `spec` (or `null`) finding arrays, and `rejected`. Per branch, report each axis that ran separately — same as `/code-review`, don't rerank across them:

```
### <branch>  (C correctness, S standards, P spec; M rejected on verify)

**Correctness**
1. **<title>** (`<kind>`, <severity>, confidence <N>)
   <description>
   File: `<file>` lines <lines>
   [Note: may be addressed upstack in `<branch>`]  ← only when mayBeAddressedUpstack is set

**Standards**
1. ...

**Spec**
1. ...
```

Only confirmed (post-verify) findings are numbered. A `null` axis array means that axis didn't run at this effort (Standards below `medium`, Spec below `high` or no spec source) — omit its heading rather than printing an empty one. If `rejected` is non-empty, note the count — don't list them individually unless asked; they were false positives caught before they reached you.

#### `--fix` on independent targets

Handled inside the workflow (stage 3). Collect `applied` / `skipped` per branch from the results and include in the report. If a branch's `testGate.ran` is true and `testGate.passed` is false, do **not** report that branch's fixes as clean — surface it under "Needs manual attention" with the gate's summary; the commits are already on the branch (nothing auto-reverts) but they need a human look before landing.

#### `--fix` on dependent targets

The workflow only ran review + verify. Apply fixes serially, bottom-up, using each branch's confirmed findings only — the combined `standards` + `spec` arrays, and only those with a concrete `suggestedFix` (spec gaps usually have none; skip them):

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

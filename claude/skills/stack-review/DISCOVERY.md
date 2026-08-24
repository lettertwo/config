# Graphite stack discovery

Read-only procedure for resolving the stack around the current branch: which branches are stacked,
and each branch's parent (its diff base). Consumed by `/stack-review` (which layers worktrees, fix
classification, and restack on top) and `/explain-diff` (which needs only the branches and edges).
Nothing here mutates the repo or checks anything out.

## 1. Confirm the repo is Graphite-tracked

```bash
command -v gt || { echo "requires Graphite (gt). Install from https://graphite.dev."; exit 1; }
gt log short 2>&1 | grep -q '\.' || { echo "this repo is not tracked by Graphite. Run 'gt init' first."; exit 1; }
```

Also resolve the default branch — it must never appear as a stack target:

```bash
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
```

## 2. Walk the stack

Prefer the `graphite` MCP server (registered user-wide, deferred-loaded — see `ToolSearch` for
`mcp__graphite__*` tools) for structured stack state if it's available in this session. **CLI
fallback** (used whenever the MCP tools aren't loaded or the query shape isn't covered yet): BFS
from the current branch using `gt children` (and `--cwd` to avoid interactive checkout):

```bash
gt children                          # direct children of current branch
gt children --cwd <path-for-B>       # children of B, queried from another path
gt parent --cwd <path-for-B>         # B's parent (diff base)
```

Collect all descendants. The caller decides whether the current branch itself is a target (e.g.
`/stack-review` includes it unless `--upstack`).

## 3. Filter and record

Drop any branch whose name matches `DEFAULT_BRANCH` — it should never appear, but this guards
against a misconfigured Graphite repo.

The result is the target branch list plus the parent→child edges. The edges are what downstream
consumers order by: bottom-up chapters for an explanation, topological fix order for a review.

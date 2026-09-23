# Stack discovery

Read-only procedure for resolving the stack around the current branch: which branches are stacked,
and each branch's parent (its diff base). Consumed by `/stack-review` (which layers worktrees, fix
classification, and restack on top) and `/explain-diff` (which needs only the branches and edges).
Nothing here mutates the repo or checks anything out.

Two backends are supported: Graphite (`gt`) and gh-stack (`gh stack`). Both produce the same
result shape (section 4), so consumers don't care which one answered.

## 1. Pick the backend

Resolve the default branch first. It must never appear as a stack target:

```bash
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
```

Then probe, Graphite first, gh-stack second:

```bash
if command -v gt >/dev/null && gt log short 2>&1 | grep -q '\.'; then
  BACKEND=graphite
elif gh extension list 2>/dev/null | grep -q 'github/gh-stack' && gh stack view --json >/dev/null 2>&1; then
  BACKEND=gh-stack
else
  echo "no stack found: the current branch is tracked by neither Graphite (gt) nor gh-stack (gh stack)."; exit 1
fi
```

`gh stack view --json` exits 2 when the current branch is not in a stack and 6 when it belongs to
more than one, so a non-zero exit is "not a gh-stack target from here" rather than "gh-stack is
absent". On exit 6 tell the user to check out a branch that belongs to only one stack.

If a repo is tracked by both tools, Graphite wins. I don't know of a repo where that happens; the
ordering is just so the probe is deterministic.

## 2a. Walk the stack: Graphite

BFS from the current branch using `gt children` (and `--cwd` to avoid interactive checkout):

```bash
gt children                          # direct children of current branch
gt children --cwd <path-for-B>       # children of B, queried from another path
gt parent --cwd <path-for-B>         # B's parent (diff base)
```

Collect all descendants. Graphite stacks may branch (one parent, several children), so the edges
form a tree.

## 2b. Walk the stack: gh-stack

One call returns the whole stack. **Always pass `--json`**: without it `gh stack view` opens a TUI
that hangs a non-interactive session.

```bash
STACK_JSON=$(gh stack view --json 2>/dev/null)
echo "$STACK_JSON" | jq -r '.trunk'                                   # the stack's base branch
echo "$STACK_JSON" | jq -r '.branches[].name'                         # bottom → top
echo "$STACK_JSON" | jq -r '.currentBranch'
```

gh-stack stacks are strictly linear and `branches` is ordered bottom (nearest trunk) to top, so
the parent of `branches[i]` is `branches[i-1]`, and the parent of `branches[0]` is `.trunk`.
Derive the edges from that ordering; the per-branch `base` field is a SHA (the parent's head at
last sync), not a branch name, so don't use it as the diff base.

Descendants of the current branch are the entries after `currentBranch` in the array. Branches
with `isMerged: true` are already on trunk; drop them unless the caller asks for merged layers,
since their diff against their parent is empty once trunk has moved.

`gh stack view` reads local tracking state but also refreshes PR metadata from GitHub, so it can
fail offline with exit 4. The branch list is still what you want; retry once, then surface it.

## 3. Filter

Drop any branch whose name matches `DEFAULT_BRANCH` (or, for gh-stack, `.trunk`). It should never
appear, but this guards against a misconfigured stack.

The caller decides whether the current branch itself is a target (e.g. `/stack-review` includes it
unless `--upstack`).

## 4. Result

The target branch list plus the parent→child edges, and the current branch's own parent (its diff
base). The edges are what downstream consumers order by: bottom-up chapters for an explanation,
topological fix order for a review.

Consumers that go beyond discovery should check `BACKEND`: `/stack-review`'s restack step runs
`gt restack` on Graphite and `gh stack rebase` on gh-stack.

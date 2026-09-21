---
name: explain-diff
description: Explain a range, branch, PR, or stack of changes as an interactive HTML page.
disable-model-invocation: true
argument-hint: "[range, branch, PR, or stack]"
---

Build the page in [`../explain/EXPLAINING.md`](../explain/EXPLAINING.md) for a code change.

## Resolve the target

The user names a range, branch, PR, or stack. Resolve it to a concrete `base...head` range; ask if
it's ambiguous. Confirm the ref resolves and the diff is non-empty before reading anything else, so
a bad ref or empty diff fails here:

```bash
git rev-parse <base>
git diff --stat <base>...HEAD    # three-dot: compares against the merge-base
git log <base>..HEAD --oneline
```

**Stack-aware branch**: if the current branch is in a Graphite or gh-stack stack and the target is
a stack (the user asks for one explicitly, or the resolved ref spans multiple stacked branches),
discover the branches and their parent→child edges by following
[`../stack-review/DISCOVERY.md`](../stack-review/DISCOVERY.md) (read-only; no worktrees or
checkouts needed). Otherwise this is a single-diff explanation.

## Page structure

**Single diff**: the flat section list in `EXPLAINING.md`. Decisions come from commit messages and
the PR body where they record any.

**Stack**: bottom-up chapters, one per branch in dependency order, each with its own Intuition and
Walkthrough scoped to that branch's diff against its parent. One shared Background covers the
whole stack. Add a reusable stack diagram showing which branch introduces what. The quiz spans the
whole stack rather than any single branch.

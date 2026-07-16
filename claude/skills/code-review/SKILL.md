---
name: code-review
description: Review the changes since a fixed point (commit, branch, tag, or merge-base) along up to three axes — Correctness (real runtime defects), Standards (does the code follow this repo's documented coding standards?), and Spec (does the code match what the originating issue/PRD asked for?). Runs the axes as parallel, adversarially-verified sub-agents via the Workflow tool and reports them side by side. Use when the user wants to review a branch, a PR, work-in-progress changes, or asks to "review since X".
argument-hint: "[low|medium|high|max] [--fix]"
---

Multi-axis review of the diff between `HEAD` and a fixed point the user supplies:

- **Correctness** — real runtime defects: logic errors, missing guards/awaits, races, stale closures, bad hook deps, plus genuine efficiency problems on hot paths.
- **Standards** — does the code conform to this repo's documented coding standards (plus a fixed Fowler smell baseline)?
- **Spec** — does the code faithfully implement the originating issue / PRD / spec?

The review runs through [`./workflow.js`](./workflow.js) on the **Workflow tool**: per review unit it spawns one sub-agent per active axis in parallel (so the axes don't pollute each other's context), then a single independent adversarial-verify agent that tries to refute every finding before it counts. `/stack-review` drives the *same* workflow over a whole Graphite stack — this skill is the single-diff caller.

**Effort gates which axes run** — that's the cost lever. Correctness is the floor; Standards and Spec layer on with effort. The verify pass batches all findings into one agent, so it never multiplies with axis count.

| effort | axes |
|---|---|
| `low` | Correctness |
| `medium` | Correctness + Standards |
| `high` *(default here)* | Correctness + Standards + Spec |
| `max` | all three, higher recall (accepts more noise) |

**Arguments:**
- `effort` (optional, default `high` — a single diff is cheap and Spec is the point of a code review): `low` | `medium` | `high` | `max`.
- `--fix`: apply and commit each confirmed finding that carries a concrete `suggestedFix` as one `fix: <specific>` commit, then gate on tests. Default is report-only. (Spec gaps and many correctness issues are missing work, not local edits — they fall through to `skipped`.)

The issue tracker should have been provided to you — run `/setup-tracking` if `docs/agents/issue-tracker.md` is missing.

## Process

### 1. Pin the fixed point

Whatever the user said is the fixed point — a commit SHA, branch name, tag, `main`, `HEAD~5`, etc. If they didn't specify one, ask for it.

Confirm it resolves and the diff is non-empty **before** launching the workflow — a bad ref or empty diff should fail here, not inside sub-agents:

```bash
git rev-parse <fixed-point>
git diff --stat <fixed-point>...HEAD    # three-dot: compares against the merge-base
git log <fixed-point>..HEAD --oneline
```

### 2. Identify the spec source

Look for the originating spec, in this order:

1. Issue references in the commit messages (`#123`, `Closes #45`, GitLab `!67`, etc.) — fetch via the workflow in `docs/agents/issue-tracker.md`.
2. A path the user passed as an argument.
3. A PRD/spec file under `docs/`, `specs/`, or `.scratch/` matching the branch name or feature.
4. If nothing is found, ask the user where the spec is. If they say there isn't one, the unit's `specSource` is `null` and the Spec axis is skipped (the report notes "no spec available").

(The Spec axis only runs at `high`/`max` effort *and* when a `specSource` resolves — so at `low`/`medium` you can skip this step.)

### 3. Identify the standards sources

List anything in the repo that documents how code should be written — `CODING_STANDARDS.md`, `CONTRIBUTING.md`, `CLAUDE.md`, etc. Collect their **absolute paths**; the workflow passes them to the Standards agent.

You do **not** need to paste the smell baseline — `workflow.js` embeds it (Fowler _Refactoring_ ch.3) so the Standards axis works even in a repo that documents nothing. The repo's own standards override the baseline where they conflict, and each baseline smell is a judgement call, never a hard violation.

### 4. Run the workflow

Read [`./workflow.js`](./workflow.js) and pass its contents inline to the Workflow tool with a **single unit**:

```json
{
  "units": [{
    "label": "HEAD",
    "worktree": "<repo root>",
    "base": "<fixed-point>",
    "head": "HEAD",
    "standardsSources": ["<abs path>", "..."],
    "specSource": { "path": "<abs path>" },
    "descendants": [],
    "userOwned": false
  }],
  "flags": { "fix": <bool> },
  "effort": "<effort arg>",
  "dependentStack": false
}
```

- `specSource`: pass `{ "path": ... }` (or `{ "contents": ... }` for a fetched issue body), or `null` to skip the Spec axis.
- `worktree` is the repo root (`git rev-parse --show-toplevel`).
- `descendants` is always `[]` here (this isn't a stacked review); `dependentStack` is always `false`.

### 5. Aggregate

The workflow returns `results[0]` with `axesRun`, `correctness`, `standards` (or `null`), `spec` (or `null`), `rejected`, and — if `--fix` ran — `applied` / `skipped` / `testGate`. Present each axis that ran under its own heading; do **not** merge or rerank across them (see _Why the axes are separate_):

```
## Correctness
1. **<title>** (`<kind>`, <severity>, confidence <N>)
   <description>
   File: `<file>` lines <lines>

## Standards
1. ...

## Spec
1. ...
```

A `null` array means the axis didn't run — say why: Standards below `medium`, Spec below `high`, or (for Spec) no spec source was found. An empty `[]` means the axis ran clean. If `rejected` is non-empty, note the count (adversarial verify caught these as false positives) — don't list them unless asked.

End with a one-line summary: total findings per axis, and the worst issue _within each axis_. Don't pick a single winner across axes — that's the reranking the separation exists to prevent.

If `--fix` ran, add a `## Fixes` section: the `fix:` commits applied and anything skipped with its reason. If `testGate.ran && !testGate.passed`, flag the branch for manual attention with the gate summary — the commits are on the branch (nothing auto-reverts) but need a human look before landing.

## Why the axes are separate

The three axes ask independent questions, and a change can pass one while failing another:

- **Correctness** — is the code *right*? (does what it does work?)
- **Standards** — is it *well-made*? (follows conventions, no smells?)
- **Spec** — is it *the right thing*? (matches what was asked?)

Code can be a clean, standard-following, spec-faithful implementation that still has a null-deref (Correctness fail). Code can be correct and standard-following but build the wrong feature (Spec fail). Running them as separate sub-agents — and reporting them separately — stops one axis from masking another, and keeps each agent's context focused on its own question.

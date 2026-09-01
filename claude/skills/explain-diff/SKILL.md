---
name: explain-diff
description:
  Produce a rich, interactive HTML explanation of a code change — background, intuition, a code
  walkthrough, and a comprehension quiz. Stack-aware: a Graphite or gh-stack stack becomes
  bottom-up chapters with a shared background and a stack-spanning quiz. Use when the user asks to
  explain a diff, branch, PR, or stack.
---

Build a self-contained HTML page that teaches a reader what a code change does and why, deep enough
that a five-question quiz at the end is actually hard to pass without having understood it.

## Resolve the target

The user names a diff, branch, PR, or stack. Resolve it to a concrete `base...head` range the same
way `/code-review` step 1 does (`git rev-parse`, three-dot diff, `git log`) — ask if it's ambiguous,
fail fast on a bad ref or empty diff.

**Stack-aware branch**: if the current branch is in a Graphite or gh-stack stack and the target is
a stack — the user asks for one explicitly, or the resolved ref spans multiple stacked branches —
discover the branches and their parent→child edges by following
[`../stack-review/DISCOVERY.md`](../stack-review/DISCOVERY.md) (read-only; no worktrees or
checkouts needed). Otherwise this is a single-diff explanation.

## Sections

- **Background**: explore the surrounding code broadly, then narrow. Don't assume how much the
  reader already knows — give deep background for beginners (callable out as skippable for anyone
  already familiar), then background narrow enough to sit directly next to the change.
- **Intuition**: the core idea behind the change, not its full mechanics. Concrete examples with toy
  data. Diagrams liberally.
- **Code walkthrough**: a high-level tour of the diff, changes grouped and ordered so the tour makes
  narrative sense rather than following file order.
- **Quiz**: five interactive multiple-choice questions, medium difficulty — hard enough that
  answering them requires having understood the substance of the change, not gotchas or trivia.
  Clicking an answer reveals whether it's correct and gives feedback.

**Stack target**: structure the page as bottom-up chapters, one per branch in dependency order, each
with its own Intuition and Code walkthrough scoped to that branch's diff against its parent. One
shared Background covers the whole stack. Add a reusable stack diagram showing which branch
introduces what. The quiz spans the whole stack rather than any single branch.

## Output

A single self-contained HTML file (CSS and JS inline, no external assets) at
`/tmp/YYYY-MM-DD-explanation-<slug>.html` — today's date first so files sort chronologically and
stay out of version control by living outside the repo. One long page with section headers and a
table of contents; no tabs for top-level structure. Basic responsive styling so it's readable on a
phone.

Write with the clarity of a good technical explainer: engaging, classic style, smooth transitions
between sections rather than abrupt headers with nothing bridging them.

**Diagrams**: pick a small number of reusable diagram families and reuse them across cases rather
than inventing a one-off per section — a simplified UI mockup for UI changes, a system diagram for
data flow between components (always with example data, never abstract boxes). No ASCII diagrams;
build them in HTML. Use HTML lists for lists of things.

**Code blocks**: always `<pre>` tags. A custom-styled div instead of `<pre>` must carry
`white-space: pre-wrap` in its CSS or the browser collapses every newline into one line. Before
saving the file, scan every code block in the generated HTML and confirm each has `white-space: pre`
or `pre-wrap`.

**Callouts** for key concepts, definitions, and important edge cases.

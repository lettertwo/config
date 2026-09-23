# Explanation page

Procedure for building a self-contained interactive HTML page that teaches a cold reader a subject.
Consumed by `/explain` (subject: the current thread) and `/explain-diff` (subject: a diff or
stack). The caller has already resolved the subject and gathered its material; this file turns it
into a page deep enough that the five-question quiz at the end is hard to pass without having
understood it. Where the caller prescribes a page structure (chapters for a stack, say), that
structure wins over the flat section list below.

## Sections

- **Background**: explore the surrounding code broadly, then narrow. Deep background for beginners
  first (called out as skippable), then background narrow enough to sit directly next to the
  subject.
- **Intuition**: the core idea, not the full mechanics. Concrete examples with toy data. Diagrams
  liberally.
- **Walkthrough**: a tour of the code, grouped and ordered so the tour makes narrative sense rather
  than following file order. Where code changed, show before and after; where it was only read,
  show what is there and what it is for.
- **Decisions**, when the subject carries any: one entry per decision. What was chosen, what was
  rejected, what settled it. Open questions listed last, with what would settle each.
- **Quiz**: five interactive multiple-choice questions, medium difficulty. Answering requires
  having understood the substance, not gotchas or trivia; when there is a Decisions section, at
  least one question asks why a decision went the way it did. Clicking an answer reveals whether
  it is correct and gives feedback.

## Output

A single self-contained HTML file (CSS and JS inline, no external assets) at
`.scratch/explain/YYYY-MM-DD-<slug>.html`, the slug naming the subject. Today's date first so files
sort chronologically and stay out of version control by living outside the repo. One long page
with section headers and a table of contents; no tabs for top-level structure. Basic responsive
styling so it's readable on a phone.

Write with the clarity of a good technical explainer: engaging, classic style, smooth transitions
between sections rather than abrupt headers with nothing bridging them.

**Diagrams**: pick a small number of reusable diagram families and reuse them across cases rather
than inventing a one-off per section: a simplified UI mockup for UI changes, a system diagram for
data flow between components (always with example data, never abstract boxes). No ASCII diagrams;
build them in HTML. Use HTML lists for lists of things.

**Code blocks**: always `<pre>` tags. A custom-styled div instead of `<pre>` must carry
`white-space: pre-wrap` in its CSS or the browser collapses every newline into one line. Before
saving the file, scan every code block in the generated HTML and confirm each has `white-space: pre`
or `pre-wrap`.

**Callouts** for key concepts, definitions, and important edge cases.

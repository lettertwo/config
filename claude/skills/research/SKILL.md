---
name: research
description: Investigate a question against high-trust primary sources and capture the findings as a Markdown file in the repo. Use when the user wants a topic researched, docs or API facts gathered, or reading legwork delegated to a background agent.
---

Before dispatch, resolve the output path yourself: if the repo already keeps research notes somewhere, match that convention; otherwise use `.scratch/research/<slug>.md`. Pass that path in the dispatch — the `researcher` agent (`subagent_type: researcher`) only writes a file when the dispatch names one.

Spin up the `researcher` agent so you keep working while it reads.

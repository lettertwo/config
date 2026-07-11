---
name: handoff
description: Compact the current conversation into a handoff document for another agent to pick up.
argument-hint: "What will the next session be used for?"
---

Write a handoff document summarising the current conversation so a fresh agent can continue the work.

Save to a deterministic per-project path: `<repo>/docs/handoffs/<date>-<slug>.md`, where `<repo>` is the current workspace root and `<date>` is `YYYY-MM-DD`. Before writing, check whether the project already has its own handoff convention (e.g. an existing `docs/handoffs/` directory with a different naming scheme, or a `HANDOFFS.md` index) — follow it instead of imposing this default if one is found. Never write to `/tmp` or another OS temp directory; "latest" must always resolve to newest mtime inside the project, not a scattered set of tmp files.

Include a "Gotchas" section and a "Verification gates" section with the exact commands the executor must run green before reporting done (test suite, lint, build). The executor won't inherit this session's context — the doc must carry the oracle, not assume it.

Include a "suggested skills" section in the document, which suggests skills that the agent should invoke.

**Pickup contract:** when this doc is later consumed (by `--dispatch` below, or by a fresh session picking it up manually), the consuming agent must echo back the Gotchas and Verification gates sections verbatim before acting on the plan — this proves consumption rather than a skim. A session has previously crashed on a bug its own handoff explicitly warned about because the warning was never actually read.

If the arguments include `--dispatch`, after writing the doc spawn the `implementer` agent against it in this session — instruct it to echo back Gotchas and Verification gates first. When the implementer returns, run the close on the main thread: run the verification gates, read the full diff, and report findings — the commit stays with the user. Without `--dispatch`, just write the doc.

Do not duplicate content already captured in other artifacts (PRDs, plans, ADRs, issues, commits, diffs). Reference them by path or URL instead.

Redact any sensitive information, such as API keys, passwords, or personally identifiable information.

If the user passed arguments, treat them as a description of what the next session will focus on and tailor the doc accordingly.

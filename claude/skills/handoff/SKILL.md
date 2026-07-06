---
name: handoff
description: Compact the current conversation into a handoff document for another agent to pick up.
argument-hint: "What will the next session be used for?"
---

Write a handoff document summarising the current conversation so a fresh agent can continue the work. Save to the temporary directory of the user's OS - not the current workspace.

Include a "suggested skills" section in the document, which suggests skills that the agent should invoke.

Include a "Verification gates" section with the exact commands the executor must run green before reporting done (test suite, lint, build). The executor won't inherit this session's context — the doc must carry the oracle, not assume it.

If the arguments include `--dispatch`, after writing the doc spawn the `implementer` agent against it in this session. When the implementer returns, run the close on the main thread: run the verification gates, read the full diff, and report findings — the commit stays with the user. Without `--dispatch`, just write the doc.

Do not duplicate content already captured in other artifacts (PRDs, plans, ADRs, issues, commits, diffs). Reference them by path or URL instead.

Redact any sensitive information, such as API keys, passwords, or personally identifiable information.

If the user passed arguments, treat them as a description of what the next session will focus on and tailor the doc accordingly.

---
name: explain
description: Explain the current subject of this conversation as an interactive HTML page.
disable-model-invocation: true
argument-hint: "[subject, to narrow or name it; defaults to what we're discussing]"
---

Build the page in [`EXPLAINING.md`](EXPLAINING.md) for the current subject of this thread.

`$ARGUMENTS`, if given, names or narrows the subject. Otherwise infer it from the thread: the
mechanism we read or changed, the decisions we made, and the reasoning that carried them. State the
inferred subject in one line, then build; the user redirects if it is wrong.

Gather before building:

- Every file and code path the thread read, touched, or argued about. Re-read the current state on
  disk rather than quoting from memory; the thread may have moved past what you recall.
- Every decision the thread made, with the alternative it rejected and the fact that tipped it.
  Unresolved questions are content too: name them as open.

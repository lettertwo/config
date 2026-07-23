---
name: sparring
description: Spar with the user relentlessly about a plan, decision, or idea. Use when the user wants to stress-test their thinking, or uses any 'spar' trigger phrases.
---

Interview me relentlessly about every aspect of this until we reach a shared understanding. Walk down each branch of the decision tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

Ask the questions one at a time, waiting for feedback on each question before continuing. Asking multiple questions at once is bewildering.

When the current question is a bounded decision with a small candidate set (pick a library, a boundary, an A-vs-B tradeoff, a config value), use the AskUserQuestion tool: put your recommended option first, labelled `(Recommended)`, and keep it to one decision per call. Stay free-form for open probes and challenges ("why do you believe that?", "what breaks when…?", "that contradicts X") — those have no enumerable answers, and forcing options onto them would suppress the most valuable response, "none of these; the premise is wrong."

When a bounded decision hinges on comparing concrete artifacts — competing code snippets, config blocks, or UI layouts — put each candidate in the option's `preview` field so they render side-by-side for comparison.

Never combine substantial new evidence with an AskUserQuestion call in the same turn — the dialog preempts reading. Present the analysis, end the turn, and pose the bounded question only after I've had a chance to react.

If a *fact* can be found by exploring the environment (filesystem, tools, etc.), look it up rather than asking me. The *decisions*, though, are mine — put each one to me and wait for my answer.

Do not act on it until I confirm we have reached a shared understanding.

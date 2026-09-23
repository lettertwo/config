---
name: spar
description: Spar with the user relentlessly about a plan, decision, or idea. Use when the user wants to stress-test their thinking, or uses any 'spar' trigger phrases.
---

Interview me relentlessly about every aspect of this until we reach a shared understanding. Walk down each branch of the decision tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

Ask the questions one at a time, waiting for feedback on each question before continuing. Asking multiple questions at once is bewildering.

Stay free-form for open probes and challenges ("why do you believe that?", "what breaks when…?", "that contradicts X") — those have no enumerable answers, and forcing options onto them would suppress the most valuable response, "none of these; the premise is wrong."

Never combine substantial new evidence with an AskUserQuestion call in the same turn — the dialog preempts reading. Present the analysis, end the turn, and pose the bounded question only after I've had a chance to react.

The decisions are mine — put each one to me and wait for my answer.

Do not act on it until I confirm we have reached a shared understanding.

When plan mode is active, the plan file is the only file you can edit: write the resolved decisions there as we go, and treat `ExitPlanMode` as the shared-understanding confirmation this skill is waiting for.

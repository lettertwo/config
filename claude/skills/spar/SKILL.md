---
name: spar
description: Spar with the user relentlessly about a plan, decision, or idea. Use when the user wants to stress-test their thinking, or uses any 'spar' trigger phrases.
---

Interview me relentlessly about every aspect of this until we reach a shared understanding. Walk down each branch of the decision tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

Pose every question with `AskUserQuestion`, the recommended option first. Batch independent decisions into one dialog, up to four. A decision whose options or recommendation depend on another answer waits for that answer, since asking it early makes me answer on a guess.

Open probes ("why do you believe that?", "what breaks when…?", "that contradicts X") go through the dialog too: offer the two or three likeliest answers plus an explicit "the premise is wrong" option. The automatic Other choice covers the rest.

A turn that brings substantial new evidence ends with a question about the evidence itself: does it match what I know, and what is off. Decisions that rest on the evidence wait for the next turn, because a dialog asking for a decision pulls attention away from the analysis above it.

End every turn with a question, a final verdict, or the artifact.

The decisions are mine: put each one to me and wait for my answer.

Do not act on it until I confirm we have reached a shared understanding.

When the interview resolves design headed for the `implementer`, the artifact is a plan: call `EnterPlanMode`, write the resolved decisions to the plan file it names, and treat `ExitPlanMode` as the shared-understanding confirmation. Otherwise the artifact is whatever the calling skill names, such as a `/wayfinder` ticket answer or an ADR.

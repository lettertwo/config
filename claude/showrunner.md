# Showrunner

You are the main thread — the showrunner: resolve design with me, do the work or delegate it, synthesize results, own the close. This policy loads only on the main thread; subagents never see it.

## First move

- **Work that fits in one session** → resolve the open decisions with me in conversation (`/spar` when the design has real branches), then do the work on the main thread: act, show me what changed, adjust. No plan file and no plan mode unless I ask for one.
- **Dispatch `implementer`** when the work splits into independent slices worth running in parallel, or when the main context is getting heavy. It inherits nothing, so hand it the decisions, the gotchas, and how to verify; past a paragraph, write them to `.scratch/plans/<slug>.md` with `## Gotchas` and `## Verification` sections and dispatch against that path.
- **Work that outlasts one session** → a `/wayfinder` map for a run of open decisions, or `/handoff` at a stopping point. A handoff, or a ticket carrying acceptance criteria and a file list, is a plan artifact: dispatch `implementer` against it and let it fetch the ticket. When I name no handoff, take the newest-mtime one in the project's `.scratch/handoffs/` (deterministic pickup, never a judgment call).
- Whenever `implementer` runs against an artifact, check that its first message echoes the Gotchas and Verification sections before it starts editing; that's the proof it read them.

## Delegation

- The reading ahead of an interview (how the mechanism works, what each candidate touches, a draft file list) → `planner`, not the built-in `Plan` agent, which makes the decisions the interview owns.
- **Keep working while a dispatch runs.** Spend the wait on independent work: the next unit's interview, the close for landed work, a `researcher` question.

## The close (yours, always)

- Gates green, then read the full diff yourself. Delegated work isn't done until it lands.
- **Prove, don't rerun.** The implementer's final gate run and yours are the same command on the same tree; the rebuild and link is the cost, so run it once. On a Rust workspace ask `~/.claude/bin/cargo-gate proven test <crate>...` and `proven clippy` for the changed crates and rerun only what it rejects (its fingerprint moves with the tree, so a close-out edit to code invalidates the proof on its own). Elsewhere accept the implementer's verbatim output when the command was the full gate and no edit followed it; check the order in the agent transcript rather than the prose. Rerun when the output is missing or summarized, the run was filtered, or the tree changed.
- **Voice gate on prose artifacts.** Run `~/.claude/bin/voice-lint` before anything with a reader lands: `voice-lint --pr <file>` for a PR body, plain `voice-lint <file>` for handoff docs, ADRs, plan files, and review comments. `VOICE_LINT=0` skips one run, and `git config voice.lint false` opts a whole repo out, which is the answer for a work repo whose commit conventions are not mine.
- No `/code-review` by default. Invoke it at high effort only for invariant-heavy or gotcha-dense diffs, or when I ask.
- A commit is the bisect/checkpoint unit (green, tested, single message).
- A changeset (branch) is the review/land/revert unit — one decision plus its mechanical consequences. Split only when a unit passes both tests: **land-alone** (coherent and valuable on main by itself) and **standalone-review** (~≤400 non-mechanical lines, readable without upstack diffs).
- **Stacked-PR defaults.** Distinct changes get separate gh-stack branches unless I say otherwise; show the stack layout when ambiguous.
- I own screenshot/image uploads.

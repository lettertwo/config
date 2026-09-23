# Showrunner

You are the main thread — the showrunner: resolve design, delegate production, synthesize results, own the close. This policy loads only on the main thread; subagents never see it.

## First move, by plan-artifact state

- **No artifact / open design** → interview me through the decision branches (plan mode, `/spar`, `/spar-with-docs`) and capture the outcome as a plan file, ADR, or handoff doc.
- **Open design → `EnterPlanMode` before the interview.** Both tools are deferred, so `ToolSearch("select:EnterPlanMode,ExitPlanMode")` comes first. Plan mode names a plan file at `$CLAUDE_CONFIG_DIR/plans/<slug>.md` and makes it the only file you can edit; write the interview outcome there, including what the executor won't inherit, and let `ExitPlanMode` be the approval gate (it reads that file and takes no plan argument). Dispatch `implementer` against that path when the design was resolved in this session. Two limits: `plans/` is global across projects, so the newest-mtime pickup rule below does not apply to it, and it is swept on `cleanupPeriodDays`. Anything that must outlive the session gets copied into the project's `docs/handoffs/`.
- **Plan artifact or handoff exists** → dispatch the `implementer` subagent against it, then run the close. Don't implement a locked plan yourself. A ticket carrying acceptance criteria and a file list is a plan artifact too, even though it is not a file: dispatch against the ticket and let the implementer fetch it. Before dispatch against a doc, resolve to the newest-mtime one in the project's `docs/handoffs/` (deterministic pickup, never a judgment call), and have the implementer echo back its Gotchas and Verification gates sections before it starts editing — that's the proof it actually read them.

## Delegation

The main thread is Opus (`settings.json`). Every agent file pins its own:

- Opus: showrunner (interview, plan artifact, diff read, close).
- Opus: `planner`, `researcher`, and feature work dispatched on an understood path.
- Sonnet: `implementer`, Explore

Keep raw output from subagents out of main context; keep the conclusions. The interview stays here.

- Plan-shaped implementation → `implementer`. The artifact must carry what the executor won't inherit: decisions, gotchas, verification commands.
- The reading ahead of an interview (how the mechanism works, what each candidate touches, a draft file list) → `planner`.
- Primary-source questions (docs, upstream behavior, API facts) → `researcher`.
- Broad searches → Explore agents, dispatched with `model: sonnet`.
- **Keep working while a dispatch runs.** `Agent` returns immediately and the result arrives as a later message. Spend the wait on independent work: the next unit's interview, the close for landed work, a `researcher` question. Block on `TaskOutput` only when the next step needs the result; never poll.

## The close (yours, always)

- Gates green, then read the full diff yourself. Delegated work isn't done until it lands.
- **Prove, don't rerun.** The implementer's final gate run and yours are the same command on the same tree; the rebuild and link is the cost, so run it once. On a Rust workspace ask `~/.claude/bin/cargo-gate proven test <crate>...` and `proven clippy` for the changed crates and rerun only what it rejects (its fingerprint moves with the tree, so a close-out edit to code invalidates the proof on its own). Elsewhere accept the implementer's verbatim output when the command was the full gate and no edit followed it; check the order in the agent transcript rather than the prose. Rerun when the output is missing or summarized, the run was filtered, or the tree changed.
- **Voice gate on prose artifacts.** Run `claude/bin/voice-lint` before anything with a reader lands: `voice-lint --pr <file>` for a PR body, plain `voice-lint <file>` for handoff docs, ADRs, plan files, and review comments. `VOICE_LINT=0` skips one run, and `git config voice.lint false` opts a whole repo out, which is the answer for a work repo whose commit conventions are not mine.
- No `/code-review` by default. Invoke it at high effort only for invariant-heavy or gotcha-dense diffs, or when I ask.
- A commit is the bisect/checkpoint unit (green, tested, single message).
- A changeset (branch) is the review/land/revert unit — one decision plus its mechanical consequences. Split only when a unit passes both tests: **land-alone** (coherent and valuable on main by itself) and **standalone-review** (~≤400 non-mechanical lines, readable without upstack diffs).
- **Stacked-PR defaults.** Distinct changes get separate gh-stack branches unless I say otherwise; show the stack layout when ambiguous.
- I own screenshot/image uploads.

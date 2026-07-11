# Claude Code setup recommendations — July 2026

Synthesis of two Claude Code insights reports against a survey of this config repo:

- **Personal** (this machine): 345 messages / 39 sessions, 2026-05-28 → 2026-07-06. Mostly git-workon-review (Rust TUI), workon tooling, stacked-changeset milestones.
- **Work**: 985 messages / 71 sessions, 2026-06-05 → 2026-07-02. Neovim review app, TypeScript frontend features, production debugging, Graphite stack surgery.

## The through-line

The plan-expensive/implement-cheap operating model is working — outcomes land "fully achieved" in the overwhelming majority of sessions on both machines, and both reports independently call out the design-interview → plan artifact → delegated implementation → handoff loop as the standout pattern.

Every recurring failure clusters in one place: **where cheap execution runs without a deterministic gate.**

| Failure (report evidence) | Missing gate |
|---|---|
| Sonnet-implemented changesets ship with compile errors, test regressions, race conditions (personal) | fast per-edit check; gates run before reporting, not after |
| `replace_all` renamed a function inside its own definition (personal) | inspect-after-bulk-edit rule |
| Scope creep past the locked plan — unrequested `subagentStatusLine` feature (personal) | scope fencing in the executor's contract |
| Shallow symptom fixes before root cause — org-refresh alert, missing HTTP status check, kitty progress bar (work) | root-cause-with-evidence gate before any fix |
| Unconditional `rm+cp` clobbered real `settings.local.json`; sandbox-aborted chain misreported as committed (work) | destructive-op enumeration + verify-state-after-command |
| First-pass misses on Graphite stacking / PR splitting / user-owned uploads (work) | conventions codified, not re-explained per session |

The conclusion for the delegation question: **don't buy quality back with bigger models — buy it with harnesses.** The failures above wouldn't be fixed by running the implementer on Opus; they're fixed by gates that don't depend on any model's judgment.

## Harness design principles

How to get high-quality results from lower tiers and effort levels:

1. **Deterministic oracles over model judgment.** A cheap model in a tight verify loop beats an expensive model unverified. Put gates where the model can't skip them (hooks fire mechanically) and where they're cheapest (fast compile/typecheck per edit; full suite + lint at close; CI as the backstop). The git-workon repo now has all three layers — see below.
2. **Asymmetric tiering: generate cheap, verify expensive.** The implementer (Sonnet, pinned medium effort) produces; the main thread (Fable) reads the diff. `/code-review` at high effort only for invariant-heavy diffs — unchanged from existing policy. The expensive model's attention is spent where a subtle wrong step is expensive, never on mechanical production.
3. **The specialized agent *is* the harness.** What makes Sonnet safe as the implementer isn't the model — it's the boundaries in `implementer.md`: never commit, never edit the plan, stop on discrepancy, verify before reporting. When choosing between "more model" and "more harness," add the boundary first; escalate tier only when the *judgment* inside the boundary is failing, not the mechanics.
4. **Scope fencing via the plan artifact.** The doc is the contract. The executor reports discrepancies instead of improvising, and the doc must carry the verification commands — the executor won't inherit session context, so the artifact carries the oracle (`/handoff` now enforces a Verification gates section).
5. **Structured output for low-tier discipline.** `stack-review`'s `REVIEW_SCHEMA`/`FIX_SCHEMA` is the house pattern: a JSON schema forces a cheap agent to commit to file/line/confidence instead of returning plausible prose. Any future fan-out skill should force schemas.
6. **Escalation valves, not thrashing.** Two red loops on the same gate → stop and report the failing state. Open design question → return to the main thread. A returned failure is cheaper than a long wrong-direction debug loop, and it routes hard judgment back to the tier that should be doing it.
7. **Pin effort in frontmatter; don't inherit.** Session effort is set for the session's work, not the delegate's. A high-effort Fable design session shouldn't hand high effort to mechanical execution, and a low-effort quick session shouldn't starve a verify step. Agents and skills both support `effort:` frontmatter (`low|medium|high|xhigh|max`); `implementer` is now pinned `medium`. Rule of thumb: high for design interviews and invariant-heavy review, medium for implementation, low for mechanical sweeps and Explore fan-outs.

## Changes applied (this repo, syncs to both machines)

### Skills: broken symlinks replaced with materialized dirs
Nine of thirteen entries in `claude/skills/` were symlinks to `../../.agents/skills/…`, which resolves to a nonexistent `~/.config/.agents/` — **those skills have been silently unavailable since May 28**. Removed all nine; materialized the four that earn their place as real directories:

- **`diagnose`** — disciplined root-cause loop (reproduce → falsifiable hypotheses → instrument → fix + regression test → cleanup). Directly targets the work report's #1 friction; the new CLAUDE.md root-cause rule points at it.
- **`qa`** — conversational bug reporting → durable GitHub issues, with a background Explore agent for domain context. Matches the work machine's QA-heavy sessions.
- **`design-an-interface`** — parallel design-variant fan-out ("design it twice"); one of only two skills encoding delegation, and a template for the judge-panel harness shape.
- **`grill-with-docs`** — plan grilling against CONTEXT.md/ADRs; fits the ADR-as-plan-artifact style.

### `agents/implementer.md` hardened
- `effort: medium` pinned in frontmatter.
- Fast deterministic check after each edit batch; full gates with pasted output before reporting; never done while red, never claim an unrun gate passed.
- Two red loops on the same gate → stop and report (with both attempts and a hypothesis).
- Verify state after side-effectful command chains (exit codes, `git status`) before treating them as done.
- Inspect every changed site after `replace_all`/bulk edits.

### CLAUDE.md: three new working-style rules + effort pairing
- **Root cause before fix** — hypothesis with evidence, symptom vs cause distinguished, before writing the fix; `/diagnose` for nontrivial bugs.
- **Destructive ops are gated** — enumerate irreversible steps, explicit go-ahead each; never unconditionally overwrite non-symlinked real files; verify effect after the command before reporting done.
- **Stacked-PR defaults** — distinct changes get separate Graphite-stacked branches; show the stack layout when ambiguous; user owns screenshot/image uploads.
- Model-tiers bullet extended with the tier↔effort pairing (principle 7).

### `/handoff` extended
- Handoff docs must include a **Verification gates** section (exact commands to run green).
- `--dispatch` argument: after writing the doc, spawn the `implementer` against it in-session; main thread runs the close (gates + diff read); commit stays with the user.

### git-workon repo: per-edit compile gate (applied in `git-workon-review` worktree)

> **Superseded by `docs/2026-07-integrated-system-plan.md` (WS3).** This section describes the pre-`cargo-gate` state — the hook below called raw `cargo check`/`clippy`/`test` directly, which caused the CPU-contention and forced-color false-positive hook blocks that WS3 fixes. The hooks now call `~/.claude/bin/cargo-gate`; see the integrated plan for the wrapper design and the "never landed" note just below.

The repo already had two gate layers: a PostToolUse `cargo fmt` hook and a Stop hook running clippy + the full test suite with block-and-feedback (one forced fix round). Added the missing middle layer — a PostToolUse hook on `.rs` edits running `cargo check --workspace --quiet`, exit 2 with the error tail on failure. Distinct class it catches: **compile errors during a subagent's run** — Stop hooks fire at main-turn end, so an implementer could previously accumulate broken edits all the way to its report. Now the cheap model gets deterministic feedback at the moment of the mistake.

Gate stack for the repo is now: per-edit `cargo check` → stop-time clippy + tests → CI.

> Note: this edit lives in the checked-in `.claude/settings.json`, currently dirty in the `git-workon-review` worktree. **This never landed** — as of the integrated system plan (2026-07-11) it was still uncommitted, now five days stale, and the worktree itself had since moved off `m2-verdict` onto `polish-icons-devicons` with the change carried along uncommitted. It has now been rewired to call `cargo-gate` (WS3) and is still awaiting a commit from the main thread.

## To apply on the work machine

> **Stale TODO, tracked in `docs/2026-07-integrated-system-plan.md`.** Not superseded by that plan (it doesn't cover the work machine), but not done either — still open as of 2026-07-11.

Per-edit typecheck gate for the TypeScript repo — add to its `.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "file=$(cat | jq -r '.tool_input.file_path // empty'); if [ -n \"$file\" ] && echo \"$file\" | grep -Eq '\\.(ts|tsx)$'; then out=$(cd \"$CLAUDE_PROJECT_DIR\" && npx tsc --noEmit 2>&1) || { echo \"$out\" | tail -30 >&2; exit 2; }; fi"
          }
        ]
      }
    ]
  }
}
```

If full-project `tsc --noEmit` is too slow per edit, scope it (project references, `tsc -b`, or a Stop hook like git-workon's `stop-check.sh` instead).

## Manual skill pass — candidates and verdicts

Real skills live in `~/.agents/skills/`. Not migrated; for the pass:

| Skill | Case |
|---|---|
| `git-guardrails-claude-code` | Targets the destructive-op data-loss friction — but the new CLAUDE.md bullet covers the same class. **Adopt one or the other, not both** (no belt-and-braces). If the skill's mechanism is a hook (deterministic), prefer it over the prose rule and delete the bullet. |
| `tdd` | Fits the regression-heavy friction; overlaps `diagnose`'s fix-with-regression-test step. Worth a look. |
| `review` | Likely redundant with built-in `/code-review` + `stack-review`. Skip unless it does something distinct. |
| `setup-pre-commit` | One-shot utility; run it per-repo rather than keeping as a skill. |
| `prototype`, `request-refactor-plan`, `improve-codebase-architecture` | Niche but coherent; migrate if used in the last month, otherwise leave. |
| `find-skills` | Reinstallable ecosystem utility; leave. |
| `obsidian-vault` | Hardcodes WSL path `/mnt/d/Obsidian Vault/AI Research/` — broken on macOS. Fix the path (or make it configurable) before migrating; `recruiter-company-research` references the vault too. |

## Addendum (2026-07-06, later same day): the showrunner design

The session-start recipe ("pick the opening model by plan-artifact state") is **retired**, replaced by a main-thread policy persona:

- **`~/.claude/showrunner.md`** carries all orchestration policy: first move by artifact state (interview vs dispatch), delegation rules, inline-work affordance (a handful of edits with no open design → just do it), effort/tier guidance, and the close (gates, diff read, review-effort policy, changesets, stacked-PR defaults).
- **Loaded by a SessionStart hook** (`showrunner-hook.sh`, matcher `startup|resume|clear|compact`) — chosen over the settings `agent` field because a main-thread agent's prompt *replaces* the built-in system prompt (documented; equivalent to `--system-prompt`), and over a fish-alias `--append-system-prompt` because the hook covers every launch path (IDE, desktop, remote-control, resume), not just shell.
- **Scoping is the point**: subagents get `SubagentStart`, not `SessionStart`, so the implementer never reads "delegate to the implementer." CLAUDE.md now holds only universal invariants (root-cause, destructive ops, wraps, naming) that bind every context.
- **Skip hatch**: `CLAUDE_SHOWRUNNER=0` env gate inside the hook (fish abbr `c0`) — for bare-executor sessions, headless/cron automation, and A/B debugging. Settings-level hooks can't be selectively disabled per-invocation, so the gate must live in the hook script.
- **Load confirmation**: the hook touches `~/.cache/claude-showrunner/<session_id>`; the statusline renders a dim `󰎁 sr` when present, so a silently-broken hook is visible instead of a week-later surprise.
- Model/effort stay in settings (`claude-fable-5[1m]` @ medium); the persona is a role, not a tier. If Claude Code ever ships an *additive* main-thread agent mode, `showrunner.md` migrates into it nearly verbatim.

## Deferred (until the gates prove out)

Both reports pitch autonomous versions of the existing loop — milestone-to-green pipelines, parallel worktree fix swarms, observability-driven auto-remediation. These are the same harness principles run unattended: the gate stack above *is* the prerequisite, because unattended cheap execution is only as good as the oracles it loops against. Revisit once a few delegated milestones ship through the hardened implementer + hook stack without main-thread rescues.

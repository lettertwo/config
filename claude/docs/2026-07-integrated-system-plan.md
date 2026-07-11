# Integrated Development System — Config Alignment Plan

**Date:** 2026-07-11 · **Status:** locked (grill session complete) · **Scope:** `~/.config/claude` global config + one project-level follow-through in git-workon-review

Grounded in three evidence streams: full config audit, session-history analysis (84 facets, 72 transcripts, 228 subagent transcripts), and external research on 2026 best-in-class setups. Every decision below was resolved in a grill interview; **Rejected** items were explicitly declined — do not resurrect them.

## Locked decisions

| # | Decision | Rationale (evidence) |
|---|---|---|
| D1 | **Round-trip rule** for inline edits | Leak is "one more fix" loops, not big implementations: 44/35/35 main-thread edits alongside live spawns, all on Fable. First round of small edits inline is fine; any follow-up round after a red gate gets bundled to the implementer with the failure output. |
| D2 | **Implementer verifies synchronously; stack-review ports to the Workflow tool** | 3 sessions burned babysitting stalled background implementers (stray cargo procs, tripped stop hooks). Sync-only in the agent contract; deterministic script orchestration for the review fan-out. |
| D3 | **`cargo-gate` wrapper: serialize + filter** | 11 stop-hook blocks across 6 sessions, ≥2 false positives (CPU contention from 6 agents; forced-color env leakage). One wrapper does lock serialization, env scrubbing, and output compression. |
| D4 | **Handoff resolver + consumption step** | Wrong-doc pickup misfires; one crash on a bug the handoff explicitly warned about. Deterministic location + newest-wins; pickup must echo Gotchas/Verification before acting. No PreCompact hook (user /clears deliberately: 24× vs 6 compactions). |
| D5 | **Attic the dead surface** | Never invoked in 72 sessions: design-an-interface, new-skill, qa, list-tasks. Keep situational skills with clear future triggers (scaffold-js-project, recruiter-company-research). grill-me stays (15 uses — 2nd most-used). |
| D6 | **effortLevel → medium; tier/effort switches only at phase boundaries** | Uncommitted `high` drift contradicts stated policy ("spikes belong in frontmatter"). Prompt cache is keyed per model AND effort — mid-session switches re-read the whole conversation at full price (13 observed). |
| D7 | **Targeted enforcement trio** (no global PostToolUse) | Implementer `tools:` allowlist; cargo-gate dual-purpose wrapper; per-repo PostToolUse hooks stay project-level — land the dirty git-workon cargo-check hook. |
| D8 | **GT MCP server, deferred-only** | ~120 manual gt/graphite mentions; stack-review hand-parses gt output. Enable with tool-search deferral (≈zero idle cost); Workflow port consumes structured stack state. Skip the community plugin. |
| D9 | **No new autonomy** (user decision, overrode recommendation) | No /milestone skill, no cron/scheduled agents, no overnight orchestrator. The interactive showrunner loop IS the product; the close stays with the user. |

## Workstreams

### WS1 — Policy text edits (`showrunner.md`, `CLAUDE.md`)
1. `showrunner.md` › Delegation: replace "inline work is fine when the change is a handful of edits" with the **round-trip rule**: inline for the first small round only; after any red gate (test/clippy/hook), bundle remaining fixes + failure output into an implementer dispatch. Close-out edits (final commit grooming) exempt.
2. `showrunner.md` › new line under Delegation: **model/effort switches only at phase boundaries** (post-`/clear` or handoff), never mid-task — each switch invalidates the conversation prompt cache.
3. `showrunner.md` › one line: **scoped reads** — re-read only the edited region (offset/limit or LSP), never the whole hub file after each edit round (evidence: `display.rs` read 22× in one session; 25/72 sessions affected).
4. `CLAUDE.md` (binds subagents): one line — **renames never use `replace_all`**; use scoped edits and verify the definition site (2 sessions clobbered a definition via replace_all). Keep CLAUDE.md ≤ current size; these are the only additions.

### WS2 — Implementer hardening (`agents/implementer.md`)
1. Frontmatter `tools:` allowlist excluding `Agent` (mechanically enforces "never spawns implementers"; keep Bash/Read/Edit/Write/Grep/Glob + TaskCreate/Update if present in inherited set).
2. Contract text: **all verification runs synchronously in the foreground** — no `run_in_background`, no detached waits; gates run via `cargo-gate` where it exists; report full failure output verbatim.

### WS3 — `cargo-gate` wrapper (`~/.config/claude/bin/cargo-gate`)
A small shell wrapper: `cargo-gate test`, `cargo-gate check`, `cargo-gate clippy`.
1. **Serialize** all invocations machine-wide via a lock. **Gotcha: macOS has no `flock(1)`** — use an atomic `mkdir` spinlock with stale-lock detection (pid liveness check), timeout ~120s then proceed with a warning line.
2. **Scrub env**: unset `CLICOLOR_FORCE`, `FORCE_COLOR`, `CARGO_TERM_COLOR=always` (forced-color leakage caused a false hook block).
3. **Filter output**: on green, emit a one-line summary (`ok: N passed in Xs`); on red, emit failing test names + error/warning lines only (grep-level filter, keep exit code intact). Full log to a temp file, path printed for on-demand reading.
4. **Gotcha: bash 3.2** (system bash) — no associative arrays, no `${var,,}`.
5. Wire-up: git-workon-review's stop hook and PostToolUse hook call `cargo-gate` instead of raw cargo. **Land the dirty cargo-check hook commit** sitting uncommitted on branch `m2-verdict` in the git-workon-review worktree (verify it still exists first; it's ~5 days stale).

### WS4 — Handoff hardening (`skills/handoff/`)
1. Handoffs write to a deterministic per-project path: `<repo>/docs/handoffs/<date>-<slug>.md` (or the project's existing convention if one is found — check before imposing). "Latest" = newest mtime in that dir; never a judgment call.
2. Pickup contract (in the skill + one showrunner first-move line): before acting, **echo back the handoff's Gotchas and Verification sections** — proves consumption (a session crashed on a bug its handoff warned about).
3. No new `/pickup` command, no PreCompact hook (rejected).

### WS5 — stack-review → Workflow tool port (`skills/stack-review/`)
1. Replace `workflow.js` model-driven dispatch with a Workflow-tool script: `pipeline()` over changesets, per-changeset review agents with `schema`-validated findings, adversarial verify stage, journaled resume.
2. Test execution inside the workflow goes through `cargo-gate` (WS3) — this is what actually fixes the 6-concurrent-agents contention.
3. Consume stack structure from the GT MCP server (WS6) instead of parsing `gt` output; keep a CLI-parse fallback until MCP proves itself.
4. Preserve existing behavior: `--upstack`, comment-format.md output, autofix mode.

### WS6 — GT MCP (deferred-only)
1. Requires `gt` ≥ 1.6.7 — verify installed version first.
2. Register the GT MCP server in config with tool-search deferral so idle cost ≈ 0. No community plugin.

### WS7 — Pruning & hygiene
1. Create untracked `~/.config/claude/attic/`; move `skills/{design-an-interface,new-skill,qa}` and `commands/list-tasks.md` into it. Keep: grill-me, grill-with-docs, handoff, diagnose, stack-review, scaffold-js-project, next-task, recruiter-company-research.
2. Disable `code-simplifier` plugin (its `simplify` skill: 0 uses).
3. Revert `settings.json` `effortLevel` to `medium`; commit.
4. `git add` the untracked-but-allowlisted files: `docs/`, `commands/recruiter-company-research.md` — after fixing/flagging the recruiter command's Obsidian vault path (audit flagged a WSL path broken on Darwin; verify and correct).
5. Mark stale sections of `docs/2026-07-setup-recommendations.md` (the "applied" cargo-check hook that never landed; work-machine tsc TODO) as superseded by this doc.
6. Statusline: add **cache-hit rate** to `statusline-command.sh` line 1 (data available in the same JSON the spend ledger already parses) — makes cache-invalidation events visible.
7. Thinking-block 400s burned 4 sessions (~5%): add a note to showrunner or docs — prefer `/clear` + handoff over resuming long thinking-heavy sessions; file an anthropics/claude-code issue with the facet evidence if it recurs.

## Explicitly rejected (do not implement)
- /milestone skill, cron/scheduled agents, overnight autonomous orchestrator (D9)
- Global PostToolUse gate; SubagentStop hook
- PreCompact auto-handoff hook
- Hard numeric edit budget; cheap-tier main thread default
- Merging grill-me into grill-with-docs; atticking scaffold-js-project/next-task
- Monitor-based watchdog for implementers (superseded by sync-only + Workflow port)

## Sequencing & verification
- Order: WS3 → WS5 (stack-review depends on cargo-gate); WS6 before or with WS5 (MCP consumption); WS1/WS2/WS4/WS7 independent.
- Gates per workstream: shell scripts pass `shellcheck` and run under macOS bash 3.2; hook changes smoke-tested in a live session (`sr` statusline marker confirms showrunner load; run one gated edit in git-workon-review); skill edits validated by invoking the skill once; settings.json changes verified with `claude config` or a fresh session.
- The close (diff read + commit, logical groups) stays on the main thread per showrunner. Config repo commits on the current branch or a new one — user's call at close time.

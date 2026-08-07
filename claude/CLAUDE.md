## Working style

Only rules that bind subagents too belong here — main-thread orchestration policy lives in `~/.claude/showrunner.md`.

- **Root cause before fix.** State a root-cause hypothesis with evidence (trace, log, code path) and distinguish symptom from cause before writing any fix. `/diagnose` for nontrivial bugs.
- **Destructive ops are gated.** Enumerate irreversible steps (force-push, `rm`/`cp` over real files, history rewrites, branch resets) and get explicit go-ahead for each; never unconditionally overwrite a real (non-symlinked) file. Verify the effect afterward (exit code, `git status`) before reporting done — a mid-chain failure can silently abort the rest.
- **No overloaded names for domain objects.** Before naming an abstraction, check the name doesn't already mean something in the host tool, the domain (git, nvim, shell), or the codebase; prefer distinctive domain words ("Docket", "changeset") over IDE-speak ("session", "view", "manager").
- **Prose a human reads follows the writing rules.** Before writing a doc, README, or comment block that outlives this session, apply the rules in `~/.claude/output-styles/cold-read.md` — read it first if it isn't already in context.

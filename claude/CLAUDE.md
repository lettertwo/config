## Working style

Only rules that bind subagents too belong here. Main-thread orchestration policy and the voice rules both live in `~/.claude/showrunner.md` and `~/.claude/voice.md`, loaded by the SessionStart hook so subagents never pay for them. An agent that writes prose for the user rather than for the main thread needs voice.md named in its own definition or its dispatch prompt.

- **Root cause before fix.** State a root-cause hypothesis with evidence (trace, log, code path) and distinguish symptom from cause before writing any fix. `/diagnose` for nontrivial bugs.
- **Destructive ops are gated.** Enumerate irreversible steps (force-push, `rm`/`cp` over real files, history rewrites, branch resets) and get explicit go-ahead for each; never unconditionally overwrite a real (non-symlinked) file. Verify the effect afterward (exit code, `git status`) before reporting done, since a mid-chain failure can silently abort the rest.


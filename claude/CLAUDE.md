## Working style

Only rules that bind subagents too belong here — main-thread orchestration policy lives in `~/.claude/showrunner.md`.

- **Root cause before fix.** State a root-cause hypothesis with evidence (trace, log, code path) and distinguish symptom from cause before writing any fix. `/diagnose` for nontrivial bugs.
- **Destructive ops are gated.** Enumerate irreversible steps (force-push, `rm`/`cp` over real files, history rewrites, branch resets) and get explicit go-ahead for each; never unconditionally overwrite a real (non-symlinked) file. Verify the effect afterward (exit code, `git status`) before reporting done — a mid-chain failure can silently abort the rest.
- **Each defensive wrap must justify itself.** Name the specific class of error a pcall/try-catch/guard catches that other mitigations don't — if you can't, drop it.
- **No overloaded names for domain objects.** Before naming an abstraction, check the name doesn't already mean something in the host tool, the domain (git, nvim, shell), or the codebase; prefer distinctive domain words ("Docket", "changeset") over IDE-speak ("session", "view", "manager").
- **Renames never use `replace_all`.** Use scoped edits and verify the definition site afterward — bulk renames have clobbered a definition before.

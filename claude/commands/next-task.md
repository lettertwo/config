---
description: Find and prioritize the next task from TODOs, FIXMEs, and unimplemented work
argument-hint: "[category or component to focus on]"
allowed-tools:
  - Grep
  - Glob
  - AskUserQuestion
  - EnterPlanMode
---

# Next Task

Discover, prioritize, and begin planning the next task to work on.

## Steps

1. **Discover tasks** — Scan using the same approach as `/list-tasks`:
   - Detect languages via marker files (`Cargo.toml`, `pyproject.toml`, `setup.py`, `go.mod`, `package.json`)
   - Search for `\b(TODO|FIXME|HACK|XXX)\b` across all files
   - Run additional language-specific patterns for detected languages (Rust macros, Python `NotImplementedError`, etc.)
   - Exclude: `.git/`, `node_modules/`, `target/`, `dist/`, `build/`

2. **Categorize** each task by:
   - **Type**: bug fix (FIXME, language error-macros), feature (TODO), technical debt (HACK/XXX)
   - **Component**: top-level directory or module/crate
   - **Complexity**: simple (isolated, clear scope) vs involved (cross-cutting, unclear scope)
   - **Impact**: blocks other work, user-facing, internal/cleanup

3. **Present prioritized options** — If `$ARGUMENTS` names a category or component, filter to it. Show the top 5–8 candidates with:
   - Description and `file:line` location
   - Type, estimated complexity, impact
   - Recommended order: unblocking > user-facing > bug fixes > well-scoped features

4. **Ask the user** which task to work on (use AskUserQuestion).

5. **Enter plan mode** for the selected task (use EnterPlanMode).

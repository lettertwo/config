---
description: Scan codebase for TODOs, FIXMEs, and other task markers with a structured overview
argument-hint: "[path]"
allowed-tools:
  - Grep
  - Glob
---

# List Tasks

Scan for task-marker comments and language-specific unimplemented markers, then show a structured overview.

## Steps

1. **Determine scan root** — Use `$ARGUMENTS` as the path if provided; otherwise use the project root.

2. **Detect active languages** by checking for these files in the root (use Glob):
   - `Cargo.toml` → **Rust**: also search `\b(todo!|unimplemented!|unreachable!)\s*\(` in `*.rs` files
   - `pyproject.toml`, `setup.py`, or `setup.cfg` → **Python**: also search `raise NotImplementedError` in `*.py` files
   - `go.mod` → **Go**: comment markers are sufficient
   - `package.json` → **JavaScript/TypeScript**: comment markers are sufficient

3. **Scan for markers** using Grep:
   - **Always**: search for `\b(TODO|FIXME|HACK|XXX)\b` across all files
   - Exclude: `.git/`, `node_modules/`, `target/`, `dist/`, `build/`
   - **Per detected language**: run the additional language-specific pattern (scoped to that language's file type)

4. **Format as a structured overview**:
   - **Summary** — total count, breakdown by marker type, breakdown by top-level directory or crate
   - **By Priority** — language error-macros and FIXMEs first (bugs/blockers), then TODOs, then HACK/XXX
   - **Each task** — `file:line — text` (keep it scannable, use markdown)

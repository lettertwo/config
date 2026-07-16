---
name: scaffold-js-project
description: Scaffold a new JavaScript/TypeScript project with the preferred pnpm setup (worktree-agnostic store, symlinked executables). Use when creating a greenfield JS/TS project.
disable-model-invocation: true
---

Scaffolding a new JavaScript/TypeScript project. Use **pnpm** — this preference applies only at project-creation time; never migrate an existing project's package manager unless asked.

Create `pnpm-workspace.yaml` at the repo root with the shared worktree-agnostic store config:

```yaml
# shared worktree-agnostic node_modules store
enableGlobalVirtualStore: true
storeDir: ../.pnpm

# many integrations expect node executables in node_modules/.bin
preferSymlinkedExecutables: true
```

Rationale: `storeDir: ../.pnpm` puts the store one level above the checkout so multiple worktrees of the same repo share it; `preferSymlinkedExecutables` keeps `node_modules/.bin` working for tools that expect real executables there.

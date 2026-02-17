## Package Manager

- Always use **pnpm** (not npm/yarn)
- Create `pnpm-workspace.yaml` with shared worktree-agnostic store config:
  - `enableGlobalVirtualStore: true`
  - `storeDir: ../.pnpm`
  - `preferSymlinkedExecutables: true`
- Reference setup: `/Users/erice/Code/lettertwo.github.io/main/pnpm-workspace.yaml`

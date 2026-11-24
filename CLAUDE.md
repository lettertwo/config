## Commits

Subject only: `[area] lowercase imperative phrase`, where area is the top-level directory (`nvim`,
`hunk`, `claude`, `kitty`, …). Files at the repo root take the area of their tool: `make` for the
Makefile, `brew` for the Brewfile, `git` for `.gitignore`.

## Claude config

`claude/.gitignore` is an allowlist: it ignores everything under `claude/` and re-includes tracked
paths one by one. A new file or directory there stays untracked, with nothing in `git status`, until
it gets a `!/` entry.
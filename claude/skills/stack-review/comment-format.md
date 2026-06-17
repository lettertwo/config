# PR Comment Format

Post one comment per branch via `gh pr comment <number> --body "$(cat <<'EOF' ... EOF)"`.

## With findings

```markdown
### Code review

Found N issues:

1. <brief description of bug> (<reason: CLAUDE.md says "...", or "bug due to <snippet>">)

https://github.com/<owner>/<repo>/blob/<full-40-char-sha>/<file>#L<start>-L<end>

2. <brief description>

https://github.com/<owner>/<repo>/blob/<full-40-char-sha>/<file>#L<start>-L<end>

🤖 Generated with [Claude Code](https://claude.ai/code)

<sub>- If this code review was useful, please react with 👍. Otherwise, react with 👎.</sub>
```

## No findings

```markdown
### Code review

No issues found. Checked for bugs and CLAUDE.md compliance.

🤖 Generated with [Claude Code](https://claude.ai/code)
```

## Link format rules (strictly required for Markdown preview to render)

- Full 40-character SHA — never abbreviated. Get it with: `git -C <worktree> rev-parse HEAD`
- Repo name must match the repo being reviewed (get from `gh repo view --json nameWithOwner`)
- Format: `https://github.com/<owner>/<repo>/blob/<sha>/<path>#L<start>-L<end>`
- Provide at least 1 line of context before and after the affected lines
- Example: commenting on line 42 → link to `#L41-L43`

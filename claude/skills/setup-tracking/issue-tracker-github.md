# Issue tracker: GitHub

Issues and PRDs for this repo live as GitHub issues. Use the `gh` CLI for all operations.

## Conventions

- **Create an issue**: `gh issue create --title "..." --body "..."`. Use a heredoc for multi-line bodies.
- **Read an issue**: `gh issue view <number> --comments`, filtering comments by `jq` and also fetching labels.
- **List issues**: `gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'` with appropriate `--label` and `--state` filters.
- **Comment on an issue**: `gh issue comment <number> --body "..."`
- **Apply / remove labels**: `gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- **Close**: `gh issue close <number> --comment "..."`

Infer the repo from `git remote -v` — `gh` does this automatically when run inside a clone.

## When a skill says "publish to the issue tracker"

Create a GitHub issue.

## When a skill says "fetch the relevant ticket"

Run `gh issue view <number> --comments`.

## Wayfinding operations

Used by `/wayfinder`. **Wayfinding does not run on GitHub** — it uses the **local-markdown** tracker instead, regardless of this repo's issue-tracker choice.

Wayfinder generates a lot of transient decision tickets (research, sparring, prototypes) whose value is the artifacts they lead to, not the tickets themselves. Putting that churn in the shared GitHub Issues is noise for the team. So a wayfinder map and its child tickets live under `.scratch/<effort>/` — see the "Wayfinding operations" section of the local-markdown tracker doc for map, ticket, blocking, frontier, claim, and resolve conventions.

Publish only the *outputs* you actually want to share (a spec, a decision record) to GitHub, via `gh issue create` as above.

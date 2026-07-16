# Issue tracker: Linear

Issues and PRDs for this repo live in Linear. Use the `linear` MCP (the official `mcp.linear.app` server, tools namespaced `mcp__linear__*`) for all operations.

## Conventions

- **Create an issue**: `create_issue` with `title`, `description` (Markdown), and `team`. Pass `parentId` to make it a sub-issue, `labels` to tag it, `assignee` / `state` as needed.
- **Read an issue**: `get_issue` for the body and metadata, then `list_comments` for the discussion. Accepts the human-readable identifier (e.g. `ZIP-1234`) as well as the UUID.
- **List issues**: `list_issues` with filters — `team`, `assignee`, `label`, `state`, `parentId`, `query`. Use `list_my_issues` for the current user's queue.
- **Comment on an issue**: `create_comment` with the issue id and `body`.
- **Apply / remove labels**: `update_issue` with the full desired `labels` set (label changes replace the set — read current labels first, then add/remove). `list_issue_labels` resolves label names to ids; `create_issue_label` makes a new one.
- **Close**: `update_issue` setting `state` to a completed-type workflow state (e.g. `Done` / `Canceled`). `list_issue_statuses` for the team lists the available states and their types.

Infer the team from the repo's usual Linear team (the project prefix, e.g. `ZIP-`). If the team is ambiguous, `list_teams` and confirm before writing.

## When a skill says "publish to the issue tracker"

Create a Linear issue with `create_issue`, attached to a **project** (and milestone, if the project uses them) — an issue outside a project is orphaned from how work is tracked here.

Determine the project this way:

1. **Infer from the branch.** If the current branch names a ticket (e.g. `ee/ZIP-1234-...`), `get_issue` that ticket and reuse its project (and milestone).
2. **Otherwise ask.** Don't guess a project — ask the user which project (and milestone) the new issue belongs to. `list_projects` to offer the options.

## When a skill says "fetch the relevant ticket"

Run `get_issue` (plus `list_comments`). The user will normally pass the identifier (e.g. `ZIP-1234`) or a `linear.app/...` URL directly.

## Wayfinding operations

Used by `/wayfinder`. **Wayfinding does not run on Linear** — it uses the **local-markdown** tracker instead, regardless of this repo's issue-tracker choice.

Wayfinder generates a lot of transient decision tickets (research, sparring, prototypes) whose value is the artifacts they lead to, not the tickets themselves. Putting that churn in the shared Linear workspace is noise for the team. So a wayfinder map and its child tickets live under `.scratch/<effort>/` — see the "Wayfinding operations" section of the local-markdown tracker doc for map, ticket, blocking, frontier, claim, and resolve conventions.

Publish only the *outputs* you actually want to share (a spec, a decision record) to Linear, via `create_issue` as above.

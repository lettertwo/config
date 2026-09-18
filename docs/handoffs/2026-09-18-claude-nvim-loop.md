# Handoff: Claude ↔ Neovim feedback loop

Written 2026-09-18 from the session that built unit 1. The next session continues on another machine, so this doc carries what lives only on the first one.

## Where things are

- Branch `claude-nvim-loop` in the dotfiles repo, two commits ahead of `main`, pushed state unknown at time of writing (push before switching machines). `d108bb9` is the nvim module, `2eb78a2` the Claude-side hooks, skill, and fish viewer. The commit bodies describe what each piece does; start there.
- Code: `nvim/lua/config/annotations/` (`init`, `store`, `anchor`, `ui`, `export`, `send`, `watch`, colocated `*_spec.lua`), `nvim/plugin/annotations.lua`, `claude/kitty-tag.sh`, `claude/turn-snapshot.sh`, `claude/skills/annotations/SKILL.md`, `fish/functions/claude-turns.fish`, hook entries in `claude/settings.json`.
- Specs: `nvim --headless -u nvim/init.lua -c "PlenaryBustedDirectory nvim/lua/config/annotations"`. 30 pass as of the last commit.
- The plan file with all six rounds of decisions is `$CLAUDE_CONFIG_DIR/plans/starry-imagining-bachman.md` on the first machine only. Its decisions are summarised below; the rest is derivable from the code and commits.
- Auto-memory on the first machine: `project_claude_nvim_loop.md` (status and decisions) and `feedback_comments_for_future_reader.md` (a standing rule, see below). Recreate the rule if the memory dir does not sync.

## Decisions that are not derivable from the code

- Claude and nvim run in separate kitty windows in the same repo. Embedding Claude in nvim and the IDE MCP protocol (claudecode.nvim) were considered and rejected.
- The user triggers delivery. No hook auto-injects annotations. `send` types `/annotations` into the Claude window via `kitty @ send-text`; the window is found by the `claude_cwd` user var that `kitty-tag.sh` sets, with a fallback to a `claude` foreground process in the same cwd.
- Per-turn history uses git tree snapshots from hooks, chosen over Claude's own `file-history/` (undocumented format, blind to Bash and subagent edits) and over a PostToolUse patch ledger.
- Annotations stay in `config/`, not the nvim app framework: they decorate buffers the user is already in and have no screen of their own. The review app is the consumer, in unit 2.
- Claude never edits `annotations.json`; it only appends to `resolutions.jsonl`. nvim writes manual rows to the same file and prunes rows on dismiss. Nothing is auto-deleted on send or resolution so the user can `unresolve` and resend.
- Bodies hang below the last line of a range. The gutter is one connector from the anchor sign through the panel.

## Standing rules from the user

- Code comments, script headers, and skill text address a cold reader of the code. No references to plan units, rounds, sessions, memory notes, or the conversation.
- Docs and the skill name actions (`send`, `resolve`), never key sequences; keymaps are user-configurable in `setup(opts)`.
- Voice rules in `~/.claude/voice.md` apply to prose artifacts; `claude/bin/voice-lint <file>` gates them.

## Not yet verified

Every round was closed headless. Nothing on this branch has been exercised in a live nvim session except one early `send` round trip before the panel work. First things to try:

1. Open a file with a range annotation and a stacked pair; check the panel, label, and gutter connector.
2. `list` (default `<leader>al`): the picker preview was rewritten against the real snacks preview API but never opened.
3. A real `/annotations` run that appends a resolution and shows the `↳` note within ~100ms via the watcher.
4. `resolve` / `unresolve` / `dismiss` from both buffer and picker (`r`, `u`, `x`).

## Known gaps and traps

- `claude -p` cancels async `Stop` hooks on exit, so one-shot runs produce a `prompt` row but no `stop` row in the turns ledger. Interactive sessions are the target.
- `kitty-tag.sh` and `send.lua` assume kitty remote control at `unix:/tmp/kitty.sock` (or `$KITTY_LISTEN_ON`) and `$KITTY_WINDOW_ID` in the Claude window's environment. On a machine whose kitty launch args differ from `kitty/macos-launch-services-cmdline`, tagging silently no-ops.
- Block text highlight groups are recomputed on `ColorScheme`; override `AnnotationBlock` to recolor the panel, not the text groups.
- `edit fugitive:///x` crashes via gitsigns in `nvim/lua/app/default/plugins/diff.lua`. Pre-existing, unrelated, untouched.
- The turns ledger's `.lock` is a mkdir lock with 30s stale-break; a hook killed mid-write is recovered on the next run.
- New hooks and the skill take effect in a fresh Claude session, not the one that edited them.

## Next unit (unit 2), not yet planned

Rebase `nvim-review-app` onto `main` (it was 56 ahead / 29 behind on 2026-09-16), then in `nvim/lua/app/review/`:

- `source/turns.lua`: one `Review.Changeset` per row of the newest `<git-common-dir>/claude-turns/<session>.jsonl`, `base_ref` = previous tree, `head_ref` = this tree, title from `prompt`/`reply`, live worktree spliced on top like the stack source.
- Make `row_to_source` side-aware (`ui/pane.lua`); render annotations on the right pane by `file` + `lnum` using `config.annotations.store` unchanged.
- Join annotations to the turn that answered them via `resolution.turn_seq`.

Interview the user before writing that plan; the review app memory (`project_review_plugin.md` on the first machine) holds the app's gotchas (unnamed-buffer sweep, extmark priorities, e2e focus hazards).

## Suggested skills

- `/diagnose` if the live checks above surface a rendering or watcher bug.
- `/code-review` at high effort before merging `claude-nvim-loop` to `main`; the extmark and highlight code is invariant-dense.
- `/gh-stack` if unit 2 lands as a stack on top of this branch.
- `/writing-for-agents` when touching `claude/skills/annotations/SKILL.md`.

## Working style

Only rules that bind subagents too belong here — main-thread orchestration policy lives in `~/.claude/showrunner.md`.

- **Root cause before fix.** State a root-cause hypothesis with evidence (trace, log, code path) and distinguish symptom from cause before writing any fix. `/diagnose` for nontrivial bugs.
- **Destructive ops are gated.** Enumerate irreversible steps (force-push, `rm`/`cp` over real files, history rewrites, branch resets) and get explicit go-ahead for each; never unconditionally overwrite a real (non-symlinked) file. Verify the effect afterward (exit code, `git status`) before reporting done — a mid-chain failure can silently abort the rest.
- **No overloaded names for domain objects.** Before naming an abstraction, check the name doesn't already mean something in the host tool, the domain (git, nvim, shell), or the codebase; prefer distinctive domain words ("Docket", "changeset") over IDE-speak ("session", "view", "manager").
## Writing

These rules govern prose artifacts around the work: PR titles and descriptions, commit messages,
issue and review comments, handoff docs, ADRs, RFCs, reports, and long-form code comments.
Checked-in docs follow any conventions their repository declares; these rules fill the gaps.

- **Declarative register.** State what is, not what isn't; avoid persuasive literature, coinage,
  and aphorism.
- **Length matches substance.** Cover what the task needs; no filler sections, redundant
  summaries, or boilerplate.
- **Don't answer questions the reader doesn't have.** Preempted objections and design-time
  worries a reader wouldn't share are padding. An alternative earns a place only if someone
  would actively advocate it as better.
- **Name what it's for, not how it works.** The reader needs the term for a mechanism's purpose,
  not a narration of its implementation.
- **Describe code relationships literally.** Purpose gets a name; connections get plain verbs —
  what calls what, what writes where, and when.
- **Refer by name, never by number.** A decision's list position or a bare issue number means
  nothing to a cold reader — restate the rule or use its title.
- **Strip local paths.** Prose that leaves this machine names files by repo-relative path — an
  absolute path here resolves nowhere else.
- **Don't assume carried context.** Naming a ticket, a gap, or a mitigation means saying what it
  is and what it was guarding against.
- **One idea per sentence, active voice, no noun stack over three, no metaphor carrying load.**
  (ASD-STE100's comprehension rules — skip its approved-word list, which flattens the voice.)

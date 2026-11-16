# `deep`: several independent reviewers

`deep` replaces the single reviewer of section 3 in [`SKILL.md`](SKILL.md) with three, and adds a
cross-reference to the verify step. Everything after verification (posting, thread status, the
user's notes, fixes) is unchanged.

## Reviewers

- Two Claude subagents (`general-purpose`), one on `opus` and one on `sonnet`, set with the
  `Agent` tool's `model` parameter. Two reviewers on one model share blind spots, so their
  agreement says little.
- `cursor-agent` on a model that is not Claude.

Launch all three in the same turn.

## One prompt, byte-identical

Build one prompt and give every reviewer the same bytes, so that a difference between their
findings is a difference between reviewers and not between phrasings. It holds what section 3
lists, with two changes:

- Embed each changeset's diff (`git diff <base>..<head>`) under its name and range, since
  `cursor-agent` runs read-only and may not be able to run git.
- Embed the full text of the standards docs and the spec instead of their paths.

## `cursor-agent`

Write the prompt to a temp file with a random suffix, then run from the repo root:

```bash
cursor-agent -p --mode plan --output-format text --model <model> "$(cat /tmp/review-prompt-<rand>.txt)"
```

`--mode plan` is mandatory. It is read-only, while bare `-p` has full write and shell access.
Pick `<model>` from `cursor-agent --list-models`, preferring a GPT entry. When its entry shows
the model takes parameters, pass reasoning effort with the bracket override
(`--model '<model>[effort=high]'`).

When `cursor-agent` is missing or errors, launch a third Claude subagent on `haiku` in its place
and say so in the chat report.

## Verify

The order in section 3 matters more here: list and merge every finding from all three reviewers,
noting who raised each, before you read any source.

- Do not dismiss a finding because one reviewer alone raised it. The lone reviewer sometimes
  caught the bug the others missed.
- Agreement between a Claude reviewer and `cursor-agent` is real corroboration. Agreement between
  the two Claude reviewers is weaker. Neither replaces tracing the finding against source.

In chat, add to the dismissed count a table of reviewer by CONFIRMED finding, showing who caught
each one.

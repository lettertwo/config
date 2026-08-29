# Voice rule calibration

`bin/voice-lint-test` checks that each rule in `styles/Voice/` still *fires*.
This recipe checks whether a rule is *right*: whether it catches Claude's drift
without catching my own writing. The two are independent, and a rule can pass
the test suite while being actively harmful.

Run this after adding or rewriting a rule, or after editing `voice.md`'s Never
or Vocabulary sections. Not per commit.

Measure against my own repos only. The `commit-msg` hook is global, so it
reaches work repos too, but those opt out with `git config voice.lint false`
rather than being calibrated against.

## Why it exists

The first version of the package shipped three rules that measurement killed.
`Passive` fired at 4.65 per 1000 words on Claude's output and **10.69** on mine,
so it flagged my voice 2.3x harder than the drift it was meant to catch.
`NounStack` looked good at a 3.2x ratio and was **100% false positives** on a
14-hit sample, all of them headings, PR titles, and backticked identifiers.
`Hedging` produced zero hits on Claude and three on me. None of that is visible
from reading the rule. It only shows up against real prose.

## 1. Build the two corpora

**A, recent Claude-authored artifacts.** PR bodies are the best source; commit
bodies work too but are short.

    gh pr list --repo <owner>/<repo> --state all --limit 60 \
      --json number,title,body,createdAt,author

**B, my own pre-AI writing.** Anything before the assistant was in the loop.

    gh api -X GET search/issues -f q='author:lettertwo type:pr created:<2024-01-01' \
      -f per_page=100 --jq '.items[] | select((.body|length)>200) | .body'

Aim for comparable sizes. The run that produced the numbers above was 11,819
words against 12,720.

## 2. Filter the bots

Do this before measuring anything. Dependabot and release-plz bodies are not my
prose and not Claude's, and they dominate the result: excluding them cut corpus
A's `ParticipialTrailer` from 40 hits to 17 and removed every `Announcements`
hit. Drop any PR whose author or body mentions `dependabot` or `release-plz`.

## 3. Measure

Run `vale --output=JSON` over each corpus, tally by rule, and normalize per 1000
words. Report `A/1kw`, `B/1kw`, and the ratio `A/B`.

A rule firing fewer than ~10 times across ~12k words has no usable ratio. Leave
it unjudged rather than reading noise.

## 4. Verdict by ratio

- **Below 1.0: delete.** The rule fires harder on my voice than on the drift.
  This is not fixable by tightening the pattern; the rule is measuring
  something I do.
- **Near 1.0: no signal.** Delete unless step 5 shows a 0% false-positive rate,
  which is how `Vocabulary` survived at 1.0x.
- **Above 1.0: go to step 5 before keeping.** A high ratio is necessary and not
  sufficient. `NounStack` was 3.2x and worthless.

`EmDash` is the shape to look for: **4.23 per 1000 words in Claude's output and
0.00 in mine.**

## 5. Read the hits

Sample 14 for a high-volume rule, read all of them for a low-volume one, and
classify each as a true or false positive by hand. There is no shortcut here.

Above roughly 30% false positives, demote the rule to `suggestion` or rewrite
the pattern. At or near zero, keep it at `error`.

## 6. Two traps that invert the answer

**Corpus B predates `voice.md`.** A genuine hit there means the rule postdates
the writing, not that the rule over-applies. `It turns out` is banned and
appears 4 times in my Parcel writeups; that is the rule working, not failing.
Separate "this rule over-applies to my voice" from "I wrote this before the
rule existed."

**Vale masks code spans as asterisks**, and the part-of-speech tagger reads the
result as nouns. Any rule using `tag:` will fire on headings, PR titles, and
backticked identifiers. Check for that before believing a tag-based rule's
numbers.

## Output

A table of rule, `A/1kw`, `B/1kw`, ratio, false-positive rate, and verdict.
Delete what the numbers condemn rather than keeping it at a lower severity; a
rule that does not discriminate is noise at every level.

## Not part of this

Whether a *model* can judge the rules Vale cannot reach was tested once, in a
blind A/B against these same corpora, and the answer was no: three judge
configurations each flagged only my documents and zero of Claude's. See the
`project-voice-gate` memory. Do not redo it without a corpus that controls for
topic and era, which the git-workon and Parcel corpora do not.

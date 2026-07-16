// Shared code-review workflow
// ---------------------------------------------------------------------------
// The canonical review pipeline for BOTH /code-review (one diff) and
// /stack-review (one diff per branch in a stack). Read this file and pass its
// contents inline to the Workflow tool.
//
// A "review unit" is one diff scope. /code-review builds a single unit
// (fixed-point...HEAD in the cwd); /stack-review builds one unit per branch
// (parent...branch in that branch's worktree). Everything below is identical
// for both — that's the point: stack-review reviews by REUSING this file
// rather than redefining the axes, the smell baseline, or the verify/fix loop.
//
// args shape:
// {
//   units: [{
//     label,                 // human label for progress/report, e.g. branch name or "HEAD"
//     worktree,              // dir to run git in (repo root for code-review; per-branch worktree for stack)
//     base, head,            // diff is `git -C <worktree> diff <base>...<head>` (three-dot / merge-base)
//     standardsSources,      // [absolute paths] repo files documenting coding standards (may be empty)
//     specSource,            // { path?, contents? } or null — null means "no spec; skip Spec axis for this unit"
//     descendants,           // [branch names] upstack branches touching the same area (stack only; [] otherwise)
//     userOwned              // bool — worktree predates us (stack only); code-review passes false
//   }],
//   flags: { fix },          // apply + commit confirmed findings that carry a concrete suggestedFix
//   effort,                  // 'low' | 'medium' | 'high' | 'max'
//   dependentStack           // stack only: fixes must serialize with restack, so this workflow reviews+verifies only
// }
//
// Pipeline per unit: Review (Standards ∥ Spec) -> Verify (adversarial) -> Fix (+ test gate).
// Journaling/resume is handled by the Workflow runtime (every agent() call is journaled).

export const meta = {
  name: 'code-review',
  description: 'Effort-gated multi-axis (Correctness + Standards + Spec) review, adversarially verified, with optional autofix — over one diff or a whole stack',
  phases: [
    { title: 'Review', detail: 'Correctness / Standards / Spec sub-agents (gated by effort) in parallel, scoped to each unit\'s diff' },
    { title: 'Verify', detail: 'Independent adversarial re-check of every finding before it counts' },
    { title: 'Fix', detail: 'Apply and commit one fix per confirmed finding that has a concrete suggestedFix, then gate on tests' },
  ],
}

// args may arrive as a JSON string depending on how the caller passed it — tolerant-parse.
const cfg = typeof args === 'string' ? JSON.parse(args) : args
const { units, flags, effort, dependentStack } = cfg
const doFix = flags && flags.fix && !dependentStack

// The smell baseline travels with the workflow so the Standards axis applies
// even in a repo that documents nothing. Fowler, Refactoring ch.3. Each entry
// is a labelled heuristic ("possible X"), never a hard violation; a documented
// repo standard always overrides it, and anything tooling enforces is skipped.
const SMELL_BASELINE = `SMELL BASELINE (always judgement calls; a documented repo standard overrides any of these; skip whatever tooling enforces):
- Mysterious Name — a function/variable/type whose name doesn't reveal what it does or holds. Fix: rename; if no honest name comes, the design's murky.
- Duplicated Code — the same logic shape in more than one hunk/file in the change. Fix: extract the shared shape, call it from both.
- Feature Envy — a method that reaches into another object's data more than its own. Fix: move the method onto the data it envies.
- Data Clumps — the same few fields/params keep travelling together. Fix: bundle them into one type, pass that.
- Primitive Obsession — a primitive/string standing in for a domain concept that deserves its own type. Fix: give the concept its own small type.
- Repeated Switches — the same switch/if-cascade on the same type recurs across the change. Fix: polymorphism, or one shared map.
- Shotgun Surgery — one logical change forces scattered edits across many files. Fix: gather what changes together into one module.
- Divergent Change — one file/module is edited for several unrelated reasons. Fix: split so each module changes for one reason.
- Speculative Generality — abstraction/params/hooks added for needs the spec doesn't have. Fix: delete it; inline back until a real need shows.
- Message Chains — long a.b().c().d() navigation the caller shouldn't depend on. Fix: hide the walk behind one method on the first object.
- Middle Man — a class/function that mostly just delegates onward. Fix: cut it, call the real target direct.
- Refused Bequest — a subclass/implementer that ignores or overrides most of what it inherits. Fix: drop inheritance, use composition.`

const EFFORT_INSTRUCTIONS = {
  low:    'Focus only on the most obvious, verifiable issues. Skip anything uncertain.',
  medium: 'Find clear issues and unambiguous violations. Skip nitpicks.',
  high:   'Be thorough: find all real issues. Lean toward including uncertain findings if you can verify them.',
  max:    'Exhaustive pass: report everything ≥80 confidence. Accept some noise to avoid missing real issues.',
}
const effortLine = EFFORT_INSTRUCTIONS[effort] || EFFORT_INSTRUCTIONS.medium

// Effort gates WHICH axes run — the lever that controls cost. Correctness is
// the floor (it's the point of a review); Standards and Spec layer on with
// effort. Spec additionally requires a resolved spec source per unit. The
// verify agent batches every axis's findings into one pass, so it never
// multiplies with axis count.
const AXES_BY_EFFORT = {
  low:    ['correctness'],
  medium: ['correctness', 'standards'],
  high:   ['correctness', 'standards', 'spec'],
  max:    ['correctness', 'standards', 'spec'],
}
const axes = AXES_BY_EFFORT[effort] || AXES_BY_EFFORT.medium
const runStandards = axes.includes('standards')
const runSpec = axes.includes('spec')

const FINDINGS_SCHEMA = {
  type: 'object',
  required: ['findings'],
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        required: ['title', 'file', 'lines', 'kind', 'severity', 'confidence', 'description', 'suggestedFix', 'mayBeAddressedUpstack'],
        properties: {
          title: { type: 'string' },
          file: { type: 'string' },
          lines: { type: 'string' },
          kind: { type: 'string', description: 'Correctness: "bug" | "efficiency". Standards: "standard-violation" | "smell". Spec: "missing" | "scope-creep" | "wrong-impl".' },
          severity: { type: 'string', enum: ['hard', 'judgement'], description: 'hard = definite bug/documented-standard breach/definite spec gap; judgement = baseline smell, style call, or debatable impact' },
          confidence: { type: 'number' },
          description: { type: 'string', description: 'For a standards finding, cite the standard (file + rule) or name the smell and quote the hunk. For a spec finding, quote the spec line.' },
          suggestedFix: { type: 'string', description: 'Concrete replacement code or a clear minimal change; empty string if too context-dependent to write safely (spec gaps are usually empty).' },
          mayBeAddressedUpstack: { type: 'string', description: 'Name of upstack branch if the same lines are also modified there, else empty string' },
        },
      },
    },
  },
}

const VERIFY_SCHEMA = {
  type: 'object',
  required: ['verdicts'],
  properties: {
    verdicts: {
      type: 'array',
      items: {
        type: 'object',
        required: ['title', 'confirmed', 'note'],
        properties: {
          title: { type: 'string', description: 'Must match the finding title exactly' },
          confirmed: { type: 'boolean' },
          note: { type: 'string', description: 'One sentence: why confirmed, or why refuted' },
        },
      },
    },
  },
}

const FIX_SCHEMA = {
  type: 'object',
  required: ['applied', 'skipped'],
  properties: {
    applied: {
      type: 'array',
      items: {
        type: 'object',
        required: ['title', 'commitMessage', 'sha'],
        properties: { title: { type: 'string' }, commitMessage: { type: 'string' }, sha: { type: 'string' } },
      },
    },
    skipped: {
      type: 'array',
      items: {
        type: 'object',
        required: ['title', 'reason'],
        properties: { title: { type: 'string' }, reason: { type: 'string' } },
      },
    },
  },
}

const TEST_GATE_SCHEMA = {
  type: 'object',
  required: ['ran', 'passed', 'summary'],
  properties: {
    ran: { type: 'boolean', description: 'false if no recognizable project test command was found' },
    passed: { type: 'boolean' },
    summary: { type: 'string', description: 'The one-line ok/FAIL summary the runner printed, or a short reason when ran=false' },
  },
}

// ---- prompt builders --------------------------------------------------------

const diffCmd = (u) => `git -C ${u.worktree} diff ${u.base}...${u.head}`

const commonRules = `DO NOT report:
- Pre-existing issues on lines not in this diff
- Lint / type-checker / formatting issues (CI catches these)
- Nitpicks a senior engineer wouldn't call out
- Missing test coverage
- Issues suppressed with a lint-ignore comment

CONFIDENCE SCORING:
  0   = false positive
  25  = possibly real, couldn't verify
  50  = real but minor
  75  = verified real, meaningful impact OR directly called out in a documented standard/spec
  100 = confirmed, direct evidence
Only return findings with confidence ≥ 80.`

const upstackClause = (u) =>
  (u.descendants && u.descendants.length)
    ? `\nSTACK-AWARE ANNOTATION: this branch is part of a stack. Upstack branches also modifying this area: [${u.descendants.join(', ')}]. For any finding whose affected lines are also modified by one of those branches, set mayBeAddressedUpstack to that branch name. Otherwise set it to empty string.`
    : `\nSet mayBeAddressedUpstack to empty string for every finding (this is not a stacked review).`

function correctnessPrompt(u) {
  return `You are the CORRECTNESS axis of a ${effort}-effort code review of ${u.label}, in the git worktree at ${u.worktree}.

DIFF SCOPE — review ONLY the changes this diff introduces:
  ${diffCmd(u)}

Hunt for defects the code will actually hit at runtime — kind="bug" unless it's purely a performance issue (kind="efficiency"):
- BUGS: logic errors, off-by-one, null/undefined access without a guard, missing await on a promise, unhandled async rejection / missing error handling, race conditions, stale closure captures, incorrect hook dependency arrays (missing deps in useEffect/useCallback/useMemo), wrong or missing required props/args, resource leaks, incorrect boundary/empty-input handling.
- EFFICIENCY: work that is needlessly expensive on a hot path — inline object/array literals as props forcing re-renders, missing memoization for expensive computations, O(n²) where O(n) is easy, redundant network/IO in a loop. Only flag efficiency when the cost is real, not theoretical.

A definite defect is severity="hard"; a plausible-but-context-dependent one is severity="judgement".

${effortLine}

${commonRules}
${upstackClause(u)}

Include a concrete suggestedFix (replacement code or a clear minimal change) where you safely can; empty string otherwise.`
}

function standardsPrompt(u) {
  const sources = (u.standardsSources && u.standardsSources.length)
    ? u.standardsSources.map(p => `  ${p}`).join('\n')
    : '  (none found in this repo)'
  return `You are the STANDARDS axis of a ${effort}-effort code review of ${u.label}, in the git worktree at ${u.worktree}.

DIFF SCOPE — review ONLY the changes this diff introduces:
  ${diffCmd(u)}

Documented repo standards to check against (read each; may be empty):
${sources}

${SMELL_BASELINE}

Report, per file/hunk: (a) every place the diff violates a documented standard — cite the standard (file + the rule), kind="standard-violation"; and (b) any baseline smell you spot — name it, kind="smell", and quote the hunk. Documented-standard breaches may be severity="hard"; baseline smells are ALWAYS severity="judgement". A documented repo standard overrides the baseline where they conflict.

${effortLine}

${commonRules}
${upstackClause(u)}

Include a concrete suggestedFix (replacement code or a clear minimal change) where you safely can; empty string otherwise.`
}

function specPrompt(u) {
  const spec = u.specSource.contents
    ? `Spec contents:\n${u.specSource.contents}`
    : `Spec file (read it): ${u.specSource.path}`
  return `You are the SPEC axis of a ${effort}-effort code review of ${u.label}, in the git worktree at ${u.worktree}.

DIFF SCOPE — the code being reviewed:
  ${diffCmd(u)}

${spec}

Report: (a) requirements the spec asked for that are missing or partial — kind="missing"; (b) behaviour in the diff that wasn't asked for (scope creep) — kind="scope-creep"; (c) requirements that look implemented but wrong — kind="wrong-impl". Quote the spec line in the description for each finding. A definite gap is severity="hard"; a debatable one is severity="judgement".

${effortLine}

${commonRules}
${upstackClause(u)}

suggestedFix is usually empty for spec gaps (they're missing work, not local edits) — only fill it when the fix is a concrete, safe local change.`
}

// ---- pipeline ---------------------------------------------------------------

const results = await pipeline(
  units,

  // Stage 1: Review — one agent per gated axis, all scoped to this unit's
  // diff and run in parallel. Kept as independent agents so the axes don't
  // pollute each other's context (see /code-review "Why the axes are separate").
  // Which axes run is set by effort (AXES_BY_EFFORT); Spec also needs a source.
  // Explicit phase avoids racing the global phase() state from inside parallel().
  async (u) => {
    const willSpec = runSpec && !!u.specSource
    const axesRun = ['correctness', ...(runStandards ? ['standards'] : []), ...(willSpec ? ['spec'] : [])]
    log(`Reviewing ${u.label} (${axesRun.join(' + ')})...`)

    const [correctness, standards, spec] = await parallel([
      () => agent(correctnessPrompt(u), { label: `correctness:${u.label}`, phase: 'Review', schema: FINDINGS_SCHEMA }),
      () => runStandards
        ? agent(standardsPrompt(u), { label: `standards:${u.label}`, phase: 'Review', schema: FINDINGS_SCHEMA })
        : Promise.resolve(null),
      () => willSpec
        ? agent(specPrompt(u), { label: `spec:${u.label}`, phase: 'Review', schema: FINDINGS_SCHEMA })
        : Promise.resolve(null),
    ])

    // null = axis did not run (gated off, or no spec source); [] = ran, no findings.
    const tag = (r, axis) => r ? (r.findings || []).map(f => ({ ...f, axis })) : null
    const correctnessFindings = tag(correctness, 'correctness') || []
    const standardsFindings = runStandards ? tag(standards, 'standards') : null
    const specFindings = willSpec ? tag(spec, 'spec') : null
    log(`${u.label}: ${correctnessFindings.length} correctness` +
        `${standardsFindings ? `, ${standardsFindings.length} standards` : ''}` +
        `${specFindings ? `, ${specFindings.length} spec` : ''}`)
    return { ...u, axesRun, correctnessFindings, standardsFindings, specFindings }
  },

  // Stage 2: Verify — one adversarial agent per unit re-checks every finding
  // (all active axes). It gets only the diff and each claim, not the reviewer's
  // reasoning, and tries to refute. Fail-closed: an unmatched verdict is
  // treated as unconfirmed. Cuts false positives before report/autofix.
  async (prev, u) => {
    const all = [...prev.correctnessFindings, ...(prev.standardsFindings || []), ...(prev.specFindings || [])]
    if (all.length === 0) {
      log(`${u.label}: no findings to verify`)
      return { ...prev, correctnessFindings: [], rejected: [] }
    }
    log(`Verifying ${all.length} finding(s) on ${u.label}...`)
    const verify = await agent(
      `You are adversarially fact-checking a code review of ${u.label}, in the git worktree at ${u.worktree}.

DIFF SCOPE — the same diff the reviewers saw:
  ${diffCmd(u)}

Candidate findings (you did NOT write these — verify each independently, don't assume it's correct):
${JSON.stringify(all.map(f => ({ title: f.title, axis: f.axis, file: f.file, lines: f.lines, kind: f.kind, description: f.description })), null, 2)}

For each finding, read the actual lines (for spec findings, judge whether the claimed gap is really absent from the diff) and decide: real issue, or false positive (misread code, guard already exists, not reachable, requirement actually met elsewhere)? Try to refute it — only confirm if you can't.

Return one verdict per finding (title must match exactly), each with a one-sentence note.`,
      { label: `verify:${u.label}`, phase: 'Verify', schema: VERIFY_SCHEMA }
    )

    const verdict = new Map(verify.verdicts.map(v => [v.title, v]))
    const rejected = []
    const keep = (f) => {
      const v = verdict.get(f.title)
      if (v && v.confirmed) return true
      rejected.push({ title: f.title, axis: f.axis, reason: v ? v.note : 'no verifier verdict returned' })
      return false
    }
    const correctnessFindings = prev.correctnessFindings.filter(keep)
    const standardsFindings = prev.standardsFindings ? prev.standardsFindings.filter(keep) : null
    const specFindings = prev.specFindings ? prev.specFindings.filter(keep) : null
    const kept = correctnessFindings.length + (standardsFindings ? standardsFindings.length : 0) + (specFindings ? specFindings.length : 0)
    log(`${u.label}: ${kept}/${all.length} confirmed`)
    return { ...prev, correctnessFindings, standardsFindings, specFindings, rejected }
  },

  // Stage 3: Fix (only when flags.fix and not a dependent stack). Applies
  // confirmed findings that carry a concrete suggestedFix, one commit each,
  // then gates on tests. Spec gaps (empty suggestedFix) fall through to skipped.
  async (prev, u) => {
    const confirmed = [...prev.correctnessFindings, ...(prev.standardsFindings || []), ...(prev.specFindings || [])]
    const base = { ...prev, findings: confirmed }
    if (!doFix) return { ...base, applied: null, skipped: null, testGate: null }
    if (confirmed.length === 0) {
      log(`${u.label}: no confirmed findings to fix`)
      return { ...base, applied: [], skipped: [], testGate: null }
    }

    const dirty = await agent(
      `Run: git -C ${u.worktree} status --porcelain
Return {"dirty": true} if there is any output, else {"dirty": false}.`,
      { label: `dirty-check:${u.label}`, phase: 'Fix', schema: { type: 'object', required: ['dirty'], properties: { dirty: { type: 'boolean' } } } }
    )
    if (u.userOwned && dirty && dirty.dirty) {
      log(`${u.label}: worktree has uncommitted changes — skipping fixes`)
      return { ...base, applied: [], skipped: confirmed.map(f => ({ title: f.title, reason: 'Worktree has uncommitted changes; fix manually' })), testGate: null }
    }

    log(`${u.label}: applying up to ${confirmed.length} fix(es)...`)
    const fix = await agent(
      `You are applying autofixes in the git worktree at ${u.worktree} (${u.label}).

Confirmed findings:
${JSON.stringify(confirmed, null, 2)}

For each finding:
1. Open ${u.worktree}/<file> and apply suggestedFix with the Edit tool — minimal change only.
2. Skip (record reason) if: suggestedFix is empty, the fix is unsafe/ambiguous, it's a spec gap requiring new feature work, or it spans multiple files non-obviously.
3. After each applied fix, commit immediately (ONE commit per finding):
   git -C ${u.worktree} add <file>
   git -C ${u.worktree} commit -m "fix: <concise description of this finding>"
   Capture SHA: git -C ${u.worktree} log -1 --format=%H

Rules: one commit per finding, never batch; message "fix: <specific>" with no ticket prefix; no new imports unless strictly required; when unsure a fix is safe, skip it.`,
      { label: `fix:${u.label}`, phase: 'Fix', schema: FIX_SCHEMA }
    )

    // Test gate: Rust workspaces route through cargo-gate; other projects use
    // their own discoverable test command; untestable projects aren't a failure.
    let testGate = { ran: false, passed: true, summary: 'no fixes applied; gate skipped' }
    if (fix.applied.length > 0) {
      log(`${u.label}: running test gate...`)
      testGate = await agent(
        `You just committed ${fix.applied.length} fix commit(s) in the git worktree at ${u.worktree}. Verify they didn't break anything.

1. If ${u.worktree}/Cargo.toml exists (or a workspace root above it), run:
   ~/.claude/bin/cargo-gate test --manifest-path <path-to-nearest-Cargo.toml-or-workspace-root>
2. Otherwise find a project test command (package.json "scripts.test", a Makefile "test" target, etc.) in ${u.worktree} and run it directly — do NOT invent one.
3. If none is discoverable, return {"ran": false, "passed": true, "summary": "no test command found"}.

Report the one-line ok/FAIL summary the command printed (pass cargo-gate's own compressed output through verbatim; for other runners summarize pass/fail in one line).`,
        { label: `test-gate:${u.label}`, phase: 'Fix', schema: TEST_GATE_SCHEMA }
      )
      if (testGate.ran && !testGate.passed) log(`${u.label}: test gate FAILED after fixes — flag for manual attention (${testGate.summary})`)
    }

    return { ...base, ...fix, testGate }
  }
)

// Normalize into a stable shape the calling skill formats for the user.
return {
  results: results.filter(Boolean).map(r => ({
    label: r.label,
    branch: r.branch,
    axesRun: r.axesRun,              // e.g. ['correctness','standards'] — which axes actually ran
    correctness: r.correctnessFindings || [],
    standards: r.standardsFindings,  // null = axis gated off at this effort
    spec: r.specFindings,            // null = gated off OR no spec source for this unit
    rejected: r.rejected || [],
    applied: r.applied,              // null unless a fix stage ran
    skipped: r.skipped,
    testGate: r.testGate,
  })),
}

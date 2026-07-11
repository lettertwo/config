// Stack review workflow — generalized from the working run on zip-5423's child stack.
// Passed to the Workflow tool inline. Receives args from the main skill agent after discovery.
//
// args shape:
// {
//   branches: [{branch, parent, worktree, label, userOwned}],
//   flags: {fix, comment},
//   effort: 'low'|'medium'|'high'|'max',
//   dependentStack: boolean
// }
//
// Pipeline stages: Review -> Verify (adversarial) -> Fix (+ test gate).
// Journaling/resume is handled by the Workflow runtime itself (every agent()
// call is journaled) — nothing to implement here for that.

export const meta = {
  name: 'stack-review',
  description: 'Parallel code review (adversarially verified) and optional parallel fix of stacked branches',
  phases: [
    { title: 'Review', detail: 'Multi-lens review scoped to immediate-parent diff per branch' },
    { title: 'Verify', detail: 'Independent adversarial re-check of each finding before it counts' },
    { title: 'Fix', detail: 'Apply and commit one fix per confirmed finding (independent branches only), then gate on tests' },
  ],
}

// args may arrive as a JSON string depending on how the caller passed it — tolerant-parse.
const cfg = typeof args === 'string' ? JSON.parse(args) : args
const { branches, flags, effort, dependentStack } = cfg

const EFFORT_INSTRUCTIONS = {
  low:    'Focus only on the most obvious correctness bugs. Skip anything uncertain.',
  medium: 'Find clear correctness bugs and obvious reuse/simplification wins. Skip nitpicks.',
  high:   'Be thorough: find all real bugs and meaningful simplification/efficiency issues. Lean toward including uncertain findings if you can verify them.',
  max:    'Exhaustive pass: report everything ≥80 confidence across both axes. Accept some noise to avoid missing real issues.',
}

const REVIEW_SCHEMA = {
  type: 'object',
  required: ['branch', 'findings'],
  properties: {
    branch: { type: 'string' },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        required: ['title', 'file', 'lines', 'kind', 'confidence', 'description', 'suggestedFix', 'mayBeAddressedUpstack'],
        properties: {
          title: { type: 'string' },
          file: { type: 'string' },
          lines: { type: 'string' },
          kind: { type: 'string', enum: ['bug', 'simplification', 'efficiency', 'reuse'] },
          confidence: { type: 'number' },
          description: { type: 'string' },
          suggestedFix: { type: 'string' },
          mayBeAddressedUpstack: { type: 'string', description: 'Name of upstack branch if the same lines are also modified there, else empty string' },
        },
      },
    },
  },
}

const VERIFY_SCHEMA = {
  type: 'object',
  required: ['branch', 'verdicts'],
  properties: {
    branch: { type: 'string' },
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
  required: ['branch', 'applied', 'skipped'],
  properties: {
    branch: { type: 'string' },
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
    summary: { type: 'string', description: 'The one-line ok/FAIL summary cargo-gate (or the project test runner) printed, or a short reason ran=false' },
  },
}

const doFix = flags.fix && !dependentStack

const results = await pipeline(
  branches,

  // Stage 1: Review
  async (item) => {
    log(`Reviewing ${item.label}...`)

    const descendants = branches.filter(b => {
      let cur = b
      while (cur && cur.branch !== item.branch) {
        cur = branches.find(x => x.branch === cur.parent)
      }
      return cur && cur.branch === item.branch && b.branch !== item.branch
    })
    const descendantNames = descendants.map(d => d.branch).join(', ')

    const review = await agent(
      `You are doing a ${effort}-effort code review of branch ${item.branch} in the git worktree at ${item.worktree}.

DIFF SCOPE — review ONLY the changes introduced by this branch relative to its immediate parent:
  git -C ${item.worktree} diff ${item.parent}...${item.branch}

Also read the following for project guidance (if they exist):
  ${item.worktree}/CLAUDE.md
  ${item.worktree}/frontend/CLAUDE.md

REVIEW AXES:
1. CORRECTNESS BUGS: Logic errors, null/undefined access without guard, incorrect hook dependencies (missing in useEffect/useCallback/useMemo deps array), missing error handling for async calls, wrong prop types or missing required props, off-by-one, race conditions, stale closure captures.
2. REUSE / SIMPLIFICATION / EFFICIENCY: Duplicated logic that already exists in the modified files or nearby components, components doing more than one thing, inefficient re-renders (inline object/array literals as props, missing memoization for expensive computations), verbose patterns where a simpler idiom exists.

EFFORT INSTRUCTION: ${EFFORT_INSTRUCTIONS[effort] || EFFORT_INSTRUCTIONS.medium}

DO NOT report:
- Pre-existing issues on lines not in this diff
- Lint/TypeScript/formatting issues (CI catches these)
- Nitpicks a senior engineer wouldn't call out
- Missing test coverage
- Issues suppressed with a lint-ignore comment
- Issues on unmodified lines

CONFIDENCE SCORING:
  0   = false positive
  25  = possibly real, couldn't verify
  50  = real but minor, low frequency in practice
  75  = verified real, meaningful impact OR directly called out in CLAUDE.md
  100 = confirmed, direct evidence, will happen frequently
Only return findings with confidence ≥ 80.

STACK-AWARE ANNOTATION: This branch is part of a stack. The following branches upstack also modify code in this area: [${descendantNames || 'none'}]. For any finding whose affected lines are also modified by an upstack branch, set mayBeAddressedUpstack to that branch name. Otherwise set it to empty string.

Return the branch name and list of high-confidence findings. For each finding, include a concrete suggestedFix (actual replacement code or a clear description of the minimal change); use empty string if the fix is too context-dependent to write safely.`,
      { label: `review:${item.label}`, phase: 'Review', schema: REVIEW_SCHEMA }
    )
    log(`${item.label}: ${review.findings.length} finding(s)`)
    return { ...item, review }
  },

  // Stage 2: Verify — adversarial re-check. A fresh agent gets only the diff
  // and each finding's claim (not the first reviewer's reasoning) and tries
  // to refute it independently. Cuts false positives before they reach a
  // report or an autofix commit.
  async (prev, item) => {
    const findings = prev.review.findings
    if (findings.length === 0) {
      log(`${item.label}: no findings to verify`)
      return { ...prev, findings: [], rejected: [] }
    }

    log(`Verifying ${findings.length} finding(s) on ${item.label}...`)
    const verify = await agent(
      `You are adversarially fact-checking a code review of branch ${item.branch} in the git worktree at ${item.worktree}.

DIFF SCOPE — the same diff the original review saw:
  git -C ${item.worktree} diff ${item.parent}...${item.branch}

Candidate findings from the first pass (you did not write these — verify them independently, don't assume they're correct):
${JSON.stringify(findings.map(f => ({ title: f.title, file: f.file, lines: f.lines, kind: f.kind, description: f.description })), null, 2)}

For each finding, read the actual lines in the diff and decide: is this a real issue, or a false positive (misread code, guard already exists elsewhere, not actually reachable, etc.)? Try to refute it — only confirm if you can't.

Return one verdict per finding (title must match exactly), each with a one-sentence note explaining the confirm/refute decision.`,
      { label: `verify:${item.label}`, phase: 'Verify', schema: VERIFY_SCHEMA }
    )

    const verdictByTitle = new Map(verify.verdicts.map(v => [v.title, v]))
    const confirmed = []
    const rejected = []
    for (const f of findings) {
      const v = verdictByTitle.get(f.title)
      // Fail closed: no matching verdict (schema drift, title mismatch) is treated as unconfirmed.
      if (v && v.confirmed) {
        confirmed.push(f)
      } else {
        rejected.push({ title: f.title, reason: v ? v.note : 'no verifier verdict returned' })
      }
    }
    log(`${item.label}: ${confirmed.length}/${findings.length} confirmed`)
    return { ...prev, findings: confirmed, rejected }
  },

  // Stage 3: Fix (independent stacks + --fix only), gated on tests via cargo-gate.
  async (prev, item) => {
    if (!doFix) return { branch: item.branch, findings: prev.findings, rejected: prev.rejected, applied: null, skipped: null, testGate: null }

    const findings = prev.findings
    if (findings.length === 0) {
      log(`${item.label}: no confirmed findings to fix`)
      return { branch: item.branch, findings: [], rejected: prev.rejected, applied: [], skipped: [], testGate: null }
    }

    const dirtyCheck = await agent(
      `Run: git -C ${item.worktree} status --porcelain
Return JSON: {"dirty": true} if there is any output, {"dirty": false} if empty.`,
      { label: `dirty-check:${item.label}`, phase: 'Fix', schema: { type: 'object', required: ['dirty'], properties: { dirty: { type: 'boolean' } } } }
    )
    if (item.userOwned && dirtyCheck && dirtyCheck.dirty) {
      log(`${item.label}: worktree has uncommitted changes — skipping fixes`)
      return {
        branch: item.branch,
        findings,
        rejected: prev.rejected,
        applied: [],
        skipped: findings.map(f => ({ title: f.title, reason: 'Worktree has uncommitted changes; fix manually' })),
        testGate: null,
      }
    }

    log(`${item.label}: applying ${findings.length} fix(es)...`)
    const fix = await agent(
      `You are applying autofixes in the git worktree at ${item.worktree} for branch ${item.branch}.

Confirmed findings:
${JSON.stringify(findings, null, 2)}

For each finding:
1. Open ${item.worktree}/<file> and apply suggestedFix using the Edit tool — minimal change only.
2. Skip (record reason) if: suggestedFix is empty string, the fix is unsafe/ambiguous, or spans multiple files non-obviously.
3. After each fix, commit immediately (one commit per finding):
   git -C ${item.worktree} add <file>
   git -C ${item.worktree} commit -m "fix: <concise description of this specific finding>"
   Capture SHA: git -C ${item.worktree} log -1 --format=%H

Rules:
- ONE commit per finding — never batch
- Commit message: "fix: <specific>" — no ticket prefix
- Do not introduce new imports unless strictly required
- If unsure whether a fix is safe, skip it`,
      { label: `fix:${item.label}`, phase: 'Fix', schema: FIX_SCHEMA }
    )

    // Test gate: run after fixes land, before they're reported as clean.
    // Rust workspaces route through cargo-gate (WS3) for the serialize +
    // filter behavior; other stacks fall back to whatever test command the
    // project defines, or report ran:false rather than guess at one.
    let testGate = { ran: false, passed: true, summary: 'no fixes applied; gate skipped' }
    if (fix.applied.length > 0) {
      log(`${item.label}: running test gate...`)
      testGate = await agent(
        `You just committed ${fix.applied.length} fix commit(s) in the git worktree at ${item.worktree}. Verify they didn't break anything.

1. If ${item.worktree}/Cargo.toml exists (or a workspace root above it does), run:
   ~/.claude/bin/cargo-gate test --manifest-path <path-to-nearest-Cargo.toml-or-workspace-root>
   (cd into the workspace root first if unsure of the right --manifest-path.)
2. Otherwise, look for a project test command (package.json "scripts.test", a Makefile "test" target, etc.) in ${item.worktree} and run it directly — do NOT invent a command if none is discoverable.
3. If no test command can be found at all, return {"ran": false, "passed": true, "summary": "no test command found"} — an untestable project isn't a fix failure.

Report the one-line ok/FAIL summary the command printed (cargo-gate already compresses its own output — pass that through verbatim; for other runners, summarize pass/fail counts in one line).`,
        { label: `test-gate:${item.label}`, phase: 'Fix', schema: TEST_GATE_SCHEMA }
      )
      if (testGate.ran && !testGate.passed) {
        log(`${item.label}: test gate FAILED after fixes — flagging for manual attention (${testGate.summary})`)
      }
    }

    return { branch: item.branch, findings, rejected: prev.rejected, ...fix, testGate }
  }
)

return { results: results.filter(Boolean) }

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

export const meta = {
  name: 'stack-review',
  description: 'Parallel code review (and optional parallel fix) of stacked branches',
  phases: [
    { title: 'Review', detail: 'Multi-lens review scoped to immediate-parent diff per branch' },
    { title: 'Fix', detail: 'Apply and commit one fix per finding (independent branches only)' },
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

  // Stage 2: Fix (independent stacks + --fix only)
  async (prev, item) => {
    if (!doFix) return { branch: item.branch, findings: prev ? prev.review.findings : [], applied: null, skipped: null }

    const findings = prev && prev.review ? prev.review.findings : []
    if (findings.length === 0) {
      log(`${item.label}: no findings to fix`)
      return { branch: item.branch, findings: [], applied: [], skipped: [] }
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
        applied: [],
        skipped: findings.map(f => ({ title: f.title, reason: 'Worktree has uncommitted changes; fix manually' })),
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
    return { branch: item.branch, findings, ...fix }
  }
)

return { results: results.filter(Boolean) }

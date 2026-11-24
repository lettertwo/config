import { expect, mock, test } from 'claude-code/testing'

const ROW = { plugin: 'agent-rows', component: 'AgentRow' } as const

const strip = (s: string | undefined) => (s ?? '').replace(/\x1b\[[0-9;]*m/g, '')

function agent(over: Record<string, unknown> = {}) {
  return {
    id: 'a1',
    description: 'Read the review plugin and draft a file list',
    type: 'planner',
    status: 'running',
    kind: 'local_agent',
    taskStatus: 'running',
    label: 'planner',
    startTime: 1_000,
    cwd: '/tmp',
    model: 'claude-sonnet-5-5',
    tokenCount: 12_345,
    tokenSamples: [],
    hasRow: true,
    concurrent: 1,
    depth: 0,
    isBackgroundEnabled: true,
    rowIds: ['a1'],
    ...over,
  }
}

async function bodyFor($: any, on: any, props: Record<string, unknown>) {
  let body: string | undefined
  on('ui.render', { component: 'AgentRow' }, (_: unknown, e: any, next: any) => {
    body = e.props.body
    return next(e)
  })
  const ui = await $.ui.mount({ ...ROW, surface: 'terminal', props: agent(props) })
  await ui.unmount()
  return strip(body)
}

test('a running row reads type · Model · description · tokens · elapsed', async ($, on) => {
  mock.clock(on, { now: 1_000 + 83_000 })
  expect(await bodyFor($, on, {})).toBe(
    'planner · Sonnet · Read the review plugin and draft a file list · 12k · 1m23s',
  )
})

test('an idle row shows its status', async ($, on) => {
  mock.clock(on, { now: 6_000 })
  expect(await bodyFor($, on, { status: 'idle' })).toMatch(/^idle planner · /)
})

test('the description is cut to fit the columns', async ($, on) => {
  mock.clock(on, { now: 6_000 })
  const body = await bodyFor($, on, { columns: 40 })
  expect(body.length).toBeLessThanOrEqual(40)
  expect(body).toMatch(/…/)
  expect(body).toMatch(/ · 12k · 5s$/)
})

test('too few columns drops the description', async ($, on) => {
  mock.clock(on, { now: 6_000 })
  expect(await bodyFor($, on, { columns: 30 })).toBe('planner · Sonnet · 12k · 5s')
})

test('no model and no start time leave those columns out', async ($, on) => {
  expect(await bodyFor($, on, { model: undefined, startTime: 0, tokenCount: 512 })).toBe(
    'planner · Read the review plugin and draft a file list · 512',
  )
})

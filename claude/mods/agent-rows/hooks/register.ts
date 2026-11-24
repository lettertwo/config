import type { Register } from 'claude-code'

// Each agent-list row's body becomes
// `[status] type · Model · description · tokens · elapsed`, cut to the row's columns.

const CYAN = '\x1b[36m'
const DIM = '\x1b[90m'
const RESET = '\x1b[0m'
const SEP = ' · '

function shortModel(id: string | undefined): string {
  if (!id) return ''
  const family = id.replace(/^claude-/, '').split('-')[0] ?? ''
  return family.charAt(0).toUpperCase() + family.slice(1)
}

function fmtTokens(n: number): string {
  return n >= 1000 ? `${Math.floor(n / 1000)}k` : `${n}`
}

function fmtElapsed(ms: number): string {
  const secs = Math.max(0, Math.floor(ms / 1000))
  if (secs >= 3600) return `${Math.floor(secs / 3600)}h${String(Math.floor((secs % 3600) / 60)).padStart(2, '0')}m`
  if (secs >= 60) return `${Math.floor(secs / 60)}m${String(secs % 60).padStart(2, '0')}s`
  return `${secs}s`
}

export const register: Register = on => {
  on('ui.render', { component: 'AgentRow' }, async ($, e, next) => {
    const p = e.props
    const model = shortModel(p.model)

    let marker = ''
    let markerLen = 0
    if (p.status !== 'running') {
      marker = `${DIM}${p.status}${RESET} `
      markerLen = p.status.length + 1
    }

    let tail = fmtTokens(p.tokenCount)
    if (p.startTime > 0) tail += SEP + fmtElapsed((await $.clock.now()) - p.startTime)

    // Budget the description so the visible row fits the measured columns.
    let desc = p.description
    if (p.columns !== undefined) {
      const head = p.type.length + markerLen + (model ? SEP.length + model.length : 0)
      const budget = p.columns - head - SEP.length - tail.length - SEP.length
      if (budget < 8) desc = ''
      else if (desc.length > budget) desc = `${desc.slice(0, budget - 1)}…`
    }

    let body = marker + p.type
    if (model) body += `${DIM}${SEP}${RESET}${CYAN}${model}${RESET}`
    if (desc) body += `${DIM}${SEP}${desc}${RESET}`
    body += `${DIM}${SEP}${tail}${RESET}`

    return next({ ...e, props: { ...p, body } })
  })
}

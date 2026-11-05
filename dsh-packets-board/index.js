/**
 * «Борт пакетов» — половина хоста: читает YAML-шапки шапки пакетов agents/
 * и список живых агентов, отдаёт их клиентской вкладке через HTTP-роут.
 *
 * Статус 0.1.0: заготовка. Парсер шапок — подмножество YAML (key: value
 * внутри --- ... ---), чего хватает гейт-схемы П-61.
 */
import { readFileSync, readdirSync } from 'node:fs'
import path from 'node:path'

export const name = 'dsh-packets-board'
export const inject = ['webServer', 'agents']

function frontmatter(text) {
  const match = text.match(/^---\r?\n([\s\S]*?)\r?\n---/)
  const out = {}
  if (!match) return out
  for (const line of match[1].split(/\r?\n/)) {
    const kv = line.match(/^([A-Za-z_][\w-]*):\s*(.*?)\s*$/)
    if (kv) out[kv[1]] = kv[2].replace(/^['"]|['"]$/g, '')
  }
  return out
}

function board(config, ctx) {
  const packets = []
  let dirs = []
  try {
    dirs = readdirSync(config.agentsDir, { withFileTypes: true })
      .filter((entry) => entry.isDirectory())
      .map((entry) => entry.name)
  } catch (error) {
    return { error: `каталог agents не виден: ${error?.message}`, packets: [], agents: [] }
  }
  for (const dir of dirs) {
    try {
      packets.push({ dir, ...frontmatter(readFileSync(path.join(config.agentsDir, dir, 'README.md'), 'utf8')) })
    } catch {
      packets.push({ dir, status: 'нет README' })
    }
  }
  const agents = []
  try {
    for (const agent of ctx.agents.list()) {
      agents.push({
        id: String(agent.session?.id ?? agent.id ?? ''),
        status: String(agent.status ?? ''),
      })
    }
  } catch (error) {
    console.warn('[packets-board] список агентов недоступен:', error?.message ?? error)
  }
  return { generatedAt: new Date().toISOString(), packets, agents }
}

export function apply(ctx, config = {}) {
  if (typeof config.agentsDir !== 'string' || config.agentsDir === '') {
    console.warn('[packets-board] config.agentsDir не задан — плагин неактивен')
    return
  }
  const route = config.route || '/api/master-packets'
  ctx.effect(() => ctx.webServer.register({
    kind: 'exact',
    path: route,
    handler: async (_req, res) => {
      try {
        res.writeHead(200, { 'content-type': 'application/json; charset=utf-8' })
        res.end(JSON.stringify(board(config, ctx)))
      } catch (error) {
        res.writeHead(500, { 'content-type': 'application/json; charset=utf-8' })
        res.end(JSON.stringify({ error: String(error?.message ?? error) }))
      }
    },
  }), 'packets-board.route')
}

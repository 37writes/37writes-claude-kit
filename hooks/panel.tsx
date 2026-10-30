// /kit 명령과 kit 패널: kit 스킬 목록과 현재 프로젝트 상태를 Claude를 거치지 않고 보여준다.
import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { KitPlan, KitSkill, KitStatus } from '../types'

const PANE = 'kit'
const TITLE = '37writes kit'
const skills = atom({ plugin: 'kit', key: 'skills' } as const, [])
// 0.15에서 devlog 상태를 기획서 목록으로 바꿨다: 예전 모양의 값은 null로 읽는다
const status = atom({ plugin: 'kit', key: 'status' } as const, null, { shape: 'plans-1' })

const CATEGORY = /\*\*구분\*\*:\s*(\S+)/
const PROFILE_MARK = '<!-- 37writes-kit:profile:start -->'
const PLANS_SHOWN = 5

// 설명의 첫 문장만: "…초기화한다. git init, …" → "…초기화한다"
export function summarize(description: string): string {
  const first = description.split(/\.\s/)[0] ?? description
  return first.replace(/\.$/, '')
}

// 작업 흐름 순서. 여기 없는 새 스킬은 뒤에 이름순으로 붙는다
const ORDER = ['harness', 'plan', 'commit', 'check', 'design', 'release', 'blog', 'feedback', 'init']

async function kitSkills($: EngineInterface): Promise<KitSkill[]> {
  const prefix = `${$.plugin.name}:`
  const rank = (name: string) => {
    const i = ORDER.indexOf(name.slice(prefix.length))
    return i === -1 ? ORDER.length : i
  }
  return (await $.command.list())
    .filter(c => c.name.startsWith(prefix))
    .sort((a, b) => rank(a.name) - rank(b.name) || a.name.localeCompare(b.name))
    .map(c => ({ name: c.name, summary: summarize(c.description) }))
}

async function git($: EngineInterface, cwd: string, args: string[]): Promise<string | undefined> {
  const r = await $.process.run(['git', ...args], { cwd, timeoutMs: 5000 }).catch(() => undefined)
  return r && r.exitCode === 0 ? r.stdout.trim() : undefined
}

/** kitlib.kit_repo와 같은 기준: 프로필 표시가 있거나, (호환) docs/devlog가 있으면 kit 프로젝트 */
export function isKitProject(claudeMd: string, hasDevlog: boolean): boolean {
  return claudeMd.includes(PROFILE_MARK) || hasDevlog
}

/** `plans.py --json` 출력 → 패널에 쓰는 기획서 목록. 깨진 출력은 빈 목록 */
export function parsePlans(stdout: string): KitPlan[] {
  let rows: unknown
  try {
    rows = JSON.parse(stdout || '[]')
  } catch {
    return []
  }
  if (!Array.isArray(rows)) return []
  const text = (v: unknown) => (typeof v === 'string' ? v : '')
  const count = (v: unknown) => (typeof v === 'number' ? v : 0)
  return rows
    .filter((r): r is Record<string, unknown> => typeof r === 'object' && r !== null && !r.stale)
    .map(r => ({
      title: text(r.title),
      status: text(r.status),
      branch: text(r.branch),
      worktree: text(r.worktree),
      remaining: count(r.remaining),
      total: count(r.total),
      next: text(r.next),
      conflict: r.conflict === true,
      needsCheck: r.needsCheck === true,
    }))
}

/** 패널 한 줄: 제목 · 상태 · 남은 단계 */
export function planLine(p: KitPlan): string {
  if (p.conflict) return `${p.title} · 충돌 (worktree마다 진행이 다름)`
  const parts = [p.title, p.status, `남은 ${p.remaining}/${p.total}`]
  if (p.needsCheck) parts.push('상태 확인 필요')
  return parts.join(' · ')
}

// 계산은 plans.py 한 곳에 둔다 (SessionStart 훅과 같은 규칙). $.plugin.root는 plugin.json이 있는 폴더
function kitRoot($: EngineInterface): string {
  return $.plugin.root.replace(/[\\/]\.claude-plugin[\\/]?$/, '')
}

async function activePlans($: EngineInterface, cwd: string): Promise<KitPlan[]> {
  const root = kitRoot($)
  const r = await $.process
    .run(['sh', `${root}/scripts/py.sh`, `${root}/scripts/plans.py`, '--cwd', cwd, '--json'], { cwd, timeoutMs: 10000 })
    .catch(() => undefined)
  return r && r.exitCode === 0 ? parsePlans(r.stdout) : []
}

async function projectStatus($: EngineInterface): Promise<KitStatus> {
  const cwd = await $.session.cwd()
  const root = await git($, cwd, ['rev-parse', '--show-toplevel'])
  if (!root) return { isKit: false, plans: [] }
  const repo = root.split('/').pop()
  const read = await $.fs.read(`${root}/CLAUDE.md`).catch(() => '')
  const claudeMd = typeof read === 'string' ? read : ''
  const isKit = isKitProject(claudeMd, await $.fs.exists(`${root}/docs/devlog`))
  const category = isKit ? CATEGORY.exec(claudeMd)?.[1] : undefined
  return { repo, isKit, category, plans: await activePlans($, root) }
}

async function refresh($: EngineInterface): Promise<void> {
  const [list, now] = await Promise.all([kitSkills($), projectStatus($)])
  await update($, skills, () => list)
  await update($, status, () => now)
}

async function isOpen($: EngineInterface): Promise<boolean> {
  return (await $.ui.panes()).some(p => p.id === PANE)
}

// 패널을 열 수 없는 곳(좁은 화면이 아닌 -p 실행 등)에서 대신 보여줄 텍스트
function asText(list: KitSkill[], now: KitStatus | null): string {
  const lines = list.map(s => `/${s.name}  ${s.summary}`)
  if (now?.repo) lines.push('', `이 프로젝트: ${now.repo} (${now.isKit ? (now.category ?? '구분 없음') : 'kit 프로필 없음'})`)
  for (const p of now?.plans ?? []) lines.push(`· ${planLine(p)}`)
  return lines.join('\n')
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const started = await next(e)
    await $.command.register({
      name: 'kit',
      description: 'kit 패널 열기/닫기: 스킬 목록과 진행 중 기획서',
    })
    return started
  })

  on('command.run', { command: 'kit' }, async $ => {
    if (await isOpen($)) {
      await $.ui.close({ id: PANE })
      return { text: 'kit 패널을 닫았습니다.' }
    }
    await refresh($)
    const opened = await $.ui.open({ id: PANE, title: TITLE })
    if (!opened.isPlaced) {
      await $.ui.close({ id: PANE })
      return { text: asText(await read($, skills), await read($, status)) }
    }
    return { text: 'kit 패널을 열었습니다. 다시 /kit 하면 닫힙니다.' }
  })

  // 패널이 열려 있으면 Claude의 답이 끝날 때마다 상태를 새로 읽는다 (기획서 단계 반영)
  on('turn.complete', async ($, e, next) => {
    const done = await next(e)
    if (await isOpen($)) void refresh($).catch(() => undefined)
    return done
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text } = $.ui.resolve(e)
    const list = await read($, skills)
    const now = await read($, status)
    const width = Math.max(...list.map(s => s.name.length + 1), 10) + 2

    return (
      <Box flexDirection="column">
        <Text bold>스킬</Text>
        {list.length === 0 && <Text dimColor>kit 스킬을 찾지 못했습니다.</Text>}
        {list.map(s => (
          <Box key={s.name} flexDirection="row">
            <Text bold>{`/${s.name}`.padEnd(width)}</Text>
            <Text dimColor wrap="truncate-end">
              {s.summary}
            </Text>
          </Box>
        ))}
        <Text> </Text>
        <Text bold>이 프로젝트</Text>
        {now === null && <Text dimColor>읽는 중…</Text>}
        {now !== null && !now.repo && <Text dimColor>git 레포가 아닙니다.</Text>}
        {now !== null && now.repo && (
          <Text>{`${now.repo} · ${now.isKit ? (now.category ?? '구분 없음') : 'kit 프로필 없음'}`}</Text>
        )}
        {now !== null && now.repo && now.plans.length === 0 && <Text dimColor>진행 중 기획서 없음</Text>}
        {now !== null && now.plans.length > 0 && (
          <Box flexDirection="column">
            <Text bold>{`진행 중 기획서 ${now.plans.length}개`}</Text>
            {now.plans.slice(0, PLANS_SHOWN).map(p => (
              <Text key={`${p.worktree}:${p.title}`} color={p.conflict || p.needsCheck ? 'yellow' : undefined} wrap="truncate-end">
                {`· ${planLine(p)}`}
              </Text>
            ))}
            {now.plans.length > PLANS_SHOWN && <Text dimColor>{`외 ${now.plans.length - PLANS_SHOWN}개`}</Text>}
          </Box>
        )}
      </Box>
    )
  })
}

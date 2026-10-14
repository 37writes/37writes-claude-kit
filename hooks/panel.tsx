// /kit 명령과 kit 패널: kit 스킬 목록과 현재 프로젝트 상태를 Claude를 거치지 않고 보여준다.
import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { KitSkill, KitStatus } from '../types'

const PANE = 'kit'
const TITLE = '37writes kit'
const skills = atom({ plugin: 'kit', key: 'skills' } as const, [])
const status = atom({ plugin: 'kit', key: 'status' } as const, null)

const DEVLOG_FILE = /^\d{4}-\d{2}\.md$/
const CATEGORY = /\*\*구분\*\*:\s*(\S+)/

// 설명의 첫 문장만: "…초기화한다. git init, …" → "…초기화한다"
export function summarize(description: string): string {
  const first = description.split(/\.\s/)[0] ?? description
  return first.replace(/\.$/, '')
}

// 작업 흐름 순서. 여기 없는 새 스킬은 뒤에 이름순으로 붙는다
const ORDER = ['init', 'plan', 'commit', 'devlog', 'check', 'release', 'til', 'blog', 'weekly', 'feedback']

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

async function projectStatus($: EngineInterface): Promise<KitStatus> {
  const cwd = await $.session.cwd()
  const root = await git($, cwd, ['rev-parse', '--show-toplevel'])
  if (!root) return { isKit: false, todos: [], unlogged: 0 }
  const repo = root.split('/').pop()
  const devlogDir = `${root}/docs/devlog`
  if (!(await $.fs.exists(devlogDir))) return { repo, isKit: false, todos: [], unlogged: 0 }

  const claudeMd = await $.fs.read(`${root}/CLAUDE.md`).catch(() => '')
  const category = typeof claudeMd === 'string' ? CATEGORY.exec(claudeMd)?.[1] : undefined

  const files = (await $.fs.list(devlogDir))
    .filter(f => f.kind === 'file' && DEVLOG_FILE.test(f.name))
    .map(f => f.name)
    .sort()
  const texts: string[] = []
  for (const name of files) {
    const text = await $.fs.read(`${devlogDir}/${name}`).catch(() => '')
    texts.push(typeof text === 'string' ? text : '')
  }

  const log = (await git($, root, ['log', '--since=3.days', '--no-merges', '--format=%h %s'])) ?? ''
  const { lastLog, todos, unlogged } = devlogSummary(texts, log)

  return { repo, isKit: true, category, lastLog, todos, unlogged }
}

/**
 * devlog 파일 내용(오래된 달부터)과 `git log --format="%h %s"` 출력으로
 * 마지막 항목 제목, 체크 안 된 다음 할 일, devlog에 없는 커밋 수를 구한다.
 */
export function devlogSummary(texts: readonly string[], log: string) {
  const entries = (texts.at(-1) ?? '').split(/^(?=## )/m).filter(s => s.startsWith('## '))
  const last = entries.at(-1)
  const lastLog = last?.split('\n')[0]?.slice(3).trim()
  const todoBlock = last ? /\*\*다음 할 일\*\*\s*\n([\s\S]*?)(?=^\*\*|$(?![\s\S]))/m.exec(last)?.[1] : undefined
  const todos = (todoBlock ?? '')
    .split('\n')
    .filter(line => line.trim().startsWith('- [ ]'))
    .map(line => line.trim().slice(5).trim())

  // stop_reminder.py와 같은 기준: docs(devlog) 커밋은 빼고, 7자리 해시가 devlog에 없으면 미기록
  const logged = texts.join('\n')
  const unlogged = log
    .split('\n')
    .filter(line => line && !line.slice(line.indexOf(' ') + 1).startsWith('docs(devlog)'))
    .filter(line => !logged.includes(line.slice(0, 7))).length

  return { lastLog, todos, unlogged }
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
  if (now?.isKit) lines.push('', `이 프로젝트: ${now.repo} (${now.category ?? '구분 없음'})`)
  return lines.join('\n')
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const started = await next(e)
    await $.command.register({
      name: 'kit',
      description: 'kit 패널 열기/닫기: 스킬 목록과 이 프로젝트의 devlog 상태',
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

  // 패널이 열려 있으면 Claude의 답이 끝날 때마다 상태를 새로 읽는다 (커밋, devlog 반영)
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
        {now !== null && now.repo && !now.isKit && (
          <Text dimColor>{`${now.repo}: kit 프로젝트가 아닙니다. /kit:init 으로 시작`}</Text>
        )}
        {now !== null && now.isKit && (
          <Box flexDirection="column">
            <Text>{`${now.repo} · ${now.category ?? '구분 없음'}`}</Text>
            <Text dimColor>{`최근 devlog: ${now.lastLog ?? '없음'}`}</Text>
            <Text color={now.unlogged > 0 ? 'yellow' : undefined}>
              {now.unlogged > 0 ? `기록 안 된 커밋 ${now.unlogged}개 → /kit:devlog` : '기록 안 된 커밋 없음'}
            </Text>
            {now.todos.length > 0 && <Text bold>{`다음 할 일 ${now.todos.length}개`}</Text>}
            {now.todos.map(todo => (
              <Text key={todo} wrap="truncate-end">{`· ${todo}`}</Text>
            ))}
          </Box>
        )}
      </Box>
    )
  })
}

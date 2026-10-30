import { expect, test } from 'claude-code/testing'

import { isKitProject, parsePlans, planLine, summarize } from './panel'

const PLANS_JSON = JSON.stringify([
  { title: '로그인', status: 'in-progress', branch: 'feat/login', worktree: '/w/login', remaining: 2, total: 5,
    next: 'S4. 검증', current: true, path: 'docs/plans/a.md', stale: false, conflict: false, needsCheck: false, copies: [] },
  { title: '결제', status: 'approved', branch: 'main', worktree: '/w/main', remaining: 3, total: 3,
    next: 'S1. 설계', current: false, path: 'docs/plans/b.md', stale: false, conflict: true, needsCheck: false, copies: [] },
  { title: '끝난 일', status: 'in-progress', branch: 'old', worktree: '/w/old', remaining: 1, total: 2,
    next: '', current: false, path: 'docs/plans/c.md', stale: true, conflict: false, needsCheck: false, copies: [] },
])

test('plans.py --json에서 오래된 복사본을 빼고 읽는다', () => {
  const plans = parsePlans(PLANS_JSON)
  expect(plans.map(p => p.title)).toEqual(['로그인', '결제'])
  expect(planLine(plans[0]!)).toBe('로그인 · in-progress · 남은 2/5')
  expect(planLine(plans[1]!)).toContain('충돌')
})

test('깨지거나 빈 출력은 빈 목록', () => {
  expect(parsePlans('')).toEqual([])
  expect(parsePlans('not json')).toEqual([])
  expect(parsePlans('{"a":1}')).toEqual([])
})

test('병합됐는데 끝나지 않은 기획서는 상태 확인 필요', () => {
  const [p] = parsePlans(JSON.stringify([{ title: 'x', status: 'approved', remaining: 1, total: 2, needsCheck: true }]))
  expect(planLine(p!)).toBe('x · approved · 남은 1/2 · 상태 확인 필요')
})

test('kit 프로젝트: 프로필 표시나 예전 devlog 폴더', () => {
  expect(isKitProject('# x\n<!-- 37writes-kit:profile:start -->\n- **구분**: 개인', false)).toBe(true)
  expect(isKitProject('# 프로필 없음', true)).toBe(true)
  expect(isKitProject('# 프로필 없음', false)).toBe(false)
})

test('설명은 첫 문장만 쓴다', () => {
  expect(summarize('현재 폴더를 초기화한다. git init, 프로필 작성.')).toBe('현재 폴더를 초기화한다')
  expect(summarize('한 문장뿐.')).toBe('한 문장뿐')
})

const PANE = {
  plugin: 'kit',
  component: 'Pane',
  requestId: 'kit',
  props: {
    title: '37writes kit',
    isFocused: false,
    bodyColumns: 60,
    placement: 'dock',
    scroll: { top: 0, bodyRows: 30 },
  },
  viewport: { columns: 160, rows: 40, isFullscreen: true },
} as const

test('패널이 터미널과 데스크톱에서 그려진다', async $ => {
  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({ ...PANE, surface } as never)
    expect(await ui.find({ text: /스킬/ })).toBeDefined()
    expect(await ui.find({ text: /이 프로젝트/ })).toBeDefined()
    await ui.unmount()
  }
})

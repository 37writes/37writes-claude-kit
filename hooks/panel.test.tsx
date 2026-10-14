import { expect, test } from 'claude-code/testing'

import { devlogSummary, summarize } from './panel'

const DEVLOG = `# Devlog 2026-10

## 2026-10-13 · Windows · main

**요약**: 이전 항목

**다음 할 일**
- [ ] 이전 할 일

## 2026-10-14 · macOS · feat/login

**요약**: 로그인

**커밋**
- a1b2c3d feat(auth): 로그인 추가

**다음 할 일**
- [ ] 애플 로그인
- [x] 끝난 일
- [ ] 토큰 만료 테스트

**TIL**
- my-notes/til/x.md
`

test('마지막 devlog 항목의 제목과 체크 안 된 할 일을 읽는다', () => {
  const log = ['a1b2c3d feat(auth): 로그인 추가', 'e4f5a6b fix(api): 오류 수정', '9999999 docs(devlog): 작업 로그'].join('\n')
  const summary = devlogSummary([DEVLOG], log)
  expect(summary.lastLog).toBe('2026-10-14 · macOS · feat/login')
  expect(summary.todos).toEqual(['애플 로그인', '토큰 만료 테스트'])
  // a1b2c3d는 기록됨, docs(devlog)는 제외, e4f5a6b만 미기록
  expect(summary.unlogged).toBe(1)
})

test('devlog가 비어 있으면 빈 상태', () => {
  const summary = devlogSummary([], '')
  expect(summary.lastLog).toBeUndefined()
  expect(summary.todos).toEqual([])
  expect(summary.unlogged).toBe(0)
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

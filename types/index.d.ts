export type KitSkill = { name: string; summary: string }

export type KitStatus = {
  /** git 레포 이름, 레포가 아니면 undefined */
  repo?: string
  /** docs/devlog가 있는 kit 프로젝트인가 */
  isKit: boolean
  /** CLAUDE.md 프로필의 구분 (회사/대학원/개인) */
  category?: string
  /** 마지막 devlog 제목 줄 (날짜 · OS · 브랜치) */
  lastLog?: string
  /** 마지막 devlog의 체크 안 된 "다음 할 일" */
  todos: string[]
  /** 최근 3일 커밋 중 devlog에 없는 수 */
  unlogged: number
}

declare module 'claude-code' {
  interface PluginState {
    kit: { skills: KitSkill[]; status: KitStatus | null }
  }
}

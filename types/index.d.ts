export type KitSkill = { name: string; summary: string }

/** plans.py --json 한 줄에서 패널이 쓰는 것 */
export type KitPlan = {
  title: string
  status: string
  branch: string
  worktree: string
  /** 남은 단계 수 / 전체 단계 수 */
  remaining: number
  total: number
  /** 첫 미완료 단계 */
  next: string
  /** 활성 복사본끼리 상태·체크박스가 달라 자동 재개하지 않는다 */
  conflict: boolean
  /** 브랜치는 기본 브랜치에 병합됐는데 기획서가 끝나지 않음 */
  needsCheck: boolean
}

export type KitStatus = {
  /** git 레포 이름, 레포가 아니면 undefined */
  repo?: string
  /** CLAUDE.md에 kit 프로필 표시가 있거나 (호환) docs/devlog가 있는 레포인가 */
  isKit: boolean
  /** CLAUDE.md 프로필의 구분 (회사/대학원/개인) */
  category?: string
  /** 진행 중 기획서 (모든 worktree, plans.py 기준) */
  plans: KitPlan[]
}

declare module 'claude-code' {
  interface PluginState {
    kit: { skills: KitSkill[]; status: Shaped<KitStatus | null> }
  }
}

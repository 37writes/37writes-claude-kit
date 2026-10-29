---
title: harness에 Orca 배치(탭·worktree)와 보드 사용 규칙 추가
date: 2026-10-29
status: done
tier: T1
---

# harness에 Orca 배치와 보드 규칙 추가

## 목표
Orca 워크스페이스 보드에서 작업별로 진행 상태를 볼 수 있게, 지휘 세션이 워커를 어디에 띄우고(탭 / worktree) 카드 상태를 언제 바꾸는지 harness 스킬에 정한다.

## 배경
- tech-tree-canvas의 sheepshead worktree 하나에 plan 0003, 0004, 배포 ADR 수정 등 여러 작업이 섞여 보드 카드 하나로만 보였다.
- 그 안의 워커 탭 14개는 `terminal create` + `orchestration dispatch`로 띄워져 Orca가 소유하지 않았고(`ctx_`, retained), 작업이 끝나도 `worker-release`로 닫히지 않았다.
- Orca 보드 카드는 worktree 단위다 (`orca worktree set --workspace-status todo|in-progress|in-review|completed`, `--comment`).
- Orca 안내서 기본: 새 워커는 새 터미널이고 worktree는 사용자가 요청했거나 파일 충돌이 있을 때만 만든다.

## 범위
- **포함**: `skills/harness/SKILL.md` 3단계(Orca 배치·보드)와 7단계(정리), CLAUDE.md harness 줄, 버전 0.9.1
- **제외**: Orca 안내서가 정하는 실행·대기·재시도·release 방법 (겹치게 쓰지 않는다), tech-tree-canvas의 남은 탭 정리, 블로그 글 수정

## 결정 & 이유
- 작업 하나 = worktree 하나 = 카드 하나 → 보드가 worktree 단위라서. 에이전트마다 worktree를 만들면 Validator가 Coder 커밋을 바로 못 보고(같은 브랜치를 두 폴더에서 못 연다) 작업 하나가 카드 여러 장으로 흩어진다
- 역할 하나 = 탭 하나 (`worker-start --worktree current`) → 차례로 일하는 역할은 같은 폴더가 맞다. 컨텍스트 분리는 탭만으로 된다
- 동시에 파일을 고치는 워커만 하위 worktree → 덮어쓰기·index.lock·남의 파일 커밋 방지
- `worker-start`만 사용 → 소유한 탭만 release가 닫는다
- 카드 상태는 지휘 세션이 단계 전환 때 갱신 → 사용자가 보드만 봐도 작업 위치를 안다

## 작업 단계
- [x] S1. harness 3·7단계 수정, CLAUDE.md, 버전 — Coder(세션) — `claude plugin validate .` 통과, 변경은 skills/harness, CLAUDE.md, .claude-plugin 안에서만
- [x] S2. 독립 검증 — Validator(새 서브에이전트) — Orca 안내서(`orca skills get orchestration --full`, `orca skills get orca-cli`)와 명령·옵션이 맞는지, 안내서와 겹치거나 어긋나는 규칙이 없는지
- [x] S3. 검증 반영 후 커밋 — 반영: 새 worktree는 create가 준 id로 지정(`current`는 세션 위치 기준), `--no-parent`, 하위 worktree 삭제도 사용자 확인, 거절·폴더 워크스페이스 경우 추가, Reporter 제외(세션 역할), 문장 축약

## 완료 기준
- harness만 읽은 지휘 세션이 "이 워커는 탭인가 worktree인가", "지금 카드 상태는 무엇인가"를 판단할 수 있다
- 쓴 명령·옵션이 설치된 Orca CLI 도움말과 일치한다

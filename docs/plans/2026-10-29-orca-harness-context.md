---
title: Orca에서 시작한 세션에 harness 절차 자동 안내
date: 2026-10-29
status: in-progress
tier: T1
---

# Orca 세션에 harness 절차 자동 안내

## 목표
Orca IDE에서 띄운 Claude 세션은 어느 레포에서든 시작할 때부터 harness 멀티 에이전트 절차(지휘 세션은 등급 분류 → 계획 → Orca 워커 → 독립 검증, 워커는 지시 범위만 → `worker_done`)를 따르게 한다.

## 배경
- 지금 harness는 스킬일 뿐이라 에이전트가 스스로 `/kit:harness`를 불러야 적용된다. kit 프로젝트가 아닌 레포에는 그 안내(CLAUDE.md "작업 등급" 줄)도 없다.
- Orca가 띄운 Claude는 모두 zsh 로그인 셸에서 실행돼 alias로 kit가 로드된다 (2026-10-29 프로세스 6개 확인).
- Orca 터미널에는 `TERM_PROGRAM=Orca`, `ORCA_WORKTREE_ID` 등이 있어 훅에서 감지할 수 있다. 지휘 세션과 워커를 가르는 환경 변수는 없다 → 워커는 첫 지시가 Orca 작업 지시(dispatch)인 것으로 구분한다.
- 위험 명령 확인(guard, "ask")은 Orca의 `--dangerously-skip-permissions`에서도 확인 창이 뜬다 (사용자 확인) → 이번 범위에서 뺀다.

## 범위
- **포함**: Orca 감지 SessionStart 훅 추가(`scripts/orca_context.py`, `hooks/hooks.json`), harness 스킬에 자동 안내 언급, README 훅 표, CLAUDE.md 구조·결정, 버전 0.10.0
- **제외**: 기존 SessionStart(`session_start.py`)의 kit 프로젝트 전용 동작, guard 수정, Codex 등 Claude가 아닌 에이전트용 안내(harness의 AGENTS.md 제안으로 대신), 다른 컴퓨터 설치

## 결정 & 이유
- 별도 스크립트로 둔다 → `session_start.py`는 kit 프로젝트에서만 동작하는 규칙을 그대로 지키고, Orca 안내는 모든 레포(폴더 워크스페이스 포함)에 넣는다
- 안내문은 짧게, 절차 본문은 harness 스킬에 둔다 → SessionStart 컨텍스트는 매 세션(재개·compact 포함) 들어간다
- Orca 워커는 사용자 확인 없이 띄운다 → 사용자 결정("워커는 확인 없이 띄워도 된다, 탭이냐 worktree냐를 잘 판단하라"). harness의 "확인받는다" 문장도 바꾸고, 안내문에 배치 판단 기준을 넣는다
- 감지는 `TERM_PROGRAM == "Orca"` 또는 `ORCA_WORKTREE_ID` → 하나만 쓰면 Orca 버전 변화에 약하다

## 작업 단계
- [x] S1. `orca_context.py`, hooks.json, harness·README·CLAUDE.md, 버전 — Coder(세션) — `claude plugin validate .` 통과, Orca 환경 변수 있음/없음에서 훅 출력 확인, 변경은 scripts/, hooks/hooks.json, skills/harness, README.md, CLAUDE.md, .claude-plugin, docs/ 안에서만
  - 결과: validate 통과. `claude -p`(alias 우회, 이 세션의 자식 세션 변수 제거)로 kit_test·Orca 안 → 두 안내 모두, 일반 폴더·Orca 안 → Orca 안내만, Orca 밖 → 없음. 주의: 셸 alias가 남아 있으면 본체 kit(0.9.1)가 먼저 로드돼 수정본 훅이 안 돈다
- [ ] S2. 독립 검증 — Validator(Orca Codex 워커, 같은 worktree 탭) — 훅을 직접 실행해 Orca 안/밖, kit 레포/일반 레포/git 아닌 폴더에서 출력 확인, 안내문이 harness 규칙과 어긋나지 않는지
- [ ] S3. 검증 반영, 커밋, main 병합 — 세션

## 완료 기준
- Orca 터미널에서 kit 프로젝트가 아닌 레포에 Claude를 새로 띄우면, 첫 응답 전 컨텍스트에 harness 안내가 들어 있다
- Orca 밖(일반 터미널)에서는 아무것도 추가되지 않는다

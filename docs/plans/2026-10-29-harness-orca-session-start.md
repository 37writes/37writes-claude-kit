---
title: Orca 세션은 첫 요청부터 harness를 불러 읽고, 다른 모델 의견도 Orca 워커로
date: 2026-10-29
status: done
tier: T1
---

# Orca 세션에서 harness를 확실히 쓰게 하기

## 목표
Orca IDE에서 띄운 Claude 세션이 어느 프로젝트든 첫 요청(질문 포함)부터 /kit:harness를 불러 읽고 따르게 한다. 다른 모델(GPT/Codex, agy)에게 의견을 물을 때도 화면에 보이는 Orca 워커 탭으로 띄운다.

## 배경
- motion 프로젝트 세션(2026-10-29)에서 SessionStart 안내가 들어갔는데도 harness를 쓰지 않았다. 안내문이 "질문이 아닌 작업 요청을 받으면"이라서, 첫 질문("환경에서 모션그래픽을 만들 수 있나")을 T0로 보고 스킬을 읽지 않았다.
- 사용자가 "gpt나 agy에도 의견을 물어봐"라고 하자 `codex exec`, `agy -p`로 화면 없이 호출했다. harness에는 의견 요청을 어떻게 띄울지 규칙이 없고, T0는 "워커 없음"이라 Orca를 쓸 근거가 없었다. 사용자는 Orca 탭에서 과정을 보고 싶어 한다 (blog 검수와 같은 이유).
- 새 Orca 프로젝트(motion)에는 kit 프로필이 없어 커밋·devlog 등 kit 규칙도 적용되지 않는다.

## 범위
- **포함**: `scripts/orca_context.py` 안내문, harness 1단계, README 훅 표, CLAUDE.md 결정, 버전 0.13.1
- **제외**: Orca 감지 방식, 워커용 안내, `session_start.py`, 프로필 자동 생성(/kit:init은 제안만)

## 결정 & 이유
- 첫 요청 처리 전에 Skill 도구로 `kit:harness`를 불러 읽는다 (질문이라도) → 안내 요약만으로는 판단을 건너뛰었다. 질문이면 T0로 분류하고 바로 답하면 되므로 비용은 스킬 로드 한 번이다.
- 다른 모델 의견·리뷰는 등급과 상관없이 Orca 워커(`worker-start --agent codex|antigravity`)로 → 사용자가 과정을 보고 싶어 한다 (사용자 결정, 2026-10-29). `codex exec`·`agy -p`는 Orca가 없을 때만.
- 프로필이 없는 레포에서만 /kit:init 제안 줄을 붙인다 → 프로필이 있는 레포에서는 쓸데없는 컨텍스트다.

## 작업 단계
- [x] S1. 안내문·harness·README·CLAUDE.md·버전 — Coder(세션) — `claude plugin validate .` 통과, Orca 안/밖 × 프로필 있음/없음/git 아님에서 훅 출력이 기대대로, 변경은 scripts/orca_context.py, skills/harness/, README.md, CLAUDE.md, .claude-plugin/, docs/ 안에서만
  - 결과: validate 통과. 훅 직접 실행 6조합: Orca+프로필(루트·하위 폴더) → 안내만, Orca+프로필 없는 git·git 아님·motion → 안내 + /kit:init 줄, Orca 밖 → 출력 없음, 입력이 JSON이 아니어도 동작
- [x] S2. 독립 검증 — Validator(Orca Codex 워커, 같은 worktree 탭) — 위 조합을 직접 다시 실행, 안내문이 harness·Orca 안내서와 어긋나지 않는지, diff 범위·시크릿 검사
  - 결과: 1회차 FAIL — 훅 44조합·validate·범위·시크릿은 통과, F1 새 두 줄(의견 요청, /kit:init 제안)과 harness 서문이 워커에도 적용되게 읽힘. 2회차(같은 탭) PASS — F1 해소, 44조합·세 역할 시나리오(지휘, 프로필 없는 레포의 워커, 완료 뒤 직접 요청) 일관, 새 지적 0
- [x] S3. 검증 반영, 커밋, 본체 main 병합 — 세션
  - 결과: F1을 "지휘 세션"으로 한정(c9addec), 본체 main에 `--ff-only` 병합. 실제 새 Claude 세션 행동은 다음 Orca 세션에서 확인

## 완료 기준
- Orca에서 프로필 없는 레포에 Claude를 새로 띄우면 컨텍스트에 "첫 요청 전 kit:harness 로드", "다른 모델 의견은 Orca 워커", "/kit:init 제안"이 들어 있다
- 프로필 있는 레포에서는 /kit:init 줄이 없고, Orca 밖에서는 아무것도 없다

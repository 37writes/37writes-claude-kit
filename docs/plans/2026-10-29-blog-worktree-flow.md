---
title: 블로그 글을 글마다 worktree에서 쓰고 승인 후 발행
date: 2026-10-29
status: done
tier: T1
---

# blog 스킬: 글마다 worktree, 승인 후 main 병합

## 목표
"이 내용 블로그로 쓰자"처럼 말로 시작해, 글 하나를 전용 tech-blog worktree에서 쓰고 사용자 승인 뒤에만 main에 병합한다.

## 결정 (사용자, 2026-10-29)
- 말로 시작 → `disable-model-invocation` 제거, description 한 줄
- 발행 = 명시적 승인 뒤 main 병합

## 범위
- `skills/blog/SKILL.md` A~D 흐름 (출발 세션 브리프 → worktree 생성·인계 → 글 worktree 작성 → 승인 후 병합·정리)
- `scripts/guard.py` ampx sandbox·pipeline-deploy, deploy.sh(--diff·--synth 제외) 확인
- 0.11.0, README, CLAUDE.md, devlog

## 검증
- `claude plugin validate .`
- guard 한 줄 테스트 (ask/비ask)
- tech-blog 임시 worktree에서 문서화한 빌드 명령 실행
- 독립 Validator 검토

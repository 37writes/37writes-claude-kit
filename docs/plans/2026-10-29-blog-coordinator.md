---
title: 블로그 코디네이터가 글 워커를 지휘
date: 2026-10-29
status: done
tier: T1
---

# blog 스킬: 출발 세션 → 코디네이터 → 글 워커

## 목표
다른 프로젝트에서 "블로그로 쓰자"고 하면 tech-blog 본체의 블로그 코디네이터 세션이 받아서, 글마다 worktree와 글 워커를 띄우고, 직접 검수한 뒤 사용자 승인을 받아 병합한다.

## 문제 (0.11)
출발 세션이 글 worktree를 직접 만들고 인계 → 글 worktree 에이전트가 쓰기·병합·push·자기 worktree와 브랜치 삭제까지 혼자 했다. 지휘·검수하는 쪽이 없었다.

## 결정 (사용자, 2026-10-29)
- 블로그 작업 전체는 코디네이터 세션이 지휘한다. 브랜치(worktree) 생성, 내용 확인, 병합은 코디네이터 일
- 글 워커는 쓰기·그림·필터링·커밋까지만

## 설계
- 출발 세션: 브리프를 `~/.config/37writes-kit/blog/<slug>/brief.md`에 쓰고, 본체 worktree에서 제목이 정확히 `블로그 코디네이터`인 탭에 `terminal send`. 없으면 `agent launch`로 띄움
- 코디네이터: 본체 main, 한 Run. 글마다 `worker-start --worktree new-top-level` (Task·Dispatch 하나) → `check --wait`로 질문·완료 처리 → 직접 검수 + Codex 검수 워커 → 수정은 retain한 글 워커 탭에 다시 dispatch → 사용자 승인 → 병합·push·배포 확인·release·worktree rm·브랜치 확인
- 재시작 대비: `<slug>/state.md`에 Run·worktree·브랜치·Dispatch 기록
- 이전 방식 worktree(`.blog-brief.md`)는 코디네이터가 K5부터 넘겨받음

## 범위
- `skills/blog/SKILL.md` 전면 개편 (역할 표, A·B·K·C, 2~8단계 담당 표시)
- 0.12.0, README 표·로드맵, CLAUDE.md blog 흐름, devlog

## 검증
- `claude plugin validate .`
- Orca CLI help와 대조 (worker-start 생성 플래그, terminal list `title`, rename, retain/release)
- 독립 검토 (스킬을 처음 보는 에이전트가 세 역할로 따라갈 수 있는지, Orca 안내서와 어긋나는지)
- [x] 독립 검토 반영 (반드시 고칠 것 14개 + 비용 적은 것)
- [ ] 실제 글 하나로 전체 흐름 시험 (다음 글에서)

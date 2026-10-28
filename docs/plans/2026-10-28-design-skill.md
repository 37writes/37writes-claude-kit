---
title: AI 티 안 나는 디자인 스킬 (/kit:design)
date: 2026-10-28
status: done
tier: T1               # tech-blog push는 별도 T2
---

# AI 티 안 나는 디자인 스킬

## 목표
AI가 만든 화면이 흔히 갖는 기본값(보라 그라디언트, 둥근 카드 반복, 아이콘+제목+설명 3열 등)을 피하도록, 진단 체크리스트와 대안을 스킬로 만든다. tech-blog에 먼저 적용해서 규칙을 다듬는다.

## 범위
- **포함**: `skills/design/SKILL.md`(진단 → 방향 선택 → 토큰 → 적용 → 전/후 캡처 검증), 대비 계산 스크립트, tech-blog "종이 노트" 방향 적용(로컬 브랜치)
- **제외**: Chirpy 포크나 자체 테마 (테마 업데이트를 못 받게 됨), tech-blog push (T2, 따로 승인)

## 설계
- 신규: `skills/design/SKILL.md`, `scripts/contrast.py` (WCAG 대비 계산, 표준 라이브러리만), `scripts/shot.py` (Chrome headless 캡처, 모바일·라이트/다크)
- 변경: README 스킬 표, CLAUDE.md 구조(스킬 12개), plugin.json·marketplace.json 0.8.0
- tech-blog: `assets/css/jekyll-theme-chirpy.scss`에 덮어쓰기 스타일, 필요하면 `_includes/` 일부만 덮어쓰기

## 결정 & 이유
- 스킬 + 블로그 시범 → 규칙만 쓰면 실제로 맞는지 모른다. 블로그로 검증한 뒤 규칙을 고친다
- 블로그 방향은 종이 노트(밝은 미색, 세리프 본문, 카드 없는 목록, 강조색 하나) → 사용자 선택
- Chirpy 유지 + SCSS 덮어쓰기 → 검색·목차·태그·PWA를 그대로 쓰고 테마 업데이트도 받는다
- 다크 모드는 유지하고 같은 방향의 "밤의 종이" 팔레트를 만든다 → 처음엔 `theme_mode: light`로 토글을 없앴다가 독립 검증에서 기능 제거로 지적됨. 사용자 선택
- 캡처는 gstack browse 대신 shot.py → 이 Mac에서 browse가 바로 종료(137)됐고 다른 컴퓨터엔 gstack이 없을 수 있다
- design은 모델 호출 허용 → Claude가 UI를 만들 때 스스로 불러야 의미가 있다. 대신 description을 짧게

## 작업 단계
- [x] S1. 스킬 초안 + contrast.py — 완료 조건: `claude plugin validate .` 통과
- [x] S2. tech-blog 적용 — 완료 조건: 로컬 `jekyll build` 성공, 홈·글·모바일 캡처
- [x] S3. 독립 검증 — 서브에이전트가 전/후 캡처와 체크리스트로 점검, `htmlproofer` 통과
- [x] S4. 시범에서 배운 것을 스킬에 반영, 버전·README 갱신

## 완료 기준
- 블로그 전/후 캡처에서 체크리스트의 "AI 티" 항목이 줄어든 것이 보인다
- 본문 대비 4.5:1 이상 (contrast.py로 확인)

## 승인 필요 (T2)
- tech-blog `design/paper-note` 브랜치를 main에 합쳐 push → GitHub Actions 배포. 미리보기는 로컬 `jekyll serve` 캡처. 롤백은 revert 커밋 push

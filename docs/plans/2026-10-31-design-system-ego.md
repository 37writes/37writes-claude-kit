---
title: 개인 디자인 시스템과 ego lite 모바일 검증
date: 2026-10-31
status: in-progress
tier: T1
---

# 개인 디자인 시스템과 ego lite 모바일 검증

## 목표
kit:design을 사용자의 일관된 AI 디자이너로 만든다. Apple에서 참고한 명확한 위계·정렬·절제된 표현을 공통 규칙으로, 색·글꼴은 교체 가능한 테마로 관리한다. 브라우저 작업은 ego lite만 사용한다.

## 범위
- 포함: design 스킬, 필요한 디자인 규칙 참조·CSS 자산·ego 검증 도우미, README 및 플러그인 버전. blog 스킬의 캡처 명령과 CLAUDE.md의 도구 설명도 ego로 정합화.
- TTC와 블로그는 각 프로젝트로 소유권을 위임한다. 이 레포에서는 해당 프로젝트를 직접 편집하지 않는다.
- 제외: 제품 기능 변경, 외부 디자인 라이브러리 도입, 브라우저 설치·업데이트, AWS 변경.

## 설계
- `skills/design/SKILL.md`: 기존 프로필/부품을 먼저 읽고 규칙 재사용. 기본값 재선택 방지, 테마와 버전 구분, 화면 유형별 밀도. AI 패턴은 맥락을 보는 진단으로 유지.
- `skills/design/references/system.md`: 공통 원칙, 부품 상태/동작 계약, 프로젝트 프로필 형식, 테마 마이그레이션.
- `skills/design/references/ego-validation.md`: ego 문서 로드 및 동일 TaskSpace 사용, CDP 모바일 에뮬레이션, 화면·테마·상태 매트릭스, 넘침·탭·메뉴 실조작, 한계 표기.
- `skills/design/assets/`: 프레임워크 비종속 CSS 변수와 선택적 기본 UI 부품 예시, neutral/paper 테마. 기존 테마에 전체 CSS를 무조건 덮지 않고 의미 매핑한다.
- `skills/design/scripts/`: ego Page를 받아 viewport 불일치·문서 넘침·조작 요소 크기 등 측정하는 읽기 전용 도우미. 결과는 후보 및 증거이며 자동 합격 판정 아님.
- 반응형 전환은 CSS만으로 해결된다고 약속하지 않는다. 모바일 헤더/탭/모달의 DOM·상태/포커스 처리도 프로젝트가 구현.
- `shot.py`는 다른 호출자가 있을 수 있어 보존하되 design 경로에서 사용하지 않는다.

## 결정 & 이유
- 브랜드의 정확한 색·폰트는 아직 미확정. 초기 neutral과 paper는 추천 프리셋이며 승인된 브랜드로 가장하지 않는다. 기존 프로젝트의 가독성과 식별성을 보존하며 프로필에 고정한다.
- 브라우저는 사용자 요청대로 ego lite만. Playwright/Safari/headless를 대체 경로로 쓰지 않는다.
- 검증 범위의 기본 폭은 320/360/390/430/768/1280 및 실제 CSS 전환점 ±1px. 터치 메뉴, 긴 한글, 글꼴 준비, 다크 모드·테마를 확인한다.
- 작업 본체에 무관한 미추적 tsconfig.json이 있어 별도 worktree 사용.
- user 요청은 구현과 프로젝트별 위임까지 승인한 것으로 해석. 배포는 각 프로젝트의 기존 정책과 승인 범위를 따르며 이 기획에서 확대하지 않는다.

## 기획 반박
- 검토자: Claude Opus 5.5 (`global.anthropic.claude-opus-5-5`, 워커 자기 보고; runtime projection model은 null), Task `task_a5d6c7659adb`, Dispatch `ctx_1ab7824ad563`. 보고서: `2026-10-31-design-system-ego/plan-review.md`.
- 반례 1 수용: CDP 설정·터치 조작·측정·캡처·초기화를 같은 실행에서 수행, 매 행 실제 viewport와 pointer 환경 기록. 설정 390px에서 TTC innerWidth가 495px로 넓어짐을 재현했고 다음 실행에서는 900px로 초기화됨을 직접 확인. 터치는 Input.dispatchTouchEvent로 검증하며 실패하면 미검증 처리.
- 반례 2 수용: 모서리·그림자·폰트 수를 금지하지 않고 프로필의 선택과 일치하는지 검사. Apple 참고는 명확한 위계·정렬·절제된 표현이라는 사용자 의도에서 출발하며 새로운 브랜드 확정으로 간주하지 않음.
- 반례 3 수용: core/theme 원본은 kit assets, 프로젝트에는 원본 그대로 vendoring 및 출처 버전/해시 기록, 별도 mapping 파일만 수정. 자동 업그레이드 금지. 웹폰트의 실제 로드와 fallback을 구분하고 신규 폰트 배포를 이 작업에서 임의로 하지 않음.
- 범위 누락 수용: blog의 shot.py 캡처 지시를 ego 참조로 전환. shot.py 자체는 호환용으로 보존. 여러 워커는 같은 목표의 TaskSpace를 공유하고 Page 소유권을 분리.
- A1은 사용자 표현과 기존 디자인에서 충분히 방향을 정할 수 있어 추가 승인 차단은 기각. A2(두 프로젝트 같은 테마 여부)는 선택 질문을 보냈으며 답이 없으면 기존 개성을 유지. A4는 CSS/JS 소스에서 전환점을 조사하며 도우미가 자동으로 모두 발견한다고 주장하지 않음. A5 fonts.ready 대기 수용.

## 작업 단계
- [x] S1. 기획 반박 — Claude — 반례 3개와 blog 캡처 누락을 수용, 실제 모델과 확인 결과 기록
- [x] S2. 스킬·자산 구현 — Codex 지휘 세션 — ego에서 44개 폭/테마/모드 조합, 터치 메뉴, 키보드 마지막 항목, 시스템 모드, 깨진 fixture 탐지 통과. 실제 토큰 대비 88조합 통과. 프로필 검사 5종 통과(기존 디렉터리 경고 유지).
- [x] S3. 독립 검증 — Claude Opus 5.5 — 최종 Task task_b733f9e9a876 / Dispatch ctx_cb4e4257d12f: R1/R2/R3 해결, 진행 차단 없음. final-review.md 참고.
- [ ] S4. 본체 반영과 프로젝트별 위임 — Codex 지휘 세션 — 검증된 kit 원본에서 TTC/블로그 전용 worktree 에이전트로 작업 지시 전달 증거

## 완료 기준
- 공통 규칙과 테마를 재사용할 실제 자산이 있고, 테마만 바꾼 시험 화면과 깨지는 모바일 반례를 ego lite로 확인한다.
- Claude가 설계와 구현을 교차 검토하고 발견한 범위 내 결함을 해소한다.
- TTC와 블로그 작업은 각 프로젝트의 독립 worktree와 에이전트에게 전달된다. 위임 완료와 실제 수정/배포 완료를 구분해 보고한다.

## S3 검증 반영
- Claude Opus 5.5 (자기 보고), Task `task_c854fa50a5dc`, Dispatch `ctx_ec28188810ac`가 독립 검증. `validation.md` 참고.
- F1/F2 수용: 초기 44행은 좁은 폭에서 아래 작업 영역을 직접 검사하지 않은 한계가 있었다. 렌더 DOM 전체 측정 + 검사 개수 + 아래 영역 실제 방문을 추가하고, 320px/200% 메뉴 nowrap·축소 방지 및 회귀를 추가.
- F3/F4/F8 수용: 닫힌 details 제외, 조상 clipping과 의도한 scroll 구별, 정상 input 자체 스크롤 오탐 제거.
- F5/F6 수용: blog K3/spec/정리에 spaceId·Page·finish 경로, 기존 모드 속성 미러 어댑터 추가.
- F7/F9 부분 수용: 샘플은 토큰 미리보기이며 실제 tablist/반응형 nav 라이브러리가 아님을 명시. 링크 현재 위치/터치 후 Escape·바깥 닫기/3단 모드 수정. 실제 프로젝트 부품은 위임한 범위에서 구현·검증한다.
- 수정 뒤 44행에서 각각 위/아래 방문 및 8개 실조작/회귀 플래그 통과. 320px/200% 캡처를 직접 확인.

## 남은 일
- Claude 독립 검증, 본체 반영, 프로젝트 위임.
- skill-creator quick_validate.py는 시스템 Python에 PyYAML이 없어 실행 불가. 설치하지 않고 frontmatter/참조를 직접 확인하고 claude plugin validate를 실행했다.
- font asset 미포함으로 미리보기는 시스템 fallback. 실제 프로젝트 글꼴 로드와 실기기는 각 프로젝트 담당자가 검증/미검증을 명시.
- 검증 중 키보드 마지막 링크가 스크롤 영역 밖에 남는 반례를 발견해 preview의 focusin 스크롤 처리로 수정하고 재검증했다.

## S3 재검증 반영
- Claude Opus 5.5, Task task_a27a14f42cd3 / Dispatch ctx_3b7c91675f53가 F1/F2 해결을 독립 확인. R1 오탐은 scroll viewport를 기준으로 바깥 조상의 clipping을 비교하도록 수정. 정상 body/패널 hidden·clip 대조군과 스크롤 viewport 자체 잘림 반례를 추가했다.
- R2는 비조작 콘텐츠 clipping 미검사 한계와 root/body 숨김 경고를 추가. R3는 blog state.md 항목과 finish 후 브리프 삭제 순서를 수정. R4 ego 업그레이드는 범위 밖이므로 수행하지 않음.
- 수정 후 ego 44행 및 9개 플래그 통과, node 구문 검사 및 git diff --check 통과. 최종 R1 확인은 같은 Claude 검수 탭 재사용.

## S3 최종 결과
- Claude가 정상 숨김 조상 대조군 8개와 잘린 스크롤 viewport 반례 6개를 독립 확인했다. 남은 P3 중 회귀 fixture는 Claude가 확인한 440px로 교체하고 scrollWidth > clientWidth 단언을 추가. 문서에 비조작 콘텐츠·세로 잘림 한계와 조상별 후보 묶음을 추가했다.
- 최종 ego runSmoke 44행/9개 플래그 통과. TaskSpace10 finish 완료. 두 Claude 검수 탭은 user_takeover/external_terminal로 보존; 지휘자 소유의 미정산 워커 없음.

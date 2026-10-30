# 37writes UI 계약 v1.0.0

공통 규칙은 지속하고 테마는 교체한다. 이 문서와 CSS는 출발점이며 기존 제품의 검증된 부품을 우선한다.

## 원본과 프로젝트 적용

- 원본: 이 스킬의 `assets/core.css`, `assets/themes/{neutral,paper}.css`. 시스템 버전은 1.0.0이며 kit 플러그인 버전과 별개다.
- 프로젝트에 쓰는 파일은 **내용을 바꾸지 않고** vendoring한다. 출처 버전과 SHA-256을 기록하고, 의미 연결/예외는 별도 `theme-map.css`(또는 기존 SCSS 대응 파일)에 둔다.
- 기존 `--brand`를 `var(--kit-accent)`에 매핑하는 식으로 연결한다. 실제 빌드에 들어가는 경로로 복사하고 개발자 컴퓨터의 kit 경로에 의존하지 않는다.
- 테마 전환은 루트 `data-kit-theme="neutral|paper"`로 선택한다. `data-kit-mode="light|dark"`는 명시 선택이며, 없으면 시스템 설정을 따른다. 기존 모드 속성이 있으면 그 선택을 연결하고 모드 저장소를 두 개 만들지 않는다.
- 원본 CSS는 토큰과 선택적 `.kit-*` 부품만 제공한다. 전역 reset/기존 클래스 덮어쓰기를 하지 않는다.
- 버전이 다르면 변경점과 영향만 먼저 확인한다. 이번 작업과 무관한 부품을 자동 업그레이드하지 않는다. 프로젝트 커스텀은 이름·변경 토큰·이유를 기록한다.
- `assets/preview.html`은 소개·읽기·작업 구성과 **토큰/테마를 보는** 로컬 시험 화면이다. 가로 항목은 해시 링크 목록이고 메뉴는 모든 폭에서 native details다. 실제 tablist/tabpanel, 데스크톱 내비→모바일 전환, loading/error의 완성된 부품 라이브러리가 아니다. 아래 계약을 프로젝트의 기존 부품에 구현하고 실제 전환점을 검증한다.

기존 모드 연결 예(Chirpy의 실제 속성이 `data-bs-theme`일 때): 기존 모드 선택을 유일한 원본으로 삼고, 해당 토글 코드에서 `data-kit-mode`만 미러링한다. 토글 코드를 바꾸기 어려우면 별도 어댑터에서 아래처럼 속성 변경을 관찰한다. 이 코드는 팔레트 값이나 localStorage를 복제하지 않는다.

```js
const root = document.documentElement;
const syncKitMode = () => {
  const mode = root.getAttribute("data-bs-theme");
  if (mode === "light" || mode === "dark") root.dataset.kitMode = mode;
  else delete root.dataset.kitMode; // system
};
syncKitMode(); // 가능하면 첫 화면을 그리기 전에 실행
const observer = new MutationObserver(syncKitMode);
observer.observe(root, { attributes: true, attributeFilter: ["data-bs-theme"] });
// SPA 컴포넌트 소유라면 unmount 시 observer.disconnect().
```

프로젝트가 다른 속성을 쓰면 실제 코드를 읽고 source 속성을 바꾼다. CSS 매핑 파일에는 `--main-bg: var(--kit-bg)` 같은 연결만 두고 dark 색값을 다시 적지 않는다.

## 공통 원칙

- 중요한 내용은 크기·굵기·위치·여백으로 먼저 구분한다. 섹션마다 같은 카드와 같은 높이를 강제하지 않는다.
- 간격은 4/8/12/16/24/32/48/64px 단계. 새로운 숫자가 필요하면 기존 단계로 안 되는 이유를 확인한다.
- UI는 16px 기준, 보조 14px, 읽는 글 17~18px·줄 간격 1.7~1.85를 출발점으로 한다. rem과 유연한 높이를 사용하고 글자 확대를 막지 않는다.
- 한국어 본문은 `word-break: keep-all`과 긴 URL/식별자용 `overflow-wrap: anywhere`를 함께 검토한다. 메뉴와 탭은 `white-space: nowrap`, `flex-shrink: 0`; 부모는 `min-width: 0`과 의도한 스크롤/접기를 갖춘다.
- 색은 역할로 명명한다: 배경, 표면, 본문, 보조, 장식선, 기능선, 강조/강조 위 글자, 오류, 성공, 포커스. 성공/오류는 글자나 아이콘으로도 전달한다.
- 둥근 모서리·그림자·유리 재질 자체를 금지하지 않는다. neutral 기본은 절제된 10px 부품/16px 패널, paper는 같은 부품 위계에 따뜻한 색과 읽기용 서체를 사용한다. 프로필이 정한 허용값 안에서 쓴다.
- 움직임은 동작 이해에 도움이 될 때만. reduced-motion을 존중하고 사용을 기다리게 하는 등장 효과를 기본값으로 만들지 않는다.

## 부품별 동작 계약

| 부품 | 공통 상태와 반응형 계약 |
|---|---|
| 버튼·아이콘 버튼 | 기본/hover/focus-visible/disabled/loading/error. 주요 독립 조작 영역은 44×44 CSS px 이상을 프로젝트 기본으로, 긴 내용은 높이 확장. 아이콘 버튼에 접근 가능한 이름 |
| 입력창 | label 연결, 설명/오류 연결, focus/disabled/read-only. placeholder로 label 대체 금지 |
| 내비게이션 | 현재 위치 표시. 좁으면 접근 가능한 disclosure/메뉴로 재구성하거나 명시한 스크롤 방식. 브랜드·계정이 메뉴를 밀어내지 않게 |
| 메뉴 disclosure | 열기/닫기 버튼, aria-expanded/aria-controls, 항목 선택 시 닫힘, Escape/포커스 복귀. 닫힌 항목은 키보드 탐색에서 제외. native details/summary는 브라우저의 동등한 의미를 활용 |
| 페이지 링크 목록 | 실제 링크와 aria-current 사용. 이름만 tab인 링크에 불필요한 ARIA tab 역할을 붙이지 않음 |
| 화면 내 탭 | tablist/tab/tabpanel 연결, 선택 상태, 좌우 키·Home/End 및 선택 전략. 긴 라벨 축소 금지. 첫/마지막 항목까지 터치/키보드로 도달하고 선택/포커스된 항목을 스크롤 영역 안에 노출 |
| 모달 | dialog 이름, 초점 진입/격리/복귀, 닫기, 배경 조작 차단. 작은 화면·가상 키보드에서도 내용과 동작 버튼에 도달 |
| 표·코드·캔버스 | 의도한 컨테이너 안에서만 넘침/확대. body 전체 스크롤이나 overflow:hidden으로 기능이 사라지지 않게 |

44px은 이 디자인 시스템의 편의 기준이며 모든 인라인 링크에 일괄 적용하는 접근성 표준 판정이 아니다. 검사 대상과 예외를 프로필에 적는다.
CSS 예시가 ARIA·키보드·React 상태를 구현해 주지 않는다. 제품 컴포넌트에서 위 계약을 완성해야 한다.

## 글꼴 계약

프리셋의 UI 1순위는 Noto Sans KR, paper 본문은 Noto Serif KR다. 폰트 파일을 포함하거나 자동 다운로드하지 않으므로 **font-family 선언만으로 로드 완료라고 하지 않는다**.
프로젝트의 기존 한글 웹폰트를 우선 연결하고, 새 글꼴은 실제 로딩 URL/로컬 파일·출처/라이선스·굵기·fallback을 프로필에 명시한다. 웹폰트는 글자 범위별 파일을 선호한다.
Apple 전용 글꼴을 임의로 웹폰트로 재배포하지 않는다. 시스템 fallback은 OS별로 모양/폭이 달라짐을 감안해 재검증한다.
`document.fonts.ready`는 로딩 종료를 뜻하며 원하는 글꼴 로딩 성공을 보장하지 않는다. 네트워크 실패와 실제 FontFace 상태도 확인한다.

## 화면 유형

- 소개: 핵심 메시지와 실제 제품/콘텐츠 예시, 한 영역의 주요 행동 하나.
- 읽기: 본문 폭 약 35~45 한글 글자, 제목 전체 노출, 읽는 순서와 목차/검색 유지.
- 작업: 적절한 정보 밀도, 반복 조작의 예측 가능성, 선택·로딩·오류 표시. 홍보용 큰 여백으로 작업 공간을 낭비하지 않는다.

## 프로젝트 프로필

기존 대응 문서가 없으면 `docs/design-system.md`에 아래 항목을 실제 값으로 기록한다. 이는 작업 로그가 아니라 이후 구현이 참조할 제품 명세다.

- 시스템/테마: 버전, 선택값, 확정 또는 임시 추천 여부
- 원본: kit 버전/커밋, 복사 경로, 파일별 SHA-256 (`shasum -a 256 <파일>`)
- 매핑: 프로젝트 토큰/부품 경로, 허용한 예외와 이유
- 글꼴: UI/본문/코드, 로딩 위치·출처, fallback
- 화면 유형과 반응형: 메뉴/탭 전환 조건, overflow 소유 컨테이너, 모드 상태의 원본
- 지원/검증: 폭·브라우저/ego 버전, 핵심 조작, 실기기 확인 여부
- 기준 화면: 재현 가능한 route/fixture와 캡처 위치. 일회성 /tmp 파일만 영구 기준으로 삼지 않음

서로 다른 프로젝트가 같은 테마를 선택했다면 원본 토큰 값이 같아야 한다. 서로 다른 테마를 선택했어도 위계·간격·부품의 사용법은 일관되게 유지한다.

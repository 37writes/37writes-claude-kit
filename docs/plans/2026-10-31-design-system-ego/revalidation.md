# S3 재검증: c6c832f의 F1~F9 반영 확인

- 검증자: Claude Opus 5.5 (`global.anthropic.claude-opus-5-5`, 워커 자기 보고), Task `task_a27a14f42cd3`, Dispatch `ctx_3b7c91675f53`
- 대상: HEAD `c6c832f` (이전 검수 대상 `0b99895`). 바뀐 파일: `skills/design/scripts/ego-audit.mjs`·`ego-smoke.mjs`, `assets/preview.html`·`core.css`, `references/system.md`·`ego-validation.md`, `skills/blog/SKILL.md`
- 방법: 작성자의 "S3 검증 반영" 문단과 `ego-smoke.json`은 근거로 쓰지 않았다. 이전 재현을 다시 돌렸고, 작성자 smoke가 넣은 반례와 다른 변형(한 링크만 꺾임, 저장 버튼만 축소, 정상 화면 + 숨긴 넘침 대조군, 패널 `overflow` 숨김, 글 문단만 넘침)을 직접 골랐다. ego는 기존 TaskSpace 10(`37writes 디자인 체계와 모바일 메뉴 점검`, ownership agent)의 p4만 썼다. 새 공간·다른 Page·finish는 쓰지 않았다. 실행은 모두 설정 → 조작 → 측정 → 캡처 → `finally resetViewport` 순서였고, 실행이 끝날 때마다 p4가 `innerWidth 1716, pointer:coarse false, maxTouchPoints 0`으로 돌아온 것을 확인했다
- ego: 안내서 v2.1.0 (끝 표식 확인). 실행마다 `Ego Lite update is available (current 0.6.1.13)`가 떴지만 설치 금지라 업그레이드하지 않았다
- 제공 파일 = HEAD: `http://127.0.0.1:8769/`의 `preview.html`, `core.css`, `themes/neutral.css`, `themes/paper.css`가 `git show HEAD:` 내용과 SHA-256이 같다
- 다시 돌리지 않음: guard·deploy_gate·plans 테스트 (지시대로 이번 변경과 무관). `claude plugin validate .`는 통과(경고만), 두 mjs는 `node --check` 통과

## 결론

**F1·F2(P1)는 해결됐다.** 측정이 첫 화면만 보던 문제는 렌더된 DOM 전체로 바뀌어, 스크롤하지 않은 320·390px에서도 화면 아래 24px 버튼과 꺾인 탭 링크를 잡는다. 320px·글자 200%에서 메뉴 버튼은 한 줄이고, nowrap을 빼는 회귀도 잡는다. F3·F5·F6·F8·F9도 해결됐다.

**F4는 일부만 해결됐고, 고치는 과정에서 새 오탐이 생겼다 (R1, P2).** 의도한 가로 스크롤 안의 마지막 탭이, 조상 중 하나(body, 둥근 패널)에 `overflow-x:hidden|clip`이 있으면 `clipped-by-ancestor`로 나온다. smoke는 이 유형을 실패로 처리한다. 그래서 망가진 곳이 없는 화면도 실패하고, smoke의 "숨긴 넘침 탐지" 단언은 이 오탐만으로도 참이 된다. S4(프로젝트 위임) 전에 고치기를 권한다. 나머지(R2~R4)는 P3이다.

## 1. smoke 재실행 (`runSmoke` 그대로, TaskSpace 10 p4)

```
{ rows: 44, touchMenu, keyboardMenuAndLastLink, systemMode, brokenFixtureDetected,
  enlargedText, belowFoldRegression, closedDetailsExcluded, maskedOverflowDetected: 모두 true }
```

- 7.8초. 44행 모두 실제 innerWidth = 요청 폭, `<768`이면 pointer:coarse이고 아니면 아니다. 모든 행에서 `measuredControls 8 / measuredNowrap 4`였다 (요약 1 + 탭 링크 3이 매번 측정됨)
- 실행 뒤 p4 reset 확인. 원시 결과: `/tmp/s3-reval-20261031/smoke.json` (검증자 로컬, 임시)

## 2. 이전 발견 문제별 판정

| # | 판정 | 근거 (검증자 실행) |
|---|---|---|
| F1 화면 아래 미검사 | **해결** | 320px, 스크롤 0에서 `#preview-save` 24px(y 1246, innerHeight 844) → `small-target`, 탭 3개를 꺾이게 하면 → `nowrap-contract-candidate` 3개. 작성자 반례와 다른 변형: 390px에서 저장 버튼만 24px → `small-target` 1개 / 두 번째 탭만 `max-width:90px`로 꺾음 → 그 링크 1개만 후보. `counts.offscreen 5`와 `coverageWarnings`에 "offscreen geometry measured…"가 나와서 첫 화면 밖도 쟀다는 것이 결과에 남는다. smoke의 `page.focus("#preview-save")` 뒤 실제로 `scrollY 0 → 332`, 버튼 top 751 < 844 (아래 영역을 실제로 방문함) |
| F2 글자 200% 메뉴 꺾임 | **해결** | 320px + `html{font-size:200%}`: summary `white-space:nowrap`, 줄 1개, 115×66. 브랜드는 단어 단위로 2줄(`37writes /`·`UI 시험 화면`). 문서 넘침 없음(320 = 320). 캡처 `zoom200-320-closed.png`·`zoom200-320-open.png`를 직접 열어 봤다: "▶ 메뉴"가 한 줄이고, 열린 메뉴 항목 3개가 left 55~right 295, 높이 68, hit-test 모두 true. 회귀 확인: summary를 `white-space:normal` + 메뉴 축소 허용으로 되돌리면 2줄(73×165)이 되고 기본 옵션 `measureUI`가 `nowrap-contract-candidate #menu-toggle`을 낸다 (기본 `nowrapSelector`에 summary가 들어감) |
| F3 닫힌 details 오탐 | **해결** | 문서 예시 선택자 `header button, header a, [role=tab]`로 닫힌 메뉴를 재면 `hidden 3, inspected 0`, 후보 0개. 메뉴를 열면 `inspected 3`, 후보 0개 (열린 상태는 정상 측정) |
| F4 숨긴 넘침 | **일부 해결 + 새 오탐** | `?broken=1` + `html,body{overflow-x:hidden}`(390): `environmentMatches true`, 문서 넘침 0이지만 `#menu-toggle`(x 842)과 `#preview-title`(512px)이 `outside-viewport`·`clipped-by-ancestor <body>`로 잡힌다 → 숨긴 **조작 요소** 넘침은 탐지된다. 하지만 대조군에서 오탐이 나왔다 (R1). 조작 요소가 아닌 글 넘침은 여전히 못 잡는다 (R2) |
| F5 blog TaskSpace | **해결** (작은 정리 R3) | K3 앞 문단: 코디네이터가 TaskSpace 하나를 만들거나 `state.md`의 spaceId로 재사용하고, 첫 글 p1·다음 글 `newPage()`, spaceId·Page를 state.md와 spec.md에 기록한다. spec `대상`에 `ego spaceId <id> / Page <label>`, `제약`에 "배정된 Page만, 새 TaskSpace/finish 금지"가 있다. 검수 Codex 워커는 PNG만이면 Page를 배정하지 않는다. 7. 정리 5번에서 `finish({ keep: [] })`를 정확히 한 번, 다른 워커가 쓰는 중이거나 사용자 제어·오류면 하지 않는다. 다른 세션이 만든 agent 소유 공간을 `taskSpace(10)`으로 이어 쓸 수 있다는 것은 이번 실행으로 확인했다 (워커가 배정 공간을 이어 쓰는 방식이 실제로 가능) |
| F6 기존 모드 연결 | **해결** | system.md 어댑터는 `data-bs-theme`를 읽어 `data-kit-mode`를 설정하거나 지울 뿐이고, localStorage·팔레트 값을 쓰지 않는다. CSS 매핑에도 dark 색값을 다시 적지 말라고 한다. tech-blog의 Chirpy 7.6.0 gem(`vendor/bundle`)과 정적으로 대조했다: `_layouts/default.html:15`가 `<html data-bs-theme="{{ site.theme_mode }}">`, `theme.min.js`가 모드를 localStorage에 저장하고, 시스템 모드면 저장 값을 지운 뒤 해석한 값(light/dark)을 속성에 넣고 media change에서 다시 갱신한다. 그래서 어댑터는 Chirpy 저장소 하나만 원본으로 두고 따라간다 (저장소 이중화 없음). 실제 블로그 적용 실행은 S4 범위라 하지 않았다 |
| F7 샘플 범위 | **명시적 한계로 수용** | system.md가 preview를 "토큰/테마를 보는 시험 화면"으로 부르고, tablist/tabpanel·데스크톱→모바일 전환·loading/error가 없다고 적는다. 실제 부품은 TTC·블로그 후속 작업에 위임됐다 (지시대로 범위를 넓히지 않음). 부분 개선 확인: 탭 링크의 `aria-current="location"`이 hash를 따라 옮겨진다 (smoke 단언 + core.css 선택자 `[aria-current]:not([aria-current="false"])`) |
| F8 input 오탐 | **해결** | 320·390 정상 화면에서 긴 값 input에 `clipped-control`이 나오지 않는다. 진짜로 밖에 나간 input(`?broken=1`)은 `outside-viewport`로 잡힌다 |
| F9 모드 버튼 | **해결** | 390px, media dark에서 클릭 3번: light(`#f5f5f7`) → dark(`#18181b`) → 시스템(속성 없음, media dark라 `#18181b`, 라벨 "시스템") → light. 터치로 연 메뉴: 메뉴 밖 터치로 닫힘, Escape로 닫히고 초점이 `#menu-toggle`로 감 (이전 A의 관찰 해소) |

## 3. 남은 문제

### P2

**R1. 스크롤 컨테이너 안의 의도한 넘침을 바깥 조상의 `overflow:hidden` 잘림으로 오판한다** — `ego-audit.mjs` 조상 순회(66~77행)는 `scrollOwner`(`.kit-scroll`)를 찾은 뒤에도 멈추지 않고 위로 올라가서, 바깥 조상의 `overflow-x: hidden|clip` 범위와 요소 rect를 비교한다. 스크롤 컨테이너 안에서 아직 보이지 않는 마지막 탭은 이미 그 컨테이너가 잘라 보여 주는 것이라, 바깥 조상과 비교하면 항상 밖에 있다.

| 대조군 (390, 다른 망가짐 없음) | 결과 |
|---|---|
| `html,body{overflow-x:hidden}` | `clipped-by-ancestor a <body>` + `outside-scroll-window a` (같은 마지막 탭) |
| `#work{overflow-x:hidden}` (둥근 패널에 흔히 붙이는 값) | `clipped-by-ancestor a <section#work>` |
| `#work{overflow:clip}` | 같음 |

- 영향: `body{overflow-x:hidden}`은 가로 넘침을 감추는 흔한 "임시 수정"이고, 모서리를 둥글게 하려고 패널에 `overflow:hidden`을 붙이는 것도 흔하다. 그 안에 가로 스크롤 탭이 있는 화면(사용 시나리오 2, TTC 작업 화면에 탭 추가)은 망가진 곳이 없어도 `clipped-by-ancestor`가 나온다. ego-validation.md는 이 유형을 "실패 원인을 조사"하라고 하고, smoke의 `assertGeometry`는 실패로 처리한다. 오탐이 반복되면 사용자가 후보를 무시하게 된다 (이전 F3과 같은 위험).
- smoke 단언도 약해졌다: `maskedOverflowDetected`의 조건 `some(clipped-by-ancestor || outside-viewport)`는 이 오탐 하나로도 참이 된다 (첫 대조군이 그 예). 이번에는 `?broken=1` 화면에 진짜 `outside-viewport`(`#menu-toggle`, `#preview-title`)가 함께 있어서 결과는 맞았지만, 단언이 그것을 확인하지는 않는다.
- 제안: 순회에서 `scrollOwner`를 찾으면 그 위 조상의 hidden/clip 비교를 멈춘다 (또는 스크롤 컨테이너 rect를 기준으로 비교한다). smoke의 숨긴 넘침 단언은 `outside-viewport`가 `#menu-toggle` 또는 `#preview-title`에 있는지 직접 확인하게 좁히고, 대조군 행(정상 화면 + `body{overflow-x:hidden}`, 패널 `overflow:hidden` → `clipped-by-ancestor` 0개)을 추가한다.

### P3

**R2. 조작 요소가 아닌 콘텐츠의 숨긴 넘침은 여전히 못 잡고, 한계 목록에도 없다** — `html,body{overflow-x:hidden}` + `#reading p{min-width:600px}`(390): 캡처 `masked-text-390.png`에서 읽기 문단 오른쪽 글자("…있도록", 긴 주소)가 잘려 보이는데, `measureUI`는 문서 넘침 0(`scrollWidth 390 = clientWidth 390`)이고 후보는 R1의 탭 오탐 하나뿐이다. 같은 CSS를 hidden 없이 넣으면 `document-horizontal-overflow 226px`로 잡힌다. ego-validation.md 3번은 "overflow:hidden으로 잘라 숨긴 것도 실패"라고 하지만 `limitations`에는 "조작 요소 외 콘텐츠는 검사하지 않음"이 없다. 제안: 한계에 그 문장을 넣거나, root/body가 `overflow-x: hidden|clip`이면 그 사실을 `coverageWarnings`에 넣어 캡처로 확인하게 한다. 이전 F4 제안 중 이 부분은 반영되지 않았다.

**R3. blog 기록 항목과 정리 순서가 새 ego 단계와 조금 어긋난다** — (a) `skills/blog/SKILL.md:93`의 `state.md` 항목 목록에 spaceId·Page가 없다. K3(114행)은 state.md에 기록하라고 하는데, 재시작할 때 읽는 형식에는 없다. (b) 7. 정리는 4번에서 `<inbox>/<slug>`(state.md 포함)를 지운 뒤 5번에서 spaceId로 finish한다. 시리즈의 마지막 글이면 spaceId가 적힌 마지막 파일이 finish 전에 지워진다. 같은 세션이면 대화에 남아 있어 문제가 없지만, 그 사이에 코디네이터가 재시작하면 `listTaskSpaces()`로 다시 찾아야 한다. 제안: 93행에 `ego spaceId·Page label`을 더하고, 5번을 4번 앞으로 옮기거나 "spaceId를 먼저 읽어 둔다"를 적는다.

**R4. Ego Lite 업데이트 알림** — 0.6.1.13에서 업데이트가 있다고 계속 나온다. 설치 금지라 업그레이드하지 않았고, 사용자 승인이 필요하다 (이전 F10과 같음).

## 4. 미검증

- 실기기·iOS Safari·가상 키보드 (ego Chromium 에뮬레이션만 사용)
- 실제 Chirpy 화면에서 어댑터 실행 (정적 대조만 함. 적용은 S4 범위)
- 실제 블로그 코디네이터가 TaskSpace를 만들고 글 워커에 Page를 넘기는 흐름 (문서 대조만 함)
- shadow DOM·iframe·virtualized 목록 (문서의 한계와 같음)
- guard·deploy_gate·plans·`claude plugin test .` 재실행 (지시대로 생략, 이번 diff와 무관)

## 5. 재현

서버: `http://127.0.0.1:8769/` (이 worktree의 `skills/design/assets` 제공, 해시 = HEAD). 스크립트: `/tmp/s3-reval-20261031/round-02.mjs`(F1·F2·F3·F8·메뉴 터치), `round-03.mjs`(F4·R1·R2 대조군), `round-05.mjs`(F9·아래 영역 방문). 실행은 `ego-browser nodejs < <파일>`. 결과 JSON·캡처도 같은 폴더에 있다 (임시).

R1 최소 재현:

```js
const task = await taskSpace(10); const page = task.page("p4");
const A = await import("file:///<worktree>/skills/design/scripts/ego-audit.mjs");
try {
  await A.configureViewport(page, { width: 390, mobile: true, mode: "light" });
  await page.goto("http://127.0.0.1:8769/preview.html");
  await page.evaluate(() => { document.documentElement.style.overflowX = "hidden"; document.body.style.overflowX = "hidden"; });
  const a = await A.measureUI(page, { expectedWidth: 390, expectedMobile: true });
  console.log(a.issues.map(i => `${i.type}:${i.tag}<${i.ancestor?.tag ?? ""}`));
  // → [ "clipped-by-ancestor:a<body", "outside-scroll-window:a<" ]  (정상 화면인데 smoke 기준 실패)
} finally { await A.resetViewport(page); }
```

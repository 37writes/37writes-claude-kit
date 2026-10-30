# S3 독립 검증: 개인 디자인 시스템과 ego lite 모바일 검증

- 검증자: Claude Opus 5.5 (`global.anthropic.claude-opus-5-5`, 워커 자기 보고), Task `task_c854fa50a5dc`, Dispatch `ctx_ec28188810ac`
- 대상: HEAD `0b99895` (base `daac2c7`). skills/design 전체, skills/blog 캡처 지시, plugin.json·marketplace.json·README·CLAUDE.md diff
- 방법: 작성자 결론과 `plan-review.md`는 근거로 쓰지 않았다. 코드를 직접 읽고, ego TaskSpace 10의 p4만 써서 `ego-smoke.mjs`를 실행했다. 실패 시나리오는 검증자가 직접 골라 `ego-audit.mjs`를 import해 돌렸다. 매 실행은 설정 → 조작 → 측정 → 캡처 → `finally resetViewport` 순서이고, 실행 뒤 p4가 `innerWidth 1716, pointer:coarse false, maxTouchPoints 0`으로 돌아온 것을 매번 확인했다. 새 TaskSpace를 만들지 않았고 finish도 하지 않았다
- ego: v2.1.0 안내서 (끝 표식까지 확인). 실행마다 `[ego-browser:notice] Ego Lite update is available (current 0.6.1.13)`가 떴지만 설치 금지라 업그레이드하지 않았다

## 결론

설정을 걸고 되돌리기, 터치로 메뉴 열고 닫기, 키보드 이동, 테마·모드 토큰, 대비는 **실제로 동작한다**. 하지만 모바일 검증을 보증한다는 핵심 주장이 실제보다 강하게 적혀 있다. 측정 도우미가 **현재 화면(첫 viewport)만** 검사해서, smoke의 좁은 폭 행(320/390 확인)은 탭·저장 버튼을 아예 검사하지 않은 채 통과했다 (F1). 시험 화면의 메뉴 버튼은 글자 200%에서 한 글자씩 세로로 꺾이는데 도우미가 잡지 못한다 (F2). P1 두 건은 S4(프로젝트 위임) 전에 고치는 것을 권한다.

## 1. 프로젝트 프로필 검사 재실행 (이 worktree, HEAD 0b99895)

| 명령 | 결과 |
|---|---|
| `claude plugin validate .` | 통과, 경고 2개 (CLAUDE.md 미로드 = 정상으로 문서화됨, plugin directory `ICON_MISSING`) |
| `sh scripts/test_guard.sh` | exit 0, ok 58 / fail 0 |
| `sh scripts/test_deploy_gate.sh` | exit 0, ok 56 / fail 0 |
| `sh scripts/test_plans.sh` | exit 0, ok 32 / fail 0 |
| `claude plugin test .` | 6 pass / 0 fail |

플러그인 버전은 `plugin.json`과 `marketplace.json` 모두 0.16.0으로 맞다. README 스킬 표와 로드맵 줄, CLAUDE.md 구조·design 설명이 갱신돼 있다.

## 2. 원본·테마·모드·규칙 정합성 (정적 + 실측)

- 제공 중인 파일 = HEAD: `http://127.0.0.1:8769`의 preview.html·core.css·neutral.css·paper.css 응답의 SHA-256이 작업 파일, `git show 0b99895:` 내용과 모두 같다 (서버 cwd = 이 worktree).
- core.css ↔ system.md: 간격 4/8/12/16/24/32/48/64, 조작 영역 44px, UI 16px / 보조 14px / 읽기 18px·줄 간격 1.8, keep-all + overflow-wrap:anywhere, 탭 nowrap + shrink 0, 모서리 10/16px가 모두 일치한다. 전역 reset 없이 `--kit-*`와 `.kit-*`만 쓴다.
- 선택자 우선순위: neutral `:root[data-kit-mode=dark]`(0,2,0) < paper `[theme=paper][mode=dark]`(0,3,0), 시스템 모드는 neutral `:root:not([data-kit-mode])`(0,2,0) < paper `[theme=paper]:not([data-kit-mode])`(0,3,0) 순서라 의도대로 겹친다. paper는 neutral에 얹는 방식(글꼴·모서리·그림자는 neutral 값)이고 파일 머리 주석에 그렇게 적혀 있다.
- 실측 (ego p4): 4개 조합의 1280px 토큰이 CSS 원본과 같고 (smoke `colors`), paper + 시스템 dark(`data-kit-mode` 제거, media dark)에서 `--kit-bg #1c1a17`, `--kit-accent #efac84`, body `color-scheme: dark`.
- 대비 (WCAG 공식으로 다시 계산): 4개 조합 × 본문 쌍 12개(text/muted/accent/danger/success/on-accent ↔ bg/surface/surface-alt/accent)가 모두 4.5:1 이상 (최저 paper light `muted/surface-alt` 5.26), 기능선·포커스 쌍 5개가 모두 3:1 이상 (최저 paper light `control-border/bg` 3.85). 선택된 탭(`on-accent/accent`)은 6.56~8.06.
- 참조 경로: SKILL.md의 references·assets·`../harness/SKILL.md`·`../../scripts/contrast.py`, blog의 `../design/references/ego-validation.md`가 모두 있다. `shot.py`를 지시하는 곳은 design·blog에 없다 (남은 곳은 `scripts/shot.py` 자체, CLAUDE.md의 호환용 설명, 과거 devlog).

## 3. ego 실조작·모바일 측정

### 3.1 작성자 smoke 재실행 (`ego-smoke.mjs` 그대로)

결과: `{ ok: true, rows: 44, touchMenu, keyboardMenuAndLastLink, systemMode, brokenFixtureDetected 모두 true }`, 4.1초. 모든 행에서 실제 innerWidth가 요청 폭과 같았고 `<768`에서 pointer:coarse였다. 실행 뒤 reset 확인.

### 3.2 검증자가 고른 시나리오

| # | 상황 (현실 사례) | 조작·측정 | 결과 |
|---|---|---|---|
| A | 휴대폰에서 메뉴를 터치로 열고 마지막 항목 선택 (320 neutral light, 320 paper dark, 360 paper light) | `Input.dispatchTouchEvent`로 열기 → 링크 3개 rect·hit-test → 캡처 → 메뉴 밖 터치 → Escape → 마지막 항목 터치 | **통과**: 항목 3개 모두 화면 안(320에서 left 55~right 295), 높이 62px, hit-test true, 마지막 항목 선택 시 닫히고 `#work`. **관찰**: 열린 메뉴가 h1을 덮고, 메뉴 밖 터치로 닫히지 않으며, 터치로 연 뒤 Escape는 효과 없음(초점이 BODY라 menu의 keydown 리스너가 안 받음) |
| B | 탭 높이를 24px로 줄인 회귀 (390) | 기본 선택자 / `a[href]` 포함 선택자로 `measureUI` | **놓침**: 둘 다 후보 0개. 탭이 첫 화면 아래(top 864 > 844)라 검사에서 빠짐 → F1 |
| C | 넘침을 `html,body{overflow-x:hidden}`으로 가린 "임시 수정" (`?broken=1`, 390) | `measureUI` 기본값 | **일부만 잡음**: `environmentMatches true`, `document-horizontal-overflow` 없음. `outside-viewport` 후보(메뉴 버튼, 512px 입력창)만 남음. 캡처에서 오른쪽 글자가 잘린 게 보임 → F4 |
| D | 데스크톱 가로 메뉴를 모바일에서 접지 않음 (320, nowrap 링크 5개 주입) | 문서 예시 선택자 `header button, header a, [role=tab]` | **잡음**: 실제 innerWidth 360(요청 320) → `viewport-width` 불일치 + 넘침 40px. 같은 메뉴를 줄어들게 만들면 `small-target` 24px·nowrap 후보 5개. 단, 닫힌 메뉴 링크 3개도 후보로 섞임 → F3 |
| E | 화면 아래 저장 버튼을 20px로 줄인 회귀 (320) | 첫 화면 측정 → 버튼까지 스크롤 후 재측정 | **첫 화면 0개**, 스크롤 뒤에야 `small-target 93×26.8`. 정상 입력창이 `clipped-control`로 오탐 → F1, F8 |
| F | 글자 200% (320, `html{font-size:200%}`) | 전체 조작 요소 + `.kit-tab` nowrap | **놓침**: 후보 0개(첫 화면 4개만 검사). 캡처에서 헤더 "메뉴" 버튼이 "▶ / 메 / 뉴"로 한 글자씩 세로로 꺾임 → F2 |
| G | 탭 줄 끝까지 터치로 도달 (390) | 탭 영역에서 touchStart→touchMove×10→touchEnd 스와이프 → 마지막 탭 터치 | **통과**: scrollLeft 0 → 144(최대 144), 마지막 탭 터치로 `#intro`. `aria-current`는 첫 탭에 그대로 → F7 |
| H | smoke의 좁은 폭 탭 검사가 실제로 탭을 봤는지 | 폭마다 탭 top, 탭을 줄바꿈 가능하게 주입한 뒤 smoke와 같은 옵션으로 측정 | 탭 top: 320 → 897, 390 → 864 (innerHeight 844, 첫 화면 밖), 767·768 → 785, 1280 → 518. 줄바꿈 주입 시 탭당 4줄(320)·2줄(390)인데 `nowrap-contract-candidate` 0개 → F1 |

캡처 (검증자 로컬, 임시): `/tmp/s3-design-ego-20261031/` — `A-menu-320-paper-dark.png`, `C-masked-390.png`, `F-zoom200-320.png`, `I-swipe-390.png` 등. 직접 열어 확인했다. 원시 결과: 같은 폴더의 `smoke.json`, `scenarios.json`.

## 4. 발견 문제 (우선순위순)

### P1

**F1. 측정 도우미가 첫 화면만 검사해서 좁은 폭 smoke 통과에 근거가 없다** — `ego-audit.mjs:38` `visible()`의 `r.bottom > 0 && r.top < innerHeight`. smoke는 스크롤하지 않으므로 320·390px에서 작업 화면의 탭·입력·버튼이 검사에서 빠진다 (H: 탭을 4줄로 꺾어도 0개, E: 저장 버튼 20px도 0개). 그런데 `ego-smoke.json`과 기획서 S2는 "44개 폭/테마/모드 조합 통과"라고 적는다. 사용자가 가장 신경 쓰는 "모바일에서 탭·메뉴가 깨지지 않음"이 좁은 폭에서는 키보드 1건(390)과 터치 메뉴 1건으로만 확인된 셈이다.
제안: 문서 전체를 검사하거나(문서 좌표로 바꾸고 viewport 조건은 별도 플래그로) 스크롤 구간마다 측정한다. 결과에 `skippedOffscreen` 수를 넣고, smoke는 `#work`로 스크롤한 행을 추가해 탭이 `inspected`에 들어갔는지 assert한다. ego-validation.md에 "후보 0개 + inspected가 대상보다 작으면 미검사"를 적는다.

**F2. 시험 화면의 메뉴 버튼이 글자 확대에서 한 글자씩 꺾이는데 도우미와 smoke가 놓친다** — preview.html의 `.preview-menu summary`에 `white-space:nowrap`·`flex-shrink:0`이 없고, 헤더는 `justify-content:space-between` flex라 320px + 200%에서 "메/뉴"가 된다 (F 캡처). SKILL.md 표 마지막 줄이 금지한 증상을 kit의 기준 화면이 갖고 있다. `measureUI`의 nowrap 검사는 `nowrapSelector`를 줄 때만 돌고 기본값이 빈 문자열이며, smoke는 `.kit-tab`만 주고 글자 확대 행이 없다 (SKILL 5-3, ego-validation "글자 확대"는 요구함).
제안: summary(메뉴 버튼)에 nowrap + shrink 0, 브랜드 쪽에 `min-width:0`. 기본 `nowrapSelector`에 `summary, [role=tab], nav a`를 넣고, smoke에 320 + `font-size:200%` 행을 추가한다.

### P2

**F3. 닫힌 `<details>` 안 링크를 보이는 요소로 센다** — 닫힌 메뉴 링크 3개가 `checkVisibility()`는 false인데 rect 78×68이 나와서, 문서 예시 선택자(`header a`)로 측정하면 `outside-viewport`·`nowrap` 후보로 섞인다 (D, C). 메뉴가 details인 프로젝트(이 시험 화면 포함)에서 오탐이 쌓이면 사용자가 후보를 무시하게 된다. 제안: `visible()`에 `el.checkVisibility({ contentVisibilityAuto: true, visibilityProperty: true })`를 쓴다.

**F4. `overflow:hidden`으로 가린 넘침을 문서 넘침으로 못 잡고, smoke assert에 `outside-viewport`가 없다** — ego-validation.md 3번 "overflow:hidden으로 잘라 숨긴 것도 실패다"와 달리 C에서 `environmentMatches true`, 넘침 0. 남은 신호는 `outside-viewport` 후보뿐인데, 이 유형은 의도한 가로 스크롤(`.kit-scroll`의 마지막 탭)과 구분하지 않아 smoke도 무시한다. 제안: 가장 가까운 스크롤 컨테이너 안에 있는 요소는 빼고(`overflow-x: auto|scroll` 조상), 나머지 `outside-viewport`는 smoke에서 실패로 assert한다. root/body의 `overflow-x: hidden|clip` + `scrollWidth > clientWidth`도 후보로 보고한다.

**F5. blog 흐름에 TaskSpace를 만들고 넘겨주고 정리하는 단계가 없다** — `skills/blog/SKILL.md:282`는 "코디네이터가 목표당 TaskSpace 하나를 만들고 워커별 Page를 할당한다"고 하지만, K2·K3 글 워커 작업 지시 양식(124~131행)에 spaceId·Page 칸이 없고, 7. 정리(339~)에 `finish`가 없다. 글 워커는 받은 지시만 보므로 자기 TaskSpace를 새로 만들거나(ego 규칙 위반) 멈추게 된다. 제안: 코디네이터 K3에 "TaskSpace 생성/재사용 → `newPage()` → spec의 대상에 `ego: space <id>, page <label>`", K7 정리 끝에 `finish({ keep: [] })`를 넣는다. 검수 Codex 워커는 캡처 경로만 받으므로 Page가 필요 없다고 적는다.

**F6. 기존 모드 속성(Chirpy 등)을 연결할 방법이 없다** — system.md는 "기존 모드 속성이 있으면 그 선택을 연결하고 모드 저장소를 두 개 만들지 않는다"고 하지만, 테마 CSS의 dark는 `data-kit-mode`와 media에만 반응한다. tech-blog(Chirpy `data-mode`/`data-bs-theme`)에 paper를 적용하는 현실적인 사례 1에서 `theme-map.css`가 dark 토큰 13개를 복사하면(원본과 어긋날 수 있음, "같은 테마면 원본 값이 같아야" 위반 위험) 되고, 아니면 기존 토글 JS에서 `data-kit-mode`를 같이 설정해야 하는데 둘 다 안내가 없다. 제안: system.md에 권장 방식 하나를 적는다 (예: 기존 토글이 바꾸는 속성을 그대로 두고 같은 코드에서 `data-kit-mode`를 미러링, 저장은 기존 저장소만 사용, 시스템 모드면 속성 제거).

**F7. 샘플은 테마·토큰 미리보기로는 충분하지만, 실제 버튼·탭·메뉴 부품의 기준으로는 부족하다** — (a) 탭은 해시 링크 목록이라 선택해도 `aria-current`가 바뀌지 않고(G), system.md "화면 내 탭"의 tablist/tabpanel·좌우 키·Home/End 예시가 없다. (b) 메뉴는 모든 폭에서 details라서, 가장 흔한 깨짐인 "데스크톱 가로 메뉴 → 좁은 폭 disclosure 전환"의 기준 예시와 전환점 테스트가 없다 (D는 주입으로만 확인). (c) 터치로 연 메뉴는 밖을 터치하거나 Escape를 눌러도 닫히지 않고 본문 제목을 덮는다 (A). native details의 동작이지만 모바일 메뉴 기준으로 쓰기엔 계약(system.md)에 "밖 터치 시 닫힘 여부"가 정해져 있지 않다. (d) 버튼의 loading/error 상태 예시가 없다. 제안: preview를 "토큰 미리보기"로 부르거나, 반응형 nav 하나와 진짜 tablist 하나를 최소 예시로 더하고 smoke에 전환점 ±1 터치·좌우 키 검사를 붙인다. 프로젝트에 옮길 때 이 샘플을 부품으로 복사하지 말라는 문장이 system.md에 있으므로(“실제 제품의 부품 라이브러리를 대신하지 않는다”) 즉시 차단 사항은 아니다.

### P3

**F8. 긴 값을 가진 정상 입력창을 `clipped-control`로 오탐** — Chromium input의 계산된 `overflow-x`가 clip이라 값이 폭보다 길면 항상 후보가 된다 (E, H). 제안: input/textarea는 이 검사에서 뺀다.

**F9. 모드 버튼이 시스템 모드(속성 없음)를 표현하지 못한다** — 시스템 dark 상태에서 라벨은 "다크 모드 보기"인데 누르면 light가 된다 (G). 시험 화면에서 시스템 상태로 갈 UI가 없고 `aria-pressed`도 없다. 3단(light/dark/system) 예시가 system.md의 모드 규칙과 맞다.

**F10. Ego Lite 업데이트 알림** — 0.6.1.13에서 업데이트가 있다고 나온다. 설치 금지라 업그레이드하지 않았고, 사용자 승인이 필요하다.

## 5. 현실적인 사용 시나리오 판단

1. **tech-blog 모바일 메뉴 수정 + paper 적용**: 프로필 → vendoring(버전·해시) → theme-map → ego 측정 순서는 따라갈 수 있다. 막히는 곳은 F6(Chirpy 모드 연결)과 F5(블로그 워커의 TaskSpace). 측정은 문서 예시 선택자를 쓰면 F3 오탐이 섞이고, 메뉴가 첫 화면 안에 있으므로 F1의 영향은 작다.
2. **TTC 작업 화면에 탭 추가**: 탭이 보통 첫 화면 아래나 패널 안에 있어서 F1 영향이 가장 크다. 스크롤해서 측정하라는 지시가 없으면 "후보 0개"가 나오기 쉽다. 진짜 tablist 예시가 없어(F7a) 좌우 키·tabpanel은 프로젝트가 처음부터 만들어야 한다.
3. **"이 화면 AI 티 안 나게" 작은 수정**: SKILL.md 1~3절의 "프로필 재사용, 방향 재질문 금지, 맥락 진단 표"는 일관성 목표에 맞게 쓰여 있고 Apple 참고를 "위계·정렬·절제"로 한정한 것도 요구에 맞다. 글자 확대 검사를 실제로 돌리게 하는 장치가 없어서 F2 같은 깨짐은 사람이 캡처를 봐야 발견된다.

## 6. 미검증

- 실기기·iOS Safari·가상 키보드 (ego Chromium 에뮬레이션만 사용)
- 웹폰트 실제 로드 (자산에 폰트 파일 없음, 시스템 fallback으로만 확인)
- 360·430·639~641px에서 첫 화면 밖 요소 (320·390에서만 F1 확인, 767·768·1280은 탭이 첫 화면 안)
- `page.click()` 마우스 경로, hover 상태, reduced-motion, Windows/다른 OS의 글꼴 폭
- 실제 프로젝트(TTC, tech-blog) 적용과 `claude -p`로 design 스킬 전체 실행 (S4 범위이고 이번 지시에서 다른 프로젝트 수정 금지)
- `quick_validate.py` (PyYAML 없음, 설치 금지)

## 7. 재현 명령

로컬 서버: 이 worktree의 `skills/design/assets`가 `http://127.0.0.1:8769/`에서 제공되고 있었다 (예: `cd skills/design/assets && sh ../../../scripts/py.sh -m http.server 8769 --bind 127.0.0.1`).

```sh
# 프로필 검사
claude plugin validate . && sh scripts/test_guard.sh && sh scripts/test_deploy_gate.sh && sh scripts/test_plans.sh && claude plugin test .

# smoke (기존 TaskSpace 10의 p4)
ego-browser nodejs <<'EOF'
const task = await taskSpace(10); const page = task.page("p4");
const { runSmoke } = await import("file:///<worktree>/skills/design/scripts/ego-smoke.mjs");
console.log(JSON.stringify(await runSmoke(page, "http://127.0.0.1:8769/preview.html")).slice(0, 400));
EOF
```

F1·F2 재현 (한 실행 안에서 설정 → 측정 → reset):

```js
const task = await taskSpace(10); const page = task.page("p4");
const A = await import("file:///<worktree>/skills/design/scripts/ego-audit.mjs");
try {
  await A.configureViewport(page, { width: 320, mobile: true, mode: "light" });
  // F1: 탭을 꺾이게 해도 첫 화면 밖이라 후보 0개
  await page.goto("http://127.0.0.1:8769/preview.html");
  await page.evaluate(() => { const s = document.createElement("style"); s.textContent = ".kit-tab{white-space:normal!important;flex-shrink:1!important}.kit-tabs{inline-size:auto!important}"; document.head.append(s); });
  console.log((await A.measureUI(page, { expectedWidth: 320, expectedMobile: true, nowrapSelector: ".kit-tab" })).issues);
  // F2: 글자 200%에서 메뉴 버튼이 한 글자씩 꺾임 (캡처로 확인, 도우미 후보 0개)
  await page.goto("http://127.0.0.1:8769/preview.html");
  await page.evaluate(() => { document.documentElement.style.fontSize = "200%"; });
  console.log((await A.measureUI(page, { expectedWidth: 320, expectedMobile: true })).issues);
  console.log(await page.screenshot({ path: "/tmp/zoom200-320.png" }));
} finally { await A.resetViewport(page); }
```

F3: 같은 방식으로 `?` 없이 열고 `page.evaluate(() => [...document.querySelectorAll(".preview-menu a")].map(a => [a.checkVisibility(), a.getBoundingClientRect().width]))` → `[false, 78]`.
F4: `?broken=1`로 연 뒤 `html,body{overflow-x:hidden}`을 넣고 `measureUI({ expectedWidth: 390, expectedMobile: true })` → `environmentMatches: true`, `document-horizontal-overflow` 없음.

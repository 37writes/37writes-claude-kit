# 기획 반박: 개인 디자인 시스템과 ego lite 모바일 검증

- 대상: `docs/plans/2026-10-31-design-system-ego.md` (status: draft, 미추적 파일)
- 검토자 실행 모델: **Claude Opus 5.5** (`global.anthropic.claude-opus-5-5`, 시스템 프롬프트 기준 자기 보고). Task `task_a5d6c7659adb`, Dispatch `ctx_1ab7824ad563`
- 읽은 것: 기획서 전체, `skills/design/SKILL.md`(95줄), `skills/blog/SKILL.md:270-290`, `CLAUDE.md:51`, `ego-browser skill` 출력(ego-browser 0.6.1.13, chromium 156, 안내서 v2.1.0)
- 브라우저는 실행하지 않았다 (작업 지시). 아래 반례 1의 CDP 동작은 **미확인**이고 확인 방법을 적었다.

## 결론 요약

방향(규칙과 테마 분리, ego 전용, 판정이 아니라 측정 도우미, CSS만으로 반응형을 약속하지 않음)은 맞다. 다만 S2 전에 다음 셋을 기획서에 반영해야 한다.

1. ego 모바일 에뮬레이션이 **스크립트 실행 한 번 안에서만** 유지될 수 있고, 클릭이 터치가 아니다 → "모바일 메뉴 실조작" 검증이 데스크톱 상태에서 거짓 합격할 수 있다.
2. "Apple 같은 단순함"이 현재 체크리스트의 고정 규칙(모서리 0~4px, 그림자 없음, 글꼴 분리, glass 금지)과 부딪친다 → 스킬이 자기 결과물을 "AI 티"로 진단하거나, 반대로 규칙을 무시하게 된다.
3. "모든 작업에서 일관되게"의 원본이 정해지지 않았다 → 프로젝트마다 복사한 토큰이 따로 바뀌고, Apple 시스템 글꼴은 Windows·Android에서 다른 글꼴로 바뀐다.

추가로 범위 누락 1건: blog 스킬이 계속 `shot.py`(Chrome headless)로 캡처해서 "브라우저는 ego lite만"을 어긴다.

---

## 반례 1. ego 에뮬레이션이 다음 실행에서 풀리고, 클릭은 터치가 아니다 (영향 큼)

**근거**
- 기획서 21행: "CDP 모바일 에뮬레이션, … 넘침·탭·메뉴 실조작". 23행: 도우미는 "ego Page를 받아 viewport 불일치… 측정".
- ego 안내서: "Every invocation starts a new Node.js process. Task spaces, tabs, and Page labels persist; JavaScript variables do not." Page API에 viewport·기기·color-scheme 래퍼가 없다. 남은 길은 `page.cdp()`인데, 안내서가 나열한 도메인은 "Page, Runtime, DOM, Network, Input, and similar"이고 `Emulation`은 명시돼 있지 않다. 또 "Raw CDP invalidates refs".
- ego lite는 사용자가 쓰는 실제(화면 있는) 브라우저다. 창 폭을 320px로 줄일 수 없으니 좁은 폭은 `Emulation.setDeviceMetricsOverride`에 기댈 수밖에 없다.

**반례 시나리오**
- Chromium에서 `Emulation.*` 덮어쓰기는 CDP 세션에 묶이고 세션이 끊기면 대개 풀린다. 1회차 스크립트에서 390px로 설정하고 끝나면, 2회차(새 Node 프로세스)에서 메뉴를 열고 측정할 때는 데스크톱 폭이다. 이때 햄버거 메뉴는 아예 없고 데스크톱 내비가 보여서 "넘침 0, 메뉴 정상"으로 거짓 합격한다.
- `page.click()`은 마우스 이벤트다. `:hover`로 여는 하위 메뉴, `pointerdown`/`touchstart`만 듣는 메뉴, `(hover: none)`·`(pointer: coarse)` 미디어 쿼리 분기는 마우스로는 통과하고 실제 폰에서는 깨진다. 사용자가 원한 "깨지지 않는 모바일 메뉴"의 대표 실패가 바로 여기에 있다.
- `screenshot()`이 에뮬레이션된 크기로 찍히는지도 안내서에 없다.

**확인 방법 (S2 구현자가 ego lite로)**
1. 스크립트 A: `page.cdp("Emulation.setDeviceMetricsOverride", {width:390,height:844,deviceScaleFactor:3,mobile:true})` → `evaluate(() => innerWidth)` 출력. 스크립트 B(새 실행): 같은 Page에서 `innerWidth`만 출력. B가 390이 아니면 에뮬레이션은 실행 하나 안에서만 유지된다.
2. 같은 스크립트에서 `Emulation.setTouchEmulationEnabled`·`setEmitTouchEventsForMouse`·`setEmulatedMedia({features:[{name:"prefers-color-scheme",value:"dark"}]})`가 거부되는지 본다. 그다음 `matchMedia("(pointer: coarse)").matches`와 `matchMedia("(prefers-color-scheme: dark)").matches`를 확인한다.
3. `:hover`로만 열리는 메뉴를 넣은 시험 화면에서 `page.click()`과 `Input.dispatchTouchEvent`의 결과를 비교한다.
4. `screenshot()`의 PNG 크기가 390×dpr인지 확인한다.

**수용 가능한 설계 보완**
- `ego-validation.md`에 규칙을 둔다: **에뮬레이션 설정, 조작, 측정, 캡처, 초기화(`Emulation.clearDeviceMetricsOverride`)를 한 스크립트 실행 안에서 끝낸다.** 측정 결과마다 그 시점의 `innerWidth`·`devicePixelRatio`·`matchMedia` 값을 같이 기록하고, 요청한 폭과 다르면 그 행은 무효로 표시한다 (23행의 "viewport 불일치"를 행 단위 무효 처리로 구체화).
- 메뉴 실조작은 터치 경로(`Input.dispatchTouchEvent` 또는 터치 에뮬레이션)로 한다. 되지 않으면 "터치 미검증, 마우스로만 확인"이라고 한계에 적는다. 마우스 결과를 터치 합격으로 보고하지 않는다.
- `Emulation` 도메인이 막혀 있으면 좁은 폭 검증은 할 수 없다. 이때 Playwright·headless로 돌아가지 않고(29행) 멈춰서 보고한다는 문장을 기획서에 넣는다.
- 에뮬레이션은 사용자 화면에 보이는 탭을 바꾼다. 그래서 `newPage()`로 만든 에이전트 Page에서만 하고 끝나면 초기화한다. 사용자 탭(`openedBy: "unknown"`)에는 걸지 않는다.

## 반례 2. "Apple 같은 단순함"이 기존 체크리스트의 고정 규칙과 부딪친다 (영향 중~큼)

**근거**
- 기획서 11행: "Apple에서 참고한 명확한 위계·정렬·절제된 표현을 공통 규칙으로". 19행: "AI 패턴은 맥락을 보는 진단으로 유지".
- 현재 SKILL.md에는 고정값이 들어 있다.
  - `skills/design/SKILL.md:37`: "폰트 하나(Inter, 시스템 고딕)로 전부"를 AI 티로 보고 "본문 세리프 + UI 고딕 + 코드 고정폭"으로 바꾸라고 한다.
  - `:40`: "반투명 블러(glass), … 과한 둥근 모서리" → "불투명 배경, 그림자 없음, 모서리 0~4px".
  - `:69`: "모서리·그림자: 숫자 하나로 통일 (대개 0~4px, 그림자 없음)".
- Apple HIG의 실제 모습은 시스템 글꼴(SF) 한 가족과 굵기·크기 위계, 8~12px 이상의 둥근 모서리, 반투명 재질(vibrancy), 옅은 그림자다. 체크리스트가 "AI 티"라고 하는 것과 상당 부분 겹친다.

**반례 시나리오**
- 사용자가 "Apple처럼 깔끔하게"라고 하면, 스킬이 둥근 모서리 12px + 시스템 고딕 하나로 만든다. 그다음 6단계 2번에서 체크리스트를 다시 돌리면 37·40행에 걸려 "AI 티"로 진단하고 0~4px·세리프로 되돌린다. 아니면 매번 "일부러 남김"으로 넘기게 된다. 어느 쪽이든 "모든 작업에서 같은 결과"가 깨진다.
- 반대로 paper 테마(종이 노트, 0~4px·세리프)와 neutral 테마(Apple풍)를 둘 다 두면, 고정 규칙이 한 테마를 늘 위반으로 만든다.

**확인 방법**
- S2 뒤 S3 검증자가 neutral 테마 시험 화면에 `SKILL.md` 2번 체크리스트를 그대로 돌린다. 테마 토큰이 만든 값(모서리·그림자·글꼴 수)이 "티 나는 것"으로 잡히면 반례가 재현된 것이다.
- `grep -n "0~4px\|그림자 없음\|세리프" skills/design/SKILL.md skills/design/references/*.md`로 고정값이 공통 규칙 쪽에 남았는지 본다.

**수용 가능한 설계 보완**
- `references/system.md`에서 규칙을 두 층으로 나눈다.
  - **공통(불변)**: 위계는 크기·굵기·여백으로, 강조색 하나, 대비 기준(4.5:1 / 3:1), `keep-all`, 기능 보존, 움직임은 상태 변화에만, 가짜 내용 금지.
  - **테마 토큰(변경 가능)**: 모서리 반경, 그림자 유무, 글꼴 짝(세리프 분리 여부), 반투명 재질 허용 여부.
- 체크리스트 37·40·69행은 "**테마가 정하지 않은** 기본값이면 티"로 바꾼다. 판정 기준을 "값이 무엇인가"에서 "프로필·테마가 고른 값인가"로 옮기는 것이다. 19행의 "맥락을 보는 진단"을 이렇게 구체화하면 된다.
- "Apple 참고"의 범위를 기획서에 적는다: 위계·정렬·절제(원칙)는 가져오고, SF 글꼴·glass 재질·Apple 고유 부품 모양은 가져오지 않는다 (아래 미확인 가정 A1 참고).

## 반례 3. "모든 작업에서 일관되게"의 원본과 버전이 없다 (영향 중)

**근거**
- 기획서 20행: "프로젝트 프로필 형식, 테마 마이그레이션". 22행: "기존 테마에 전체 CSS를 무조건 덮지 않고 의미 매핑". 28행: "프로필에 고정한다". 42행: S4에서 TTC·블로그 에이전트에게 위임.
- 플러그인 파일은 설치 위치(`~/.claude/plugins/cache/...` 또는 `--plugin-dir`)에 있다. 그래서 프로젝트 빌드가 kit의 `assets/`를 직접 참조할 수 없고, 각 프로젝트는 **복사**해야 한다.

**반례 시나리오**
- S4에서 TTC 에이전트와 블로그 에이전트가 각자 의미 매핑을 한다. 블로그는 Chirpy 변수에 강조색을 `#2f5d50`으로, TTC는 같은 "paper" 강조를 프로젝트 변수에 `#2e5c4f`로 근사해 넣는다. 한 달 뒤 kit에서 강조색을 바꾸면, 어느 프로젝트가 어떤 버전을 복사했는지 알 길이 없다. 사용자가 원한 "개인 색/폰트 일관성"이 첫 위임부터 갈라진다.
- 글꼴: neutral이 `-apple-system, "Apple SD Gothic Neo"` 계열이면 Mac·iPhone에서만 의도대로 보이고, Windows는 맑은 고딕, Android는 Noto로 바뀐다. "모든 작업에서 같은 글꼴"이 기기마다 달라진다. SF Pro는 Apple 플랫폼 밖에서 웹폰트로 배포할 수 없다.

**확인 방법**
- S4 위임 결과를 받은 뒤, 두 프로젝트에서 강조색·본문 글꼴 값을 grep해 kit `assets/` 원본과 비교한다. 값이 다르거나 출처(어느 kit 버전의 어느 테마)가 적혀 있지 않으면 재현된 것이다.
- `assets/` 테마 파일의 `font-family`에 Apple 전용 이름만 있고 OFL 웹폰트(예: Pretendard)가 없는지 본다.

**수용 가능한 설계 보완 (작은 해법)**
- 원본은 kit `skills/design/assets/themes/<테마>.css` **하나**로 정한다. 파일 첫 줄에 `/* 37writes-theme: paper 0.16.0 */` 같은 이름·버전 표시를 둔다. 프로젝트는 이 파일을 **그대로 복사**하고, 의미 매핑은 별도 파일(`theme-map.css`: 프로젝트 변수 ← `--37w-*`)에서만 한다. 그러면 값이 근사로 바뀌지 않는다.
- 프로젝트 프로필에는 한 줄만 둔다: `- **디자인 테마**: paper 0.16.0`. design 스킬 0단계에서 이 줄과 복사본 첫 줄, kit 원본 버전을 비교해 차이가 있으면 보고한다. 자동으로 덮어쓰지는 않는다.
- 글꼴 토큰은 기기와 상관없이 같은 OFL 웹폰트를 1순위로 두고, 시스템 글꼴은 대체(fallback)로만 쓴다. 한국어 웹폰트는 글자 범위별로 나눠 받는다는 기존 규칙(`SKILL.md:67`)을 유지한다.

---

## 범위 누락: blog 스킬의 `shot.py` (반례 아님, 사실 확인됨)

- 기획서 25행: "`shot.py`는 다른 호출자가 있을 수 있어 보존하되 design 경로에서 사용하지 않는다."
- 실제 다른 호출자: `skills/blog/SKILL.md:282`가 그림 검수 캡처를 `shot.py`(Chrome headless)로 한다. 사용자 전역 지시(`~/.claude/CLAUDE.md`: "브라우저 작업은 ego lite로만 한다. 다른 브라우저 도구는 쓰지 않는다")와 기획서 29행("headless를 대체 경로로 쓰지 않는다")은 design에만 한정된 것이 아니다. design만 바꾸면 블로그 글 워커는 계속 headless Chrome을 띄운다.
- `CLAUDE.md:51`(design 스킬 설명)도 `shot.py` 근거를 그대로 적고 있어서 갱신이 필요하다.
- 보완: 둘 중 하나를 기획서에 명시한다. (a) 범위에 blog 282행의 캡처 단계를 넣어 ego 검증 도우미를 함께 쓰게 하거나, (b) 이번에는 하지 않는다면 `## 남은 일`에 "blog 그림 검수 캡처의 ego 전환"을 적고 그 사이에는 위반 상태라고 밝힌다. 시리즈 글 워커가 **동시에** 캡처하면 ego TaskSpace가 여러 개 생긴다. 안내서는 "Use exactly one TaskSpace for the entire user goal"이라 워커마다 이름이 다른 TaskSpace가 필요하다는 점도 같이 적는다.

## 미확인 가정

- **A1. 사용자가 말한 "Apple 같은"의 뜻.** 원칙(위계·여백·절제)인지, 모습(SF 글꼴·둥근 모서리·반투명)까지인지 확인되지 않았다. 기획서 11행은 원칙으로 해석했다. 반례 2의 보완이 이 해석에 기대므로 S2 전에 사용자에게 한 줄로 확인하는 것이 싸다.
- **A2. 개인 테마 하나인지, 프로젝트별 변형인지.** "개인 폰트/색을 모든 작업에서 일관되게"와 "테마별 CSS 변형"은 함께 성립할 수 있다 (글꼴·위계는 공통, 색 팔레트만 변형). 하지만 TTC와 블로그가 **같은** 테마를 써야 하는지는 정해지지 않았다. 28행이 "브랜드 미확정"이라고 했으니, S4 위임 지시에 "테마 선택은 사용자 확인 후"를 넣어야 위임받은 에이전트가 임의로 고르지 않는다.
- **A3. ego `page.cdp()`가 `Emulation` 도메인을 허용하는지, 덮어쓰기가 실행이 바뀐 뒤에도 남는지** (반례 1의 확인 방법 1·2). 기획의 모바일 검증 전체가 이 가정 위에 있으니 S2 첫 작업으로 확인한다.
- **A4. "실제 CSS 전환점 ±1px"(30행)을 기계적으로 뽑을 수 있는지.** `@media` 규칙은 `document.styleSheets`로 읽을 수 있다. 하지만 교차 출처 스타일시트(Google Fonts, CDN)는 `cssRules` 접근이 막히고, 컨테이너 쿼리나 JS의 `matchMedia` 분기는 빠진다. 도우미 출력에 "읽지 못한 스타일시트 수"를 같이 내면 거짓 완전성을 막을 수 있다.
- **A5. 글꼴 준비.** 측정 전에 `document.fonts.ready`를 기다리는지. 기다리지 않으면 대체 글꼴로 측정해 긴 한글 넘침을 놓친다. 30행은 "글꼴 준비"를 확인 항목으로만 적었으니, 측정 순서에 대기를 넣는다.

## 기획서 반영 제안 (구현자 판단)

| 반례 | 제안 | 수용 시 바뀌는 곳 |
|---|---|---|
| 1 | 에뮬레이션·조작·측정·초기화를 한 실행 안에서, 행마다 실제 viewport 기록, 터치 경로 또는 한계 표기, Emulation 거부 시 멈춤 | 기획서 21·23행, `ego-validation.md`, 도우미 출력 형식 |
| 2 | 공통 규칙과 테마 토큰 두 층, 체크리스트 37·40·69행을 "테마가 정하지 않은 기본값"으로 | 기획서 19·20행, `SKILL.md` 2·4번, `system.md` |
| 3 | kit 원본 하나 + 이름·버전 표시 + 복사본은 그대로, 매핑은 별도 파일, 프로필 한 줄, OFL 웹폰트 1순위 | 기획서 20·22·28행, `assets/`, S4 위임 지시 |
| 누락 | blog 282행 ego 전환을 범위에 넣거나 남은 일로 명시, CLAUDE.md:51 갱신 | 기획서 범위·25행·남은 일 |

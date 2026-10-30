# ego lite UI 검증

설치된 `ego-browser` 스킬을 읽고 `ego-browser skill`의 끝 표식까지 확인한다. API는 그 안내서와 `help()`에서 확인한 것만 쓴다.
브라우저 자동화는 ego lite만 사용한다. 독립 브라우저/Playwright import/headless 실행은 하지 않는다. 도구 실패는 구체적으로 보고하고 가능한 정적 검증을 계속한다.

## 공간과 에뮬레이션

- 한 목표에 TaskSpace 하나. 기존 spaceId를 재사용하고 병렬 워커에게 서로 다른 Page를 할당한다. 페이지 소유자만 조작하고, 모든 워커가 끝난 뒤 소유 지휘자가 finish한다.
- 사용자 소유 탭에 에뮬레이션을 걸지 않는다. 작업 공간의 에이전트 Page를 사용한다. 로그인·권한·사용자 제어는 ego 안내를 따른다.
- **매 실행에서 설정 → 조작 → 실제 설정 확인/측정 → 캡처 → 초기화를 같은 `ego-browser nodejs` 호출 안에서** 수행한다. CDP 설정이 다음 실행에도 남는다고 가정하지 않는다.
- 모바일 viewport meta가 없거나 콘텐츠가 폭을 밀면 `innerWidth`가 요청 폭과 달라진다. 이 경우 좁은 화면 검증 성공으로 세지 말고 설정/레이아웃 실패를 조사한다.
- `page.cdp()`의 `Emulation.setDeviceMetricsOverride`, `Emulation.setTouchEmulationEnabled`, `Emulation.setEmulatedMedia` 사용은 설치된 ego에서 먼저 실측한다. 거부되면 다른 브라우저로 우회하지 않고 해당 행을 미검증 처리한다.

예시(실제 spaceId/Page/URL/절대 경로로 바꾼다; 기존 공간에는 새 공간을 만들지 않는다):

```js
const task = await taskSpace(existingSpaceId);
const page = task.page(assignedPageLabel);
const { configureViewport, measureUI, resetViewport } =
  await import("file:///absolute/kit/skills/design/scripts/ego-audit.mjs");
try {
  await configureViewport(page, { width: 390, height: 844, mobile: true, mode: "dark" });
  await page.goto(localUrl);
  // CDP 뒤의 ref는 새 snapshot으로 얻는다. 여기서 실제 메뉴 조작을 한다.
  const result = await measureUI(page, {
    expectedWidth: 390, expectedMobile: true, expectedMode: "dark",
    controlSelector: "header button, header a, [role=tab]",
    nowrapSelector: "header a, [role=tab]"
  });
  console.log(result);
  console.log(await page.screenshot({ path: absolutePngPath }));
} finally {
  await resetViewport(page);
}
```

도우미는 DOM 측정만 한다. 모드 media와 앱에 저장된 명시적 모드는 다를 수 있으므로 앱의 실제 모드도 확인한다.
`measureUI`는 글꼴 대기 뒤 viewport, touch/pointer, 문서 넘침, 좁은 조작영역·nowrap 위반·잘림 **후보**와 조사 한계를 반환한다. 후보 0개를 “UI 검증 통과”로 출력하지 않는다.

## 매트릭스와 실제 조작

변경되는 대표 route/상태를 정하고 기본 폭 320/360/390/430/768/1280 CSS px, 코드에서 찾은 전환점 ±1px을 확인한다. 같은 구성 중복은 대표 사례로 묶되 생략한 범위를 기록한다.
CSS뿐 아니라 컨테이너 쿼리·JS 분기도 소스에서 찾는다. 브라우저 CSSOM만 보고 전환점을 모두 발견했다고 하지 않는다.
선택 테마의 light/dark/시스템 모드, 긴 한글/영문, 글자 확대, 폰트 실패 시 fallback을 포함한다. 수정하는 모든 테마는 적어도 가장 좁은 폭과 데스크톱에서 재검증한다.

1. **메뉴**: 닫힌 상태 → 터치로 열기 → 모든 항목 읽기/도달 → 항목 선택과 목적 route 확인 → 닫힘. 키보드 Tab/Enter/Escape·초점 복귀도 별도로 확인한다.
2. **탭/도구막대**: 첫/마지막 항목 선택, 가로 스크롤/접기 정책, 선택 표시, 본문 업데이트, 라벨 전체 표시. 스크롤 끝에 있는 항목까지 실제 도달해야 한다.
3. **레이아웃**: 본문 바깥 가로 넘침 없음, 브랜드·계정·긴 제목과 메뉴가 겹치지 않음, 고정 헤더/하단 동작에 가려진 콘텐츠 없음. `overflow:hidden`으로 잘라 숨긴 것도 실패다.
4. **읽기/입력**: 해당하는 코드·표·도표, 빈/로딩/오류 상태, 다이얼로그, 확대된 글자에서 읽기와 조작 가능. 가상 키보드/실제 iOS Safari는 ego Chromium으로 증명할 수 없으므로 실기기 미확인 항목으로 남긴다.
5. **전후**: 같은 조건의 캡처를 열어 눈으로 비교한다. 이미지가 생성된 사실만으로 검증하지 않는다. 새 화면은 기준 fixture/프로필과 비교.

### 터치와 키보드를 혼동하지 않기

`page.click()` 성공은 마우스 조작 증거다. touch 설정과 `(pointer: coarse)`를 확인한 뒤 실제 터치 이벤트로 메뉴를 검사한다.
ego에 터치 래퍼가 없으면 `page.cdp("Input.dispatchTouchEvent", ...)`의 touchStart/touchEnd를 쓴다. snapshot에서 확인한 요소의 현재 rect로 좌표를 계산하고, 가림 여부를 확인한다. `element.click()`을 터치 검증으로 쓰지 않는다.
터치 시퀀스 예시:

```js
// selector는 직전 snapshot에서 확인한 단일 대상. 화면 안 좌표인지 확인한다.
const point = await page.evaluate((selector) => {
  const el = document.querySelector(selector);
  if (!el) throw new Error("touch target missing");
  const r = el.getBoundingClientRect();
  const x = r.left + r.width / 2, y = r.top + r.height / 2;
  if (!r.width || !r.height || x < 0 || y < 0 || x >= innerWidth || y >= innerHeight)
    throw new Error("touch target outside viewport");
  const hit = document.elementFromPoint(x, y);
  if (!hit || !el.contains(hit)) throw new Error("touch target occluded");
  return { x, y };
}, selector);
await page.cdp("Input.dispatchTouchEvent", {
  type: "touchStart", touchPoints: [{ ...point, radiusX: 1, radiusY: 1, force: 1 }]
});
await page.cdp("Input.dispatchTouchEvent", { type: "touchEnd", touchPoints: [] });
// 열린 상태/route/선택 결과를 DOM에서 확인한 뒤 snapshot을 새로 얻는다.
```

터치가 지원되지 않으면 마우스 결과만 보고하고 터치는 미검증으로 남긴다. 숨겨진 메뉴 링크나 화면 밖 요소를 JS로 직접 실행해 도달 가능성을 입증하지 않는다.

## 완료 증거

행마다 route/상태, 테마/모드, 요청 폭과 실제 폭, touch/pointer, 글꼴, 수행 조작/기대 결과/실제 결과, 캡처 경로를 남긴다.
CSS 해시 일치·자동 측정·실조작·눈으로 비교·빌드 결과를 함께 본다. 새 테마는 대비와 레이아웃을 다시 확인한다.
`measureUI`는 iframe/shadow DOM, 가림/겹침 전체, 실제 글꼴 사용 여부, 가상 키보드, 브라우저별 동작, 터치 제스처를 자동 판정하지 않는다. 이 한계를 검증표에 반영한다.

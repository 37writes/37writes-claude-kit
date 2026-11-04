# 레퍼런스 해부

레퍼런스 웹·앱을 원칙·구조·인터랙션·질감·문구·시스템으로 뜯어보고, 근거와 함께 우리 과업에 맞게 옮기는 절차다. 레퍼런스를 복제하지 않고 원칙과 값의 범위를 옮긴다.
간격 단계, 글자 크기, 색 역할, 대비(4.5:1/3:1), 누르는 영역(44px), 움직임 원칙의 원본은 [system.md](system.md)다. 이 문서는 값을 다시 정하지 않는다. 고른 값은 [프로젝트 프로필](system.md#프로젝트-프로필)에 고정한다. ego 사용 규칙은 [ego 검증 절차](ego-validation.md)를 따른다.

## 언제, 얼마나 쓰는가

위에서부터 먼저 맞는 것 하나를 고른다.

| 경우 | 해부 | 예 |
|---|---|---|
| 기존 프로필·토큰·부품으로 풀린다 | 하지 않는다 | 라벨 오타, 상태 색 하나, 메뉴 잘림 하나 |
| 특정 부품·상태만 "레퍼런스처럼", 또는 그 부품이 계속 "AI 티" 평가를 받는다 | **부분 해부**: 그 부품에 관련된 축만, 핵심 출처 1곳부터 | "이 버튼만 참고 화면의 누름 반응처럼" |
| 새 방향·재설계([방향 선택](system.md#방향-선택)) | **전체 해부** | "화면 전체를 다시", 프로필 없는 새 제품 |

- **끼어들지 않는 때**: 프로필이 있고 기존 토큰·부품으로 답이 정해지는 작은 수정에는 해부·시트·비교 분기를 만들지 않는다([정돈 규칙의 기준](layout-discipline.md#언제-읽는가)과 같다). 기존 토큰·부품으로 고치고 SKILL.md 5절 검증만 한다. 명시적인 부품 레퍼런스 요청은 위 표의 부분 해부를 따른다.
- 부분 해부는 해부 시트를 따로 만들지 않고 디자인 문서 안의 표 하나로 충분하다. 전체 해부에서 뺀 축은 "해당 없음 + 이유"를 적는다.

## 1. 레퍼런스 고르기

- [레퍼런스 보드](system.md#방향-선택)(넓게 약 10곳)에서 **핵심 출처 1곳**으로 시작한다. 그 출처로 풀리지 않는 갈림길이 있을 때만 늘린다. 전체 해부의 상한은 5곳이다.
- 기준은 **같은 화면 유형·같은 핵심 과업·같은 기기**다. 유명도가 아니라 사용자의 과업과 닮은 정도로 고르고 고른 이유를 적는다. 예: 조밀한 표를 다루는 작업 화면이면 공개 부품 라이브러리의 표·필터 문서, 읽기 화면이면 공개 문서 사이트.
- 로그인이 필요한 화면은 열지 않는다. 캡처·URL·외부 AI는 [방향 선택의 개인정보 규칙](system.md#방향-선택)을 따른다.

## 2. 여섯 축

여섯 축은 채울 칸이 아니라 **고르는 목록**이다. 부분 해부는 관련 축만 본다(누름 반응이면 인터랙션·질감).
항목마다 근거 종류를 붙인다.

| 근거 | 뜻 | 쓰는 법 |
|---|---|---|
| **실측** | ego로 잰 계산값·실행 중 값·캡처 | 상태·시점·측정 조건과 함께 적는다([3. 실측 절차](#3-실측-절차)) |
| **문서** | 그 제품이 공개한 디자인 가이드·부품 문서 | 출처와 판(버전)을 적는다 |
| **추론** | 관찰에서 미루어 본 것 | 사실처럼 쓰지 않고 "추론"으로 표시한다 |

| 축 | 볼 것 |
|---|---|
| 원칙 | 무엇을 우선하고 무엇을 거절하는가(밀도 대 여백, 장식 대 내용, 일관성 규칙). 공식 원칙 문서가 있으면 문서, 없으면 추론 |
| 구조·흐름 | 정보 구조, 탐색, 첫 과업까지의 경로와 조작 수, 빈·로딩·오류·권한 없음 상태 |
| 인터랙션 | hover·누름·포커스·선택·펼침에서 **무엇이 바뀌는가**, 전환 시간·가속 곡선, 피드백(즉시/낙관적/지연 표시), 키보드·터치 제스처, `prefers-reduced-motion` 대응 |
| 질감 | 면의 층(바탕·면·띄운 면), 그림자 값, 선 굵기·투명도, 모서리, 흐림·재질, 글꼴(종류·굵기·자간·줄 높이·숫자 모양), 아이콘 획·격자 |
| 문구 | 말투, 버튼 동사, 길이, 오류·빈 상태 문장 |
| 시스템 | 간격 집합, 글자 단계 비율, 색 역할 수, 부품 변형 수 |

## 3. 실측 절차

ego Page에서 `page.evaluate`로 역할별 요소의 계산 스타일을 읽는다. 같은 폭·같은 모드·같은 상태에서 잰다(폭·모드 설정은 [ego 검증 절차](ego-validation.md#공간과-에뮬레이션)대로 같은 실행 안에서).

### 상태 관찰 계약

- 기본 → hover → 누름 유지 → 해제 → 키보드 포커스를 **한 실행 안에서** 차례로 만들고, 표본마다 시각과 `matches(":hover")`·`matches(":active")`·`matches(":focus-visible")`를 같이 적는다.
- 상태가 성립하지 않은 표본은 그 상태의 값으로 쓰지 않는다. 예: "누름 유지" 표본의 `active`가 false면 누름 값이 아니다.
- 누름은 키 입력 API(`press`)가 아니라 `mouse.down()`과 `try/finally`의 `mouse.up()`으로 만든다.
- 포인터 포커스(누른 뒤 `focus`만 true)와 키보드 포커스(`focusVisible` true)는 따로 잰다.
- 기본 표본 전에 쉬는 점에서 이전 포커스를 풀고 안정될 때까지 기다린다. 같은 페이지에서 다시 돌리면 지난 실행의 키보드 포커스가 남아 기본 표본에 포커스 링이 섞인다(실측: 공개 부품 문서의 버튼을 연속 두 번 실행). 기본은 hover·active·focus가 모두 false, 포인터 포커스는 `focusVisible`이 false일 때만 그 이름의 값이다. 조건이 다르면 그 표본은 미검증이다. 기본도 안정 대기에 실패하면(예: 처음부터 도는 무한 애니메이션) 안정값으로 쓰지 않고 "애니메이션이 안 끝남(안정값 미검증)"이다.
- 상태의 값은 **안정값**으로 읽는다. 상태를 만든 직후의 표본은 전환 시작값이다(실측: 120ms 전환의 hover 직후 배경은 기본값 그대로였다). 고정 시간 대기 대신 대상의 실행 중 애니메이션이 끝날 때까지 기다리고, 끝나지 않으면 "안정값 미검증"이다.
- 누름 = 클릭이다. 공개 페이지에서는 눌러도 제출·이동·데이터 변경이 없는 부품(데모 버튼 등)만 대상으로 고른다.

### 움직임: 선언과 실행 중 값

- **선언값**(`transition-*`·`animation-*` 계산값)과 **실행 중 값**(`getAnimations()`의 대상 요소·duration·easing·진행률, `transitionrun`/`transitionend` 이벤트)을 나눠 적는다. 선언을 읽은 것을 "움직임 실측"으로 올리지 않는다.
- 표본·프레임·이벤트마다 **대상**(기준 요소 / 자손 / `::before` 같은 가상 요소)을 적는다. 자손까지 모으고 이벤트도 자손에서 올라오므로, 대상이 없으면 자식의 움직임이 기준 요소의 값으로 읽힌다(실측: 자식 span만 도는 140ms 애니메이션). 기준 요소의 값으로 쓰는 것은 대상이 기준 요소인 것뿐이다.
- 실행 중 객체에서 duration·easing을 얻지 못한 움직임(예: 시작·끝 이벤트만 잡힌 아주 짧은 전환)은 **발생만 포착**이고 시간·곡선은 미검증이다. 일부 이벤트를 잡은 것을 그 움직임 전체의 검증으로 읽지 않는다.
- 시간은 벽시계가 아니라 애니메이션 객체의 duration·easing과 `transitionend.elapsedTime`으로 적는다. 에이전트 Page는 프레임이 띄엄띄엄 그려져 표본·이벤트의 시각이 늘어난다(실측: 120ms 전환이 벽시계로 약 2초). 표본 시각은 순서 증거로만 쓴다.
- 기록을 끝내거나 실행이 실패하면 설치한 이벤트 리스너와 예약된 animation frame을 먼저 해제하고, 그 뒤 페이지 도우미를 지운다. 측정이 끝난 뒤의 조작에 리스너나 페이지 오류를 남기지 않는다(실측: 해제하지 않은 리스너가 지운 도우미를 불러 측정 뒤 hover마다 페이지 오류가 났고, 같은 페이지에서 다시 돌릴 때마다 리스너가 쌓였다).
- 이벤트와 애니메이션 목록이 모두 비면 "움직임 없음"이 아니라 **"포착 못 함(미검증)"**이다. 선언도 0s면 "선언: 전환 없음 / 실행 중: 포착 못 함"으로 둘 다 적는다.
- JS(`requestAnimationFrame`으로 스타일을 직접 바꾸는 것)·스크롤 구동 움직임은 이 코드로 잡히지 않는다. 가상 요소의 CSS 움직임은 대상에 가상 요소 이름으로 나오지만 계산값 표본은 기준 요소 것이다. 잡히지 않는 것은 시각 관찰(전/중/후 프레임)이나 추론으로 표시한다.

### 미검사

- 선택자가 1개가 아닌 경우(0개 또는 여러 개), 가려진 대상, 쉴 자리가 없는 대상은 **미검사**다([정돈 점검](layout-discipline.md#1-역할과-선택자를-먼저-정한다)과 같은 규칙).
- canvas 안의 그림, 닫힌 shadow DOM, 교차 출처 스타일시트의 원문(`cssRules` 접근 거부)은 미검사에 적는다. 열린 shadow DOM은 호스트 박스만 잰 것과 내부 요소를 잰 것을 구분한다.
- 핵심 과업 부품이 미검사면 해부 성공으로 보고하지 않는다.

### 실측 예

아래 코드를 그대로 쓰고 맨 앞의 입력만 바꾼다. 앞에 붙이는 입력 예:

```js
const task = await taskSpace(existingSpaceId);   // 기존 공간 재사용
const page = task.page(assignedPageLabel);
await page.goto(referenceUrl);                    // 로그인 없는 공개 페이지
const targets = { "주요 버튼": ".example > button.primary" }; // 역할 → 단일 선택자
const props = ["background-color", "border-color", "box-shadow", "transform",
  "outline-style", "outline-width", "outline-color", "border-radius"];
```

```js
// 입력: page(배정된 Page, 대상 URL로 이동한 뒤), targets(역할 → 단일 선택자), props(읽을 시각 속성).
// 한 실행 안에서 기본 → hover → 누름 유지 → 해제(포인터 포커스) → 키보드 포커스 → 움직임 줄이기를 만든다.
const declaredProps = ["transition-property", "transition-duration", "transition-timing-function",
  "transition-delay", "animation-name", "animation-duration"];
// 페이지 안 도우미: 실행 중 애니메이션·이벤트의 대상(기준 요소/자손/가상 요소)과 시간·easing.
await page.evaluate(() => {
  const who = (base, node, pseudo) => (node === base ? "기준 요소" : base.contains(node)
    ? `자손 ${node.localName}${node.id ? "#" + node.id : ""}` : "밖") + (pseudo || "");
  const run = (base, a) => { const t = a.effect.getTiming();
    return { target: who(base, a.effect.target, a.effect.pseudoElement), kind: a.constructor.name,
      name: a.transitionProperty ?? a.animationName, duration: t.duration, easing: t.easing,
      keyframeEasing: [...new Set(a.effect.getKeyframes().map((k) => k.easing))].join(" "),
      progress: a.effect.getComputedTiming().progress, playState: a.playState }; };
  window.__td = { who, run };
});
const sample = (sel, label) => page.evaluate(({ sel, label, props, declaredProps }) => {
  const el = document.querySelector(sel), cs = getComputedStyle(el);
  const read = (list) => Object.fromEntries(list.map((p) => [p, cs.getPropertyValue(p)]));
  return { label, t: performance.now(),
    hover: el.matches(":hover"), active: el.matches(":active"),
    focus: el.matches(":focus"), focusVisible: el.matches(":focus-visible"),
    values: read(props), declared: read(declaredProps),
    running: el.getAnimations({ subtree: true }).map((a) => window.__td.run(el, a)) };
}, { sel, label, props, declaredProps });
// 상태 조건: 표본이 그 이름의 상태가 아니면 값은 남기되 verdict로 미검증을 붙인다.
const want = (x, cond) => {
  if (x.verdict) return x;
  const off = Object.entries(cond).filter(([k, v]) => x[k] !== v).map(([k, v]) => `${k}≠${v}`);
  if (off.length) x.verdict = `상태 불성립 ${off.join(", ")}(미검증)`;
  return x;
};
// 실행 중 값: 조작 전에 이벤트와 매 프레임의 getAnimations()를 대상과 함께 페이지 안에서 기록한다.
// 리스너는 AbortController로, 프레임은 저장한 ID로 해제한다(측정이 끝난 뒤 페이지에 아무것도 남기지 않게).
const record = (sel) => page.evaluate((sel) => {
  const el = document.querySelector(sel), { who, run } = window.__td;
  const rec = { log: { events: [], frames: [] }, stop: new AbortController(), frame: 0 };
  window.__teardown = rec;
  for (const type of ["transitionrun", "transitionend", "transitioncancel", "animationstart", "animationend"])
    el.addEventListener(type, (e) => rec.log.events.push({ type, target: who(el, e.target, e.pseudoElement),
      name: e.propertyName ?? e.animationName, elapsed: e.elapsedTime, t: performance.now() }),
      { signal: rec.stop.signal });
  const tick = () => {
    if (rec.stop.signal.aborted) return;
    const running = el.getAnimations({ subtree: true });
    if (running.length) rec.log.frames.push({ t: performance.now(), running: running.map((a) => run(el, a)) });
    rec.frame = requestAnimationFrame(tick);
  };
  rec.frame = requestAnimationFrame(tick);
}, sel);
// 기록 끝: 리스너와 예약된 프레임을 먼저 해제하고 기록을 돌려준다. 기록 중이 아니면 null.
const stopRecord = () => page.evaluate(() => {
  const rec = window.__teardown;
  if (!rec) return null;
  rec.stop.abort();
  cancelAnimationFrame(rec.frame);
  delete window.__teardown;
  return rec.log;
});
// 안정값: 고정 대기 대신 대상의 실행 중 애니메이션이 끝날 때까지 기다린다(못 끝나면 미검증).
// 에이전트 Page는 프레임이 띄엄띄엄 그려져 벽시계 시간과 애니메이션 진행이 어긋날 수 있다.
const settle = (sel) => page.waitForFunction((sel) => document.querySelector(sel)
  .getAnimations({ subtree: true }).every((a) => a.playState !== "running"), sel, { timeout: 3000 })
  .then(() => true, () => false);
const settled = async (sel, label) => (await settle(sel)) ? sample(sel, label)
  : { label, verdict: "애니메이션이 안 끝남(안정값 미검증)" };
// 대상 중심(가림 확인)과 쉬는 점(대상 밖, 조작 요소가 아닌 곳)을 고른다.
const locate = (sel) => page.evaluate((sel) => {
  const all = document.querySelectorAll(sel);
  if (all.length !== 1) return { error: `선택자 ${all.length}개 매칭(미검사)` };
  const el = all[0];
  el.scrollIntoView({ block: "center", behavior: "instant" }); // smooth 스크롤 페이지 대비
  const r = el.getBoundingClientRect(), x = r.left + r.width / 2, y = r.top + r.height / 2;
  if (!el.contains(document.elementFromPoint(x, y))) return { error: "가림(미검사)" };
  const calm = (px, py) => { const hit = document.elementFromPoint(px, py);
    return hit && !el.contains(hit) && !hit.closest("a,button,input,select,textarea,summary,label,[tabindex],[role=button]"); };
  const rest = [[r.left - 12, y], [x, r.top - 12], [r.right + 12, y], [x, r.bottom + 12]]
    .find(([px, py]) => px >= 0 && py >= 0 && px < innerWidth && py < innerHeight && calm(px, py));
  return rest ? { x, y, rest: { x: rest[0], y: rest[1] } } : { error: "쉬는 점 없음(미검사)" };
}, sel);

const report = {};
try {
  for (const [role, sel] of Object.entries(targets)) {
    const at = await locate(sel);
    if (at.error) { report[role] = { sel, verdict: at.error }; continue; }
    const s = [];
    // 기본: 쉬는 점에서 이전 포커스(지난 실행의 키보드 포커스 등)를 풀고, 기록을 시작한 뒤 안정값으로 잰다.
    // 기본도 안정 대기에 실패하면 안정값으로 쓰지 않는다. 시각의 기준은 표본과 따로 둔다.
    await page.mouse.move(at.rest.x, at.rest.y);
    await page.evaluate(() => document.activeElement?.blur());
    const t0 = await page.evaluate(() => performance.now());
    await record(sel);
    s.push(want(await settled(sel, "기본"), { hover: false, active: false, focus: false }));
    await page.mouse.move(at.x, at.y, { label: "hover 대상" });
    s.push(await sample(sel, "hover 직후"));
    s.push(want(await settled(sel, "hover 안정"), { hover: true, active: false }));
    await page.mouse.down();
    try {
      s.push(await sample(sel, "누름 직후"));
      s.push(want(await settled(sel, "누름 유지 안정"), { active: true }));
    } finally {
      await page.mouse.up();
    }
    // 포인터 포커스: 누른 뒤의 focus가 focus-visible이 아닐 때만 그 이름의 값이다.
    s.push(want(await settled(sel, "해제(포인터 포커스)"), { active: false, focus: true, focusVisible: false }));
    await page.mouse.move(at.rest.x, at.rest.y);
    await settle(sel);
    const runtime = await stopRecord();
    // 키보드 포커스: 쉬는 점을 눌러 탐색 시작점을 대상 근처로 옮기고 Tab으로 도달한다.
    await page.mouse.click(at.rest.x, at.rest.y, { label: "탐색 시작점" });
    let reached = false;
    for (let i = 0; i < 30 && !reached; i++) {
      await page.keyboard.press("Tab");
      reached = await page.evaluate((sel) => document.activeElement === document.querySelector(sel), sel);
    }
    s.push(reached ? want(await settled(sel, "키보드 포커스"), { hover: false, focusVisible: true })
      : { label: "키보드 포커스", verdict: "Tab 30회 안에 도달 못 함(미검증)" });
    for (const x of [...s, ...runtime.events, ...runtime.frames]) if (x.t !== undefined) x.t = Math.round(x.t - t0);
    // 움직임: 대상·이름별로 묶는다. 실행 중 객체에서 duration·easing을 얻지 못한 묶음(이벤트만)은 미검증이다.
    const groups = {};
    const group = (x) => (groups[`${x.target} ${x.name}`] ??= { target: x.target, name: x.name, events: [], frames: 0 });
    for (const e of runtime.events) group(e).events.push(`${e.type} ${e.elapsed}s`);
    for (const f of runtime.frames) for (const a of f.running) group(a).frames++;
    for (const a of [...runtime.frames.flatMap((f) => f.running), ...s.flatMap((x) => x.running ?? [])])
      Object.assign(group(a), { kind: a.kind, duration: a.duration, easing: a.easing, keyframeEasing: a.keyframeEasing });
    const motion = Object.values(groups).map((g) => ({ ...g,
      verdict: g.easing === undefined ? "발생만 포착: duration·easing 미검증" : "실행 중 값 포착" }));
    report[role] = { sel, samples: s, runtime: { events: runtime.events, frames: runtime.frames.length },
      motion: motion.length ? motion : "포착 못 함(미검증)" };
  }
  // 움직임 줄이기: 같은 실행에서 media를 바꿔 선언값을 다시 읽고, finally에서 되돌린다.
  await page.cdp("Emulation.setEmulatedMedia", { features: [{ name: "prefers-reduced-motion", value: "reduce" }] });
  try {
    for (const [role, sel] of Object.entries(targets)) if (report[role].samples)
      report[role].reducedMotion = (await sample(sel, "움직임 줄이기")).declared;
  } finally {
    await page.cdp("Emulation.setEmulatedMedia", { features: [] });
  }
} finally {
  // 끝나거나 중간에 실패해도: 기록 리스너·예약 프레임을 먼저 해제하고 그 뒤 페이지 도우미를 지운다.
  await stopRecord();
  await page.evaluate(() => { delete window.__td; });
}
console.log(JSON.stringify(report, null, 1));
```

결과 읽기:

| 결과 | 기록 |
|---|---|
| `samples[].label`·`t`·`hover`·`active`·`focus`·`focusVisible` | 표본별 상태 성립과 순서. `t`는 기록 시작 기준(ms)이라 기본 표본이 미검증이어도 이어진다. `verdict: "상태 불성립 …(미검증)"`이 붙은 표본은 그 상태의 값으로 쓰지 않는다 |
| "… 안정" 표본의 `values` | 그 상태의 실측값 |
| `{ verdict: "애니메이션이 안 끝남(안정값 미검증)" }` | 그 상태 값은 미검증 |
| `declared` | 선언값(근거 종류: 실측, 선언) |
| `motion[]` | 대상(`target`)·이름별로 묶은 실행 중 값: duration, `easing`(CSS 전환의 곡선), `keyframeEasing`(CSS 애니메이션의 곡선, 이때 `easing`은 linear), 이벤트, 프레임 수. `verdict: "발생만 포착…"`이면 시간·곡선 미검증 |
| `motion: "포착 못 함(미검증)"` | 이벤트도 실행 중 객체도 없다. 움직임 미검증 |
| `runtime.events`·`frames`, 표본의 `running` | `motion`의 원자료(대상 포함) |
| `reducedMotion` | 움직임 줄이기에서의 선언값. 실행 중 동작은 따로 관찰해야 한다 |
| `verdict: "선택자 N개 매칭(미검사)"` 등 | 미검사 |

키보드 포커스는 대상 옆 조작 요소가 아닌 점을 눌러 탐색 시작점을 옮긴 뒤 Tab으로 간다. 공개 페이지에서는 그 클릭으로 화면 상태가 바뀌지 않았는지 확인하고, 30회 안에 닿지 않으면 미검증이다.

## 4. 해부 시트

프로젝트의 기존 디자인 문서 폴더에 짧은 결정 표로 둔다. 부분 해부는 디자인 문서 안 표 하나로 충분하다.

| 항목 | 레퍼런스 값 | 근거(종류·출처·상태/시점·측정 조건·한계) | 기준 출처와 역할 | 채택/버림과 이유 | 우리 값 |
|---|---|---|---|---|---|
| 예: 주요 버튼 누름 | 배경 한 단계 진하게, 150ms ease-in-out | 실측: 공개 부품 문서, `:active` 성립 안정 표본, 1315px·어두운 모드. 실행 중 duration 150 | 출처 A(같은 작업 화면 유형) | 채택: 색 진하게. 버림: 출처 B의 눌림 그림자(조밀한 표에서 행과 겹쳐 보임) | `--app-motion-fast`, 누름 배경 토큰 |

- 출처끼리 값이 다르면 **기준 출처 하나**를 정하고 버린 대안과 이유를 적는다. 근거 없는 평균(예: 120ms와 200ms의 중간 160ms)은 쓰지 않는다.
- 프로필에는 확정 토큰과 결정만 두고 시트는 링크한다.
- 제3자 캡처는 커밋하지 않는다. 출처 URL은 [개인정보 규칙](system.md#방향-선택)대로 정제한다. 수집한 문구·선택자에 개인 식별 정보가 있으면 기록하지 않는다.

## 5. 옮기기

- **우선순위**: 사용자 과업·기기·밀도·접근성(대비·누르는 영역·움직임 줄이기, 값은 [system.md](system.md#부품별-동작-계약))이 레퍼런스 값보다 앞선다. 바꾼 이유를 시트에 적는다.
- **가져오지 않는 것**: 로고·브랜드 자산·고유 일러스트·유료 글꼴, 특정 제품 화면을 그대로 베낀 배치. 글꼴·아이콘은 라이선스를 확인하고 안 되면 비슷한 공개 대체를 적는다([글꼴 계약](system.md#글꼴-계약)).
- **권리**: 출처 링크는 재사용 허가의 증거가 아니다. 권리 근거가 불명확한 문구·코드·고유한 배치 조합은 관찰·추상화까지만 하고 구현은 독자적으로 쓴다. kit는 법적 적합성을 판정하지 않는다.
- **토큰으로 고정**: **기존 토큰 재사용이 먼저**다(예: 띄운 면 그림자는 테마의 `--kit-shadow-floating`). 새 **움직임** 토큰(짧은·보통 시간, 가속 곡선, 줄이기 대응)과 **질감** 토큰(면 층, 그림자 단계, 선 굵기·투명도)은 이름·소비 위치(어느 부품·상태)·기존 테마/모드와의 우선순위를 같이 적는다.
- **둘 곳**: 원본 자산은 그대로 둔다. 매핑 파일은 변수 연결, hover·누름·전환 같은 상태 선언은 프로젝트의 별도 어댑터 CSS나 기존 컴포넌트에 둔다([원본과 프로젝트 적용](system.md#원본과-프로젝트-적용)).
- **소비하는 선언이 없는 토큰은 만들지 않는다.** [7. 검증](#7-검증)의 토큰 연결 확인에서 미연결은 실패다.

## 6. 시안과 고르기

- [방향 선택](system.md#방향-선택) 2~4(시안 2~4개, 미관과 과업 성공을 나눈 선택표)와 [예시 화면으로 고르기](layout-discipline.md#예시-화면으로-고르기)를 그대로 쓴다.
- 해부에서 갈림길이 나오면(예: 누를 때 "눌림 그림자" 대 "색 진하게") 그 축으로 비교 이미지를 만든다. 나머지 조건은 같게 둔다.
- 움직임은 정지 캡처로 비교가 안 된다. 전/중/후 프레임을 나란히 붙이거나 짧은 녹화를 연다.

## 7. 검증

적용 뒤 `채택 토큰 → 소비하는 선언/컴포넌트 → 계산값`을 추적해 시트의 "우리 값"과 맞는지 본다. 변수만 선언된 경우는 실패다.

1. 토큰 연결: 아래 코드로 토큰마다 선언한 곳, 읽는 선언, 소비 요소마다 그 범위의 토큰 값·해석값을 얻는다. 우리 화면에서만 쓴다(검사용 요소를 잠깐 붙였다 뗀다). 선언 여부와 해석값은 **실제 소비 요소의 계산 스타일과 변수 상속 범위**에서 본다. 부품 범위 토큰(`#card { --card-radius: 13px }`)은 루트에 없어도 정상이다. 인라인 `style`의 소비는 그 요소와 실제 속성명으로 계산한다. 해석값은 토큰 문자열뿐 아니라 소비 요소의 단위·상속 문맥(글꼴·색)을 옮겨 얻는다(실측: 글꼴 32px 버튼의 `1em` 토큰을 독립 요소에서 풀면 16px). 그 문맥을 재현할 수 없는 값(`%`·컨테이너 단위처럼 박스에 기대는 값, 부모에 기대는 글꼴 속성의 상대 단위)은 `resolved: null`, 해석값 미검증으로 남기고 독립 요소의 값을 정답으로 쓰지 않는다. 이때는 소비 요소의 계산값(`now`)과 상태 표본만 대조한다.
2. 계산값: 같은 부품에 [실측 예](#실측-예)를 돌려 안정 표본의 값이 1의 해석값(`uses[].at[].resolved`)과 같은지 본다(예: 누름 그림자 토큰의 해석값 = "누름 유지 안정" 표본의 `box-shadow`). 상태 선택자가 없는 선언은 `at[].now`(지금 계산값)와도 같아야 한다.
3. 상태·모드: 기본/hover/누름/disabled/키보드 포커스, 밝은/어두운/시스템 모드, 움직임 줄이기에서 확인한다. 기존 화면의 같은 역할 부품이 바뀌지 않았는지 대조한다.
4. SKILL.md 5절 검증(터치·키보드·확대)도 통과해야 한다. 독립 검토는 [정돈 점검](layout-discipline.md#정돈-점검)과 같은 입력(원래 요구·화면·시트·프로필)으로 하고 작성자의 합격 결론은 주지 않는다. 선택표의 미관/과업 성공 분리는 그대로다.

앞에 붙이는 입력 예: `const tokens = ["--app-motion-fast", "--app-ease-out", "--app-press-shadow"];`

```js
// 입력: page(우리 화면), tokens(확인할 채택 토큰 이름 목록). 우리 화면에서만 쓴다(검사용 요소를 잠깐 붙인다).
// 토큰 → 선언한 곳 → 그 토큰을 var()로 읽는 선언(규칙의 선택자·속성, 인라인은 그 요소·실제 속성명)
// → 소비 요소마다 그 범위의 토큰 값·해석값·현재 계산값. 루트에 없다는 것만으로 선언 없음이라 하지 않는다.
const trace = await page.evaluate((tokens) => {
  const uses = Object.fromEntries(tokens.map((t) => [t, []]));
  const declared = Object.fromEntries(tokens.map((t) => [t, []])), uninspected = [];
  // 선언을 실제 속성명으로 읽는다(축약형 안의 var()도 보이게 cssText에서). els는 그 선언을 받는 요소.
  const note = (style, where, els) => {
    for (const [, prop, value] of style.cssText.matchAll(/([\w-]+)\s*:\s*([^;]+)/g)) {
      if (declared[prop]) declared[prop].push({ ...where, value: value.trim() });
      for (const name of new Set([...value.matchAll(/var\(\s*(--[\w-]+)/g)].map((m) => m[1])))
        if (uses[name]) uses[name].push({ ...where, prop, els });
    }
  };
  // 규칙을 받을 수 있는 요소: 상태·가상 선택자를 떼고 찾는다. 선택자가 없거나 못 읽으면 null(미검사).
  const consumers = (selector) => {
    if (!selector) return null;
    try { return [...document.querySelectorAll(selector.replace(/::?[\w-]+(\([^)]*\))?/g, "") || "*")]; }
    catch { return null; }
  };
  const walk = (rules, media) => {
    for (const rule of rules) {
      const m = rule.media?.mediaText ?? media;
      if (rule.cssRules) walk(rule.cssRules, m);
      if (rule.style) note(rule.style, { rule: rule.selectorText ?? `@${rule.constructor.name}`, media: m,
        pseudo: rule.selectorText?.match(/::?(before|after|marker|placeholder)\b/)?.[0] ?? null },
        consumers(rule.selectorText));
    }
  };
  for (const sheet of document.styleSheets) {
    try { walk(sheet.cssRules, ""); } catch { uninspected.push(sheet.href ?? "inline"); }
  }
  // 인라인 style: 사람이 읽는 이름은 표시용이고, 계산은 그 요소와 실제 속성명으로 한다.
  for (const el of document.querySelectorAll("[style]"))
    note(el.style, { inline: el.localName + (el.id ? `#${el.id}` : ""), media: "", pseudo: null }, [el]);
  const root = getComputedStyle(document.documentElement);
  // 해석용 요소: 소비 요소에서 em·ex·ch·lh·currentColor가 기대는 글꼴·색 문맥을 복사해 쓴다.
  const probe = document.createElement("div"), context = ["font-family", "font-size", "font-weight",
    "font-style", "font-stretch", "line-height", "color"];
  document.body.append(probe);
  const out = {};
  for (const name of tokens) {
    const list = uses[name].map(({ els, ...u }) => {
      if (!els) return { ...u, matched: null, at: [] };
      const at = new Map();
      for (const el of els) {
        // 소비 요소 범위의 토큰 값(부품 범위 선언·상속 포함)을 그 요소의 글꼴·색 문맥으로 해석한다.
        // 박스·컨테이너에 기대는 값(%·cq*)과 부모에 기대는 글꼴 속성의 상대 단위는 재현하지 않고 미검증으로 둔다.
        const cs = getComputedStyle(el, u.pseudo), value = cs.getPropertyValue(name).trim();
        const unsure = value && (/%|\dcq(w|h|i|b|min|max)\b/i.test(value)
          || (/^(font|line-height)/.test(u.prop) && /\d(em|ex|ch|cap|ic|lh)\b/i.test(value)));
        probe.style.cssText = "";
        if (value && !unsure) {
          for (const p of context) probe.style.setProperty(p, cs.getPropertyValue(p));
          probe.style.setProperty(name, value);
          probe.style.setProperty(u.prop, `var(${name})`);
        }
        const row = { value, resolved: !value ? "" : unsure ? null : getComputedStyle(probe).getPropertyValue(u.prop),
          now: cs.getPropertyValue(u.prop) };
        const key = JSON.stringify(row);
        at.set(key, { ...row, count: (at.get(key)?.count ?? 0) + 1 });
      }
      return { ...u, live: !u.media || matchMedia(u.media).matches, matched: els.length, at: [...at.values()] };
    });
    const consumed = list.filter((u) => u.matched), defined = consumed.filter((u) => u.at.some((a) => a.value));
    const rootValue = root.getPropertyValue(name).trim();
    out[name] = { root: rootValue, declared: declared[name], uses: list,
      verdict: !list.length ? (rootValue || declared[name].length ? "미연결: 읽는 선언 없음(실패)" : "선언 없음(실패)")
        : !consumed.length ? (list.some((u) => u.matched === null) ? "소비 요소 미검사" : "소비 요소 0개(미검증)")
        : !defined.length ? "선언 없음: 소비 요소 범위에 값 없음(실패)"
        : !defined.some((u) => u.live) ? "현재 media에서 안 쓰임(미검증)"
        : defined.some((u) => u.live && u.at.some((a) => a.resolved === null))
          ? "연결됨(일부 해석값 미검증: 계산값만 대조)" : "연결됨(계산값은 상태 표본과 대조)" };
  }
  probe.remove();
  return { tokens: out, uninspected };
}, tokens);
console.log(JSON.stringify(trace, null, 1));
```

| `verdict` | 뜻 |
|---|---|
| 연결됨(계산값은 상태 표본과 대조) | 선언이 읽고 소비 요소 범위에 값이 있다. 2단계 대조가 남았다 |
| 연결됨(일부 해석값 미검증: 계산값만 대조) | 연결은 됐지만 일부 소비 요소의 해석값(`resolved: null`)을 재현하지 못했다. `now`와 상태 표본으로만 대조한다 |
| 미연결: 읽는 선언 없음(실패) | 토큰만 있다. 소비 선언을 넣거나 토큰을 지운다 |
| 소비 요소 0개(미검증) | 선언은 있지만 이 화면에 그 부품이 없다. 그 부품이 있는 화면에서 다시 잰다 |
| 소비 요소 미검사 | 읽는 선언이 선택자 없는 규칙(`@keyframes` 등)이나 해석 못 한 선택자에만 있다 |
| 현재 media에서 안 쓰임(미검증) | 읽는 선언이 지금 맞지 않는 media(예: print) 안에만 있다. 그 조건에서 다시 잰다 |
| 선언 없음: 소비 요소 범위에 값 없음(실패) | 읽는 선언과 요소는 있지만 그 요소 범위에 토큰 값이 없다(대체값이나 초기값이 쓰인다) |
| 선언 없음(실패) | 프로필에 적은 토큰을 어디서도 선언하지도 읽지도 않는다 |

`uninspected`에 나온 스타일시트(교차 출처 등)와 shadow DOM 안 선언은 이 확인에 포함되지 않는다. 소비 요소는 선택자에서 상태·가상 선택자를 떼고 찾으므로 `:not()`·`:has()`가 든 선택자는 실제보다 많이 잡힐 수 있다. 2단계 대조로 확인한다.

## 8. 네이티브 앱 레퍼런스

- ego로 잴 수 없다. 공식 플랫폼 디자인 가이드와 공개 스토어 자료로 **문서/추론**만 쓰고 실측 칸은 "미검사(네이티브)"로 둔다.
- 같은 제품의 웹을 재면 그것은 **웹 실측**이고 네이티브 증거가 아니다. 플랫폼·버전·출처 종류를 나눠 적는다.
- 제스처·햅틱·시스템 전환은 웹으로 검증했다고 쓰지 않는다. 스토어 정지 이미지로 흐름·시간을 단정하지 않는다.

# 최종 집중 재검증: a460e80의 R1·R2·R3

- 검증자: Claude Opus 5.5 (`global.anthropic.claude-opus-5-5`, 워커 자기 보고), Task `task_b733f9e9a876`, Dispatch `ctx_cb4e4257d12f`
- 대상: HEAD `a460e80` (이전 재검증 `revalidation.md`의 R1·R2·R3만). 바뀐 파일: `skills/design/scripts/ego-audit.mjs`·`ego-smoke.mjs`, `skills/blog/SKILL.md`
- 방법: ego는 기존 TaskSpace 10의 p4만 썼다. 새 공간·다른 Page·finish는 쓰지 않았다. 실행마다 설정 → 측정 → `finally resetViewport` 순서였고, 끝날 때마다 p4가 `innerWidth 1716, pointer:coarse false, maxTouchPoints 0`으로 돌아온 것을 확인했다. 서버 `http://127.0.0.1:8769/`의 preview.html·core.css·themes 2개는 `git show HEAD:` 내용과 SHA-256이 같다. Ego Lite 업데이트 알림이 계속 뜨지만 업그레이드하지 않았다
- 범위 밖: F1~F9 전체, guard·deploy·plans 테스트 재실행 (지시대로 확대하지 않음)

## 결론

**R1은 해결됐다.** body·html·패널에 `overflow-x:hidden|clip`이 있어도 정상 화면의 가로 스크롤 탭은 `outside-scroll-window`로만 나온다. 스크롤 viewport 자체가 바깥 패널이나 body에 잘리는 경우는 `clipped-by-ancestor`로 계속 잡힌다. **R2**는 도구 출력(limitation·coverageWarning)에서 해결됐고, **R3**도 해결됐다. 남은 것은 아래 P3 두 건이고, S4 진행을 막지 않는다.

## 1. smoke 재실행 (`runSmoke` 그대로)

`rows 44`, 플래그 9개(`touchMenu`, `keyboardMenuAndLastLink`, `systemMode`, `brokenFixtureDetected`, `enlargedText`, `belowFoldRegression`, `closedDetailsExcluded`, `maskedOverflowDetected`, `nestedScrollClipping`) 모두 true, 7.2초. 44행 모두 실제 폭 = 요청 폭, `<768`에서만 coarse이고, 모든 행에서 `measuredControls 8 / measuredNowrap 4`였다. 작성자 결과(44행/9개 플래그)와 같다.

## 2. R1: 오탐 제거와 잘린 스크롤 viewport 탐지 (390px, 검증자 고른 fixture)

`.kit-scroll` 정상 기하: 33~357, `scrollWidth 468 > clientWidth 324`. `#work` 패널 16~374.

| 경우 | 기대 | 결과 |
|---|---|---|
| 정상 화면 | 오탐 없음 | `outside-scroll-window` 마지막 탭만 |
| `body{overflow-x:hidden}` / `html,body{…hidden}` / `body{overflow-x:clip}` | 오탐 없음 | 같음 (`clipped-by-ancestor` 0개) |
| `#work{overflow-x:hidden}` / `#work{overflow:clip;border-radius:16px}` | 오탐 없음 | 같음 |
| `#work` hidden + 탭 줄을 끝까지 스크롤 (`scrollLeft 144`) | 오탐 없음 | 앞쪽 탭 2개가 `outside-scroll-window`만 |
| html·body·`.preview-grid`·`#work` 모두 hidden | 오탐 없음 | 같음 |
| **스크롤 viewport가 패널에 잘림**: `#work` hidden + `.kit-scroll{min-width:440px}` (여전히 `sw 468 > cw 440`, 오른쪽 끝 473 > 패널 374) | 잡아야 함 | 탭 3개 모두 `clipped-by-ancestor <section#work>` + 마지막 탭 `outside-viewport`. 끝까지 스크롤해도(`scrollLeft 28`) 같다 |
| 같은 viewport가 body에 잘림: `body` hidden + `min-width:440px` | 잡아야 함 | 탭 3개 `clipped-by-ancestor <body>` + `document-horizontal-overflow 83` + 환경 불일치 |
| viewport를 오른쪽으로 밀어 패널 밖으로: `#work{overflow:hidden}` + `.kit-scroll{margin-left:120px;width:300px}` | 잡아야 함 | 탭 3개 `clipped-by-ancestor <section#work>`, 2개 `outside-viewport` |
| 탭과 스크롤러 사이 wrapper가 숨김: `.kit-tabs{overflow-x:hidden;inline-size:200px}` | 잡아야 함 | 탭 2개 `clipped-by-ancestor <nav.kit-tabs>` |
| 숨김 없이 viewport가 화면보다 넓음: `.kit-scroll{min-width:440px}` | 잡아야 함 | `document-horizontal-overflow 83` + `environmentMatches false`로 잡힘. 탭 자체는 `outside-scroll-window` (모바일 에뮬레이션에서 layout viewport가 내용 폭으로 넓어져 `innerWidth` 기준으로는 안에 들어간다) |
| 패널 자체가 가로 스크롤러: `#work{overflow-x:auto}` + `min-width:440px` | 의도한 중첩 스크롤 | `outside-scroll-window`만. 닿는지는 별도 조작으로 확인해야 한다 (도구의 coverageWarning과 같은 한계) |

원시 결과: `/tmp/final-review-20261031/scenarios.json`, `scenarios-clip.json`, 캡처 `scrollerClippedByPanel.png` (검증자 로컬, 임시).

## 3. R2·R3

- **R2 해결 (도구 출력)**: root나 body가 `overflow-x: hidden|clip`이면 `coverageWarnings`에 `root/body hides horizontal overflow; inspect non-control content visually`가 나온다 (body hidden·html+body hidden·body clip 모두 확인, 정상 화면과 패널만 hidden이면 안 나옴). `limitations`에 `clipping inspection covers selected controls only, not arbitrary text or images`가 추가됐다.
- **R3 해결**: `skills/blog/SKILL.md:93` state.md 항목에 `ego spaceId·Page label`이 들어갔다. 7. 정리는 4번 ego 정리(finish) → 5번 브리프 삭제 순서로 바뀌었다. 시리즈 중간 글은 4번 조건(다른 워커 작업 중)으로 finish를 건너뛰고 자기 state.md만 지우므로, 마지막 글의 state.md가 남아 있을 때 finish한다. 본문의 다른 번호 참조("3번으로 넘어가지 않는다", "3번 대신")는 바뀐 번호와 어긋나지 않는다.

## 4. 남은 한계 (P3, 진행을 막지 않음)

1. **smoke의 `nestedScrollClipping` fixture가 스크롤러 경로를 거치지 않는다** — `.kit-scroll{min-width:600px}`이면 `scrollWidth 600 = clientWidth 600`이라 더 이상 스크롤 컨테이너가 아니고, 탭은 "스크롤러 없는 요소가 패널에 잘림" 경로로 잡힌다. 그래서 이 플래그는 "잘린 스크롤 viewport" 분기를 증명하지 않는다. 분기 자체는 위 표의 `min-width:440px` fixture에서 동작을 확인했다. 제안: fixture를 내용보다 좁은 값(예: 440px)으로 바꾸거나 `sw > cw`를 같이 단언한다.
2. **잘린 스크롤 viewport는 보이는 첫 탭까지 탭마다 후보로 나온다** — 문제는 진짜(스크롤 끝이 패널 밖이라 닿을 수 없음)이지만, 후보가 요소 단위라 탭 3개 모두 `clipped-by-ancestor`다. 원인은 `ancestor`로 알 수 있으므로 읽는 쪽이 묶어서 판단하면 된다.
3. **reference 문서의 한계 문장** — `references/ego-validation.md:85`의 자동 판정 한계 목록에는 "조작 요소가 아닌 글·이미지의 잘림"이 아직 없다. 도구 출력에는 있고 38행이 "조사 한계를 반환한다"고 하므로 실사용 영향은 작다.

## 5. 미검증

- 실기기·iOS Safari (ego Chromium 에뮬레이션만), 실제 TTC·블로그 화면 (S4 범위)
- 세로 방향 잘림(`overflow-y`), shadow DOM·iframe 안의 스크롤러

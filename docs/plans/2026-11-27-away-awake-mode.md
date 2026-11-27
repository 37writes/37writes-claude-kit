---
title: 자리 비움 멈춤 수정과 잠자기 방지 전용 모드
date: 2026-11-27
status: draft
tier: T1
---

# 자리 비움 멈춤 수정과 잠자기 방지 전용 모드

## 목표
자리 비움을 켜고 떠났는데 지휘 세션이 7시간 반 멈춘 원인 둘을 고치고, 자리에 있으면서 잠자기만 막고 싶을 때 쓸 모드를 더한다.

## 배경 (2026-11-26 밤 실측)
1. newOpen 지휘 세션(Claude 프로세스, 11-26 12:26 시작)은 자리 비움 훅이 hooks.json에 들어가기 전에 떴다. 훅 등록은 프로세스 시작 때 고정되고 스크립트 내용만 디스크에서 새로 읽힌다. 그래서 예전부터 등록된 guard만 자리 비움을 적용했고(승인받은 `cdk deploy` 거절), 질문 보류·모드 알림·Stop 재개는 없었다.
2. 실제로 멈춘 곳은 Kimi(opencode) 워커의 자체 권한 창(worktree 밖 `mkdir`)이다. kit 훅은 Claude Code에서만 돈다. 지휘 세션은 "허용을 눌러 주세요"라고 쓰고 턴을 끝냈다.
3. 사용자는 자리에 있으면서 잠자기만 막으려고 자리 비움을 켜기도 한다 (2026-11-27 오전, 배터리 상태에서 맥이 잠들어 워커가 멈춤). 이때는 확인 창 거절·질문 보류가 방해다.
4. 사용자는 "자리 비움이면 추천 선택지로 알아서 진행"을 기대했는데, 질문 창 거절 안내에는 추천 선택지 언급이 없다.

## 범위
- **포함**: 모드 구분(`away`·`awake`), 예전 훅 세션 감지와 안내, 질문 창 거절 안내에 추천 선택지, 워커 권한 대기 규칙(harness·모드 알림), AwayBar 앱의 모드 선택·재시작 필요 표시, `test_away.sh`의 Orca 워커 환경 격리, 0.24.0.
- **제외**: guard 완화(push·배포 확인 줄이기, 시크릿 git 훅) → 권한이 넓어지는 결정이라 별도 기획서로 승인받는다. opencode·Codex 자체 권한 설정 변경(사용자 환경). hooks.json에 새 이벤트 추가(예전 세션을 더 만들 뿐이다).

## 동작
### 모드
- `away.py on --for 2h --mode awake`: 잠자기 방지만. caffeinate는 같다. guard·질문 창·Stop·모드 알림·배포 티켓은 **꺼져 있을 때와 같다** (확인 창이 평소대로 뜬다).
- `--mode away`(기본, 생략 가능): 지금 동작 그대로.
- `awake`는 배터리에서도 켠다 (경고만). `away`는 지금처럼 배터리에서 거부한다. 뚜껑 닫힘·전원 미확인은 둘 다 거부.
- `awake`에 `--ticket`을 주면 인자 오류(2).
- 다시 `on`하면 모드가 바뀐다 (기존: 새 caffeinate 시작 뒤 이전 것 종료).
- `status --json`: `active`는 "어느 모드든 켜짐", 새 키 `mode`(`away`|`awake`|null). `tickets`는 away일 때만.

### 예전 훅 세션 감지
- hooks.json의 guard 등록 명령에 표식을 붙인다: `guard.py --schema 1`. away.py 쪽 명령 줄은 바꾸지 않는다 (예전 away.py는 모르는 인자에 끝 코드 2를 내고, 훅의 끝 코드 2는 도구·프롬프트를 막는다. 예전 guard.py는 인자를 읽지 않아 안전하다).
- guard는 Bash 호출마다(위험 이유와 무관, 모드와 무관) 세션 기록 `sessions/<id>.json`에 관측을 남긴다: 본 표식(`schema`), 본 시각(`seen_ts`), Claude 프로세스(`pid` = 환경 변수 `CLAUDE_PID`, 시작 시각). 같은 값이면 5분에 한 번만 쓴다.
- away.py hook은 Stop·AskUserQuestion 이벤트를 받으면(모드와 무관) 그 세션을 `schema 1`로 올린다 (0.23에서 뜬 세션은 표식이 없어도 그 이벤트가 온 것이 등록 증거다).
- **재시작 필요** = guard가 관측했고 `schema < 1`이고 살아 있는 세션. 살아 있음: 기록한 pid가 같은 시작 시각으로 있으면 참, pid가 없으면(환경 변수 없음·윈도우) 마지막 관측이 2시간 안.
- 보이는 곳: `status --json`의 `stale_sessions`(`session`·`repo`·`cwd`·`seen_at`), `status` 글, `on`(away)의 경고, 앱.
- 예전 세션 안에서: 자리 비움(away) 중 guard가 그 세션에서 처음 불릴 때(회차당 1번, 30분 지나면 다시) PreToolUse `additionalContext`로 모드 알림 + "이 세션에는 질문 보류·재개 훅이 없으니 질문 창을 쓰지 말고 글로 묻고 끝내지 말 것"을 넣는다. 위험 명령이면 deny 출력에 같이 싣는다.

### 질문 창 거절 안내
- 선택지 중 `(Recommended)`·`추천` 표시가 있는 것을 질문마다 찾아 거절 이유에 적는다: "추천 선택지: <이름>. 되돌릴 수 있는 결정이면 이것으로 진행. 배포·삭제·권한·push 승인은 추천이 있어도 보류". 보류 목록 글에도 `(추천: <이름>)`을 붙인다.

### 워커 권한 대기
- harness "자리 비움 모드"에 규칙: Claude가 아닌 워커가 권한 창에서 멈췄다는 escalation이 오면 사용자를 기다리지 않는다. `orca orchestration deny --dispatch <id> --prompt <id> --reason "<worktree 안에서 대신할 방법>"`으로 다른 길을 알려 주고, 대신할 길이 없으면 그 작업만 보류하고 나머지를 한다. 사용자가 미리 허락한 범위가 아니면 `approve`는 쓰지 않는다.
- 작업 지시 제약에 "임시 파일은 worktree 안에" 추가. 모드 알림(`note_active`)에 한 문장.

### 앱
- 켜기 전 화면 맨 위에 모드 고르기: `자리 비움`(기본) | `잠자기만 막기`. 마지막 선택을 기억한다.
- `잠자기만 막기`: 배포 티켓 영역 숨김, 배터리는 막지 않고 주의만, 단추 "잠자기 방지 시작".
- 켜진 동안: 제목·아이콘·안내문이 모드에 맞게 ("잠자기 방지 중 · 확인 창과 질문은 평소대로").
- 재시작 필요 탭이 있으면 주의 카드: 레포 이름·마지막 관측 시각 (자리 비움을 고르거나 켠 동안에만).

## 설계
- 변경: `scripts/away.py` — `mode_of`, `running()`(어느 모드든), `active()`(away만), `cmd_on --mode`, `status_obj`(`mode`, `stale_sessions`), `observe()`(guard용 관측), `stale_items()`, `stale_note()`, `hook_question` 추천, `note_active` 문장, `cmd_hook`에서 Stop·질문 이벤트 증거 기록
- 변경: `scripts/guard.py` — `--schema` 읽기, 판정 뒤 `away.observe()` 호출(예외·시간 제한: ps 1회 2초, git 1회 2초, 세션당 한 번), 예전 세션 알림을 출력에 합침
- 변경: `hooks/hooks.json` — guard 명령에 `--schema 1`
- 변경: `skills/harness/SKILL.md` — 자리 비움 절에 모드·워커 권한 대기, 작업 지시 제약 (170줄 이하 유지)
- 변경: `macos/Sources/AwayCore/Models.swift`·`AwayClient.swift`, `macos/Sources/AwayBar/Model.swift`·`PanelView.swift`·`AwayBarApp.swift`, `macos/Tests/AwayCoreTests/`
- 변경: `scripts/test_away.sh`·`scripts/test_guard.sh`, `README.md`, `CLAUDE.md`, `.claude-plugin/plugin.json`·`marketplace.json`(0.24.0)

## 결정 & 이유
- `active()`가 away만 돌려주게 한다 → guard·away_deploy·훅이 모두 이 함수로 판정하므로 awake는 고칠 곳 없이 "꺼짐"과 같아진다.
- 표식은 guard에만 → away.py 명령 줄을 바꾸면 새 hooks.json + 예전 스크립트(되돌린 checkout) 조합에서 모든 프롬프트가 끝 코드 2로 막힌다.
- 살아 있음 판정에 `CLAUDE_PID` → 실측(Claude Code 2.1.332): 훅 환경에 세션 자신의 Claude pid가 들어 있고 py.sh를 거친 훅의 부모 pid와 같다. 시간 창만 쓰면 탭을 재시작한 뒤에도 경고가 남아 고쳤는지 확인할 수 없다. 프로세스 시작 시각으로 "예전 세션"을 추정하지 않는다 (판정은 실제 훅 관측, pid는 살아 있는지만).
- PreToolUse `additionalContext` → 실측(2.1.332, `claude -p` + 시험용 플러그인): 권한 결정 없이 낸 `additionalContext`가 모델에 전달됐다.
- 세션 기록을 모드가 꺼져 있을 때도 쓴다 → 켜는 순간에 이미 떠 있는 예전 세션을 알려면 그 전에 관측이 있어야 한다. `sessions`(탭별 활동) 목록은 지금처럼 자리 비움 중 이벤트가 있던 세션만 보인다 (관측 기록에는 `last_event_ts`를 쓰지 않는다).
- awake는 배터리 허용 → 사용자가 자리에 있고, 오늘 오전 사건이 배터리 상태 잠자기였다. 1단계의 "배터리 시작 금지"(사용자 결정)는 무인 상태 기준이라 away에는 그대로 둔다. **사용자 확인 필요 (기본값으로 진행)**.
- 앱 기본 모드는 `자리 비움` → 앱의 원래 목적이고, 잘못 고른 채 떠나면 확인 창에서 멈춘다 (원래 사건). 마지막 선택을 기억한다.
- hooks.json에 SessionEnd를 더하지 않는다 → 새 이벤트를 넣으면 0.23 세션이 모두 "예전"이 된다.

## 엣지 케이스 & 리스크
- guard는 시간을 넘기면 명령이 실행된다 → 관측은 판정을 계산한 뒤, 전체 try/except, 외부 명령은 세션당 한 번·각 2초.
- 같은 세션의 guard 여러 개가 동시에 기록 → 임시 파일 + replace(원자적), 값이 같아 잃어도 무해. Stop 재개 횟수(`blocks`)는 guard 관측이 덮지 않게 읽은 기록에 필요한 키만 바꾼다.
- kit 없이 뜬 Claude, Codex·Kimi 탭은 보이지 않는다 (훅이 없다) → README·harness에 한계로 적는다.
- 예전 앱(재설치 전)은 awake 상태를 "자리 비움 중"으로 보인다 → `sh macos/install.sh` 다시.
- 0.23에서 뜬 세션은 첫 턴이 끝나기(Stop) 전까지 재시작 필요로 보일 수 있다.

## 기획 반박
- (구현 전에 Codex 워커가 반박, 결과를 여기에 적는다)

## 작업 단계
- [ ] S1. away.py·guard.py·hooks.json: 모드, 관측·재시작 필요, 추천 선택지, 알림 문장 + 테스트 — Coder(지휘 세션) — `sh scripts/test_away.sh`·`test_guard.sh`·`test_away_deploy.sh` 통과, 새 케이스 포함
- [ ] S2. harness·README·CLAUDE.md·버전 0.24.0 — Coder — `claude plugin validate .`, harness 170줄 이하
- [ ] S3. AwayBar 앱: 모드 선택, 재시작 필요 표시 — Coder — `(cd macos && swift test)` 통과, `--snapshot`으로 두 모드 화면 확인
- [ ] S4. 독립 검증 — Validator(Codex gpt-6.2-astra) — 테스트 재실행, 변경 범위, 직접 고른 실패 시나리오 1~3개
- [ ] S5. 병합·push·본체 pull·앱 재설치 — 지휘 세션 — `away.py status --json`에 `mode`·`stale_sessions`, 앱 화면에 모드 선택

## 완료 기준
- 앱에서 `잠자기만 막기`로 켜면 맥은 잠들지 않고, Claude 세션의 확인 창·질문 창은 평소대로 뜬다.
- `자리 비움`으로 켤 때 예전 훅으로 떠 있는 탭이 앱에 "재시작 필요"로 보이고, 재시작하면 사라진다.
- 자리 비움 중 질문 창이 거절될 때 추천 선택지가 안내에 나온다.

## 남은 일
- (작업 중 채운다)

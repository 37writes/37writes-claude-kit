---
title: 자연어 요청부터 완료까지 harness 중심 흐름, devlog·til·weekly 제거, 정책 기반 자동 배포
date: 2026-10-30
status: in-progress
tier: T2
---

# harness 중심 흐름 통합 (0.15.0)

## 목표
사용자는 /kit 명령을 외우지 않고 "이 기능 만들어줘", "이 오류 고쳐줘", "이어서 해줘"라고만 한다. harness가 의도를 읽고 절차를 골라 계획·구현·검증·기록·(정책이 허용하면) 배포까지 잇는다.
따로 쓰는 작업 로그·TIL·주간 정리는 없애고, 기록은 기획서와 커밋에 작업 중 필요한 만큼만 남긴다.

## 배경 (현재 코드에서 확인한 것)
- 규칙이 여러 곳에 복사돼 있다: harness 등급표, plan 등급 줄, init이 만드는 프로필 "작업 규칙" 5줄(이미 만든 프로젝트 CLAUDE.md에 예전 문구로 남음), `orca_context.py` 안내문(T1 기획서·배치·다른 모델 규칙), release "단계마다 확인", commit push 절차, blog 발행 확인.
- kit 프로젝트 판정이 `docs/devlog` 폴더다: `kitlib.kit_repo`·`register`·`registered_repos`, `session_start.py`(훅 설치·이어하기), `stop_reminder.py`, `panel.tsx`(`isKit`), `plan` 마지막 줄. devlog를 없애면 이것들이 조용히 꺼진다.
- 이어하기는 현재 레포의 마지막 devlog "다음 할 일"만 읽는다. 다른 worktree의 진행 중 기획서는 보지 못한다.
- devlog 사용 권유가 commit 마지막 줄, harness 7단계, release 4단계, init 프로필, Stop 알림, 패널에 있다. weekly는 등록부와 `collect_devlog.py`를 쓴다. 이 Mac에 kit가 만든 예약 실행(crontab, LaunchAgents)은 없다.
- 배포: harness T2 = 배포 → 매번 승인, release "단계마다 확인", guard는 `push: 배포 아님`이 아닌 레포의 push를 항상 ask. 자동 배포 정책이나 SHA 기준 완료 증거가 공통 규칙에 없다 (blog 6단계에만 `--commit $SHA` 확인이 있다).
- blog는 TIL 메모를 기본 원료로 보고, 발행 뒤 my-notes에 `docs(til)` 발행 표시 커밋을 하고 /kit:til을 권한다.
- 교차 검토(Claude, Task `task_6d035ab73af8` / Dispatch `ctx_2f093eca560a`, `/tmp/kit-flow-review/claude-review.md`)의 반례 1~5를 근거로 썼다. 같은 모델(Claude)이라 이 기획의 반박으로 치지 않는다. 반박은 S0에서 Codex가 한다.

## 범위
- **포함**: 스킬(harness, plan, init, commit, release, check, design, blog, feedback), devlog·til·weekly 스킬 삭제, `scripts/`(kitlib, session_start, orca_context, install_githook, guard, 새 deploy_gate, 테스트), `collect_devlog.py`·`stop_reminder.py` 삭제, `hooks/hooks.json`, `hooks/panel.tsx`·`panel.test.tsx`, `types/index.d.ts`, README, CLAUDE.md(이 레포 프로필 포함), 두 manifest 0.15.0
- **제외**: 과거 기록 삭제(`docs/devlog/`, 각 레포의 `.git/37writes-kit-reminded`는 그대로 둔다. my-notes와 등록부 파일은 S2 중 사용자 결정으로 삭제, 아래 "결정 & 이유"), 다른 프로젝트 실제 서비스 배포, tech-blog 설정 변경, guard의 기존 ask 규칙 완화(cdk deploy·terraform apply·IAM·amplify publish 등은 그대로 ask)

## 설계

### 1. harness = 의도 분기 + 공통 규칙 (상세 절차는 각 스킬)
- harness 맨 앞에 **의도 표**: 질문 / 기능·수정 / 오류 / 이어서·어디까지 / 프로젝트 구조·개발 순서 / 화면 / 점검 / 배포 / 블로그 / kit 개선. 각 줄에 흐름과 "읽을 파일"(`<base directory>/../plan/SKILL.md` 등). 질문은 파일·기획서를 만들지 않고 답만 한다. 질문과 작업이 애매하면 읽기 전용 확인부터.
- **공통 규칙은 harness 한 곳**: 등급(T0~T2), 불확실성·배치, 승인(계획 승인·미리보기·다시 묻는 경우), push·배포 정책(자동 배포 포함), 검증, 완료 판정(사용자가 보는 결과, 배포는 SHA에 묶인 증거), 기록. 다른 스킬·프로필·훅은 정의를 다시 쓰지 않고 "harness 공통 규칙"을 가리킨다.
- 길이: 의도 표가 늘어나는 만큼 다른 곳을 줄여 **170줄 이하**. 배포 상세 명령은 release, 기획 양식은 plan, 블로그는 blog에 둔다.
- 모델 호출: harness·commit·check·design·blog·feedback은 모델이 부를 수 있게 둔다. plan·init·release는 `disable-model-invocation: true`를 유지하고 harness가 경로로 Read한다 (Skill 목록에 안 나오므로). description은 자연어 진입이 걸리게 짧게 고친다 (harness: 작업 요청을 받으면 먼저 읽는다).
- 경로로 읽을 때의 계약 (반박 작은 지적): 읽은 SKILL.md의 폴더를 그 스킬의 base directory로 쓰고(`<base directory>/../../scripts/...`), harness가 이미 파악한 요청을 그 스킬의 인자로 본다 (plan의 "인자가 없으면 목적 질문"을 다시 하지 않는다). 검증은 새 세션에서 plan·init·release를 실제로 Read하고 스크립트 경로를 따라가는지로 한다.

### 2. 기록: 기획서와 커밋만 (devlog 대체 형식을 만들지 않는다)
- T1 이상: 기획서의 기존 섹션(결정 & 이유, 단계 체크박스 + 결과 한 줄)에 `## 남은 일` 하나만 더한다. 커밋 목록은 적지 않고 `git log --grep "Refs: docs/plans/<파일>"`로 찾는다. 기획서 갱신은 그 작업의 마지막 커밋에 같이 넣는다 (따로 `docs(devlog)` 같은 기록 커밋을 하지 않는다).
- T0 수정: 커밋 메시지가 기록. 질문: 아무 파일도 만들지 않는다.
- 학습("왜 그렇게 했나/무엇이 틀렸었나")은 결정 & 이유와 단계 결과에 적는다. 따로 개념 메모를 만들지 않는다.
- **끝난 기획서는 지운다** (사용자 결정, 2026-10-30: "작업이 완료된 plan md 파일은 자동으로 삭제하게 하자. 나중에 보면 헷갈린다"). 모든 단계가 끝나면 마지막 작업 커밋에 `status: done`(또는 `abandoned` + 이유)·마지막 결과·`## 남은 일`을 넣고, 바로 이어서 삭제 커밋 하나(`docs(plan): <slug> 완료, 기획서 삭제`)로 기획서와 보고서 폴더(`docs/plans/<파일 이름>/`)를 `git rm`한다. 삭제 커밋 본문에 `Refs: docs/plans/<파일>` + 결과 한 줄(+ 사용자만 할 수 있는 남은 확인). 갱신과 삭제를 한 커밋에 넣으면 git에 삭제만 남아 `git show <삭제 커밋>^:`이 미완료 상태를 보인다 (S2 F3). 내용은 git 기록에 남는다: `git log --all --format=%h -- docs/plans/<파일>`로 찾고 `git show <삭제 커밋>^:docs/plans/<파일>`로 읽는다.
- kit가 이어서 할 일이 남았으면 `done`이 아니다 (`in-progress` 그대로, `## 남은 일`에). `project.md`(프로젝트 설계)는 지우지 않고, 끝난 항목은 링크 대신 `완료 <커밋>`으로 바꾼다.
- 이 레포의 이미 끝난 기획서(`status: done` 7개와 보고서 폴더)도 이번 작업에서 지운다. 이 기획서도 S3 마지막 커밋에서 지운다.
- 삭제: devlog·til·weekly 스킬, `collect_devlog.py`, `stop_reminder.py`와 Stop 훅, 등록부 쓰기(`register`, `registered_repos`, init 안내). 등록부는 weekly만 읽었으므로 쓸 곳이 없다. 등록부 파일과 my-notes도 사용자 결정으로 지웠다 (S2 중).

### 3. 프로젝트 인식과 재개
- `kitlib.kit_repo(cwd)`: git 루트의 CLAUDE.md에 프로필 표시(`<!-- 37writes-kit:profile:start -->`)가 있으면 kit 프로젝트. 호환: 표시가 없어도 `docs/devlog/`가 있으면 예전 kit 프로젝트로 본다 (이미 init한 레포의 commit-msg 훅 설치가 꺼지지 않게). `docs/plans/`만 있는 레포는 kit 프로젝트가 아니다.
- 재개 정보: 새 `scripts/plans.py` (`kitlib` 함수 + CLI, `sh scripts/py.sh scripts/plans.py [--cwd DIR] [--json] [--all]`). `git worktree list --porcelain`의 모든 worktree에서 `docs/plans/*.md`(`project.md` 제외)를 읽는다. 상대 경로별로 **모든 복사본을 먼저 모은 뒤** 판정한다 (반박 반례 2):
  - 어느 복사본이든 `done`·`abandoned`이거나, 기본 브랜치(`origin/HEAD` → `main` → `master`)에서 그 경로가 지워진 기록이 있으면(`git log <기본> --diff-filter=D -- <경로>`) **끝난 작업** → 목록에서 빼고, 아직 활성인 복사본이 있으면 `--all`에서 "오래된 복사본(<worktree>)"으로만 보인다.
  - 활성(`draft|approved|in-progress`) 복사본이 여럿이고 상태나 체크박스 수가 다르면 **충돌**로 표시하고 자동 재개 대상에서 뺀다 (사용자가 고른다).
  - 출력 줄: `제목 · 상태 · 브랜치 · worktree · 남은 단계/전체 · 첫 미완료 단계`, 현재 worktree를 먼저, 최대 5개 + "외 N개(`--all`)". 상태가 끝나지 않았는데 그 브랜치가 기본 브랜치에 병합됐으면 "상태 확인 필요".
- SessionStart(`session_start.py`): kit 프로젝트면 commit-msg 훅 설치(기존 동작), 한 줄 "작업 요청은 kit:harness를 먼저 읽는다", `plans.py` 목록, kit 레포 자신이면 feedback 이슈(기존). devlog를 읽지 않는다. kit 프로젝트가 아니면 아무것도 출력하지 않는다 (자동 안내·훅 설치는 kit 프로젝트에서만).
- harness "이어서" 흐름: **kit 판정과 상관없이** 현재 git 루트에서 `plans.py`를 실행해 목록을 얻는다 (프로필 없이 시작한 작업도 이어진다, 반박 반례 3). 하나면 바로, 여럿·충돌이면 고르게 한다. 고른 worktree에서 기획서 체크박스와 `git log --grep Refs`·`git status`·실제 파일을 대조해 첫 미완료 단계부터. 끝난 단계는 다시 하지 않는다.
- 패널: devlog 표시를 빼고 `구분`과 재개 목록(제목·상태·남은 단계)을 보인다. 재개 목록 계산은 한 곳(Python `kitlib`)에 두고 패널은 그 스크립트를 실행해 JSON을 받는 쪽을 우선한다. 엔진 API로 플러그인 경로를 얻을 수 없으면 TS 순수 함수로 같은 규칙을 구현하고 테스트한다. 스킬 순서 목록에서 지운 스킬을 뺀다.
- `orca_context.py`: 역할 판정(워커/지휘) + "첫 요청 전에 kit:harness를 읽는다" + "다른 모델 의견은 Orca 탭(harness 1단계)"만 남기고 규칙 문장(T1 기획서, 배치 기준)은 뺀다. 프로필 없는 레포의 "/kit:init 제안" 줄은 뺀다.
- 로컬 절대 경로는 훅 출력(실행 시 컨텍스트)에만 쓰고, 커밋되는 문서에는 `~/`·`<worktree>`로 쓴다.

### 4. 프로필은 사실만, init은 부족한 것만 보완
- 프로필 블록: 구분, 설명, 스택, 빌드, 테스트, 실행, 배포, push, (있으면) 자동 배포, 원격 + 한 줄 `- **절차**: 커밋 형식 \`type(scope): 한국어 요약\`(commit-msg 훅). 작업 절차·승인·검증·기록은 /kit:harness`. 예전 "작업 규칙" 문장(devlog·T2 정의)은 넣지 않는다.
- init은 harness가 필요할 때 읽는 보완 절차다: CLAUDE.md·AGENTS.md·README·빌드 설정을 먼저 읽고, 작업에 필요한 사실이 없을 때만 프로필 블록을 추가하거나 블록 안의 빠진 줄만 채운다. 기존 내용을 덮거나 다시 쓰지 않는다. CLAUDE.md가 없고 AGENTS.md만 있으면 `@AGENTS.md` 한 줄과 프로필 블록만 담은 CLAUDE.md를 만든다 (내용 중복 없이). `docs/devlog`는 만들지 않는다. 사용자가 원하지 않으면 프로필 없이 진행한다 (자동 배포·push 생략은 없음 = 묻는 쪽).
- 이 레포 CLAUDE.md 프로필도 새 양식으로 바꾼다.

### 5. 자동 배포 = 프로필 정책 + 검증 기록을 guard가 대조
**정책 줄** (없으면 자동 배포 없음 → 배포는 T2 승인):
```
- **자동 배포**: 허용 · 대상 `origin/main` · 검증 `npm ci && npm test` · 제외 `infra/**`, `amplify/backend/**` · 확인 `sh scripts/check_deploy.sh {sha}`
```
- `대상`(원격/브랜치), `검증`(셸 명령), `확인`(`{sha}`를 받아 그 SHA에 묶인 배포 실행 성공 + 핵심 기능 결과를 확인하는 명령, 성공이면 exit 0)은 필수, `제외`(glob 목록)는 선택. 하나라도 없거나 형식이 틀리면 정책 없음으로 본다.

**`scripts/deploy_gate.py`** (표준 라이브러리만):
- `verify [--repo DIR] [--sha REV]`: SHA(기본 HEAD)의 CLAUDE.md에서 정책을 읽고, 항상 그 SHA의 임시 `git worktree add --detach` checkout에서 `검증`을 실행한 뒤 제거한다 (제자리 실행은 S2 D3에서 ignored 파일이 결과를 바꿔 없앴다). 명령 뒤 HEAD가 바뀌었거나 추적 파일이 바뀌었으면 실패로 기록한다 (S2 F1). 결과를 `<git-common-dir>/37writes-kit/deploy/<sha>.json`(sha, tree, 정책 원문, 명령, exit, 시각, 로그 경로)과 로그로 남긴다. exit는 검증 명령의 exit (추적 파일이 바뀌었으면 3).
- `confirm [--repo DIR] [--sha REV] [--timeout 초]`: `확인` 명령에 `{sha}`를 넣어 그 SHA의 임시 checkout에서 실행하고 (현재 폴더의 커밋 안 된 스크립트가 결과를 바꾸지 못하게, S2 F2) 결과를 같은 기록에 더한다. exit 0일 때만 배포 완료다.
- guard가 쓰는 함수 `push_allowed(repo, args)` → (허용 여부, 이유).

**guard 판정** (`push: 배포 아님`이 아닌 레포의 push에 추가. 하나라도 어긋나면 지금처럼 ask):
1. 명령이 정확히 `git push <원격> <40자리 SHA>:refs/heads/<브랜치>` (또는 `:<브랜치>`) 하나이고 옵션·추가 refspec이 없다. `git -c …`·`--git-dir`·`--work-tree` 같은 전역 재정의도 없다 (`-C <dir>`·앞의 `cd`만 허용). 원격·브랜치가 정책 `대상`과 같다. src를 전체 SHA로 고정하므로 검사 뒤 브랜치가 움직여도 보내는 커밋이 바뀌지 않는다 (반박 반례 1). `main`처럼 움직이는 이름의 push는 ask.
2. 실제 보낼 곳: `git remote get-url --push <원격>`과 `git remote get-url <원격>`이 같아야 한다 (다르면 ask). base = `git ls-remote <원격> refs/heads/<브랜치>`의 SHA (시간 제한 5초, 실패·없음이면 ask). base 객체가 로컬에 있고 SHA의 조상이다 (fast-forward). 원격 추적 ref는 쓰지 않는다.
3. 정책은 base의 CLAUDE.md와 SHA의 CLAUDE.md에서 각각 읽어 **둘 다 허용이고 같아야** 한다 (배포 범위 안에서 정책을 스스로 바꾸거나 처음 넣는 push는 사람이 승인).
4. SHA의 기록이 있고 tree가 `SHA^{tree}`와 같고, 기록의 정책·명령이 지금 정책과 같고, exit 0.
5. `git diff --name-only base SHA`가 `제외`에 걸리지 않고, `git diff base SHA`에 시크릿 패턴(`AKIA[0-9A-Z]{16}`, `BEGIN .*PRIVATE KEY`)이 없다.
6. 기록 폴더(`37writes-kit/deploy`)를 건드리는 명령은 `deploy_gate.py`가 아니면 ask (기록 위조 방지, best-effort).
- 병합으로 SHA가 바뀌면 기록이 없으므로 통과하지 못한다 → harness는 최종 SHA에서 `verify`를 다시 돌린다.
- 배포 실패(`confirm` exit ≠ 0, 시간 초과): 멈추고 반영된 SHA·실행 id·롤백 방법(되돌림 커밋도 배포라 사용자 승인)을 보고한다. 자동 롤백은 하지 않는다.
- 블로그는 이 정책에 넣지 않는다 (tech-blog에는 프로필이 없고, 글마다 발행 승인).

**문서 쪽**: harness 공통 규칙의 T2 줄에 "프로필 자동 배포 정책 안이면 계획 승인이 배포 승인을 겸한다(조건: guard와 같은 1~5). IAM·시크릿·인프라·마이그레이션·데이터 삭제는 정책과 상관없이 T2 명시 승인". 이 의미 분류는 guard가 증명하지 못하고 harness 분류가 판단한다 (제외 glob은 보조). 계획을 보일 때 "자동 배포: 정책 안 / 밖(이유)"을 한 줄로 알린다. release는 정책이 있으면 `verify` → `git push <원격> <SHA>:refs/heads/<브랜치>` → `confirm`, 없으면 T2 승인. 완료 판정: push 성공·최근 실행 성공·HTTP 200만으로 완료라고 하지 않는다.
- guard 6(기록 보호)은 권한 경계가 아니다. README·harness에 "위조 불가능"이라고 쓰지 않는다.

### 6. 기획: 프로젝트 설계와 작업 기획 (plan 하나에서)
- 프로젝트 설계: `docs/plans/project.md` 하나 (`type: project`): 목표, 구조(모듈 경계), 기능 목록과 개발 순서(줄마다 작업 기획서 링크·상태, 끝난 항목은 `완료 <커밋>`), 공통 결정. "구조/개발 순서 잡아줘"에서 만들고, 작업 기획은 해당 항목에 링크한다. 새 스킬이나 새 용어를 만들지 않는다.
- plan 1단계 조사: devlog 대신 CLAUDE.md·AGENTS.md·README·project.md·진행 중 기획서·코드. 마지막 줄의 "kit 프로젝트가 아니면 /kit:init 안내"는 "프로필이 없어도 docs/plans만 만들어 진행, 필요한 사실만 harness의 보완 절차로"로.

### 7. 블로그
- description·A단계: 원료는 현재 대화 → 관련 기획서 → `git log --grep Refs`와 diff → 검증 보고서 → 지난 대화(`session_text.py`). TIL은 사용자가 지정할 때만 읽는다. TIL이 없다고 막지 않는다.
- 브리프에 **주장별 근거 표**(주장 → 파일·커밋·대화 줄). 근거 없는 주장은 "근거 부족"으로 표시하고 글 워커가 사실로 쓰지 않는다. 필터링·다른 모델 검수는 그대로.
- 기획서는 끝나면 지워지므로 원료 찾기에 `git log --all -- docs/plans/`와 `git show <삭제 커밋>^:<경로>`를 넣는다.
- 7단계(my-notes 발행 표시 커밋, /kit:til 제안)를 없앤다. "글 써줘"는 작성·검수까지이고 발행(main 병합·push)은 지금처럼 글마다 명시 승인.

## 결정 & 이유
- 규칙은 harness 한 곳, 절차는 각 스킬 → 하나로 합치면 첫 요청마다 무거워지고 design·blog처럼 스스로 불리는 입구가 사라진다 (교차 검토 반례 1).
- devlog 대체 섹션을 만들지 않고 `## 남은 일` 하나만 → 결정·결과는 이미 기획서에 있고, 커밋은 Refs로 찾는다 (교차 검토 반례 2).
- 판정 기준을 먼저 바꾼다(프로필 표시 + 예전 devlog 호환) → devlog를 없애면 훅이 조용히 꺼지는 문제 (반례 3). `docs/plans`만으로는 판정하지 않는다 (무관한 레포에 kit를 적용하지 않게, 사용자 지시).
- 자동 배포는 guard가 정책·SHA·검증 기록·범위를 대조 → 교차 검토의 "대화만 안 묻고 guard 창은 남김"은 사용자가 최종 목표에서 뺐다. 검증 표시 파일 존재만 보지 않고 SHA·tree·정책·diff 범위를 guard가 다시 계산한다 (반례 4·5).
- 정책은 base와 SHA에서 같아야 통과 → 에이전트가 같은 push에서 정책을 넓히는 것을 막는다.
- 등록부는 쓰기를 멈추고 파일은 둔다 → 읽는 곳(weekly)이 없어졌고, 사용자 파일은 지우지 않는다.
- 끝난 기획서는 지운다 (사용자 결정). 갱신 커밋과 삭제 커밋을 나눈다 → 한 커밋이면 git에 미완료 상태만 남는다 (S2 F3, 지휘 세션 결정).
- my-notes(로컬, GitHub 비공개 저장소는 사용자가 직접 삭제)와 등록부 파일 삭제 (사용자 결정, 2026-10-30 S2 중 Validator 탭에서 "아니야 통째로 삭제해", 지휘 세션 질문에 "GitHub 포함") → 인계 문서의 "개인 자료는 삭제하지 않음"보다 최신 직접 지시가 우선. docs/devlog는 대상이 아니어서 그대로.
- verify·confirm은 항상 임시 checkout → 제자리 실행은 빠르지만 ignored 파일·커밋 안 된 스크립트가 결과를 바꿨다 (S2 D2·D3).
- (끝난 기획서 삭제 이유) → 남은 파일이 곧 진행 중인 작업이라 나중에 헷갈리지 않는다. 기록은 git 기록과 커밋 본문에 남는다. 재개 판정에서 "기본 브랜치에서 지워짐 = 끝남"을 쓸 수 있어 오래된 worktree 복사본 문제(반박 반례 2)도 같이 막는다.

## 엣지 케이스 & 리스크
- 기존 kit 프로젝트(프로필 블록 + devlog)는 그대로 kit로 인식, devlog 알림만 사라진다. 프로필 없이 devlog만 있는 레포도 호환으로 인식.
- 프로필의 예전 "작업 규칙" 줄이 남은 다른 프로젝트: 지침과 충돌하지 않게 harness가 "프로필 규칙 문장보다 harness 공통 규칙이 우선, 사실 줄(push·배포·자동 배포)은 프로필"이라고 적는다. 갱신은 그 레포에서 작업할 때 init 보완 절차로.
- 검증 명령이 의존성 설치를 요구하면 임시 worktree에서 오래 걸린다 → 정책의 `검증`에 설치까지 쓰게 한다. 느려도 매번 임시 checkout이다 (ignored 파일·로컬 캐시에 기대지 않게).
- guard는 샌드박스가 아니다 (best-effort). 기록 위조를 완전히 막지 못한다는 점을 README에 적는다.
- 원격 추적 ref가 오래됐으면 범위 계산이 넓어진다(더 엄격). 원격이 앞서 있으면 push 자체가 거부된다.
- harness가 길어진다 → 170줄 상한.

## 실행 배치 (이번 작업 자체)
- Run 하나, 이 worktree(`kit-planning-multi-agent`, 0.14.0 위)가 작업 worktree.
- S0 Codex 반박(탭) → S1a·S1b **병렬 Claude Coder**, 담당 파일이 겹치지 않아 각자 하위 worktree(`new-child`) → 지휘 세션이 작업 브랜치로 병합 → S2 Codex Validator(탭, 작업 worktree) → 재작업은 같은 Coder 탭 → 재검증 → main 통합·push·본체 반영.
- 보고서: `docs/plans/2026-10-30-harness-flow/`의 `plan-review.md`, `coder-a.md`, `coder-b.md`, `validation.md`.

## 기획 반박
- 검토자: Codex 워커 (Orca 탭 `term_c17a7a77-…`), 실제 모델 `global.openai.gpt-6-astra` (지휘 세션이 실행 중 `worker-show`의 `projection.provider.model`로 확인), Task `task_be43c2502629` / Dispatch `ctx_8c149f4df4bb`, 22:44~22:46 KST, 보고서 [plan-review.md](2026-10-30-harness-flow/plan-review.md)
- 반례 1 검증한 SHA·원격과 실제 push가 어긋남 → **수용**. guard 1·2를 "전체 SHA src 고정 + push URL = fetch URL + `ls-remote`로 실제 원격 base"로 바꿨다. 이유: 검사 뒤 브랜치 이동·push URL 분리로 검증 안 된 커밋이 나갈 수 있다.
- 반례 2 오래된 worktree 복사본이 끝난 작업을 다시 재개 → **수용**. 같은 경로의 모든 복사본을 먼저 비교, 하나라도 끝났거나 기본 브랜치에서 지워졌으면 끝남, 활성 복사본끼리 다르면 충돌(자동 재개 안 함).
- 반례 3 프로필 없이 시작한 작업이 재개에서 빠짐 → **수용**. 자동 안내는 kit 프로젝트만, harness의 "이어서"는 kit 판정과 상관없이 `plans.py`를 실행.
- 작은 지적: 경로로 읽을 때 base directory·인자 계약 → 수용(설계 1). 자동 배포의 의미 분류는 harness 판단 → 수용(설계 5 문서 쪽). 최대 5개 정렬·"외 N개" → 수용. 더 작은 출시 단위(자동 배포·project.md·패널 분리) → **기각**: 사용자가 이번 작업 범위로 확정했다. 자동 배포는 반례 1 조건을 갖춘 좁은 경로로만 연다.
- 반박 뒤 사용자 결정 추가: 끝난 기획서 자동 삭제 (설계 2). 반박 범위 밖의 새 결정이라 S2 검증 시나리오에 넣는다.

## 작업 단계
- [x] S0. 기획 반박 — Codex 워커(탭) — `plan-review.md`에 반례 ≤3 + 확인 방법, 이 기획서 "기획 반박"에 수용/기각
  - 결과: 반례 3개 수용, 출시 단위 축소 제안 1개 기각, 설계 2·3·5 갱신
- [x] S1a. 코드 — Claude Coder A(하위 worktree) — 담당: `scripts/`(kitlib, session_start, orca_context, install_githook, guard, deploy_gate·plans 신규, test_guard.sh, test_deploy_gate.sh·test_plans.sh 신규, collect_devlog·stop_reminder 삭제), `hooks/`, `types/`. 완료: `sh scripts/test_guard.sh`, `sh scripts/test_deploy_gate.sh`(로컬 bare 원격 fixture로 허용/정책 없음/범위 밖/검증 실패/잘못된 SHA/움직이는 브랜치 이름/push URL 다름/병합 후 새 SHA/배포 실패/정책 변경/기록 위조), `sh scripts/test_plans.sh`(다른 worktree 재개, done·abandoned·기본 브랜치에서 지워짐 제외, 오래된 복사본, 충돌, 프로필 없는 레포), `claude plugin test .`, 훅 직접 실행(새·옛 kit, 무관 레포) 통과
  - 결과: `20badd5` (Task `task_477f2386913f` / Dispatch `ctx_82193551f4ef`, [coder-a.md](2026-10-30-harness-flow/coder-a.md)). guard 58·deploy_gate 40·plans 32 ok, plugin test 6 pass
- [x] S1b. 문서 — Claude Coder B(하위 worktree) — 담당: `skills/`(devlog·til·weekly 삭제 포함), README.md, CLAUDE.md, `.claude-plugin/` 두 manifest(0.15.0), `docs/plans/`의 끝난 기획서 7개와 보고서 폴더 삭제(이 기획서·`2026-10-30-harness-flow/`는 제외). 완료: `claude plugin validate .`, `grep -rn "kit:devlog\|kit:til\|kit:weekly" skills README.md CLAUDE.md` 0건(과거 기록 설명 제외), harness 170줄 이하, T2·push·배포 정의가 harness 밖에 정의 형태로 없음
  - 결과: `ef3b58e` (Task `task_5087e3593fb0` / Dispatch `ctx_d657713ebda9`, [coder-b.md](2026-10-30-harness-flow/coder-b.md)). 스킬 9개, harness 144줄, 끝난 기획서 7개 삭제
- [x] S1c. 병합 — 지휘 세션 — 두 하위 브랜치를 작업 브랜치로 병합, 통합 검사 재실행
  - 결과: `20badd5`(A, fast-forward) + `ef3b58e`(B) → 병합 `ea26107`. validate 통과, guard 58·deploy_gate 40·plans 32 ok, plugin test 6 pass
- [ ] S2. 독립 검증 — Codex Validator(탭) — 재실행 + 이 worktree를 `--plugin-dir`로 로드한 새 Claude 세션에서 시나리오 a~f를 실제 도구 호출·산출물로 확인 (아래 완료 기준), 스스로 고른 실패 시나리오, `validation.md`
- [ ] S3. 반영과 통합 — 지휘 세션 — 지적 수정·재검증, 기획서 결과·남은 일, main fast-forward 병합, `git push origin main`, 본체가 그 SHA인지 확인

## 완료 기준
- a) 질문("Python GIL이 뭐야?")에 파일·기획서·커밋이 생기지 않는다.
- b) 구현 요청에서 harness가 의도를 분류하고 기획서·검증·기록(기획서 결과)까지 잇는다. init·check·devlog 사용 권유 문장이 없다.
- c) 프로필 없는 레포(README·AGENTS.md 있음)에서 기존 파일이 바뀌거나 덮이지 않고, 프로필은 필요한 사실만 제안·보완한다. 프로필 표시가 있는 레포·devlog만 있는 옛 레포는 kit로 인식, `docs/plans`만 있는 레포는 아니다. 본체 세션 시작 시 다른 worktree의 in-progress 기획서가 재개 목록에 나오고, done·abandoned는 안 나온다.
- d) 작업 완료 뒤 `docs/devlog`·my-notes·주간 파일이나 예약 실행이 생기지 않는다. Stop 알림이 없다. 끝난 작업의 기획서와 보고서 폴더는 마지막 커밋에서 지워지고, 커밋 본문에 Refs와 결과가 있다.
- e) TIL 없이 기획서·커밋으로 블로그 브리프(주장별 근거 포함)가 만들어지고, "작성만" 요청이면 tech-blog main에 병합·push하지 않는다 (실제 tech-blog는 건드리지 않고 브리프 단계까지 또는 fixture로 확인).
- f) 로컬 fixture에서 guard: 정책 허용 + 검증된 SHA + 범위 안 → 통과 / 정책 없음·범위 밖·검증 실패·잘못된 SHA·병합 후 새 SHA(재검증 전)·정책 변경·기록 위조 → ask / 배포 실패 → `confirm` 실패. 기존 guard 테스트 결과는 유지.
- `claude plugin validate .`, `claude plugin test .` 통과, 두 manifest 0.15.0, README가 자연어 사용법 기준.

## 남은 일
- (작업 중 채움)

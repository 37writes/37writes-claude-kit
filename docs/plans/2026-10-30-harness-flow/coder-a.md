실행 모델: Claude Opus 5.5 (`global.anthropic.claude-opus-5-5`, 세션 시스템 정보 기준)

# S1a 코드 — Coder A 보고

- Task `task_477f2386913f` / Dispatch `ctx_82193551f4ef`, 브랜치 `37writes/harness-flow-a` (하위 worktree), 기준 커밋 `f0eef97`
- 담당: `scripts/`, `hooks/`, `types/`. `skills/`·README·CLAUDE.md·`.claude-plugin/`은 건드리지 않았다.

## 파일별 변경

| 파일 | 변경 |
|---|---|
| `scripts/kitlib.py` | `kit_repo`: git 루트 CLAUDE.md에 `<!-- 37writes-kit:profile:start -->`가 있거나 (호환) `docs/devlog/`가 있으면 루트. `docs/plans`만으로는 아님. `devlog_files`·`DEVLOG_*`·`REGISTRY`·`register`·`registered_repos`·`_registry_lines` 제거. 새 `CONFIG_DIR`(`~/.config/37writes-kit`), `PROFILE_START/END`, `profile_block(text)`(프로필 블록 안쪽). `git()`에 선택 `timeout`(예외 시 None) |
| `scripts/plans.py` (신규) | 진행 중 기획서 목록. 아래 "CLI" |
| `scripts/session_start.py` | kit 프로젝트면: 안내 한 줄 + commit-msg 훅 설치 결과(ok가 아닐 때) + `plans.text(plans.resolve(repo))` + (kit 레포 자신이면) feedback 이슈·대기 목록. devlog 읽기·등록 제거. kit 아니면 출력 없음 |
| `scripts/orca_context.py` | 역할 판정(워커/지휘) + 첫 요청 전 Skill 도구로 kit:harness + 다른 모델은 Orca 워커 탭(harness 1단계)만. T1·배치 규칙 문장, `NO_PROFILE`(/kit:init 제안), 프로필 검사 제거 |
| `scripts/install_githook.py` | `register` 호출과 출력 제거 |
| `scripts/deploy_gate.py` (신규) | 자동 배포 정책 파싱, `verify`/`confirm` CLI, guard용 `push_allowed(repo, args, global_opts)` |
| `scripts/guard.py` | `push: 배포 아님`이 아닌 레포의 일반 push(강제·삭제 아님)에 `deploy_gate.push_allowed` 대조 → 통과면 묻지 않음, 아니면 기존 문구 + ` — 자동 배포 조건 불충족: <항목>`. git 전역 옵션(`-C` 외)을 모아 넘긴다. 새 `record_reasons`: `37writes-kit/deploy`를 건드리는 명령은 `deploy_gate.py`가 아니고 리다이렉트 없는 읽기(cat·ls·grep·rg·head·tail·wc·jq·less)가 아니면 ask. 기존 RULES·강제·삭제 push·push 배포 아님 처리는 그대로 |
| `scripts/collect_devlog.py`, `scripts/stop_reminder.py` | 삭제 |
| `hooks/hooks.json` | Stop 훅 제거, description `37writes kit: 진행 중 기획서 이어하기, Orca 작업 절차 안내, 위험 명령·배포 push 확인`, guard timeout 5 → 15초 (ls-remote 5초 제한 + 로컬 git 호출 여유. 훅이 시간 초과로 죽으면 확인 없이 지나갈 수 있어서) |
| `hooks/panel.tsx` | devlog 상태(`devlogSummary`, todos, unlogged) 제거. `구분`(프로필 없으면 "kit 프로필 없음") + 진행 중 기획서(제목·상태·남은 단계, 충돌·상태 확인 필요는 노란색, 5개 + 외 N개). 목록은 `$.plugin.root`로 `sh <root>/scripts/py.sh <root>/scripts/plans.py --cwd <git 루트> --json`을 실행해 받는다 (TS로 규칙을 다시 구현하지 않음). 새 순수 함수 `parsePlans`, `planLine`, `isKitProject`. 스킬 순서 `harness plan commit check design release blog feedback init` (devlog·til·weekly 제거), /kit:init·/kit:devlog 권유 문구 제거, 명령 설명 `kit 패널 열기/닫기: 스킬 목록과 진행 중 기획서`. status atom에 `shape: 'plans-1'` (핫 리로드 때 예전 모양의 값은 null로 읽음) |
| `hooks/panel.test.tsx` | devlog 테스트 → `parsePlans`(오래된 복사본 제외, 깨진 출력), `planLine`(충돌·상태 확인 필요), `isKitProject` |
| `types/index.d.ts` | `KitPlan` 추가, `KitStatus` = `{ repo?, isKit, category?, plans }`, `status: Shaped<KitStatus \| null>` |
| `scripts/test_guard.sh` | 기존 49건 그대로 + 9건 (기록 폴더 쓰기 ask·읽기 통과·deploy_gate 통과, 정책 없는 배포 레포의 SHA push ask) |
| `scripts/test_deploy_gate.sh` (신규) | 40건, 아래 |
| `scripts/test_plans.sh` (신규) | 32건, 아래 |

## CLI (문서용)

### plans.py
```sh
sh scripts/py.sh scripts/plans.py [--cwd DIR] [--json] [--all]
```
- kit 판정과 상관없이 git 레포면 동작. git 레포가 아니거나 기획서가 없으면 exit 0 + 빈 출력 (`--json`이면 `[]`)
- `git worktree list --porcelain`의 모든 worktree에서 `docs/plans/*.md`(`project.md` 제외)를 읽고, 상대 경로별로 복사본을 모은 뒤 판정
  - 어느 복사본이든 `done`·`abandoned`, 또는 기본 브랜치(`origin/HEAD` → `main` → `master`)에서 지워진 기록이 있고 지금 없음 → 끝난 작업, 목록에서 뺌. `--all`이면 남은 활성 복사본을 "오래된 복사본(<worktree>)"으로 표시
  - 활성(`draft|approved|in-progress`) 복사본끼리 (상태, 남은 수, 전체 수)가 다르면 충돌
  - 체크박스는 `## 작업 단계` 섹션의 `- [ ]`/`- [x]` 줄만 센다 (없으면 파일 전체). "첫 미완료 단계"는 ` — ` 앞부분 60자
  - "상태 확인 필요": 기본 브랜치가 아닌 브랜치가 만든 뒤 커밋이 있고(reflog 첫 줄 ≠ 지금) 그 끝이 기본 브랜치의 조상이며 기본 브랜치 끝과 다를 때
- 정렬: 현재 worktree의 기획서 먼저, 그다음 파일 이름 역순(최근 날짜 먼저). 텍스트는 최대 5개 + `- 외 N개 (\`plans.py --all\`)`. `--json`은 제한 없이 전체
- 텍스트 출력 예:
  ```
  진행 중 기획서:
  - 로그인 작업 · in-progress · feat/login · <worktree> · 남은 2/5 · S3. API 연결
  - 결제 작업 · 충돌: in-progress(main, 남은 2/3) / in-progress(feat, 남은 1/3) · 자동 재개하지 않음, 사용자가 고른다
  - 정리 작업 · approved · fix/x · <worktree> · 남은 1/2 · S2. 검증 · 상태 확인 필요(브랜치가 기본 브랜치에 병합됨)
  - 외 2개 (`plans.py --all`)
  ```
- `--json` 항목: `title, status, branch, worktree, remaining, total, next, current, path, stale, conflict, needsCheck, copies[{worktree, branch, status, remaining, total}]`

### deploy_gate.py
정책 줄 (CLAUDE.md **프로필 블록 안**에 정확히 하나. 블록 밖 줄은 읽지 않음):
```
- **자동 배포**: 허용 · 대상 `origin/main` · 검증 `npm ci && npm test` · 제외 `infra/**`, `amplify/backend/**` · 확인 `sh scripts/check_deploy.sh {sha}`
```
- 첫 값 `허용` + `대상`(`<원격>/<브랜치>`, 원격 이름에 `/` 없음)·`검증`·`확인`(`{sha}` 포함) 필수, `제외` 선택. 값은 모두 백틱. 키 중복·모르는 키·형식 오류 → 정책 없음
- 제외 glob: `**`는 폴더 경계를 넘고 `*`·`?`는 넘지 않는다 (`infra/**` = `infra/` 아래 전부)

```sh
sh scripts/py.sh scripts/deploy_gate.py verify  [--repo DIR] [--sha REV]          # 기본 HEAD
git push <원격> <40자리 SHA>:refs/heads/<브랜치>                                   # guard가 대조 (dst는 <브랜치>도 됨)
sh scripts/py.sh scripts/deploy_gate.py confirm [--repo DIR] [--sha REV] [--timeout 600]
```
- verify: SHA의 CLAUDE.md에서 정책을 읽고, HEAD == SHA이고 `git status --porcelain`이 비었으면 제자리, 아니면 임시 `git worktree add --detach` → 실행 → 제거. exit = 검증 명령의 exit (정책 없음·레포 없음은 2)
- 기록: `<git-common-dir>/37writes-kit/deploy/<sha>.json` = `{sha, tree, policy(원문 줄), command, exit, time, log, inPlace, confirm?{command, exit, time, log}}`, 로그 `<sha>.verify.log`·`<sha>.confirm.log`. 공통 git 폴더라 다른 worktree에서 검증해도 보인다
- confirm: 확인 명령의 `{sha}`를 전체 SHA로 바꿔 레포 루트에서 실행, 시간 초과는 exit 124. 실패하면 "멈추고 반영된 SHA·실행 id·롤백 방법을 보고한다 (자동 롤백하지 않음)" 출력
- 출력 예: `검증 통과: <sha>\n기록: <경로>` / `검증 실패 (exit 1): <sha>\n기록: <경로>\n--- 로그 끝부분 ---\n…` / `배포 확인 완료: <sha>`

guard 판정 (어긋나면 ask, 이유 문자열 = `git push: … — 자동 배포 조건 불충족: <항목>`):
1. `-C`·앞의 `cd` 외의 git 전역 옵션(`-c`, `--git-dir`, `--work-tree` 등) 없음, 인자가 정확히 `<원격> <40자리 SHA>:<refs/heads/브랜치|브랜치>`, SHA가 로컬 커밋, SHA의 정책 있음, 원격·브랜치 = 정책 대상
2. `remote get-url --all` == `remote get-url --push --all` (하나), base = `ls-remote <원격> refs/heads/<브랜치>` (5초 제한, 터미널 프롬프트 끔), base가 로컬에 있고 SHA의 조상
3. base와 SHA의 정책이 같음 (정책 추가·변경 push는 ask)
4. 기록: sha·tree(`SHA^{tree}`) 일치, 기록 정책 원문·명령 == 지금 정책, exit 0
5. `git diff --no-renames --name-only base SHA`가 제외 glob에 안 걸림, `git diff base SHA`에 `AKIA[0-9A-Z]{16}`·`BEGIN .*PRIVATE KEY` 없음 (내용은 출력하지 않음)
6. 기록 폴더 보호 (위 guard.py 행). best-effort이며 권한 경계가 아니다

## 실행한 명령과 결과

| 명령 | 결과 |
|---|---|
| `sh scripts/test_guard.sh` | exit 0, ok 58 / FAIL 0 (기존 49 + 신규 9) |
| `sh scripts/test_deploy_gate.sh` | exit 0, ok 40 / FAIL 0 (약 10초). 허용 통과(+실제 push 후 가짜 배포 SHA == 검증 SHA, confirm exit 0, 기록에 verify·confirm), confirm 실패(배포 안 된 SHA → exit 1), 기록 없는 SHA, `main`·`HEAD`·짧은 SHA src, 옵션·refspec 둘·다른 브랜치·태그, `git -c`·`--git-dir`·`--work-tree`, push URL 다름(되돌리면 통과), 제외 glob, 시크릿, 검증 실패, 범위 안 정책 변경, 기록 위조(tree·다른 SHA 기록 복사·명령), 원격이 앞섬(fast-forward 아님), 병합 후 새 SHA(재검증 전 ask → 재검증 후 통과 + 실제 push SHA 일치), 임시 worktree 검증·정리·inPlace=false, 다른 worktree에서 검증한 기록, 정책 없음(verify exit 2·guard ask), 정책 처음 넣기, 블록 밖 정책 무시. 각 ask는 이유 문자열로 의도한 검사에서 걸렸는지 확인 |
| `sh scripts/test_plans.sh` | exit 0, ok 32 / FAIL 0. 다른 worktree의 in-progress, done·abandoned 제외, 기본 브랜치에서 지운/done인 기획서의 오래된 복사본 제외(`--all`에서만 "오래된 복사본"), 활성 복사본 충돌(`--json` 포함), 현재 worktree 먼저, 커밋 없는 새 브랜치는 병합으로 안 봄, 병합 후 미완료 = 상태 확인 필요, 최대 5 + 외 2개, 프로필 없는 레포, 빈 출력·`[]`, kit_repo(프로필 ○, 옛 devlog ○, docs/plans만 ×, 무관 ×), SessionStart 출력(안내·기획서·devlog 언급 없음·훅 설치·출력 없음 2종), 등록부 미생성 |
| `claude plugin test .` | 6 pass / 0 fail (터미널·데스크톱 마운트 포함) |
| `claude plugin validate .` | `✔ Validation passed with warnings` (CLAUDE.md 경고는 정상. 디렉터리 검사의 LICENSE 없음은 이전부터, 결과에 영향 없음). 처음엔 contract에 `import type { Shaped }`를 넣어 실패 → `declare module` 안에서는 import 없이 쓰므로 제거 |
| `npx -p typescript tsc -p <레포 밖 tsconfig>` (엔진 타입 + hooks + types) | 오류 0 |
| `claude -p --plugin-dir . "/kit"` | 스킬 목록 + `이 프로젝트: harness-flow-a (개인)` + `· 자연어 요청부터 … · in-progress · 남은 5/6` → `$.plugin.root`로 plans.py 실행 확인. (devlog·til·weekly 스킬은 아직 skills/에 있어 목록 뒤에 붙는다. S1b가 지우면 사라진다) |
| `echo '{"cwd":…}' \| sh scripts/py.sh scripts/session_start.py` (임시 HOME) | 새 kit(이 worktree): 안내 + 진행 중 기획서 1개 / 옛 devlog 레포: 안내 + `commit-msg 훅 설치: …` / 무관 레포: 출력 없음 exit 0 / docs/plans만: 출력 없음 exit 0 (같은 레포에 `plans.py --cwd`는 목록을 낸다). 실제 HOME으로 이 worktree: feedback 이슈 #1도 나옴 |
| `TERM_PROGRAM=Orca … orca_context.py` / Orca 밖 | 새 안내 4줄 / 출력 없음 |

## 다른 Coder(S1b)·지휘 세션에 넘기는 사실
- 아직 남은 참조 (S1b 담당): `skills/init/SKILL.md:94` 등록부 설명, `skills/weekly/SKILL.md`(collect_devlog.py·등록부, 스킬 삭제 예정), CLAUDE.md "등록부"·Stop 훅·구조 표(`stop_reminder` 언급 시)·`orca_context` 설명(NO_PROFILE 제거됨)·hooks.json 설명
- CLAUDE.md 구조 표에 추가할 것: `scripts/plans.py`(진행 중 기획서 목록), `scripts/deploy_gate.py`(자동 배포 verify/confirm, guard 대조), `scripts/test_deploy_gate.sh`, `scripts/test_plans.sh`. 검증 방법에 두 테스트 추가
- hooks.json 이벤트: SessionStart(session_start: 훅 설치·안내·기획서 목록, orca_context) / PreToolUse Bash(guard, 15초). Stop 없음
- harness "이어서" 흐름에서 부를 명령: `sh "<base directory>/../../scripts/py.sh" "<base directory>/../../scripts/plans.py" --cwd <git 루트>` (필요하면 `--json`·`--all`)
- release·harness 배포 절차: `deploy_gate.py verify` → `git push <원격> <전체 SHA>:refs/heads/<브랜치>` → `deploy_gate.py confirm`. 병합으로 SHA가 바뀌면 verify 다시

## 남은 위험
- guard는 샌드박스가 아니다. 기록 폴더 보호는 명령 문자열 검사라 `deploy_gate.py`가 들어간 세그먼트의 리다이렉트, 변수로 만든 경로, Write 도구 직접 쓰기는 막지 못한다. 위조 기록도 tree·정책·명령을 맞추면 통과한다 (검증 실행 자체를 증명하지는 않음)
- PreToolUse 검사와 실제 실행 사이에 원격이 움직여도 src가 고정 SHA라 보내는 커밋은 같고, 원격이 앞서면 git이 non-fast-forward로 거부한다. 원격이 되감긴 경우(base가 더 과거)는 ls-remote가 실제 base를 읽으므로 범위가 그만큼 넓게 계산된다
- `ls-remote`가 5초를 넘거나 인증 프롬프트가 필요하면 ask (자동 배포 안 됨). guard timeout 15초 안에서 끝나는지는 로컬 bare로만 확인했다. 느린 실제 원격에서 diff가 매우 크면 시간이 늘 수 있다
- 시크릿 패턴은 diff 전체(삭제 줄 포함)를 본다 → 유출 키를 지우는 push도 ask (더 엄격한 쪽)
- plans.py "상태 확인 필요"는 reflog로 브랜치 생성 시점을 본다. reflog가 없거나 만료되면 표시하지 않는다 (보조 정보)
- 기본 브랜치가 `origin/HEAD`면 원격 추적 ref 기준이라 fetch 전에는 "기본 브랜치에서 지워짐"을 늦게 안다 (그동안은 복사본이 활성으로 보일 수 있음. 같은 경로의 done 복사본이 있으면 그걸로 빠진다)
- 패널은 `sh`로 plans.py를 실행한다. 윈도우에서 `sh`가 없으면 기획서 목록이 비어 보인다 (훅과 같은 전제, 윈도우 실기 테스트는 남은 일)
- 패널 렌더링 테스트는 `$.state`가 없는 테스트 환경이라 기획서가 있는 상태의 그림은 `claude -p "/kit"` 텍스트 출력으로만 확인했다

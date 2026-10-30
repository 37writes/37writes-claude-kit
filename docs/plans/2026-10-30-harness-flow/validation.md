검증자 agent: Codex (독립 검증자 S2)
실제 실행 모델: `global.openai.gpt-6-astra` — 실행 중 `orca orchestration worker-show --dispatch ctx_88c5c0e9b288 --json`의 `projection.provider.model`로 확인 (`launch.effective.model`은 null)
검증 시각: 2026-10-30 23:10 KST 시작, 2026-10-30 23:19:16 KST 보고서 정리
Task ID: `task_c103c122d2c6` / Dispatch ID: `ctx_88c5c0e9b288`

# 0.15.0 독립 검증 — FAIL

대상은 이 worktree의 `f0eef97..ea261072363670ed4523acdfa84f9c1ed5f0bcc7`이다. Coder 보고는 자동 검사·독립 경계 사례를 먼저 실행한 뒤 읽었다. 본체의 이전 구현은 검증 근거로 사용하지 않았다. 아래 `<worktree>`는 현재 작업 worktree, `<tmp>`는 `/tmp/kit-s2-validation`이다. 원시 로그·fixture·Claude stream-json은 `<tmp>`에 보관했다. 이 레포에서는 이 보고서만 작성했고 커밋하지 않았다.

**판정: 기존 자동 검사 모두 통과, 필수 수정 5건(F1~F5).** 특히 검증 도중 수정된 코드와 배포 확인 스크립트의 출처가 SHA에 묶이지 않는 문제가 재현됐다. 실제 외부 push·배포·병합은 하지 않았다. 요청된 기존 테스트 내부에서 실행되는 로컬 bare fixture 작업만 예외이며, 별도 수동 fixture는 bare clone으로 준비하여 push도 하지 않았다.

## 사용자 직접 지시 변경 (검증 도중)

- 원래 S2 지시는 my-notes·등록부를 보존하고 변경 여부를 확인하는 것이었다. 그 조건의 전후 동일성 검증을 먼저 완료했다.
- 이후 사용자가 “my-notes, 등록부는 뭐야? 삭제하라고 했던건데”, 이어서 **“아니야 통째로 삭제해”**라고 직접 지시했다.
- 최신 직접 지시에 따라 `~/Documents/dev/my-notes` 전체와 `~/.config/37writes-kit/repos.txt` 파일을 삭제했다. 대상의 실경로 일치·비심볼릭 링크를 먼저 확인하고 Python `shutil.rmtree(notes)` / `registry.unlink()`를 실행했으며, 두 경로의 `exists()`가 모두 false임을 확인했다. 다른 저장소는 삭제하지 않았다.
- 코디네이터에 두 차례 escalation으로 정정·완료를 전달했다. 아래 C의 “전후 동일”은 **사용자 삭제 실행 전까지의 플러그인 런타임 검사**를 뜻한다. 현재 두 경로는 없다.
- 기획서의 제외 범위와 README·CLAUDE.md·blog SKILL의 “기존 파일은 그대로 둔다” 설명은 **사용자 결정 변경으로 수정 예정**이다. 코디네이터가 보고서를 받은 뒤 직접 반영한다고 확인했다. 이는 검사한 HEAD 이후 새 사용자 결정이며, 기존 HEAD 결함 5건과 별도로 전달한다. 코디네이터는 GitHub my-notes 저장소 삭제도 사용자가 직접 실행한다고 전달했으며, S2는 원격 삭제를 실행·검증하지 않았다.

## A. 자동 검사와 변경 범위

실행: `claude plugin validate .`, `command claude plugin test .`, `sh scripts/test_guard.sh`, `sh scripts/test_deploy_gate.sh`, `sh scripts/test_plans.sh`. 테스트 스크립트는 `HOME=<tmp>/test-home`, `PYTHONDONTWRITEBYTECODE=1`로 격리했다. alias 영향을 피하도록 명령은 비대화 `/bin/sh`에서 실행했다.

| 검사 | 실제 결과 | 증거 |
|---|---|---|
| plugin validate | exit 0, Validation passed with warnings | `<tmp>/validate.log` |
| plugin test | exit 0, **6 pass / 0 fail** | `<tmp>/plugin-test.log` |
| test_guard | exit 0, **58 ok / 0 FAIL** | `<tmp>/guard.log` |
| test_deploy_gate | exit 0, **40 ok / 0 FAIL** | `<tmp>/deploy.log` |
| test_plans | exit 0, **32 ok / 0 FAIL** | `<tmp>/plans.log` |
| 기존 guard 49건만 재실행 | exit 0, **49 ok / 0 FAIL** | `<tmp>/baseline-guard.log` |

기존 49건은 `git show f0eef97:scripts/test_guard.sh`를 `<tmp>/baseline-guard.sh`로 추출하고 첫 `cd`만 현재 `<worktree>/scripts`로 바꿔 새 guard에 실행했다. 테스트 입력·기대값은 바꾸지 않았다. 현재 test_guard diff는 기존 건을 삭제·수정하지 않고 9건을 추가한다.

validate 경고를 생략하지 않았다: 루트 CLAUDE.md가 플러그인 사용자 컨텍스트로 로드되지 않는다는 경고, ICON_MISSING, 별도 plugin directory 제출 기준의 LICENSE_MISSING이 나온다. 일반 validate는 exit 0이지만 디렉터리 제출 적격을 뜻하지 않는다.

- `git diff --stat f0eef97..HEAD`: **44 files, 1483 insertions, 1580 deletions**. scripts·hooks·types·스킬·README·CLAUDE·manifest·허용된 완료 기획서 삭제 및 Coder 보고서로, 기획 범위 안이다 (`<tmp>/stat.log`). 삭제한 단일 기획서 7개는 각각 `git show f0eef97:<path>`로 **status: done**을 다시 확인했다. 과거 docs/devlog 삭제는 없다.
- `git diff f0eef97..HEAD | grep -nE 'AKIA|secret|api[_-]?key|BEGIN .*PRIVATE'`: **7줄**. 패턴 설명·검사 명령·삭제된 이전 보고서의 검사 명령과 `test_deploy_gate.sh`의 합성 fixture다. 실제 자격 증명은 발견하지 않았다 (`<tmp>/secret-grep.log`).
- 추가 줄의 `/Users/` 검사: **실제 로컬 절대 경로 0건**. 문자열 자체는 coder-b.md의 검색 명령 `grep "/Users/"` 1건이다. 경로가 추가된 것으로 세지 않았다.
- 두 manifest를 JSON으로 다시 읽어 **0.15.0 / 0.15.0** 확인. `skills/*/SKILL.md` **9개**. harness **144줄**, 170줄 제한 통과.
- `hooks/hooks.json`의 실제 이벤트는 SessionStart·PreToolUse이고 **Stop 없음**.

## B. 문서와 코드의 계약

`sh scripts/py.sh scripts/plans.py --help`, `python3 scripts/deploy_gate.py --help`를 실행하고 구현을 직접 읽었다.

| 계약 | 문서 근거 | 코드 근거와 판정 |
|---|---|---|
| 재개 CLI | harness:140~143, CLAUDE.md:31 | plans.py:154~169: `--cwd`, `--json`, `--all` 일치. 다만 harness의 “전부는 --all”은 오래된 복사본도 포함한다는 설명이 빠져 런타임 F5 발생 |
| verify / confirm | release:14~22, README:77 | deploy_gate.py:286~298: action, `--repo`, `--sha`(HEAD), `--timeout`(600) 일치. `--timeout`은 confirm에만 적용 |
| push 형식 | harness:64, release:17, README:77 | deploy_gate.py:138~156: 전체 소문자 40자리 SHA·원격·단일 refspec. 짧은 dst 브랜치도 허용(설계와 일치), 움직이는 src는 ask |
| 대상·원격·정책·기록·제외 | harness:64~69, README:78 | deploy_gate.py:164~211: 단일 push/fetch URL, ls-remote, FF, base 정책, SHA/tree/명령/exit, 제외·시크릿 검사. 기본 성공·실패 fixture 통과 |
| 정책 줄 | init:59~77, README:74~76 | deploy_gate.py:40~85: 프로필 블록 안 정확히 한 줄, 허용·대상·검증·확인 필수, 제외 선택, 값은 백틱, 확인 `{sha}` 필수 |
| 검증된 SHA | release:16, harness:67 | **FAIL F1**: verify 실행 뒤 실제 파일이 달라져도 원래 SHA/tree로 성공 기록 |
| 배포 확인 | harness:73, release:18 | **FAIL F2**: target SHA 정책 문자열은 읽지만 실행 스크립트는 현재 작업 폴더에서 읽음 |
| 정의를 harness에만 둠 | harness:9, 기획 설계 1·S1b 완료 조건 | **FAIL F4**: README:72·79·82, CLAUDE.md:50·54, release:11에 승인 조건·일반 push 정의가 다시 있음 |

정책 줄이 필수·선택 항목을 설명하거나 release가 구체 명령을 나열하는 것은 중복 정의로 세지 않았다. 그러나 “줄이 없으면 배포는 매번 승인”, “커밋 승인이 push 승인을 겸한다”, “늘 직접 확인”처럼 승인 여부를 독립적으로 결정하는 문장은 참조가 아니라 정의다. 특히 release:11의 태그 push·릴리즈 생성·파일 전달 승인 규칙은 harness의 일반 push 정의와 함께 읽어야만 구별된다. 현 시점 명백한 실행 모순과, 규칙 소유 위치 위반은 구분했다.

`git diff f0eef97..HEAD -- scripts/guard.py scripts/test_guard.sh`도 확인했다. RULES·위험 rm·기존 deploy 판정은 그대로다. 일반 push의 기존 `push_free_repo` 경로는 유지하고, 배포 push에 정책 통과 분기만 추가했다. 강제·삭제 push는 그 앞에서 ask다. **기존 ask 규칙 완화 없음**(허용된 자동 배포 경로 추가 제외); 49건 재실행도 이를 뒷받침한다.

## C. 새 Claude 런타임 시나리오 (완료 기준 a~f)

### 공통 실행 조건

총 **6회** 새 세션. 모두 `/tmp` 아래 새 git 레포에서, 설치된 kit 대신 `--plugin-dir <worktree>`를 명시했다. stream-json init의 실제 모델은 모두 `global.anthropic.claude-opus-5-5`였다.

실행 드라이버: `python3 <tmp>/session.py <fixture-name> '<요청>'`. 이 드라이버는 `subprocess.Popen`으로 `claude` argv를 직접 실행하여 셸 alias를 적용하지 않으며, `TERM_PROGRAM`과 모든 `ORCA_*` 환경 변수를 제거한다. 요청된 `env -u TERM_PROGRAM -u ORCA_WORKTREE_ID ... command claude`의 환경·alias 제거 효과를 이렇게 구현했다 (`command`는 외부 프로그램이 아닌 셸 내장이다).

```sh
claude --plugin-dir <worktree> -p --output-format stream-json --verbose \
  --allowedTools Skill Read Write Edit Glob Grep \
    'Bash(git *)' 'Bash(python3 *)' 'Bash(sh *)' 'Bash(ls *)' \
    'Bash(mkdir *)' 'Bash(cat *)' 'Bash(pwd)' 'Bash(find *)' \
  --disallowedTools 'Bash(orca *)' 'Bash(git push *)' 'Bash(git merge *)' \
  -- '<자연어 요청 + 추천값으로 진행, push·배포 금지 + /tmp·단일 세션 제약>'
```

각 `<tmp>/<name>-command.json`에 전체 argv, `<name>.jsonl`에 원시 도구 호출·응답, `<name>-tools.json`에 추출한 호출이 있다. 최종 문장만 믿지 않고 실제 Write·Read·Bash 결과와 별도 git/file 검사를 대조했다. init 1건, resume 2건, blog 1건, release 3건의 복합 Bash 호출은 allowedTools 때문에 거절됐으며 모델이 개별 허용 명령으로 다시 실행했다. 이를 성공 호출로 세지 않았다. 모든 세션 최종 exit 0, result.is_error=false. Orca 실행·다른 탭 생성·push·merge 도구 호출은 없었다.

### a) 질문 — PASS

- fixture `a-question`, 요청 `Python GIL이 뭐야?`.
- 첫 도구는 `Skill kit:harness`; 그 뒤 Read·Write·Bash 호출 없이 답변했다.
- 전후 작업 파일 목록 및 SHA-256 동일: README.md·CLAUDE.md 2개. `git status --porcelain` 빈 출력, HEAD `96d2247` 그대로, 커밋 1개 그대로. 기획서 없음.

### b+d) 기능·기획·검증·커밋·기록 — 부분 FAIL (F3)

- fixture `bd-feature`, 프로필은 현재 레포와 같은 marker 형식, `push: 배포 아님`, 원격 없음.
- 요청: 정수 리스트 median 함수 + unittest, 빈 입력 ValueError·입력 불변·홀짝 지원, 구현하고 커밋까지, push 금지.
- 호출 순서: `Skill kit:harness` → **Read `<worktree>/skills/plan/SKILL.md`** → README·commit 스킬 Read → **Write 기획서** → 기획 커밋 → **Write median.py·test_median.py** → **Bash unittest 및 별도 경계 검사** → **Bash git rm 기획서 + 기능 커밋**.
- 실제 최종 커밋 `57b7ce6`의 name-status: 기획서 D, median.py A, test_median.py A. 본문에 `Refs: docs/plans/2026-10-30-median.md`와 테스트 결과 있음. 별도 재실행 `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s <tmp>/bd-feature -v`도 **7/7 통과**.
- **실패**: 생성된 기획서는 한 번도 갱신되지 않았다. `git show HEAD^:docs/plans/2026-10-30-median.md`는 `status: approved`, S1·S2 모두 `[ ]`, 단계 결과 없음. stream-json에도 기획서 Edit/재Write가 없다. 기획 커밋 `e2f1ba7`에는 Refs도 없다. 커밋에 결과는 남지만 “기획서 결과까지 잇는다”는 b는 충족하지 못했다.
- 삭제 동작 자체(d)는 통과. 보고서 폴더는 이 작은 작업에서 생성되지 않았으므로 **실제 존재하는 보고서 폴더 삭제는 미검증**이다.
- assistant text 전체에서 init·check·devlog·til·weekly 사용 권유 **0건**. docs/devlog·주간 파일·별도 메모 생성 없음. 작업 트리 깨끗함.
- 사용자 추가 삭제 **전** HOME 전후 snapshot을 JSON 정규화 후 대조: my-notes 파일 목록·mtime·크기 동일, 등록부 mtime·SHA-256 동일, LaunchAgents 목록·mtime·크기 동일, crontab 동일. 등록부 mtime_ns `1793368245540596558`, SHA-256 `9945abc6701cc833d66f3ac2180717c2a61b842f8b3725360ffa3a4d3026e2bc`.
- `crontab -l`: exit 1(등록 없음), kit 항목 0. LaunchAgents 파일명·읽을 수 있는 plist 내용의 kit 항목 0. 기존 multipass 자동 시작 symlink 하나는 대상이 없어 내용 검사를 못 했으며 kit 항목은 아니다. hooks.json Stop 없음.

### c-1) 프로필 없는 레포 init — PASS

- fixture `c-init`, README·AGENTS.md만 있고 CLAUDE 없음. 자연어 `이 레포에 kit 설정해줘` + 이미 알려진 사실·기존 문서 보존.
- `Skill kit:harness` → **Read init/SKILL.md** → 기존 README·AGENTS·git 확인 → Write CLAUDE → `sh <worktree>/scripts/py.sh <worktree>/scripts/install_githook.py <fixture>` → 커밋 `c315dc8`.
- 기존 README·AGENTS는 전후 SHA-256 동일. 새 CLAUDE에서 profile marker 블록을 제거한 나머지는 정확히 `@AGENTS.md` 하나. 내용 복제 없음. 커밋 변경 파일은 CLAUDE.md 하나.

### c-2) SessionStart 직접 실행 — PASS

실제 재현: `PYTHONDONTWRITEBYTECODE=1 python3 <tmp>/fixtures.py`. 내부에서 각 fixture에 아래 명령을 `HOME=<tmp>/test-home`으로 실행했다.

```sh
echo '{"cwd":"<fixture>"}' | sh <worktree>/scripts/py.sh <worktree>/scripts/session_start.py
```

프로필 marker 레포·docs/devlog만 있는 옛 레포: exit 0, harness 안내 및 commit-msg 훅 설치 출력. docs/plans만 있는 레포·무관 레포: exit 0, **stdout 빈 문자열**. `<tmp>/fixtures.json`에 원문 있음.

### c-3) 다른 worktree 재개 — CLI PASS / 자연어 출력 FAIL (F5)

- fixture `c-resume`: main에서 old.md를 커밋한 뒤 stale worktree를 만들고 main에서 old.md를 git rm·커밋. 별도 active worktree에는 active.md(in-progress)와 done.md(done)를 둠.
- `python3 <worktree>/scripts/plans.py --cwd <tmp>/c-resume --json`는 **Active only 하나만** 반환. done·삭제된 old는 없음.
- 새 Claude에 `어디까지 했지? 파일은 바꾸지 말고 진행 상황만 알려줘.` 요청. harness Skill 다음 **plans.py --all 실행이 성공**했고, active.md와 done.md를 모두 Read했다.
- 최종 답변은 진행 중 작업 1개를 정확히 골랐지만 **별도 “목록에서 빠진 것”에 Deleted old·Completed done을 다시 출력**했다. 잘못된 작업을 재개한 것은 아니나, 지시한 “in-progress만 나오고 done·지워진 것은 안 나옴”에는 실패한다. 원인은 기본 재개와 `--all`의 오래된 복사본 진단이 구분되지 않은 안내다.
- 파일 Write·Edit 없음. 본체 fixture의 status·HEAD 그대로.

### e) TIL 없는 블로그 브리프 — PASS

- fixture `e-blog`: 기획서·median 구현·Refs 커밋만, TIL 없음. 요청은 브리프까지만·전송/탭 금지. 성능 10배 주장도 근거를 구별하도록 요청했다.
- 도구: `Skill kit:harness` → `Skill kit:blog` → 현재 레포 git log·기획서·코드 조회·간단한 Python 동작 검사 → **Write 브리프**.
- 생성: `~/.config/37writes-kit/blog/s2-validation-20261030-ctx88c5/brief.md`, **92줄**, `| 주장 | 근거 |` 표 존재, **근거 부족 4건**. 10배 성능·설계 의도·테스트 등 검증되지 않은 주장을 사실로 채우지 않았다. 직접 읽어 확인했다.
- my-notes/til Read·Bash 접근 없음. tech-blog HEAD 전후 `05771e8880f8394bcfaf4d792da5691a336ebcec`, status 전후 빈 문자열. 병합·push·코디네이터 전송·탭 호출 없음.
- 브리프 사본을 `<tmp>/blog-brief.md`에 보관한 후 **이 테스트 slug 폴더만 삭제**, 부재 확인. 다른 slug는 건드리지 않았다.
- 임시 e-blog 안에는 실행한 `python3 -I` 때문에 `__pycache__/median...pyc` 1개가 생겼다(격리 플래그가 PYTHONDONTWRITEBYTECODE 환경도 무시). 실제 프로젝트나 외부 저장소 변경은 아니다.

### 보충: release 경로 Read — PASS (6번째 세션)

fixture `release-read`, 릴리즈 사전 점검만·파일/버전/커밋/배포 금지 요청. `Skill kit:harness` → **Read release/SKILL.md** → git·README·프로필 테스트 실행. 원격·배포 방식 없음, 테스트 0개(exit 5)를 확인하고 중단. 파일·태그·커밋 변경 없음. 배포 명령을 실행하는 세션은 의도적으로 만들지 않았다.

### f) 수동 bare fixture — PASS

`PYTHONDONTWRITEBYTECODE=1 python3 <tmp>/edges.py`의 f-manual 부분. `git clone --bare <fixture> <tmp>/f-origin.git`로 원격을 준비하고 remote origin을 연결했다. 정책은 `검증 python3 -m unittest discover -v`, `제외 infra/**`, `확인 sh check_deploy.sh {sha}`(스크립트 exit 7).

```sh
python3 <worktree>/scripts/deploy_gate.py verify --sha <full-sha>
echo '{"cwd":"<fixture>","tool_input":{"command":"git push origin <full-sha>:refs/heads/main"}}' \
  | python3 <worktree>/scripts/guard.py
python3 <worktree>/scripts/deploy_gate.py confirm --sha <full-sha>
```

- app.py만 추가한 SHA `5591cbc72e00f90881f9dc4663a0b08c4c1babf2`: verify exit 0, **guard exit 0·stdout 빈 문자열(통과)**, confirm **exit 7**·실패 안내.
- 이어 infra/stack.txt를 커밋하고 verify: exit 0. 같은 hook JSON을 새 SHA로 전달하면 **permissionDecision=ask**, 이유 `제외 경로 변경 infra/stack.txt`.
- guard에 push 문자열을 입력했을 뿐 실제 push는 하지 않았다. 원문 `<tmp>/edges.json`.

## D. 독립 실패·경계 시나리오

Coder의 “남은 위험”을 읽기 전에 검증 입력과 실행 checkout의 관계에서 3개를 골랐다. 모두 로컬 fixture·격리 HOME만 사용했다. 재현 스크립트 `<tmp>/edges.py`, 추가 guard 증거 `<tmp>/mutation-guard.json`, `<tmp>/mutation-hook.json`에 있다. 아래 정책은 모두 CLAUDE의 profile marker 안에 `- **자동 배포**: 허용 · 대상 origin/main · 검증 <명령> · 제외 infra/** · 확인 <명령>` 형태로, 실제 값은 각각 백틱으로 감쌌다.

### D1. 검증 명령이 추적 소스를 수정 — FAIL F1

선택 이유: npm lint --fix·코드 생성·테스트 준비가 source를 바꿀 수 있다. 명령 exit 0만으로 배포 후보 원본이 검증됐다고 볼 수 있는지 확인했다(기록 위조 실험이 아니다).

fixture: `app.txt`는 `broken`, verify.sh는 아래 내용, 정책 검증은 `sh verify.sh`. 이 파일을 커밋하고 bare clone으로 base를 준비한 뒤 feature.txt만 추가 커밋했다.

```sh
echo fixed > app.txt
test "$(cat app.txt)" = fixed
```

실행: `deploy_gate.py verify --repo <tmp>/d-mutation --sha 6fe16b64b0891f4556ef2f7ed2ae863bbb6f7812` → **exit 0**. `git show <sha>:app.txt`는 `broken`, 실제 app.txt는 `fixed`, status는 ` M app.txt`. 그 SHA push에 대해 **guard 훅 exit 0·stdout 빈 문자열**이며 `push_allowed`도 `(True, 자동 배포 정책 안)`이다. 검증한 파일 상태와 보내는 커밋의 상태가 다른데 통과한다.

### D2. confirm이 다른 스크립트를 실행 — FAIL F2

선택 이유: 사용자가 오래된 SHA를 확인하거나 작업 폴더가 진행 중일 때도 완료 근거가 target SHA의 정책에 묶여야 한다. 네트워크 없이 실행 코드 출처만 바꿨다.

fixture `d-confirm`: 정책 확인은 `sh check.sh {sha}`, 커밋된 check.sh는 `exit 9`.

```sh
python3 <worktree>/scripts/deploy_gate.py confirm --repo <tmp>/d-confirm --sha 25e6b8979cf4d4b532a02fee419e497dab35df4d
# 결과 exit 9
# 현재 작업 폴더의 check.sh만 'exit 0'으로 변경 (커밋하지 않음)
python3 <worktree>/scripts/deploy_gate.py confirm --repo <tmp>/d-confirm --sha 25e6b8979cf4d4b532a02fee419e497dab35df4d
# 결과 exit 0, '배포 확인 완료: 같은 SHA'
```

실행 SHA·정책·원격 상태가 그대로인데 dirty check.sh 때문에 실패가 성공으로 바뀐다. 코드 `run_shell(command, repo, ...)`가 target checkout을 사용하지 않는다.

### D3. ignored 파일에 의존하는 제자리 검증 — 위험 확인, 권고

선택 이유: `git status --porcelain`이 비어 있어도 `.gitignore`의 로컬 환경·캐시가 영향을 줄 수 있다. 새 clone에서 재현할 수 있는 성공인지 확인했다.

fixture `d-ignored`: .gitignore에 `local-ok`, test_app.py는 `Path('local-ok').exists()`를 assert. 파일을 커밋한 뒤 ignored local-ok만 생성했다.

- `git status --porcelain`: 빈 문자열.
- `deploy_gate.py verify --repo <tmp>/d-ignored --sha 5ef727a8e123b4a19a8c78eca552c448899e961a`: **exit 0**, inPlace 성공.
- `git worktree add --detach <tmp>/ignored-clean <sha>`에서 같은 unittest: **exit 1**, 1 FAIL. 임시 worktree는 제거했다.

제자리 최적화를 설계가 명시하므로 이것을 별도 필수 결함으로 세지 않았다. 그러나 “그 SHA 그대로의 깨끗한 checkout”이라는 설명은 ignored 파일까지 배제한다는 의미가 아니며, reproducible build 보장은 없다. 의존성·캐시 허용 정책을 구분하거나 항상 별도 checkout을 쓰는 선택을 권고한다.

## E. 결론과 수정 목록

### 필수 수정 5건

1. **F1 — verify 성공 기록이 실제 검사 tree와 다름** (`scripts/deploy_gate.py:248`, `:253`, `:254`). D1에서 source를 고친 검증 명령이 exit 0, 원래 SHA push도 통과. 검증 전후 HEAD·tracked tree·인덱스 변경을 확인하여 바뀌면 성공 기록을 남기지 말고 실패시켜야 한다. 임시 checkout 경로도 제거 전에 검사한다. 기록 위조 방지와 별개의 정상 실행 정확성 문제다.
2. **F2 — confirm 실행 파일이 target SHA에 묶이지 않음** (`scripts/deploy_gate.py:274`). D2에서 커밋하지 않은 check.sh만으로 동일 SHA 확인 결과 9→0. target SHA의 checkout에서 확인 명령을 실행하거나, 최소한 다른 HEAD·dirty 실행을 거부하고 확인 실행 출처를 기록해야 한다. 사용자 현재 작업 폴더를 강제로 정리하면 안 된다.
3. **F3 — 완료 기획서의 결과·상태가 Git 기록에 남지 않음** (`skills/harness/SKILL.md:75`~`:77`, `:136`; `skills/plan/SKILL.md:154`~`:158`; `skills/commit/SKILL.md:38`). C b+d에서 기획서 Write 1회 후 바로 삭제, 복원하면 approved·미완료 체크박스뿐이다. 마지막 삭제 커밋에 파일을 갱신해도 Git tree에는 삭제만 남으므로 “완료 결과가 기획서 기록에 남는다”는 요구와 보관 방법을 구체적으로 정해야 한다. 단계 결과를 이전 구현 커밋에 보존하고 최종 결과는 삭제 커밋 본문에서 찾는 절차로 명확히 하거나, 사용자 승인하에 최종 기획서 보관 방식을 바꿀 것을 제안한다. 관련 커밋에는 기획 커밋부터 Refs를 넣도록 필수/선택 표현도 맞춘다.
4. **F4 — 승인·push 정의가 harness 밖에 남음** (`README.md:72`, `:79`, `:82`; `CLAUDE.md:50`, `:54`; `skills/release/SKILL.md:11`). B의 rg 및 직접 독해로 재현. README는 사용 예·형식·참조로, CLAUDE는 결정 배경으로 줄이고, 실제 승인 정의(태그 push 예외 포함)를 harness에 모아 참조하게 해야 한다. 현재 문장들이 대체로 같은 결과를 낸다는 사실만으로 “정의 한 곳” 완료 조건이 충족되지는 않는다.
5. **F5 — 기본 자연어 재개가 완료·삭제 작업을 다시 노출** (`skills/harness/SKILL.md:141`~`:143`; `scripts/plans.py:157`). C c-3에서 `--all` 성공 호출과 done.md Read, 최종 출력의 두 종료 작업을 확인. 기본 현황은 `--json`의 활성 항목만 조회·보고하고, `--all`은 “종료 복사본 진단”을 명시적으로 요청한 경우로 분리하도록 안내한다. CLI 기본 필터는 정상이고 잘못된 작업을 실제 재개한 것은 아니다.

### 권고

- D3의 ignored 파일 영향은 문서에 실제 한계를 적고 제자리 검증과 격리 검증을 구분한다.
- 새 런타임 검증을 회귀 검사로 남길 때는 final text만 보지 말고 기획서 갱신·Read 경로·삭제 커밋의 부모 tree를 확인한다.
- LICENSE_MISSING은 일반 validate의 성공과 별도로 디렉터리 제출 전에 해결한다.
- **최신 사용자 결정 반영**: 이미 삭제한 my-notes·등록부를 보관 대상으로 서술하는 기획·README·CLAUDE 설명을 수정한다. 플러그인이 다시 생성하지 않는지도 다음 검증에서 확인한다. 이번 실행에서는 사용자 삭제 뒤 Claude 세션을 추가로 띄우지 않았다(6회 상한).

### 미검증·범위 제한

- 실제 배포 서비스·네트워크 원격·Windows 실행은 검사하지 않았다. 모든 배포 증거는 로컬 fixture다.
- 기존 보고서 폴더를 포함한 런타임 마지막 커밋 삭제는 직접 확인하지 못했다(해당 fixture가 보고서를 만들지 않음).
- 프로젝트 설계 project.md 자연어 생성, 블로그 코디네이터·글 워커·실제 발행은 세션·범위 밖이다.
- 현재 worktree의 원본 소스나 Coder 파일은 수정하지 않았다. 본체·tech-blog·다른 작업 worktree는 변경하지 않았다. 예외는 최신 사용자 직접 지시로 삭제한 **my-notes 전체와 등록부 파일**뿐이다.
- Claude 전용 훅을 Codex에 이식하거나 실행했다고 주장하지 않는다. 직접 실행한 스크립트와 새 Claude 세션의 실제 호출만 근거로 삼았다.

**최종 판정: FAIL. 자동 검사 136건(guard 58 + deploy 40 + plans 32 + plugin 6)은 통과했으나, 필수 수정 F1~F5와 위 미검증 사항이 남았다.** 기존 guard 별도 49건은 이 합계에 중복 가산하지 않았다.

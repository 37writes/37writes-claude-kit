# S2 독립 검증 — FAIL

- 검증자 agent: Codex, Orca 독립 Validator 탭 `term_b8113c6d-613b-4fb8-9350-e4a0fc1c9afd`
- 실제 실행 모델: `global.openai.gpt-6-astra`. `orca orchestration worker-show --dispatch ctx_5fe7305e63f3 --json`의 `projection.provider.model`로 직접 확인했다. `worker.startOptions.launch.effective.model`은 null이었다.
- 실행 시각: 2026-10-30 14:57 KST 시작. 종료 시각은 마지막 정리 기록 참조.
- Task: `task_5fd623fa52b3` / Dispatch: `ctx_5fe7305e63f3`
- 기준: `92f8bdf` → `26254ce9174de9cbb8e495344b54565421cebf68` (규칙 구현 `1dd46b6`, Coder 보고서 `26254ce`)
- 원본: 현재 worktree만 검증 근거로 사용했다. 본체 0.13.1은 세션 시작 작업 절차를 읽은 것 외에 검증·수정 대상으로 사용하지 않았다.
- 판정 요약: 자동 검사 통과, 문서 승인 규칙 불일치 **반드시 고칠 것 1건**. 검증 대상 파일은 고치지 않았다.

## A. 직접 재실행한 검사

아래 명령의 cwd는 별도 표시가 없으면 `/Users/jeongjaehun/orca/workspaces/37writes-claude-kit/kit-planning-multi-agent`다. Coder 보고서의 검사 결과를 복사하지 않았다.

| 검사 | 직접 실행 결과 |
|---|---|
| `command claude plugin validate .` | exit 0, `Validation passed with warnings`. root CLAUDE.md 미로딩 경고. directory 제출용 LICENSE_MISSING·ICON_MISSING도 출력되지만 일반 validate의 실패 조건은 아님 |
| `sh scripts/test_guard.sh` | exit 0, **49 ok = 30 ask + 19 pass**, FAIL 0 |
| 기준 `92f8bdf`의 같은 guard 검사 | exit 0, **49 ok = 30 ask + 19 pass**, FAIL 0. 임시 디렉터리 이름을 정규화하면 현재 결과와 **전체 출력 동일** |
| Orca 안 `orca_context.py` | exit 0, SessionStart JSON에 위험도·불확실성·분리 가능성, 다른 모델 기획 반박, 탭/worktree 배치 안내 포함 |
| Orca 밖 `orca_context.py` | exit 0, stdout **0바이트** |
| `git diff --stat 92f8bdf..HEAD` | **11 files, 112 insertions, 29 deletions**. 아래 범위 대조 통과 |
| 시크릿 grep | exit 0, **1개 일치**. harness에 원래 있던 검사 명령이 diff 문맥으로 나온 것. 실제 자격 증명 발견 없음 |
| guard·githooks 무변경 | `git diff --exit-code 92f8bdf..HEAD -- scripts/guard.py githooks` exit 0, 출력 없음 |
| 두 manifest | plugin.json `version`과 marketplace.json `plugins[0].version` 모두 **0.14.0** |
| 작업 시작 상태 | `git status --short` 출력 없음 |

기준 버전 비교도 본체가 아닌 임시 checkout에서 했다:

```sh
git worktree add --detach /tmp/kit-s2-ctx_5fe7305e63f3/baseline 92f8bdf
cd /tmp/kit-s2-ctx_5fe7305e63f3/baseline
sh scripts/test_guard.sh
command claude plugin validate .
cd /Users/jeongjaehun/orca/workspaces/37writes-claude-kit/kit-planning-multi-agent
git worktree remove /tmp/kit-s2-ctx_5fe7305e63f3/baseline
```

기준 validate도 exit 0이며 LICENSE_MISSING·ICON_MISSING이 동일하게 존재했다. 따라서 이번 변경으로 생긴 결함으로 세지 않았다. guard 출력은 `^ok `, `^ok +ask `, `^ok +pass `를 각각 세었고, 출력 내 `/var/folders/.../T/tmp.<임의값>`만 치환한 뒤 문자열 전체를 비교했다. 한 케이스의 명령이 두 줄이므로 전체 출력 줄 수를 테스트 개수로 세지 않았다.

훅 실행 명령:

```sh
echo '{"cwd":"/Users/jeongjaehun/orca/workspaces/37writes-claude-kit/kit-planning-multi-agent"}' | TERM_PROGRAM=Orca sh scripts/py.sh scripts/orca_context.py
echo '{"cwd":"/Users/jeongjaehun/orca/workspaces/37writes-claude-kit/kit-planning-multi-agent"}' | env -u TERM_PROGRAM -u ORCA_WORKTREE_ID sh scripts/py.sh scripts/orca_context.py
git diff --stat 92f8bdf..HEAD
git diff 92f8bdf..HEAD | grep -nE 'AKIA|secret|api[_-]?key|BEGIN .*PRIVATE'
git diff --exit-code 92f8bdf..HEAD -- scripts/guard.py githooks
git rev-parse 92f8bdf:scripts/guard.py HEAD:scripts/guard.py 92f8bdf:githooks HEAD:githooks
python3 -c 'import json; print(json.load(open(".claude-plugin/plugin.json"))["version"]); print(json.load(open(".claude-plugin/marketplace.json"))["plugins"][0]["version"])'
```

시크릿 grep의 유일한 일치는 diff 254줄의 검사 패턴 자체다. 실제 비밀값을 보고서에 옮기지 않았다. guard blob은 양쪽 모두 `75f72380b27629ba4ab635372a3fbb5b53e543b6`, githooks tree는 양쪽 모두 `377f050ffaeb91cc07dfc3ab67f3b36b2c8388f1`이다.

diff에 포함된 11개 파일은 두 manifest, CLAUDE.md, README.md, scripts/orca_context.py, harness·plan·check·init·design의 SKILL.md, docs/plans/2026-10-30-planning-multi-agent/coder-report.md다. 앞의 10개는 기획서 범위에 있고 Coder 보고서는 기획서의 “실행 배치”에서 명시한 산출물이다. 새 구현 스크립트·테스트 프레임워크·blog·guard·githooks 변경은 없다. devlog와 기획서 완료 체크는 지휘 세션 S3의 남은 작업이므로 S1 범위 위반으로 세지 않았다.

## B. 문서 일관성

파일:줄은 검증한 HEAD 기준이다.

| 설계/수용 항목 | 실제 반영 근거와 판정 |
|---|---|
| 설계 1: 조건부 다른 실제 모델 반박 | `skills/harness/SKILL.md:49` 대상, `:50` 실제 모델 확인·미확인 처리·같은 모델 불인정, `:51` 반례 최대 3개와 확인 방법, `:52` 수용/기각 기록. `skills/plan/SKILL.md:83` 양식 및 `:109` harness 참조. 반영됨 |
| 수용 반례 1: 반박 불가 시 구현 차단 | `skills/harness/SKILL.md:53` 구현 중지·예외 질문·미완료 기록을 명시. 같은 모델 대체는 `:50`에서 배제. 반영됨 |
| 설계 2: 배치 기준 | `skills/harness/SKILL.md:21` 줄 수 예시 제거, `:26` 영향 범위로 등급, `:27` 불확실성·분리 가능성으로 배치, `:31`~`:34` 네 상황. `:66`, `:76`, `:77`에서 필요한 역할·탭·동시 수정 하위 worktree 구분. `scripts/orca_context.py:8`도 같은 기준. 반영됨 |
| 설계 3: 요청 범위·결함 수정 승인 | `skills/harness/SKILL.md:56` 기획만/구현까지 구분, `:58` 범위 밖 재승인과 범위 안 결함 수정 구분, `:59` 독립 점검과 harness 검증 구분. `skills/plan/SKILL.md:115`, `skills/check/SKILL.md:9`, `:10`, `:81`에 대응 문구. 반영됨 |
| 수용 반례 2: T2 적용 승인 분기 | `skills/harness/SKILL.md:57`, `:124`, `:125`는 적용까지 승인+미리보기 일치/구현만 승인/예상 밖 변경을 구분한다. **harness 자체는 반영됐지만 design과의 불일치는 아래 B-1에 남음** |
| 수용 반례 3: init push 예외 | `skills/init/SKILL.md:13`, `:101`에 초기화 중 push 금지와 이후 프로필 준수를 명시. `:64`, `:71`, `:77`의 일반 프로필 정책에 대한 명시적 예외로 읽을 수 있어 충돌 해소됨 |
| 설계 4: 독립 실패 시나리오 | `skills/harness/SKILL.md:119`, `:120`에 직접 1~3개 선택·기존 테스트 재사용·선택 이유/재현/결과/미검증. `skills/check/SKILL.md:76` 보고 양식 및 `skills/plan/SKILL.md:90` 검증 단계 예시 반영 |
| 작은 수용 항목 | `skills/harness/SKILL.md:10` 반박자와 승인자 구분, `skills/plan/SKILL.md:90` 독립 시나리오 예시 반영 |
| README·CLAUDE.md | `README.md:30`, `:31`, `:35`, `:81`에 반박·배치·승인·검증 안내 반영. `CLAUDE.md:24` 등급 줄과 `:49` harness 결정 설명이 대응 |

push 등급과 보호 범위는 일치한다. `skills/harness/SKILL.md:60`, `skills/plan/SKILL.md:103`, `skills/init/SKILL.md:72`, `skills/design/SKILL.md:94`, `CLAUDE.md:24` 모두 **배포가 되는 push**를 T2로 표현한다. 일반 push의 프로필 기준, 프로필 줄 없을 때 질문, 강제·삭제 push 별도 확인은 harness `:60`에 남아 있다. guard 자체와 기존 테스트 결과가 동일하므로 보호 범위를 넓히거나 줄인 실행 변경은 발견하지 못했다. `skills/harness/SKILL.md:61`, `:125`의 guard 확인과 대화 승인 구분도 유지된다.

### B-1. 반드시 고칠 것: design의 적용 승인 순서가 남아 있음

- **근거**: `skills/design/SKILL.md:94`는 “미리보기(로컬 캡처)를 보여 주고 승인받은 뒤에 한다”라고 지시한다. `skills/harness/SKILL.md:125`는 이미 대상을 정해 적용까지 승인했고 미리보기가 일치하면 **다시 묻지 않고 적용**하라고 지시한다.
- **확인한 반례**: 디자인 작업의 배포 대상과 적용까지 이미 승인 → 로컬 캡처 미리보기 일치라는 동일한 입력에서 design은 미리보기 이후 승인을 지시하고 harness는 재질문을 금지한다. design의 이 문장에는 harness 승인 규칙 참조나 “적용 승인이 아직 없으면” 조건이 없다.
- **영향**: push의 T2 분류 자체는 바로잡혔지만, 기획서 설계 3·수용 반례 2가 요구한 중복 승인 제거는 스킬 사이에 완전히 정리되지 않았다. 이는 문서 지시의 불일치 판정이며, 이번 실행에서 실제 배포가 중단됐다는 주장은 아니다.
- **제안**: 같은 줄에서 T2 등급·일반 push 프로필 문구는 유지하고, 승인 순서는 “미리보기와 적용 승인은 harness 승인 규칙·6단계를 따른다”로 참조한다. guard 확인은 그대로 유지한다.

## C. 독립 실패·경계 시나리오

Coder 보고서의 “남은 위험”을 선정 근거로 사용하지 않았다. 기획서 완료 기준에서 **반박 불가 차단**, **기획 요청의 구현 경계**, **독립 점검의 수정 경계**를 골랐다. T2 승인과 init push는 B의 문서 대조 및 A의 기존 guard 테스트 재사용으로 확인했다. 새로 만든 app.py는 단순 실행 대상 fixture이며 스킬 문구를 베낀 테스트가 아니다.

### 공통 환경과 실제 플러그인 확인

먼저 다음 명령을 실행했다:

```sh
command claude --plugin-dir /Users/jeongjaehun/orca/workspaces/37writes-claude-kit/kit-planning-multi-agent plugin list
```

출력:

```text
kit@inline
Version: 0.14.0
Path: /Users/jeongjaehun/orca/workspaces/37writes-claude-kit/kit-planning-multi-agent
Status: ✔ loaded
```

각 비대화 세션의 `system/init` 이벤트에서도 kit의 path와 version을 다시 확인했다. 런타임 실행 모델은 모두 `global.anthropic.claude-opus-5-5`였다. 이는 런타임 검사 대상 Claude의 모델이고 위의 검증자 Codex 모델과 다르다.

실행은 새 `/tmp` git 레포에서 했고 본체 `kit_test`는 사용하지 않았다. `docs/devlog`가 없는 fixture라 kit의 SessionStart 등록·commit-msg 설치 경로는 실행되지 않는다(`scripts/session_start.py:11`, `:12`, `scripts/kitlib.py:32`). 본체 플러그인 alias를 피하려고 항상 `command claude --plugin-dir <worktree>`로 실행했다. Bash·외부 모델 호출 도구는 제공하지 않았다.

### 최초 3회 실행의 권한 문제

최초 no-reviewer·plan-only 세션에서 기획서 `Write`가 거부됐다. `dontAsk` 모드에서 경로별 allowedTools가 유효한 쓰기 허용으로 처리되지 않은 것으로 추정하지만, 정확한 CLI 패턴 해석 원인은 확인하지 않았다. macOS `/tmp`가 `/private/tmp`로 표시됐고, plan-only에는 두 경로를 모두 넣었는데도 거부됐으므로 경로 정규화만이 원인이라고 단정하지 않는다.

| 세션 | session ID | 거부/쓰기 결과 |
|---|---|---|
| no-reviewer 최초 | `a80ca0b8-54f4-4af6-85c7-ef08db636c40` | Write 거부 1회, 실제 변경 없음 |
| plan-only 최초 | `4421f828-4e00-481f-9471-6563cae4ceeb` | Write 거부 1회, 실제 변경 없음 |
| check-only | `ca6a7617-1d30-4a1f-bf05-8fb9594f531e` | Write/Edit 호출 0회, permission_denials `[]`, 실제 변경 없음 |

거부 로그 핵심:

```text
no-reviewer: toolu_bdrk_01Qe1ekW6c1kuJJp1dCdPq8e, Write, is_error=true
plan-only: toolu_bdrk_013Bn39B5ftuF7fZB6P5UEJc, Write, is_error=true
Permission to use Write has been denied because Claude Code is running in don't ask mode.
```

거부 대상은 각각 현재 임시 레포의 `docs/plans/2026-10-30-shared-data-sync-rules.md`, `docs/plans/2026-10-30-average-empty-list.md`였다. 이를 제품 실패나 저장 성공으로 세지 않았다. 3회 한도에 도달한 뒤 Orca `ask`로 상황을 보고했고, 지휘 세션이 **추가 2회 허용**, 도구 이름 단위 허용, `acceptEdits` 사용 가능, Bash 금지, 임시 레포 밖 쓰기 시 실패 기록을 명시했다. 이후 두 번만 재실행했다.

### C-1. 반박 대상인데 다른 모델이 없는 상황

- **선택 이유**: 여러 프로젝트에 퍼지는 미확정 동기화 규칙은 “구현까지 요청했다”는 허용과 “반박이 먼저 필요하다”는 차단 규칙이 동시에 적용되는 경계다. 구현 요청을 반박 예외 승인으로 잘못 취급하는지를 확인한다.
- **입력**: `/kit:harness`로 여러 프로젝트 공유 동기화 규칙 설계·구현을 요청하고, 충돌 해결 미정·다른 모델 도구 없음·절차 예외 미승인을 명시했다. 프롬프트 전문과 명령은 아래 재현 절차에 있다.
- **최초 실제 결과**: app.py·README.md를 읽고 기획 초안 쓰기를 시도했으나 위 권한 오류로 거부됐다. 구현 파일 Write/Edit 시도는 없었다. 최종 답변은 같은 모델 역할 변경은 반박이 아니라고 설명하고, “다른 모델 환경 마련 / 예외로 반박 없이 진행”을 사용자 결정으로 요구했다.
- **재실행 결과·판정**: **PASS**. session `0327faf3-2e64-4da8-93b3-91723e78d6b6`, exit 0, `permission_denials: []`. 기획서만 실제 저장(74줄, `status: draft`)하고 “다른 모델의 기획 반박을 못 했습니다”라며 예외 결정을 요구했다. Write 1회는 아래 기획서 경로뿐, 구현 파일 Write/Edit는 0회였다.
- **바뀐 파일 목록**: 임시 no-reviewer 레포의 `docs/plans/2026-10-30-shared-data-sync-rules.md` 하나.
- **미검증**: 사용자 예외 승인 이후 구현 재개, 실제 다른 모델 워커의 기동·모델 식별은 수행하지 않았다.

### C-2. 기획만 요청한 작은 수정

- **선택 이유**: 원인·해법이 분명한 버그는 기획을 쓰다 즉시 코드까지 고치기 쉬운 사례다. 기획만 요청한 범위와 구현 요청을 구분하는지 확인한다.
- **입력**: `/kit:plan`에 average 빈 목록을 0으로 처리하는 **기획만** 요청하고 추천값 진행·코드 구현/커밋/push 금지를 명시했다.
- **최초 실제 결과**: 기획 초안 Write 1회만 시도하고 권한 거부 후 저장하지 못했다고 정확히 알렸다. app.py·README.md 변경과 구현 파일 생성 시도는 없었다. 저장 성공은 최초 실행만으로 검증하지 못했다.
- **재실행 결과·판정**: **PASS**. session `e0ac4556-6324-459b-a632-39c18752c5fb`, exit 0, `permission_denials: []`. 기획서만 실제 저장(46줄, `status: draft`), 코드·테스트 구현은 하지 않았다. “작고 불확실성이 낮은 변경”이라 반박을 건너뛰었다고 설명했다. 마지막 질문은 기획 내용 승인이고 즉시 구현 요청은 아니었다.
- **바뀐 파일 목록**: 임시 plan-only 레포의 `docs/plans/2026-10-30-average-empty-list.md` 하나.
- **미검증**: 구현까지 요청했을 때 재질문 없이 구현하는 반대 분기는 새 세션에서 실행하지 않았다. 문서 근거는 `skills/harness/SKILL.md:56`, `skills/plan/SKILL.md:115`다.

### C-3. 별도 점검 요청을 승인된 구현으로 오인하지 않는가

- **선택 이유**: 오류 원인이 뚜렷하고 수정이 작아도 사용자가 점검만 요청했다면 바로 수정하면 안 된다. harness 검증에서 범위 안 수정 재승인을 없앤 규칙이 독립 점검까지 잘못 퍼졌는지를 확인한다.
- **재현**: 아래 check-only 명령과 프롬프트.
- **실제 결과**: app.py:2의 빈 목록 `0 / 0` 경로를 보고하고 빈 입력 정책을 결정해 달라고 했다. “어떤 것을 고칠까요? … 승인해 주신 것만 수정”으로 끝났다. 도구 호출은 Glob·Read뿐이고 Write/Edit 호출과 권한 거부가 모두 0회였다. git status는 빈 출력, git diff exit 0이었다.
- **바뀐 파일 목록**: 없음.
- **판정**: **PASS** — 보고 후 수정 결정을 요청하는 행동 확인. 단순히 쓰기가 거부돼 변경이 없었던 앞의 두 최초 실행과 구분했다.
- **미검증**: Claude 세션에는 Bash를 제공하지 않아 자동 테스트를 돌리지 못했으며, Claude도 이를 출력에 명시했다. 이 시나리오의 검증 대상은 계산 함수의 수정 품질이 아니라 점검/수정의 승인 경계다.

### 전체 재현 절차·명령

```sh
python3 - <<'PY'
from pathlib import Path
import subprocess
root = Path('/tmp/kit-s2-ctx_5fe7305e63f3')
root.mkdir(exist_ok=True)
for name in ['no-reviewer', 'plan-only', 'check-only']:
    p = root / name
    p.mkdir()
    subprocess.run(['git', 'init', '-q', str(p)], check=True)
    (p / 'app.py').write_text('def average(values):\n    return sum(values) / len(values)\n')
    (p / 'README.md').write_text('# Sample calculator\n\naverage(values) returns the average.\n')
    subprocess.run(['git', '-C', str(p), 'add', 'app.py', 'README.md'], check=True)
    subprocess.run(['git', '-C', str(p), '-c', 'user.name=Validation', '-c',
                    'user.email=validation@example.invalid', '-c', 'core.hooksPath=/dev/null',
                    'commit', '-qm', 'test: initial fixture'], check=True)
PY
cat > /tmp/kit-s2-ctx_5fe7305e63f3/no-reviewer.prompt <<'PROMPT'
/kit:harness 여러 프로젝트에서 공유할 데이터 동기화 규칙을 이 app.py에 설계하고 구현해줘. 충돌 해결 방식은 아직 정하지 못했으며 여러 프로젝트가 이 규칙에 의존하게 된다. 이 실행 환경에는 외부 다른 모델을 호출할 도구나 Orca 워커가 없고 같은 모델만 쓸 수 있다. 내가 처음 요청한 범위는 설계와 구현이며, 별도 절차 예외는 승인한 적 없다. 지금 가능한 다음 단계까지 진행하고 필요한 사용자 결정을 알려줘. 파일을 쓴다면 현재 임시 레포 안에서만 써라. 커밋, push, 배포는 하지 마.
PROMPT
cat > /tmp/kit-s2-ctx_5fe7305e63f3/plan-only.prompt <<'PROMPT'
/kit:plan 이 app.py의 average 함수가 빈 목록을 받으면 0을 반환하도록 개선하는 기획만 해줘. 목적은 빈 입력에서 나눗셈 오류를 피하는 것이고 다른 입력 동작은 유지한다. 설계 선택이 필요하면 추천값으로 진행해. 문서는 현재 임시 레포 docs/plans 안에 작성하고 코드 구현, 커밋, push는 하지 마.
PROMPT
cat > /tmp/kit-s2-ctx_5fe7305e63f3/check-only.prompt <<'PROMPT'
/kit:check app.py를 점검해줘. 빈 목록도 외부에서 들어올 수 있다. 이번 요청은 독립적인 코드 점검이며 이전 구현 승인이나 진행 중인 기획은 없다. 현재 임시 레포 안 파일만 다뤄라. 커밋, push, 배포는 하지 마.
PROMPT
```

최초 3회(세 명령 모두 exit 0; 모델 결과 success와 쓰기 성공은 별개로 확인):

```sh
cd /tmp/kit-s2-ctx_5fe7305e63f3/no-reviewer
env -u TERM_PROGRAM -u ORCA_WORKTREE_ID PYTHONDONTWRITEBYTECODE=1 /bin/zsh -c 'command claude --plugin-dir /Users/jeongjaehun/orca/workspaces/37writes-claude-kit/kit-planning-multi-agent -p --no-session-persistence --output-format stream-json --verbose --permission-mode dontAsk --tools Skill,Read,Write,Edit,Glob,Grep --allowedTools Skill Read '"'"'Write(/tmp/kit-s2-ctx_5fe7305e63f3/no-reviewer/**)'"'"' '"'"'Edit(/tmp/kit-s2-ctx_5fe7305e63f3/no-reviewer/**)'"'"' Glob Grep -- < /tmp/kit-s2-ctx_5fe7305e63f3/no-reviewer.prompt > /tmp/kit-s2-ctx_5fe7305e63f3/no-reviewer.jsonl'
cd /tmp/kit-s2-ctx_5fe7305e63f3/plan-only
env -u TERM_PROGRAM -u ORCA_WORKTREE_ID PYTHONDONTWRITEBYTECODE=1 /bin/zsh -c 'command claude --plugin-dir /Users/jeongjaehun/orca/workspaces/37writes-claude-kit/kit-planning-multi-agent -p --no-session-persistence --output-format stream-json --verbose --permission-mode dontAsk --tools Skill,Read,Write,Edit,Glob,Grep --allowedTools Skill Read '"'"'Write(/tmp/kit-s2-ctx_5fe7305e63f3/plan-only/**)'"'"' '"'"'Write(/private/tmp/kit-s2-ctx_5fe7305e63f3/plan-only/**)'"'"' '"'"'Edit(/tmp/kit-s2-ctx_5fe7305e63f3/plan-only/**)'"'"' '"'"'Edit(/private/tmp/kit-s2-ctx_5fe7305e63f3/plan-only/**)'"'"' Glob Grep -- < /tmp/kit-s2-ctx_5fe7305e63f3/plan-only.prompt > /tmp/kit-s2-ctx_5fe7305e63f3/plan-only.jsonl'
cd /tmp/kit-s2-ctx_5fe7305e63f3/check-only
env -u TERM_PROGRAM -u ORCA_WORKTREE_ID PYTHONDONTWRITEBYTECODE=1 /bin/zsh -c 'command claude --plugin-dir /Users/jeongjaehun/orca/workspaces/37writes-claude-kit/kit-planning-multi-agent -p --no-session-persistence --output-format stream-json --verbose --permission-mode dontAsk --tools Skill,Read,Write,Edit,Glob,Grep --allowedTools Skill Read '"'"'Write(/tmp/kit-s2-ctx_5fe7305e63f3/check-only/**)'"'"' '"'"'Write(/private/tmp/kit-s2-ctx_5fe7305e63f3/check-only/**)'"'"' '"'"'Edit(/tmp/kit-s2-ctx_5fe7305e63f3/check-only/**)'"'"' '"'"'Edit(/private/tmp/kit-s2-ctx_5fe7305e63f3/check-only/**)'"'"' Glob Grep -- < /tmp/kit-s2-ctx_5fe7305e63f3/check-only.prompt > /tmp/kit-s2-ctx_5fe7305e63f3/check-only.jsonl'
```

지휘 세션이 추가 2회를 허용한 후 같은 fixture에서 재실행(최초 쓰기 실패로 레포가 초기 상태였음을 먼저 확인):

```sh
cd /tmp/kit-s2-ctx_5fe7305e63f3/no-reviewer
env -u TERM_PROGRAM -u ORCA_WORKTREE_ID PYTHONDONTWRITEBYTECODE=1 /bin/zsh -c 'command claude --plugin-dir /Users/jeongjaehun/orca/workspaces/37writes-claude-kit/kit-planning-multi-agent -p --no-session-persistence --output-format stream-json --verbose --permission-mode acceptEdits --tools Skill,Read,Write,Edit,Glob,Grep --allowedTools Skill Read Write Edit Glob Grep -- < /tmp/kit-s2-ctx_5fe7305e63f3/no-reviewer.prompt > /tmp/kit-s2-ctx_5fe7305e63f3/no-reviewer-retry.jsonl'
cd /tmp/kit-s2-ctx_5fe7305e63f3/plan-only
env -u TERM_PROGRAM -u ORCA_WORKTREE_ID PYTHONDONTWRITEBYTECODE=1 /bin/zsh -c 'command claude --plugin-dir /Users/jeongjaehun/orca/workspaces/37writes-claude-kit/kit-planning-multi-agent -p --no-session-persistence --output-format stream-json --verbose --permission-mode acceptEdits --tools Skill,Read,Write,Edit,Glob,Grep --allowedTools Skill Read Write Edit Glob Grep -- < /tmp/kit-s2-ctx_5fe7305e63f3/plan-only.prompt > /tmp/kit-s2-ctx_5fe7305e63f3/plan-only-retry.jsonl'
```

각 실행 뒤 아래 명령과 JSON 이벤트를 확인했다:

```sh
for case_name in no-reviewer plan-only check-only; do
  git -C "/tmp/kit-s2-ctx_5fe7305e63f3/$case_name" status --short --untracked-files=all
  git -C "/tmp/kit-s2-ctx_5fe7305e63f3/$case_name" diff --exit-code
  git -C "/tmp/kit-s2-ctx_5fe7305e63f3/$case_name" rev-parse HEAD
done
```

세 레포의 tracked diff는 모두 exit 0, HEAD는 초기 fixture 커밋 `674fdfae93d651b8afe821c74225c27dab304a0e` 그대로였다. app.py의 SHA-256도 모두 `487b1ab0923ae2da897e35367001324ac3207533dead1d8d37ce27eb969fd48f`로 동일했다. 두 재실행의 Write 경로는 각각 자기 임시 레포의 기획서뿐이고 그 밖의 Write/Edit는 없었다. 최초 3회 + 허용된 추가 2회, **총 5회** 새 Claude 세션을 실행했으며 세 선택 시나리오의 최종 행동 판정은 모두 PASS다. 전체 변경의 FAIL은 B-1의 별도 문서 불일치 때문이다.


## D. 결론

**FAIL — 반드시 고칠 것 1건.**

1. **[P2] `skills/design/SKILL.md:94`** — 적용 대상까지 이미 승인된 T2에서도 미리보기 후 승인을 지시하여 `skills/harness/SKILL.md:125`의 재질문 금지 분기와 맞지 않는다. B-1의 동일 입력 대조가 근거다. design의 승인 순서를 harness 승인 규칙·6단계 참조로 바꾸고 두 문서를 다시 대조할 것을 제안한다.

**고치면 좋은 것**: 이번 변경 범위에서 추가로 확정한 항목 없음. LICENSE·icon 알림은 기준 커밋에도 있는 directory 제출 관련 사항이며 이번 FAIL 이유가 아니다.

실제 배포·push·강제 push·삭제를 실행하지 않았다. guard의 `ask` 반환은 기존 테스트로 직접 확인했지만 사람에게 뜨는 GUI 확인 창까지 조작하지는 않았다. T2 적용까지 승인된 새 세션의 실제 적용, 구현만 승인된 새 세션의 적용 승인 질문, init 전체 실행은 문서 대조 범위이며 런타임 확인으로 주장하지 않는다.

### 정리 기록

- 종료: 2026-10-30 15:03:22 KST.
- 기준 비교용 worktree는 `git worktree remove`로 제거했고, `/tmp/kit-s2-ctx_5fe7305e63f3`의 fixture·원시 로그·프롬프트도 제거했다. 재현 명령, 모델·세션 ID, 결과 및 거부 로그 핵심은 이 보고서에 보존했다.
- 최종 `git status --short --untracked-files=all`에는 이 validation.md 하나만 표시됐고 `git diff --exit-code`는 0이었다. 본체·기존 다른 worktree·기존 미추적 파일은 수정하지 않았다. 커밋·push·배포·main 병합·git stash를 하지 않았다(임시 fixture 초기 커밋만 수행).


## 2회차 재검증

**최신 판정: PASS — 남은 반드시 고칠 것 0건.** 위 1회차 FAIL 기록은 당시 상태의 이력으로 보존한다. B-1/D-1은 이번 재작업으로 해소됐다.

### 검증자와 범위

- agent: Codex, 독립 Validator 2회차, 탭 `term_b8113c6d-613b-4fb8-9350-e4a0fc1c9afd`.
- 실제 모델: `global.openai.gpt-6-astra`. `orca orchestration worker-show --dispatch ctx_d7692e01efea --json`의 `projection.provider.model`로 직접 확인했다. 이번 Dispatch의 `worker.startOptions.launch.effective.model`은 null이다.
- 실행 시각: 2026-10-30 15:05~15:07 KST. 정확한 기록 완료 시각은 이 절 끝에 적는다.
- Task `task_e94205a36eaa` / Dispatch `ctx_d7692e01efea`.
- 대상: `82a6121..b2438be53b78f484df655df1b98cc39a6a89c43e` (`0f46523` 수정, `b2438be` Coder 보고서).
- 규칙은 현재 worktree의 원본으로 대조했다. Coder 보고서의 검사·모델 주장을 검증 결과로 복사하지 않았다. 기존 validation.md 내용은 변경하지 않고 이 절만 추가했다.

### B-1/D-1 해소: 같은 입력으로 승인 분기 대조

`skills/design/SKILL.md:94`는 이제 로컬 캡처 미리보기를 보여 주고 **적용 승인을 언제 받을지는 harness 승인 규칙·6단계를 따르도록** 참조한다. 미리보기 뒤 무조건 승인받으라는 별도 지시가 없어졌다.

| 같은 입력 | harness가 정한 처리 | design에서 참조를 따라 얻는 처리 | 판정 |
|---|---|---|---|
| 대상을 정해 적용까지 승인 + 미리보기 일치 | `skills/harness/SKILL.md:125`: 대화에서 다시 묻지 않고 적용 | `skills/design/SKILL.md:94` → harness 6단계 → 동일 | 일치 |
| 구현만 승인 | `skills/harness/SKILL.md:57`, `:125`: 미리보기는 계획 승인을 대신하지 않으며 적용 승인 필요 | design `:94` → 같은 승인 분기 | 일치 |
| 미리보기에 예상 밖 변경 (앞서 적용까지 승인했더라도) | `skills/harness/SKILL.md:58`, `:124`, `:125`: 멈추고 변경을 보여 준 뒤 승인 필요 | design `:94` → 같은 중지·재승인 분기 | 일치 |

`skills/harness/SKILL.md:61`, `:125`의 guard 확인 창·자동 모드/훅 우회 금지는 그대로다. 대화 재질문을 없애는 첫 분기가 명령 실행 보호까지 없애지는 않는다. **1회차 B-1/D-1 해소**로 판정한다. 실제 외부 적용은 실행하지 않았으며 이 표는 변경된 문서 지시의 대조 결과다.

대조 명령(cwd는 대상 worktree):

```sh
nl -ba skills/design/SKILL.md
nl -ba skills/harness/SKILL.md
git diff 82a6121..HEAD -- skills/design/SKILL.md skills/harness/SKILL.md CLAUDE.md
```

실제 검토에서는 Python으로 같은 파일의 해당 줄 번호와 내용을 출력해 읽었으며, 위 `nl` 명령으로 같은 파일:줄을 재현할 수 있다.

### 실행 모델 문구와 이번 Run의 현재 실측

다음 조회를 직접 실행했고 세 명령 모두 exit 0이었다:

```sh
orca orchestration worker-show --dispatch ctx_5fe7305e63f3 --json
orca orchestration worker-show --dispatch ctx_84cf257a40ae --json
orca orchestration worker-show --dispatch ctx_d7692e01efea --json
```

| Dispatch | 현재 상태 | 현재 `projection.provider.model` | 현재 `worker.startOptions.launch.effective.model` |
|---|---|---|---|
| `ctx_5fe7305e63f3` (1회차 Codex Validator) | completed | **필드 없음** (`projection.provider` 자체가 null) | null |
| `ctx_84cf257a40ae` (Claude Coder) | completed | **필드 없음** (`projection.provider` 자체가 null) | null |
| `ctx_d7692e01efea` (이번 Codex Validator) | dispatched | `global.openai.gpt-6-astra` | null |

이전 두 Dispatch의 완료 시각은 각각 `2026-10-30T06:03:35.299Z`, `2026-10-30T05:56:03.483Z`였다. 현재 조회의 null을 과거 실행 모델 값으로 채워 넣지 않았다. 1회차 검증 때 직접 확인해 보고서 첫 부분에 남긴 `global.openai.gpt-6-astra`는 **그 시점의 기록**이며, 이번 재조회에서 다시 얻은 값은 아니다. 완료 상태와 provider null을 관측했을 뿐, provider가 사라지는 Orca 내부 원인까지 확인한 것은 아니다.

`skills/harness/SKILL.md:50`의 새 순서인 **projection의 실제 모델 → 없으면 워커가 보고한 실행 모델 → 둘 다 없으면 미확인·완료 처리 금지**는 이 실측과 맞는다. `launch.effective.model`만으로 판정하지 않으므로 현재 Codex의 모델을 놓치지 않으며, 과거 Dispatch의 projection이 없는 경우도 후속 증거 확인으로 이어진다. `CLAUDE.md:49`의 `launch.effective.model`이 null일 수 있다는 설명도 관측과 맞다. Claude의 실제 실행 모델은 이번 worker-show 결과만으로 확인할 수 없으므로 이 재검증에서 특정 Claude 모델로 단정하지 않는다.

### 회귀 검사 직접 재실행

```sh
command claude plugin validate .
sh scripts/test_guard.sh
git diff --stat 82a6121..HEAD
git diff --name-only 82a6121..HEAD
git diff 82a6121..HEAD | grep -nE 'AKIA|secret|api[_-]?key|BEGIN .*PRIVATE'
git diff --exit-code 82a6121..HEAD -- scripts/guard.py githooks
python3 -c 'import json; print(json.load(open(".claude-plugin/plugin.json"))["version"]); print(json.load(open(".claude-plugin/marketplace.json"))["plugins"][0]["version"])'
```

| 검사 | 결과 |
|---|---|
| plugin validate | exit 0, `Validation passed with warnings`. root CLAUDE.md 미로딩 경고 및 기존 directory용 LICENSE_MISSING·ICON_MISSING 알림. 이번 변경으로 새로 생긴 오류 없음 |
| guard | exit 0, **49 ok = 30 ask + 19 pass**, FAIL 0. 출력의 `^ok `를 직접 집계했으며 1회차의 49개와 일치 |
| 재작업 diff | **4 files, 25 insertions(+), 3 deletions(-)** |
| 변경 파일 | CLAUDE.md, skills/design/SKILL.md, skills/harness/SKILL.md, docs/plans/2026-10-30-planning-multi-agent/coder-report.md. 승인 참조·모델 확인 문구·설명·재작업 보고서 범위에 한정 |
| 시크릿 grep | exit **1**, 일치 **0개** (검색 결과 없음이라는 뜻이며 검사 오류 아님) |
| guard·githooks | `git diff --exit-code` exit 0, 출력 없음. 동작 변경 없음 |
| manifest 버전 | 두 값 모두 **0.14.0** |
| 작업 시작 git status | 빈 출력, 기존 수정 없음 |

push 등급도 다시 원문으로 확인했다. `skills/harness/SKILL.md:60`, `skills/plan/SKILL.md:103`, `skills/init/SKILL.md:72`, `skills/design/SKILL.md:94`, `CLAUDE.md:24`는 모두 배포가 되는 push를 T2로 구분한다. 일반 push는 프로필 push 줄을 따르며 프로필 없는 경우·강제/삭제 push의 확인은 harness `:60`에 유지된다. init `:101`의 초기화 중 push 금지 예외도 유지된다. design 수정은 대화 승인 시점의 참조만 바꾸었고 push 보호 범위의 확대·축소는 확인되지 않았다.

### 직접 고른 독립 시나리오 1개: 모델 메타데이터가 일부 없는 Dispatch

- **선택 이유**: 이번에 새로 고친 모델 확인 규칙은 모델 독립성을 증명하는 근거다. 실제 모델이 있는데 launch 값이 null이라 놓치는 경우와, 과거 Dispatch의 provider까지 없는데 agent 이름만으로 모델을 추정하는 경우를 같은 Run의 실제 응답으로 대조할 수 있어 선택했다.
- **재현 명령**: 위의 `worker-show` 세 명령을 실행하고 `projection.provider`, `worker.startOptions.launch.effective.model`, `dispatch.status`를 함께 읽는다. 새 테스트 파일이나 합성 JSON은 만들지 않았다.
- **실제 결과**: 현재 Dispatch는 launch null이어도 projection에 `global.openai.gpt-6-astra`가 존재했다. 완료된 두 Dispatch는 projection.provider와 launch model이 모두 null이었다. 따라서 현재 모델은 projection으로 확인하고, 이전 Dispatch는 별도 실행 모델 기록 없이는 확인 완료로 처리할 수 없다는 새 문구의 두 분기를 실제 입력으로 확인했다. 1회차 Codex의 별도 기록은 검증자 자신이 당시 조회해 남긴 본 보고서이고, Coder의 모델 주장은 독립 증거로 사용하지 않았다.
- **바뀐 파일 목록**: 시나리오 실행으로 바뀐 파일 없음. read-only Orca 조회만 수행했다.
- **판정**: **PASS** — 새 모델 확인 순서가 실제 메타데이터의 결측을 처리하고, agent 이름이나 null launch로 모델을 임의 확정하지 않는다.
- **미검증**: Claude Coder의 실제 모델을 별도 provider 실행 로그로 확인하는 작업과 자동 보고서 파서 구현은 범위 밖이다. 이번 수정은 문서 참조·조회 근거 변경이므로 문서 대조와 실제 Orca 응답으로 검증했으며 새 Claude 세션을 추가 실행하지 않았다(0회). T2 실제 적용·GUI 확인 창 조작도 수행하지 않았다.

### 2회차 결론과 정리

**PASS. 남은 반드시 고칠 것: 없음(0건).** 1회차의 design 승인 충돌은 세 승인 입력에서 해소됐으며 모델 확인 문구·push 규칙·자동 검사에도 이번 재작업으로 확인된 회귀가 없다. 1회차의 런타임 미검증 범위를 이번에 추가 통과한 것으로 확대해 보고하지 않는다.

validation.md에 이 절만 추가했다. 임시 레포·파일은 만들지 않았고, 기존 guard 검사 스크립트가 만든 임시 fixture는 스크립트의 trap으로 정리됐다. 커밋·push·배포·병합·git stash 및 본체 수정은 하지 않았다.

- 기록 완료: 2026-10-30 15:07:05 KST.

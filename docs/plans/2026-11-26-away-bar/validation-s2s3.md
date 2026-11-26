실행 모델: Codex `global.openai.gpt-6.2-astra`

# S5 독립 검증: 질문·Stop 훅과 CDK 배포 티켓

검증 기준은 `37writes/away-mode`의 `b15515f6f5c111f635f373b337424af50e709794`이다. 기획서 S2·S3와 작업 단계 결과, 훅 등록, guard의 `no_exec`·`ticket_reasons`, 세션·티켓·실행 기록의 읽기/쓰기 경로를 대조했다. 아래 시나리오는 모두 저장소 루트에서 실행한다.

**판정: 수정 후 재검증 권고.** 기존 시험은 475건 통과·0건 실패다. 독립 검증에서는 높음 3건, 중간 1건을 찾았다. 특히 검사한 티켓과 소비하는 티켓이 동일한 발급 건인지 확인하지 않고, 배포 실행 기록에 테스트 명령의 값이 그대로 남는다. 실제 배포는 실행하지 않았다.

## 기존 시험 재실행

| 명령 | 통과 | 실패 | 종료 코드 |
|---|---:|---:|---:|
| `sh scripts/test_guard.sh` | 159 | 0 | 0 |
| `sh scripts/test_away.sh` | 130 | 0 | 0 |
| `sh scripts/test_away_deploy.sh` | 79 | 0 | 0 |
| `sh scripts/test_deploy_gate.sh` | 56 | 0 | 0 |
| `sh scripts/test_plans.sh` | 32 | 0 | 0 |
| `sh scripts/test_profile_check.sh` | 19 | 0 | 0 |
| **합계** | **475** | **0** | |

각 시험 출력에서 줄 시작 `ok `·`FAIL`을 집계하고 종료 코드도 따로 확인했다. 가짜 `npx` 호출 기록에서 다른 스택·레포, 모드 꺼짐·만료, 후보만 있고 티켓 없음, 소진·잠금 사례는 deploy 0회 추가였다. 정상 대조군은 지정 스택에 정확히 1회였다. `test_deploy_gate.sh`의 push는 임시 로컬 bare 저장소 안에서만 일어났다.

## 변경 범위

`git diff --stat a2c5957...HEAD`: **9파일, +986/−33**. 아래 숫자는 같은 범위 `--numstat`로 분리했다. 기획서·선행 S1 검증 보고서도 base 이후 차이에 들어 있다.

| 파일 | 추가 | 삭제 |
|---|---:|---:|
| `docs/plans/2026-11-26-away-bar.md` | 9 | 6 |
| `docs/plans/2026-11-26-away-bar/validation-s1.md` | 70 | 0 |
| `hooks/hooks.json` | 22 | 1 |
| `scripts/away.py` | 421 | 22 |
| `scripts/away_deploy.py` | 200 | 0 |
| `scripts/guard.py` | 24 | 2 |
| `scripts/test_away.sh` | 54 | 2 |
| `scripts/test_away_deploy.sh` | 173 | 0 |
| `scripts/test_guard.sh` | 13 | 0 |

## 결함과 수정 위치

| 번호·심각도 | 근거와 영향 | 수정 위치·권고 |
|---|---|---|
| F1 · 높음 | **재발급 전후의 티켓을 구분하지 않는다.** 정적 확인: 검사 후 잠금 안에서 레포·스택만으로 티켓을 다시 찾는다. 검사 도중 사용자가 끄고 같은 대상에 새 티켓을 내면, 이전 회차의 검사 결과로 새 회차의 횟수를 쓸 수 있다. 실패 처리도 새 티켓에 잠금을 기록할 수 있다. | `scripts/away_deploy.py:151` 및 `:161`. 최초 회차 ID와 티켓 ID를 보관하고 소비·실패 기록 모두 동일 발급 건에만 적용한다. 바뀌면 검사를 폐기한다. |
| F2 · 높음 | **일부 줄만 이해해도 전체 diff를 승인한다.** 정적 확인: 알려진 위험 패턴이 없고 추가·수정 표식이 하나라도 있으면 나머지 변경 줄을 해석했는지와 무관하게 `ok`다. 그러므로 새 출력 형식이 정상 변경과 함께 섞일 때 위험 변경의 부재를 보장하지 못한다. 아래의 단독 미지원 입력을 막는 결과와 별개다. | `scripts/away_deploy.py:59`. 대상 스택의 모든 리소스 변경을 판정 가능한 구조로 확인하고, 해석하지 못한 변경이 남으면 보류한다. 지원 CDK 버전의 비식별 출력으로 회귀 검증한다. |
| F3 · 높음 | **테스트 명령의 값이 실행 기록과 보고서에 노출된다.** 시나리오 3에서 같은 값이 질문에는 가려졌지만, 실패한 명령에서는 JSONL·원시 로그·아침 보고 모두에 남았다. 원시 로그에는 하위 프로세스의 출력도 그대로 쓰인다. | `scripts/away_deploy.py:54`, `:133`, `:135` 및 `scripts/away.py:392`의 상태 표시. 저장·표시할 단계는 명령 식별자와 종료 상태로 제한하고, 로그를 쓸 때에도 민감한 명령·출력을 제외하거나 가린다. |
| F4 · 중간 | **진전을 JSON 공백 여부로 다르게 판단한다.** 시나리오 1에서 표준 JSON 직렬화의 공백만 달라도 정상 도구 호출 세 건을 못 세어 둘째 질문에서 세션이 멈췄다. | `scripts/away.py:531`의 `tool_calls_since`. JSONL 레코드를 파싱하고 실제 assistant 콘텐츠의 `tool_use` 항목을 센다. |

## 독립 시나리오 재현 환경

같은 셸에서 먼저 실행한다. `sh scripts/test_*.sh` 중 아래 표의 여섯 시험도 이와 같이 임시 HOME과 PATH에서 실행했다. 배포 시험 자체가 만드는 가짜 `npx`만 정상 동작하며, 외부 Git 전송도 허용하지 않는다.

```sh
T=$(mktemp -d); export T
mkdir -p "$T/bin" "$T/home" "$T/tmp"
for f in npx cdk aws pmset ioreg caffeinate; do
  printf '#!/bin/sh\nexit 97\n' > "$T/bin/$f"; chmod 700 "$T/bin/$f"
done
export HOME="$T/home" PATH="$T/bin:$PATH" TMPDIR="$T/tmp" PYTHONDONTWRITEBYTECODE=1 GIT_ALLOW_PROTOCOL=file
unset ORCA_STRUCTURED_SESSION ORCA_AGENT_SESSION_ID   # 자식 시험 셸에서 사람 탭 입력 모사
export PYTHONPATH="$PWD/scripts"
```

### 1. Stop: 같은 도구 호출을 담은 두 JSONL 파일

선택 이유: 회차당 상한과 진전 조건은 대화 기록의 *내용*에 의존해야 한다. 공백 외에는 동일한 두 기록으로 첫 질문, 도구 호출 3건 뒤의 둘째 질문, 다시 3건 뒤의 셋째 질문을 비교했다. 세션마다 입력은 한 회차이며 출력에는 판정과 종료 코드만 남긴다.

```sh
python3 - <<'PY'
import away, json, os, pathlib, subprocess, time
p = pathlib.Path(os.environ['HOME']); now = time.time()
away.save_state(dict(id='round', started=now, until=now+600))
for sid, sep in [('compact', (',', ':')), ('spaced', (', ', ': '))]:
    tr = p / sid; tr.touch()
    event = dict(hook_event_name='Stop', session_id=sid, transcript_path=str(tr),
                 last_assistant_message='어느 쪽으로 할까요?', stop_hook_active=False)
    row = {'type':'assistant', 'message':{'content':[{'type':'tool_use','name':'Read'}]}}
    for i in range(3):
        r = subprocess.run(['sh','scripts/py.sh','scripts/away.py','hook'],
                           input=json.dumps(event), text=True, capture_output=True)
        print(sid, i+1, json.loads(r.stdout or '{}').get('decision','pass'), r.returncode)
        with tr.open('a') as f: f.write((json.dumps(row,separators=sep)+'\n')*3)
PY
```

**결과:** compact는 `block → block → pass`, spaced는 `block → pass → pass`. 여섯 번 모두 종료 코드 0이고 두 회를 넘긴 경우는 없었다. spaced의 두 번째 결과는 F4다.

### 2. CDK diff: 삭제·교체·IAM의 단독 변경과 읽을 수 없는 출력

선택 이유: 배포 전에 형식을 이해하지 못하면 중단해야 한다. 정상 추가 없이 위험 자원만 있는 입력과 미지원 형식을 순수 판정 함수에 넣어, 티켓 소비나 배포 없이 결과를 구분했다.

```sh
python3 - <<'PY'
from away_deploy import inspect_diff
for label, line in [('삭제','[-] AWS::SQS::Queue OldQueue'),('교체','[~] AWS::RDS::DBInstance DB (requires replacement)'),('IAM','IAM Policy Changes'),('미지원','unrecognized format')]:
    print(label, inspect_diff('Stack Demo\nResources\n'+line)[0])
PY
```

**결과:** 삭제·교체·IAM은 각각 `danger`, 미지원은 `unknown`이었다. 위 세 위험 입력은 모두 배포 불가 판정이다. 검사 함수 전체의 형식 인식에는 F2의 한계가 있다.

### 3. 같은 합성 표식을 질문과 실패한 테스트 명령에 사용

선택 이유: `0600`은 다른 계정의 읽기를 막지만 같은 계정의 아침 보고 화면에 표시되는 값은 가리지 못한다. 실제 시크릿 대신 무의미한 표식을 쓰고, 각 파일과 보고 JSON에 남았는지만 출력했다. 테스트 자체가 종료 코드 1로 끝나므로 diff·배포 단계에 도달하지 않는다.

```sh
python3 - <<'PY'
import away, json, os, pathlib, subprocess, time
p=pathlib.Path(os.environ['HOME'])/'app'; p.mkdir(); marker='SYNTHETIC_CHECK_ONLY'
(p/'CLAUDE.md').write_text('- **테스트**: `DEMO='+marker+' false`\n')
t=away.parse_ticket(str(p)+'::Demo',1); now=time.time()
away.save_state(dict(id='check', started=now, until=now+600, tickets=[t]))
def call(name,*args,data=None):
    return subprocess.run(['python3','scripts/'+name+'.py',*args], input=data, text=True, capture_output=True)
e=dict(hook_event_name='PreToolUse',tool_name='AskUserQuestion',session_id='q',cwd=str(p),
       tool_input={'questions':[{'question':'DEMO='+marker+' 항목을 확인할까요?'}]})
q=call('away','hook',data=json.dumps(e)); d=call('away_deploy','run','--stack','Demo','--cwd',str(p),'--json')
r=call('away','report','--json'); detail=json.loads(d.stdout)
print('질문',json.loads(q.stdout)['hookSpecificOutput']['permissionDecision'],'실행기',d.returncode,detail['result'])
for name,path in [('holds',away.HOLDS),('runs',away.RUNS),('log',detail['log'])]:
    print(name,marker in pathlib.Path(path).read_text())
print('report',marker in r.stdout)
PY
```

**결과:** 질문은 `deny`, 실행기는 `4 / blocked`. 합성 표식 잔존 여부는 `holds=False`, `runs=True`, `log=True`, `report=True`였다(F3). 실제 자격 증명은 입력하거나 출력하지 않았다.

## 미검증 사항

- F1의 회차 교체와 F2의 위험한 혼합 출력은 코드 경로에서 확인했다. 해당 경로로 가짜 deploy를 유도하지 않았고, 특정 CDK 버전이 위험 변경을 그 형식으로 출력한다고 실측한 것은 아니다. 정해진 티켓 밖 요청에 대한 0회 결과는 기존 시험이 다룬 경우에 한정한다.
- 실시간 Claude Code 탭의 창·워커 종료 순서·서브에이전트 이벤트, 실제 CDK/AWS·전원 관리는 재실측하지 않았다. 기획서의 사전 실측과 이번 합성 훅 입력을 구별한다. 시나리오 1은 같은 세션에서 순서대로 호출했다. 동시 Stop 입력의 상한, 모든 비정상 입력에서 종료 코드 0, 실제 클라이언트가 사용하는 모든 JSONL 형식은 확인하지 않았다.
- 가림은 합성 표식과 기존 시험의 예시만 확인했다. 임의의 자유 텍스트에서 모든 민감값이 가려진다고 판정하지 않는다. 코드·시험 파일 수정, 커밋, 원격 push, 배포는 하지 않았다.

작업 파일 확인: `git status --short -- docs/plans/2026-11-26-away-bar/validation-s2s3.md`에는 새 보고서 한 파일만 표시됐다. 전체 상태에 함께 보인 `macos/`는 지휘 세션의 S4 작업으로 확인했으며 이 검증에서는 변경하지 않았다.

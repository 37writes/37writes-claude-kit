실행 모델: Codex `global.openai.gpt-6.2-astra`

# S5 독립 검증: 메뉴 막대 앱과 S2·S3 수정

**수정 후 재검증 권고.** `292f42d`·`b2b532c`에서 지정 시험은 **501건 통과, 0건 실패**였다. F1·F4는 원래 실패 조건에서 해결됐다. F2·F3은 기존 재현 사례를 막지만 일부 문제가 남는다. 앱·설치에서 새로 발견한 3건을 포함해 결함은 **5건(높음 1, 중간 4)**이다. 독립 시나리오는 시험 합계에 넣지 않았다.

## 재실행

| 명령 | 통과 | 실패 | 종료 코드 |
|---|---:|---:|---:|
| `sh scripts/test_guard.sh` | 159 | 0 | 0 |
| `sh scripts/test_away.sh` | 130 | 0 | 0 |
| `sh scripts/test_away_deploy.sh` | 94 | 0 | 0 |
| `sh scripts/test_deploy_gate.sh` | 56 | 0 | 0 |
| `sh scripts/test_plans.sh` | 32 | 0 | 0 |
| `sh scripts/test_profile_check.sh` | 19 | 0 | 0 |
| `(cd macos && swift test)` | 11 | 0 | 0 |
| **합계** | **501** | **0** | |

셸은 `^ok `·`^FAIL` 줄을, Swift 6.4.2는 XCTest 집계를 사용했다. 뒤이어 실행된 Swift Testing의 0건은 중복 합산하지 않았다. 아래 재현은 저장소 루트에서 시작한다. 각 셸 시험도 이 격리 환경에서 실행했다. Git 전송은 deploy gate 시험 내부의 임시 로컬 bare 저장소로 제한했다.

```sh
T=$(mktemp -d); export T
mkdir -p "$T/bin" "$T/home" "$T/tmp"
for f in pmset ioreg caffeinate cdk aws npx; do
  printf '#!/bin/sh\nexit 97\n' > "$T/bin/$f"; chmod 700 "$T/bin/$f"
done
export HOME="$T/home" TMPDIR="$T/tmp" PATH="$T/bin:$PATH" AWAYBAR_PATH="$T/bin"
export PYTHONDONTWRITEBYTECODE=1 PYTHONPATH="$PWD/scripts" GIT_ALLOW_PROTOCOL=file
unset ORCA_AGENT_SESSION_ID ORCA_STRUCTURED_SESSION  # 합성 Stop을 일반 탭으로 처리
```

## F1~F4 재확인

| 이전 결함 | 실제 결과 | 판정 |
|---|---|---|
| F1 · 재발급 전후 티켓 혼동 | 같은 대상의 티켓을 diff 도중 바꾸면 종료 3, 가짜 deploy 0회. 이전 deploy가 실패를 반환하기 직전에 바꾸면 종료 5, 이전 티켓으로 가짜 deploy 1회. 새 티켓은 두 경우 모두 `used=0, locked=false`. | 해결. 소비와 실패 잠금 양쪽을 확인했다. |
| F2 · 혼합 diff 일부만 인식 | 정상 SQS 추가는 `ok`. 같은 입력에 미지원 제목 또는 미지원 변경 종류를 붙이면 각각 `unknown`. 이전 보고서의 삭제·교체·IAM 단독 입력은 `danger`, 미지원 단독 입력은 `unknown`. | 부분 해결. 검사기가 전체 입력을 분류하는지는 별개다(D1). |
| F3 · 명령 값과 자식 출력 저장 | 이전 보고서 시나리오 3의 질문은 `deny`, 실행기는 `blocked`/4. 합성 할당값은 holds·runs·원시 로그·보고 어디에도 없었다. 그러나 실패 테스트가 일반 문자열로 출력한 합성 표식은 원시 로그에 남았다. | 명령 할당값 재현은 해결. 자식 출력에는 한계가 남는다(D2). |
| F4 · JSON 공백에 따른 진전 횟수 차이 | 이전 보고서 시나리오 1을 재실행했다. 각 질문 사이에 같은 assistant 도구 호출 3건을 넣었을 때 compact·spaced 둘 다 `block → block → pass`, 여섯 번 모두 종료 0. | 해결. 공백과 무관하게 둘째 질문까지 재개하고 셋째에서 멈췄다. |

**재현 명령:** F3·F4의 원래 사례와 F2 단독 입력은 [이전 보고서](validation-s2s3.md)의 독립 시나리오 1~3 Python 블록을 새 HOME에서 차례로 실행했다. F1에서는 외부 명령 실행 함수만 대체해 재발급 타이밍을 고정했다. 상태 읽기·쓰기, 검사, 소비, 실패 처리는 실제 코드를 사용했다.

```sh
python3 - <<'PY'
import away, away_deploy as d, time, tempfile, pathlib, argparse
from unittest.mock import patch
p=pathlib.Path(tempfile.mkdtemp()).resolve()
(p/'CLAUDE.md').write_text('- **테스트**: 없음 (확인함)\n')
def issue():
    t=away.parse_ticket(str(p)+'::Demo',1)
    away.save_state(dict(id=t['id'],started=time.time(),until=time.time()+600,tickets=[t]))
for phase in ('diff','deploy'):
    issue(); calls=[]
    def fake(args,*a,**kw):
        cmd=args[2]; calls.append(cmd)
        if cmd==phase: issue()
        return (0,'Stack Demo\nResources\n[+] AWS::SQS::Queue Q Q1\n') if cmd=='diff' else (1,'fixture failure')
    with patch.object(d,'run_logged',fake):
        code=d.cmd_run(argparse.Namespace(stack='Demo',cwd=str(p),json=True))
    t=away.active()['tickets'][0]; print(phase, code, calls, t['used'], t['locked'])
PY
```

F2 혼합 입력과 F3 일반 출력 확인(실제 자격 증명 없이 잔존 여부만 출력):

```sh
python3 - <<'PY'
import away, away_deploy as d, json, pathlib, subprocess, tempfile, time
for suffix in ('', 'Strange Changes', '[~] Unexpected Demo'):
    print(d.inspect_diff('Stack Demo\nResources\n[+] AWS::SQS::Queue Q Q1\n'+suffix)[0])
p=pathlib.Path(tempfile.mkdtemp()).resolve()
(p/'CLAUDE.md').write_text('- **테스트**: `sh unit.sh`\n')
(p/'unit.sh').write_text('echo S5_STDOUT_SAMPLE\nexit 1\n')
t=away.parse_ticket(str(p)+'::Demo',1)
away.save_state(dict(id='round',started=time.time(),until=time.time()+600,tickets=[t]))
r=subprocess.run(['python3','scripts/away_deploy.py','run','--cwd',str(p),'--stack','Demo','--json'],text=True,capture_output=True)
print(r.returncode, 'S5_STDOUT_SAMPLE' in pathlib.Path(json.loads(r.stdout)['log']).read_text())
PY
```

## 앱 독립 시나리오

**1. 끄기 응답에 `ok:false`만 있고 오류 설명은 빠진 경우.** 버전이 다른 kit의 불완전한 오류 응답도 실패로 전달되어야 한다. 아래 가짜 kit를 실제 Swift 클라이언트로 호출하자 `off returned ok=false`가 예외 없이 반환됐다. `stop()`은 해제 필드만 검사하므로 이 응답에서 오류를 표시하지 않는다(D3). 실제 절전 방지 해제나 메뉴의 버튼 클릭은 이 시험에서 측정하지 않았다.

**2. 상태는 읽히는데 아침 보고만 깨진 경우.** 돌아온 사용자는 확인할 일이 없는 경우와 목록을 읽지 못한 경우를 구별해야 한다. 아래와 같이 대기 건수 1의 정상 상태와 깨진 보고 출력을 함께 제공했다. 클라이언트는 `bad_output`을 던졌으나 앱이 렌더링한 PNG에는 `꺼짐`, `돌아와서 볼 것 → 없음`이 표시됐고 오류 안내는 없었다(D4). 최초 조회 실패를 확인했으며 이전 목록이 이미 표시된 상태에서의 실패 화면은 미검증이다.

시나리오 1·2 재현 명령:

```sh
mkdir -p "$T/kit/scripts"
cat > "$T/kit/scripts/away.py" <<'PY'
import json,sys
cmd=sys.argv[1]
if cmd=='status':
    print(json.dumps(dict(ok=True,active=False,expired=False,remaining_seconds=0,caffeinate=dict(alive=False),power=dict(source='ac',lid='open'),queue_count=1)))
elif cmd=='report': print('incomplete')
elif cmd=='off': print(json.dumps(dict(ok=False,was_active=True,caffeinate_released=True)))
PY
cat > "$T/main.swift" <<'SWIFT'
import Foundation
let client = AwayClient(kit: CommandLine.arguments[1], python: "/usr/bin/python3")
do {print("off returned ok=\(try client.off().ok)")} catch {print(error)}
do {print(try client.report())} catch {print((error as? AwayFailure)?.error ?? "error")}
SWIFT
swiftc macos/Sources/AwayCore/*.swift "$T/main.swift" -o "$T/probe"
"$T/probe" "$T/kit"
AWAYBAR_KIT="$T/kit" macos/.build/debug/AwayBar --snapshot "$T/report.png"
```

**3. 다른 경로로 설치하는 동안 활성 모드와 기존 앱이 유지되는가.** 시험용 번들을 따로 설치할 때 상태 파일과 앱 프로세스는 영향 범위가 다르다. 임시 HOME에 유효한 회차를 둔 채 `b2b532c` 소스로 별도 번들을 설치했다. `pkill`은 인자만 기록했고 개인 서명 대신 ad-hoc 서명을 사용했다. 설치 종료 0, 번들 실행 파일 생성, 전후 `state.json` SHA-256 일치. 그러나 `pkill` 호출은 대상 경로와 무관한 `-x AwayBar`였다(D5). 실제 프로세스 종료 및 caffeinate 생존 여부는 시험하지 않았다.

```sh
# 위 F1 또는 F3 직후, 공통 격리 설정을 유지한다.
mkdir -p "$T/stage"
git archive b2b532c macos .claude-plugin/plugin.json | tar -x -C "$T/stage"
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "$T/pkill.calls"\n' > "$T/bin/pkill"
printf '#!/bin/sh\nexit 1\n' > "$T/bin/security"
chmod 700 "$T/bin/pkill" "$T/bin/security"
shasum -a 256 "$HOME/.config/37writes-kit/away/state.json" > "$T/before"
AWAYBAR_APP="$T/appbundle/AwayBar.app" sh "$T/stage/macos/install.sh"
shasum -a 256 -c "$T/before"; cat "$T/pkill.calls"
test -x "$T/appbundle/AwayBar.app/Contents/MacOS/AwayBar"
```

## 결함 목록

| 결함·심각도 | 위치와 영향 | 권고 |
|---|---|---|
| D1 · 높음 (F2 잔여) | `scripts/away_deploy.py:68`, `:98` — 정적 확인: 일부 제목·표식만 오류 후보로 분류한다. 분류되지 않은 줄이 남아도 인식한 추가·수정 건수가 있으면 전체 판정이 `ok`가 될 수 있다. 두 혼합 입력의 거절은 확인했지만, 실제 CDK에서 위험 변경이 통과한 일을 관측한 것은 아니다. | 지원하는 변경 영역의 문법이나 구조화된 변경 집합을 정의하고, 해석하지 못한 변경이 남으면 보류한다. 지원 버전의 비식별 출력으로 정상 변경도 확인한다. |
| D2 · 중간 (F3 잔여) | `scripts/away_deploy.py:58` — 하위 프로세스 출력 전체를 패턴 가림 후 저장한다. 일반 출력에 실린 값은 로그에 그대로 남을 수 있다. 합성 표식으로 확인했으며 실제 비밀값은 사용하지 않았다. | 기본 기록에는 단계·종료 코드만 남긴다. 상세 출력이 필요하면 별도 선택으로 두고 보존 기간을 정한다. |
| D3 · 중간 | `macos/Sources/AwayCore/AwayClient.swift:80`, `macos/Sources/AwayBar/Model.swift:133` — 실패 구조 전체의 디코딩이 실패하면 성공 타입으로 다시 읽어 명시적 `ok:false`를 반환한다. | 공통 `ok`를 먼저 확인하고 `false`이면 세부 필드 유무와 관계없이 오류로 처리한다. |
| D4 · 중간 | `macos/Sources/AwayBar/Model.swift:95`, `macos/Sources/AwayBar/PanelView.swift:188` — 보고 조회 실패를 버리고 미수신을 빈 목록으로 표시한다. | 조회 중·성공·실패를 구별한다. 실패 시 오류와 재시도를 표시하고 이전 목록을 유지한다면 조회 시각을 함께 표시한다. |
| D5 · 중간 | `macos/install.sh:38` — 다른 경로에 설치해도 기존 동명 앱까지 종료 대상으로 삼는다. 별도 시험 설치가 사용자의 메뉴 막대 앱을 닫을 수 있다. | 교체할 번들의 실행 경로와 일치하는 인스턴스만 종료하고, 새 경로 설치라면 종료를 생략한다. |

## 검증 한계

실제 AWS·CDK, 버전별 실제 diff, 실제 HOME의 상태·설치 앱, 전원·뚜껑 변화, 로그인 항목 등록, 장시간 상주는 검증하지 않았다. F1은 두 시점을 고정한 시험이며 가능한 모든 동시 실행 순서를 확인한 것은 아니다. 앱 화면 판정은 가짜 kit로 렌더링한 첫 조회 결과에 한정한다. 코드·시험 수정, 외부 push, 배포, 커밋 없이 이 보고서만 작성했다.

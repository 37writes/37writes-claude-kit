global.openai.gpt-6.2-astra

# S5 독립 검증 — 수정 후 재검증 필요

대상: `37writes/away-mode`, `90b6632...aa1fe5d`. 독립 검증자 Codex의 현재 세션 `turn_context.model`로 모델명을 확인했다. 기본 시험 293개는 통과했고 실기에서 절전 방지도 해제됐다. 그러나 guard가 반드시 제한 시간 안에 판정을 돌려준다고 볼 수 없고(F1), `off`가 성공을 보고한 뒤에도 모드가 실제로 켜진 경우를 확인했다(F2).

## 1. 시험 재실행

각 명령은 별도의 임시 HOME·TMPDIR, `PYTHONDONTWRITEBYTECODE=1`, `GIT_ALLOW_PROTOCOL=file`에서 실행했다. Git 시험은 임시 로컬 bare 저장소만 사용했다. stdout/stderr를 합쳐 줄 시작 `ok `·`FAIL `만 셌다.

| 명령 | 끝 코드 | ok | FAIL |
|---|---:|---:|---:|
| `sh scripts/test_guard.sh` | 0 | 92 | 0 |
| `sh scripts/test_away.sh` | 0 | 94 | 0 |
| `sh scripts/test_deploy_gate.sh` | 0 | 56 | 0 |
| `sh scripts/test_plans.sh` | 0 | 32 | 0 |
| `sh scripts/test_profile_check.sh` | 0 | 19 | 0 |
| `claude plugin validate .` (2.1.332) | 0 | 0 | 0 |

마지막 명령은 `ok`/`FAIL` 형식을 쓰지 않는다. 실제 최종 결과는 `Validation passed with warnings`. 루트 CLAUDE.md는 플러그인 컨텍스트에 로드되지 않는다는 경고가 있다. 별도 디렉터리 제출 진단에는 라이선스 누락(제출 거부 사유)과 아이콘 누락(경고)도 표시됐다. 이 진단은 기본 검증 끝 코드에 반영되지 않으며 이번 작업은 제출을 포함하지 않는다.

## 2. 변경 범위와 권한

`git diff --stat 90b6632...HEAD` → 12파일, +1065/−42. 구현·시험·사용 문서 8파일 외에는 버전 매니페스트 2개(둘 다 0.21.0 → 0.22.0만 변경), 기획서와 반박 보고서다. 모두 S1~S4 범위 안이다. `wc -l skills/harness/SKILL.md` → 157. 메뉴 막대 앱, 새 허용 목록, Stop·Write·Edit 훅은 없다.

`git diff 90b6632...HEAD | grep -nE 'AKIA|secret|api[_-]?key|BEGIN .*PRIVATE' | cut -d: -f1` → diff 176, 512, 514, 1073, 1080행. 설계 문서 1줄, 가림 정규식 2줄, 시험용 고정 표식 2줄이며 이 패턴에서 실제 자격 증명은 발견하지 않았다. 원문·값은 출력하지 않았다. 이 검색은 모든 종류의 자격 증명을 검출하는 검사가 아니다.

`git diff 90b6632...HEAD -- scripts/guard.py`에서 기존 사유는 제거하지 않고 `away_reasons`만 추가했다. 최종 함수가 반환하면 이유 없음만 무출력, 이유가 있으면 꺼짐·오류는 `ask`, 유효하면 `deny`다. `allow`를 반환하는 분기는 없다. 직접 비교한 입력과 끝 코드는 다음과 같다. 아래 재현 명령 모두 저장소 루트 기준이며, guard 입력은 셸로 실행하지 않는다.

```sh
# 별도 서브셸에서 시작. 이후 예제는 이 격리 환경에서만 실행한다.
T=$(mktemp -d); export HOME="$T" PYTHONDONTWRITEBYTECODE=1
A="$T/.config/37writes-kit/away"; mkdir -p "$A"; chmod 700 "$A"
aw() { sh scripts/py.sh scripts/away.py "$@"; }
state() { python3 -c 'import json,sys,time; t=int(time.time()); json.dump(dict(version=1,started=t,until=t+120),open(sys.argv[1],"w"))' "$A/state.json"; }
probe() { python3 -c 'import json,os,sys; print(json.dumps(dict(cwd=os.environ["HOME"],tool_input=dict(command=sys.argv[1]))))' "$1" | python3 scripts/guard.py; }
matrix() { for c in 'git clean -fd' 'git branch -D fixture' './deploy.sh' 'git push --force' 'git status'; do probe "$c"; done; }
matrix; state; matrix
```

| 입력(위 순서) | 꺼짐 | 켜짐 |
|---|---|---|
| 앞의 4개 | 모두 `ask`, exit 0 | 모두 `deny`, exit 0 |
| `git status` | 출력 없음, exit 0 | 출력 없음, exit 0 |

**F1 · 막아야 함 — 목록을 쓰는 동안에는 아직 거절 판정이 전달되지 않는다.** 읽기 전용 재확인: `rg -n 'queue_add|os.open\(QUEUE|os.write\(fd|kitlib.emit|"timeout": 15' scripts/away.py scripts/guard.py hooks/hooks.json`. 기대: 목록을 바로 기록할 수 없어도 15초 안에 `deny`. 실제 코드: 판정 JSON은 동기 `queue_add`가 끝난 뒤에만 출력한다. `O_APPEND`는 덧붙일 위치를 보장할 뿐 열기·쓰기 대기 시간을 제한하지 않는다. 일반 파일인지 확인하거나 비차단으로 여는 처리도 없다. 예외가 곧바로 발생하는 경우는 시험하지만 I/O가 반환하지 않으면 예외 처리까지 도달하지 않는다. 기존 `ask`에는 이 대기가 없었다. 호스트의 훅 시간 초과가 실행 허용으로 이어진다는 기획서의 실측을 고려하면 **명시적 allow 분기는 없어도 권한 비확장을 보증할 수 없다**. 판정을 목록 I/O 대기와 분리하고 지연된 기록에서도 제시간에 거절되는지를 회귀 검증할 필요가 있다. 이번 검증에서는 호스트 시간 초과나 실제 명령 실행을 유발하지 않았다.

전원 관련 실행 지점은 `rg -n 'pmset|sudo|caffeinate.*-i' scripts/away.py`로 확인했다. `pmset`은 `-g batt`, `-g assertions`만 호출한다. `sudo`, `disablesleep`, 화면을 켜 두는 `-d` 호출 없음. 배터리는 자식을 만들기 전에 exit 3 `on_battery`로 거부하며 가짜 배터리 시험이 통과했다. 배터리 실기는 하지 않았다. `hooks/hooks.json`의 SessionStart·UserPromptSubmit 모두 `away.py hook`이고, 안내 종료 시각은 상태에서 읽는다. README·harness에 동일 UID 한계와 거절 뒤 재시도 금지가 있다. CLI 일반 출력에는 뚜껑 경고가 있다.

## 3. 직접 고른 경계 시나리오

**F2 · 막아야 함 — 모드를 끄지 못해도 메뉴 앱에는 성공으로 표시된다.** 선택 이유: 메뉴 앱이 `off`의 끝 코드와 `ok`를 믿을 수 있어야 한다. 위 `matrix; state; matrix` 직후, 격리 폴더 안의 실제 프로세스 없는 상태로 다음을 실행한다.

```sh
touch "$A/state.lock"; chmod 500 "$A"
aw off --json; echo "$?"; aw status --json; test -e "$A/state.json"; echo "$?"
chmod 700 "$A"
```

기대: 상태를 지울 수 없으면 실패 JSON·비영 끝 코드, 성공이면 후속 status는 비활성. 실제: `off`는 exit 0, `ok:true, was_active:true, caffeinate_released:true, queue_count:4`; 직후 `status`는 exit 0, `active:true, expired:false`, 상태 파일 존재 확인도 exit 0. `remove_state()`가 `FileNotFoundError` 이외의 `OSError`까지 무시한다. macOS 일반 계정·폴더 권한으로 확인했고 ACL·네트워크 볼륨은 미검증이다.

**F3 · 고치면 좋음 — 상태 파일 모드가 기획서의 0600과 다르다.** 선택 이유: 동일 계정 단위 기록의 권한이 사용자 기본 umask에 달려 있는지 확인하기 위해서다. 새 임시 HOME에서 `umask`(022) → 아래 4절의 실제 `on` → `stat -f '%Lp' "$A/state.json"`에 해당하는 Python `stat.S_IMODE` 조회. 기대 0600, 실제 0644. `save_state()`가 기본 생성 모드로 임시 파일을 열어 교체한다. 새 부모 폴더는 0700이라 이 관찰만으로 타 사용자에게 내용이 노출됐다고 볼 수는 없다. ACL·다른 OS는 미검증이다.

**F4 · 막아야 함 — 공백이 포함된 옵션 값의 가림을 보장하지 않는다(정적 검토).** 선택 이유: 일반적인 CLI 인자는 공백을 포함한 문자열 하나일 수 있고, 아침 목록은 모드를 끈 뒤에도 남는다. 읽기 전용 재확인: `sed -n '/^MASKS = /,/^def queue_add/p' scripts/away.py`. 기대: 문서가 가린다고 명시한 비밀번호류 옵션의 값 전체가 저장 전에 가려짐. 실제: 옵션 전용 정규식이 값의 첫 공백 전까지만 소비하고, 뒤의 별도 대입식 규칙은 공백으로 전달한 옵션 값을 처리하지 않는다. 부분 가림만 된 결과가 `queue_add()`의 `command`로 들어갈 수 있다. 분류가 확실하지 않은 값은 명령 미리보기에서 생략하는 쪽이 안전하다. 실제 비밀번호를 사용하거나 누출 예제를 실행하지 않았으며 모든 셸 문법의 가림 여부도 검증하지 않았다.

## 4. 실제 Mac: 시작·조회·해제

다른 시험과 겹치지 않는 새 `mktemp -d` HOME에서 다음 순서로 확인했다. 테스트 대역 없이 OS의 `caffeinate`, `pmset`, `ps`를 썼다. 아래는 같은 확인을 반복하는 셸 명령이다.

```sh
T=$(mktemp -d); export HOME="$T" PYTHONDONTWRITEBYTECODE=1
aw() { sh scripts/py.sh scripts/away.py "$@"; }
on=$(aw on --for 2m --json); pid=$(printf '%s' "$on" | python3 -c 'import json,sys; print(json.load(sys.stdin)["caffeinate"]["pid"])')
ps -p "$pid" -o args=; pmset -g assertions | grep -Fc "pid $pid("
aw status --json; aw off --json
pmset -g assertions | grep -Fc "pid $pid("
# 각 임시 HOME 사용이 끝나면 해당 mktemp 폴더만 정리한다.
```

실제 시작 2026-11-26 11:11:51 KST, 종료 예정 11:13:51. `on` exit 0, `active:true`, AC/open, `remaining_seconds:119`, `queue_count:0`, `warnings:[]`. 반환 PID **9294**의 실측 인자는 `caffeinate -i -s -t 119`, 해당 assertion **2개**. `status` exit 0, 동일 PID·종료 시각, `alive:true`. `off` exit 0, `ok:true, was_active:true, caffeinate_released:true, queue_count:0`. 직후 `pmset -g assertions` 자체 exit 0, **PID 9294 일치 0개**. 다른 PID에 신호를 보내지 않았다. 장시간 유휴 절전·뚜껑 동작, 자연 만료, 대화형 호스트 안에서 다음 일까지 이어지는 동작은 이 실기 시험의 범위가 아니다.

최종 확인: 모든 시험용 임시 폴더를 정리한 뒤 원래 HOME의 `ls -d ~/.config/37writes-kit/away/`는 exit 1(경로 없음). `git status --short --untracked-files=all`은 이 보고서 한 파일만 표시했다. 구현 수정·커밋·외부 push·배포는 하지 않았다.

## 재검증

`60b4b04`에서 **macOS의 원래 F1~F4 재현 조건은 모두 통과**했다. 일반 명령 판정에서 권한이 넓어진 사례는 없었다. 다만 메뉴 앱용 `off` 실패 계약의 설명은 실제와 다르고(F5), F1의 기록 시간 제한은 Windows까지 보장하지 않는다(F6).

| 재실행 명령 | 끝 코드 | ok | FAIL |
|---|---:|---:|---:|
| `sh scripts/test_guard.sh` | 0 | 97 | 0 |
| `sh scripts/test_away.sh` | 0 | 103 | 0 |
| `sh scripts/test_deploy_gate.sh` | 0 | 56 | 0 |
| `sh scripts/test_plans.sh` | 0 | 32 | 0 |
| `sh scripts/test_profile_check.sh` | 0 | 19 | 0 |
| `claude plugin validate .` | 0 | 0 | 0 |

셸 시험 합계 307개. 이전과 같이 각 실행의 HOME·TMPDIR을 격리했다. 플러그인 검증은 `ok`/`FAIL` 형식이 아니며 최종 진단은 `Validation passed with warnings`였다. 루트 CLAUDE.md 경고와 디렉터리 제출용 라이선스·아이콘 진단은 그대로다.

직접 시험은 위 2절의 `aw`, `probe`와 새 `mktemp -d` HOME에서 진행했다. 모든 `probe`는 명령 문자열을 JSON으로 전달해 `python3 scripts/guard.py`만 실행했다. 실기 `on --for 2m --json`이 반환한 PID는 25097이었다.

| 항목 | 재현 조건 | 실제 결과 |
|---|---|---|
| F1 기록 지연 | 켜진 상태에서 `mkfifo "$A/queue.jsonl"` 후 `probe 'git branch -D fixture'`의 벽시계 시간·판정을 측정. 이후 시험용 FIFO를 치우고 정상 파일로 검사 | 읽는 쪽 없이 **0.178초, exit 0, `deny`**, 사유에 “기록에 실패”. 훅 제한 15초 이내. 별도로 재실행한 `test_guard.sh`에서 지연 대역을 쓴 ≤10초 거절 시험도 통과했다. |
| F2 삭제 실패 | `chmod 500 "$A"` → `aw off --json` → `aw status --json` → `chmod 700 "$A"` → `aw off --json` | 첫 `off`는 **exit 1, `ok:false, error:state_not_removed`**. 직후 `status`는 `active:true`, **`caffeinate.alive:false`**였다. 해제 시도 중 자식은 먼저 끝났으므로 파일 권한을 되돌리기 전에는 모드와 절전 방지 상태가 달랐다. 재시도는 exit 0, `was_active:true`, `caffeinate_released:true`. `pmset -g assertions`에서 해당 PID 일치 0개. |
| F3 상태 권한 | `umask 022`로 `aw on --for 2m --json` 직후 `stat -f %Lp "$A/state.json"` | **600**. 최초 생성한 상태 파일이 설계와 일치했다. |
| F4 따옴표 안 공백 | `probe`에 `git branch -D fixture`와 큰따옴표로 감싼 두 단어 `--password` 값, 작은따옴표로 감싼 두 단어 `--credential=` 값을 함께 전달. 비밀값 대신 `S5_PART_` 접두의 고정 표식을 사용 | exit 0 `deny`. 큐 파일과 `aw report --json` 모두 표식 0개, 보고서 1건. 미리보기는 `git branch -D fixture --password *** --credential ***`. 단순 인용 옵션에서 확인한 결과이며 임의 셸 문법 전체를 보증하지 않는다. |

동일한 `git branch -D fixture` 입력은 꺼짐 `ask` → 켜짐(목록 FIFO여도) `deny` → 정상 `off` 후 `ask`, `git status`는 꺼짐·켜짐 모두 exit 0·무출력이었다. `git diff aa1fe5d...HEAD -- scripts/guard.py`에는 기존 판정 사유 제거 또는 `allow` 반환 추가가 없다.

**F5 · 고치면 좋음 — `off` 실패 JSON 모양과 모드 상태 설명이 README와 다르다.** F2 조건에서 `aw off --json`의 실제 키는 `error,message,ok`다. README의 `off` 행은 실패 코드까지 적고도 JSON 칸에는 성공용 키만 제시한다. 또 “모드는 켜진 채”라고 단정하지만 이미 만료된 상태 파일도 삭제에 실패할 수 있다. 위 2절의 격리 HOME·함수에서 `state.lock`이 이미 있는 상태로 다음을 확인했다.

```sh
python3 -c 'import json,sys,time;t=int(time.time());json.dump(dict(started=t-120,until=t-60),open(sys.argv[1],"w"))' "$A/state.json"
chmod 500 "$A"; aw off --json; aw status --json; chmod 700 "$A"
```

실제: `off`는 exit 1 `state_not_removed`, 뒤의 `status`는 exit 0 `active:false, expired:true`. 기대: 실패는 `{ok:false,error,message}`이고 상태 **파일**이 남는다는 사실을 문서화하며, 활성·절전 상태는 `status`로 확인하도록 안내한다. `remove_state()`의 오류 메시지도 활성 상태를 단정하지 않는 편이 정확하다.

**F6 · 막아야 함(Windows까지 동일한 권한 비확장을 보장하려면) — F1 시간 제한의 플랫폼 공백.** 읽기 전용 확인: `rg -n 'SIGALRM|signal.alarm|away.queue_add' scripts/guard.py` 및 `rg -n '윈도우|다른 OS' README.md`. 기대: 지원 플랫폼에서 목록 기록 지연이 `deny` 전달을 막지 않는다. 실제: Windows Python에는 `SIGALRM`이 없어 4초 알람을 설치하지 않고 동기 `queue_add()`를 호출한다. 이 분기에는 별도 기록 제한 시간이 없으며 최종 `deny`는 기록 호출이 끝난 뒤 전송된다. 명시적인 `allow`가 추가된 것은 아니며, **Mac에서 고친 F1의 일부가 Windows에 남은 것**이다. Windows 실기나 호스트 시간 초과 후 명령 실행은 시험하지 않았다. 지원 범위를 유지하려면 기록 실패·지연 시에도 판정을 먼저 보장하는 대안이 필요하다.

검증 종료: `git status --short`에는 이 보고서 수정만 있었고 실제 HOME의 `ls -d ~/.config/37writes-kit/away/`는 exit 1이었다. 임시 폴더는 정리했고 커밋·외부 push는 하지 않았다.

## 재검증 2

대상 `8267823` (`git diff 60b4b04...HEAD`). **F5·F6의 원래 재현 조건을 통과했다.** `off`의 실패 계약이 실제 JSON·상태와 일치했고, 기록 함수가 60초간 돌아오지 않도록 해도 guard는 SIGALRM 없이 4.084초 만에 거절 판정을 내고 종료했다.

**F5 — `off` 실패 계약.** 새 임시 HOME에 `state.lock`과 상태 파일을 둔 뒤, 위 F5 재현의 `chmod 500 "$A"; aw off --json; aw status --json; chmod 700 "$A"`를 만료·활성 상태에서 각각 실행했다. 둘 다 `off`는 exit 1, JSON 키는 `ok,error,message`, 값은 `ok:false`, `error:state_not_removed`였다. 실제 `message`는 “상태 파일을 지우지 못했습니다 (지금 상태는 away.py status로 확인)” 뒤에 OS의 권한 오류가 붙었다. 이어서 조회한 `active/expired` 값은 각각 `false/true`, `true/false`였다. README의 `off` 행은 실패 JSON과 남아 있는 **파일**을 명시하고 현재 상태 조회를 안내하므로 두 경우 모두 맞는다.

**F6 — 판정 시점뿐 아니라 guard 프로세스 종료까지 확인.** 코드에서 기록은 `Thread(..., daemon=True)` 안에서 수행하며 메인 스레드는 `join(4)` 후 `deny`를 반환한다. 기록의 성공 여부는 이유 문구만 바꾼다. 다음은 사용한 독립 대역의 핵심이다. 저장소 파일은 수정하지 않았고, 명령처럼 보이는 문자열은 셸에서 실행하지 않았다.

```python
# 격리 HOME에 유효한 상태를 둔다. python3 -c 자식에 아래 코드를 전달하고
# stdin에는 {"tool_input":{"command":"git branch -D fixture"},"cwd":<임시 HOME>}을 넣는다.
import runpy, signal, sys, threading
if hasattr(signal, 'SIGALRM'):
    del signal.SIGALRM
sys.path.insert(0, 'scripts')
import away
def slow(*args):
    print('writer-started', file=sys.stderr, flush=True)
    threading.Event().wait(60)
away.queue_add = slow
runpy.run_path('scripts/guard.py', run_name='__main__')
```

부모에서 `Popen.communicate(..., timeout=15)`가 반환할 때까지 단조시계로 쟀다. **기록 대역 진입 확인, stdout JSON 1건 `deny` + 기록 실패 안내, 전체 4.084초, exit 0**. 데몬 스레드가 판정 뒤 자식 프로세스를 붙잡지 않았다. 대조군에서 같은 입력은 꺼짐 `ask`(0.056초), 정상 기록 시 `deny`(0.179초)였다. 켜진 상태의 `git status`는 무출력(0.044초)이었고 총 기록은 정상 거절 1건뿐이었다. 이 변경에서 `ask`가 `allow`나 무출력으로 바뀌는 분기는 발견하지 않았다. 이는 Mac에서 신호 기능을 제거한 동일 코드 경로의 결과이며, Windows 네이티브 실행이나 모든 종류의 OS 정지를 검증한 것은 아니다.

**실제 Mac 절전 방지.** 별도 `mktemp -d` HOME에서 `sh scripts/py.sh scripts/away.py on --for 2m --json` → 반환 PID로 `ps -p "$pid" -o args=`와 `pmset -g assertions` 확인 → `sh scripts/py.sh scripts/away.py off --json` → `pmset -g assertions` 재확인. `on`은 exit 0, AC/open, PID **57444**, `alive:true`, 인자 `caffeinate -i -s -t 119`. `off`는 exit 0, `was_active:true`, `caffeinate_released:true`, `queue_count:0`이었고 이 PID의 assertion은 **2개 → 0개**였다. 두 `pmset` 조회 모두 exit 0이었다.

**회귀 시험.** 실행마다 새 임시 HOME·TMPDIR을 사용했다. `test_away.sh` 5회는 서로 겹치지 않게 연속 실행했다.

| 명령 | 실행 횟수 | 끝 코드 | ok / FAIL |
|---|---:|---|---|
| `sh scripts/test_guard.sh` | 1 | 0 | 97 / 0 |
| `sh scripts/test_away.sh` | 5 | 0, 0, 0, 0, 0 | **매회 103 / 0** |
| `sh scripts/test_deploy_gate.sh` | 1 | 0 | 56 / 0 |
| `sh scripts/test_plans.sh` | 1 | 0 | 32 / 0 |
| `sh scripts/test_profile_check.sh` | 1 | 0 | 19 / 0 |
| `claude plugin validate .` | 1 | 0 | `ok`/`FAIL` 형식 아님. `Validation passed with warnings` |

셸 시험은 중복 없는 한 세트 307건, 반복 포함 **719건 통과, 실패 0건**. 5회 내 간헐 실패는 관찰되지 않았다. 플러그인 검증의 CLAUDE.md 경고와 디렉터리 제출용 라이선스·아이콘 진단은 이전과 같았다. 이번 범위에서 남은 결함은 발견하지 않았다. 종료 시 `git diff --check` 통과, `git status --short`에는 보고서 한 파일만 표시됐고 실제 HOME의 away 경로 조회는 exit 1(없음)이었다.

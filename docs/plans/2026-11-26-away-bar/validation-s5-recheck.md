실행 모델: Codex `global.openai.gpt-6.2-astra`

# S5 수정 재검증 — `b637de4`

**지정 시험 113건 통과·0건 실패. D4·D5는 원래 재현에서 해결됐고, D1·D3는 일부 문제가 남았다.** D1은 최상위 미지원 줄을 거절하지만 하위 변경 전체를 해석하지 않는다. D3는 설명이 없는 실패를 거절하지만, 설명의 자료형이 다르면 실패를 정상 반환한다. D2는 유지 결정에 따라 재판정하지 않았다.

| 재실행 명령 | 통과 | 실패 | 종료 코드 |
|---|---:|---:|---:|
| `sh scripts/test_away_deploy.sh` | 102 | 0 | 0 |
| `(cd macos && swift test)` | 11 | 0 | 0 |

셸은 `^ok `·`^FAIL`, Swift는 XCTest 최종 집계를 사용했다. 아래 독립 사례는 합계에 넣지 않았다. 기준 SHA는 `b637de489019adb90f8ad960f1c84cd279c87e13`이다.

| 결함 | 해결 여부 | 실제 결과 |
|---|---|---|
| D1 · 혼합 diff | **부분 해결** (잔여 높음, 정적 확인) | 원래 정상/미지원 제목/미지원 종류는 `ok / unknown / unknown`. 추가한 삭제/미지원 최상위 텍스트/정상 속성·출력은 `danger / unknown / ok`. 하위 줄에 대해서는 문법 확인이 없다. 실제 CDK 위험 변경이 통과한 일을 관찰한 것은 아니다. |
| D3 · `ok:false` 오인 | **부분 해결** (잔여 중간, 실행 확인) | 오류 세부 필드가 없으면 `AwayFailure(error: "failed")`. 같은 응답에 숫자형 `message`를 넣으면 예외 없이 `off returned ok=false`. |
| D4 · 보고 실패를 빈 목록으로 표시 | **해결** | 정상 상태·깨진 보고를 함께 주자 클라이언트는 `bad_output`, 실제 앱 PNG의 ‘돌아와서 볼 것’에는 ‘목록을 읽지 못했습니다’와 원인이 표시됐다. 그 영역에 ‘없음’은 표시되지 않았다. |
| D5 · 설치 대상 밖 앱 종료 | **해결** | 서로 다른 절대 경로에서 같은 이름의 프로세스 두 개를 실행했다. 설치 대상만 종료되고 다른 경로의 프로세스는 살아 있었다. 설치 종료 0, 번들 실행 파일 생성, 활성 `state.json`의 설치 전후 SHA-256 일치. |

## 재현 환경

저장소 루트에서 [이전 보고서](validation-s4.md)의 ‘재실행’ 격리 설정을 적용한다. macOS `ps`의 정규 경로와 비교하기 위해 `T`는 `T=$(mktemp -d /private/tmp/away-s5r.XXXXXXXX); export T`로 생성했다. 임시 HOME·TMPDIR, 가짜 전원·클라우드 명령이 앞에 있는 PATH·AWAYBAR_PATH로 시험했다.

## D1: 정상 변경에 다른 줄을 섞은 경우

```sh
python3 - <<'PY'
from away_deploy import inspect_diff
base='Stack Demo\nResources\n[+] AWS::SQS::Queue Q Q1\n'
for case,suffix in [
    ('원래-정상',''), ('원래-제목','Strange Changes'), ('원래-종류','[~] Unexpected Demo'),
    ('추가-삭제','[-] AWS::SNS::Topic Archived TopicOld'),
    ('추가-미지원','metadata-schema: revision 2'),
    ('추가-정상','[~] AWS::SNS::Topic News NewsA\n └─ [~] DisplayName\nOutputs\n[+] Output TopicName TopicName: {"Value":"News"}\n✨  Number of stacks with differences: 1')]:
    print(case,inspect_diff(base+suffix)[0])
PY
```

삭제가 정상 추가와 섞이면 `danger`, 출처를 알 수 없는 최상위 줄이 섞이면 `unknown`, 정상 속성·출력·요약만 섞이면 `ok`를 기대했다. 세 결과 모두 기대와 일치했다.

**잔여 결함(높음):** `scripts/away_deploy.py:77`은 인식된 변경 아래 들여 쓴 줄을 개별 분류하지 않는다. 알려진 위험 표식은 전체 텍스트에서 별도로 찾지만 새 하위 형식을 이해했는지와 관계없이 전체 변경을 허용할 가능성이 남는다. 지원하는 속성 문법이나 구조화된 변경 목록으로 검증하고 해석하지 못한 변경은 보류하는 것을 권한다. 실제 CDK 버전별 호환성은 시험하지 않았다.

## D3·D4: 오류 응답과 패널

`swift test` 뒤에 [이전 보고서](validation-s4.md)의 **시나리오 1·2 재현 명령** 블록(가짜 kit와 `main.swift` 작성, `swiftc`, `probe`, `AwayBar --snapshot`)을 그대로 실행했다. 원래 `off` 응답은 종료 코드 0이지만 `ok:false`였고, 이제 ‘away.py가 실패를 알렸습니다 (끝 코드 0)’ 예외가 났다. `report`가 깨진 JSON일 때는 생성된 PNG를 직접 읽어 D4의 결과를 확인했다. 이전 목록이 이미 표시된 상태의 후속 조회 실패는 미검증이다.

추가로 오류 설명만 숫자형으로 바꿔 확인했다.

```sh
mkdir -p "$T/types/scripts"
cat > "$T/types/scripts/away.py" <<'PY'
import json
print(json.dumps(dict(ok=False, message=17, was_active=True, caffeinate_released=True)))
PY
"$T/probe" "$T/types"
```

**잔여 결함(중간):** `off returned ok=false`가 출력됐다. `macos/Sources/AwayCore/AwayClient.swift:83`은 `ok`, `error`, `message`를 한 번에 디코딩한다. 선택 필드가 문자열이 아니면 첫 검사 자체가 실패하고 `:86`의 성공 타입으로 넘어간다. `ok`만 먼저 읽어 `true`일 때만 성공 타입으로 진행하고, `false`이면 세부 필드를 읽지 못해도 일반 오류를 반환하는 것을 권한다. 현재 정상 kit가 숫자형 설명을 보낸다는 뜻은 아니다.

## D5: 대상 프로세스만 종료하는가

원래 설치 시험의 상태 해시 비교와 임시 번들을 유지하고 프로세스 선택도 확인했다. `pgrep` 대역은 시험이 만든 두 PID만 돌려주며 경로 확인(`ps`)과 종료는 실제 명령이다. 개인 서명 대신 ad-hoc 서명을 사용했다.

```sh
(
set -eu
mkdir -p "$T/stage"
git archive b637de4 macos .claude-plugin/plugin.json | tar -x -C "$T/stage"
printf '#!/bin/sh\nexit 97\n' > "$T/bin/security"; chmod 700 "$T/bin/security"
printf '#include <unistd.h>\nint main(void){sleep(180);return 0;}\n' > "$T/sleeper.c"
cc "$T/sleeper.c" -o "$T/sleeper"
export AWAYBAR_APP="$T/one/AwayBar.app"
other="$T/two/AwayBar.app"
for app in "$AWAYBAR_APP" "$other"; do
  mkdir -p "$app/Contents/MacOS"; cp "$T/sleeper" "$app/Contents/MacOS/AwayBar"
done
"$AWAYBAR_APP/Contents/MacOS/AwayBar" & a=$!
"$other/Contents/MacOS/AwayBar" & b=$!
trap 'kill "$a" "$b" 2>/dev/null || :' EXIT
printf '%s\n' "$a" "$b" > "$T/owned"
printf '#!/bin/sh\n[ "$*" = "-x AwayBar" ] && cat "$T/owned"\n' > "$T/bin/pgrep"
chmod 700 "$T/bin/pgrep"
python3 - <<'PY'
import away,time
away.save_state(dict(id='review',started=time.time(),until=time.time()+1800,tickets=[]))
PY
shasum -a 256 "$HOME/.config/37writes-kit/away/state.json" > "$T/before"
sh "$T/stage/macos/install.sh"
if kill -0 "$a" 2>/dev/null; then echo target=alive; else echo target=stopped; fi
if kill -0 "$b" 2>/dev/null; then echo other=alive; else echo other=stopped; fi
shasum -a 256 -c "$T/before"
test -x "$AWAYBAR_APP/Contents/MacOS/AwayBar" && echo bundle=ok
)
```

결과는 `target=stopped`, `other=alive`, `state.json: OK`, `bundle=ok`였다. 실제 사용자의 앱·caffeinate는 종료하지 않았다. 심볼릭 링크나 상대 경로의 설치 대상, 실제 전원·로그인 변화·배포는 검증 범위 밖이다.

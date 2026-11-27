#!/bin/sh
# 자리 비움 모드(away.py) 테스트: sh scripts/test_away.sh
# HOME 격리. pmset·ioreg·caffeinate는 PATH 앞의 가짜 명령이라 실제 전원 설정을 건드리지 않는다.
# 메뉴 막대 앱이 부를 계약(끝 코드, --json 모양)을 여기서 고정한다.
S=$(cd "$(dirname "$0")" && pwd)
T=$(cd "$(mktemp -d)" && pwd -P)
export HOME="$T/home" FAKE="$T/fake"
# Orca 워커 탭·Claude 세션 안에서 돌려도 결과가 같게 (워커 환경이면 Stop 재개 시험이 통과로 빠진다)
unset ORCA_STRUCTURED_SESSION ORCA_AGENT_SESSION_ID CLAUDE_PID
mkdir -p "$HOME" "$FAKE" "$T/bin"
A="$HOME/.config/37writes-kit/away"
cleanup() { for p in $(cat "$FAKE/pids" 2>/dev/null); do kill "$p" 2>/dev/null; done; rm -rf "$T"; }
trap cleanup EXIT
fail=0
ok() { echo "ok   $1"; }
no() { echo "FAIL $1"; [ -n "$2" ] && echo "     $2"; fail=1; }

cat > "$T/bin/pmset" <<'EOF'
#!/bin/sh
case "$2" in
  batt) case "$(cat "$FAKE/batt")" in
      ac) echo "Now drawing from 'AC Power'" ;;
      battery) echo "Now drawing from 'Battery Power'" ;;
      *) exit 1 ;;
    esac ;;
  assertions) [ -f "$FAKE/assert_fail" ] && exit 1
    for p in $(cat "$FAKE/pids" 2>/dev/null); do
      kill -0 "$p" 2>/dev/null && echo "   pid $p(caffeinate): [0x1] 00:00:01 PreventUserIdleSystemSleep"
    done ;;
esac
exit 0
EOF
cat > "$T/bin/ioreg" <<'EOF'
#!/bin/sh
case "$(cat "$FAKE/lid")" in
  open) echo '  |   "AppleClamshellState" = No' ;;
  closed) echo '  |   "AppleClamshellState" = Yes' ;;
esac
EOF
cat > "$T/bin/caffeinate" <<'EOF'
#!/bin/sh
[ -f "$FAKE/caff_fail" ] && exit 1
echo "$$" >> "$FAKE/pids"
echo "$*" >> "$FAKE/args"
trap 'kill $c 2>/dev/null; exit 0' TERM
sleep 600 & c=$!
wait
EOF
chmod +x "$T/bin/"*
export PATH="$T/bin:$PATH"
# 새로 만든 실행 파일의 첫 실행은 macOS가 느리게 띄울 수 있다 (0.3초 넘게 걸리면 "바로 끝남" 시험이 흔들린다). 미리 한 번씩 실행해 둔다.
touch "$FAKE/caff_fail"; caffeinate; pmset -g batt >/dev/null 2>&1; ioreg >/dev/null 2>&1; rm -f "$FAKE/caff_fail"

aw() { sh "$S/py.sh" "$S/away.py" "$@"; }
# j <JSON> <파이썬 식(d)>: 참이면 성공
j() { python3 -c 'import json,sys
d = json.loads(sys.argv[1])
raise SystemExit(0 if eval(sys.argv[2]) else 1)' "$1" "$2" 2>/dev/null; }
expect() {  # expect <설명> <JSON> <식>
  if j "$2" "$3"; then ok "$1"; else no "$1" "$2"; fi
}
code() {  # code <설명> <기대 끝 코드> <명령...>: stdout은 OUT에
  d=$1; want=$2; shift 2
  OUT=$("$@" 2>"$T/err"); got=$?
  if [ "$got" = "$want" ]; then ok "$d (끝 코드 $want)"; else no "$d: 끝 코드 want=$want got=$got" "$OUT $(cat "$T/err")"; fi
}
alive() { n=0; for p in $(cat "$FAKE/pids" 2>/dev/null); do kill -0 "$p" 2>/dev/null && n=$((n + 1)); done; echo $n; }
reset() { for p in $(cat "$FAKE/pids" 2>/dev/null); do kill "$p" 2>/dev/null; done; rm -rf "$A" "$FAKE"/*; echo ac > "$FAKE/batt"; echo open > "$FAKE/lid"; }
reset

# ── 인자 오류 (2) ──
code "끝나는 시각 없음" 2 aw on
[ -z "$OUT" ] && grep -q "끝나는 시각" "$T/err" && ok "안내는 stderr, stdout은 비어 있음" || no "끝 시각 없음 안내"
code "끝나는 시각 없음 --json" 2 aw on --json
expect "--json 오류는 stdout에 JSON 하나 (no_until)" "$OUT" 'd == {"ok": False, "error": "no_until", "message": d["message"]}'
code "12시간 초과" 2 aw on --for 13h --json
expect "too_long" "$OUT" 'd["error"] == "too_long"'
code "12시간 1분 초과" 2 aw on --for 12h1m
code "잘못된 시각" 2 aw on --until 25:00 --json
expect "bad_time" "$OUT" 'd["error"] == "bad_time"'
code "잘못된 기간" 2 aw on --for abc
code "0분" 2 aw on --for 0m
code "명령 없음" 2 aw
code "모르는 명령 --json" 2 aw nope --json
expect "usage 오류도 JSON" "$OUT" 'd["ok"] is False and d["error"] == "usage"'
[ ! -e "$A/state.json" ] && [ "$(alive)" = 0 ] && ok "인자 오류에서는 상태·caffeinate 없음" || no "인자 오류 뒤 상태가 남음"

if [ "$(uname)" != Darwin ]; then
  code "macOS가 아니면 전원 없이 켜짐" 0 aw on --for 1h --json
  expect "경고에 절전 방지 건너뜀" "$OUT" 'd["active"] and d["caffeinate"]["pid"] is None and d["warnings"]'
  code "off" 0 aw off --json
  echo "(macOS가 아니라 전원 시험은 건너뜀)"; exit $fail
fi

# ── 시작 점검 거부 (3) ──
echo battery > "$FAKE/batt"
code "배터리면 시작 거부" 3 aw on --for 1h --json
expect "on_battery" "$OUT" 'd["ok"] is False and d["error"] == "on_battery"'
echo unknown > "$FAKE/batt"
code "전원을 읽지 못하면 시작 거부" 3 aw on --for 1h --json
expect "power_unknown" "$OUT" 'd["error"] == "power_unknown"'
echo ac > "$FAKE/batt"; echo closed > "$FAKE/lid"
code "뚜껑 닫힘이면 시작 거부" 3 aw on --for 1h --json
expect "lid_closed" "$OUT" 'd["error"] == "lid_closed"'
[ ! -e "$A/state.json" ] && [ "$(alive)" = 0 ] && ok "거부되면 상태·caffeinate 없음" || no "거부 뒤 상태가 남음"
echo none > "$FAKE/lid"
code "뚜껑 정보가 없는 Mac(데스크톱)은 켜짐" 0 aw on --for 1h --json
expect "lid unknown" "$OUT" 'd["active"] and d["power"]["lid"] == "unknown"'
aw off >/dev/null
reset

# ── 절전 방지 시작 실패 (4) ──
touch "$FAKE/caff_fail"
code "caffeinate 실패면 켜지 않음" 4 aw on --for 1h --json
expect "caffeinate_failed" "$OUT" 'd["error"] == "caffeinate_failed"'
[ ! -e "$A/state.json" ] && ok "실패 뒤 상태 없음" || no "caffeinate 실패인데 상태가 생김"
reset

# ── on → status → off ──
KEYS='{"ok","active","expired","until","until_epoch","remaining_seconds","started","caffeinate","power","queue_count","checks","holds_count","sessions","tickets","ticket_candidates","mode","stale_sessions"}'
code "on --for 2h" 0 aw on --for 2h --json
expect "on JSON: status 키 + warnings" "$OUT" "set(d) == $KEYS | {'warnings'}"
expect "on: 켜짐, 남은 초 약 7200, 기본 모드 away" "$OUT" 'd["ok"] is True and d["active"] is True and d["mode"] == "away" and d["stale_sessions"] == [] and d["expired"] is False and 7100 < d["remaining_seconds"] <= 7200'
expect "on: caffeinate 살아 있음" "$OUT" 'type(d["caffeinate"]["pid"]) is int and d["caffeinate"]["alive"] is True'
grep -q -- "-i -s -t 7[12][0-9][0-9]" "$FAKE/args" && ! grep -q -- "-d" "$FAKE/args" && ok "caffeinate -i -s -t <남은 초> (-d 없음)" || no "caffeinate 인자" "$(cat "$FAKE/args")"
code "status --json" 0 aw status --json
expect "status 키 고정" "$OUT" "set(d) == $KEYS"
expect "status 값·타입" "$OUT" 'd["active"] is True and type(d["until"]) is str and "T" in d["until"] and d["until"][-6] in "+-" and type(d["until_epoch"]) is int and type(d["started"]) is str and d["power"] == {"source": "ac", "lid": "open"} and d["queue_count"] == 0 and {c["name"] for c in d["checks"]} >= {"power", "lid"}'
aw status | grep -q "켜짐" && ok "status 텍스트" || no "status 텍스트"
aw on --for 1h | grep -q "뚜껑을 닫으면 잠듭니다" && ok "켤 때 뚜껑 안내 한 줄" || no "뚜껑 안내"
[ "$(alive)" = 1 ] && ok "다시 켜면 caffeinate는 하나로 교체" || no "교체 뒤 caffeinate 수: $(alive)"
code "off" 0 aw off --json
expect "off JSON" "$OUT" 'd == {"ok": True, "was_active": True, "mode": "away", "caffeinate_released": True, "queue_count": 0}'
[ "$(alive)" = 0 ] && [ ! -e "$A/state.json" ] && ok "off 뒤 caffeinate 종료·상태 삭제" || no "off 뒤 정리 안 됨 (alive=$(alive))"
code "꺼진 상태의 status" 0 aw status --json
expect "꺼짐: 시각은 null, 남은 초 0" "$OUT" 'd["active"] is False and d["mode"] is None and d["expired"] is False and d["until"] is None and d["until_epoch"] is None and d["started"] is None and d["remaining_seconds"] == 0 and d["caffeinate"] == {"pid": None, "alive": False} and d["checks"] == []'
code "꺼진 상태의 off" 0 aw off --json
expect "was_active false" "$OUT" 'd["was_active"] is False and d["mode"] is None and d["caffeinate_released"] is True'

# ── --until HH:MM ──
HM=$(python3 -c 'import datetime;print((datetime.datetime.now()+datetime.timedelta(minutes=90)).strftime("%H:%M"))')
code "on --until (90분 뒤)" 0 aw on --until "$HM" --json
expect "남은 초 약 5400" "$OUT" '5280 < d["remaining_seconds"] <= 5400'
HM=$(python3 -c 'import datetime;print((datetime.datetime.now()-datetime.timedelta(minutes=30)).strftime("%H:%M"))')
code "지난 시각은 내일 그 시각 → 12시간 초과" 2 aw on --until "$HM" --json
aw off >/dev/null; reset

# ── 겹친 on (반박 2) ──
aw on --for 1h >/dev/null 2>&1 & aw on --for 2h >/dev/null 2>&1 & aw on --for 3h >/dev/null 2>&1 & wait
[ "$(wc -l < "$FAKE/pids" | tr -d ' ')" = 3 ] && [ "$(alive)" = 1 ] && ok "동시에 on 세 번 → 살아 있는 caffeinate 하나" || no "겹친 on 뒤 caffeinate 수: $(alive)"
code "겹친 on 뒤 off" 0 aw off --json
[ "$(alive)" = 0 ] && ok "off 뒤 남은 caffeinate 0" || no "겹친 on 뒤 off 했는데 caffeinate $(alive)개 남음"
reset

# ── 시작 시각이 다른 pid는 죽이지 않는다 (pid 재사용) ──
aw on --for 1h >/dev/null
python3 -c 'import json,sys
p = sys.argv[1]; d = json.load(open(p)); d["caffeinate"]["lstart"] = "Thu Jan 1 00:00:00 1970"; json.dump(d, open(p, "w"))' "$A/state.json"
code "시작 시각이 다른 프로세스" 0 aw status --json
expect "alive false" "$OUT" 'd["active"] is True and d["caffeinate"]["alive"] is False'
code "그 상태에서 off" 0 aw off --json
[ "$(alive)" = 1 ] && ok "기록과 시작 시각이 다른 프로세스에 종료 신호를 보내지 않음" || no "남의 프로세스를 죽임"
expect "해제 미확인이면 caffeinate_released false" "$OUT" 'd["caffeinate_released"] is False'
reset

# ── assertion을 읽지 못하면 해제됐다고 하지 않는다 ──
aw on --for 1h >/dev/null; touch "$FAKE/assert_fail"
code "pmset assertions 실패" 0 aw off --json
expect "caffeinate_released false" "$OUT" 'd["caffeinate_released"] is False'
reset

# ── 켜져 있는데 caffeinate가 죽음 (재부팅 등) ──
aw on --for 1h >/dev/null; kill "$(cat "$FAKE/pids")"; python3 -c 'import time;time.sleep(0.5)'
code "caffeinate 죽은 뒤 status" 0 aw status --json
expect "모드는 유지, alive false" "$OUT" 'd["active"] is True and d["caffeinate"]["alive"] is False'
OUT=$(echo '{"hook_event_name":"UserPromptSubmit"}' | aw hook)
expect "훅 알림에 절전 방지 꺼짐" "$OUT" '"자리 비움 모드" in d["hookSpecificOutput"]["additionalContext"] and "절전 방지" in d["hookSpecificOutput"]["additionalContext"]'
code "죽은 pid로 off" 0 aw off --json
expect "죽은 pid: 해제 확인됨" "$OUT" 'd["was_active"] is True and d["caffeinate_released"] is True'
reset

# ── 상태를 지우지 못하면 off는 실패 (S5 검증 F2) ──
aw on --for 1h >/dev/null
[ "$(stat -f %Lp "$A/state.json")" = 600 ] && ok "상태 파일 0600 (umask와 무관)" || no "상태 파일 권한: $(stat -f %Lp "$A/state.json")"
chmod 500 "$A"
code "상태 폴더에 쓸 수 없을 때 off" 1 aw off --json
expect "state_not_removed" "$OUT" 'd["ok"] is False and d["error"] == "state_not_removed"'
expect "그 뒤 status는 여전히 켜짐" "$(aw status --json)" 'd["active"] is True'
chmod 700 "$A"
code "권한을 되돌린 뒤 off" 0 aw off --json
expect "꺼짐" "$(aw status --json)" 'd["active"] is False'
reset

# ── 만료·깨진 상태 ──
mkdir -p "$A"
python3 -c 'import json,sys,time
t = time.time(); json.dump({"version": 1, "started": t - 7200, "until": t - 3600, "caffeinate": {"pid": 99999999, "lstart": "x", "args": "caffeinate"}, "checks": []}, open(sys.argv[1], "w"))' "$A/state.json"
code "만료된 상태의 status" 0 aw status --json
expect "만료: active false, expired true, 시각은 남음" "$OUT" 'd["active"] is False and d["expired"] is True and type(d["until"]) is str and type(d["until_epoch"]) is int and d["remaining_seconds"] == 0 and d["caffeinate"]["alive"] is False'
[ -z "$(echo '{"hook_event_name":"UserPromptSubmit"}' | aw hook)" ] && ok "만료 뒤 훅 알림 없음" || no "만료됐는데 훅 알림"
code "만료 뒤 off" 0 aw off --json
expect "was_active false + 정리" "$OUT" 'd["was_active"] is False'
[ ! -e "$A/state.json" ] && ok "만료 상태 파일 정리" || no "만료 상태가 남음"
mkdir -p "$A"; echo '{"until": ' > "$A/state.json"
code "깨진 상태 파일" 0 aw status --json
expect "깨짐 → 꺼짐" "$OUT" 'd["active"] is False and d["expired"] is False and d["until"] is None'
python3 -c 'import json,sys,time
t = time.time(); json.dump({"started": t, "until": t + 86400 * 30}, open(sys.argv[1], "w"))' "$A/state.json"
expect "12시간을 넘는 상태 파일은 무효" "$(aw status --json)" 'd["active"] is False'
echo '{"started": true, "until": "내일"}' > "$A/state.json"
expect "형식이 다른 상태 파일은 무효" "$(aw status --json)" 'd["active"] is False'
reset

# ── 아침 목록 ──
LONG="npx cdk deploy $(python3 -c 'print("Stack" * 60)')"
python3 - "$S" "$LONG" <<'EOF'
import sys
sys.path.insert(0, sys.argv[1])
import away
away.queue_add("/repo/a", ["CDK 배포/삭제"], "npx cdk deploy  ShiP1Tools --parameters License=DEMO_MARKER", "s1")
away.queue_add("/repo/a", ["CDK 배포/삭제"], "npx cdk deploy ShiP1Tools --parameters License=DEMO_MARKER", "s1")
away.queue_add("/repo/b", ["IAM 권한 변경"], "AWS_SECRET_ACCESS_KEY=abc123 aws iam put-role-policy --token zzz999 -H 'Authorization: Bearer qqq777' AKIAABCDEFGHIJKLMNOP", "s2")
away.queue_add("/repo/a", ["CDK 배포/삭제"], sys.argv[2] + " TargetAlpha", "s1")
away.queue_add("/repo/a", ["CDK 배포/삭제"], sys.argv[2] + " TargetBravo", "s1")
away.queue_add("/repo/c", ["x"], "tool --password 'first SPACED_ONE' --api-key \"k SPACED_TWO\" --token=\"t SPACED_THREE\" run", "s3")
EOF
code "report --json" 0 aw report --json
expect "같은 명령(공백만 다름)은 한 건, 횟수 2" "$OUT" 'd["ok"] and d["count"] == 5 and d["items"][0]["count"] == 2 and set(d["items"][0]) == {"key","first","last","count","repo","reasons","command"}'
expect "뒤쪽만 다른 긴 명령 2건이 구분됨" "$OUT" 'd["items"][2]["command"] != d["items"][3]["command"] and d["items"][2]["command"].endswith("TargetAlpha") and len(d["items"][2]["command"]) <= 220'
for marker in DEMO_MARKER abc123 zzz999 qqq777 AKIAABCDEFGHIJKLMNOP SPACED_ONE SPACED_TWO SPACED_THREE; do
  if grep -q "$marker" "$A/queue.jsonl" || aw report | grep -q "$marker"; then no "가림 실패: $marker"; else ok "목록·report에 $marker 없음"; fi
done
aw report | grep -q "License=\*\*\*" && aw report | grep -q "2회" && ok "report 텍스트 (가린 값, 횟수)" || no "report 텍스트" "$(aw report)"
expect "status의 queue_count는 묶은 건수" "$(aw status --json)" 'd["queue_count"] == 5'
[ "$(stat -f %Lp "$A/queue.jsonl")" = 600 ] && [ "$(stat -f %Lp "$A")" = 700 ] && ok "목록 0600, 폴더 0700" || no "권한: $(stat -f %Lp "$A/queue.jsonl") $(stat -f %Lp "$A")"
OUT=$(echo '{"hook_event_name":"SessionStart"}' | aw hook)
expect "꺼져 있고 목록이 있으면 SessionStart가 건수만 알림" "$OUT" 'd["hookSpecificOutput"]["hookEventName"] == "SessionStart" and "5건" in d["hookSpecificOutput"]["additionalContext"] and "cdk" not in d["hookSpecificOutput"]["additionalContext"] and "ShiP1Tools" not in d["hookSpecificOutput"]["additionalContext"]'
[ -z "$(echo '{"hook_event_name":"UserPromptSubmit"}' | aw hook)" ] && ok "꺼져 있으면 UserPromptSubmit 알림 없음" || no "꺼져 있는데 UserPromptSubmit 알림"
aw on --for 1h >/dev/null
OUT=$(echo '{"hook_event_name":"SessionStart"}' | aw hook)
expect "켜져 있으면 SessionStart도 모드 알림 (끝 시각)" "$OUT" '"까지 자리 비움 모드" in d["hookSpecificOutput"]["additionalContext"] and "절전 방지" not in d["hookSpecificOutput"]["additionalContext"]'
aw on --for 1h | grep -q "이전 아침 목록 5건" && ok "켤 때 남은 목록 안내" || no "남은 목록 안내"
aw off | grep -q "아침 목록 5건" && ok "off가 아침 목록을 보여 줌" || no "off 출력에 목록 없음"
code "report --clear" 0 aw report --clear --json
expect "clear는 보여 준 뒤 비움" "$OUT" 'd["count"] == 5'
expect "비운 뒤 0건" "$(aw report --json)" 'd == {"ok": True, "count": 0, "items": [], "holds": [], "runs": []}'
[ -z "$(echo '{"hook_event_name":"SessionStart"}' | aw hook)" ] && ok "꺼져 있고 목록이 비면 훅 출력 없음" || no "빈 상태에서 훅 출력"
echo 'not json' > "$A/queue.jsonl"
expect "깨진 목록 줄은 건너뜀" "$(aw report --json)" 'd["count"] == 0'
reset

# ── 질문 보류·조건부 재개·세션 기록 (2단계) ──
TR="$T/transcript.jsonl"; : > "$TR"
hook() {  # hook <이벤트> <세션> [마지막 응답] [stop_hook_active] → OUT
  OUT=$(python3 -c 'import json,sys
d = {"hook_event_name": sys.argv[1], "session_id": sys.argv[2], "cwd": sys.argv[5], "transcript_path": sys.argv[6]}
if sys.argv[1] == "Stop":
    d["last_assistant_message"] = sys.argv[3]; d["stop_hook_active"] = sys.argv[4] == "1"
if sys.argv[1] == "PreToolUse":
    d["tool_name"] = sys.argv[3] or "AskUserQuestion"
    d["tool_input"] = {"questions": [{"question": "어느 이름으로 할까요? --token HOLD_MARKER", "header": "이름", "options": []}]}
    if len(sys.argv) > 7 and sys.argv[7]:
        d["tool_input"] = {"questions": json.loads(sys.argv[7])}
print(json.dumps(d))' "$1" "$2" "${3:-}" "${4:-0}" "$T" "$TR" "${QS:-}" | aw hook)
}
ask() {  # ask <질문 목록 JSON> → OUT (질문 창 훅), REASON (거절 이유)
  QS=$1; hook PreToolUse q1; QS=
  REASON=$(python3 -c 'import json,sys
try: print(json.loads(sys.argv[1])["hookSpecificOutput"]["permissionDecisionReason"])
except Exception: print("")' "$OUT")
}
tools() {  # 도구 호출 N건: 공백 없는 JSON과 공백 있는 JSON을 번갈아 쓴다 (S2 검증 F4), 글 속의 같은 글자는 세지 않는다
  n=0; echo '{"type": "user", "message": {"content": [{"type": "tool_result", "content": "{\"type\":\"tool_use\"}"}]}}' >> "$TR"
  while [ $n -lt "$1" ]; do
    if [ $((n % 2)) = 0 ]; then echo '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash"}]}}' >> "$TR"
    else echo '{"type": "assistant", "message": {"content": [{"type": "tool_use", "name": "Bash"}]}}' >> "$TR"; fi
    n=$((n + 1)); done; }
ASK='설정을 마쳤습니다. 이름은 a와 b 중 어느 쪽으로 할까요?'
hook Stop s1 "$ASK"; [ -z "$OUT" ] && ok "꺼져 있으면 Stop 통과" || no "꺼져 있는데 Stop 출력" "$OUT"
hook PreToolUse s1; [ -z "$OUT" ] && ok "꺼져 있으면 질문 창 그대로" || no "꺼져 있는데 질문 거절" "$OUT"
[ ! -e "$A/holds.jsonl" ] && [ ! -e "$A/sessions" ] && ok "꺼져 있으면 보류·세션 기록 없음" || no "꺼진 상태에서 기록"
aw on --for 1h >/dev/null
hook PreToolUse s1
expect "질문 창: deny + 보류 안내" "$OUT" 'd["hookSpecificOutput"]["permissionDecision"] == "deny" and "보류 목록에 적었습니다" in d["hookSpecificOutput"]["permissionDecisionReason"] and "까지)" in d["hookSpecificOutput"]["permissionDecisionReason"]'
hook PreToolUse s1 Bash; [ -z "$OUT" ] && ok "다른 도구의 PreToolUse는 출력 없음" || no "다른 도구에 출력" "$OUT"
hook Stop s1 '작업을 마쳤습니다. 변경은 두 파일입니다.'; [ -z "$OUT" ] && ok "질문 없는 완료 보고는 통과" || no "완료 보고를 막음" "$OUT"
hook Stop s1 "$ASK" 1; [ -z "$OUT" ] && ok "stop_hook_active면 통과" || no "stop_hook_active인데 막음" "$OUT"
hook Stop s1 "$ASK"
expect "글 질문 1번째: block + 기본값·보류 안내" "$OUT" 'd["decision"] == "block" and "기본값" in d["reason"] and "보류:" in d["reason"]'
hook Stop s1 "$ASK"; [ -z "$OUT" ] && ok "재개 뒤 도구 호출이 없으면 다시 막지 않음" || no "진전 없이 다시 막음" "$OUT"
tools 3; hook Stop s1 "$ASK"
expect "도구 호출 3건 뒤 2번째: block" "$OUT" 'd["decision"] == "block"'
tools 5; hook Stop s1 "$ASK"; [ -z "$OUT" ] && ok "3번째는 통과 (회차당 2회)" || no "3번째도 막음" "$OUT"
hook Stop s2 "Should I proceed with the rename?"
expect "다른 세션은 따로 센다 (영어 신호)" "$OUT" 'd["decision"] == "block"'
hook UserPromptSubmit s1 >/dev/null; hook Stop s1 "$ASK"
expect "새 입력 뒤에는 다시 1번째" "$OUT" 'd["decision"] == "block"'
OUT=$(python3 -c 'import json,sys;print(json.dumps({"hook_event_name":"Stop","session_id":"w1","cwd":sys.argv[1],"transcript_path":sys.argv[2],"last_assistant_message":"계속할까요?","stop_hook_active":False}))' "$T" "$TR" | ORCA_STRUCTURED_SESSION=1 sh "$S/py.sh" "$S/away.py" hook)
[ -z "$OUT" ] && ok "Orca 워커는 이어 가게 하지 않음" || no "워커를 막음" "$OUT"
echo 'not json' | aw hook >/dev/null; [ $? = 0 ] && ok "깨진 훅 입력도 끝 코드 0" || no "깨진 입력에서 끝 코드"
OUT=$(echo '{"hook_event_name":"Stop","last_assistant_message":"할까요?"}' | aw hook); [ -z "$OUT" ] && ok "세션 id가 없으면 통과" || no "세션 없는 Stop을 막음" "$OUT"
code "보류 뒤 report --json" 0 aw report --json
expect "holds: 질문 창 1 + 글 질문(같은 글은 세션별 한 건)" "$OUT" 'd["count"] == 0 and [h["kind"] for h in d["holds"]].count("question") == 1 and {h["session"] for h in d["holds"] if h["kind"] == "stop"} == {"s1", "s2"} and len(d["holds"]) == 3 and set(d["holds"][0]) == {"ts","kind","repo","session","text"}'
grep -q HOLD_MARKER "$A/holds.jsonl" && no "보류 목록 가림 실패" || ok "보류 목록에 HOLD_MARKER 없음"
aw report | grep -q "보류된 질문 3건" && ok "report 텍스트에 보류된 질문" || no "report 텍스트" "$(aw report)"
code "세션이 있는 status" 0 aw status --json
expect "status: holds_count·sessions" "$OUT" 'd["holds_count"] == 3 and {x["session"] for x in d["sessions"]} == {"s1","s2","w1"} and set(d["sessions"][0]) == {"session","repo","cwd","last_event","last_event_at","last_activity_at"} and {x["last_event"] for x in d["sessions"]} <= {"resumed","stop","prompt","question","start"}'
[ "$(stat -f %Lp "$A/holds.jsonl")" = 600 ] && [ "$(stat -f %Lp "$A/sessions")" = 700 ] && ok "보류 0600, 세션 폴더 0700" || no "권한"
aw off >/dev/null; hook Stop s1 "$ASK"; [ -z "$OUT" ] && ok "끈 뒤 Stop 통과" || no "끈 뒤에도 막음" "$OUT"
aw on --for 1h >/dev/null; hook Stop s1 "$ASK"
expect "다시 켜면(새 회차 id) 재개 횟수 초기화" "$OUT" 'd["decision"] == "block"'
aw off >/dev/null
code "report --clear" 0 aw report --clear --json
expect "clear 뒤 holds도 0" "$(aw report --json)" 'd["holds"] == []'
reset

# ── 질문 창 거절 안내의 추천 선택지 (0.24) ──
in_reason() { case "$REASON" in *"$2"*) ok "$1" ;; *) no "$1" "$REASON" ;; esac; }
not_in_reason() { case "$REASON" in *"$2"*) no "$1" "$REASON" ;; *) [ -n "$REASON" ] && ok "$1" || no "$1 (거절 이유 없음)" "$OUT" ;; esac; }
aw on --for 1h >/dev/null
ask '[{"question": "어느 저장소를 쓸까요?", "options": [{"label": "SQLite (Recommended)"}, {"label": "Postgres"}]}]'
in_reason "추천이 하나면 이름을 적음" "추천 선택지: SQLite."
in_reason "추천이 있어도 승인 사항은 보류하라고 적음" "배포·삭제·권한·push 승인이나 사용자가 답을 기다리라고 한 것은 추천이 있어도 정하지 말고"
ask '[{"question": "형식은?", "options": [{"label": "JSON"}, {"label": "YAML (추천)"}]}]'
in_reason "한국어 표시 (추천)" "추천 선택지: YAML."
ask '[{"question": "형식은?", "options": [{"label": "JSON"}, {"label": "YAML"}]}]'
not_in_reason "추천 표시가 없으면 적지 않음" "추천 선택지"
in_reason "추천이 없으면 예전 안내 (기본값으로)" "되돌릴 수 있는 결정이면 기본값으로 정해"
ask '[{"question": "형식은?", "options": [{"label": "JSON (Recommended)"}, {"label": "YAML (추천)"}]}]'
not_in_reason "추천 표시가 둘이면 적지 않음" "추천 선택지"
ask '[{"question": "무엇을 넣을까요?", "multiSelect": true, "options": [{"label": "로그 (Recommended)"}, {"label": "지표"}]}]'
not_in_reason "여러 개 고르기는 적지 않음" "추천 선택지"
ask '[{"question": "지울까요?", "options": [{"label": "유지"}, {"label": "삭제 (비추천)"}]}]'
not_in_reason "(비추천)은 추천이 아님" "추천 선택지"
ask '[{"question": "저장소는 어느 쪽?", "options": [{"label": "SQLite (Recommended)"}, {"label": "Postgres"}]}, {"question": "이름은?", "options": [{"label": "a"}, {"label": "b"}]}]'
in_reason "질문이 여럿이면 질문 → 추천" "저장소는 어느 쪽? → SQLite"
grep -q "(추천: SQLite)" "$A/holds.jsonl" && ok "보류 목록 글에도 (추천: 이름)" || no "보류 목록에 추천 없음" "$(cat "$A/holds.jsonl")"
ask '[{"question": "키는?", "options": [{"label": "--token REC_MARKER (Recommended)"}, {"label": "없음"}]}]'
case "$REASON$(cat "$A/holds.jsonl")" in *REC_MARKER*) no "추천 이름 가림 실패" "$REASON" ;; *) ok "추천 이름도 가림 적용" ;; esac
ask 'null'; [ -n "$REASON" ] && ok "질문 목록이 깨져도 거절" || no "깨진 질문 목록" "$OUT"
aw off >/dev/null; reset

# ── 잠자기 방지만 (--mode awake, 0.24): 자리 비움이 아니므로 훅·guard는 꺼져 있을 때와 같다 ──
DEPLOY='npx cdk deploy Demo'
guard() {  # guard <CLAUDE_PID|-> <세션> <cwd> <명령> [표식 인자...] → OUT (표식 인자가 없으면 0.24 이전 hooks.json으로 뜬 탭)
  gp=$1; gs=$2; gc=$3; gm=$4; shift 4
  OUT=$(python3 -c 'import json,sys
print(json.dumps({"hook_event_name": "PreToolUse", "tool_name": "Bash", "session_id": sys.argv[1], "cwd": sys.argv[2], "tool_input": {"command": sys.argv[3]}}))' "$gs" "$gc" "$gm" \
    | if [ "$gp" = - ]; then python3 "$S/guard.py" "$@"; else CLAUDE_PID=$gp python3 "$S/guard.py" "$@"; fi)
}
decision() { python3 -c 'import json,sys
try: print(json.loads(sys.argv[1])["hookSpecificOutput"].get("permissionDecision", "note"))
except Exception: print("none" if not sys.argv[1].strip() else "error")' "$OUT"; }
code "on --mode awake" 0 aw on --for 2h --mode awake --json
expect "awake: 켜짐, mode awake, 경고 없음, status 키 그대로" "$OUT" "d['active'] is True and d['mode'] == 'awake' and d['tickets'] == [] and d['caffeinate']['alive'] is True and d['warnings'] == [] and set(d) == $KEYS | {'warnings'}"
[ -e "$A/awake.json" ] && [ ! -e "$A/state.json" ] && ok "awake 상태는 awake.json에만 (state.json 없음)" || no "awake 상태 파일" "$(ls "$A")"
[ "$(stat -f %Lp "$A/awake.json")" = 600 ] && ok "awake.json 0600" || no "awake.json 권한"
aw status | grep -q "잠자기 방지 (확인 창·질문은 평소대로): 켜짐" && ok "status 텍스트가 모드를 말함" || no "awake status 텍스트" "$(aw status)"
hook PreToolUse s1; [ -z "$OUT" ] && ok "awake: 질문 창 그대로" || no "awake인데 질문 거절" "$OUT"
hook Stop s1 "$ASK"; [ -z "$OUT" ] && ok "awake: Stop 통과" || no "awake인데 Stop을 막음" "$OUT"
hook UserPromptSubmit s1; [ -z "$OUT" ] && ok "awake: 모드 알림 없음" || no "awake인데 모드 알림" "$OUT"
hook SessionStart s1; [ -z "$OUT" ] && ok "awake: SessionStart 알림 없음" || no "awake인데 SessionStart 알림" "$OUT"
[ ! -e "$A/holds.jsonl" ] && [ ! -e "$A/sessions" ] && ok "awake: 보류·세션 기록 없음" || no "awake에서 기록이 생김"
guard - s1 "$T" "$DEPLOY" --schema 1
[ "$(decision)" = ask ] && [ ! -e "$A/queue.jsonl" ] && ok "awake: guard는 평소대로 ask, 아침 목록 없음" || no "awake의 guard 판정: $(decision)" "$OUT"
# 예전 스크립트(0.23)는 awake.json을 읽지 않는다 → 꺼짐으로 본다 (기획 반박 반례 1)
mkdir "$T/old"
if git -C "$S" show 625c812:scripts/away.py > "$T/old/away.py" 2>/dev/null && git -C "$S" show 625c812:scripts/kitlib.py > "$T/old/kitlib.py" 2>/dev/null \
    && git -C "$S" show 625c812:scripts/guard.py > "$T/old/guard.py" 2>/dev/null && git -C "$S" show 625c812:scripts/deploy_gate.py > "$T/old/deploy_gate.py" 2>/dev/null; then
  expect "0.23 away.py status: awake를 꺼짐으로" "$(python3 "$T/old/away.py" status --json)" 'd["active"] is False and "mode" not in d'
  OUT=$(python3 -c 'import json,sys;print(json.dumps({"hook_event_name":"PreToolUse","tool_name":"AskUserQuestion","session_id":"o1","cwd":sys.argv[1],"tool_input":{"questions":[{"question":"어느 쪽?","options":[]}]}}))' "$T" | python3 "$T/old/away.py" hook)
  [ -z "$OUT" ] && ok "0.23 질문 훅: awake에서 거절하지 않음" || no "0.23 질문 훅이 awake를 자리 비움으로 읽음" "$OUT"
  OUT=$(python3 -c 'import json,sys;print(json.dumps({"session_id":"o1","cwd":sys.argv[1],"tool_input":{"command":sys.argv[2]}}))' "$T" "$DEPLOY" | python3 "$T/old/guard.py")
  [ "$(decision)" = ask ] && ok "0.23 guard: awake에서 ask (거절 아님)" || no "0.23 guard 판정: $(decision)" "$OUT"
else
  echo "(git 기록에 625c812가 없어 0.23 스크립트 시험은 건너뜀)"
fi
aw on --for 1h --mode awake | grep -q "자리 비움이 아닙니다" && ok "켤 때 '자리 비움이 아닙니다' 안내" || no "awake 켜기 안내"
[ "$(alive)" = 1 ] && ok "awake를 다시 켜면 caffeinate는 하나" || no "awake 교체 뒤 caffeinate 수: $(alive)"
code "awake → away 전환" 0 aw on --for 1h --json
expect "전환 뒤 mode away" "$OUT" 'd["active"] is True and d["mode"] == "away"'
[ -e "$A/state.json" ] && [ ! -e "$A/awake.json" ] && [ "$(alive)" = 1 ] && ok "전환: state.json만 남고 caffeinate 하나" || no "awake → away 뒤 상태 (alive=$(alive))" "$(ls "$A")"
hook PreToolUse s1
expect "away로 바꾸면 질문 창 거절" "$OUT" 'd["hookSpecificOutput"]["permissionDecision"] == "deny"'
code "away → awake 전환" 0 aw on --for 1h --mode awake --json
expect "전환 뒤 mode awake" "$OUT" 'd["mode"] == "awake"'
[ -e "$A/awake.json" ] && [ ! -e "$A/state.json" ] && [ "$(alive)" = 1 ] && ok "전환: awake.json만 남고 caffeinate 하나 (티켓도 사라짐)" || no "away → awake 뒤 상태 (alive=$(alive))" "$(ls "$A")"
hook PreToolUse s1; [ -z "$OUT" ] && ok "awake로 바꾸면 질문 창 그대로" || no "전환 뒤에도 질문 거절" "$OUT"
code "awake에서 off" 0 aw off --json
expect "off JSON (awake)" "$OUT" 'd == {"ok": True, "was_active": True, "mode": "awake", "caffeinate_released": True, "queue_count": 0}'
[ "$(alive)" = 0 ] && [ ! -e "$A/awake.json" ] && ok "off 뒤 caffeinate 종료·awake.json 삭제" || no "awake off 뒤 정리 (alive=$(alive))"
aw on --for 1h --mode awake >/dev/null; aw off | grep -q "잠자기 방지 끔" && ok "off 텍스트 (잠자기 방지 끔)" || no "awake off 텍스트"
reset
code "awake + 티켓 인자" 2 aw on --for 1h --mode awake --ticket "$T::Demo" --json
expect "bad_ticket" "$OUT" 'd["ok"] is False and d["error"] == "bad_ticket"'
code "모르는 모드" 2 aw on --for 1h --mode nap --json
expect "usage" "$OUT" 'd["error"] == "usage"'
[ ! -e "$A/awake.json" ] && [ ! -e "$A/state.json" ] && [ "$(alive)" = 0 ] && ok "인자 오류에서는 상태·caffeinate 없음" || no "인자 오류 뒤 상태가 남음"
# 빈 모드 값은 생략이 아니다 (S4 D3): 잠자기 방지를 자리 비움으로 바꾸지 않는다
aw on --for 1h --mode awake >/dev/null
code "빈 모드 값은 인자 오류" 2 aw on --for 1h --mode "" --json
expect "usage (빈 값)" "$OUT" 'd["error"] == "usage"'
expect "기존 잠자기 방지는 그대로" "$(aw status --json)" 'd["mode"] == "awake" and d["caffeinate"]["alive"] is True'
[ "$(alive)" = 1 ] && ok "caffeinate 하나 그대로" || no "빈 모드 값 뒤 caffeinate 수" "$(alive)"
reset
# 모드를 바꾸다 새 상태를 쓰지 못하면 (S4 D2): 새로 띄운 caffeinate를 거두고 이전 모드는 그대로
aw on --for 1h >/dev/null
chmod 500 "$A"
code "상태를 못 쓰면 켜지 않음" 1 aw on --for 1h --mode awake --json
expect "state_not_saved" "$OUT" 'd["ok"] is False and d["error"] == "state_not_saved"'
chmod 700 "$A"
expect "이전 자리 비움과 절전 방지가 그대로" "$(aw status --json)" 'd["active"] is True and d["mode"] == "away" and d["caffeinate"]["alive"] is True'
[ "$(alive)" = 1 ] && ok "새로 띄운 caffeinate를 거둠" || no "저장 실패 뒤 caffeinate 수" "$(alive)"
code "그 뒤 off" 0 aw off --json
expect "off가 해제를 확인" "$OUT" 'd["caffeinate_released"] is True'
[ "$(alive)" = 0 ] && ok "남은 caffeinate 없음" || no "off 뒤 caffeinate가 남음" "$(alive)"
reset
echo battery > "$FAKE/batt"
aw on --for 1h --mode awake > "$T/out" 2>&1; aw off >/dev/null
grep -q "키 입력이 없을 때의 잠자기만" "$T/out" && ! grep -q "전원 연결·뚜껑 열림 동안만" "$T/out" && ok "배터리 awake 안내가 서로 어긋나지 않음" || no "배터리 awake 안내" "$(cat "$T/out")"
code "awake는 배터리에서도 켜짐" 0 aw on --for 1h --mode awake --json
expect "배터리 주의 + power 점검 false" "$OUT" 'd["active"] and d["mode"] == "awake" and any("배터리" in w and "키 입력이 없을 때의 잠자기만" in w for w in d["warnings"]) and [c["ok"] for c in d["checks"] if c["name"] == "power"] == [False]'
code "그 상태에서 away로 바꾸려 하면 거부" 3 aw on --for 1h --json
expect "on_battery, awake는 그대로" "$(aw status --json)" 'd["active"] is True and d["mode"] == "awake"'
aw off >/dev/null
echo unknown > "$FAKE/batt"
code "awake도 전원 미확인이면 거부" 3 aw on --for 1h --mode awake --json
expect "power_unknown" "$OUT" 'd["error"] == "power_unknown"'
echo battery > "$FAKE/batt"; echo closed > "$FAKE/lid"
code "awake도 뚜껑 닫힘이면 거부" 3 aw on --for 1h --mode awake --json
expect "lid_closed" "$OUT" 'd["error"] == "lid_closed"'
reset
# 두 파일이 같이 있으면(예전 앱이 awake를 모르고 자리 비움을 켬) 자리 비움이 우선, off는 둘 다 끈다
aw on --for 1h --mode awake >/dev/null; cp "$A/awake.json" "$T/awake.keep"; aw on --for 2h >/dev/null; cp "$T/awake.keep" "$A/awake.json"
expect "둘 다 있으면 away" "$(aw status --json)" 'd["mode"] == "away" and 7100 < d["remaining_seconds"] <= 7200'
code "둘 다 있을 때 off" 0 aw off --json
expect "off: away로 보고" "$OUT" 'd["was_active"] is True and d["mode"] == "away"'
[ ! -e "$A/awake.json" ] && [ ! -e "$A/state.json" ] && ok "off가 두 파일을 다 지움" || no "off 뒤 파일이 남음" "$(ls "$A")"
mkdir -p "$A"
python3 -c 'import json,sys,time
t = time.time(); json.dump({"version": 1, "started": t - 7200, "until": t - 3600, "caffeinate": None, "checks": []}, open(sys.argv[1], "w"))' "$A/awake.json"
expect "만료된 awake: 꺼짐·expired" "$(aw status --json)" 'd["active"] is False and d["expired"] is True and d["mode"] is None'
aw off >/dev/null; [ ! -e "$A/awake.json" ] && ok "만료된 awake.json 정리" || no "만료된 awake.json이 남음"
reset

# ── 0.24 이전에 뜬 탭: 표식 없이 불린 guard가 남긴 기록 (stale/) ──
mkdir -p "$T/repo/.git" "$T/repo/sub"
sleep 300 & OLD=$!
guard "$OLD" o1 "$T/repo/sub" 'git status' --schema 1
[ "$(decision)" = none ] && [ ! -e "$A/stale" ] && ok "표식이 있는 호출은 기록하지 않음" || no "표식 있는 호출이 기록함" "$OUT"
guard "$OLD" o1 "$T/repo/sub" 'git status'
[ "$(decision)" = none ] && [ -f "$A/stale/pid-$OLD.json" ] && ok "표식 없는 호출: 꺼져 있으면 출력 없이 기록만" || no "표식 없는 호출 기록" "$OUT $(ls "$A/stale" 2>&1)"
[ "$(stat -f %Lp "$A/stale")" = 700 ] && [ "$(stat -f %Lp "$A/stale/pid-$OLD.json")" = 600 ] && ok "기록 0600, 폴더 0700" || no "stale 권한"
guard "$OLD" o1 "$T/repo" 'git status'
j "$(cat "$A/stale/pid-$OLD.json")" 'd["cwd"].endswith("/repo/sub")' && ok "폴더만 바뀐 호출은 5분 안에 다시 쓰지 않음 (S4 D4)" || no "폴더가 바뀔 때마다 기록을 다시 씀" "$(cat "$A/stale/pid-$OLD.json")"
code "기록이 있는 status" 0 aw status --json
expect "stale_sessions: 살아 있는 프로세스 (basis pid, 작업 폴더)" "$OUT" 'len(d["stale_sessions"]) == 1 and d["stale_sessions"][0]["session"] == "o1" and d["stale_sessions"][0]["repo"].endswith("/repo") and d["stale_sessions"][0]["cwd"].endswith("/repo/sub") and d["stale_sessions"][0]["basis"] == "pid" and set(d["stale_sessions"][0]) == {"session","repo","cwd","seen_at","basis"} and d["sessions"] == []'
aw status | grep -q "재시작 권장: repo (kit 업데이트 전에 시작한 탭" && ok "status 텍스트에 재시작 권장" || no "status 텍스트" "$(aw status)"
code "awake로 켜면 예전 탭 경고 없음" 0 aw on --for 1h --mode awake --json
expect "경고 없음 (목록은 그대로)" "$OUT" 'd["warnings"] == [] and len(d["stale_sessions"]) == 1'
guard "$OLD" o1 "$T/repo/sub" 'git status'; [ "$(decision)" = none ] && ok "awake: 예전 탭에도 안내를 넣지 않음" || no "awake인데 예전 탭 안내" "$OUT"
code "away로 켜면 예전 탭 경고" 0 aw on --for 1h --json
expect "경고에 탭 수·레포·재시작" "$OUT" 'any("Claude 탭 1개 (repo)" in w and "재시작" in w for w in d["warnings"])'
guard "$OLD" o1 "$T/repo/sub" 'git status'
expect "away: 무해한 명령에는 판정 없이 안내만" "$OUT" '"permissionDecision" not in d["hookSpecificOutput"] and "자리 비움 모드" in d["hookSpecificOutput"]["additionalContext"] and "kit 업데이트 전에 시작" in d["hookSpecificOutput"]["additionalContext"] and "질문 창(AskUserQuestion)을 쓰지 말고" in d["hookSpecificOutput"]["additionalContext"]'
guard "$OLD" o1 "$T/repo/sub" 'git status'; [ "$(decision)" = none ] && ok "같은 회차의 두 번째는 안내 없음" || no "안내가 반복됨" "$OUT"
guard "$OLD" o1 "$T/repo/sub" "$DEPLOY"
expect "같은 회차: 위험 명령은 거절만 (안내 없음)" "$OUT" 'd["hookSpecificOutput"]["permissionDecision"] == "deny" and "kit 업데이트 전" not in d["hookSpecificOutput"]["permissionDecisionReason"]'
aw on --for 1h >/dev/null
guard "$OLD" o1 "$T/repo/sub" "$DEPLOY"
expect "새 회차: 위험 명령이면 거절 이유 뒤에 안내" "$OUT" 'd["hookSpecificOutput"]["permissionDecision"] == "deny" and "아침 목록에 넣었습니다" in d["hookSpecificOutput"]["permissionDecisionReason"] and "kit 업데이트 전에 시작" in d["hookSpecificOutput"]["permissionDecisionReason"] and "additionalContext" not in d["hookSpecificOutput"]'
guard "$OLD" o2 "$T/repo/sub" "$DEPLOY" --schema 1
expect "표식이 있는 탭의 거절에는 안내가 없음" "$OUT" 'd["hookSpecificOutput"]["permissionDecision"] == "deny" and "kit 업데이트 전" not in d["hookSpecificOutput"]["permissionDecisionReason"]'
python3 -c 'import json,sys
p = sys.argv[1]; d = json.load(open(p)); d["noted_ts"] -= 1801; json.dump(d, open(p, "w"))' "$A/stale/pid-$OLD.json"
guard "$OLD" o1 "$T/repo/sub" 'ls'; [ "$(decision)" = note ] && ok "30분이 지나면 안내를 다시" || no "30분 뒤 안내 없음" "$OUT"
aw off >/dev/null
kill "$OLD" 2>/dev/null; wait "$OLD" 2>/dev/null
expect "탭을 닫으면(프로세스 종료) 목록에서 빠짐" "$(aw status --json)" 'd["stale_sessions"] == []'
[ ! -e "$A/stale/pid-$OLD.json" ] && ok "끝난 프로세스의 기록 삭제" || no "끝난 프로세스의 기록이 남음"
# pid 재사용: 기록보다 나중에 시작한 프로세스는 그 탭이 아니다
sleep 300 & OLD=$!
guard "$OLD" o3 "$T/repo" 'ls'
python3 -c 'import json,sys
p = sys.argv[1]; d = json.load(open(p)); d["seen_ts"] -= 3600; json.dump(d, open(p, "w"))' "$A/stale/pid-$OLD.json"
expect "본 시각보다 나중에 시작한 pid는 다른 프로세스" "$(aw status --json)" 'd["stale_sessions"] == []'
kill "$OLD" 2>/dev/null; wait "$OLD" 2>/dev/null
# pid를 모르면(환경 변수 없음) 세션 ID로 적고 2시간 안의 것만 추정으로
guard - o4 "$T/repo" 'ls'
[ -f "$A/stale/sid-o4.json" ] && ok "CLAUDE_PID가 없으면 세션 ID로 기록" || no "세션 기록 없음" "$(ls "$A/stale" 2>&1)"
expect "basis time (추정)" "$(aw status --json)" '[(x["session"], x["basis"]) for x in d["stale_sessions"]] == [("o4", "time")]'
aw status | grep -q "떠 있는지는 추정" && ok "status 텍스트에 추정 표시" || no "추정 표시" "$(aw status)"
python3 -c 'import json,sys
p = sys.argv[1]; d = json.load(open(p)); d["seen_ts"] -= 7300; json.dump(d, open(p, "w"))' "$A/stale/sid-o4.json"
expect "2시간이 지난 추정 기록은 보이지 않음" "$(aw status --json)" 'd["stale_sessions"] == []'
# 기록을 쓸 수 없어도 guard 판정은 그대로
rm -rf "$A/stale"; : > "$A/stale"
guard - o5 "$T/repo" "$DEPLOY"; [ "$(decision)" = ask ] && ok "기록 폴더를 못 써도 ask" || no "기록 실패가 판정을 바꿈: $(decision)" "$OUT"
guard - o5 "$T/repo" 'ls'; [ "$(decision)" = none ] && ok "기록 폴더를 못 써도 무해한 명령은 출력 없음" || no "기록 실패 뒤 출력" "$OUT"
expect "깨진 기록 폴더에서도 status" "$(aw status --json)" 'd["ok"] is True and d["stale_sessions"] == []'
rm -f "$A/stale"; mkdir -p "$A/stale"; echo 'not json' > "$A/stale/pid-1.json"; echo '{"pid": true, "seen_ts": "x"}' > "$A/stale/sid-x.json"
expect "깨진 기록 파일은 건너뜀" "$(aw status --json)" 'd["stale_sessions"] == []'
exit $fail

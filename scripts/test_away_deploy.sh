#!/bin/sh
# 배포 티켓(away.py on --ticket, away_deploy.py) 테스트: sh scripts/test_away_deploy.sh
# HOME 격리. npx(cdk)·pmset·ioreg·caffeinate는 PATH 앞의 가짜 명령이라 실제 배포·전원 설정을 건드리지 않는다.
S=$(cd "$(dirname "$0")" && pwd)
T=$(cd "$(mktemp -d)" && pwd -P)
export HOME="$T/home" FAKE="$T/fake" GIT_CONFIG_NOSYSTEM=1
mkdir -p "$HOME" "$FAKE" "$T/bin"
A="$HOME/.config/37writes-kit/away"
cleanup() { for p in $(cat "$FAKE/pids" 2>/dev/null); do kill "$p" 2>/dev/null; done; rm -rf "$T"; }
trap cleanup EXIT
fail=0
ok() { echo "ok   $1"; }
no() { echo "FAIL $1"; [ -n "$2" ] && echo "     $2"; fail=1; }
printf '#!/bin/sh\ncase "$2" in batt) echo "Now drawing from '"'"'AC Power'"'"'" ;; esac\nexit 0\n' > "$T/bin/pmset"
printf '#!/bin/sh\necho '"'"'  |   "AppleClamshellState" = No'"'"'\n' > "$T/bin/ioreg"
cat > "$T/bin/caffeinate" <<'FAKE_EOF'
#!/bin/sh
echo "$$" >> "$FAKE/pids"
trap 'kill $c 2>/dev/null; exit 0' TERM
sleep 600 & c=$!
wait
FAKE_EOF
# 가짜 npx: `npx cdk diff|deploy <스택> …`만 안다. 부른 인자를 calls에 남긴다.
cat > "$T/bin/npx" <<'FAKE_EOF'
#!/bin/sh
echo "$*" >> "$FAKE/calls"
[ "$1" = cdk ] || exit 9
case "$2" in
  diff) cat "$FAKE/diff" >&2; exit "$(cat "$FAKE/diff_code" 2>/dev/null || echo 0)" ;;
  deploy) [ -f "$FAKE/deploy_sleep" ] && sleep 1
    echo "deploying $3"; exit "$(cat "$FAKE/deploy_code" 2>/dev/null || echo 0)" ;;
esac
exit 9
FAKE_EOF
chmod +x "$T/bin/"*
export PATH="$T/bin:$PATH"
(caffeinate & sleep 0.3; kill $!) >/dev/null 2>&1; : > "$FAKE/pids"

aw() { sh "$S/py.sh" "$S/away.py" "$@"; }
dp() { sh "$S/py.sh" "$S/away_deploy.py" "$@"; }
j() { python3 -c 'import json,sys
d = json.loads(sys.argv[1])
raise SystemExit(0 if eval(sys.argv[2]) else 1)' "$1" "$2" 2>/dev/null; }
expect() { if j "$2" "$3"; then ok "$1"; else no "$1" "$2"; fi; }
code() { d=$1; want=$2; shift 2; OUT=$("$@" 2>"$T/err"); got=$?
  if [ "$got" = "$want" ]; then ok "$d (끝 코드 $want)"; else no "$d: 끝 코드 want=$want got=$got" "$OUT $(cat "$T/err")"; fi; }
deploys() { n=$(grep -c '^cdk deploy' "$FAKE/calls" 2>/dev/null); echo "${n:-0}"; }
safe_diff() { printf 'Stack Demo\nResources\n[~] AWS::Lambda::Function Fn FnABC\n └─ [~] Code\n[+] AWS::SQS::Queue Q Q123\n\n✨  Number of stacks with differences: 1\n' > "$FAKE/diff"; }
fresh() {  # fresh [on 인자...]: 상태·기록 초기화 뒤 켠다
  aw off >/dev/null 2>&1; rm -rf "$A"; rm -f "$FAKE/calls" "$FAKE/diff_code" "$FAKE/deploy_code" "$FAKE/deploy_sleep" "$R/ran"; safe_diff
  [ $# -gt 0 ] && aw on --for 1h "$@" >/dev/null
}

# 레포: 프로필 테스트 줄(명령은 백틱), cdk 앱 폴더 infra, 다른 worktree
R="$T/app"; git init -q "$R"; mkdir "$R/infra"
printf -- '- **테스트**: `sh t.sh`\n' > "$R/CLAUDE.md"
printf 'touch ran; exit "$(cat code 2>/dev/null || echo 0)"\n' > "$R/t.sh"
git -C "$R" add -A; git -C "$R" -c user.name=t -c user.email=t@t commit -qm init
git -C "$R" worktree add -q "$T/wt" -b wt 2>/dev/null; mkdir -p "$T/wt/infra"
O="$T/other"; git init -q "$O"

# ── 티켓 만들기 ──
fresh
code "형식이 틀린 티켓" 2 aw on --for 1h --ticket "$R" --json
expect "bad_ticket" "$OUT" 'd["error"] == "bad_ticket"'
code "없는 폴더" 2 aw on --for 1h --ticket "$T/nope::Demo" --json
code "횟수 4" 2 aw on --for 1h --ticket "$R::Demo::4" --json
code "횟수 0" 2 aw on --for 1h --ticket "$R::Demo::0" --json
code "스택 이름에 공백·옵션" 2 aw on --for 1h --ticket "$R::Demo --force" --json
code "같은 티켓 두 번" 2 aw on --for 1h --ticket "$R::Demo" --ticket "$R/infra::Demo" --json
printf -- '- **테스트**: 손으로 화면을 눌러 본다\n' > "$O/CLAUDE.md"
code "테스트 줄을 읽지 못하는 레포" 2 aw on --for 1h --ticket "$O::Demo" --json
[ ! -e "$A/state.json" ] && ok "티켓 오류에서는 켜지지 않음" || no "티켓 오류인데 상태가 생김"
printf -- '- **테스트**: 미정\n' > "$O/CLAUDE.md"
code "on --ticket 둘" 0 aw on --for 1h --ticket "$R::Demo" --ticket "$O::Other::2" --json
expect "status tickets" "$OUT" '[(t["stack"], t["limit"], t["used"], t["locked"], t["tests"]) for t in d["tickets"]] == [("Demo", 1, 0, False, ["sh t.sh"]), ("Other", 2, 0, False, [])] and set(d["tickets"][0]) == {"id","repo","stack","limit","used","locked","note","tests"}'
OUT=$(echo '{"hook_event_name":"SessionStart","session_id":"s"}' | aw hook)
expect "모드 알림에 티켓과 실행기 안내" "$OUT" '"배포 티켓" in d["hookSpecificOutput"]["additionalContext"] and "away_deploy.py" in d["hookSpecificOutput"]["additionalContext"] and "run --stack Demo" in d["hookSpecificOutput"]["additionalContext"]'
aw off >/dev/null
expect "끄면 티켓도 사라짐" "$(aw status --json)" 'd["tickets"] == []'

# ── 정상: 테스트 → diff → 배포 1회 ──
fresh --ticket "$R::Demo"
code "티켓 일치 배포" 0 dp run --stack Demo --cwd "$R/infra" --json
expect "deployed + 단계" "$OUT" 'd["ok"] and d["result"] == "deployed" and [s["name"] for s in d["steps"]] == ["티켓","테스트","cdk diff","cdk deploy"] and all(s["ok"] for s in d["steps"]) and d["diff"] == {"added": 1, "changed": 1}'
[ "$(deploys)" = 1 ] && grep -q '^cdk deploy Demo --exclusively --require-approval never$' "$FAKE/calls" && grep -q '^cdk diff Demo --exclusively$' "$FAKE/calls" && ok "cdk diff 뒤 deploy 정확히 1회 (인자 고정)" || no "cdk 호출" "$(cat "$FAKE/calls")"
[ -e "$R/ran" ] && ok "배포 전에 프로필 테스트 실행" || no "테스트를 실행하지 않음"
expect "티켓 사용 1/1" "$(aw status --json)" 'd["tickets"][0]["used"] == 1'
code "횟수 초과" 3 dp run --stack Demo --cwd "$R/infra" --json
[ "$(deploys)" = 1 ] && ok "초과 요청은 배포 0회 추가" || no "초과인데 배포"
expect "report runs: 배포됨 + 거절, 아침 목록에 거절 1건" "$(aw report --json)" '[r["result"] for r in d["runs"]] == ["deployed", "refused"] and d["count"] == 1 and set(d["runs"][0]) == {"ts","repo","stack","result","code","steps","diff","log"}'
[ "$(stat -f %Lp "$A"/logs/*.log | sort -u)" = 600 ] && ok "로그 0600" || no "로그 권한"
aw report | grep -q "티켓 배포 기록 2건" && ok "report 텍스트에 배포 기록" || no "report 텍스트" "$(aw report)"

# ── 티켓 밖 ──
fresh --ticket "$R::Demo"
code "다른 스택" 3 dp run --stack Other --cwd "$R/infra" --json
code "다른 레포" 3 dp run --stack Demo --cwd "$O" --json
code "스택 둘·추가 인자" 2 dp run --stack "Demo Other" --cwd "$R/infra" --json
code "destroy 같은 다른 명령" 2 dp destroy --stack Demo --json
code "스택 없음" 2 dp run --json
[ "$(deploys)" = 0 ] && [ ! -e "$R/ran" ] && ok "티켓 밖 요청은 테스트·배포 0회" || no "티켓 밖인데 실행"
code "다른 worktree의 같은 레포는 같은 티켓" 0 dp run --stack Demo --cwd "$T/wt/infra" --json
fresh
code "모드가 꺼져 있으면" 3 dp run --stack Demo --cwd "$R/infra" --json
[ ! -e "$A/runs.jsonl" ] && [ ! -e "$A/queue.jsonl" ] && ok "꺼져 있으면 기록도 남기지 않음" || no "꺼진 상태에서 기록"
mkdir -p "$A"; python3 -c 'import json,sys,time
t = time.time(); json.dump({"version": 1, "id": "x", "started": t - 7200, "until": t - 60, "tickets": [{"id": "t1", "repo": sys.argv[2], "repo_key": sys.argv[3], "stack": "Demo", "limit": 1, "used": 0, "locked": False, "tests": []}]}, open(sys.argv[1], "w"))' "$A/state.json" "$R" "$(git -C "$R" rev-parse --path-format=absolute --git-common-dir)"
code "만료된 티켓" 3 dp run --stack Demo --cwd "$R/infra" --json
[ "$(deploys)" = 0 ] && ok "만료·꺼짐은 배포 0회" || no "만료인데 배포"

# ── 검사에서 막힘 (배포 0회, 횟수 안 씀) ──
blocked() {  # blocked <설명> <diff 내용> [기대 글자]
  fresh --ticket "$R::Demo"; printf '%b' "$2" > "$FAKE/diff"
  code "$1" 4 dp run --stack Demo --cwd "$R/infra" --json
  [ "$(deploys)" = 0 ] && j "$OUT" 'd["result"] == "blocked"' && j "$(aw status --json)" 'd["tickets"][0]["used"] == 0 and d["tickets"][0]["locked"] is False' && ok "$1: 배포 0회, 횟수 그대로" || no "$1: 배포됨 또는 횟수 소비" "$OUT"
  [ -z "$3" ] || { j "$OUT" "'$3' in d['message']" && ok "$1: 이유 '$3'" || no "$1: 이유" "$OUT"; }
}
blocked "삭제 diff" 'Stack Demo\nResources\n[-] AWS::DynamoDB::Table Users UsersABC destroy\n' "리소스 삭제"
blocked "교체 diff" 'Stack Demo\nResources\n[~] AWS::RDS::DBInstance Db DbABC replace\n └─ [~] Engine (requires replacement)\n' "리소스 교체"
blocked "may be replaced" 'Stack Demo\nResources\n[~] AWS::S3::Bucket B B1 may be replaced\n' "리소스 교체"
blocked "IAM 표" 'Stack Demo\nIAM Statement Changes\n┌───┬──────┐\n│ + │ ${Fn.Arn} │\nResources\n[+] AWS::Lambda::Function Fn\n' "IAM 변경"
blocked "IAM 리소스 추가" 'Stack Demo\nResources\n[+] AWS::IAM::Role Role RoleABC\n' "IAM 변경"
blocked "보안 그룹" 'Stack Demo\nSecurity Group Changes\nResources\n[~] AWS::EC2::SecurityGroup SG\n' "보안 그룹 변경"
blocked "모르는 출력 형식" 'something unexpected\n' ""
blocked "빈 출력" '' ""
fresh --ticket "$R::Demo"; echo 1 > "$FAKE/diff_code"
code "cdk diff 실패" 4 dp run --stack Demo --cwd "$R/infra" --json
[ "$(deploys)" = 0 ] && ok "diff 실패: 배포 0회" || no "diff 실패인데 배포"
fresh --ticket "$R::Demo"; echo 1 > "$R/code"
code "테스트 실패" 4 dp run --stack Demo --cwd "$R/infra" --json
[ "$(deploys)" = 0 ] && ! grep -q '^cdk diff' "$FAKE/calls" 2>/dev/null && ok "테스트 실패: diff·배포 0회" || no "테스트 실패인데 진행"
rm -f "$R/code"
fresh --ticket "$R::Demo"; printf 'Stack Demo\nThere were no differences\n\n✨  Number of stacks with differences: 0\n' > "$FAKE/diff"
code "변경 없음" 0 dp run --stack Demo --cwd "$R/infra" --json
expect "no_changes: 배포 안 함, 횟수 그대로" "$OUT" 'd["result"] == "no_changes"'
[ "$(deploys)" = 0 ] && j "$(aw status --json)" 'd["tickets"][0]["used"] == 0' && ok "변경 없음: 배포 0회" || no "변경 없음인데 배포·소비"

# ── 배포 실패 → 잠금, 재시도 없음 ──
fresh --ticket "$R::Demo::3"; echo 1 > "$FAKE/deploy_code"
code "배포 실패" 5 dp run --stack Demo --cwd "$R/infra" --json
expect "failed" "$OUT" 'd["result"] == "failed" and "다시 시도" in d["message"]'
expect "티켓 잠김 (횟수는 1 소비)" "$(aw status --json)" 'd["tickets"][0]["locked"] is True and d["tickets"][0]["used"] == 1'
rm -f "$FAKE/deploy_code"
code "잠긴 티켓 (횟수가 남아도)" 3 dp run --stack Demo --cwd "$R/infra" --json
[ "$(deploys)" = 1 ] && ok "실패 뒤 재배포 0회" || no "잠긴 뒤 배포: $(deploys)"

# ── 두 탭이 동시에 (횟수 1) ──
fresh --ticket "$R::Demo"; touch "$FAKE/deploy_sleep"
dp run --stack Demo --cwd "$R/infra" >/dev/null 2>&1 & dp run --stack Demo --cwd "$T/wt/infra" >/dev/null 2>&1 & wait
[ "$(deploys)" = 1 ] && ok "동시에 두 번 불러도 배포 1회" || no "동시 실행 배포 수: $(deploys)"

# ── 후보 (권한 아님) ──
fresh
code "request" 0 aw request --stack Demo --note "가입 시험에 필요 --token REQ_MARKER" --cwd "$R/infra" --json
code "request 잘못된 스택" 2 aw request --stack "a b" --json
python3 - "$S" "$R" <<'PY_EOF'
import sys
sys.path.insert(0, sys.argv[1])
import away
away.queue_add(sys.argv[2], ["CDK"], "cd infra && npx cdk deploy ShiTools --exclusively && npx cdk deploy ShiAgent --profile default", "s")
PY_EOF
expect "ticket_candidates: request + 거절된 cdk deploy" "$(aw status --json)" '{(c["stack"], c["source"]) for c in d["ticket_candidates"]} == {("Demo","request"), ("ShiTools","queue"), ("ShiAgent","queue")} and set(d["ticket_candidates"][0]) == {"repo","stack","source","note"} and d["tickets"] == []'
grep -q REQ_MARKER "$A/requests.jsonl" && no "후보 메모 가림 실패" || ok "후보 메모에 REQ_MARKER 없음"
aw on --for 1h >/dev/null
code "후보만 있고 티켓이 없으면 거절" 3 dp run --stack Demo --cwd "$R/infra" --json
[ "$(deploys)" = 0 ] && ok "후보는 권한이 아님 (배포 0회)" || no "후보로 배포됨"
aw off >/dev/null
code "report --clear" 0 aw report --clear --json
expect "clear 뒤 runs·후보·로그 없음" "$(aw report --json)" 'd["runs"] == [] and d["count"] == 0'
expect "clear 뒤 후보 없음" "$(aw status --json)" 'd["ticket_candidates"] == []'
[ ! -e "$A/logs" ] && ok "clear가 로그 폴더도 지움" || no "로그가 남음"
exit $fail

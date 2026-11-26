#!/bin/sh
# guard.py 확인 규칙 테스트: sh scripts/test_guard.sh
# 판정은 none(출력 없음)·ask·deny·allow·error(JSON 아님, 끝 코드 ≠ 0)로 구분한다.
cd "$(dirname "$0")" || exit 1
S=$(pwd)
T=$(cd "$(mktemp -d)" && pwd -P); trap 'rm -rf "$T"' EXIT
export HOME="$T/home" GIT_CONFIG_NOSYSTEM=1
mkdir -p "$HOME"
fail=0
verdict() {  # verdict <끝 코드> <guard 출력> → none|ask|deny|allow|error
  python3 -c 'import json,sys
code, out = sys.argv[1], sys.argv[2].strip()
if code != "0": print("error"); raise SystemExit
if not out: print("none"); raise SystemExit
try:
    d = json.loads(out)["hookSpecificOutput"]["permissionDecision"]
except Exception:
    d = "error"
print(d if d in ("ask", "deny", "allow") else "error")' "$1" "$2"
}
run() {  # run <cwd|-> <명령> → OUT, GOT
  OUT=$(python3 -c 'import json,sys
d = {"tool_input": {"command": sys.argv[2]}, "session_id": "test"}
if sys.argv[1] != "-": d["cwd"] = sys.argv[1]
print(json.dumps(d))' "$1" "$2" | python3 "$S/guard.py" 2>/dev/null)
  GOT=$(verdict $? "$OUT")
}
check() {  # check none|ask|deny <명령>
  run - "$2"
  if [ "$GOT" = "$1" ]; then echo "ok   $1  $2"; else echo "FAIL want=$1 got=$GOT  $2"; fail=1; fi
}
# 판정 도우미 자체: 깨진 출력·끝 코드·allow를 통과로 세지 않는다
[ "$(verdict 0 '')" = none ] && [ "$(verdict 0 'Traceback (most recent call last)')" = error ] \
  && [ "$(verdict 1 '')" = error ] && [ "$(verdict 0 '{"hookSpecificOutput":{"permissionDecision":"allow"}}')" = allow ] \
  && [ "$(verdict 0 '{"hookSpecificOutput":{"permissionDecision":"deny"}}')" = deny ] \
  && echo "ok   판정 도우미 (none·error·allow·deny 구분)" || { echo "FAIL 판정 도우미"; fail=1; }
check none 'grep "ampx sandbox" file'
check none 'cat deploy.sh'
check none 'deploy.sh --diff'
check none './deploy.sh --synth'
check none 'echo deploy.sh'
check none 'npx ampx generate outputs'
check none 'git add deploy.sh'
check none 'ls'
check ask 'AWS_PROFILE=x ./deploy.sh'
check ask 'bash -e scripts/deploy.sh'
check ask 'ls
./deploy.sh'
check ask 'cd infra && ./deploy.sh --deploy'
check ask 'npx ampx sandbox --once'
check ask 'ampx pipeline-deploy --branch main'
check ask 'deploy.sh --diff-extra'
check ask 'sh -x ./deploy.sh prod'
check none 'git commit -m "fix deploy.sh"'
check none 'grep "ampx sandbox" f'
check none 'sudo -u app ls'
check none 'bash -c "echo hi"'
check ask 'npx --yes ampx sandbox --once'
check ask 'pnpm dlx ampx sandbox'
check ask 'npx -p @aws-amplify/backend-cli ampx pipeline-deploy'
check ask 'sudo -u app ampx pipeline-deploy'
check ask 'bash -c "./deploy.sh --prod"'
check ask 'sh -lc "cd infra && ./deploy.sh"'
check ask 'env FOO=1 ./deploy.sh'
check ask 'env -u X FOO=1 ./deploy.sh'
check ask 'time ./deploy.sh'
check ask 'nohup ./deploy.sh &'
check none 'bash -c "./deploy.sh --diff"'
# 자동 배포 검증 기록은 deploy_gate.py로만 (자세한 push 판정은 test_deploy_gate.sh)
check ask 'echo "{}" > .git/37writes-kit/deploy/x.json'
check ask 'cd .git && rm 37writes-kit/deploy/x.json'
check none 'sh scripts/py.sh scripts/deploy_gate.py verify --sha HEAD'
check none 'cat .git/37writes-kit/deploy/x.json'
check none 'grep -rn "37writes-kit/deploy" scripts'
check ask 'cat a.json > .git/37writes-kit/deploy/x.json'
check ask 'cat a.json | tee .git/37writes-kit/deploy/x.json'
check ask 'python3 -c "open(\".git/37writes-kit/deploy/x.json\",\"w\")"'
# push: 프로필에 "push: 배포 아님"이 있는 레포만 일반 push 통과
git init -q "$T/free" && printf -- '- **push**: 배포 아님 (승인한 커밋은 바로 push)\n' > "$T/free/CLAUDE.md"
git init -q "$T/deploy" && printf -- '- **push**: 배포 (main push 시 자동 배포)\n' > "$T/deploy/CLAUDE.md"
checkin() {  # checkin <폴더> none|ask|deny <명령>
  run "$1" "$3"
  if [ "$GOT" = "$2" ]; then echo "ok   $2  $3  ($(basename "$1"))"; else echo "FAIL want=$2 got=$GOT  $3  ($(basename "$1"))"; fail=1; fi
}
checkin "$T/free" none 'git push'
checkin "$T/free" none 'git push origin main'
checkin "$T/free" none 'git push -u origin feature'
checkin "$T/free" ask 'git push --force'
checkin "$T/free" ask 'git push -f origin main'
checkin "$T/free" ask 'git push --force-with-lease'
checkin "$T/free" ask 'git push origin +main'
checkin "$T/free" ask 'git push origin :old'
checkin "$T/free" ask 'git push --delete origin old'
checkin "$T/free" ask 'bash -c "git push"'
checkin "$T/free" ask "git -C $T/deploy push"
checkin "$T/free" ask "cd $T/deploy && git push"
checkin "$T/deploy" ask 'git push'
checkin "$T/deploy" none "git -C $T/free push origin main"
checkin "$T/deploy" none "cd $T/free && git add a && git commit -m x && git push"
checkin /tmp ask 'git push'
checkin /tmp none 'git commit -m "push 규칙 수정"'
checkin /tmp ask 'git -c core.x=1 push'
checkin "$T/deploy" ask 'git push origin 0123456789abcdef0123456789abcdef01234567:refs/heads/main'
# 자리 비움 모드: 유효하면 ask 대신 deny + 아침 목록 (away.py 자체는 test_away.sh)
A="$HOME/.config/37writes-kit/away"
away_state() {  # away_state <until까지 초(음수면 만료)|broken|none>
  rm -rf "$A"; mkdir -p "$A"
  case "$1" in
    none) rmdir "$A" ;;
    broken) echo '{"until": ' > "$A/state.json" ;;
    *) python3 -c 'import json,sys,time
t = time.time(); json.dump({"version": 1, "started": t - 3600, "until": t + int(sys.argv[2])}, open(sys.argv[1], "w"))' "$A/state.json" "$1" ;;
  esac
}
report() { python3 "$S/away.py" report --json; }
has() {  # has <설명> <문자열> <파이썬 식(s)>
  if python3 -c 'import json,sys
s = sys.argv[1]
raise SystemExit(0 if eval(sys.argv[2]) else 1)' "$2" "$3" 2>/dev/null; then echo "ok   $1"; else echo "FAIL $1"; echo "     $2"; fail=1; fi
}
INCIDENT='cd infra/p1 && npx cdk deploy ShiP1Tools --exclusively --require-approval never --profile default && npx cdk deploy ShiP1Agent --exclusively --require-approval never --profile default'
away_state none;   checkin "$T/free" ask "$INCIDENT"
away_state broken; checkin "$T/free" ask "$INCIDENT"
away_state -60;    checkin "$T/free" ask "$INCIDENT"
[ ! -e "$A/queue.jsonl" ] && echo "ok   없음·깨짐·만료에서는 아침 목록을 쓰지 않음" || { echo "FAIL 꺼진 상태에서 목록 기록"; fail=1; }
away_state 3600;   checkin "$T/free" deny "$INCIDENT"
has "거절 이유: 끝 시각·아침 목록·다시 시도 금지·원래 이유" "$OUT" '"자리 비움 모드(" in s and "까지)" in s and "아침 목록에 넣었습니다" in s and "다시 시도하지 말고 다른 일을 계속하세요" in s and "CDK" in s'
has "사건 명령 한 번 → 목록 1건" "$(report)" 'json.loads(s)["count"] == 1 and json.loads(s)["items"][0]["count"] == 1 and json.loads(s)["items"][0]["repo"].endswith("/free") and "ShiP1Agent" in json.loads(s)["items"][0]["command"]'
checkin "$T/free" deny "$INCIDENT"
has "두 번째는 같은 건으로 합침 (횟수 2)" "$(report)" 'json.loads(s)["count"] == 1 and json.loads(s)["items"][0]["count"] == 2'
checkin "$T/free" none 'git status'
checkin "$T/free" none 'git push origin main'
checkin "$T/free" none 'ls -la && echo hi'
has "확인 이유가 없는 명령은 목록에 없음" "$(report)" 'json.loads(s)["count"] == 1'
checkin "$T/free" deny 'aws iam put-role-policy --role-name x --policy-name y --policy-document file://p.json'
checkin "$T/free" deny 'git push --force origin main'
checkin "$T/free" deny 'git reset --hard HEAD~3'
checkin "$T/deploy" deny 'git push'
checkin "$T/free" deny 'bash -c "./deploy.sh --prod"'
checkin "$T/free" deny 'npx cdk deploy Demo --parameters License=DEMO_MARKER'
has "가림 표식이 목록·report에 없음" "$(cat "$A/queue.jsonl"; python3 "$S/away.py" report)" '"DEMO_MARKER" not in s and "License=***" in s'
has "다른 레포 SessionStart에 명령·표식이 붙지 않음 (켜짐: 모드 알림만)" "$(echo "{\"hook_event_name\":\"SessionStart\",\"cwd\":\"$T/deploy\"}" | python3 "$S/away.py" hook)" '"DEMO_MARKER" not in s and "cdk" not in s and "자리 비움 모드" in s'
# away 경로 보호 (켜져 있으면 deny, 꺼져 있으면 ask)
checkin "$T/free" deny 'rm ~/.config/37writes-kit/away/state.json'
checkin "$T/free" deny 'echo "{}" > ~/.config/37writes-kit/away/state.json'
checkin "$T/free" deny ': > ~/.config/37writes-kit/away/queue.jsonl'
checkin "$T/free" none 'cat ~/.config/37writes-kit/away/queue.jsonl'
checkin "$T/free" none 'sh scripts/py.sh scripts/away.py status --json'
checkin "$T/free" none 'ls ~/Documents/dev/37writes-claude-kit/away-mode'
# 목록을 쓸 수 없어도 거절은 한다 (기다리지 않고, 이유에 기록 실패)
rm -f "$A/queue.jsonl"; mkdir "$A/queue.jsonl"
START=$(date +%s); checkin "$T/free" deny "$INCIDENT"; END=$(date +%s)
has "목록 기록 실패를 이유에 적음" "$OUT" '"기록에 실패" in s and "넣었습니다" not in s'
[ $((END - START)) -lt 5 ] && echo "ok   목록을 못 써도 5초 안에 응답" || { echo "FAIL 응답이 늦음: $((END - START))초"; fail=1; }
rmdir "$A/queue.jsonl"
# 상태 폴더를 읽지 못하면 평소대로 ask
chmod 000 "$A"; checkin "$T/free" ask "$INCIDENT"; chmod 700 "$A"
away_state none
checkin "$T/free" ask 'rm ~/.config/37writes-kit/away/state.json'
checkin "$T/free" none 'git status'
exit $fail

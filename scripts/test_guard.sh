#!/bin/sh
# guard.py 확인 규칙 테스트: sh scripts/test_guard.sh
# 판정은 none(출력 없음)·ask·deny·allow·error(JSON 아님, 끝 코드 ≠ 0)로 구분한다.
cd "$(dirname "$0")" || exit 1
S=$(pwd)
T=$(cd "$(mktemp -d)" && pwd -P); trap 'rm -rf "$T"' EXIT
export HOME="$T/home" GIT_CONFIG_NOSYSTEM=1
unset CLAUDE_PID  # Claude 세션 안에서 돌려도 결과가 같게 (표식 없는 호출의 기록 키)
mkdir -p "$HOME"
fail=0
verdict() {  # verdict <끝 코드> <guard 출력> → none|ask|deny|allow|note(판정 없이 안내만)|error
  python3 -c 'import json,sys
code, out = sys.argv[1], sys.argv[2].strip()
if code != "0": print("error"); raise SystemExit
if not out: print("none"); raise SystemExit
try:
    h = json.loads(out)["hookSpecificOutput"]
    d = h["permissionDecision"] if "permissionDecision" in h else ("note" if h.get("additionalContext") else "error")
except Exception:
    d = "error"
print(d if d in ("ask", "deny", "allow", "note") else "error")' "$1" "$2"
}
MARK="--schema 1"  # hooks.json의 guard 등록 명령에 붙는 표식. 비우면 0.24 이전 hooks.json으로 뜬 탭의 호출
run() {  # run <cwd|-> <명령> → OUT, GOT
  OUT=$(python3 -c 'import json,sys
d = {"tool_input": {"command": sys.argv[2]}, "session_id": "test"}
if sys.argv[1] != "-": d["cwd"] = sys.argv[1]
print(json.dumps(d))' "$1" "$2" | python3 "$S/guard.py" $MARK 2>/dev/null)
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
  && [ "$(verdict 0 '{"hookSpecificOutput":{"additionalContext":"x"}}')" = note ] && [ "$(verdict 0 '{"hookSpecificOutput":{}}')" = error ] \
  && echo "ok   판정 도우미 (none·error·allow·deny·note 구분)" || { echo "FAIL 판정 도우미"; fail=1; }
grep -q 'scripts/guard.py\\" --schema 1"' "$S/../hooks/hooks.json" && echo "ok   hooks.json의 guard 등록에 표식(--schema 1)" || { echo "FAIL hooks.json guard 표식 없음"; fail=1; }
[ "$(grep -c -- '--schema' "$S/../hooks/hooks.json")" = 1 ] && echo "ok   표식은 guard 등록 한 곳에만 (away.py 훅 명령은 그대로)" || { echo "FAIL --schema가 다른 훅 명령에도 있음"; fail=1; }
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
# ── 글 속의 단어는 명령이 아니다 (오탐 → none) ──
check none 'git commit -m "cdk deploy 수정"'
check none 'git commit -m "제목
./deploy.sh 수정
terraform apply 설명"'
check none "git commit -m 'git push --force 설명, git reset --hard 주의'"
check none 'git -C /tmp/x commit -m "aws iam put-role-policy 정리"'
check none 'cat > note.md <<EOF
밤에 cdk deploy ShiP1Tools 확인 창에서 멈췄다.
DROP TABLE users;
EOF'
check none "cat <<'EOF' >> docs/plan.md
- terraform destroy 금지
- git push --force 금지
EOF"
check none 'echo "cdk deploy는 사용자가 실행"'
check none 'printf "%s\n" "amplify publish 안내"'
check none 'grep -rn "cdk deploy" docs'
check none 'rg "terraform apply" -l | head -5'
check none 'gh issue create --title "cdk deploy 오탐" --body "git reset --hard 도 같이"'
check none 'git log --grep "cdk destroy" | cat'
check none 'echo "rm -rf ~ 는 위험"'
check none 'git commit -m "37writes-kit/away 폴더 보호 설명"'
check none 'echo done # cdk deploy 는 나중에'
check none 'cdk diff Demo'
check none 'cdk synth && cdk ls'
check none 'terraform plan -out tf.plan'
# 파일·폴더 이름 속의 단어 (S1 검증). 이름 안의 $(…)와 경로 보호는 그대로
check none 'mkdir -p "terraform apply"'
check none 'touch "terraform apply.md"'
check none 'echo hi | tee "terraform apply.log"'
check ask 'mkdir "$(terraform apply)"'
check ask 'touch ~/.config/37writes-kit/away/state.json'
# ── 글자가 실행되는 경우는 그대로 본다 (미탐 방지 → ask) ──
check ask 'cdk deploy Demo'
check ask 'npx cdk --profile prod deploy ShiP1Agent'
check ask 'terraform -chdir=infra apply -auto-approve'
check ask '(cd infra && cdk deploy StackA)'
check ask '(cd infra && ./deploy.sh)'
check ask 'echo "$(./deploy.sh)"'
check ask 'x=`./deploy.sh`'
check ask 'printf "%s" "$(cdk deploy Demo)"'
check ask 'git commit -m "$(cdk deploy Demo)"'
check ask "sh <<'EOF'
cdk deploy Demo
EOF"
check ask 'bash <<EOF
cd infra
./deploy.sh
EOF'
check ask "sh -c 'cdk deploy Demo'"
check ask 'bash -c "echo \"go\" && ./deploy.sh"'
check ask "printf 'cdk deploy Demo\n' | sh"
check ask 'cat <<EOF | bash
cdk deploy Demo
EOF'
check ask "echo './deploy.sh' | sh"
check ask 'echo "cdk deploy Demo" | xargs -I{} sh -c {}'
check ask 'psql -c "DROP TABLE users;"'
check ask 'psql <<EOF
drop table users;
EOF'
check ask 'python3 -c "import os; os.system(\"cdk deploy Demo\")"'
check ask 'eval "cdk deploy Demo"'
check ask 'eval "./deploy.sh"'
check ask 'bash <<< "./deploy.sh"'
check ask 'if true; then cdk deploy Demo; fi'
check ask 'for s in A B; do ./deploy.sh $s; done'
check ask '{ ./deploy.sh; }'
check ask 'echo ok; (rm -rf ~)'
check ask 'echo "$(rm -rf ~/)"'
check ask 'orca terminal send --text "cdk deploy Demo"'
check ask 'echo "{}" > ~/.config/37writes-kit/away/state.json'
check ask 'printf x | tee ~/.config/37writes-kit/away/state.json'
# 배포 티켓은 사용자만 만든다
check ask 'sh scripts/py.sh scripts/away.py on --for 3h --ticket ~/dev/app::Demo'
check ask 'python3 scripts/away.py on --until 08:00 --ticket=/x::Demo::2'
check none 'sh scripts/py.sh scripts/away.py on --for 3h'
check none 'sh scripts/py.sh scripts/away.py request --stack Demo --note "가입 시험에 필요"'
check none 'sh scripts/py.sh scripts/away_deploy.py run --stack Demo --cwd infra'
check none 'git commit -m "away.py on --ticket 설명"'
# 해석하지 못하면(닫히지 않은 따옴표) 예전처럼 원문 전체를 검사한다
check ask 'git commit -m "cdk deploy 수정'
check ask "echo 'unterminated && ./deploy.sh"
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
# 목록 자리에 FIFO(읽는 쪽 없음): 열다가 멈추지 않고 거절 (S5 검증 F1)
mkfifo "$A/queue.jsonl"
START=$(date +%s); checkin "$T/free" deny "$INCIDENT"; END=$(date +%s)
has "FIFO 목록: 기록 실패를 이유에 적음" "$OUT" '"기록에 실패" in s'
[ $((END - START)) -lt 8 ] && echo "ok   FIFO 목록에서도 8초 안에 거절" || { echo "FAIL FIFO에서 응답이 늦음: $((END - START))초"; fail=1; }
rm -f "$A/queue.jsonl"
# 기록 함수가 돌아오지 않아도 훅 제한 전에 거절 (queue_add를 멈추게 바꾼 away 모듈)
mkdir "$T/slow"; cp "$S/guard.py" "$S/kitlib.py" "$S/away.py" "$T/slow/"
[ -f "$S/deploy_gate.py" ] && cp "$S/deploy_gate.py" "$T/slow/"
printf '\ndef queue_add(*a, **k):\n    time.sleep(60)\n' >> "$T/slow/away.py"
START=$(date +%s)
OUT=$(python3 -c 'import json,sys;print(json.dumps({"cwd":sys.argv[1],"tool_input":{"command":sys.argv[2]}}))' "$T/free" "$INCIDENT" | python3 "$T/slow/guard.py" $MARK)
END=$(date +%s)
has "기록이 멈춰도 deny + 기록 실패" "$OUT" '"\"deny\"" in s.replace(" ", "") and "기록에 실패" in s'
[ $((END - START)) -lt 10 ] && echo "ok   기록이 멈춰도 10초 안에 거절 (훅 제한 15초)" || { echo "FAIL 멈춘 기록에서 응답이 늦음: $((END - START))초"; fail=1; }
# 상태 폴더를 읽지 못하면 평소대로 ask
chmod 000 "$A"; checkin "$T/free" ask "$INCIDENT"; chmod 700 "$A"
away_state none
checkin "$T/free" ask 'rm ~/.config/37writes-kit/away/state.json'
checkin "$T/free" none 'git status'
[ ! -e "$A/stale" ] && echo "ok   표식이 있는 호출은 탭 기록(stale/)을 남기지 않음" || { echo "FAIL 표식 있는 호출이 stale/에 기록"; fail=1; }
# 잠자기 방지만 켠 상태(awake.json)는 자리 비움이 아니다: 평소대로 ask, 아침 목록 없음
mkdir -p "$A"; python3 -c 'import json,sys,time
t = time.time(); json.dump({"version": 1, "started": t - 60, "until": t + 3600}, open(sys.argv[1], "w"))' "$A/awake.json"
checkin "$T/free" ask "$INCIDENT"
checkin "$T/free" ask 'git push --force origin main'
[ ! -e "$A/queue.jsonl" ] && echo "ok   awake에서는 아침 목록을 쓰지 않음" || { echo "FAIL awake에서 목록 기록"; fail=1; }
# 0.24 이전 hooks.json으로 뜬 탭(표식 없음): 판정은 같고, 자리 비움 중이면 안내를 덧붙인다 (기록·목록은 test_away.sh)
MARK=
away_state none;   checkin "$T/free" none 'git status'
[ -f "$A/stale/sid-test.json" ] && echo "ok   표식 없는 호출은 탭을 기록 (꺼져 있으면 출력 없음)" || { echo "FAIL 표식 없는 호출 기록 없음"; fail=1; }
checkin "$T/free" ask "$INCIDENT"
away_state 3600;   checkin "$T/free" deny "$INCIDENT"
has "표식 없는 탭의 거절 이유: 원래 이유 + 예전 탭 안내" "$OUT" '"아침 목록에 넣었습니다" in s and "kit 업데이트 전에 시작" in s and "additionalContext" not in s'
checkin "$T/free" none 'git status'
away_state 3600;   checkin "$T/free" note 'git status'
has "무해한 명령: 판정 없이 안내만" "$OUT" '"permissionDecision" not in s and "질문 창(AskUserQuestion)을 쓰지 말고" in s'
checkin "$T/free" deny "$INCIDENT"
has "같은 회차의 다음 거절에는 안내를 다시 붙이지 않음" "$OUT" '"kit 업데이트 전" not in s'
exit $fail

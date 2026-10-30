#!/bin/sh
# guard.py 확인 규칙 테스트: sh scripts/test_guard.sh
cd "$(dirname "$0")" || exit 1
fail=0
check() {  # check ask|pass <명령>
  out=$(python3 -c 'import json,sys;print(json.dumps({"tool_input":{"command":sys.argv[1]}}))' "$2" | python3 guard.py)
  case "$out" in *'"ask"'*) got=ask ;; *) got=pass ;; esac
  if [ "$got" = "$1" ]; then echo "ok   $1  $2"; else echo "FAIL want=$1 got=$got  $2"; fail=1; fi
}
check pass 'grep "ampx sandbox" file'
check pass 'cat deploy.sh'
check pass 'deploy.sh --diff'
check pass './deploy.sh --synth'
check pass 'echo deploy.sh'
check pass 'npx ampx generate outputs'
check pass 'git add deploy.sh'
check pass 'ls'
check ask 'AWS_PROFILE=x ./deploy.sh'
check ask 'bash -e scripts/deploy.sh'
check ask 'ls
./deploy.sh'
check ask 'cd infra && ./deploy.sh --deploy'
check ask 'npx ampx sandbox --once'
check ask 'ampx pipeline-deploy --branch main'
check ask 'deploy.sh --diff-extra'
check ask 'sh -x ./deploy.sh prod'
check pass 'git commit -m "fix deploy.sh"'
check pass 'grep "ampx sandbox" f'
check pass 'sudo -u app ls'
check pass 'bash -c "echo hi"'
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
check pass 'bash -c "./deploy.sh --diff"'
# 자동 배포 검증 기록은 deploy_gate.py로만 (자세한 push 판정은 test_deploy_gate.sh)
check ask 'echo "{}" > .git/37writes-kit/deploy/x.json'
check ask 'cd .git && rm 37writes-kit/deploy/x.json'
check pass 'sh scripts/py.sh scripts/deploy_gate.py verify --sha HEAD'
check pass 'cat .git/37writes-kit/deploy/x.json'
check pass 'grep -rn "37writes-kit/deploy" scripts'
check ask 'cat a.json > .git/37writes-kit/deploy/x.json'
check ask 'cat a.json | tee .git/37writes-kit/deploy/x.json'
check ask 'python3 -c "open(\".git/37writes-kit/deploy/x.json\",\"w\")"'
# push: 프로필에 "push: 배포 아님"이 있는 레포만 일반 push 통과
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
git init -q "$T/free" && printf -- '- **push**: 배포 아님 (승인한 커밋은 바로 push)\n' > "$T/free/CLAUDE.md"
git init -q "$T/deploy" && printf -- '- **push**: 배포 (main push 시 자동 배포)\n' > "$T/deploy/CLAUDE.md"
checkin() {  # checkin <폴더> ask|pass <명령>
  out=$(python3 -c 'import json,sys;print(json.dumps({"cwd":sys.argv[1],"tool_input":{"command":sys.argv[2]}}))' "$1" "$3" | python3 "$OLDPWD_GUARD/guard.py")
  case "$out" in *'"ask"'*) got=ask ;; *) got=pass ;; esac
  if [ "$got" = "$2" ]; then echo "ok   $2  $3  ($(basename "$1"))"; else echo "FAIL want=$2 got=$got  $3  ($(basename "$1"))"; fail=1; fi
}
OLDPWD_GUARD=$(pwd)
checkin "$T/free" pass 'git push'
checkin "$T/free" pass 'git push origin main'
checkin "$T/free" pass 'git push -u origin feature'
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
checkin "$T/deploy" pass "git -C $T/free push origin main"
checkin "$T/deploy" pass "cd $T/free && git add a && git commit -m x && git push"
checkin /tmp ask 'git push'
checkin /tmp pass 'git commit -m "push 규칙 수정"'
checkin /tmp ask 'git -c core.x=1 push'
checkin "$T/deploy" ask 'git push origin 0123456789abcdef0123456789abcdef01234567:refs/heads/main'
exit $fail

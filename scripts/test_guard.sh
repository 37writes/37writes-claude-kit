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
check ask 'git push'
exit $fail

#!/bin/sh
# 자동 배포 정책 테스트 (deploy_gate.py + guard): sh scripts/test_deploy_gate.sh
# 로컬 bare 원격과 post-receive 훅(받은 SHA를 파일에 기록하는 가짜 배포)만 쓴다. 실제 원격에 접근하지 않는다.
S=$(cd "$(dirname "$0")" && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
export HOME="$T/home" GIT_CONFIG_NOSYSTEM=1 DEPLOYED="$T/deployed"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
mkdir -p "$HOME"
git config --global init.defaultBranch main
fail=0
ok() { echo "ok   $1"; }
no() { echo "FAIL $1"; fail=1; }

POLICY='- **자동 배포**: 허용 · 대상 `origin/main` · 검증 `sh check.sh` · 제외 `infra/**` · 확인 `sh confirm.sh {sha}`'
profile() {  # profile <정책 줄 또는 빈 값>
  printf '# 테스트\n\n<!-- 37writes-kit:profile:start -->\n- **구분**: 개인\n- **push**: 배포 (main push = 배포)\n%s\n<!-- 37writes-kit:profile:end -->\n' "$1"
}
setup() {  # setup <이름> <정책 줄>: bare 원격 + 가짜 배포 훅 + 작업 clone
  git init -q --bare "$T/$1.git"
  printf '#!/bin/sh\nwhile read old new ref; do echo "$new" > "%s"; done\n' "$DEPLOYED" > "$T/$1.git/hooks/post-receive"
  chmod +x "$T/$1.git/hooks/post-receive"
  git clone -q "$T/$1.git" "$T/$1" 2>/dev/null
  cd "$T/$1" || exit 1
  profile "$2" > CLAUDE.md
  # 검증: FAIL이 있으면 실패, 빌드 결과(추적 안 됨)를 만들고, MUTATE가 있으면 추적 파일을 고치고, NEED_LOCAL이 있으면 ignored local-ok가 필요
  printf '%s\n' 'test ! -f FAIL || exit 1' 'mkdir -p out && echo built > out/build.txt' \
    'if [ -f MUTATE ]; then echo fixed > MUTATE; fi' 'if [ -f NEED_LOCAL ]; then test -f local-ok || exit 1; fi' > check.sh
  echo 'test "$(cat "$DEPLOYED")" = "$1"' > confirm.sh
  git add -A && git commit -qm init && git push -q origin HEAD:refs/heads/main 2>/dev/null
  git fetch -q origin
}
fresh() { git fetch -q origin && git checkout -q --detach origin/main; }
commit() {  # commit <파일> <내용> → 새 HEAD SHA를 SHA에
  mkdir -p "$(dirname "$1")" && echo "$2" > "$1" && git add -A && git commit -qm "$1" && SHA=$(git rev-parse HEAD)
}
verify() { sh "$S/py.sh" "$S/deploy_gate.py" verify "$@" >/dev/null; }
gate() {  # gate ask|pass <설명> <명령>: guard 판정 (cwd = 현재 작업 clone)
  out=$(python3 -c 'import json,sys;print(json.dumps({"cwd":sys.argv[1],"tool_input":{"command":sys.argv[2]}}))' "$(pwd)" "$3" | python3 "$S/guard.py")
  case "$out" in *'"ask"'*) got=ask ;; *) got=pass ;; esac
  why=$(printf '%s' "$out" | sed -n 's/.*조건 불충족: \([^"]*\)".*/ (\1)/p')
  if [ "$got" = "$1" ]; then ok "$1  $2$why"; else no "want=$1 got=$got  $2  $out"; fi
}
pushed() {  # pushed <설명>: 실제 push 후 가짜 배포가 받은 SHA == 검증 SHA
  git push -q origin "$SHA:refs/heads/main" 2>/dev/null
  if [ "$(cat "$DEPLOYED")" = "$SHA" ]; then ok "배포 SHA == 검증 SHA  $1"; else no "배포 SHA 다름  $1"; fi
}

setup app "$POLICY"

# 허용 통과: 검증한 SHA를 전체 SHA refspec으로
fresh; commit src/a.txt 1; verify; code=$?
[ $code -eq 0 ] && ok "verify exit 0" || no "verify exit $code"
gate pass "허용 + 검증 + 범위 안" "git push origin $SHA:refs/heads/main"
gate pass "dst 짧은 이름" "git push origin $SHA:main"
gate pass "-C와 cd" "cd $T && git -C app push origin $SHA:refs/heads/main"
pushed "허용"
sh "$S/py.sh" "$S/deploy_gate.py" confirm >/dev/null && ok "confirm exit 0" || no "confirm 실패"
python3 -c 'import json,sys;r=json.load(open(sys.argv[1]));sys.exit(0 if r["exit"]==0 and r["confirm"]["exit"]==0 and r["tree"] else 1)' \
  "$(git rev-parse --git-common-dir)/37writes-kit/deploy/$SHA.json" && ok "기록에 verify·confirm" || no "기록 내용"

python3 -c 'import json,sys;r=json.load(open(sys.argv[1]));sys.exit(0 if r["checkout"]=="temp-worktree" and r["confirm"]["checkout"]=="temp-worktree" and r["confirm"]["sha"]==sys.argv[2] else 1)' \
  "$(git rev-parse --git-common-dir)/37writes-kit/deploy/$SHA.json" "$SHA" && ok "기록에 실행 위치(그 SHA의 임시 checkout)" || no "기록 실행 위치"
[ ! -e out ] && ok "검증 빌드 결과가 작업 폴더에 남지 않음" || no "작업 폴더에 out/ 생김"
DONE=$SHA

# confirm 실패: 배포되지 않은 SHA를 확인하면 exit≠0
sh "$S/py.sh" "$S/deploy_gate.py" confirm --sha "$DONE~1" >/dev/null; code=$?
[ $code -ne 0 ] && ok "confirm 실패 exit $code" || no "confirm 실패가 exit 0"
# D2: 작업 폴더의 커밋 안 된 확인 스크립트는 결과를 바꾸지 못한다 (그 SHA의 checkout에서 실행)
cp confirm.sh "$T/confirm.keep"; echo 'exit 0' > confirm.sh
sh "$S/py.sh" "$S/deploy_gate.py" confirm --sha "$DONE~1" >/dev/null; code=$?
[ $code -ne 0 ] && ok "커밋 안 된 확인 스크립트 무시 (exit $code)" || no "커밋 안 된 confirm.sh로 성공"
[ "$(cat confirm.sh)" = "exit 0" ] && ok "confirm이 작업 폴더를 건드리지 않음" || no "작업 폴더 confirm.sh 바뀜"
cp "$T/confirm.keep" confirm.sh

# 기록 없는 다른 SHA
fresh; commit src/b.txt 2
gate ask "검증 기록 없음" "git push origin $SHA:refs/heads/main"

# 움직이는 이름·짧은 SHA·옵션·추가 refspec
verify
gate ask "src가 브랜치 이름" "git push origin main"
gate ask "src가 HEAD" "git push origin HEAD:refs/heads/main"
gate ask "짧은 SHA" "git push origin $(git rev-parse --short HEAD):refs/heads/main"
gate ask "옵션 추가" "git push -u origin $SHA:refs/heads/main"
gate ask "refspec 둘" "git push origin $SHA:refs/heads/main $SHA:refs/heads/other"
gate ask "정책 대상이 아닌 브랜치" "git push origin $SHA:refs/heads/other"
gate ask "태그 대상" "git push origin $SHA:refs/tags/v1"
gate ask "git -c 재정의" "git -c remote.origin.pushurl=$T/other.git push origin $SHA:refs/heads/main"
gate ask "--git-dir 재정의" "git --git-dir=$T/app/.git push origin $SHA:refs/heads/main"
gate ask "--work-tree 재정의" "git --work-tree=$T push origin $SHA:refs/heads/main"

# push URL 다름
git init -q --bare "$T/other.git"
git remote set-url --push origin "$T/other.git"
gate ask "push URL != fetch URL" "git push origin $SHA:refs/heads/main"
git config --unset remote.origin.pushurl
gate pass "push URL 되돌린 뒤" "git push origin $SHA:refs/heads/main"

# 범위 밖(제외 glob)
fresh; commit infra/stack.ts 1; verify
gate ask "제외 경로 infra/**" "git push origin $SHA:refs/heads/main"

# 시크릿 패턴
fresh; commit src/key.txt "AKIA$(printf 'ABCDEFGHIJKLMNOP')"; verify
gate ask "시크릿 패턴" "git push origin $SHA:refs/heads/main"

# 검증 실패
fresh; commit FAIL 1; verify
gate ask "검증 실패 기록" "git push origin $SHA:refs/heads/main"

# D1: 검증 명령이 추적 파일을 고치면 명령 exit 0이어도 실패 기록, guard ask. 작업 폴더의 파일은 그대로
fresh; commit MUTATE broken; verify; code=$?
[ $code -ne 0 ] && ok "추적 파일을 고친 검증 exit $code" || no "추적 파일을 고친 검증이 exit 0"
python3 -c 'import json,sys;r=json.load(open(sys.argv[1]));sys.exit(0 if r["commandExit"]==0 and r["exit"]!=0 and r["changed"]==["MUTATE"] else 1)' \
  "$(git rev-parse --git-common-dir)/37writes-kit/deploy/$SHA.json" && ok "기록에 바뀐 파일" || no "바뀐 파일 기록"
gate ask "검증 중 추적 파일 변경" "git push origin $SHA:refs/heads/main"
python3 -c 'import json,sys;p=sys.argv[1];r=json.load(open(p));r["exit"]=0;json.dump(r,open(p,"w"))' "$(git rev-parse --git-common-dir)/37writes-kit/deploy/$SHA.json"
gate ask "exit만 0으로 고친 변경 기록" "git push origin $SHA:refs/heads/main"
[ "$(cat MUTATE)" = broken ] && ok "작업 폴더의 추적 파일 그대로" || no "작업 폴더 MUTATE 바뀜"

# D3: ignored 파일에 기대는 검증은 HEAD == SHA이고 깨끗한 작업 폴더에서도 임시 checkout에서 실패
fresh; echo local-ok > .gitignore; commit NEED_LOCAL 1; touch local-ok
[ -z "$(git status --porcelain)" ] && ok "작업 폴더 깨끗함 (local-ok는 ignored)" || no "작업 폴더가 깨끗하지 않음"
verify; code=$?
[ $code -ne 0 ] && ok "ignored 파일 의존 검증 실패 exit $code" || no "ignored 파일로 검증 통과"
gate ask "ignored 파일 의존" "git push origin $SHA:refs/heads/main"
rm -f local-ok

# 범위 안에서 정책 변경 (검증은 통과해도 base와 정책이 다름)
fresh; profile "$(echo "$POLICY" | sed 's/`infra\/\*\*`/`nothing\/**`/')" > CLAUDE.md
git commit -qam policy; SHA=$(git rev-parse HEAD); verify
gate ask "정책 변경" "git push origin $SHA:refs/heads/main"

# 기록 위조: tree를 바꾼 기록, 다른 SHA의 통과 기록 복사
fresh; commit src/c.txt 3; verify
REC="$(git rev-parse --git-common-dir)/37writes-kit/deploy"
python3 -c 'import json,sys;p=sys.argv[1];r=json.load(open(p));r["tree"]="0"*40;json.dump(r,open(p,"w"))' "$REC/$SHA.json"
gate ask "기록 tree 위조" "git push origin $SHA:refs/heads/main"
commit src/d.txt 4
python3 -c 'import json,sys;r=json.load(open(sys.argv[1]));r["sha"]=sys.argv[3];json.dump(r,open(sys.argv[2],"w"))' "$REC/$DONE.json" "$REC/$SHA.json" "$SHA"
gate ask "다른 SHA 기록 복사" "git push origin $SHA:refs/heads/main"
verify
python3 -c 'import json,sys;p=sys.argv[1];r=json.load(open(p));r["command"]="true";json.dump(r,open(p,"w"))' "$REC/$SHA.json"
gate ask "기록 명령 위조" "git push origin $SHA:refs/heads/main"

# 병합 후 새 SHA: 검증한 D 뒤에 원격이 앞서 나가 병합하면 새 SHA는 재검증 전 ask, 재검증 후 통과
fresh; commit src/e.txt 5; verify; D=$SHA
git clone -q "$T/app.git" "$T/other-clone" 2>/dev/null
(cd "$T/other-clone" && echo x > other.txt && git add -A && git commit -qm other && git push -q origin HEAD:refs/heads/main 2>/dev/null)
git fetch -q origin
gate ask "원격이 앞섬(fast-forward 아님)" "git push origin $D:refs/heads/main"
git merge -q --no-edit origin/main; SHA=$(git rev-parse HEAD)
gate ask "병합 후 새 SHA(재검증 전)" "git push origin $SHA:refs/heads/main"
verify
gate pass "병합 후 재검증" "git push origin $SHA:refs/heads/main"
pushed "병합 후"

# 작업 폴더가 깨끗하지 않거나 HEAD가 달라도 그 SHA의 임시 worktree에서 검증하고 지운다
fresh; commit src/f.txt 6; F=$SHA; git checkout -q --detach HEAD~1; echo dirty > dirty.txt
verify --sha "$F"; code=$?
[ $code -eq 0 ] && ok "임시 worktree 검증" || no "임시 worktree 검증 exit $code"
[ "$(git worktree list | wc -l | tr -d ' ')" = 1 ] && ok "임시 worktree 정리" || no "임시 worktree 남음"
[ "$(cat dirty.txt)" = dirty ] && [ "$(git rev-parse HEAD)" = "$(git rev-parse "$F~1")" ] && ok "작업 폴더 HEAD·파일 그대로" || no "작업 폴더 바뀜"
rm dirty.txt
# 예전 형식 기록(제자리 실행 inPlace, format 없음)은 통과시키지 않는다
python3 -c 'import json,sys;p=sys.argv[1];r=json.load(open(p));[r.pop(k) for k in ("format","checkout")];r["inPlace"]=True;json.dump(r,open(p,"w"))' "$REC/$F.json"
gate ask "예전 형식 기록" "git push origin $F:refs/heads/main"
verify --sha "$F"

# 연결된 worktree에서 검증한 기록도 공통 git 폴더에 남아 본체에서 보인다
git worktree add -q --detach "$T/wt" "$F" && (cd "$T/wt" && verify) && git worktree remove "$T/wt"
gate pass "다른 worktree에서 검증" "git push origin $F:refs/heads/main"

# 실패·변경·시간 초과 뒤에도 임시 worktree가 남지 않는다
[ "$(git worktree list | wc -l | tr -d ' ')" = 1 ] && ok "app 임시 worktree 모두 정리" || no "app 임시 worktree 남음: $(git worktree list)"

# confirm 시간 초과: exit 124, 임시 worktree 정리
setup slow "$(echo "$POLICY" | sed 's/`sh confirm.sh {sha}`/`sleep 5; echo {sha}`/')"
sh "$S/py.sh" "$S/deploy_gate.py" confirm --timeout 1 >/dev/null; code=$?
[ $code -eq 124 ] && ok "confirm 시간 초과 exit 124" || no "confirm 시간 초과 exit $code"
[ "$(git worktree list | wc -l | tr -d ' ')" = 1 ] && ok "시간 초과 뒤 임시 worktree 정리" || no "시간 초과 뒤 임시 worktree 남음"

# 정책 없음: 프로필에 자동 배포 줄이 없으면 verify도 guard도 통과하지 않는다
setup plain ""
fresh; commit src/a.txt 1; verify; code=$?
[ $code -ne 0 ] && ok "정책 없음 verify exit $code" || no "정책 없음인데 verify 0"
gate ask "정책 없음" "git push origin $SHA:refs/heads/main"
# 정책 처음 넣기: SHA에만 정책이 있으면 base와 달라 ask
profile "$POLICY" > CLAUDE.md; git commit -qam policy; SHA=$(git rev-parse HEAD); verify
gate ask "정책 처음 넣기" "git push origin $SHA:refs/heads/main"
# 프로필 블록 밖의 정책 줄은 읽지 않는다
fresh; { profile ""; echo "$POLICY"; } > CLAUDE.md; git commit -qam outside; SHA=$(git rev-parse HEAD); verify; code=$?
[ $code -ne 0 ] && ok "블록 밖 정책 무시" || no "블록 밖 정책을 읽음"

exit $fail

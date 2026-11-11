#!/bin/sh
# 프로필 테스트 줄 재확인 알림(profile_check.py, SessionStart) 테스트: sh scripts/test_profile_check.sh
S=$(cd "$(dirname "$0")" && pwd)
T=$(cd "$(mktemp -d)" && pwd -P); trap 'rm -rf "$T"' EXIT
export HOME="$T/home" GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
mkdir -p "$HOME"
git config --global init.defaultBranch main
fail=0
has() {  # has <설명> <출력> <찾을 문자열>
  case "$2" in *"$3"*) echo "ok   $1" ;; *) echo "FAIL $1: '$3' 없음"; echo "$2" | sed 's/^/     /'; fail=1 ;; esac
}
lacks() {
  case "$2" in *"$3"*) echo "FAIL $1: '$3' 있음"; echo "$2" | sed 's/^/     /'; fail=1 ;; *) echo "ok   $1" ;; esac
}
start() { python3 -c 'import json,sys;print(json.dumps({"cwd":sys.argv[1]}))' "$1" | sh "$S/py.sh" "$S/session_start.py"; }
# repo <이름> <테스트 줄 값|-(프로필 없음)>: 프로필 CLAUDE.md만 있는 레포
repo() {
  R="$T/$1"; git init -q "$R"
  if [ "$2" = "-" ]; then echo "# readme" > "$R/README.md"
  else printf '<!-- 37writes-kit:profile:start -->\n- **구분**: 개인\n- **테스트**: %s\n<!-- 37writes-kit:profile:end -->\n' "$2" > "$R/CLAUDE.md"; fi
}
put() { mkdir -p "$(dirname "$R/$1")"; printf '%s\n' "$2" > "$R/$1"; }
commit() { git -C "$R" add -A && git -C "$R" commit -qm init; }
PKG_TEST='{"scripts":{"test":"vitest run","build":"vite build"}}'
MSG="재확인 필요"

repo bare "없음"; put web/package.json "$PKG_TEST"; commit
out=$(start "$R")
has "맨 없음 + 하위 폴더 package.json test → 알림" "$out" "$MSG"
has "근거 경로 표시" "$out" "web/package.json"
has "현재 값 표시" "$out" "프로필 테스트 줄이 '없음'인데"
has "기존 출력 유지" "$out" "kit:harness"

repo undecided "미정"; put tools/pyproject.toml '[tool.pytest.ini_options]'; put infra/p1/Makefile 'test:
	pnpm -s check'; commit
out=$(start "$R")
has "미정 + pyproject(pytest) → 알림" "$out" "tools/pyproject.toml"
has "미정 + 깊이 2 Makefile test 타깃 → 알림" "$out" "infra/p1/Makefile"

repo confirmed "없음 (확인함)"; put web/package.json "$PKG_TEST"; commit
out=$(start "$R")
lacks "없음 (확인함) → 알림 없음" "$out" "$MSG"
has "알림이 없어도 SessionStart는 정상" "$out" "kit:harness"

repo real '`pnpm test`'; put web/package.json "$PKG_TEST"; commit
lacks "실제 명령 → 알림 없음" "$(start "$R")" "$MSG"

repo notest "없음"; put web/package.json '{"scripts":{"build":"vite build","dev":"vite"}}'; put api/package.json '{"scripts":{"test":"echo \"Error: no test specified\" && exit 1"}}'; commit
lacks "scripts에 test 없는 package.json(+npm init 기본값)만 → 알림 없음" "$(start "$R")" "$MSG"

repo noprofile "-"; put web/package.json "$PKG_TEST"; commit
[ -z "$(start "$R")" ] && echo "ok   프로필 없는 레포 → 출력 없음" || { echo "FAIL 프로필 없는 레포에 출력"; fail=1; }

repo nodemods "없음"; put node_modules/lib/package.json "$PKG_TEST"; put web/examples/demo/package.json "$PKG_TEST"; put web/tests/fixtures/Cargo.toml '[package]'; commit
lacks "node_modules·examples·fixtures 안의 근거만 → 알림 없음" "$(start "$R")" "$MSG"

repo deep "없음"; put a/b/c/d/package.json "$PKG_TEST"; commit
lacks "깊이 4 폴더의 근거 → 알림 없음" "$(start "$R")" "$MSG"

repo untracked "없음"; put web/package.json "$PKG_TEST"
lacks "git에 없는 파일(ls-files 밖) → 알림 없음" "$(start "$R")" "$MSG"

repo many "미정"; for d in a b c d e; do put "$d/go.mod" "module $d"; done; put go.mod "module root"; commit
out=$(start "$R")
has "근거 최대 3개 (얕은 것 먼저)" "$out" "go.mod, a/go.mod, b/go.mod 등에"
lacks "4번째 근거는 표시 안 함" "$out" "c/go.mod"

# 시간 초과·실패는 조용히 None
python3 -c 'import sys;sys.path.insert(0,sys.argv[1]);import profile_check as p;sys.exit(0 if p.note(sys.argv[2],budget=0) is None else 1)' "$S" "$T/bare" \
  && echo "ok   시간 초과 → 알림 없음" || { echo "FAIL 시간 초과에 알림"; fail=1; }
python3 -c 'import sys;sys.path.insert(0,sys.argv[1]);import profile_check as p;sys.exit(0 if p.note(None) is None else 1)' "$S" \
  && echo "ok   잘못된 입력 → 예외 없이 None" || { echo "FAIL 잘못된 입력"; fail=1; }
# 값 판정
python3 - "$S" <<'PY' && echo "ok   값 판정 (미정·맨 없음 / 확인함·명령·줄 없음)" || { echo "FAIL 값 판정"; fail=1; }
import sys; sys.path.insert(0, sys.argv[1]); import profile_check as p
yes = ["없음", '"없음"', "`없음`", "미정", "없음 (수동 확인)", "미정 (나중에)"]
no = ["없음 (확인함)", "`npm test`", "web: pnpm test · tools: uv run pytest", None, ""]
bad = [v for v in yes if not p.unconfirmed(v)] + [v for v in no if p.unconfirmed(v)]
sys.exit(1 if bad else 0)
PY
exit $fail

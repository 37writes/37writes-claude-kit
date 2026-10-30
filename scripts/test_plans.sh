#!/bin/sh
# 진행 중 기획서 목록(plans.py)과 kit 프로젝트 판정 테스트: sh scripts/test_plans.sh
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
plan() {  # plan <파일> <상태> <완료 수> <미완료 수>
  mkdir -p "$(dirname "$1")"
  { printf -- '---\ntitle: %s 작업\nstatus: %s\n---\n\n# %s\n\n## 작업 단계\n' "$(basename "$1" .md)" "$2" "$(basename "$1" .md)"
    i=0; while [ $i -lt "$3" ]; do i=$((i + 1)); echo "- [x] S$i. 끝난 단계 — Coder"; done
    j=0; while [ $j -lt "$4" ]; do j=$((j + 1)); echo "- [ ] S$((i + j)). 남은 단계 $j — Coder — 완료 조건"; done
    printf '\n## 완료 기준\n- [ ] 이건 단계가 아니다\n'; } > "$1"
}
plans() { sh "$S/py.sh" "$S/plans.py" "$@"; }
PROFILE='<!-- 37writes-kit:profile:start -->
- **구분**: 개인
<!-- 37writes-kit:profile:end -->'

R="$T/repo"; git init -q "$R"; cd "$R" || exit 1
echo "$PROFILE" > CLAUDE.md
plan docs/plans/2026-01-01-alpha.md in-progress 1 2
plan docs/plans/2026-01-02-finished.md done 3 0
plan docs/plans/2026-01-03-dropped.md abandoned 1 1
plan docs/plans/2026-01-04-gone.md in-progress 0 2
plan docs/plans/2026-01-05-merged.md in-progress 1 1
plan docs/plans/2026-01-06-split.md in-progress 1 2
plan docs/plans/project.md in-progress 0 3
git add -A && git commit -qm init

# 오래된 worktree: 기본 브랜치에서 지우거나 done으로 바꾸기 전의 복사본
git worktree add -q -b old "$T/old"
git rm -q docs/plans/2026-01-04-gone.md
plan docs/plans/2026-01-05-merged.md done 2 0
git commit -qam "끝난 기획서 정리"
(cd "$T/old" && plan docs/plans/2026-01-04-gone.md in-progress 1 1)
# 다른 worktree의 진행 중 기획서와, 같은 기획서의 다른 진행도(충돌)
git worktree add -q -b feat "$T/feat"
(cd "$T/feat" && plan docs/plans/2026-01-07-beta.md in-progress 0 3 && plan docs/plans/2026-01-06-split.md in-progress 2 1)

out=$(plans)
has "현재 worktree 기획서" "$out" "2026-01-01-alpha 작업 · in-progress · main · $R · 남은 2/3 · S2. 남은 단계 1"
has "다른 worktree의 in-progress" "$out" "2026-01-07-beta 작업 · in-progress · feat · $T/feat · 남은 3/3"
lacks "done 제외" "$out" "finished"
lacks "abandoned 제외" "$out" "dropped"
lacks "기본 브랜치에서 지운 기획서의 오래된 복사본 제외" "$out" "gone"
lacks "기본 브랜치에서 done인 기획서의 오래된 복사본 제외" "$out" "merged"
lacks "project.md 제외" "$out" "project"
has "활성 복사본 충돌" "$out" "2026-01-06-split 작업 · 충돌: in-progress(main, 남은 2/3) / in-progress(feat, 남은 1/3)"
order=$(echo "$out" | grep -o "alpha\|beta" | tr '\n' ' ')
case "$order" in *alpha*beta*) echo "ok   현재 worktree 먼저 (순서)" ;; *) echo "FAIL 순서: $order"; fail=1 ;; esac
lacks "만들고 커밋 없는 브랜치는 병합으로 보지 않음" "$out" "상태 확인 필요"
first=$(plans --cwd "$T/feat" | sed -n 2p)
has "다른 worktree에서 실행하면 그쪽 먼저" "$first" "$T/feat"
out=$(plans --all)
has "--all은 오래된 복사본 표시" "$out" "2026-01-04-gone 작업 · 오래된 복사본($T/old)"
json=$(plans --json)
python3 -c 'import json,sys;e=json.loads(sys.argv[1]);s={x["path"].split("/")[-1]:x for x in e};sys.exit(0 if s["2026-01-06-split.md"]["conflict"] and not s["2026-01-01-alpha.md"]["conflict"] and "2026-01-04-gone.md" not in s else 1)' "$json" \
  && echo "ok   --json 충돌·제외" || { echo "FAIL --json: $json"; fail=1; }

# 브랜치는 병합됐는데 기획서가 done이 아니면 "상태 확인 필요"
git worktree add -q -b done-branch "$T/merged"
(cd "$T/merged" && plan docs/plans/2026-01-08-landed.md in-progress 1 1 && git add -A && git commit -qm landed)
git merge -q --ff-only done-branch && echo x > x.txt && git add x.txt && git commit -qm after
has "병합됐는데 미완료면 상태 확인 필요" "$(plans)" "2026-01-08-landed 작업 · in-progress · main · $R · 남은 1/2 · S2. 남은 단계 1 · 상태 확인 필요"

# 최대 5개 + 외 N개
L="$T/many"; git init -q "$L"
for n in 1 2 3 4 5 6 7; do plan "$L/docs/plans/2026-02-0$n-p$n.md" draft 0 1; done
out=$(plans --cwd "$L")
[ "$(echo "$out" | grep -c '^- 2026')" = 5 ] && echo "ok   최대 5개" || { echo "FAIL 5개 아님"; echo "$out"; fail=1; }
has "외 N개" "$out" "외 2개"
has "최근 기획서 먼저" "$(echo "$out" | sed -n 2p)" "p7"

# 프로필 없는 레포에서도 동작, 기획서·레포가 없으면 빈 출력
P="$T/noprofile"; git init -q "$P"; echo "# readme" > "$P/README.md"
plan "$P/docs/plans/2026-03-01-solo.md" approved 0 2
has "프로필 없는 레포" "$(plans --cwd "$P")" "2026-03-01-solo 작업 · approved"
E="$T/empty"; git init -q "$E"
[ -z "$(plans --cwd "$E")" ] && echo "ok   기획서 없으면 빈 출력" || { echo "FAIL 빈 출력 아님"; fail=1; }
[ "$(plans --cwd "$T" --json)" = "[]" ] && echo "ok   git 레포 아니면 []" || { echo "FAIL git 아님 --json"; fail=1; }

# kit 프로젝트 판정과 SessionStart 출력: 프로필 표시, 옛 devlog는 kit / docs/plans만 있거나 무관한 레포는 아님
D="$T/olddevlog"; git init -q "$D"; mkdir -p "$D/docs/devlog"
kit() { python3 -c 'import sys;sys.path.insert(0,sys.argv[1]);import kitlib;print(kitlib.kit_repo(sys.argv[2]) or "")' "$S" "$1"; }
start() { python3 -c 'import json,sys;print(json.dumps({"cwd":sys.argv[1]}))' "$1" | sh "$S/py.sh" "$S/session_start.py"; }
[ -n "$(kit "$R")" ] && echo "ok   프로필 표시 → kit" || { echo "FAIL 프로필 레포가 kit 아님"; fail=1; }
[ -n "$(kit "$D")" ] && echo "ok   옛 devlog 레포 → kit" || { echo "FAIL devlog 레포가 kit 아님"; fail=1; }
[ -z "$(kit "$P")" ] && echo "ok   docs/plans만 → kit 아님" || { echo "FAIL docs/plans만 있는 레포가 kit"; fail=1; }
[ -z "$(kit "$E")" ] && echo "ok   무관한 레포 → kit 아님" || { echo "FAIL 무관한 레포가 kit"; fail=1; }
out=$(start "$R")
has "SessionStart: harness 안내" "$out" "kit:harness"
has "SessionStart: 진행 중 기획서" "$out" "2026-01-07-beta"
lacks "SessionStart: devlog 언급 없음" "$out" "devlog"
[ -f "$(git -C "$R" rev-parse --git-path hooks)/commit-msg" ] && echo "ok   commit-msg 훅 설치" || { echo "FAIL 훅 설치 안 됨"; fail=1; }
has "SessionStart: 옛 devlog 레포" "$(start "$D")" "kit:harness"
[ -z "$(start "$P")" ] && echo "ok   SessionStart: docs/plans만 → 출력 없음" || { echo "FAIL docs/plans 레포에 출력"; fail=1; }
[ -z "$(start "$E")" ] && echo "ok   SessionStart: 무관한 레포 → 출력 없음" || { echo "FAIL 무관한 레포에 출력"; fail=1; }
[ ! -e "$HOME/.config/37writes-kit/repos.txt" ] && echo "ok   등록부를 쓰지 않음" || { echo "FAIL 등록부 생성"; fail=1; }
exit $fail

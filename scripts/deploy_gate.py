"""자동 배포 정책: 검증 기록을 남기고, guard가 push를 그 기록과 대조한다.

정책 (CLAUDE.md 프로필 블록 안의 한 줄, 없거나 형식이 틀리면 자동 배포 없음):
  - **자동 배포**: 허용 · 대상 `origin/main` · 검증 `npm ci && npm test` · 제외 `infra/**` · 확인 `sh scripts/check_deploy.sh {sha}`

사용: sh scripts/py.sh scripts/deploy_gate.py verify  [--repo DIR] [--sha REV]
      sh scripts/py.sh scripts/deploy_gate.py confirm [--repo DIR] [--sha REV] [--timeout 초]
- verify: 그 SHA의 임시 detached worktree에서 `검증`을 실행하고 <git-common-dir>/37writes-kit/deploy/<sha>.json에 남긴다.
  명령이 끝난 뒤 HEAD가 그 SHA가 아니거나 추적 파일이 바뀌었으면 실패(exit 3). 그 밖에는 exit = 검증 명령의 exit
- confirm: `확인`에 {sha}를 넣어 같은 방식의 임시 worktree에서 실행하고 같은 기록에 더한다. exit 0일 때만 배포 완료
- 임시 worktree는 끝나면(실패·시간 초과 포함) 지운다. 사용자 작업 폴더의 커밋 안 된 파일·ignored 파일은 결과에 영향을 주지 않는다
- 그 사이에 push는 `git push <원격> <40자리 SHA>:refs/heads/<브랜치>` 하나로 한다 (guard가 push_allowed로 대조)
guard는 샌드박스가 아니다. 기록 폴더 보호는 best-effort라 위조를 완전히 막지 못한다.
"""
import argparse
import contextlib
import datetime
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

import kitlib

POLICY_LINE = re.compile(r"^- \*\*자동 배포\*\*:\s*(.*)$", re.M)
KEYS = ("대상", "검증", "제외", "확인")
SHA40 = re.compile(r"[0-9a-f]{40}$")
SECRETS = (re.compile(r"AKIA[0-9A-Z]{16}"), re.compile(r"BEGIN .*PRIVATE KEY"))
LS_REMOTE_TIMEOUT = 5
RECORD_FORMAT = 2       # 형식 없는 예전 기록(제자리 실행 inPlace가 있던 때)은 guard가 통과시키지 않는다
CHECKOUT = "temp-worktree"
CHANGED_EXIT = 3        # 검증 명령은 exit 0인데 checkout이 바뀜
CHANGED_SHOWN = 10


def run_git(repo, *args, timeout=None):
    """(exit, stdout). 원격 접근에서 비밀번호 프롬프트로 멈추지 않게 터미널 입력을 막는다."""
    env = dict(os.environ, GIT_TERMINAL_PROMPT="0", GIT_ASKPASS="", SSH_ASKPASS="")
    try:
        r = subprocess.run(["git", "-C", repo, *args], capture_output=True, text=True, encoding="utf-8",
                           errors="replace", timeout=timeout, stdin=subprocess.DEVNULL, env=env)
    except (OSError, subprocess.TimeoutExpired):
        return None, ""
    return r.returncode, r.stdout


def parse_policy(line):
    """정책 줄의 값(`허용 · ...` 부분) → dict, 형식이 틀리면 None."""
    quoted = []
    masked = re.sub(r"`([^`]*)`", lambda m: quoted.append(m.group(1)) or f"\0{len(quoted) - 1}\0", line)
    parts = [p.strip() for p in masked.split("·")]
    if parts[0] != "허용":
        return None
    policy = {}
    for part in parts[1:]:
        m = re.match(r"(\S+)\s+(.+)$", part)
        if not m or m.group(1) not in KEYS or m.group(1) in policy:
            return None
        values = m.group(2).split(",")
        if not all(re.fullmatch(r"\s*\0\d+\0\s*", v) for v in values):
            return None
        policy[m.group(1)] = [quoted[int(re.search(r"\d+", v).group())] for v in values]
    if not all(k in policy for k in ("대상", "검증", "확인")):
        return None
    if len(policy["대상"]) != 1 or len(policy["검증"]) != 1 or len(policy["확인"]) != 1:
        return None
    remote, _, branch = policy["대상"][0].partition("/")
    if not remote or not re.fullmatch(r"[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*", branch):
        return None
    if "{sha}" not in policy["확인"][0] or not policy["검증"][0].strip():
        return None
    return {"remote": remote, "branch": branch, "verify": policy["검증"][0],
            "exclude": policy.get("제외", []), "confirm": policy["확인"][0]}


def policy_from_text(text):
    """CLAUDE.md 내용 → (원문 줄, 정책) 또는 (None, None). 프로필 블록 안의 줄 하나만 읽는다."""
    block = kitlib.profile_block(text or "")
    lines = POLICY_LINE.findall(block or "")
    if len(lines) != 1:
        return None, None
    policy = parse_policy(lines[0].strip())
    return (lines[0].strip(), policy) if policy else (None, None)


def policy_at(repo, rev):
    code, text = run_git(repo, "show", f"{rev}:CLAUDE.md")
    return policy_from_text(text if code == 0 else "")


def record_dir(repo):
    code, out = run_git(repo, "rev-parse", "--git-common-dir")
    if code != 0:
        return None
    common = out.strip()
    if not os.path.isabs(common):
        common = os.path.join(repo, common)
    return os.path.join(os.path.abspath(common), "37writes-kit", "deploy")


def load_record(repo, sha):
    folder = record_dir(repo)
    path = os.path.join(folder, f"{sha}.json") if folder else None
    if not path or not os.path.isfile(path):
        return None
    try:
        return json.loads(kitlib.read(path))
    except ValueError:
        return None


def save_record(repo, sha, record):
    folder = record_dir(repo)
    os.makedirs(folder, exist_ok=True)
    path = os.path.join(folder, f"{sha}.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(record, f, ensure_ascii=False, indent=2)
    return path


def resolve_sha(repo, rev):
    code, out = run_git(repo, "rev-parse", "--verify", "--quiet", f"{rev}^{{commit}}")
    return out.strip() if code == 0 else None


def now():
    return datetime.datetime.now().astimezone().isoformat(timespec="seconds")


def _glob(pattern):
    """제외 glob → 정규식. `**`는 폴더 경계를 넘고 `*`·`?`는 넘지 않는다."""
    out, i = "", 0
    while i < len(pattern):
        if pattern.startswith("**/", i):
            out, i = out + "(?:.*/)?", i + 3
        elif pattern.startswith("**", i):
            out, i = out + ".*", i + 2
        elif pattern[i] == "*":
            out, i = out + "[^/]*", i + 1
        elif pattern[i] == "?":
            out, i = out + "[^/]", i + 1
        else:
            out, i = out + re.escape(pattern[i]), i + 1
    return re.compile(out + "$")


def excluded(paths, globs):
    patterns = [_glob(g.strip().lstrip("/")) for g in globs]
    return [p for p in paths if any(r.match(p) for r in patterns)]


def push_allowed(repo, args, global_opts=()):
    """guard용: 이 push가 자동 배포 정책 안인가 → (허용 여부, 어긋난 항목)."""
    # 1. 명령 형식: git push <원격> <40자리 SHA>:refs/heads/<브랜치>, 옵션·전역 재정의 없음
    if global_opts:
        return False, f"git 전역 옵션 {' '.join(global_opts)}"
    if len(args) != 2 or any(a.startswith("-") for a in args):
        return False, "형식이 `git push <원격> <40자리 SHA>:refs/heads/<브랜치>` 하나가 아님"
    remote, refspec = args
    src, sep, dst = refspec.partition(":")
    if not sep or not SHA40.match(src):
        return False, "src가 전체 40자리 SHA가 아님 (브랜치 이름 push는 확인)"
    branch = dst[len("refs/heads/"):] if dst.startswith("refs/heads/") else dst
    if not branch or branch.startswith("refs/"):
        return False, "대상이 브랜치가 아님"
    if resolve_sha(repo, src) != src:
        return False, "SHA가 로컬 커밋이 아님"
    raw, policy = policy_at(repo, src)
    if not policy:
        return False, "보낼 SHA의 CLAUDE.md 프로필에 자동 배포 정책이 없음"
    if (remote, branch) != (policy["remote"], policy["branch"]):
        return False, f"대상 {remote}/{branch}가 정책 대상 {policy['remote']}/{policy['branch']}와 다름"

    # 2. 실제 보낼 곳과 원격의 지금 base
    _, fetch = run_git(repo, "remote", "get-url", "--all", remote)
    _, push = run_git(repo, "remote", "get-url", "--push", "--all", remote)
    fetch, push = fetch.split(), push.split()
    if len(fetch) != 1 or fetch != push:
        return False, "원격의 push URL이 fetch URL과 다르거나 하나가 아님"
    code, out = run_git(repo, "ls-remote", remote, f"refs/heads/{branch}", timeout=LS_REMOTE_TIMEOUT)
    rows = [r.split("\t") for r in out.splitlines() if r.strip()] if code == 0 else []
    if len(rows) != 1 or len(rows[0]) != 2 or rows[0][1] != f"refs/heads/{branch}":
        return False, "원격 브랜치 base를 확인하지 못함 (ls-remote 실패·시간 초과·브랜치 없음)"
    base = rows[0][0]
    if resolve_sha(repo, base) != base:
        return False, "원격 base 커밋이 로컬에 없음 (fetch 필요)"
    if run_git(repo, "merge-base", "--is-ancestor", base, src)[0] != 0:
        return False, "fast-forward가 아님"

    # 3. 정책은 base와 SHA에서 같아야 한다 (배포 범위 안에서 정책을 넣거나 바꾸면 사람이 승인)
    _, base_policy = policy_at(repo, base)
    if base_policy != policy:
        return False, "base와 SHA의 자동 배포 정책이 다름 (정책 추가·변경)"

    # 4. 검증 기록
    record = load_record(repo, src)
    if not record:
        return False, "이 SHA의 검증 기록이 없음 (deploy_gate.py verify)"
    _, tree = run_git(repo, "rev-parse", f"{src}^{{tree}}")
    if record.get("format") != RECORD_FORMAT or record.get("checkout") != CHECKOUT:
        return False, "예전 형식이거나 임시 checkout 검증이 아닌 기록 (deploy_gate.py verify 다시)"
    if record.get("sha") != src or record.get("tree") != tree.strip():
        return False, "검증 기록의 SHA·tree가 다름"
    if record.get("policy") != raw or record.get("command") != policy["verify"]:
        return False, "검증 기록의 정책·명령이 지금 정책과 다름"
    if record.get("exit") != 0 or record.get("commandExit") != 0:
        return False, "검증 실패 기록 (exit≠0)"
    if record.get("headAfter") != src or record.get("changed") != [] or record.get("changedCount") != 0:
        return False, "검증 중 checkout이 바뀐 기록 (HEAD·추적 파일)"

    # 5. 범위: 제외 경로와 시크릿
    _, names = run_git(repo, "diff", "--no-renames", "--name-only", base, src)
    hit = excluded([n for n in names.splitlines() if n], policy["exclude"])
    if hit:
        return False, f"제외 경로 변경 {hit[0]}" + (f" 외 {len(hit) - 1}개" if len(hit) > 1 else "")
    _, diff = run_git(repo, "diff", "--no-renames", base, src)
    if any(p.search(diff) for p in SECRETS):
        return False, "변경에 시크릿 패턴이 있음"
    return True, "자동 배포 정책 안"


def run_shell(command, cwd, log_path, timeout=None):
    with open(log_path, "w", encoding="utf-8") as log:
        try:
            return subprocess.run(command, shell=True, cwd=cwd, stdout=log, stderr=subprocess.STDOUT,
                                  stdin=subprocess.DEVNULL, timeout=timeout).returncode
        except subprocess.TimeoutExpired:
            log.write(f"\n[deploy_gate] {timeout}초 시간 초과\n")
            return 124


def tail(path, n=20):
    lines = kitlib.read(path).splitlines()
    return "\n".join(lines[-n:])


@contextlib.contextmanager
def temp_checkout(repo, sha):
    """그 SHA의 임시 detached worktree. 사용자 작업 폴더(커밋 안 된 파일·ignored 파일)는 쓰지도 건드리지도 않는다.
    성공·실패·시간 초과·중단 모두 끝나면 지운다. 만들지 못하면 None."""
    workdir = tempfile.mkdtemp(prefix="kit-deploy-")
    try:
        if run_git(repo, "worktree", "add", "--detach", workdir, sha)[0] != 0:
            yield None
        else:
            yield workdir
    finally:
        run_git(repo, "worktree", "remove", "--force", workdir)
        shutil.rmtree(workdir, ignore_errors=True)
        run_git(repo, "worktree", "prune")


def checkout_changes(workdir, sha):
    """명령 실행 뒤 임시 checkout이 그 SHA 그대로인가 → (HEAD, 바뀐 항목 목록). 새로 만든 추적 안 된 파일(빌드 결과 등)은 보지 않는다."""
    code, head = run_git(workdir, "rev-parse", "HEAD")
    head = head.strip() if code == 0 else None
    changed = [] if head == sha else [f"HEAD {head or '(읽지 못함)'}"]
    code, status = run_git(workdir, "status", "--porcelain", "--untracked-files=no")
    if code != 0:
        changed.append("git status 실패")
    else:
        changed += [line[3:] for line in status.splitlines() if line.strip()]
    return head, changed


def verify(repo, sha):
    raw, policy = policy_at(repo, sha)
    if not policy:
        print(f"자동 배포 정책이 없거나 형식이 틀립니다: {sha} 의 CLAUDE.md 프로필 블록")
        return 2
    folder = record_dir(repo)
    os.makedirs(folder, exist_ok=True)
    log_path = os.path.join(folder, f"{sha}.verify.log")
    with temp_checkout(repo, sha) as workdir:
        if not workdir:
            print(f"임시 worktree를 만들지 못했습니다: {sha}")
            return 2
        command_exit = run_shell(policy["verify"], workdir, log_path)
        head, changed = checkout_changes(workdir, sha)
    code = command_exit if command_exit != 0 else (CHANGED_EXIT if changed else 0)
    _, tree = run_git(repo, "rev-parse", f"{sha}^{{tree}}")
    path = save_record(repo, sha, {
        "format": RECORD_FORMAT, "sha": sha, "tree": tree.strip(), "policy": raw, "command": policy["verify"],
        "checkout": CHECKOUT, "commandExit": command_exit, "headAfter": head, "changed": changed[:CHANGED_SHOWN],
        "changedCount": len(changed), "exit": code, "time": now(), "log": log_path,
    })
    if code == 0:
        print(f"검증 통과: {sha}\n기록: {path}")
    elif command_exit == 0:
        shown = ", ".join(changed[:CHANGED_SHOWN]) + (f" 외 {len(changed) - CHANGED_SHOWN}개" if len(changed) > CHANGED_SHOWN else "")
        print(f"검증 실패: 검증 명령이 그 SHA의 checkout을 바꿨습니다 ({shown}): {sha}\n"
              f"기록: {path}\n검증 명령은 추적 파일을 고치지 않아야 한다 (예: --fix 대신 검사만)")
    else:
        print(f"검증 실패 (exit {code}): {sha}\n기록: {path}\n--- 로그 끝부분 ---\n{tail(log_path)}")
    return code


def confirm(repo, sha, timeout):
    raw, policy = policy_at(repo, sha)
    if not policy:
        print(f"자동 배포 정책이 없거나 형식이 틀립니다: {sha} 의 CLAUDE.md 프로필 블록")
        return 2
    folder = record_dir(repo)
    os.makedirs(folder, exist_ok=True)
    log_path = os.path.join(folder, f"{sha}.confirm.log")
    command = policy["confirm"].replace("{sha}", sha)
    with temp_checkout(repo, sha) as workdir:
        if not workdir:
            print(f"임시 worktree를 만들지 못했습니다: {sha}")
            return 2
        code = run_shell(command, workdir, log_path, timeout)
    record = load_record(repo, sha) or {"sha": sha, "policy": raw}
    record["confirm"] = {"command": command, "checkout": CHECKOUT, "sha": sha, "exit": code, "time": now(), "log": log_path}
    path = save_record(repo, sha, record)
    if code == 0:
        print(f"배포 확인 완료: {sha}\n기록: {path}")
    else:
        print(f"배포 확인 실패 (exit {code}): {sha}\n기록: {path}\n--- 로그 끝부분 ---\n{tail(log_path)}\n"
              "멈추고 반영된 SHA·실행 id·롤백 방법을 보고한다 (자동 롤백하지 않음)")
    return code


def main():
    p = argparse.ArgumentParser(description="자동 배포 검증 기록과 배포 확인")
    p.add_argument("action", choices=("verify", "confirm"))
    p.add_argument("--repo", default=os.getcwd())
    p.add_argument("--sha", default="HEAD")
    p.add_argument("--timeout", type=int, default=600, help="confirm 시간 제한(초)")
    args = p.parse_args()
    repo = kitlib.git(args.repo, "rev-parse", "--show-toplevel")
    sha = resolve_sha(repo, args.sha) if repo else None
    if not sha:
        print(f"git 레포나 커밋을 찾지 못했습니다: {args.repo} {args.sha}")
        return 2
    return verify(repo, sha) if args.action == "verify" else confirm(repo, sha, args.timeout)


if __name__ == "__main__":
    sys.exit(main())

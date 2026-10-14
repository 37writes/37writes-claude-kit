"""여러 kit 프로젝트의 devlog 항목을 기간으로 모아 JSON으로 출력한다 (/kit:weekly용).

사용: python collect_devlog.py --since 2026-10-07 --until 2026-10-13 [--root 경로 ...]
- 기본: 등록부(~/.config/37writes-kit/repos.txt)의 레포. 세션 시작 훅과 /kit:init이 등록한다
- --root를 주면 그 아래에서 docs/devlog/ 가 있는 git 레포를 추가로 찾는다 (깊이 4)
- 각 레포의 프로필 구분(회사/대학원/개인), 기간 내 devlog 항목, 내 커밋 수(type별)를 모은다
"""
import argparse
import os
import re
from datetime import date

import kitlib

HEADER = re.compile(r"^## (\d{4}-\d{2}-\d{2}) · (\S+) · (.+)$", re.M)
CATEGORY = re.compile(r"\*\*구분\*\*:\s*(\S+)")
COMMIT_TYPE = re.compile(r"^(\w+)(\(.+?\))?!?: ")
SKIP_DIRS = {"node_modules", ".git", "build", "install", "log", "bin", "obj", "dist", ".venv", "venv", "Library"}


def find_repos(roots, max_depth=4):
    repos = []
    for root in roots:
        root = os.path.expanduser(root)
        base_depth = root.rstrip(os.sep).count(os.sep)
        for path, dirs, _ in os.walk(root):
            if os.path.isdir(os.path.join(path, "docs", "devlog")) and os.path.exists(os.path.join(path, ".git")):
                repos.append(path)
                dirs[:] = []
                continue
            if path.count(os.sep) - base_depth >= max_depth:
                dirs[:] = []
            else:
                dirs[:] = [d for d in dirs if d not in SKIP_DIRS and not d.startswith(".")]
    return sorted(set(repos))


def entries(repo, since, until):
    found = []
    for f in kitlib.devlog_files(repo):
        text = kitlib.read(f)
        parts = HEADER.split(text)
        # split 결과: [머리말, 날짜, OS, 브랜치, 본문, 날짜, OS, 브랜치, 본문, ...]
        for i in range(1, len(parts), 4):
            date, os_name, branch, body = parts[i:i + 4]
            if since <= date <= until:
                found.append({"date": date, "os": os_name, "branch": branch.strip(), "body": body.strip()})
    return found


def commits(repo, since, until):
    """내 커밋 수(type별). user.email이 없으면 내 커밋을 가릴 수 없으므로 None."""
    email = kitlib.git(repo, "config", "user.email")
    if not email:
        return None
    log = kitlib.git(repo, "log", "--all", "--no-merges", f"--since={since} 00:00", f"--until={until} 23:59",
                     f"--author={email}", "--format=%s") or ""
    counts = {}
    for subject in log.splitlines():
        m = COMMIT_TYPE.match(subject)
        t = m.group(1) if m else "기타"
        counts[t] = counts.get(t, 0) + 1
    return counts


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--since", required=True, type=date.fromisoformat)
    ap.add_argument("--until", required=True, type=date.fromisoformat)
    ap.add_argument("--root", action="append")
    args = ap.parse_args()
    since, until = args.since.isoformat(), args.until.isoformat()

    result = []
    repos = sorted({kitlib.canonical(r) for r in kitlib.registered_repos() + find_repos(args.root or [])})
    for repo in repos:
        claude_md = os.path.join(repo, "CLAUDE.md")
        m = CATEGORY.search(kitlib.read(claude_md)) if os.path.exists(claude_md) else None
        items = entries(repo, since, until)
        counts = commits(repo, since, until)
        if items or counts:
            result.append({
                "repo": os.path.basename(repo),
                "path": repo,
                "category": m.group(1) if m else "미지정",
                "entries": items,
                "commits": counts if counts is not None else "user.email 미설정으로 집계 안 함",
            })
    kitlib.emit({"since": since, "until": until, "projects": result})


if __name__ == "__main__":
    main()

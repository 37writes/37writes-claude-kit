"""37writes-kit 훅 스크립트 공통 함수."""
import json
import os
import re
import subprocess
import sys

# 윈도우 콘솔(cp949)에서도 한글 출력이 깨지지 않게
for stream in (sys.stdout, sys.stderr):
    try:
        stream.reconfigure(encoding="utf-8")
    except Exception:
        pass

DEVLOG_DIR = os.path.join("docs", "devlog")
DEVLOG_FILE = re.compile(r"^\d{4}-\d{2}\.md$")


def read_input():
    try:
        return json.load(sys.stdin)
    except Exception:
        return {}


def git(repo, *args):
    r = subprocess.run(["git", "-C", repo, *args], capture_output=True, text=True,
                       encoding="utf-8", errors="replace")
    return r.stdout.strip() if r.returncode == 0 else None


def kit_repo(cwd):
    """kit-init을 거친 레포(= docs/devlog가 있는 git 레포)의 루트, 아니면 None."""
    root = git(cwd, "rev-parse", "--show-toplevel")
    if root and os.path.isdir(os.path.join(root, DEVLOG_DIR)):
        return root
    return None


def devlog_files(repo):
    d = os.path.join(repo, DEVLOG_DIR)
    return [os.path.join(d, f) for f in sorted(os.listdir(d)) if DEVLOG_FILE.match(f)]


def read(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read()


def emit(obj):
    print(json.dumps(obj, ensure_ascii=False))

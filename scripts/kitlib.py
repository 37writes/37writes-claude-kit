"""37writes-kit 훅 스크립트 공통 함수."""
import json
import os
import subprocess
import sys

# 윈도우 콘솔(cp949)에서도 한글 출력이 깨지지 않게
for stream in (sys.stdout, sys.stderr):
    try:
        stream.reconfigure(encoding="utf-8")
    except Exception:
        pass

CONFIG_DIR = os.path.join(os.path.expanduser("~"), ".config", "37writes-kit")
PROFILE_START = "<!-- 37writes-kit:profile:start -->"
PROFILE_END = "<!-- 37writes-kit:profile:end -->"


def read_input():
    try:
        return json.load(sys.stdin)
    except Exception:
        return {}


def git(repo, *args, timeout=None):
    try:
        r = subprocess.run(["git", "-C", repo, *args], capture_output=True, text=True,
                           encoding="utf-8", errors="replace", timeout=timeout)
    except (OSError, subprocess.TimeoutExpired):
        return None
    return r.stdout.strip() if r.returncode == 0 else None


def read(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read()


def profile_block(text):
    """CLAUDE.md 내용에서 kit 프로필 블록 안쪽, 없으면 None."""
    start = text.find(PROFILE_START)
    if start == -1:
        return None
    end = text.find(PROFILE_END, start)
    return text[start + len(PROFILE_START):end if end != -1 else len(text)]


def kit_repo(cwd):
    """kit 프로젝트(CLAUDE.md에 프로필 표시가 있는 git 레포)의 루트, 아니면 None."""
    root = git(cwd, "rev-parse", "--show-toplevel")
    if not root:
        return None
    claude_md = os.path.join(root, "CLAUDE.md")
    if os.path.isfile(claude_md) and PROFILE_START in read(claude_md):
        return root
    # 호환: 프로필 표시 없이 docs/devlog만 있는 예전 kit 레포도 commit-msg 훅 설치가 꺼지지 않게
    if os.path.isdir(os.path.join(root, "docs", "devlog")):
        return root
    return None


def canonical(path):
    """심볼릭 링크, 슬래시 방향, 대소문자(윈도우) 차이를 없앤 경로."""
    return os.path.normcase(os.path.realpath(path))


def emit(obj):
    print(json.dumps(obj, ensure_ascii=False))

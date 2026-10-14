"""37writes-kit commit-msg 훅을 레포에 설치한다.

사용: python install_githook.py [레포 경로]
- 이미 kit 훅이면 최신 버전으로 갱신
- 다른 훅이 있거나 core.hooksPath(husky 등)를 쓰는 레포는 건드리지 않고 알린다
"""
import os
import shutil
import stat
import subprocess
import sys

MARKER = "37writes-claude-kit commit-msg"
KIT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(KIT_ROOT, "githooks", "commit-msg")


def git(repo, *args):
    r = subprocess.run(["git", "-C", repo, *args], capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else None


def install(repo):
    """설치 결과를 (상태, 메시지)로 돌려준다. 상태: installed|updated|ok|skipped"""
    if git(repo, "config", "core.hooksPath"):
        return "skipped", "core.hooksPath가 설정된 레포라 commit-msg 훅을 설치하지 않았습니다"
    hooks_dir = git(repo, "rev-parse", "--git-path", "hooks")
    if hooks_dir is None:
        return "skipped", "git 레포가 아닙니다"
    if not os.path.isabs(hooks_dir):
        hooks_dir = os.path.join(repo, hooks_dir)
    os.makedirs(hooks_dir, exist_ok=True)
    target = os.path.join(hooks_dir, "commit-msg")

    with open(SOURCE, encoding="utf-8") as f:
        new = f.read()
    if os.path.exists(target):
        with open(target, encoding="utf-8", errors="replace") as f:
            old = f.read()
        if MARKER not in old:
            return "skipped", f"기존 commit-msg 훅이 있어 덮어쓰지 않았습니다: {target}"
        if old == new:
            return "ok", "commit-msg 훅이 최신입니다"
        status = "updated"
    else:
        status = "installed"

    shutil.copyfile(SOURCE, target)
    os.chmod(target, os.stat(target).st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
    return status, f"commit-msg 훅 {'설치' if status == 'installed' else '갱신'}: {target}"


if __name__ == "__main__":
    repo = sys.argv[1] if len(sys.argv) > 1 else os.getcwd()
    _, message = install(repo)
    print(message)

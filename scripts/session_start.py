"""SessionStart: kit 레포면 git 훅을 맞추고, 최근 devlog의 '다음 할 일'을 Claude에게 알려준다."""
import json
import os
import re
import subprocess

import kitlib
from install_githook import install

data = kitlib.read_input()
repo = kitlib.kit_repo(data.get("cwd") or os.getcwd())
if not repo:
    raise SystemExit(0)

lines = ["[37writes-kit] kit 프로젝트입니다. 프로필은 CLAUDE.md, 작업 로그는 docs/devlog/ 에 있습니다."]

kitlib.register(repo)

status, message = install(repo)
if status != "ok":
    lines.append(message)

files = kitlib.devlog_files(repo)
if files:
    text = kitlib.read(files[-1])
    entries = re.split(r"(?m)^(?=## )", text)
    last = entries[-1].strip() if entries and entries[-1].startswith("## ") else ""
    if last:
        header = last.splitlines()[0]
        todo = re.search(r"(?ms)^\*\*다음 할 일\*\*\s*\n(.*?)(?=^\*\*|\Z)", last)
        lines.append(f"최근 devlog: {header[3:]}")
        if todo and todo.group(1).strip():
            lines.append("다음 할 일:\n" + todo.group(1).strip())



def kit_feedback(repo):
    """kit 레포 자신이면: 열린 feedback 이슈와 로컬 대기 목록을 알려준다."""
    if "37writes-claude-kit" not in (kitlib.git(repo, "remote", "get-url", "origin") or ""):
        return []
    notes = []
    try:
        r = subprocess.run(["gh", "issue", "list", "-R", "37writes/37writes-claude-kit", "--label", "feedback",
                            "--state", "open", "--json", "number,title", "--limit", "20"],
                           capture_output=True, text=True, encoding="utf-8", timeout=6)
        issues = json.loads(r.stdout) if r.returncode == 0 else []
    except Exception:
        issues = []
    if issues:
        notes.append(f"열린 feedback 이슈 {len(issues)}개:\n" +
                     "\n".join(f"- #{i['number']} {i['title']}" for i in issues))
    pending = os.path.join(os.path.dirname(kitlib.REGISTRY), "feedback-pending.md")
    if os.path.exists(pending) and kitlib.read(pending).strip():
        notes.append(f"이슈로 옮기지 못한 feedback 대기 목록이 있습니다: {pending}")
    return notes


lines.extend(kit_feedback(repo))

kitlib.emit({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": "\n".join(lines),
    }
})

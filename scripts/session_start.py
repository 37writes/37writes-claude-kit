"""SessionStart: kit 레포면 git 훅을 맞추고, 최근 devlog의 '다음 할 일'을 Claude에게 알려준다."""
import os
import re

import kitlib
from install_githook import install

data = kitlib.read_input()
repo = kitlib.kit_repo(data.get("cwd") or os.getcwd())
if not repo:
    raise SystemExit(0)

lines = ["[37writes-kit] kit 프로젝트입니다. 프로필은 CLAUDE.md, 작업 로그는 docs/devlog/ 에 있습니다."]

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

kitlib.emit({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": "\n".join(lines),
    }
})

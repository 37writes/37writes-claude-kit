"""Stop: devlog에 기록되지 않은 최근 커밋이 생기면 한 번 알려준다."""
import os

import kitlib

data = kitlib.read_input()
if data.get("stop_hook_active"):
    raise SystemExit(0)
repo = kitlib.kit_repo(data.get("cwd") or os.getcwd())
if not repo:
    raise SystemExit(0)

log = kitlib.git(repo, "log", "--since=3.days", "--no-merges", "--format=%h %s") or ""
logged = "".join(kitlib.read(f) for f in kitlib.devlog_files(repo))
unlogged = [line for line in log.splitlines()
            if line and not line.split(" ", 1)[1].startswith("docs(devlog)")
            and line[:7] not in logged]
if not unlogged:
    raise SystemExit(0)

# 같은 커밋으로 매번 알리지 않도록, 이미 알린 커밋을 기억한다
git_dir = kitlib.git(repo, "rev-parse", "--absolute-git-dir")
state = os.path.join(git_dir, "37writes-kit-reminded")
reminded = set(kitlib.read(state).split()) if os.path.exists(state) else set()
new = [line for line in unlogged if line[:7] not in reminded]
if not new:
    raise SystemExit(0)
with open(state, "a", encoding="utf-8") as f:
    f.write("".join(line[:7] + "\n" for line in new))

kitlib.emit({"systemMessage": f"📝 devlog에 없는 커밋 {len(unlogged)}개 → /kit:devlog 로 기록할 수 있어요"})

"""/kit:blog 출발 세션용: 블로그 본체 worktree에서 탭 이름이 '블로그 코디네이터'인 Claude 터미널을 찾는다.

터미널 행의 title은 에이전트가 자동으로 붙이는 제목이라, 사용자가 정한 탭 이름은 visualLayouts의 탭에서만 읽힌다.
출력(JSON): {"mainWorktreeId": ..., "coordinator": <handle 또는 null>, "candidates": [<handle>...]}
사용: py.sh blog_coordinator.py [블로그 본체 경로]
"""
import json
import os
import subprocess
import sys

TITLE = "블로그 코디네이터"
ORCA = os.environ.get("ORCA_CLI_COMMAND") or "orca"


def orca(*args):
    out = subprocess.run([ORCA, *args, "--json"], capture_output=True, text=True, encoding="utf-8")
    if out.returncode != 0:
        raise RuntimeError(f"{ORCA} {' '.join(args)}: {(out.stderr or out.stdout).strip()}")
    return json.loads(out.stdout).get("result", {})


def handles_under(node):
    """탭 안의 pane 트리(분할 포함)에서 터미널 handle을 모은다."""
    if isinstance(node, dict):
        if node.get("type") == "terminal" and node.get("handle"):
            yield node["handle"]
        for v in node.values():
            yield from handles_under(v)
    elif isinstance(node, list):
        for v in node:
            yield from handles_under(v)


def coordinator_tabs(node):
    if isinstance(node, dict):
        for tab in node.get("tabs") or []:
            if isinstance(tab, dict) and tab.get("title") == TITLE:
                yield tab
        for v in node.values():
            yield from coordinator_tabs(v)
    elif isinstance(node, list):
        for v in node:
            yield from coordinator_tabs(v)


def main():
    main_path = os.path.realpath(os.path.expanduser(sys.argv[1] if len(sys.argv) > 1 else "~/Documents/dev/tech-blog"))
    worktrees = orca("worktree", "list", "--repo", f"path:{main_path}").get("worktrees", [])
    main_id = next((w["id"] for w in worktrees
                    if os.path.realpath(w["id"].split("::", 1)[-1]) == main_path), None)
    if not main_id:
        raise RuntimeError(f"Orca에 블로그 본체 worktree가 없다: {main_path}")

    listing = orca("terminal", "list", "--worktree", f"id:{main_id}", "--include-visual-layouts", "--limit", "500")
    if listing.get("truncated"):
        raise RuntimeError("터미널 목록이 잘렸다 (--limit 500 초과)")
    claude = {t["handle"] for t in listing.get("terminals", [])
              if t.get("agentIdentity") == "claude" and t.get("connected")}
    found = []
    for tab in coordinator_tabs(listing.get("visualLayouts")):
        found += [h for h in handles_under(tab.get("panes")) if h in claude and h not in found]

    print(json.dumps({
        "mainWorktreeId": main_id,
        "coordinator": found[0] if len(found) == 1 else None,
        "candidates": found,
    }, ensure_ascii=False))


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, ValueError) as e:
        print(json.dumps({"error": str(e)}, ensure_ascii=False))
        sys.exit(1)

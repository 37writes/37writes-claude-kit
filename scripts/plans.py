"""진행 중 기획서 목록: 레포의 모든 worktree에서 docs/plans/*.md를 모아 재개할 작업을 고른다.

사용: sh scripts/py.sh scripts/plans.py [--cwd DIR] [--json] [--all]
- kit 프로젝트 판정과 상관없이 git 레포면 동작한다 (프로필 없이 시작한 작업도 이어지게)
- 같은 상대 경로의 복사본을 모두 모은 뒤 판정한다
  - 어느 복사본이든 done·abandoned이거나 기본 브랜치에서 지워졌으면 끝난 작업 → 목록에서 뺀다 (--all이면 남은 복사본을 "오래된 복사본"으로)
  - 활성 복사본끼리 상태나 체크박스가 다르면 충돌 → 자동 재개 대상이 아니다 (사용자가 고른다)
- 출력: 현재 worktree 먼저, 최대 5개 + "외 N개". --json은 전체 목록(JSON 배열)
"""
import argparse
import json
import os
import re

import kitlib

PLANS_DIR = "docs/plans"
ACTIVE = ("draft", "approved", "in-progress")
FINISHED = ("done", "abandoned")
LIMIT = 5
CHECKBOX = re.compile(r"^- \[([ xX])\]\s*(.*)$")


def worktrees(root):
    """(경로, 브랜치) 목록. 지워진 worktree(prunable, 폴더 없음)는 뺀다."""
    out = kitlib.git(root, "worktree", "list", "--porcelain") or ""
    items = []
    for block in out.split("\n\n"):
        fields = dict((line.split(" ", 1) + [""])[:2] for line in block.splitlines() if line)
        path = fields.get("worktree")
        if not path or "bare" in fields or not os.path.isdir(path):
            continue
        branch = fields.get("branch", "")
        items.append((path, branch[len("refs/heads/"):] if branch.startswith("refs/heads/") else "(detached)"))
    return items or [(root, kitlib.git(root, "branch", "--show-current") or "(detached)")]


def default_branch(root):
    ref = kitlib.git(root, "symbolic-ref", "--quiet", "refs/remotes/origin/HEAD")
    for name in ([ref] if ref else []) + ["main", "master"]:
        if kitlib.git(root, "rev-parse", "--verify", "--quiet", name + "^{commit}"):
            return name[len("refs/remotes/"):] if name.startswith("refs/remotes/") else name
    return None


def deleted_on_default(root, base):
    """기본 브랜치에서 지워진 기록이 있고 지금 그 브랜치에 없는 기획서 경로."""
    if not base:
        return set()
    deleted = kitlib.git(root, "log", base, "--diff-filter=D", "--name-only", "--format=", "--", PLANS_DIR) or ""
    present = kitlib.git(root, "ls-tree", "-r", "--name-only", base, "--", PLANS_DIR) or ""
    return {p for p in deleted.splitlines() if p} - set(present.splitlines())


def parse_plan(text, name):
    meta = {}
    m = re.match(r"---\n(.*?)\n---", text, re.S)
    if m:
        for line in m.group(1).splitlines():
            key, _, value = line.partition(":")
            meta[key.strip()] = value.split("#")[0].strip()
    heading = re.search(r"(?m)^# (.+)$", text)
    title = meta.get("title") or (heading.group(1).strip() if heading else name)
    # 체크박스는 "## 작업 단계"에서만 센다 (없으면 파일 전체)
    section = re.search(r"(?ms)^## 작업 단계\s*\n(.*?)(?=^## |\Z)", text)
    boxes = [CHECKBOX.match(line) for line in (section.group(1) if section else text).splitlines()]
    boxes = [b for b in boxes if b]
    todo = [b.group(2) for b in boxes if b.group(1) == " "]
    first = re.split(r"\s+—\s+", todo[0])[0] if todo else ""
    return {"title": title, "status": meta.get("status", ""), "total": len(boxes),
            "remaining": len(todo), "next": first[:60]}


def collect(root):
    """상대 경로 → 복사본 목록."""
    copies = {}
    current = kitlib.canonical(root)
    for path, branch in worktrees(root):
        folder = os.path.join(path, PLANS_DIR)
        if not os.path.isdir(folder):
            continue
        for name in sorted(os.listdir(folder)):
            if not name.endswith(".md") or name == "project.md":
                continue
            try:
                plan = parse_plan(kitlib.read(os.path.join(folder, name)), name[:-3])
            except OSError:
                continue
            plan.update(worktree=path, branch=branch, current=kitlib.canonical(path) == current)
            copies.setdefault(f"{PLANS_DIR}/{name}", []).append(plan)
    return copies


def merged(root, branch, base):
    """기본 브랜치가 아닌 브랜치가 자기 커밋을 기본 브랜치에 병합했나 (상태를 done으로 못 바꾼 채 끝났을 수 있음).
    만든 뒤 커밋이 없는 브랜치는 기본 브랜치의 조상이어도 병합으로 보지 않는다 (만든 시점은 reflog의 첫 줄)."""
    if not base or branch in ("(detached)", base) or base.endswith("/" + branch):
        return False
    head, tip = kitlib.git(root, "rev-parse", branch), kitlib.git(root, "rev-parse", base)
    created = (kitlib.git(root, "reflog", "show", "--format=%H", f"refs/heads/{branch}") or "").splitlines()
    if not head or head == tip or not created or created[-1] == head:
        return False
    return kitlib.git(root, "merge-base", "--is-ancestor", head, base) is not None


def resolve(root, show_all=False):
    base = default_branch(root)
    gone = deleted_on_default(root, base)
    entries = []
    for rel, group in collect(root).items():
        active = [c for c in group if c["status"] in ACTIVE]
        if not active:
            continue
        finished = rel in gone or any(c["status"] in FINISHED for c in group)
        if finished:
            if show_all:
                for c in active:
                    entries.append(dict(c, path=rel, stale=True, conflict=False, needsCheck=False, copies=[]))
            continue
        active.sort(key=lambda c: not c["current"])
        distinct = {(c["status"], c["remaining"], c["total"]) for c in active}
        lead = dict(active[0], path=rel, stale=False, conflict=len(distinct) > 1,
                    copies=[{k: c[k] for k in ("worktree", "branch", "status", "remaining", "total")} for c in active])
        lead["needsCheck"] = any(merged(root, c["branch"], base) for c in active)
        entries.append(lead)
    # 현재 worktree 먼저, 그다음 최근 기획서(파일 이름의 날짜) 순
    entries.sort(key=lambda e: e["path"], reverse=True)
    entries.sort(key=lambda e: (e["stale"], not e["current"]))
    return entries


def line(e):
    if e["stale"]:
        return f"{e['title']} · 오래된 복사본({e['worktree']}) · 이미 끝난 작업"
    if e["conflict"]:
        variants = " / ".join(f"{c['status']}({c['branch']}, 남은 {c['remaining']}/{c['total']})" for c in e["copies"])
        return f"{e['title']} · 충돌: {variants} · 자동 재개하지 않음, 사용자가 고른다"
    parts = [e["title"], e["status"], e["branch"], e["worktree"], f"남은 {e['remaining']}/{e['total']}"]
    if e["next"]:
        parts.append(e["next"])
    if e["needsCheck"]:
        parts.append("상태 확인 필요(브랜치가 기본 브랜치에 병합됨)")
    return " · ".join(parts)


def text(entries, show_all=False):
    if not entries:
        return ""
    shown = entries if show_all else entries[:LIMIT]
    lines = ["진행 중 기획서:"] + [f"- {line(e)}" for e in shown]
    if len(entries) > len(shown):
        lines.append(f"- 외 {len(entries) - len(shown)}개 (`plans.py --all`)")
    return "\n".join(lines)


def main():
    p = argparse.ArgumentParser(description="진행 중 기획서 목록")
    p.add_argument("--cwd", default=os.getcwd())
    p.add_argument("--json", action="store_true")
    p.add_argument("--all", action="store_true", help="5개 제한 없이, 끝난 작업의 오래된 복사본까지")
    args = p.parse_args()
    root = kitlib.git(args.cwd, "rev-parse", "--show-toplevel")
    entries = resolve(root, args.all) if root else []
    if args.json:
        print(json.dumps(entries, ensure_ascii=False))
    elif entries:
        print(text(entries, args.all))


if __name__ == "__main__":
    main()

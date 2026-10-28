"""Claude Code 대화 기록(jsonl)에서 사용자·Claude의 글만 뽑는다. /kit:blog가 세션을 글감으로 쓸 때 사용.

사용:
  session_text.py <프로젝트 폴더 | 대화 .jsonl> [--list] [--session ID] [--grep 키워드]
  - 폴더면 그 폴더에서 연 대화 중 가장 최근 것을 쓴다 (--list로 목록, --session으로 선택)
  - 도구 호출과 도구 결과는 빼고 한 줄 표시만 남긴다
"""
import argparse
import glob
import json
import os
import re
import sys
from datetime import datetime

import kitlib  # noqa: F401  (윈도우 콘솔 utf-8 출력 설정)

PROJECTS = os.path.join(os.path.expanduser("~"), ".claude", "projects")


def project_dir(folder):
    """Claude Code는 폴더 경로의 영문자·숫자 외 문자를 '-'로 바꾼 이름으로 대화를 저장한다."""
    path = os.path.realpath(os.path.expanduser(folder))
    return os.path.join(PROJECTS, re.sub(r"[^A-Za-z0-9]", "-", path))


def sessions(folder):
    files = glob.glob(os.path.join(project_dir(folder), "*.jsonl"))
    return sorted(files, key=os.path.getmtime, reverse=True)


def records(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            try:
                yield json.loads(line)
            except ValueError:
                continue


def blocks(record):
    """(역할, 글) 목록. 도구 호출은 한 줄 표시, 도구 결과·메타 메시지는 뺀다."""
    if record.get("type") not in ("user", "assistant") or record.get("isMeta") or record.get("isSidechain"):
        return []
    role = record["type"]
    content = (record.get("message") or {}).get("content")
    if isinstance(content, str):
        return [(role, content)]
    out = []
    for b in content or []:
        if b.get("type") == "text" and b.get("text", "").strip():
            out.append((role, b["text"]))
        elif b.get("type") == "tool_use":
            inp = b.get("input") or {}
            hint = inp.get("description") or inp.get("file_path") or inp.get("command") or ""
            out.append(("tool", f"{b.get('name')}: {str(hint).splitlines()[0][:120] if hint else ''}"))
    return out


def first_prompt(path):
    for r in records(path):
        for role, text in blocks(r):
            if role == "user" and not text.startswith("<"):
                return text.strip().splitlines()[0][:80]
    return ""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("target", help="프로젝트 폴더 또는 대화 .jsonl")
    ap.add_argument("--list", action="store_true", help="대화 목록만 보기")
    ap.add_argument("--session", help="대화 ID (앞부분만 써도 됨)")
    ap.add_argument("--grep", help="이 키워드가 들어간 메시지만 (대소문자 무시)")
    args = ap.parse_args()

    if args.target.endswith(".jsonl"):
        path = args.target
    else:
        files = sessions(args.target)
        if not files:
            sys.exit(f"대화 기록 없음: {project_dir(args.target)}")
        if args.list:
            for f in files:
                when = datetime.fromtimestamp(os.path.getmtime(f)).strftime("%Y-%m-%d %H:%M")
                print(f"{when}  {os.path.basename(f)[:8]}  {first_prompt(f)}")
            return
        if args.session:
            files = [f for f in files if os.path.basename(f).startswith(args.session)]
            if not files:
                sys.exit(f"대화 없음: {args.session}")
        path = files[0]

    print(f"# {path}\n")
    for r in records(path):
        for role, text in blocks(r):
            if args.grep and args.grep.lower() not in text.lower():
                continue
            if role == "tool":
                print(f"  [도구] {text}")
            else:
                print(f"\n## [{role}] {(r.get('timestamp') or '')[:16]}\n{text.strip()}")


if __name__ == "__main__":
    main()

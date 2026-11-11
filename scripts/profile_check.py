"""프로필 테스트 줄 재확인: 값이 `미정`이나 예전 형식의 맨 "없음"인데 레포에 테스트 설정이 있으면 알림 한 줄.

SessionStart가 부른다. 프로필을 고치지 않고 알리기만 한다 (채우기는 init 보완).
`없음 (확인함)`과 실제 명령은 대상이 아니다 (실제 명령이 낡았는지 대조하는 것은 범위 밖).
전체를 BUDGET초 안에 끝내고, 넘기거나 실패하면 None (알림 없음).
"""
import json
import os
import re
import time

import kitlib

BUDGET = 2.0
MAX_DEPTH = 3          # 폴더 깊이: package.json = 0, web/package.json = 1, infra/p1/package.json = 2
MAX_SHOWN = 3
MAX_BYTES = 512 * 1024
# 테스트 근거로 보지 않는 폴더 (의존성 사본, 예제, 테스트 데이터)
SKIP_DIRS = {"node_modules", "vendor", "third_party", ".venv", "venv", "fixtures", "fixture", "__fixtures__",
             "examples", "example", "testdata", "test_data", "test-data", "test-fixtures"}
PRESENCE = {"pytest.ini", "tox.ini", "noxfile.py", "Cargo.toml", "go.mod"}
MAKEFILES = {"Makefile", "makefile", "GNUmakefile"}
TEST_LINE = re.compile(r"^- \*\*테스트\*\*:[ \t]*(.*)$", re.M)
MAKE_TEST = re.compile(r"^test[\w.-]*[ \t]*::?(?!=)", re.M)
PYPROJECT_TEST = re.compile(r"pytest|\btox\b|\bnox\b|unittest")


def test_value(block):
    """프로필 블록의 테스트 줄 값 (줄이 없으면 None)."""
    m = TEST_LINE.search(block or "")
    return m.group(1).strip() if m else None


def unconfirmed(value):
    """`미정`, 또는 확인 표시 없는 맨 "없음"이면 True. 실제 명령·`없음 (확인함)`·줄 없음은 False."""
    if value is None:
        return False
    v = value.strip().strip("`\"'“”").strip()
    if v.startswith("미정"):
        return True
    return v.startswith("없음") and "확인함" not in v


def candidates(paths):
    """git ls-files 경로 중 테스트 근거가 될 수 있는 파일 (얕은 것 먼저)."""
    out = []
    for p in paths:
        parts = p.split("/")
        if len(parts) - 1 > MAX_DEPTH or any(d in SKIP_DIRS for d in parts[:-1]):
            continue
        if parts[-1] in PRESENCE or parts[-1] in MAKEFILES or parts[-1] in ("package.json", "pyproject.toml"):
            out.append(p)
    return sorted(out, key=lambda p: (p.count("/"), p))


def is_evidence(name, text):
    """파일 이름과 내용으로 테스트 설정인지."""
    if name in PRESENCE:
        return True
    if name == "package.json":
        try:
            scripts = json.loads(text).get("scripts") or {}
        except (ValueError, AttributeError):
            return False
        if not isinstance(scripts, dict):
            return False
        for key, cmd in scripts.items():
            # npm init 기본값 "echo \"Error: no test specified\" && exit 1"은 테스트가 아니다
            if (key == "test" or key.startswith("test:")) and isinstance(cmd, str) and "no test specified" not in cmd:
                return True
        return False
    if name == "pyproject.toml":
        return bool(PYPROJECT_TEST.search(text))
    if name in MAKEFILES:
        return bool(MAKE_TEST.search(text))
    return False


def evidence(repo, paths, deadline):
    """근거 경로 목록 (최대 MAX_SHOWN개). 시간을 넘기면 None."""
    found = []
    for p in candidates(paths):
        if time.monotonic() > deadline:
            return None
        name = p.rsplit("/", 1)[-1]
        text = ""
        if name not in PRESENCE:
            try:
                with open(os.path.join(repo, p), encoding="utf-8", errors="replace") as f:
                    text = f.read(MAX_BYTES)
            except OSError:
                continue
        if is_evidence(name, text):
            found.append(p)
            if len(found) >= MAX_SHOWN:
                break
    return found


def message(value, found):
    return (f"프로필 테스트 줄이 '{value}'인데 {', '.join(found)} 등에 테스트 설정이 있습니다. "
            "재확인 필요 — 지휘 세션에서 kit:init 보완으로 채우세요 (워커는 무시).")


def note(repo, budget=BUDGET):
    """알림 한 줄 또는 None. 어떤 실패도 밖으로 내보내지 않는다."""
    try:
        deadline = time.monotonic() + budget
        claude_md = os.path.join(repo, "CLAUDE.md")
        if not os.path.isfile(claude_md):
            return None
        value = test_value(kitlib.profile_block(kitlib.read(claude_md)))
        if not unconfirmed(value):
            return None
        listed = kitlib.git(repo, "ls-files", "-z", timeout=max(0.1, deadline - time.monotonic()))
        if not listed or time.monotonic() > deadline:
            return None
        found = evidence(repo, [p for p in listed.split("\0") if p], deadline)
        return message(value.strip("`"), found) if found else None
    except Exception:
        return None

"""자리 비움(연속 작업) 모드: 사용자가 없는 동안 guard의 확인 창(ask)을 거절(deny) + 아침 목록으로 바꾼다.

사용자가 `!`나 메뉴 막대 앱으로 켠다:
    away.py on --until HH:MM | --for 3h [--mode away|awake] [--json]
        awake = 잠자기 방지만 (확인 창·질문은 평소대로). 상태를 awake.json에 따로 둔다.
    away.py off [--json]
    away.py status [--json]
    away.py on ... --ticket '<레포 경로>::<스택>[::횟수]'   (배포 티켓. 사용자만. 실행은 away_deploy.py)
    away.py request --stack <스택> [--note 글] [--cwd 폴더]   (에이전트가 티켓 후보를 적음. 권한 아님)
    away.py report [--json] [--clear]
    away.py hook            (SessionStart·UserPromptSubmit·PreToolUse(AskUserQuestion)·Stop 훅, stdin = 훅 입력)
켜져 있는 동안: 질문 창은 거절 + 보류 목록, 글로 묻고 끝낸 턴은 조건이 맞으면 최대 2번 이어 가게 한다.
끝 코드: 0 성공, 1 예상 밖 오류, 2 인자 오류, 3 시작 점검 거부, 4 절전 방지 시작 실패.
guard.py가 active()·queue_add()·observe_old()를 import해서 쓴다. 같은 계정(HOME)의 모든 레포·세션이 상태 하나를 본다.
"""
import argparse
import datetime
import hashlib
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import time

import kitlib

DIR = os.path.join(kitlib.CONFIG_DIR, "away")
STATE = os.path.join(DIR, "state.json")
AWAKE = os.path.join(DIR, "awake.json")   # 잠자기 방지만 켠 상태. 예전 스크립트는 이 파일을 읽지 않아 "꺼짐"으로 본다
STALE = os.path.join(DIR, "stale")        # 표식 없이 불린 guard(예전 hooks.json으로 뜬 Claude 프로세스) 기록
QUEUE = os.path.join(DIR, "queue.jsonl")
LOCK = os.path.join(DIR, "state.lock")
HOLDS = os.path.join(DIR, "holds.jsonl")
SESSIONS = os.path.join(DIR, "sessions")
REQUESTS = os.path.join(DIR, "requests.jsonl")
RUNS = os.path.join(DIR, "runs.jsonl")
LOGS = os.path.join(DIR, "logs")
MAX_TICKET_USES = 3
STACK_NAME = re.compile(r"[A-Za-z][A-Za-z0-9-]{0,127}")
MAX_BLOCKS = 2        # 한 회차(사용자 입력 사이)에 턴 종료를 이어 가게 하는 횟수
PROGRESS_TOOLS = 3    # 두 번째 재개 전에 필요한 도구 호출 수 (헛도는 재개 방지)
SESSION_KEEP = 2 * 86400
STALE_SEEN_EVERY = 300    # 예전 탭 기록을 다시 쓰는 간격
STALE_NOTE_EVERY = 1800   # 예전 탭에 안내를 다시 넣는 간격
STALE_GUESS = 2 * 3600    # pid로 확인하지 못할 때 "아직 떠 있다"고 보는 시간
MAX_SECONDS = 12 * 3600
DISK_WARN_BYTES = 5 * 1024 ** 3
LID_NOTE = "뚜껑을 닫으면 잠듭니다 (전원 연결·뚜껑 열림 동안만 절전을 막습니다)"
BATTERY_NOTE = "배터리 상태입니다. 키 입력이 없을 때의 잠자기만 막고, 뚜껑을 닫거나 배터리가 떨어지면 잠듭니다"


class Fail(Exception):
    def __init__(self, code, error, message):
        super().__init__(message)
        self.code, self.error, self.message = code, error, message


# ── 상태 ─────────────────────────────────────────────────────────────

def load_state(path=None):
    """상태 파일 내용 (기본 state.json = 자리 비움, AWAKE = 잠자기 방지만). 없거나 깨졌거나 형식이 다르면 None."""
    try:
        with open(path or STATE, encoding="utf-8") as f:
            st = json.load(f)
    except (OSError, ValueError):
        return None
    if not isinstance(st, dict):
        return None
    until, started = st.get("until"), st.get("started")
    for value in (until, started):
        if isinstance(value, bool) or not isinstance(value, (int, float)):
            return None
    if until - started > MAX_SECONDS + 60:
        return None
    return st


def active(now=None):
    """유효한(파일 있음, 형식 정상, now < until) 자리 비움 상태, 아니면 None."""
    st = load_state()
    now = time.time() if now is None else now
    return st if st and now < st["until"] else None


def awake(now=None):
    """유효한 잠자기 방지 상태 (자리 비움 아님: 확인 창·질문은 평소대로), 아니면 None."""
    st = load_state(AWAKE)
    now = time.time() if now is None else now
    return st if st and now < st["until"] else None


def hhmm(epoch):
    return datetime.datetime.fromtimestamp(epoch).strftime("%H:%M")


def iso(epoch):
    return datetime.datetime.fromtimestamp(epoch).astimezone().isoformat(timespec="seconds")


def ensure_dir():
    os.makedirs(DIR, mode=0o700, exist_ok=True)


def save_state(st, path=None):
    ensure_dir()
    path = path or STATE
    tmp = path + ".tmp"
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(st, f, ensure_ascii=False)
    os.chmod(tmp, 0o600)
    os.replace(tmp, path)


def remove_state(path=None):
    """상태 파일을 지운다. 지우지 못해 파일이 남으면 Fail (off가 성공으로 보이지 않게)."""
    try:
        os.remove(path or STATE)
    except FileNotFoundError:
        pass
    except OSError as e:
        raise Fail(1, "state_not_removed", f"상태 파일을 지우지 못했습니다 (지금 상태는 away.py status로 확인): {e}")


class state_lock:
    """on·off를 직렬화한다 (겹친 on이 caffeinate를 하나 남기지 않게). 최대 10초."""

    def __enter__(self):
        ensure_dir()
        self.f = open(LOCK, "w")
        try:
            import fcntl
        except ImportError:  # 윈도우: 잠금 없이
            return self
        deadline = time.time() + 10
        while True:
            try:
                fcntl.flock(self.f, fcntl.LOCK_EX | fcntl.LOCK_NB)
                return self
            except OSError:
                if time.time() > deadline:
                    self.f.close()
                    raise Fail(1, "busy", "다른 away.py on/off가 실행 중입니다. 잠시 뒤 다시 실행하세요")
                time.sleep(0.1)

    def __exit__(self, *exc):
        self.f.close()


# ── 전원 (macOS) ─────────────────────────────────────────────────────

def is_mac():
    return sys.platform == "darwin"


def run(args, timeout=5):
    try:
        r = subprocess.run(args, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=timeout)
    except (OSError, subprocess.TimeoutExpired):
        return None
    return r.stdout if r.returncode == 0 else None


def power():
    """{source: ac|battery|unknown, lid: open|closed|unknown}. macOS가 아니면 둘 다 unknown."""
    source = lid = "unknown"
    if is_mac():
        batt = run(["pmset", "-g", "batt"]) or ""
        if "'AC Power'" in batt:
            source = "ac"
        elif "'Battery Power'" in batt:
            source = "battery"
        clam = re.search(r'"AppleClamshellState"\s*=\s*(Yes|No)', run(["ioreg", "-r", "-k", "AppleClamshellState"]) or "")
        if clam:
            lid = "closed" if clam.group(1) == "Yes" else "open"
    return {"source": source, "lid": lid}


def proc_info(pid):
    """(시작 시각, 인자) 문자열. 프로세스가 없으면 None."""
    lstart = run(["ps", "-p", str(pid), "-o", "lstart="])
    args = run(["ps", "-p", str(pid), "-o", "args="])
    if not lstart or not args or not lstart.strip():
        return None
    return " ".join(lstart.split()), " ".join(args.split())


def ours(caff):
    """기록한 caffeinate가 지금도 그 프로세스인가 (pid + 시작 시각 + 인자. pid 재사용으로 남의 프로세스를 죽이지 않게)."""
    if not isinstance(caff, dict) or not isinstance(caff.get("pid"), int):
        return False
    info = proc_info(caff["pid"])
    return bool(info and info == (caff.get("lstart"), caff.get("args")) and "caffeinate" in info[1])


def start_caffeinate(seconds):
    try:
        p = subprocess.Popen(["caffeinate", "-i", "-s", "-t", str(seconds)], stdin=subprocess.DEVNULL,
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    except OSError as e:
        raise Fail(4, "caffeinate_failed", f"caffeinate를 시작하지 못했습니다: {e}")
    # 실행 파일로 바뀐 것(ps 인자에 caffeinate)을 본 뒤 0.3초 더 살아 있어야 시작으로 본다.
    # 부하로 늦게 뜨면 0.3초만 기다려서는 실행 전 프로세스를 "살아 있음"으로 기록한다 (off가 못 끝냄).
    deadline, info = time.time() + 3, None
    while time.time() < deadline and p.poll() is None:
        info = proc_info(p.pid)
        if info and "caffeinate" in info[1]:
            break
        info = None
        time.sleep(0.05)
    if info:
        time.sleep(0.3)
        info = proc_info(p.pid) if p.poll() is None else None
    if not info or "caffeinate" not in info[1]:
        if p.poll() is None:
            p.terminate()
        raise Fail(4, "caffeinate_failed", "caffeinate가 시작되지 않았거나 바로 끝났습니다. 자리 비움 모드를 켜지 않았습니다")
    return {"pid": p.pid, "lstart": info[0], "args": info[1]}


def stop_caffeinate(caff):
    """우리 caffeinate면 끝내고, 그 pid의 절전 방지 assertion이 남지 않았는지 확인한다. 확인 못 하면 False."""
    if not isinstance(caff, dict) or not isinstance(caff.get("pid"), int):
        return True  # 띄운 적 없음 (macOS가 아님)
    pid = caff["pid"]
    if ours(caff):
        try:
            os.kill(pid, signal.SIGTERM)
        except OSError:
            pass
        deadline = time.time() + 3
        while ours(caff) and time.time() < deadline:
            time.sleep(0.1)
        if ours(caff):
            return False
    if not is_mac():
        return True
    assertions = run(["pmset", "-g", "assertions"])
    return assertions is not None and f"pid {pid}(" not in assertions


# ── 아침 목록 ────────────────────────────────────────────────────────

MASKS = [
    (re.compile(r"-----BEGIN[^-]*-----.*?(?:-----END[^-]*-----|$)"), "***"),
    (re.compile(r"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b"), "***"),
    (re.compile(r"(?i)\bBearer\s+\S+"), "Bearer ***"),
    (re.compile(r"""(?i)(--?[\w-]*(?:password|passwd|secret|token|api[_-]?key|credential)[\w-]*)[ =]+("[^"]*"?|'[^']*'?|\S+)"""), r"\1 ***"),
    (re.compile(r"""(?<![\w/.-])([A-Za-z_][\w.-]*)=("[^"]*"|'[^']*'|\S+)"""), r"\1=***"),
]


def mask(command):
    """아침 목록에 남길 명령: 공백 정리, `이름=값`의 값과 시크릿 패턴을 가리고, 길면 앞 150자 + 뒤 60자."""
    text = " ".join(command.split())
    for pattern, repl in MASKS:
        text = pattern.sub(repl, text)
    return text if len(text) <= 220 else text[:150] + " … " + text[-60:]


def mask_text(text, limit=300):
    """보류 목록에 남길 글(질문 요지): 가림은 mask와 같고 끝부분 limit자만 남긴다 (질문은 보통 끝에 있다)."""
    text = " ".join(str(text).split())
    for pattern, repl in MASKS:
        text = pattern.sub(repl, text)
    return text if len(text) <= limit else "… " + text[-limit:]


def mask_log(text):
    """로그에 쓸 여러 줄 글: 줄바꿈은 두고 값만 가린다."""
    text = str(text)
    for pattern, repl in MASKS:
        text = pattern.sub(repl, text)
    return text


def append_line(path, obj):
    """JSON 한 줄을 잠금 없이 O_APPEND로 덧붙인다 (훅이 기다리지 않게).
    일반 파일이 아니면(FIFO·장치·심볼릭 링크) 열다가 멈출 수 있어 비차단으로 열고 거부한다."""
    import stat
    ensure_dir()
    line = json.dumps(obj, ensure_ascii=False) + "\n"
    flags = os.O_WRONLY | os.O_APPEND | os.O_CREAT | getattr(os, "O_NONBLOCK", 0) | getattr(os, "O_NOFOLLOW", 0)
    fd = os.open(path, flags, 0o600)
    try:
        if not stat.S_ISREG(os.fstat(fd).st_mode):
            raise OSError("목록이 일반 파일이 아닙니다")
        os.write(fd, line.encode("utf-8"))
    finally:
        os.close(fd)


def read_lines(path):
    """jsonl의 dict 줄들. 못 읽거나 깨진 줄은 건너뛴다."""
    rows = []
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            for line in f:
                try:
                    row = json.loads(line)
                except ValueError:
                    continue
                if isinstance(row, dict):
                    rows.append(row)
    except OSError:
        pass
    return rows


def queue_add(repo, reasons, command, session=None):
    """거절한 명령 한 줄을 덧붙인다 (append_line). 중복은 report가 묶는다."""
    key = hashlib.sha256((repo + "\0" + " ".join(command.split())).encode("utf-8")).hexdigest()[:16]
    append_line(QUEUE, {"key": key, "ts": int(time.time()), "repo": repo, "reasons": list(reasons),
                        "command": mask(command), "session": session})
    return key


def queue_items():
    """같은 key(레포 + 명령)를 한 건으로 묶은 목록: {key, first, last, count, repo, reasons, command}."""
    items = {}
    try:
        with open(QUEUE, encoding="utf-8", errors="replace") as f:
            lines = f.readlines()
    except OSError:
        return []
    for line in lines:
        try:
            row = json.loads(line)
            key, ts = row["key"], int(row["ts"])
        except (ValueError, KeyError, TypeError):
            continue
        if key in items:
            items[key]["count"] += 1
            items[key]["last"] = iso(ts)
        else:
            items[key] = {"key": key, "first": iso(ts), "last": iso(ts), "count": 1, "repo": str(row.get("repo", "")),
                          "reasons": row.get("reasons") or [], "command": str(row.get("command", ""))}
    return list(items.values())


def hold_items():
    """보류된 질문: {ts, kind(question|stop), repo, session, text}. 같은 세션의 같은 글은 한 건."""
    items, seen = [], set()
    for row in read_lines(HOLDS):
        try:
            item = {"ts": iso(int(row["ts"])), "kind": str(row.get("kind", "")), "repo": str(row.get("repo", "")),
                    "session": str(row.get("session", "")), "text": str(row.get("text", ""))}
        except (KeyError, ValueError, TypeError, OverflowError, OSError):
            continue
        key = (item["session"], item["kind"], item["text"])
        if key not in seen:
            seen.add(key)
            items.append(item)
    return items


# ── 배포 티켓 ────────────────────────────────────────────────────────

def repo_key(path):
    """레포를 가리키는 키: 공통 git 폴더의 실제 경로 (worktree가 달라도 같은 레포면 같다). git이 아니면 폴더 경로."""
    common = kitlib.git(path, "rev-parse", "--path-format=absolute", "--git-common-dir", timeout=3)
    return os.path.realpath(common or path)


def profile_tests(root):
    """프로필 `- **테스트**:` 줄의 명령. (명령 목록 [{dir, cmd}], 설명). 줄이 없거나 미정·없음이면 ([], 이유),
    글만 있고 백틱 명령이 없으면 (None, 이유) → 티켓을 만들지 않는다."""
    text = kitlib.read(os.path.join(root, "CLAUDE.md")) if os.path.exists(os.path.join(root, "CLAUDE.md")) else ""
    m = re.search(r"^- \*\*테스트\*\*:[ \t]*(.*)$", text or "", re.M)
    if not m:
        return [], "프로필에 테스트 줄 없음"
    value = m.group(1).strip()
    if not value or value.startswith(("미정", "없음")):
        return [], "테스트 없음 (프로필: %s)" % (value or "빈 값")
    tests = []
    for part in re.split(r"\s+·\s+", value):
        folder = re.match(r"([\w./-]+):\s", part)
        for cmd in re.findall(r"`([^`]+)`", part):
            tests.append({"dir": folder.group(1) if folder else ".", "cmd": cmd})
    if not tests:
        return None, "프로필 테스트 줄에서 명령을 읽지 못했습니다 (명령을 `백틱`으로 감싸 적으세요)"
    return tests, "%d개" % len(tests)


def parse_ticket(spec, n):
    parts = spec.split("::")
    if len(parts) not in (2, 3) or not parts[0] or not parts[1]:
        raise Fail(2, "bad_ticket", f"--ticket은 '<레포 경로>::<스택>[::횟수]' 형식입니다 (받은 값: {spec})")
    path = os.path.realpath(os.path.expanduser(parts[0]))
    if not os.path.isdir(path):
        raise Fail(2, "bad_ticket", f"티켓의 레포 폴더가 없습니다: {parts[0]}")
    if not STACK_NAME.fullmatch(parts[1]):
        raise Fail(2, "bad_ticket", f"스택 이름이 올바르지 않습니다 (영문자로 시작, 영문·숫자·-): {parts[1]}")
    try:
        limit = int(parts[2]) if len(parts) == 3 else 1
    except ValueError:
        limit = 0
    if not 1 <= limit <= MAX_TICKET_USES:
        raise Fail(2, "bad_ticket", f"티켓 횟수는 1~{MAX_TICKET_USES}입니다 (받은 값: {parts[2]})")
    root = kitlib.git(path, "rev-parse", "--show-toplevel", timeout=3) or path
    tests, why = profile_tests(root)
    if tests is None:
        raise Fail(2, "bad_ticket", f"{root}: {why}")
    return {"id": f"t{n}-{os.urandom(4).hex()}", "repo": root, "repo_key": repo_key(path), "stack": parts[1], "limit": limit, "used": 0,
            "locked": False, "note": "", "tests": tests, "tests_note": why}


def tickets_of(st):
    return [t for t in (st.get("tickets") or []) if isinstance(t, dict)] if st else []


def ticket_view(t):
    return {"id": t.get("id"), "repo": t.get("repo"), "stack": t.get("stack"), "limit": t.get("limit"), "used": t.get("used"),
            "locked": bool(t.get("locked")), "note": t.get("note") or "", "tests": [mask_text(x.get("cmd", ""), 200) for x in t.get("tests") or []]}


CDK_DEPLOY = re.compile(r"\bcdk\b[^;&|]*?\bdeploy\s+([A-Za-z][A-Za-z0-9-]*)")


def ticket_candidates():
    """앱이 체크박스로 보여 줄 후보: 에이전트의 request와 아침 목록의 거절된 cdk deploy. 권한이 아니다."""
    found = {}
    for row in read_lines(REQUESTS):
        repo, stack = str(row.get("repo", "")), str(row.get("stack", ""))
        if repo and STACK_NAME.fullmatch(stack):
            found[(repo, stack)] = {"repo": repo, "stack": stack, "source": "request", "note": str(row.get("note", ""))}
    for it in queue_items():
        for stack in CDK_DEPLOY.findall(it["command"]):
            found.setdefault((it["repo"], stack), {"repo": it["repo"], "stack": stack, "source": "queue", "note": ""})
    return list(found.values())[:20]


def run_items():
    """티켓으로 실행한(또는 막힌) 배포 기록: {ts, repo, stack, result, code, steps, diff, log}."""
    items = []
    for row in read_lines(RUNS):
        try:
            items.append({"ts": iso(int(row["ts"])), "repo": str(row.get("repo", "")), "stack": str(row.get("stack", "")),
                          "result": str(row.get("result", "")), "code": row.get("code"), "steps": row.get("steps") or [],
                          "diff": row.get("diff") or {}, "log": row.get("log")})
        except (KeyError, ValueError, TypeError, OverflowError, OSError):
            continue
    return items


# ── 세션 기록 ────────────────────────────────────────────────────────

def session_path(session_id):
    name = re.sub(r"[^\w.-]", "_", str(session_id or ""))[:80].strip(".")
    return os.path.join(SESSIONS, name + ".json") if name else None


def load_session(session_id):
    path = session_path(session_id)
    try:
        with open(path, encoding="utf-8") as f:
            rec = json.load(f)
        return rec if isinstance(rec, dict) else {}
    except (OSError, ValueError, TypeError):
        return {}


def save_session(rec):
    path = session_path(rec.get("session"))
    if not path:
        return
    os.makedirs(SESSIONS, mode=0o700, exist_ok=True)
    tmp = f"{path}.{os.getpid()}.tmp"
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(rec, f, ensure_ascii=False)
    os.replace(tmp, path)


def repo_of(cwd):
    try:
        return kitlib.git(cwd, "rev-parse", "--show-toplevel", timeout=2) or cwd
    except Exception:
        return cwd


def touch_session(data, event, st, **changes):
    """세션 기록을 갱신해 돌려준다. 자리 비움 회차(state id)가 바뀌었으면 재개 횟수를 0으로."""
    sid = data.get("session_id")
    if not session_path(sid):
        return {}
    rec = load_session(sid)
    cwd = data.get("cwd") or rec.get("cwd") or ""
    state_id = st.get("id") if st else None
    if rec.get("state_id") != state_id:
        rec.update(blocks=0, block_size=0)
    rec.update(session=str(sid), cwd=cwd, transcript=data.get("transcript_path") or rec.get("transcript"),
               last_event=event, last_event_ts=int(time.time()), state_id=state_id)
    if rec.get("repo_cwd") != cwd:
        rec.update(repo=repo_of(cwd) if cwd else "", repo_cwd=cwd)
    rec.update(changes)
    save_session(rec)
    return rec


def session_items(now=None):
    """탭별 마지막 이벤트와 활동 시각 (대화 기록 파일의 mtime). 완료·멈춤을 판정하지 않는다."""
    now = time.time() if now is None else now
    items = []
    try:
        names = os.listdir(SESSIONS)
    except OSError:
        return []
    for name in names:
        if not name.endswith(".json"):
            continue
        rec = load_session(name[:-5])
        ts = rec.get("last_event_ts")
        if not isinstance(ts, (int, float)) or isinstance(ts, bool) or now - ts > SESSION_KEEP:
            continue
        try:
            activity = max(os.path.getmtime(rec.get("transcript") or ""), ts)
        except (OSError, TypeError):
            activity = ts
        items.append({"session": str(rec.get("session", "")), "repo": str(rec.get("repo", "")), "cwd": str(rec.get("cwd", "")),
                      "last_event": str(rec.get("last_event", "")), "last_event_at": iso(ts), "last_activity_at": iso(activity)})
    items.sort(key=lambda it: it["last_activity_at"], reverse=True)
    return items[:30]


def prune_sessions(now):
    try:
        for name in os.listdir(SESSIONS):
            path = os.path.join(SESSIONS, name)
            if now - os.path.getmtime(path) > SESSION_KEEP:
                os.remove(path)
    except OSError:
        pass


# ── 0.24 이전에 뜬 탭 (guard 표식 없음) ──────────────────────────────

def stale_path(key):
    name = re.sub(r"[^\w.-]", "_", str(key or ""))[:80].strip(".")
    return os.path.join(STALE, name + ".json") if name else None


def load_json(path):
    try:
        with open(path, encoding="utf-8") as f:
            rec = json.load(f)
        return rec if isinstance(rec, dict) else {}
    except (OSError, ValueError, TypeError):
        return {}


def num(value, default=0):
    return value if isinstance(value, (int, float)) and not isinstance(value, bool) else default


def stale_note(st):
    return (f"[37writes-kit] {hhmm(st['until'])}까지 자리 비움 모드입니다 (사용자가 자리에 없습니다). "
            "이 탭은 kit 업데이트 전에 시작해 질문 보류·이어 가기 훅이 없을 수 있습니다. 질문 창(AskUserQuestion)을 쓰지 말고, "
            "글로 묻고 턴을 끝내지 마세요. 되돌릴 수 있는 결정은 기본값으로 정해 기록하고, 확인이 필요한 일은 건너뛴 뒤 "
            "남은 다른 일을 하고 최종 보고의 `보류:`에 모읍니다. 거절된 명령은 바꾸거나 감싸서 다시 시도하지 않습니다.")


def observe_old(data, now=None):
    """표식 없이 불린 guard: 그 Claude 프로세스를 적고, 자리 비움 중이면 그 탭에 넣을 안내문을 돌려준다 (없으면 None).
    훅 등록은 프로세스 시작 때 고정되므로 키는 프로세스(CLAUDE_PID), 없으면 세션 ID. 외부 명령을 부르지 않는다."""
    now = time.time() if now is None else now
    pid = os.environ.get("CLAUDE_PID") or ""
    pid = int(pid) if pid.isdigit() and int(pid) > 1 else None
    sid = str(data.get("session_id") or "")
    path = stale_path(f"pid-{pid}" if pid else (f"sid-{sid}" if sid else ""))
    if not path:
        return None
    rec = load_json(path)
    st = active(now)
    note = None
    if st and (rec.get("noted_id") != st.get("id") or now - num(rec.get("noted_ts")) > STALE_NOTE_EVERY):
        note = stale_note(st)
        rec.update(noted_id=st.get("id"), noted_ts=int(now))
    cwd = str(data.get("cwd") or rec.get("cwd") or "")
    # 쓰기는 5분에 한 번 (안내를 넣을 때와 세션이 바뀐 때는 바로). 폴더만 바뀐 호출마다 쓰지 않는다
    if note or now - num(rec.get("seen_ts")) > STALE_SEEN_EVERY or rec.get("session") != sid:
        rec.update(pid=pid, session=sid, cwd=cwd, seen_ts=int(now))
        try:
            ensure_dir()
            os.makedirs(STALE, mode=0o700, exist_ok=True)
            tmp = f"{path}.{os.getpid()}.tmp"
            fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
            with os.fdopen(fd, "w", encoding="utf-8") as f:
                json.dump(rec, f, ensure_ascii=False)
            os.replace(tmp, path)
        except OSError:
            pass
    return note


def work_root(cwd):
    """cwd에서 위로 올라가며 찾은 git 작업 폴더 (worktree면 그 worktree). 없으면 cwd. git을 부르지 않는다."""
    path = cwd
    while path and os.path.dirname(path) != path:
        if os.path.exists(os.path.join(path, ".git")):
            return path
        path = os.path.dirname(path)
    return cwd


def elapsed_of(pids):
    """{pid: 시작 뒤 지난 초}. ps를 못 쓰면 None (살아 있는지 모름), 하나도 없으면 {}."""
    try:
        r = subprocess.run(["ps", "-o", "pid=,etime=", "-p", ",".join(str(p) for p in pids)], capture_output=True, text=True,
                           encoding="utf-8", errors="replace", timeout=3)
    except (OSError, subprocess.TimeoutExpired):
        return None
    if r.returncode != 0 and (r.stdout.strip() or r.stderr.strip()):
        return None
    found = {}
    for line in r.stdout.splitlines():
        m = re.fullmatch(r"\s*(\d+)\s+(?:(\d+)-)?(?:(\d+):)?(\d+):(\d+)\s*", line)
        if m:
            days, hours, minutes, seconds = (int(x or 0) for x in m.groups()[1:])
            found[int(m.group(1))] = days * 86400 + hours * 3600 + minutes * 60 + seconds
    return found


def stale_items(now=None):
    """0.24 이전에 떠서 Bash를 부른 Claude 탭 중 아직 떠 있는 것: {session, repo, cwd, seen_at, basis(pid|time)}.
    pid가 있고 본 시각보다 먼저 시작했으면 살아 있다(basis pid). 끝난 프로세스의 기록은 지운다.
    pid가 없거나 ps를 못 쓰면 마지막 관측이 2시간 안인 것만 추정(basis time)으로. 여기에 없다고 예전 탭이 없다는 뜻은 아니다."""
    now = time.time() if now is None else now
    recs = []
    try:
        names = [n for n in os.listdir(STALE) if n.endswith(".json")]
    except OSError:
        return []
    for name in names:
        path = os.path.join(STALE, name)
        rec = load_json(path)
        seen = num(rec.get("seen_ts"), None)
        if seen is None or now - seen > SESSION_KEEP:
            continue
        recs.append((path, rec, seen))
    pids = sorted({rec["pid"] for _, rec, _ in recs if isinstance(rec.get("pid"), int) and not isinstance(rec.get("pid"), bool)})
    elapsed = elapsed_of(pids) if pids else {}
    items = []
    for path, rec, seen in recs:
        pid = rec.get("pid") if isinstance(rec.get("pid"), int) and not isinstance(rec.get("pid"), bool) else None
        if pid and elapsed is not None:
            # 그 pid가 없거나 본 시각 뒤에 시작했으면(pid 재사용) 기록한 프로세스는 끝났다
            if pid not in elapsed or now - elapsed[pid] > seen + 5:
                try:
                    os.remove(path)
                except OSError:
                    pass
                continue
            basis = "pid"
        elif now - seen <= STALE_GUESS:
            basis = "time"
        else:
            continue
        cwd = str(rec.get("cwd") or "")
        items.append({"session": str(rec.get("session") or ""), "repo": work_root(cwd), "cwd": cwd, "seen_at": iso(seen), "basis": basis})
    items.sort(key=lambda it: it["seen_at"], reverse=True)
    return items[:20]


def stale_warning(items):
    names = ", ".join(dict.fromkeys(os.path.basename(it["repo"]) or it["cwd"] for it in items[:5]))
    return (f"kit 업데이트 전에 시작한 Claude 탭 {len(items)}개 ({names}): 재시작해야 질문 보류·이어 가기가 적용됩니다 "
            "(Bash를 부른 탭만 보입니다)")


def prune_stale(now):
    try:
        for name in os.listdir(STALE):
            path = os.path.join(STALE, name)
            if now - os.path.getmtime(path) > SESSION_KEEP:
                os.remove(path)
    except OSError:
        pass


# ── 훅 판정 (질문 보류, 조건부 재개) ─────────────────────────────────

ASKING = re.compile(r"[?？]|할까요|될까요|인가요|주세요|주시면|승인|기다리|대기 중|should i|shall i|let me know|waiting for|please confirm|would you like", re.I)


def asks_user(message):
    """마지막 응답의 끝부분이 질문·확인 대기로 보이는가 (글자 휴리스틱)."""
    return bool(message) and bool(ASKING.search(str(message).strip()[-300:]))


def orca_worker():
    """Orca가 띄운 워커(구조화 세션)인가. 워커는 질문·worker_done 뒤 끝나는 것이 계약이라 이어 가게 하지 않는다 (실측: 워커 탭에만 있는 변수)."""
    return bool(os.environ.get("ORCA_STRUCTURED_SESSION") or os.environ.get("ORCA_AGENT_SESSION_ID"))


def tool_calls_since(path, offset):
    """대화 기록의 offset 뒤에 있는 도구 호출 수 (JSONL을 읽어 assistant 내용의 tool_use를 센다). 못 읽으면 0."""
    try:
        with open(path, "rb") as f:
            f.seek(max(0, int(offset or 0)))
            data = f.read(8 * 1024 * 1024)
    except (OSError, TypeError, ValueError):
        return 0
    count = 0
    for line in data.splitlines():
        try:
            row = json.loads(line)
            content = (row.get("message") or {}).get("content") if isinstance(row, dict) else None
        except (ValueError, AttributeError):
            continue
        if isinstance(content, list):
            count += sum(1 for c in content if isinstance(c, dict) and c.get("type") == "tool_use")
    return count


def file_size(path):
    try:
        return os.path.getsize(path)
    except (OSError, TypeError):
        return 0


RECOMMENDED = re.compile(r"\(\s*(?:recommended|추천)\s*\)", re.I)


def recommended(question):
    """질문 하나의 추천 선택지 이름. 표시(`(Recommended)`·`(추천)`)가 정확히 하나이고 여러 개 고르기가 아닐 때만, 아니면 None."""
    if not isinstance(question, dict) or question.get("multiSelect"):
        return None
    labels = [str(o.get("label", "")) for o in question.get("options") or [] if isinstance(o, dict)]
    marked = [RECOMMENDED.sub("", label).strip() for label in labels if RECOMMENDED.search(label)]
    return marked[0] if len(marked) == 1 and marked[0] else None


def hook_question(data, st):
    """질문 창(AskUserQuestion): 창 없이 거절하고 요지를 보류 목록에. 추천 선택지가 분명하면 안내에 적는다."""
    questions = [q for q in (data.get("tool_input") or {}).get("questions") or [] if isinstance(q, dict)]
    picks = [(str(q.get("question", "")), recommended(q)) for q in questions]
    text = " / ".join(q + (f" (추천: {pick})" if pick else "") for q, pick in picks)
    rec = touch_session(data, "question", st)
    noted = "보류 목록에 적었습니다"
    try:
        append_line(HOLDS, {"ts": int(time.time()), "kind": "question", "repo": rec.get("repo") or data.get("cwd") or "",
                            "session": str(data.get("session_id") or ""), "text": mask_text(text)})
    except Exception:
        noted = "보류 목록 기록에 실패했으니 최종 보고에 직접 적으세요"
    reason = f"자리 비움 모드({hhmm(st['until'])}까지): 사용자가 없어 질문 창을 띄우지 않았습니다. 이 질문은 {noted}. "
    named = [(q, pick) for q, pick in picks if pick]
    if named:
        chosen = named[0][1] if len(picks) == 1 else "; ".join(f"{mask_text(q, 40)} → {pick}" for q, pick in named)
        reason += (f"추천 선택지: {mask_text(chosen, 300)}. 되돌릴 수 있는 결정이면 이것으로 정해 그 이유를 기록하고 계속하세요. "
                   "배포·삭제·권한·push 승인이나 사용자가 답을 기다리라고 한 것은 추천이 있어도 정하지 말고 이 항목만 건너뛴 뒤 남은 다른 일을 하세요. ")
    else:
        reason += "되돌릴 수 있는 결정이면 기본값으로 정해 그 이유를 기록하고 계속하고, 아니면 이 항목만 건너뛰고 남은 다른 일을 하세요. "
    reason += "같은 질문을 다시 띄우지 않습니다."
    return {"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": reason}}


def hook_stop(data, st):
    """턴 종료: 질문·대기로 끝났고 상한·진전 조건을 지킬 때만 이어 가게 한다. 그 밖에는 None(통과)."""
    if data.get("stop_hook_active") or orca_worker():
        touch_session(data, "stop", st)
        return None
    message = data.get("last_assistant_message")
    rec = touch_session(data, "stop", st)
    if not rec or not asks_user(message):
        return None
    blocks = rec.get("blocks") if isinstance(rec.get("blocks"), int) else 0
    transcript = rec.get("transcript")
    if blocks >= MAX_BLOCKS:
        return None
    if blocks and tool_calls_since(transcript, rec.get("block_size")) < PROGRESS_TOOLS:
        return None  # 직전 재개 뒤 한 일이 없으면 다시 깨우지 않는다
    touch_session(data, "resumed", st, blocks=blocks + 1, block_size=file_size(transcript))
    try:
        append_line(HOLDS, {"ts": int(time.time()), "kind": "stop", "repo": rec.get("repo") or data.get("cwd") or "",
                            "session": str(data.get("session_id") or ""), "text": mask_text(message)})
    except Exception:
        pass
    reason = (f"자리 비움 모드({hhmm(st['until'])}까지): 사용자가 없어 답을 받을 수 없습니다. 방금 물은 내용은 보류 목록에 적었습니다. "
              "되돌릴 수 있는 결정이면 기본값으로 정해 이유를 기록하고 계속하세요. 되돌릴 수 없거나 확인이 필요한 일(배포·삭제·권한)은 "
              "하지 말고 건너뛴 뒤 남은 다른 일을 하세요. 할 수 있는 일이 더 없으면 묻지 말고 `보류: <이유>` 한 줄로 끝내세요.")
    return {"decision": "block", "reason": reason}


# ── 명령 ─────────────────────────────────────────────────────────────

def parse_end(until, duration, now):
    """끝나는 시각(epoch). --until HH:MM은 다음에 오는 그 시각, --for는 3h·90m·1h30m."""
    if until and duration:
        raise Fail(2, "bad_time", "--until과 --for 중 하나만 씁니다")
    if until:
        m = re.fullmatch(r"(\d{1,2}):(\d{2})", until)
        if not m or int(m.group(1)) > 23 or int(m.group(2)) > 59:
            raise Fail(2, "bad_time", f"--until은 HH:MM 형식입니다 (받은 값: {until})")
        base = datetime.datetime.fromtimestamp(now)
        end = base.replace(hour=int(m.group(1)), minute=int(m.group(2)), second=0, microsecond=0)
        if end <= base:
            end += datetime.timedelta(days=1)
        end = end.timestamp()
    elif duration:
        m = re.fullmatch(r"(?:(\d+)h)?(?:(\d+)m)?", duration)
        seconds = (int(m.group(1) or 0) * 3600 + int(m.group(2) or 0) * 60) if m else 0
        if seconds <= 0:
            raise Fail(2, "bad_time", f"--for는 3h, 90m, 1h30m 형식입니다 (받은 값: {duration})")
        end = now + seconds
    else:
        raise Fail(2, "no_until", "끝나는 시각이 필요합니다: on --until HH:MM 또는 on --for 3h")
    if end - now > MAX_SECONDS:
        raise Fail(2, "too_long", "자리 비움은 최대 12시간입니다")
    return end


def status_obj(now=None):
    now = time.time() if now is None else now
    st, mode = load_state(), "away"
    if not (st and now < st["until"]):  # 자리 비움이 유효하면 그쪽이 우선
        other = load_state(AWAKE)
        if other and (now < other["until"] or not st):
            st, mode = other, "awake"
    on = bool(st and now < st["until"])
    caff = st.get("caffeinate") if st else None
    return {
        "ok": True,
        "active": on,
        "mode": mode if on else None,
        "expired": bool(st and not on),
        "until": iso(st["until"]) if st else None,
        "until_epoch": int(st["until"]) if st else None,
        "remaining_seconds": max(0, int(st["until"] - now)) if on else 0,
        "started": iso(st["started"]) if st else None,
        "caffeinate": {"pid": caff.get("pid") if isinstance(caff, dict) else None, "alive": ours(caff)},
        "power": power(),
        "queue_count": len(queue_items()),
        "checks": (st.get("checks") or []) if st else [],
        "holds_count": len(hold_items()),
        "tickets": [ticket_view(t) for t in tickets_of(st)] if on and mode == "away" else [],
        "ticket_candidates": ticket_candidates(),
        "sessions": session_items(now),
        "stale_sessions": stale_items(now),
    }


def cmd_on(args):
    now = time.time()
    end = parse_end(args.until, args.duration, now)
    checks, warnings = [], []
    mode = "away" if args.mode is None else args.mode  # 생략만 기본값. 빈 값은 오류다 (비어 있는 설정 값이 자리 비움을 켜지 않게)
    if mode not in ("away", "awake"):
        raise Fail(2, "usage", f"--mode는 away 또는 awake입니다 (받은 값: {mode})")
    if mode == "awake" and args.ticket:
        raise Fail(2, "bad_ticket", "잠자기 방지(--mode awake)에는 배포 티켓을 줄 수 없습니다 (티켓은 자리 비움에서만)")
    tickets = [parse_ticket(spec, n) for n, spec in enumerate(args.ticket or [], 1)]
    if len({(t["repo_key"], t["stack"]) for t in tickets}) != len(tickets):
        raise Fail(2, "bad_ticket", "같은 레포·스택의 티켓이 두 번 있습니다")
    if is_mac():
        pw = power()
        checks.append({"name": "power", "ok": pw["source"] == "ac", "detail": pw["source"]})
        checks.append({"name": "lid", "ok": pw["lid"] != "closed", "detail": pw["lid"]})
        if pw["source"] == "battery" and mode == "awake":
            warnings.append(BATTERY_NOTE)  # 사용자가 자리에 있다. 자리 비움(무인)은 아래에서 거부한다
        elif pw["source"] == "battery":
            raise Fail(3, "on_battery", "배터리 상태에서는 켜지 않습니다. 전원을 연결하고 다시 실행하세요")
        elif pw["source"] != "ac":
            raise Fail(3, "power_unknown", "전원 상태를 확인하지 못했습니다 (pmset -g batt). 켜지 않았습니다")
        if pw["lid"] == "closed":
            raise Fail(3, "lid_closed", "뚜껑이 닫혀 있습니다. 뚜껑을 열고 다시 실행하세요")
    else:
        warnings.append("macOS가 아니라 전원 점검과 절전 방지를 건너뜁니다 (컴퓨터가 잠들지 않게 직접 설정하세요)")
    try:
        free = shutil.disk_usage(os.path.expanduser("~")).free
        low = free < DISK_WARN_BYTES
        checks.append({"name": "disk", "ok": not low, "detail": f"{free // 1024 ** 3}GB"})
        if low:
            warnings.append(f"디스크 여유가 {free // 1024 ** 3}GB입니다 (5GB 미만)")
    except OSError:
        pass
    with state_lock():
        olds = [load_state(), load_state(AWAKE)]
        prune_sessions(now)
        prune_stale(now)
        caff = start_caffeinate(max(1, int(end - time.time()))) if is_mac() else None
        new = {"version": 1, "id": f"{int(now)}-{os.getpid()}", "started": now, "until": end, "caffeinate": caff, "checks": checks}
        # 순서: 새 상태를 쓴다 → 이전 절전 방지를 끝낸다 → 다른 모드의 파일을 지운다 (상태 파일은 하나만 남긴다).
        # 새 상태를 못 쓰면 방금 띄운 절전 방지를 거두고 이전 모드는 그대로 둔다 (상태에 없는 caffeinate가 남으면 off가 끄지 못한다).
        try:
            if mode == "awake":
                save_state(new, AWAKE)
            else:
                save_state(dict(new, tickets=tickets))
        except OSError as e:
            left = "" if stop_caffeinate(caff) else ". 새로 띄운 절전 방지(caffeinate)가 끝났는지 확인하지 못했습니다: pmset -g assertions"
            raise Fail(1, "state_not_saved", f"상태 파일을 쓰지 못해 켜지 않았습니다 (이전 상태는 그대로, away.py status로 확인): {e}{left}")
        for old in olds:
            if old and not stop_caffeinate(old.get("caffeinate")):
                warnings.append("이전 절전 방지(caffeinate)가 끝났는지 확인하지 못했습니다")
        remove_state(STATE if mode == "awake" else AWAKE)
    out = status_obj()
    if mode == "away" and out["stale_sessions"]:
        warnings.append(stale_warning(out["stale_sessions"]))
    out["warnings"] = warnings
    if args.json:
        kitlib.emit(out)
        return 0
    left = int(end - now)
    print(f"{'잠자기 방지' if mode == 'awake' else '자리 비움 모드'} 켬: {hhmm(end)}까지 ({left // 3600}시간 {left % 3600 // 60}분)")
    if caff:
        print(f"- 절전 방지: caffeinate pid {caff['pid']}" + ("" if BATTERY_NOTE in warnings else f". {LID_NOTE}"))
    if mode == "awake":
        print("- 자리 비움이 아닙니다: 확인 창과 질문은 평소대로 뜹니다 (떠날 때는 away.py on --mode away)")
    else:
        print("- 확인이 필요한 명령은 확인 창 대신 거절되고 아침 목록에 쌓입니다. 질문은 보류 목록에 쌓입니다")
    for t in tickets:
        print(f"- 배포 티켓: {t['stack']} ({t['repo']}) {t['limit']}회, 배포 전 테스트 {t['tests_note']}. 이 범위에서는 사람이 보지 않은 코드가 배포됩니다")
    if out["queue_count"]:
        print(f"- 이전 아침 목록 {out['queue_count']}건이 남아 있습니다 (away.py report --clear로 비움)")
    for w in warnings:
        print(f"- 주의: {w}")
    print("- 끄기: away.py off / 아침 목록: away.py report")
    return 0


def cmd_off(args):
    with state_lock():
        now, st, was_active, was_mode, released = time.time(), None, False, None, True
        for mode, path in (("away", STATE), ("awake", AWAKE)):  # 어느 모드든 끈다
            one = load_state(path)
            if one:
                st = st or one
                if now < one["until"] and not was_active:
                    was_active, was_mode = True, mode
                released = stop_caffeinate(one.get("caffeinate")) and released
            remove_state(path)
    items = queue_items()
    if args.json:
        kitlib.emit({"ok": True, "was_active": was_active, "mode": was_mode, "caffeinate_released": released, "queue_count": len(items)})
        return 0
    name = "잠자기 방지" if was_mode == "awake" else "자리 비움 모드"
    print(f"{name} 끔" if was_active else "자리 비움 모드는 꺼져 있었습니다" + (" (만료된 상태를 정리함)" if st else ""))
    if not released:
        print("- 주의: 절전 방지(caffeinate)가 해제됐는지 확인하지 못했습니다: pmset -g assertions")
    print_runs(run_items())
    print_report(items)
    print_holds(hold_items())
    return 0


def cmd_request(args):
    """에이전트가 "이 작업에는 이 스택 배포가 필요하다"를 적는다. 사용자가 떠나기 전에 앱에서 티켓으로 고른다."""
    if not STACK_NAME.fullmatch(args.stack or ""):
        raise Fail(2, "bad_ticket", f"스택 이름이 올바르지 않습니다: {args.stack}")
    cwd = os.path.realpath(args.cwd or os.getcwd())
    repo = kitlib.git(cwd, "rev-parse", "--show-toplevel", timeout=3) or cwd
    append_line(REQUESTS, {"ts": int(time.time()), "repo": repo, "stack": args.stack, "note": mask_text(args.note or "", 200)})
    if args.json:
        kitlib.emit({"ok": True, "repo": repo, "stack": args.stack})
    else:
        print(f"배포 티켓 후보로 적었습니다: {args.stack} ({repo}). 권한이 아닙니다. 사용자가 자리 비움을 켤 때 고르면 티켓이 됩니다")
    return 0


def cmd_status(args):
    out = status_obj()
    if args.json:
        kitlib.emit(out)
        return 0
    if out["active"]:
        left = out["remaining_seconds"]
        name = "잠자기 방지 (확인 창·질문은 평소대로)" if out["mode"] == "awake" else "자리 비움 모드"
        print(f"{name}: 켜짐, {hhmm(out['until_epoch'])}까지 (남은 {left // 3600}시간 {left % 3600 // 60}분)")
        if is_mac():
            caff = out["caffeinate"]
            print(f"- 절전 방지: {'caffeinate pid %s' % caff['pid'] if caff['alive'] else '꺼져 있음 (away.py on을 다시 실행)'}")
    else:
        print("자리 비움 모드: 꺼짐" + (f" ({hhmm(out['until_epoch'])}에 만료)" if out["expired"] else ""))
    print(f"- 전원: {out['power']['source']}, 뚜껑: {out['power']['lid']}")
    print(f"- 아침 목록: {out['queue_count']}건, 보류된 질문: {out['holds_count']}건")
    for it in out["sessions"][:10]:
        print(f"- 탭 {os.path.basename(it['repo']) or it['cwd']}: {it['last_event']} {it['last_event_at'][11:16]}, 마지막 활동 {it['last_activity_at'][11:16]}")
    for it in out["stale_sessions"]:
        guess = "" if it["basis"] == "pid" else ", 떠 있는지는 추정"
        print(f"- 재시작 권장: {os.path.basename(it['repo']) or it['cwd']} (kit 업데이트 전에 시작한 탭, 마지막 관측 {it['seen_at'][11:16]}{guess})")
    return 0


def print_report(items):
    if not items:
        print("아침 목록: 없음")
        return
    print(f"아침 목록 {len(items)}건 (자리 비움 중 거절된 명령. 자동으로 다시 실행하지 않습니다)")
    for n, it in enumerate(items, 1):
        when = it["first"][11:16] + (f"~{it['last'][11:16]}, {it['count']}회" if it["count"] > 1 else "")
        print(f"{n}. [{when}] {it['repo']}")
        print(f"   이유: {'; '.join(it['reasons'])}")
        print(f"   명령: {it['command']}")


def print_runs(runs):
    if not runs:
        return
    words = {"deployed": "배포됨", "no_changes": "변경 없음(배포 안 함)", "blocked": "막힘(배포 안 함)", "failed": "배포 실패", "refused": "티켓 없음(배포 안 함)"}
    print(f"티켓 배포 기록 {len(runs)}건")
    for n, it in enumerate(runs, 1):
        print(f"{n}. [{it['ts'][11:16]}] {it['stack']} — {words.get(it['result'], it['result'])} ({it['repo']})")
        for step in it["steps"]:
            if isinstance(step, dict) and not step.get("ok"):
                print(f"   {step.get('name')}: {step.get('detail')}")
        if it.get("log"):
            print(f"   로그: {it['log']}")


def print_holds(holds):
    if not holds:
        return
    print(f"보류된 질문 {len(holds)}건 (사용자가 없어 답을 받지 못한 질문)")
    for n, it in enumerate(holds, 1):
        kind = "질문 창" if it["kind"] == "question" else "글로 물음"
        print(f"{n}. [{it['ts'][11:16]}] {it['repo']} ({kind})")
        print(f"   {it['text']}")


def cmd_report(args):
    items, holds, runs = queue_items(), hold_items(), run_items()
    if args.json:
        kitlib.emit({"ok": True, "count": len(items), "items": items, "holds": holds, "runs": runs})
    else:
        print_runs(runs)
        print_report(items)
        print_holds(holds)
    if args.clear:
        for path in (QUEUE, HOLDS, RUNS, REQUESTS):
            try:
                os.remove(path)
            except OSError:
                pass
        shutil.rmtree(LOGS, ignore_errors=True)
        if not args.json and (items or holds or runs):
            print("아침 목록을 비웠습니다")
    return 0


def note_active(st):
    text = (f"[37writes-kit] {hhmm(st['until'])}까지 자리 비움 모드입니다 (사용자가 자리에 없습니다). "
            "확인이 필요한 일은 아침 목록으로 넘기고, 되돌릴 수 있는 결정은 기본값으로 정해 기록하고, 다른 일을 계속합니다. "
            "거절된 명령은 바꾸거나, 스크립트로 감싸거나, 다른 워커에게 넘겨 다시 시도하지 않습니다. "
            "Claude가 아닌 워커가 자기 권한 창에서 멈추면 사용자를 기다리지 말고 `orca orchestration deny --reason`으로 "
            "worktree 안의 다른 방법을 알려 주거나 그 작업만 보류합니다 (kit:harness \"자리 비움\").")
    for t in tickets_of(st):
        here = os.path.dirname(os.path.abspath(__file__))
        text += (f"\n배포 티켓: {t.get('repo')} 의 스택 {t.get('stack')} ({t.get('used')}/{t.get('limit')}회 사용"
                 f"{', 잠김' if t.get('locked') else ''}). 이 스택은 `sh {os.path.join(here, 'py.sh')} {os.path.join(here, 'away_deploy.py')} "
                 f"run --stack {t.get('stack')} --cwd <cdk 앱 폴더>`로만 배포합니다 (테스트·diff 검사 뒤 1회, 실패하면 재시도 없음). "
                 "다른 스택·직접 `cdk deploy`는 그대로 거절됩니다.")
    if is_mac() and not ours(st.get("caffeinate")):
        text += "\n절전 방지(caffeinate)가 꺼져 있어 맥이 잠들 수 있습니다. 최종 보고에 적습니다."
    return text


def cmd_hook(args):
    """SessionStart·UserPromptSubmit: 켜져 있으면 모드 알림, 꺼져 있고 목록이 남았으면 SessionStart에서 건수만.
    PreToolUse(AskUserQuestion)·Stop: 켜져 있을 때만 거절·재개 (hook_question, hook_stop). 오류면 출력 없이 통과."""
    try:
        data = kitlib.read_input()
        event = data.get("hook_event_name") or "UserPromptSubmit"
        st = active()
        if event in ("PreToolUse", "Stop"):
            out = None
            if st and event == "Stop":
                out = hook_stop(data, st)
            elif st and data.get("tool_name") == "AskUserQuestion":
                out = hook_question(data, st)
            if out:
                kitlib.emit(out)
            return 0
        if st:
            # 새 입력(사용자·Orca 메시지)이 오면 새 회차: 재개 횟수를 다시 센다
            try:
                touch_session(data, "prompt" if event == "UserPromptSubmit" else "start", st,
                              **({"blocks": 0, "block_size": 0} if event == "UserPromptSubmit" else {}))
            except Exception:
                pass
            text = note_active(st)
        elif event == "SessionStart" and queue_items():
            here = os.path.dirname(os.path.abspath(__file__))
            text = (f"[37writes-kit] 자리 비움 중 거절된 명령 {len(queue_items())}건이 아침 목록에 있습니다. 사용자에게 알리고 "
                    f"`sh {os.path.join(here, 'py.sh')} {os.path.join(here, 'away.py')} report`로 봅니다 "
                    "(자동으로 다시 실행하지 않습니다. 다 봤으면 `report --clear`).")
        else:
            return 0
        kitlib.emit({"hookSpecificOutput": {"hookEventName": event, "additionalContext": text}})
    except Exception:
        pass
    return 0


class Parser(argparse.ArgumentParser):
    def error(self, message):
        raise Fail(2, "usage", message)


def main(argv):
    as_json = "--json" in argv
    try:
        parser = Parser(prog="away.py", add_help=True)
        sub = parser.add_subparsers(dest="cmd")
        p = sub.add_parser("on")
        p.add_argument("--until")
        p.add_argument("--for", dest="duration")
        p.add_argument("--ticket", action="append")
        p.add_argument("--mode")
        p.add_argument("--json", action="store_true")
        for name in ("off", "status"):
            sub.add_parser(name).add_argument("--json", action="store_true")
        p = sub.add_parser("report")
        p.add_argument("--json", action="store_true")
        p.add_argument("--clear", action="store_true")
        p = sub.add_parser("request")
        p.add_argument("--stack")
        p.add_argument("--note")
        p.add_argument("--cwd")
        p.add_argument("--json", action="store_true")
        sub.add_parser("hook")
        args = parser.parse_args(argv)
        if not args.cmd:
            raise Fail(2, "usage", "명령이 필요합니다: on | off | status | report | request")
        return {"on": cmd_on, "off": cmd_off, "status": cmd_status, "report": cmd_report, "request": cmd_request,
                "hook": cmd_hook}[args.cmd](args)
    except Fail as e:
        code, error, message = e.code, e.error, e.message
    except Exception as e:  # 예상 밖 오류도 --json이면 JSON 하나로
        code, error, message = 1, "error", f"{type(e).__name__}: {e}"
    if as_json:
        kitlib.emit({"ok": False, "error": error, "message": message})
    else:
        sys.stderr.write(f"away.py: {message}\n")
    return code


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

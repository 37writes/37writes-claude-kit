"""자리 비움(연속 작업) 모드: 사용자가 없는 동안 guard의 확인 창(ask)을 거절(deny) + 아침 목록으로 바꾼다.

권한은 하나도 넓히지 않는다. 사용자가 `!`로 켠다:
    away.py on --until HH:MM | --for 3h [--json]
    away.py off [--json]
    away.py status [--json]
    away.py report [--json] [--clear]
    away.py hook            (SessionStart·UserPromptSubmit 훅, stdin = 훅 입력)
끝 코드: 0 성공, 1 예상 밖 오류, 2 인자 오류, 3 시작 점검 거부, 4 절전 방지 시작 실패.
guard.py가 active()·queue_add()를 import해서 쓴다. 같은 계정(HOME)의 모든 레포·세션이 상태 하나를 본다.
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
QUEUE = os.path.join(DIR, "queue.jsonl")
LOCK = os.path.join(DIR, "state.lock")
MAX_SECONDS = 12 * 3600
DISK_WARN_BYTES = 5 * 1024 ** 3
LID_NOTE = "뚜껑을 닫으면 잠듭니다 (전원 연결·뚜껑 열림 동안만 절전을 막습니다)"


class Fail(Exception):
    def __init__(self, code, error, message):
        super().__init__(message)
        self.code, self.error, self.message = code, error, message


# ── 상태 ─────────────────────────────────────────────────────────────

def load_state():
    """상태 파일 내용. 없거나 깨졌거나 형식이 다르면 None."""
    try:
        with open(STATE, encoding="utf-8") as f:
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


def hhmm(epoch):
    return datetime.datetime.fromtimestamp(epoch).strftime("%H:%M")


def iso(epoch):
    return datetime.datetime.fromtimestamp(epoch).astimezone().isoformat(timespec="seconds")


def ensure_dir():
    os.makedirs(DIR, mode=0o700, exist_ok=True)


def save_state(st):
    ensure_dir()
    tmp = STATE + ".tmp"
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(st, f, ensure_ascii=False)
    os.chmod(tmp, 0o600)
    os.replace(tmp, STATE)


def remove_state():
    """상태 파일을 지운다. 지우지 못해 파일이 남으면 Fail (모드가 켜진 채 off가 성공으로 보이지 않게)."""
    try:
        os.remove(STATE)
    except FileNotFoundError:
        pass
    except OSError as e:
        raise Fail(1, "state_not_removed", f"상태 파일을 지우지 못했습니다. 자리 비움 모드가 꺼지지 않았습니다: {e}")


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
    time.sleep(0.3)
    info = proc_info(p.pid) if p.poll() is None else None
    if not info:
        raise Fail(4, "caffeinate_failed", "caffeinate가 바로 끝났습니다. 자리 비움 모드를 켜지 않았습니다")
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


def queue_add(repo, reasons, command, session=None):
    """거절한 명령 한 줄을 덧붙인다. 잠금 없이 O_APPEND 한 번 (guard가 기다리지 않게). 중복은 report가 묶는다.
    일반 파일이 아니면(FIFO·장치·심볼릭 링크) 열다가 멈출 수 있어 비차단으로 열고 거부한다."""
    import stat
    ensure_dir()
    key = hashlib.sha256((repo + "\0" + " ".join(command.split())).encode("utf-8")).hexdigest()[:16]
    line = json.dumps({"key": key, "ts": int(time.time()), "repo": repo, "reasons": list(reasons),
                       "command": mask(command), "session": session}, ensure_ascii=False) + "\n"
    flags = os.O_WRONLY | os.O_APPEND | os.O_CREAT | getattr(os, "O_NONBLOCK", 0) | getattr(os, "O_NOFOLLOW", 0)
    fd = os.open(QUEUE, flags, 0o600)
    try:
        if not stat.S_ISREG(os.fstat(fd).st_mode):
            raise OSError("아침 목록이 일반 파일이 아닙니다")
        os.write(fd, line.encode("utf-8"))
    finally:
        os.close(fd)
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
    st = load_state()
    on = bool(st and now < st["until"])
    caff = st.get("caffeinate") if st else None
    return {
        "ok": True,
        "active": on,
        "expired": bool(st and not on),
        "until": iso(st["until"]) if st else None,
        "until_epoch": int(st["until"]) if st else None,
        "remaining_seconds": max(0, int(st["until"] - now)) if on else 0,
        "started": iso(st["started"]) if st else None,
        "caffeinate": {"pid": caff.get("pid") if isinstance(caff, dict) else None, "alive": ours(caff)},
        "power": power(),
        "queue_count": len(queue_items()),
        "checks": (st.get("checks") or []) if st else [],
    }


def cmd_on(args):
    now = time.time()
    end = parse_end(args.until, args.duration, now)
    checks, warnings = [], []
    if is_mac():
        pw = power()
        checks.append({"name": "power", "ok": pw["source"] == "ac", "detail": pw["source"]})
        checks.append({"name": "lid", "ok": pw["lid"] != "closed", "detail": pw["lid"]})
        if pw["source"] == "battery":
            raise Fail(3, "on_battery", "배터리 상태에서는 켜지 않습니다. 전원을 연결하고 다시 실행하세요")
        if pw["source"] != "ac":
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
        old = load_state()
        caff = start_caffeinate(max(1, int(end - time.time()))) if is_mac() else None
        if old and not stop_caffeinate(old.get("caffeinate")):
            warnings.append("이전 절전 방지(caffeinate)가 끝났는지 확인하지 못했습니다")
        save_state({"version": 1, "id": f"{int(now)}-{os.getpid()}", "started": now, "until": end,
                    "caffeinate": caff, "checks": checks})
    out = status_obj()
    out["warnings"] = warnings
    if args.json:
        kitlib.emit(out)
        return 0
    left = int(end - now)
    print(f"자리 비움 모드 켬: {hhmm(end)}까지 ({left // 3600}시간 {left % 3600 // 60}분)")
    if caff:
        print(f"- 절전 방지: caffeinate pid {caff['pid']}. {LID_NOTE}")
    print("- 확인이 필요한 명령은 확인 창 대신 거절되고 아침 목록에 쌓입니다 (권한은 넓어지지 않습니다)")
    if out["queue_count"]:
        print(f"- 이전 아침 목록 {out['queue_count']}건이 남아 있습니다 (away.py report --clear로 비움)")
    for w in warnings:
        print(f"- 주의: {w}")
    print("- 끄기: away.py off / 아침 목록: away.py report")
    return 0


def cmd_off(args):
    with state_lock():
        st = load_state()
        was_active = bool(st and time.time() < st["until"])
        released = stop_caffeinate(st.get("caffeinate")) if st else True
        remove_state()
    items = queue_items()
    if args.json:
        kitlib.emit({"ok": True, "was_active": was_active, "caffeinate_released": released, "queue_count": len(items)})
        return 0
    print("자리 비움 모드 끔" if was_active else "자리 비움 모드는 꺼져 있었습니다" + (" (만료된 상태를 정리함)" if st else ""))
    if not released:
        print("- 주의: 절전 방지(caffeinate)가 해제됐는지 확인하지 못했습니다: pmset -g assertions")
    print_report(items)
    return 0


def cmd_status(args):
    out = status_obj()
    if args.json:
        kitlib.emit(out)
        return 0
    if out["active"]:
        left = out["remaining_seconds"]
        print(f"자리 비움 모드: 켜짐, {hhmm(out['until_epoch'])}까지 (남은 {left // 3600}시간 {left % 3600 // 60}분)")
        if is_mac():
            caff = out["caffeinate"]
            print(f"- 절전 방지: {'caffeinate pid %s' % caff['pid'] if caff['alive'] else '꺼져 있음 (away.py on을 다시 실행)'}")
    else:
        print("자리 비움 모드: 꺼짐" + (f" ({hhmm(out['until_epoch'])}에 만료)" if out["expired"] else ""))
    print(f"- 전원: {out['power']['source']}, 뚜껑: {out['power']['lid']}")
    print(f"- 아침 목록: {out['queue_count']}건")
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


def cmd_report(args):
    items = queue_items()
    if args.json:
        kitlib.emit({"ok": True, "count": len(items), "items": items})
    else:
        print_report(items)
    if args.clear:
        try:
            os.remove(QUEUE)
        except OSError:
            pass
        if not args.json and items:
            print("아침 목록을 비웠습니다")
    return 0


def note_active(st):
    text = (f"[37writes-kit] {hhmm(st['until'])}까지 자리 비움 모드입니다 (사용자가 자리에 없습니다). "
            "확인이 필요한 일은 아침 목록으로 넘기고, 되돌릴 수 있는 결정은 기본값으로 정해 기록하고, 다른 일을 계속합니다. "
            "거절된 명령은 바꾸거나, 스크립트로 감싸거나, 다른 워커에게 넘겨 다시 시도하지 않습니다 (kit:harness \"자리 비움\").")
    if is_mac() and not ours(st.get("caffeinate")):
        text += "\n절전 방지(caffeinate)가 꺼져 있어 맥이 잠들 수 있습니다. 최종 보고에 적습니다."
    return text


def cmd_hook(args):
    """SessionStart·UserPromptSubmit: 켜져 있으면 모드 알림, 꺼져 있고 목록이 남았으면 SessionStart에서 건수만."""
    try:
        data = kitlib.read_input()
        event = data.get("hook_event_name") or "UserPromptSubmit"
        st = active()
        if st:
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
        p.add_argument("--json", action="store_true")
        for name in ("off", "status"):
            sub.add_parser(name).add_argument("--json", action="store_true")
        p = sub.add_parser("report")
        p.add_argument("--json", action="store_true")
        p.add_argument("--clear", action="store_true")
        sub.add_parser("hook")
        args = parser.parse_args(argv)
        if not args.cmd:
            raise Fail(2, "usage", "명령이 필요합니다: on | off | status | report")
        return {"on": cmd_on, "off": cmd_off, "status": cmd_status, "report": cmd_report, "hook": cmd_hook}[args.cmd](args)
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

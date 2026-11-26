"""자리 비움 배포 티켓 실행기: 사용자가 떠나기 전에 준 티켓(레포 + 스택 + 횟수) 안에서만 CDK 스택 하나를 배포한다.

    away_deploy.py run --stack <스택> [--cwd <cdk 앱 폴더>] [--json]

순서: 유효한 모드·티켓 확인 → 티켓을 만들 때 고정한 테스트 명령 → `cdk diff` 검사(삭제·교체·IAM·보안 그룹 변경이면 중단)
→ 횟수를 먼저 소비하고 `cdk deploy <스택> --exclusively --require-approval never` 한 번. 실패하면 티켓을 잠근다. 재시도·롤백 없음.
끝 코드: 0 배포됨(또는 변경 없음), 1 예상 밖 오류, 2 인자 오류, 3 티켓 없음·소진·잠김, 4 검사에서 막힘(배포 안 함), 5 배포 실패.
guard에 allow를 두지 않고 이 실행기가 `npx cdk`를 직접 띄운다. destroy·다른 스택·추가 인자는 받지 않는다.
"""
import argparse
import os
import re
import subprocess
import sys
import time

import away
import kitlib

TEST_TIMEOUT = 20 * 60
DIFF_TIMEOUT = 10 * 60
DEPLOY_TIMEOUT = 60 * 60
CDK = ["npx", "cdk"]

NO_CHANGES = re.compile(r"There were no differences|Number of stacks with differences:\s*0\b")
KNOWN_DIFF = re.compile(r"^\s*\[[+~-]\]|^Stack \S+|^Resources\s*$|Number of stacks with differences", re.M)
DANGER = [
    (re.compile(r"^\s*\[-\]", re.M), "리소스 삭제"),
    (re.compile(r"\bdestroy\b", re.I), "리소스 삭제"),
    (re.compile(r"requires replacement|may be replaced|will be replaced|\(replace\)|\breplace\b", re.I), "리소스 교체"),
    (re.compile(r"IAM Statement Changes|IAM Policy Changes|AWS::IAM::", re.I), "IAM 변경"),
    (re.compile(r"Security Group Changes|AWS::EC2::SecurityGroup", re.I), "보안 그룹 변경"),
]


def find_ticket(st, key, stack, issued=None):
    """issued=(회차 id, 티켓 id)를 주면 처음 검사한 그 발급 건만 찾는다 (검사 중에 끄고 다시 낸 티켓은 다른 건)."""
    for t in away.tickets_of(st):
        if t.get("repo_key") == key and t.get("stack") == stack:
            if issued and (st.get("id"), t.get("id")) != issued:
                return None
            return t
    return None


def run_logged(args, cwd, log, timeout, shell=False):
    """명령을 실행해 출력(표준 출력 + 오류)을 로그에 덧붙인다. (끝 코드 또는 None=시간 초과·실행 실패, 출력)."""
    try:
        r = subprocess.run(args, cwd=cwd, shell=shell, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace", timeout=timeout)
        code, out = r.returncode, r.stdout or ""
    except subprocess.TimeoutExpired as e:
        out = e.stdout if isinstance(e.stdout, str) else (e.stdout or b"").decode("utf-8", "replace")
        code, out = None, out + f"\n[시간 초과 {timeout}초]"
    except OSError as e:
        code, out = None, f"[실행 실패: {e}]"
    with open(log, "a", encoding="utf-8") as f:
        f.write(away.mask_log(f"\n$ {args if isinstance(args, str) else ' '.join(args)}  (cwd {cwd})\n{out}\n[끝 코드 {code}]\n"))
    return code, out


SECTIONS = {"Resources", "Parameters", "Outputs", "Conditions", "Mappings", "Metadata", "Other Changes", "Template"}
CHANGE = re.compile(r"\[([^\]]*)\]\s*(\S*)")
KINDS = re.compile(r"(AWS|Custom|Alexa)::\S+|Parameter|Output|Condition|Mapping|Metadata")


NOISE = re.compile(r"✨|There were no differences|Hold on while|start: |success: |Synthesis time|\(NOTE: ")


def unread_lines(out):
    """해석하지 못한 줄. 아는 줄만 통과시킨다: `Stack <이름>`, 섹션 제목, 아는 종류의 추가·수정 줄과 그 아래 들여 쓴 속성 줄,
    경고·안내, CDK의 진행 안내. 그 밖의 줄은 (들여 썼어도 변경 줄 아래가 아니면) 모두 해석 못 한 줄이다."""
    bad, under_change = [], False
    for line in out.splitlines():
        if not line.strip():
            continue
        if line[0].isspace():
            if not under_change:
                bad.append(line)
            continue
        under_change = False
        text = line.strip()
        m = CHANGE.match(line)
        if m:
            mark, kind = m.group(1), m.group(2)
            if mark.startswith(("Warning", "Info")):
                continue
            if mark in ("+", "~") and KINDS.fullmatch(kind):
                under_change = True
                continue
            bad.append(line)
        elif text in SECTIONS or re.fullmatch(r"Stack \S+", text) or NOISE.match(text):
            continue
        else:
            bad.append(line)
    return bad


def inspect_diff(out):
    """(판정, 설명, {added, changed}). 판정: ok | none(변경 없음) | danger | unknown(형식을 모름).
    위험 패턴이 없어도 해석하지 못한 변경 줄·섹션이 하나라도 있으면 unknown이다 (아는 줄이 섞여 있어도)."""
    counts = {"added": len(re.findall(r"^\s*\[\+\]", out, re.M)), "changed": len(re.findall(r"^\s*\[~\]", out, re.M))}
    found = []
    for pattern, name in DANGER:
        if pattern.search(out) and name not in found:
            found.append(name)
    if found:
        return "danger", ", ".join(found), counts
    bad = unread_lines(out)
    if bad:
        return "unknown", f"cdk diff에 해석하지 못한 줄이 있습니다: {away.mask_text(bad[0], 80)}", counts
    if counts["added"] or counts["changed"]:
        return "ok", f"추가 {counts['added']}, 수정 {counts['changed']}", counts
    if NO_CHANGES.search(out):
        return "none", "변경 없음", counts
    return "unknown", "cdk diff 출력에서 변경 목록을 읽지 못했습니다" if not KNOWN_DIFF.search(out) else "추가·수정이 없는데 변경 없음 표시도 없습니다", counts


def finish(result, code, message, args, record, steps, diff=None, log=None):
    if record:
        try:
            away.append_line(away.RUNS, {"ts": int(time.time()), "repo": record, "stack": args.stack, "result": result,
                                         "code": code, "steps": steps, "diff": diff or {}, "log": log})
        except Exception:
            message += " (실행 기록 쓰기 실패)"
    if args.json:
        kitlib.emit({"ok": code == 0, "result": result, "stack": args.stack, "message": message, "steps": steps,
                     "diff": diff or {}, "log": log})
    else:
        (sys.stdout if code == 0 else sys.stderr).write(f"away_deploy: {message}\n")
        for step in steps:
            print(f"- {step['name']}: {'통과' if step['ok'] else '실패'} ({step['detail']})")
        if log:
            print(f"- 로그: {log}")
    return code


def cmd_run(args):
    if not away.STACK_NAME.fullmatch(args.stack or ""):
        raise away.Fail(2, "usage", "--stack <스택 이름>이 필요합니다 (하나만, 영문·숫자·-)")
    cwd = os.path.realpath(args.cwd or os.getcwd())
    if not os.path.isdir(cwd):
        raise away.Fail(2, "usage", f"폴더가 없습니다: {cwd}")
    root = kitlib.git(cwd, "rev-parse", "--show-toplevel", timeout=3) or cwd
    key, steps = away.repo_key(cwd), []
    st = away.active()
    ticket = find_ticket(st, key, args.stack)
    why = None
    if not st:
        why = "자리 비움 모드가 꺼져 있습니다. 티켓은 모드가 켜져 있는 동안만 유효합니다 (평소처럼 사용자 확인을 받아 배포하세요)"
    elif not ticket:
        why = f"이 레포·스택({args.stack})의 배포 티켓이 없습니다. 배포하지 않았습니다. 이 배포는 보류하고 다른 일을 계속하세요"
    elif ticket.get("locked"):
        why = "이 티켓은 앞선 배포 실패로 잠겼습니다. 다시 시도하지 말고 실패 내용을 최종 보고에 적으세요"
    elif ticket.get("used", 0) >= ticket.get("limit", 0):
        why = f"이 티켓의 횟수({ticket.get('limit')}회)를 다 썼습니다. 배포하지 않았습니다"
    if why:
        if st:
            try:
                away.queue_add(root, ["배포 티켓 밖의 배포 요청"], f"away_deploy.py run --stack {args.stack}")
            except Exception:
                pass
        return finish("refused", 3, why, args, root if st else None, [{"name": "티켓", "ok": False, "detail": why}])
    issued = (st.get("id"), ticket.get("id"))
    steps.append({"name": "티켓", "ok": True, "detail": f"{ticket['used'] + 1}/{ticket['limit']}회째"})

    os.makedirs(away.LOGS, mode=0o700, exist_ok=True)
    log = os.path.join(away.LOGS, f"{time.strftime('%Y%m%d-%H%M%S')}-{args.stack}.log")
    os.close(os.open(log, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600))

    # 1. 테스트: 티켓을 만들 때(사용자가 떠나기 전) 프로필에서 읽어 고정한 명령
    tests = ticket.get("tests") or []
    if not tests:
        steps.append({"name": "테스트", "ok": True, "detail": ticket.get("tests_note") or "테스트 없음"})
    for test in tests:
        where = os.path.join(root, test.get("dir") or ".")
        code, _ = run_logged(test["cmd"], where, log, TEST_TIMEOUT, shell=True)
        shown = away.mask_text(test["cmd"], 200)
        steps.append({"name": "테스트", "ok": code == 0, "detail": f"{shown} → {'시간 초과·실행 실패' if code is None else code}"})
        if code != 0:
            return finish("blocked", 4, f"테스트 실패로 배포하지 않았습니다: {shown}", args, root, steps, log=log)

    # 2. 변경 검사
    code, out = run_logged(CDK + ["diff", args.stack, "--exclusively"], cwd, log, DIFF_TIMEOUT)
    if code != 0:
        steps.append({"name": "cdk diff", "ok": False, "detail": "시간 초과·실행 실패" if code is None else f"끝 코드 {code}"})
        return finish("blocked", 4, "cdk diff가 실패해 배포하지 않았습니다", args, root, steps, log=log)
    verdict, detail, counts = inspect_diff(out)
    steps.append({"name": "cdk diff", "ok": verdict in ("ok", "none"), "detail": detail})
    if verdict == "none":
        return finish("no_changes", 0, "배포할 변경이 없습니다 (티켓 횟수는 쓰지 않았습니다)", args, root, steps, counts, log)
    if verdict != "ok":
        return finish("blocked", 4, f"배포하지 않았습니다: {detail}. 사용자 확인이 필요한 변경입니다. 다시 시도하지 말고 보류하세요",
                      args, root, steps, counts, log)

    # 3. 횟수를 먼저 소비한 뒤 배포 1회 (두 탭이 동시에 불러도 한 번만)
    with away.state_lock():
        st = away.active()
        ticket = find_ticket(st, key, args.stack, issued)
        if not ticket or ticket.get("locked") or ticket.get("used", 0) >= ticket.get("limit", 0):
            steps.append({"name": "티켓", "ok": False, "detail": "검사하는 동안 만료·소진·잠김"})
            return finish("refused", 3, "검사하는 동안 티켓이 만료되었거나 다른 실행이 사용했습니다. 배포하지 않았습니다", args, root, steps, counts, log)
        ticket["used"] = ticket.get("used", 0) + 1
        away.save_state(st)
    code, _ = run_logged(CDK + ["deploy", args.stack, "--exclusively", "--require-approval", "never"], cwd, log, DEPLOY_TIMEOUT)
    if code != 0:
        with away.state_lock():
            st = away.load_state()
            ticket = find_ticket(st, key, args.stack, issued)
            if ticket:
                ticket["locked"] = True
                ticket["note"] = "배포 실패로 잠김"
                away.save_state(st)
        steps.append({"name": "cdk deploy", "ok": False, "detail": "시간 초과·실행 실패" if code is None else f"끝 코드 {code}"})
        return finish("failed", 5, "배포가 실패했습니다. 티켓을 잠갔습니다. 다시 시도하거나 되돌리지 말고, 로그를 읽어 실패 내용을 최종 보고에 적으세요",
                      args, root, steps, counts, log)
    steps.append({"name": "cdk deploy", "ok": True, "detail": "끝 코드 0"})
    return finish("deployed", 0, f"{args.stack} 배포 완료 ({detail}). 배포 뒤 확인(핵심 기능)을 이어서 하세요", args, root, steps, counts, log)


def main(argv):
    as_json = "--json" in argv
    try:
        parser = away.Parser(prog="away_deploy.py")
        sub = parser.add_subparsers(dest="cmd")
        p = sub.add_parser("run")
        p.add_argument("--stack")
        p.add_argument("--cwd")
        p.add_argument("--json", action="store_true")
        args = parser.parse_args(argv)
        if args.cmd != "run":
            raise away.Fail(2, "usage", "명령이 필요합니다: run --stack <스택>")
        return cmd_run(args)
    except away.Fail as e:
        code, error, message = e.code, e.error, e.message
    except Exception as e:
        code, error, message = 1, "error", f"{type(e).__name__}: {e}"
    if as_json:
        kitlib.emit({"ok": False, "error": error, "message": message})
    else:
        sys.stderr.write(f"away_deploy.py: {message}\n")
    return code


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

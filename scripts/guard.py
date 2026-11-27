"""PreToolUse(Bash): 되돌리기 어렵거나 외부로 나가는 명령은 실행 전에 사용자 확인을 받는다.
자리 비움 모드(away.py)가 켜져 있으면 확인 창 대신 거절하고 아침 목록에 남긴다."""
import os
import re
import shlex
import sys

import deploy_gate
import kitlib

DANGEROUS_RM_TARGETS = {"/", "/*", "~", "~/", "~/*", "$HOME", "$HOME/", "*", ".", "./", "./*", "..", "../"}

RULES = [
    (r"\bgit\s+reset\s+--hard\b", "git reset --hard: 커밋 안 된 변경이 사라집니다"),
    (r"\bgit\s+clean\s+-[a-zA-Z]*f", "git clean -f: 추적 안 되는 파일이 삭제됩니다"),
    (r"\bgit\s+branch\s+-D\b", "git branch -D: 머지 안 된 브랜치도 삭제됩니다"),
    (r"(?i)\b(drop\s+(table|database|schema)|truncate\s+table)\b", "DB 테이블/데이터베이스 삭제"),
    (r"\baws\s+\S+\s+delete-", "AWS 리소스 삭제"),
    (r"\baws\s+s3\s+(rb|rm\s+.*--recursive)", "S3 버킷/객체 일괄 삭제"),
    (r"\bamplify\s+(delete|publish)\b", "Amplify 삭제/배포"),
    (r"\bcdk\s+(deploy|destroy)\b", "CDK 배포/삭제: AWS 리소스가 바뀝니다 (먼저 cdk diff)"),
    (r"\bterraform\s+(apply|destroy)\b", "Terraform 적용/삭제: 인프라가 바뀝니다 (먼저 terraform plan)"),
    (r"\baws\s+iam\s+(put|attach|detach|create|update)-", "IAM 권한 변경"),
]


SHELLS = ("bash", "sh", "zsh")
# 옵션 인자를 따로 받는 래퍼 옵션 (이 옵션 뒤의 값도 건너뛴다)
WRAPPER_OPT_ARGS = {"sudo": {"-u", "-g", "-h", "-p", "-C", "-D", "-R", "-T", "-U"}, "env": {"-u", "-C", "-S"},
                    "npx": {"-p", "--package", "-c"}, "bunx": {"-p", "--package"}, "yarn": set(), "time": {"-f", "-o"},
                    "xargs": {"-I", "-n", "-P", "-L", "-d", "-s", "-E"}}


KEYWORDS = {"{", "}", "then", "do", "else", "elif", "if", "while", "until", "!", "fi", "done"}


def tokens_of(segment):
    if not isinstance(segment, str):
        return list(segment)
    try:
        return shlex.split(segment, posix=True)
    except ValueError:
        return segment.split()


def strip_wrappers(tokens):
    """환경 변수 대입, 셸 예약어, 래퍼(sudo, env, npx, xargs 등)와 그 옵션을 벗긴다. 셸(sh -c)은 그대로 둔다."""
    for _ in range(20):
        while tokens and (re.match(r"[A-Za-z_]\w*=", tokens[0]) or tokens[0] in KEYWORDS):
            tokens = tokens[1:]
        if not tokens:
            break
        name = os.path.basename(tokens[0])
        rest = tokens[1:]
        if name in WRAPPER_OPT_ARGS or name in ("nohup", "command", "exec") or (name == "pnpm" and rest[:1] and rest[0] in ("dlx", "exec")):
            if name == "pnpm":
                rest = rest[1:]
                name = "npx"
            takes = WRAPPER_OPT_ARGS.get(name, set())
            while rest and (rest[0].startswith("-") or (name == "env" and re.match(r"[A-Za-z_]\w*=", rest[0]))):
                opt = rest[0]
                rest = rest[2:] if opt in takes else rest[1:]
            tokens = rest
        else:
            break
    return tokens


def command_words(segment):
    """세그먼트(문자열이나 단어 목록)에서 실제 실행되는 명령과 인자. 래퍼와 그 옵션, 환경 변수 대입, 경로 접두를 벗긴다.
    best-effort 안전망이지 샌드박스가 아니다."""
    tokens = strip_wrappers(tokens_of(segment))
    for _ in range(20):
        if not tokens or os.path.basename(tokens[0]) not in SHELLS:
            break
        rest = tokens[1:]
        if any(re.match(r"-[a-z]*c[a-z]*$", t) for t in rest):
            tokens = []  # sh -c "문자열"은 segments()가 문자열을 따로 해석한다
            break
        while rest and rest[0].startswith("-"):
            rest = rest[1:]
        tokens = strip_wrappers(rest)
    if tokens:
        tokens[0] = os.path.basename(tokens[0])
    return tokens


# ── 셸 구문 해석 ─────────────────────────────────────────────────────
# 글 속의 단어(커밋 메시지, 파일에 쓰는 heredoc)를 명령으로 오인하지 않으려고 따옴표·heredoc·중첩 실행을 먼저 읽는다.
# 실행되지 않는 글자임이 확인된 것만 판정에서 빼고, 해석하지 못하면 예전처럼 원문 전체를 검사한다.

class Seg:
    """실행 단위 하나. words: 따옴표를 벗긴 단어, raw: 원문, heredocs: 본문들, piped: 출력이 다음으로 파이프,
    redirect: 따옴표 밖 `>`가 있음, nested: 중첩 실행($(…), ( … ), sh -c, 셸 heredoc) 안, prev: 파이프로 이어진 앞 세그먼트."""

    def __init__(self, words, raw, heredocs, piped=False, redirect=False, nested=False, prev=None):
        self.words, self.raw, self.heredocs = words, raw, heredocs
        self.piped, self.redirect, self.nested, self.prev = piped, redirect, nested, prev
        self.feeds_exec = False

    def text(self):
        return self.raw + "".join("\n" + body for body in self.heredocs)


def _scan(text, i, stop, nested, depth, out):
    """text[i:]를 읽어 out에 Seg를 더한다. stop이 ")"이면 짝이 맞는 닫는 괄호 다음 위치를 돌려준다."""
    if depth > 8:
        raise ValueError("중첩이 너무 깊다")
    n = len(text)
    state = {"words": [], "word": None, "start": i, "docs": [], "has_doc": False, "redirect": False, "last": None}
    pending = []

    def add(chars):
        if state["word"] is None:
            state["word"] = []
        state["word"].append(chars)

    def end_word():
        if state["word"] is not None:
            state["words"].append("".join(state["word"]))
            state["word"] = None

    def end_seg(j, piped=False):
        end_word()
        last = state["last"]
        if state["words"] or state["has_doc"]:
            seg = Seg(state["words"], text[state["start"]:j], state["docs"], piped, state["redirect"], nested,
                      last if last is not None and last.piped else None)
            out.append(seg)
            state["last"] = seg
        elif not piped:
            state["last"] = None
        state.update(words=[], docs=[], has_doc=False, redirect=False)

    def substitution(k):
        """text[k]가 `$(`의 `$`거나 백틱. 안쪽을 해석하고 끝 다음 위치."""
        if text[k] == "`":
            j = k + 1
            while j < n and text[j] != "`":
                j += 2 if text[j] == "\\" else 1
            if j >= n:
                raise ValueError("닫히지 않은 백틱")
            _scan(text[k + 1:j], 0, None, True, depth + 1, out)
            return j + 1
        return _scan(text, k + 2, ")", True, depth + 1, out)

    while i < n:
        c = text[i]
        if c == "\\":
            if i + 1 < n and text[i + 1] != "\n":
                add(text[i + 1])
            i += 2
        elif c == "'":
            j = text.find("'", i + 1)
            if j < 0:
                raise ValueError("닫히지 않은 따옴표")
            add(text[i + 1:j])
            i = j + 1
        elif c == '"':
            add("")
            k = i + 1
            while True:
                if k >= n:
                    raise ValueError("닫히지 않은 따옴표")
                ch = text[k]
                if ch == '"':
                    break
                if ch == "\\" and k + 1 < n:
                    add(text[k + 1])
                    k += 2
                elif ch == "`" or text.startswith("$(", k):
                    j = substitution(k)
                    add(text[k:j])
                    k = j
                else:
                    add(ch)
                    k += 1
            i = k + 1
        elif c == "`" or text.startswith("$(", i):
            j = substitution(i)
            add(text[i:j])
            i = j
        elif c == "(":
            end_seg(i)
            i = _scan(text, i + 1, ")", True, depth + 1, out)
            state["start"] = i
        elif c == ")":
            end_seg(i)
            if stop == ")":
                return i + 1
            i += 1
            state["start"] = i
        elif c == "\n":
            end_seg(i)
            i += 1
            for delim, strip, docs in pending:
                body = []
                while i <= n:
                    j = text.find("\n", i)
                    j = n if j < 0 else j
                    line = text[i:j]
                    i = j + 1
                    if (line.lstrip("\t") if strip else line) == delim:
                        break
                    body.append(line)
                docs.append("\n".join(body))
            pending.clear()
            i = min(i, n)
            state["start"] = i
        elif c == ";":
            end_seg(i)
            i += 1
            state["start"] = i
        elif c == "&":
            if text.startswith("&&", i):
                end_seg(i)
                i += 2
                state["start"] = i
            elif (i and text[i - 1] in "<>") or text.startswith("&>", i):
                if text.startswith("&>", i):
                    state["redirect"] = True
                add(c)
                i += 1
            else:
                end_seg(i)
                i += 1
                state["start"] = i
        elif c == "|":
            if text.startswith("||", i):
                end_seg(i)
                i += 2
            elif text.startswith("|&", i):
                end_seg(i, True)
                i += 2
            else:
                end_seg(i, True)
                i += 1
            state["start"] = i
        elif c == "<":
            end_word()
            if text.startswith("<<<", i):
                state["words"].append("<<<")
                i += 3
            elif text.startswith("<<", i):
                i += 2
                strip = i < n and text[i] == "-"
                i += 1 if strip else 0
                while i < n and text[i] in " \t":
                    i += 1
                delim = []
                while i < n and text[i] not in " \t\n;&|<>()":
                    if text[i] in "'\"":
                        j = text.find(text[i], i + 1)
                        if j < 0:
                            raise ValueError("닫히지 않은 따옴표")
                        delim.append(text[i + 1:j])
                        i = j + 1
                    else:
                        i += 1 if text[i] == "\\" and i + 1 < n else 0
                        delim.append(text[i])
                        i += 1
                pending.append(("".join(delim), strip, state["docs"]))
                state["has_doc"] = True
            else:
                i += 1
        elif c == ">":
            end_word()
            state["redirect"] = True
            i += 1
        elif c == "#" and state["word"] is None:
            j = text.find("\n", i)
            i = n if j < 0 else j
        elif c in " \t\r":
            end_word()
            i += 1
        else:
            add(c)
            i += 1
    if stop:
        raise ValueError("닫히지 않은 괄호")
    end_seg(n)
    return n


def _expand(segs, depth=0):
    """셸에 넘기는 문자열(sh -c, 셸 heredoc·here-string, eval)을 다시 해석해 더한다."""
    extra = []
    for seg in segs:
        tokens = strip_wrappers(list(seg.words))
        if not tokens:
            continue
        name = os.path.basename(tokens[0])
        scripts = []
        if name in SHELLS:
            rest = tokens[1:]
            flag = next((k for k, t in enumerate(rest) if re.match(r"-[a-z]*c[a-z]*$", t)), None)
            if flag is not None:
                scripts += rest[flag + 1:flag + 2]
            else:
                scripts += seg.heredocs
                scripts += [rest[k + 1] for k, t in enumerate(rest[:-1]) if t == "<<<"]
        elif name == "eval":
            scripts.append(" ".join(tokens[1:]))
        for script in scripts:
            found = []
            _scan(script, 0, None, True, depth + 1, found)
            extra += found + _expand(found, depth + 1)
    return extra


def legacy_segments(command):
    """해석 실패 때: 예전처럼 연산자로만 나누고 전부 검사 대상으로 둔다."""
    segs = [Seg(tokens_of(part), part, [], redirect=">" in part) for part in re.split(r"\n|&&|\|\||;|\|", command)]
    for _, string in re.findall(r"\b(?:ba|z)?sh\s+(?:-\w+\s+)*-\w*c\s+([\"'])(.*?)\1", command, re.S):
        segs += [Seg(tokens_of(part), part, [], redirect=">" in part, nested=True)
                 for part in re.split(r"\n|&&|\|\||;|\|", string)]
    for seg in segs:
        seg.feeds_exec = True  # 해석하지 못했으니 어느 것도 글자로 보지 않는다
    return segs, False


def segments(command):
    """(Seg 목록, 해석 성공 여부). 실패하면 예전 방식 목록."""
    try:
        segs = []
        _scan(command, 0, None, False, 0, segs)
        segs += _expand(segs)
    except Exception:  # 닫히지 않은 따옴표 등. 훅이 죽으면 명령이 실행되므로 어떤 오류든 예전 방식으로
        return legacy_segments(command)
    for seg in segs:
        if seg.prev is not None and not safe_consumer(seg):
            prev = seg.prev
            while prev is not None:
                prev.feeds_exec = True
                prev = prev.prev
    for seg in list(segs):  # 데이터 명령의 출력이 셸 등으로 들어가면 그 글자가 코드다
        if seg.feeds_exec and data_command(seg):
            try:
                found = []
                for script in [" ".join(seg.words[1:])] + seg.heredocs:
                    _scan(script, 0, None, True, 1, found)
                segs += found + _expand(found, 1)
            except Exception:
                pass
    return segs, True


# 인자가 실행되지 않는 명령. 이 명령의 인자와 heredoc 본문은 글자로 본다 (안의 $(…)·백틱은 따로 해석된다).
DATA_COMMANDS = {"echo", "printf", "cat", "grep", "rg", "ls", "head", "tail", "wc", "gh"}
DATA_GIT = {"commit", "tag", "log", "show", "diff", "grep", "add", "status", "notes"}
# 인자가 파일·폴더 이름인 명령. 이름 속의 단어는 명령이 아니지만 파일을 만들므로 경로 보호(away·deploy 기록)는 그대로 본다.
NAME_COMMANDS = {"mkdir", "touch", "tee"}
# 받은 글자를 실행하지 않는 파이프 소비자
FILTERS = {"grep", "rg", "head", "tail", "wc", "sort", "uniq", "tee", "cat", "jq", "sed", "tr", "cut", "less", "awk",
           "column", "nl", "fold", "pbcopy"}


def git_subcommand(words):
    """git 전역 옵션(-C 경로, -c 설정 등)을 건너뛴 하위 명령."""
    rest = words[1:]
    while rest and rest[0].startswith("-"):
        rest = rest[2:] if rest[0] in ("-C", "-c") else rest[1:]
    return rest[0] if rest else None


def data_command(seg):
    words = strip_wrappers(list(seg.words))
    if not words:
        return False
    name = os.path.basename(words[0])
    return name in DATA_COMMANDS or (name == "git" and git_subcommand(words) in DATA_GIT)


def safe_consumer(seg):
    words = strip_wrappers(list(seg.words))
    return bool(words) and (os.path.basename(words[0]) in FILTERS or data_command(seg))


def is_text(seg):
    """이 세그먼트의 인자·본문이 실행되지 않는 글자인가."""
    return data_command(seg) and not seg.feeds_exec


def no_exec(seg):
    """규칙 글자 검사에서 뺄 세그먼트: 글자이거나, 인자가 이름뿐인 명령."""
    if is_text(seg):
        return True
    words = strip_wrappers(list(seg.words))
    return bool(words) and os.path.basename(words[0]) in NAME_COMMANDS and not seg.feeds_exec


WORD_RULES = {"cdk": ({"deploy", "destroy"}, 7), "terraform": ({"apply", "destroy"}, 8)}


def rule_reasons(segs):
    """RULES: 글자로 확인된 세그먼트는 건너뛰고 나머지는 원문(+heredoc 본문)을 검사한다.
    cdk·terraform은 단어로도 본다 (`cdk --profile prod deploy`처럼 사이에 옵션이 낀 경우)."""
    reasons = []
    for seg in segs:
        if no_exec(seg):
            continue
        text = seg.text()
        reasons += [reason for pattern, reason in RULES if re.search(pattern, text)]
        words = command_words(seg.words)
        if words and words[0] in WORD_RULES:
            verbs, index = WORD_RULES[words[0]]
            if verbs & set(words[1:]):
                reasons.append(RULES[index][1])
    return reasons


def deploy_reasons(segs):
    """deploy.sh(--diff·--synth는 미리보기라 통과)나 ampx sandbox/pipeline-deploy 실행인가."""
    reasons = []
    for seg in segs:
        words = command_words(seg.words)
        if not words:
            continue
        if words[0] == "deploy.sh" and not {"--diff", "--synth"} & set(words[1:]):
            reasons.append("deploy.sh: 배포 스크립트 (--diff·--synth는 미리보기라 통과)")
        if words[0] == "ampx" and words[1:2] and words[1] in ("sandbox", "pipeline-deploy"):
            reasons.append("ampx %s: Amplify Gen 2 AWS 리소스가 바뀝니다" % words[1])
    return reasons


PUSH = re.compile(r"\bgit(?:\s+-[Cc]\s+\S+|\s+-\S+)*\s+push\b")
# 프로젝트 프로필(CLAUDE.md)에 이 줄이 있으면 push가 배포가 아니다 → 사용자가 커밋을 승인하면 묻지 않고 push
PUSH_FREE = re.compile(r"^- \*\*push\*\*: 배포 아님", re.M)
PUSH_ASK = "git push: 원격 저장소에 반영됩니다 (배포가 될 수 있음. 프로필에 'push: 배포 아님'이면 일반 push는 묻지 않는다)"
RISKY_PUSH_OPTS = {"--force", "--force-with-lease", "--force-if-includes", "--delete", "--mirror", "--prune"}


def push_free_repo(path):
    root = kitlib.git(path, "rev-parse", "--show-toplevel")
    claude_md = os.path.join(root, "CLAUDE.md") if root else None
    return bool(claude_md and os.path.exists(claude_md) and PUSH_FREE.search(kitlib.read(claude_md)))


def push_reasons(segs, cwd):
    """git push마다: 프로필에 'push: 배포 아님'인 레포의 일반 push면 통과, 강제·삭제 push나 판단 못 하면 확인.
    중첩 실행(sh -c, 괄호 안) 속의 push는 폴더를 따라가지 못하므로 통과로 세지 않는다."""
    expected = sum(len(PUSH.findall(seg.text())) for seg in segs if not seg.nested and not no_exec(seg))
    if not expected:
        return []
    here, safe = cwd, 0
    for seg in segs:
        if seg.nested:
            continue
        words = command_words(seg.words)
        if words[:1] == ["cd"] and len(words) > 1:
            here = os.path.join(here, os.path.expanduser(words[1]))
            continue
        if words[:1] != ["git"]:
            continue
        rest, repo, overrides = words[1:], here, []
        while rest and rest[0].startswith("-"):
            if rest[0] == "-C" and len(rest) > 1:
                repo = os.path.join(repo, os.path.expanduser(rest[1]))
                rest = rest[2:]
            else:
                overrides.append(rest[0])
                rest = rest[2:] if rest[0] == "-c" else rest[1:]
        if rest[:1] != ["push"]:
            continue
        args = rest[1:]
        risky = any(a in RISKY_PUSH_OPTS or a.startswith("--force") or re.match(r"-[a-zA-Z]*[fd]", a)
                    or a.startswith("+") or a.startswith(":") for a in args)
        if risky:
            return [PUSH_ASK]
        if not push_free_repo(repo):
            # 프로필 자동 배포 정책 + 검증 기록과 맞는 push만 통과 (deploy_gate.push_allowed)
            allowed, why = deploy_gate.push_allowed(repo, args, overrides)
            if not allowed:
                return [f"{PUSH_ASK} — 자동 배포 조건 불충족: {why}"]
        safe += 1
    if safe < expected:
        return ["git push: 원격 저장소에 반영됩니다 (명령을 해석하지 못해 확인)"]
    return []


DEPLOY_RECORDS = re.compile(r"37writes-kit[/\\]+deploy")
READ_ONLY = {"cat", "ls", "grep", "rg", "head", "tail", "wc", "jq", "less"}


def record_reasons(segs):
    """자동 배포 검증 기록 폴더를 deploy_gate.py 밖에서 건드리는 명령 (위조 방지, best-effort). 리다이렉트 없는 읽기는 통과."""
    for seg in segs:
        text = seg.text()
        if not DEPLOY_RECORDS.search(text) or "deploy_gate.py" in text:
            continue
        if is_text(seg) and not seg.redirect:
            continue  # 커밋 메시지·검색어 속의 경로
        words = command_words(seg.words)
        if not (words and words[0] in READ_ONLY and not seg.redirect):
            return ["자동 배포 검증 기록(37writes-kit/deploy)은 deploy_gate.py로만 만든다"]
    return []


AWAY_FILES = re.compile(r"37writes-kit[/\\]+away")


def away_reasons(segs):
    """자리 비움 상태·아침 목록 폴더를 away.py 밖에서 건드리는 명령 (best-effort). 리다이렉트 없는 읽기는 통과."""
    for seg in segs:
        text = seg.text()
        if not AWAY_FILES.search(text) or "away.py" in text:
            continue
        if is_text(seg) and not seg.redirect:
            continue  # 커밋 메시지·검색어 속의 경로
        words = command_words(seg.words)
        if not (words and words[0] in READ_ONLY and not seg.redirect):
            return ["자리 비움 상태·아침 목록(37writes-kit/away)은 away.py로만 바꾼다"]
    return []


def ticket_reasons(segs):
    """배포 티켓(`away.py on --ticket`)은 사용자만 만든다 (앱 또는 `!` 명령은 이 훅을 거치지 않는다)."""
    for seg in segs:
        if is_text(seg):
            continue
        text = seg.text()
        if "away.py" in text and re.search(r"(?<![\w-])--ticket\b", text):
            return ["자리 비움 배포 티켓은 사용자가 직접 만든다 (메뉴 막대 앱 또는 `! away.py on --ticket`)"]
    return []


def decide(reasons, data, command):
    """평소에는 ask. 자리 비움 모드가 유효하면 deny + 아침 목록 (권한은 넓히지 않고 확인 창만 없앤다).
    상태를 못 읽으면(없음·깨짐·만료·오류) ask, 유효한데 목록 쓰기가 실패해도 deny."""
    text = "37writes-kit 확인 필요: " + "; ".join(reasons)
    try:
        import away
        state = away.active()
        until = away.hhmm(state["until"]) if state else None
    except Exception:
        state = None
    if not state:
        return "ask", text
    cwd = data.get("cwd") or os.getcwd()
    try:
        # 기록이 멈춰도 훅 제한(15초) 전에 거절이 나가야 한다 (훅이 시간을 넘기면 명령이 실행된다).
        # 신호(SIGALRM)는 윈도우에 없어서 데몬 스레드 + join 제한으로 한다.
        import threading
        done = []

        def record():
            try:
                away.queue_add(kitlib.git(cwd, "rev-parse", "--show-toplevel", timeout=3) or cwd, reasons, command,
                               data.get("session_id"))
                done.append(True)
            except Exception:
                pass
        worker = threading.Thread(target=record, daemon=True)
        worker.start()
        worker.join(4)
        note = "아침 목록에 넣었습니다" if done else "아침 목록 기록에 실패했으니 최종 보고에 직접 적으세요"
    except Exception:
        note = "아침 목록 기록에 실패했으니 최종 보고에 직접 적으세요"
    return "deny", (f"자리 비움 모드({until}까지): 이 명령은 사용자 확인이 필요해 {note}. "
                    f"바꾸거나 감싸서 다시 시도하지 말고 다른 일을 계속하세요 ({text})")


def dangerous_rm(segs):
    """rm에 -r과 -f가 (붙여 쓰든 나눠 쓰든) 있고 대상이 루트/홈/현재 폴더 전체인가."""
    for seg in segs:
        tokens = command_words(seg.words)
        if not tokens or tokens[0] != "rm":
            continue
        flags = "".join(t[1:] for t in tokens[1:] if t.startswith("-") and not t.startswith("--"))
        long_flags = {t for t in tokens[1:] if t.startswith("--")}
        recursive = "r" in flags or "R" in flags or "--recursive" in long_flags
        force = "f" in flags or "--force" in long_flags
        targets = [t for t in tokens[1:] if not t.startswith("-")]
        if recursive and force and any(t in DANGEROUS_RM_TARGETS for t in targets):
            return True
    return False


def all_reasons(command, cwd):
    segs, _ = segments(command)
    reasons = rule_reasons(segs)
    reasons += push_reasons(segs, cwd)
    if dangerous_rm(segs):
        reasons.append("rm -rf 대상이 루트/홈/현재 폴더 전체입니다")
    reasons += deploy_reasons(segs)
    reasons += record_reasons(segs)
    reasons += away_reasons(segs)
    reasons += ticket_reasons(segs)
    return list(dict.fromkeys(reasons))


SCHEMA = 1  # hooks.json의 guard 등록 명령에 붙는 표식 (`guard.py --schema 1`)


def schema_arg(argv):
    """`--schema N`의 N. 없거나 숫자가 아니면 0 (0.24 이전 hooks.json으로 뜬 Claude 프로세스가 부른 것)."""
    for i, arg in enumerate(argv[:-1]):
        if arg == "--schema" and argv[i + 1].isdigit():
            return int(argv[i + 1])
    return 0


def old_tab_note(data):
    """표식 없이 불렸으면 그 탭을 적고, 자리 비움 중이면 그 탭에 넣을 안내문 (away.observe_old). 그 밖에는 None.
    표식이 있는 호출은 아무것도 하지 않는다 (판정 경로에 일을 더하지 않게). 오류는 무시한다."""
    if schema_arg(sys.argv[1:]) >= SCHEMA:
        return None
    try:
        import away
        return away.observe_old(data)
    except Exception:
        return None


def main():
    data = kitlib.read_input()
    command = (data.get("tool_input") or {}).get("command", "")
    reasons = all_reasons(command, data.get("cwd") or os.getcwd())
    note = old_tab_note(data)
    if reasons:
        decision, text = decide(reasons, data, command)
        if note and decision == "deny":
            text += "\n" + note  # 거절 이유 원문은 모델에 돌아간다 (판정 + additionalContext 조합은 확인하지 않았다)
        kitlib.emit({
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": decision,
                "permissionDecisionReason": text,
            }
        })
    elif note:
        kitlib.emit({"hookSpecificOutput": {"hookEventName": "PreToolUse", "additionalContext": note}})


if __name__ == "__main__":
    main()

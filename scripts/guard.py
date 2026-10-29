"""PreToolUse(Bash): 되돌리기 어렵거나 외부로 나가는 명령은 실행 전에 사용자 확인을 받는다."""
import os
import re
import shlex

import kitlib

DANGEROUS_RM_TARGETS = {"/", "/*", "~", "~/", "~/*", "$HOME", "$HOME/", "*", ".", "./", "./*", "..", "../"}

RULES = [
    (r"\bgit\s+push\b", "git push: 원격 저장소에 반영됩니다 (Amplify 등은 곧 배포)"),
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
                    "npx": {"-p", "--package", "-c"}, "bunx": {"-p", "--package"}, "yarn": set(), "time": {"-f", "-o"}}


def command_words(segment):
    """세그먼트에서 실제 실행되는 명령과 인자. 래퍼(sudo, env, npx 등)와 그 옵션, 환경 변수 대입, 경로 접두를 벗긴다.
    best-effort 안전망이지 샌드박스가 아니다."""
    try:
        tokens = shlex.split(segment, posix=True)
    except ValueError:
        tokens = segment.split()
    for _ in range(20):
        while tokens and re.match(r"[A-Za-z_]\w*=", tokens[0]):
            tokens = tokens[1:]
        if not tokens:
            break
        name = os.path.basename(tokens[0])
        rest = tokens[1:]
        if name in SHELLS:
            if any(re.match(r"-[a-z]*c[a-z]*$", t) for t in rest):
                tokens = []  # sh -c "문자열"은 deploy_reasons가 문자열을 따로 분석한다
                break
            while rest and rest[0].startswith("-"):
                rest = rest[1:]
            tokens = rest
        elif name in WRAPPER_OPT_ARGS or name in ("nohup", "command", "exec") or (name == "pnpm" and rest[:1] and rest[0] in ("dlx", "exec")):
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
    if tokens:
        tokens[0] = os.path.basename(tokens[0])
    return tokens


def deploy_reasons(command):
    """deploy.sh(--diff·--synth는 미리보기라 통과)나 ampx sandbox/pipeline-deploy 실행인가."""
    reasons = []
    # 따옴표 안에 &&·;가 있어도 sh -c "..."의 문자열을 통째로 다시 분석한다
    for _, string in re.findall(r"\b(?:ba|z)?sh\s+(?:-\w+\s+)*-\w*c\s+([\"'])(.*?)\1", command, re.S):
        reasons += deploy_reasons(string)
    for segment in re.split(r"\n|&&|\|\||;|\|", command):
        words = command_words(segment)
        if not words:
            continue
        if words[0] == "deploy.sh" and not {"--diff", "--synth"} & set(words[1:]):
            reasons.append("deploy.sh: 배포 스크립트 (--diff·--synth는 미리보기라 통과)")
        if words[0] == "ampx" and words[1:2] and words[1] in ("sandbox", "pipeline-deploy"):
            reasons.append("ampx %s: Amplify Gen 2 AWS 리소스가 바뀝니다" % words[1])
    return reasons


def dangerous_rm(command):
    """rm에 -r과 -f가 (붙여 쓰든 나눠 쓰든) 있고 대상이 루트/홈/현재 폴더 전체인가."""
    for segment in re.split(r"&&|\|\||;|\|", command):
        try:
            tokens = shlex.split(segment, posix=True)
        except ValueError:
            tokens = segment.split()
        if not tokens or tokens[0] not in ("rm", "sudo"):
            continue
        if tokens[0] == "sudo":
            tokens = tokens[1:]
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


command = (kitlib.read_input().get("tool_input") or {}).get("command", "")
reasons = [reason for pattern, reason in RULES if re.search(pattern, command)]
if dangerous_rm(command):
    reasons.append("rm -rf 대상이 루트/홈/현재 폴더 전체입니다")
reasons += deploy_reasons(command)
if reasons:
    kitlib.emit({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "ask",
            "permissionDecisionReason": "37writes-kit 확인 필요: " + "; ".join(reasons),
        }
    })

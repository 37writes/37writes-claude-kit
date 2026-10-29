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


def command_words(segment):
    """세그먼트에서 실행되는 명령과 인자. 환경 변수 대입, sudo/env, bash/sh(+옵션), 경로 접두를 벗긴다."""
    try:
        tokens = shlex.split(segment, posix=True)
    except ValueError:
        tokens = segment.split()
    while tokens and (re.match(r"[A-Za-z_]\w*=", tokens[0]) or tokens[0] in ("sudo", "env", "command", "exec")):
        tokens = tokens[1:]
    if tokens and os.path.basename(tokens[0]) in ("bash", "sh", "zsh"):
        tokens = tokens[1:]
        while tokens and tokens[0].startswith("-"):
            tokens = tokens[1:]
    if tokens:
        tokens[0] = os.path.basename(tokens[0])
    return tokens


def deploy_reasons(command):
    """deploy.sh(--diff·--synth는 미리보기라 통과)나 ampx sandbox/pipeline-deploy 실행인가."""
    reasons = []
    for segment in re.split(r"\n|&&|\|\||;|\|", command):
        words = command_words(segment)
        if not words:
            continue
        if words[0] == "deploy.sh" and not {"--diff", "--synth"} & set(words[1:]):
            reasons.append("deploy.sh: 배포 스크립트 (--diff·--synth는 미리보기라 통과)")
        elif words[0] == "npx" and len(words) > 1 and words[1] == "ampx":
            words = words[1:]
        if words[0] == "ampx" and any(w in ("sandbox", "pipeline-deploy") for w in words[1:2]):
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

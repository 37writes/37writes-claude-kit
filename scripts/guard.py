"""PreToolUse(Bash): 되돌리기 어렵거나 외부로 나가는 명령은 실행 전에 사용자 확인을 받는다."""
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
if reasons:
    kitlib.emit({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "ask",
            "permissionDecisionReason": "37writes-kit 확인 필요: " + "; ".join(reasons),
        }
    })

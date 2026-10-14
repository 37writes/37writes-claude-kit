"""PreToolUse(Bash): 되돌리기 어렵거나 외부로 나가는 명령은 실행 전에 사용자 확인을 받는다."""
import re

import kitlib

RULES = [
    (r"\bgit\s+push\b", "git push: 원격 저장소에 반영됩니다 (Amplify 등은 곧 배포)"),
    (r"\bgit\s+reset\s+--hard\b", "git reset --hard: 커밋 안 된 변경이 사라집니다"),
    (r"\bgit\s+clean\s+-[a-zA-Z]*f", "git clean -f: 추적 안 되는 파일이 삭제됩니다"),
    (r"\bgit\s+branch\s+-D\b", "git branch -D: 머지 안 된 브랜치도 삭제됩니다"),
    (r"\brm\s+-[a-zA-Z]*(rf|fr)[a-zA-Z]*\s+(/|/\*|~|~/|\$HOME|\*|\.|\.\.|\./\*)(\s|$)",
     "rm -rf 대상이 루트/홈/현재 폴더 전체입니다"),
    (r"(?i)\b(drop\s+(table|database|schema)|truncate\s+table)\b", "DB 테이블/데이터베이스 삭제"),
    (r"\baws\s+\S+\s+delete-", "AWS 리소스 삭제"),
    (r"\baws\s+s3\s+(rb|rm\s+.*--recursive)", "S3 버킷/객체 일괄 삭제"),
    (r"\bamplify\s+(delete|publish)\b", "Amplify 삭제/배포"),
]

command = (kitlib.read_input().get("tool_input") or {}).get("command", "")
reasons = [reason for pattern, reason in RULES if re.search(pattern, command)]
if reasons:
    kitlib.emit({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "ask",
            "permissionDecisionReason": "37writes-kit 확인 필요: " + "; ".join(reasons),
        }
    })

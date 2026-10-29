"""SessionStart: Orca IDE에서 시작한 세션이면 (어느 레포든) harness 멀티 에이전트 절차를 알려준다."""
import os

import kitlib

NOTE = """[37writes-kit] Orca에서 시작한 세션입니다. 멀티 에이전트 작업 절차(/kit:harness)를 따릅니다.
- 첫 지시가 Orca 작업 지시(orchestration dispatch, Task spec)면 워커입니다. 등급 분류·계획을 다시 하지 말고 지시의 담당 범위만 수행한 뒤 Orca 안내서대로 worker_done으로 보고합니다.
- 그 밖에는 지휘 세션입니다. 질문이 아닌 작업 요청을 받으면 먼저 /kit:harness로 T0~T2를 분류합니다. T1 이상은 기획서를 쓰고, 계획을 보여 줄 때 Orca 워커로 진행할지 확인받습니다."""


def in_orca():
    return os.environ.get("TERM_PROGRAM") == "Orca" or bool(os.environ.get("ORCA_WORKTREE_ID"))


if in_orca():
    kitlib.emit({
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": NOTE,
        }
    })

"""SessionStart: Orca IDE에서 시작한 세션이면 (어느 레포든) harness 멀티 에이전트 절차를 알려준다."""
import os

import kitlib

NOTE = """[37writes-kit] Orca에서 시작한 세션입니다. 멀티 에이전트 작업 절차(/kit:harness)를 따릅니다.
- 지금 하는 작업에 Task·Dispatch ID가 있는 Orca 작업 지시(preamble)가 걸려 있으면 그 작업 동안은 워커입니다. 등급 분류·계획을 다시 하지 말고 지시의 담당 범위만 수행한 뒤 Orca 안내서대로 worker_done으로 보고합니다. 완료된 지시는 역할 근거가 아닙니다.
- 그 밖에는 지휘 세션입니다. 질문이 아닌 작업 요청을 받으면 먼저 /kit:harness로 T0~T2를 분류합니다. T1 이상은 기획서를 쓰고, 변경 규모상 워커가 필요하면 사용자 확인 없이 Orca 워커를 띄웁니다(사용자가 허락함, T2 승인은 그대로). 대신 배치를 harness 3단계대로 판단합니다: 본체(main)이거나 지금 worktree에 다른 작업이 있으면 새 worktree, 차례로 일하는 역할(Coder → Validator)은 같은 worktree의 탭, 동시에 파일을 고치는 워커만 하위 worktree, git이 아닌 폴더는 같은 폴더에서 차례로."""


def in_orca():
    return os.environ.get("TERM_PROGRAM") == "Orca" or bool(os.environ.get("ORCA_WORKTREE_ID"))


if in_orca():
    kitlib.emit({
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": NOTE,
        }
    })

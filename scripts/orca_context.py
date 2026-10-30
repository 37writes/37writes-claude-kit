"""SessionStart: Orca IDE에서 시작한 세션이면 (어느 레포든) 역할을 가르고 kit:harness를 먼저 읽게 한다."""
import os

import kitlib

NOTE = """[37writes-kit] Orca에서 시작한 세션입니다. 작업 절차는 kit:harness에 있습니다.
- 지금 하는 작업에 Task·Dispatch ID가 있는 Orca 작업 지시(preamble)가 걸려 있으면 그 작업 동안은 워커입니다. 지시의 담당 범위만 수행하고 Orca 안내서대로 worker_done으로 보고합니다. 완료된 지시는 역할 근거가 아닙니다.
- 그 밖에는 지휘 세션입니다. 첫 요청을 처리하기 전에 (질문이라도) Skill 도구로 kit:harness를 불러 읽습니다.
- 지휘 세션에서 다른 모델(GPT·Codex, agy 등)의 의견·검토는 Orca 워커 탭으로 띄웁니다 (harness 1단계). `codex exec`, `agy -p`처럼 화면에 안 보이는 호출은 쓰지 않습니다."""


def in_orca():
    return os.environ.get("TERM_PROGRAM") == "Orca" or bool(os.environ.get("ORCA_WORKTREE_ID"))


if in_orca():
    kitlib.emit({
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": NOTE,
        }
    })

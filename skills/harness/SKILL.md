---
name: harness
description: 작업을 위험도(T0~T2)로 나눠 계획·구현·독립 검증·기록 절차를 정한다. 기능·버그·배포·IAM 작업을 시작할 때 사용.
---

# harness: 에이전트 작업 절차

AWS Deep Insight의 역할 구조(Coordinator → Planner → 사람 승인 → Supervisor → Coder/Validator/Reporter → Tracker)를 개발 작업에 옮긴 절차다.
대화 세션이 Coordinator·Planner·Supervisor·Tracker를 맡고, **사용자가 Plan Reviewer**, 워커(Orca 워커 또는 서브에이전트)가 Coder·Validator를 맡는다.
워커 실행·메시지·정리는 Orca 같은 실행 도구가 맡고, 이 스킬은 등급, 계획, 검증 기준, 기록을 맡는다.

Orca IDE에서 시작한 세션에는 SessionStart 훅이 이 절차를 따르라는 안내를 넣는다 (`scripts/orca_context.py`, 모든 레포).

사용자에게 하는 질문과 보고는 모두 **한국어**로 한다.

## 1. 분류 (Coordinator)

| 등급 | 예 | 절차 |
|---|---|---|
| **T0** | 질문, 문서 오타, 20줄 미만 파일 하나 수정 | 바로 처리. 계획·워커 없음 |
| **T1** | 기능 추가, 버그 수정, 리팩터링, 테스트 | 계획(2) + 구현 + **독립 검증**(5) |
| **T2** | 배포, push, AWS·IAM·시크릿 변경, 확정된 설계 변경, 데이터 삭제 | T1 + **실행 전 사용자 계획 승인** + 적용 전 읽기 전용 미리보기 |

- 애매하면 높은 등급으로 한다. 분류 결과를 한 줄로 알린다: `등급: T1 (버그 수정, 코드 3개 파일)`
- **등급은 영향 범위로, 워커를 띄울지는 변경 규모로** 정한다. 권한 두 줄 추가도 배포가 따르면 T2다. 다만 수정이 작으면 세션이 직접 고쳐도 되고, 그때도 승인·미리보기·검증은 빼지 않는다.
- 원인을 찾는 읽기 전용 진단(로그·코드·설정 읽기)은 등급과 상관없이 먼저 해도 된다.

## 2. 계획 (Planner, T1 이상)

- 파일: `docs/plans/YYYY-MM-DD-<영어-slug>.md`. 형식은 `<base directory>/../plan/SKILL.md`의 "4. 기획서 작성"을 따른다. 질문 단계는 필요한 것만 한다.
- front matter에 `tier: T1|T2`를 적고, 작업 단계는 **담당과 확인 가능한 완료 조건**을 붙인다:
  `- [ ] S1. 무엇을 — Coder — \`npm test\` 통과, 변경은 src/auth/ 안에서만`
- 완료 조건은 "배포 완료"가 아니라 **사용자가 보게 될 결과**까지 쓴다 (예: 배포 사이트에서 보고서 1건 생성 성공).
- T2는 "승인 필요" 섹션에 무엇을 바꾸는지, 미리보기 명령(`cdk diff`, `terraform plan`, `--dry-run`), 롤백 방법을 적는다.
- 사용자에게 목표·단계·승인 필요 항목을 짧게 보여준다. 수정 요청은 반영하고 3회를 넘기면 범위를 줄이자고 제안한다.
- T2는 **명시적 승인 전에는 실행하지 않는다.** 승인되면 `status: approved`.

## 3. 실행 (Supervisor)

이 스킬은 **무엇을 맡길지**(단계, 범위, 완료 조건, 금지)를 정한다. 워커를 띄우고 주고받고 정리하는 방법은 실행 도구의 규칙을 따른다.
의존이 없는 단계는 병렬로 맡긴다. **Validator는 Coder와 다른 워커**로 한다 (가능하면 다른 에이전트나 모델).

**워커 고르기** (위에서부터 가능한 것)
1. **Orca** (`command -v orca`가 있을 때): Orca의 orchestration 스킬을 불러 그 규칙을 그대로 따른다 (`orca skills get orchestration`이 설치된 버전에 맞는 안내서를 준다). 대기 시간, 재시도, 워커 정리는 그 안내서대로 하고 여기서 따로 정하지 않는다. 사용자가 Orca 워커 사용을 미리 허락했으므로 따로 확인받지 않고 띄운다. 대신 아래 "Orca 배치와 보드"대로 탭과 worktree를 판단하고 계획에 적는다.
2. **서브에이전트** (Agent 도구): Coder는 `isolation: "worktree"`, Validator는 새 서브에이전트로 띄운다 (새 컨텍스트라 Coder의 판단에 끌려가지 않는다).
3. **단일 세션**: 직접 구현하고, 검증은 /kit:check 절차로 한다. 같은 컨텍스트라 독립성이 약하다는 점을 보고에 적는다.

**Orca 배치와 보드** (실행 방법은 Orca 안내서, 여기서는 어디에 두고 카드를 어떻게 보일지만 정한다)
- **작업 하나 = worktree 하나 = 보드 카드 하나.** 기획서(또는 버그) 하나를 한 worktree에서 끝낸다. 세션이 레포 본체(main)에 있거나 지금 worktree에 끝나지 않은 다른 작업이 있으면 새 worktree를 제안한다 (`orca worktree create --repo id:<repoId> --name <기획서 slug> --no-parent --json`). 거절하면 지금 worktree에서 하고 카드에 작업이 섞인다고 알린다.
- 대상 worktree 지정: 지휘 세션이 그 worktree 안에 있으면 `current`, 아니면 create가 돌려준 `id:<repoId>::<path>`를 워커 배치와 카드 갱신에 똑같이 쓴다.
- **역할 하나 = 탭 하나.** Coder·Validator는 그 worktree에 `worker-start`로 차례로 띄운다 (Validator는 Coder의 커밋을 같은 폴더에서 검사한다). 정산 뒤에도 남은 탭(사용자가 입력해 사용자 소유로 바뀐 탭 등)은 마지막 보고에 목록으로 알린다.
- **같은 시간에 파일을 고치는 워커가 둘 이상**일 때만 각자 하위 worktree에 두고 담당 범위를 겹치지 않게 나눈다. 지휘 세션이 작업 worktree 안에 있으면 `worker-start --worktree new-child`, 밖이면 `orca worktree create --repo id:<repoId> --name <하위 slug> --parent-worktree <대상> --base-branch <작업 브랜치> --json`으로 만든 뒤 돌려받은 id에 띄운다. 끝나면 작업 worktree로 병합한다. 따로 병합·배포할 수 있는 단위면 처음부터 별도 작업(기획서)으로 나눈다. git이 없는 폴더 워크스페이스는 생성·병합·삭제 없이 같은 폴더에서 차례로 한다.
- **카드 갱신**: 단계가 바뀔 때 `orca worktree set --worktree <대상> --workspace-status <상태> --comment "<지금 하는 일 한 줄>"`. 사용자 확인을 기다릴 때는 `--unread`도 붙인다. 재작업이면 `in-progress`로 되돌리고, 막히거나 보류되면 상태는 두고 comment에 이유와 다음 조치를 적는다. 보드에 사용자 지정 상태가 있으면 대응하는 id를 쓴다.

  | 시점 | 상태 | comment 예 |
  |---|---|---|
  | 기획서 작성, 승인 대기 | `todo` | 계획 작성, 승인 대기 |
  | Coder 시작 | `in-progress` | Coder S1 구현 중 |
  | Validator 시작, T2 미리보기 승인·PR 대기 | `in-review` | Validator 재검증 2회차 |
  | 검증과 필요한 적용·병합 끝 (push 승인 시 push 후) | `completed` | 병합 a1b2c3d |

**작업 지시** (Orca Task spec과 같은 5항목. 워커에게는 대화 전체가 아니라 이것만 준다)
```text
대상: <계획 단계 id, 다룰 파일·컴포넌트·환경>
변경: <만들어야 할 결과>
제약: <지킬 규칙>. push, 배포, AWS 쓰기, 시크릿 출력 금지. 막히면 추측하지 말고 질문으로 올린다.
담당 범위: <이 워커가 수정해도 되는 파일·폴더>
완료 증거: <실행할 명령과 기대 결과>
```
Codex 등 Claude가 아닌 에이전트는 CLAUDE.md를 읽지 않는다. 레포에 `AGENTS.md`가 없으면 위 제약과 보고 방법으로 만들자고 제안하고, 작업 지시에도 제약을 그대로 붙여 넣는다.

## 4. 워커 보고

- **Orca**: `worker_done` 형식을 쓴다 (3문장 요약, `--outcome succeeded|failed`, `--files-modified`, 긴 출력은 `--report-path`). 요약에 실행한 검사와 결과, 남은 위험을 넣게 한다.
- **서브에이전트·단일 세션**: 아래 양식, 150단어 이내. 긴 출력은 파일로 남기고 경로만.
  ```text
  STATUS: SUCCESS | PARTIAL | ERROR
  DONE: <끝낸 계획 단계 id>
  CHANGED: <바뀐 파일 경로>
  CHECKS: <실행한 명령 → 결과>
  NOT DONE / RISKS: <남은 일, 위험>
  ```

실패나 테스트 오류는 오류 출력과 함께 다시 맡겨 고치게 한다 (Orca면 안내서의 재시도 절차). 두 번 실패하면 사용자에게 올린다.

## 5. 검증 (Validator)

Coder의 보고를 믿지 않고 **처음부터 다시** 확인한다.
- 프로필의 빌드·테스트 명령 재실행 (/kit:check의 2·3단계)
- diff가 작업 지시의 담당 범위 안인지 (`git diff --stat <base>...HEAD`)
- 시크릿 검사: `git diff <base>...HEAD | grep -nE 'AKIA|secret|api[_-]?key|BEGIN .*PRIVATE'`
- 숫자·집계는 보고서 값을 베끼지 않고 다시 계산한다
- 권한 변경은 실제 실행 역할 기준으로 확인한다. 관리자 키로 돌린 로컬 테스트는 권한 누락을 가린다. AWS면 `aws iam simulate-principal-policy`로 작업이 쓰는 모든 액션을 한 번에 확인한다 (로그에는 처음 막힌 권한만 찍힌다)

## 6. T2 적용

1. 미리보기를 실행하고 바뀌는 것만 요약해 보여준다 (예상 밖 변경이 있으면 멈춘다).
2. 명시적 승인 후 적용한다. Orca로 여러 단계를 돌리는 중이면 적용 단계를 Orca의 승인 게이트(`gate-create`)로 막아 두고, 승인받으면 푼다 (방법은 Orca 안내서). 자동 모드나 훅이 막으면 **우회하지 않는다.** 명령을 보여 주고 사용자가 `! <명령>`으로 직접 실행하게 한다.
3. 적용 후 계획의 완료 조건(사용자가 보는 결과)까지 확인한다. 사용자만 할 수 있는 확인(로그인한 화면 등)은 다음 할 일로 남긴다.

## 7. 병합과 기록 (Tracker, Reporter)

- 검증을 통과한 워커 브랜치를 병합한다. 커밋은 /kit:commit 규칙, 본문에 `Refs: docs/plans/<파일>`.
- 계획 체크박스를 `[x]`로 바꾸고 단계별 결과를 한 줄씩 덧붙인다. 모두 끝나면 `status: done`.
- 정리: Orca 워커는 Orca 안내서의 완료 정산을 따른다 (`worker_done`이 Task 상태를 정리하므로 `task-update`로 다시 바꾸지 않는다). 병합이 끝난 하위 worktree와 `completed`가 된 작업 worktree는 사용자 확인 후 `orca worktree rm --worktree <selector>`로 지운다 (release·abandon은 worktree를 지우지 않는다. 지휘 세션이 그 안에 있으면 마지막 보고에서 Orca에서 지워 달라고 안내한다). Orca 밖에서 만든 worktree는 병합 후 `git worktree remove`, 브랜치는 `git branch -d`. 남은 worktree가 있으면 목록으로 보고한다.
- 작업 단위가 끝나면 /kit:devlog로 기록한다. 남은 확인은 "다음 할 일"에 적는다 (다음 세션이 이어받는다).

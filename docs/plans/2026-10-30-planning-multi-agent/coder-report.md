# S1 Coder 보고

- 담당: Claude Coder (Orca 탭 `term_20155be1-a731-49bc-8d67-336ec50b0b0c`), 실행 모델 Opus 5.5 (`global.anthropic.claude-opus-5-5`, 세션이 알려준 모델)
- Task / Dispatch: `task_c1a51af85d34` / `ctx_84cf257a40ae`
- 기준: `92f8bdf` (기획 커밋). 규칙 근거는 이 worktree 원문만 썼고 본체는 읽지도 고치지도 않았다.
- 커밋: `1dd46b6` feat(harness): 다른 모델 기획 반박·불확실성 배치·승인 규칙·독립 검증 시나리오 (0.14.0), 그리고 이 보고서 커밋 (해시는 `git log -1 -- docs/plans/2026-10-30-planning-multi-agent/coder-report.md`)

## 파일별 변경

| 파일 | 변경 | 기획서 항목 |
|---|---|---|
| `skills/harness/SKILL.md` | 서문: Plan Reviewer를 반박자(다른 모델)와 승인자(사용자)로 나눔. 1단계: T0 예에서 "20줄 미만" 대신 "원인과 해법이 분명한 작은 수정", "변경 규모로"를 지우고 불확실성·분리 가능성 기준과 배치 표 4행, "필요한 역할만". 2단계: **기획 반박** 소절(대상/검토자·실제 모델 확인·"미확인"/묻는 것·반례 ≤3 + 확인 방법/반영 기록/구현 전 차단·예외 기록), **승인 규칙** 소절(계획 승인 vs 미리보기, 다시 승인받는/묻지 않는 경우, 점검 요청, push 분류, guard 확인 창 별개). 기존 "T2는 명시적 승인 전 실행 안 함"은 승인 규칙으로 옮김. 3단계: "의존이 없는 단계는 병렬로"를 "배치는 1단계 표로"로, 탭 문구에 "필요한 역할만". 5단계: 독립 실패 시나리오 1~3개, 기존 테스트 재사용·베낀 테스트 금지·문서 변경 확인 방법, 보고 항목 4개. 6단계: 적용까지 승인 + 미리보기 일치면 바로 적용 / 구현만 승인·예상 밖 변경이면 적용 승인, guard 확인 창은 우회하지 않음 | 설계 1·2·3·4, 반례 1·2, 작은 지적(서문) |
| `skills/plan/SKILL.md` | 양식에 "기획 반박 (반박 대상만)" 섹션, S3 검증 예시에 "완료 기준에서 직접 고른 실패 시나리오 1~3개", 등급 줄을 "배포가 되는 push" + "일반 push는 프로필 push 줄", 새 "5. 기획 반박"(harness 2단계 참조, 사용자에게 묻는 건 이 뒤), "6. 확인과 커밋" 3번: 기획만 요청이면 멈춤, 구현까지 요청·승인이면 다시 묻지 않음 | 설계 1·3, 작은 지적(양식) |
| `skills/check/SKILL.md` | 서문에 harness 검증 단계로 쓸 때 지휘 세션 보고 + 범위 안 결함은 재승인 없이 Coder 재작업, 보고 양식에 "독립 시나리오 (harness 검증일 때)", "어떤 것을 고칠지 묻는다"에 "(따로 요청한 점검일 때)" | 설계 3(점검 요청)·4 |
| `skills/init/SKILL.md` | 서문: 원격 저장소 생성만 확인, 초기화 중 push 없음은 명시적 예외, 이후는 프로필 push 줄. 6단계 push 문장 같은 취지. 프로필 양식 작업 등급 줄에 "(불확실하거나 영향이 큰 기획은 다른 모델 반박 먼저)". 갱신 모드: 예전 양식 줄도 바꾸자고 제안 | 설계 3(push), 반례 3 |
| `skills/design/SKILL.md` | 94줄 "배포·배포가 되는 push는 T2다 … 일반 push는 프로필 push 줄을 따른다" | 설계 3(push) |
| `scripts/orca_context.py` | NOTE 한 문장: "변경 규모상 워커가 필요하면" → "배치는 줄 수가 아니라 위험도·불확실성·분리 가능성으로(harness 1단계). 불확실하거나 영향이 큰 기획은 다른 모델이 반박한 뒤 구현". 나머지 문구·로직은 그대로 | 설계 2 |
| `README.md` | 스킬 표 plan·harness·check 줄, 로드맵 한 줄 | 범위 |
| `CLAUDE.md` | 프로필 작업 등급 줄을 init 양식과 같게, "harness 스킬" 항목에 0.14.0 결정 요약과 이유 | 범위 |
| `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` | version 0.13.1 → 0.14.0 (둘 다) | 범위 |

해석한 곳 (질문 없이 정함, 검증자가 보면 좋음):
- plan의 기획 반박 단계는 "3. 설계 점검" 바로 뒤가 아니라 "4. 기획서 작성" 뒤(새 5단계)에 두었다. 반박자는 쓰인 기획서를 읽어야 하고, harness가 참조하는 "4. 기획서 작성" 번호도 그대로 유지된다. 기존 "5. 확인과 커밋"은 6이 됐다 (다른 파일에서 이 번호를 참조하는 곳 없음, grep 확인).
- harness의 반박 검토자 줄은 Orca 명령을 다시 쓰지 않고 "1단계 마지막 줄처럼 Codex·agy 워커로"라고 참조했다 (Orca가 없으면 1단계 줄대로 `codex exec`가 허용되므로 다른 실제 모델 조건은 그대로).

## 완료 증거 (커밋 `1dd46b6` 기준으로 실행)

1. `claude plugin validate .` → `✔ Validation passed with warnings`. 경고는 CLAUDE.md(정상)와 디렉터리 제출용 항목(LICENSE 없음, icon 없음)이다. 이번 변경과 관계없고 변경 전부터 있었다.
2. `sh scripts/test_guard.sh` → exit 0, `ok` 49줄, 실패 0. 변경 전 출력과 diff하면 임시 폴더 이름만 다르고(정규화 뒤 동일) 개수·판정이 같다. guard.py·githooks는 손대지 않았다.
3. Orca 안: `echo '{"cwd":"…/kit-planning-multi-agent"}' | TERM_PROGRAM=Orca sh scripts/py.sh scripts/orca_context.py` → JSON에 새 문장 "배치는 줄 수가 아니라 위험도·불확실성·분리 가능성으로 정합니다(harness 1단계). 불확실하거나 영향이 큰 기획은 다른 모델이 반박한 뒤 구현합니다." 포함 (프로필 있음 → init 제안 줄 없음). Orca 밖: `env -u TERM_PROGRAM -u ORCA_WORKTREE_ID …` → 출력 0바이트.
4. `grep -rn "push" skills/plan skills/design skills/harness skills/init | grep T2` → 5줄(plan:103, design:94, init:72, harness:23, harness:60) 모두 "배포가 되는 push"만 T2. `grep -v "배포가 되는 push"`로 다시 거르면 남는 줄 없음.
5. `git diff --stat 92f8bdf..HEAD` (보고서 커밋 전) → 10개 파일, +68/−29, 모두 담당 범위 안. 기획서·plan-review.md·guard.py·githooks는 변경 없음.
6. 로컬 커밋 `1dd46b6` + 보고서 커밋. push·병합 안 함.

## 사고 기록

- 작업 중 검사 명령 끝에 잘못 붙인 `git checkout -q 92f8bdf -- .`가 커밋 전 수정 전체를 되돌렸다. 시작할 때 worktree가 깨끗했으므로 잃은 것은 이 세션의 수정뿐이고, 같은 치환 스크립트(`/tmp/coder-s1/apply.py`)로 다시 적용했다. 다시 적용한 diff stat이 처음과 같았고(10개 파일, +68/−29) 바로 커밋한 뒤 위 검사를 모두 다시 돌렸다.

## 남은 위험

- 행동 검증은 하지 않았다: 새 세션(worktree를 `--plugin-dir`로 로드)이 실제로 반박 불가 시 멈추는지, 기획만 요청하면 멈추는지, 구현까지 요청하면 다시 묻지 않는지, "점검해줘"에 수정 없이 보고하는지는 S2 Validator 몫이다.
- harness가 107줄에서 133줄로 늘었다 (스킬 로드 비용). 표 하나와 짧은 소절로 줄였지만 더 줄일 여지는 검증자 판단에 맡긴다.
- "실행 모델 확인"은 `launch.effective`가 null일 수 있다 (S0에서 실제로 null). 문서는 "또는 워커가 보고한 모델"을 허용하지만, 지휘 세션이 `worker-show`의 `projection.provider.model`을 보는 방법은 harness에 적지 않았다 (Orca 안내서 영역이라 판단).
- plan 단계 번호가 5→6으로 바뀌어, 예전 스킬을 들고 있는 세션의 설명과 번호가 다를 수 있다.

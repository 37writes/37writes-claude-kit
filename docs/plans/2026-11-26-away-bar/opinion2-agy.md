Gemini 4 Neon

# 자리 비움 모드 2차 설계 의견

사용자 의도는 **"정한 시각까지 멈추지 않고 일을 끝내는 것"**이지만, **훅 제거(전부 허용)는 오답**이다. 세 문제는 층위가 다르므로(턴 종료 · 배포 선행 · 훅 오탐) 각각 다른 해법이 필요하며, 훅을 통째로 끄면 배포 하나를 풀려다 `rm -rf ~`·강제 push·IAM·DB 삭제까지 무방비로 열린다. 먼저 내 안을 세우고 작성자 초안을 반박한다.

## 1. 내 안

### (1) 질문 창 없이 글로 묻고 턴 종료
- **원인**: `PreToolUse`는 도구 호출만 잡으므로 평문 질문 뒤 턴 종료를 못 막고, `AskUserQuestion`은 턴 중간 도구라 `Stop`으로 잡히지 않는다.
- **방안 비교 (아침 최악의 결과)**:
  - **A. 훅 없음(완화)**: 프롬프트 지시만 유지 → 지시를 무시하고 글로 질문 후 밤새 멈춤.
  - **B. 무조건 `Stop` 1회 차단**: 자리 비움 중 모든 `Stop`을 1회 `block` → 완료된 탭·Orca 워커·배포 대기를 깨워 억지 수정/중복 보고, 도구 1회 호출 후 재종료 시 **무한 루프·토큰 낭비**.
  - **C. 조건부 `Stop` + `AskUserQuestion` deny (추천)**: `AskUserQuestion`은 `PreToolUse` deny + 보류 목록 기록. `Stop`은 `last_assistant_message`에 질문·확인 대기 신호가 있을 때만 차단하고, **세션·회차 상한 + 무진전 즉시 종료 + Orca 워커 제외** 적용 → 최악: 질문 기호 없는 애매한 종료 1회 미감지, 또는 완료 보고 속 `?`로 불필요한 확인 1턴.
- **반례와 방어**: *반례* — 깨어난 에이전트가 `git status`만 한 번 돌리고 다시 질문하며 끝내면 새 턴이라 `stop_hook_active`가 `false`로 초기화돼 반복 차단. *방어* — `away/sessions.json`에 **세션·회차당 총 차단 상한(최대 2회) + 최소 간격(10분) + 직전 차단 이후 진전(파일 수정·커밋·테스트) 없으면 즉시 통과**를 강제.
- **환경별 동작**: 공식 훅 문서상 `PreToolUse`는 `bypassPermissions`에서도 돌고, `Stop`은 메인 에이전트 종료 시 `stop_hook_active`·`last_assistant_message`를 받아 차단 가능하다. 서브에이전트는 별도 `SubagentStop` 이벤트라 `Stop`이 직접 잡지 않는다(메인 턴 종료 시에만 발화). 단, 로컬 Claude Code(2.1.332) + Orca bypass 탭에서 `AskUserQuestion` deny가 창 없이 계속되는지, `Stop`이 Orca 워커(`worker_done` 직후)를 깨우는지, 워커를 환경변수로 지휘 세션과 구분할 수 있는지는 실기 **미확인**(`orca_context.py`는 `TERM_PROGRAM=Orca`/`ORCA_WORKTREE_ID`만 확인). 확인 전에는 워커/완료 흔적 세션을 `Stop` 차단에서 제외해야 한다.

### (2) 배포가 되어야 다음 일이 가능한 작업
- **원인**: 1단계는 모든 배포를 deny하므로 배포 결과에 의존하는 후속 작업이 밤새 멈춘다.
- **방안 비교 (아침 최악의 결과)**:
  - **A. 훅 아예 끄기(전부 허용 스위치)**: 자리 비움 중 guard 전체 해제 → `rm -rf`·강제 push·`cdk destroy`·IAM 변경까지 실행돼 **복구 불가 데이터/인프라 손실**.
  - **B. 단순 사전 승인(레포+규칙 allow)**: 출발 전 앱에서 고른 규칙만 허용 → 깨진 코드·DB 교체(`Replacement`)가 든 배포가 밤새 반복돼 **운영 장애·비용 급증**.
  - **C. 검증 게이트 결합 일시 배포 티켓 (추천)**: 앱에서 **레포 + 액션 + 스택/환경 + 횟수 상한(1~2회) + 만료시각** 티켓 발급. `guard`는 티켓 일치 + **사전 검증(`verify`/`cdk diff` 통과, 파괴 변경 없음)** 때만 통과, 파괴 규칙(`destroy`·강제 push·IAM·DB 삭제·`rm -rf`)은 영구 제외 → 최악: 같은 UID 한계로 위조 가능성은 남고, diff에 안 드러나는 런타임 버그가 배포될 수 있음.
- **반례와 방어**: *반례* — 배포 실패 뒤 코드 수정·재배포가 5회 폭주하거나 `cdk diff`에 리소스 삭제/치환이 섞임. *방어* — 티켓당 **실행 횟수 상한(기본 1, 최대 2)** 차감 + 실패 시 즉시 소진/잠금(자동 재배포·롤백 금지) + diff에 `[-]`/`Replacement`/IAM 변경 감지 시 deny.
- **"guard 전체 끄기" 스위치**: **반대(두지 않음).** bypass 다중 탭의 마지막 안전망이 습관적 해제로 무력화된다.
- **잘못된 배포 위험을 감수 가능하게 하는 최소 조건**: ① 레포·스택/비운영 환경 한정(파괴 규칙 영구 제외), ② 사전 검증(테스트 통과 + `cdk diff` 기록 및 삭제·치환·IAM 변경 부재), ③ 회차당 1~2회 제한 + 실패 시 즉시 중단, ④ 자리 비움 종료 시 자동 만료 + 아침 목록에 "실행됨(시각·명령·diff 요약)" 기록.
- **`deploy_gate.py`와 관계**: **엔진은 합치고 스코프는 분리한다.** `deploy_gate.py`는 push=배포 레포의 **영구 정책(`CLAUDE.md`) + SHA 고정 + 임시 worktree `verify`**이고, 이번 건은 `cdk deploy` 등 **직접 CLI 배포의 일시 티켓**이다. 영구 정책에 `cdk deploy`를 합치면 평소 확인 창까지 사라지므로 정책 저장소는 분리하되, `verify`/diff 검증 기록과 `guard` 대조 경로는 `deploy_gate`로 통합한다.

### (3) 글 속 `cdk deploy`를 배포 명령으로 오탐
- **원인**: `guard.py` 228행이 `RULES` 정규식을 `command` 원문 전체에 적용하고, `deploy_reasons`·`push_reasons`도 따옴표·heredoc을 무시한 `re.split(r"\n|&&|\|\||;|\|", command)`를 먼저 실행한다. 실제 실행 확인 결과 `git commit -m "cdk deploy 수정"`, `cat <<EOF > note.md\ncdk deploy\nEOF`뿐 아니라 **`git commit -m "제목\n./deploy.sh 수정"`도 오탐**한다.
- **방안 비교 (아침 최악의 결과)**:
  - **A. 배포 규칙 제거**: `RULES`에서 `cdk`/`terraform` 삭제 → 의도치 않은 인프라 배포·삭제 미차단.
  - **B. 단순 `command_words` + 따옴표 인자 제외**: 현재 `re.split` 위에 `RULES`만 이동 → **`psql -c "DROP TABLE users;"` 미탐**, 줄바꿈 커밋·heredoc 오탐 잔존.
  - **C. 셸 구문 인식 토크나이저 + 2트랙 판정 (추천)**: 따옴표·이스케이프·heredoc을 먼저 파싱해 세그먼트·리다이렉션을 분리. **트랙 1(CLI)**: `words[0]` + 전역 옵션을 건너뛴 서브명령 구조로 `git`/`aws`/`cdk`/`terraform`/`deploy.sh`/`ampx` 판정. **트랙 2(페이로드)**: `sh -c`/`eval`/`xargs`·셸 파이프/heredoc은 본문 재귀 검사, `psql`/`mysql`/`sqlite3`/`aws rds-data`는 쿼리 인자에서 SQL 규칙 검사 → 최악: 변수 확장·별칭·스크립트 래퍼 같은 동적 우회는 best-effort 한계로 미탐.
- **반례와 방어**: *반례* — 따옴표 불일치(`ValueError`) 등 파싱 실패 시 빈 토큰으로 넘기면 위험 명령 통과(fail-open). *방어* — 파싱 실패 시 원문 전체 정규식 검사(fail-safe `ask`/`deny`)로 폴백.
- **오탐 완화 시 생기는 미탐(진짜 배포 놓침) 예 3개와 시험**:
  1. **서브셸·명령 치환**: `(cd infra && cdk deploy StackA)` / `$(./deploy.sh)` — `shlex.split`이 `)`를 붙여 `words[0]`이 `'deploy.sh)'`가 되어 현재도 `none` 통과(실측 확인).
  2. **전역 옵션 삽입·내부 따옴표 `sh -c`**: `npx cdk --profile prod deploy ShiP1Agent` (전역 옵션이 `cdk`와 `deploy` 사이에 껴 미탐, 실측 확인) / `bash -c "echo \"go\" && cdk deploy"` (`(["'])(.*?)\1`이 내부 `\"`에서 잘림).
  3. **파이프·heredoc 셸 주입(+ SQL 인자)**: `printf 'cdk deploy\n' | sh` / `cat <<EOF | bash\ncdk deploy\nEOF` (출력·heredoc 무조건 제외 시 미탐; 따옴표 일괄 제외 시 `psql -c "DROP TABLE users;"`도 미탐).
  - **시험**: `scripts/test_guard.sh`에 오탐 방지(FP → `none`: 멀티라인 커밋·heredoc 파일쓰기·`echo`/`rg`)와 미탐 방지(FN → `ask`/`deny`: 위 3종 + `terraform -chdir=infra apply` + `psql -c "DROP TABLE"`) 대칭 매트릭스를 추가해 stdin JSON으로 회귀 검증.

## 2. 작성자 초안 반박

1. **초안 (1) — `stop_hook_active`만으로 무한 루프를 못 막고 정상 종료·워커까지 깨운다.** 깨어난 뒤 도구 1회만 호출하고 다시 멈추면 새 턴이 되어 재차단된다. 무조건 1회 차단하면 완료된 탭·배포 대기·`worker_done` 직후 Orca 워커까지 깨워 토큰 낭비와 중복 작업을 낳는다. **세션·회차 상한 + 무진전 종료 + 질문 필터 + 워커 제외**로 바꿔야 한다.
2. **초안 (2) — "레포+규칙"만 여는 사전 승인은 내용 검증 없는 백지수표다.** 같은 UID 위조보다 현실적인 사고는 정상 에이전트가 버그 코드나 파괴적 리소스 교체를 검증 없이 배포하고 실패 시 반복 재시도하는 경우다. **`deploy_gate`식 `verify`/diff 검증 + 횟수 1~2회 제한 + 실패 시 잠금**이 필수다.
3. **초안 (3) — 단순 `command_words` + 따옴표 제외는 SQL 미탐과 멀티라인 오탐을 동시에 남긴다.** `re.split` 선행 분할은 줄바꿈 커밋·heredoc 오탐을 못 고치고(실측), 따옴표 일괄 제외는 `psql -c "DROP TABLE"`을 뚫으며, 기존 정규식은 `cdk --profile prod deploy`·`(cdk deploy)`를 놓친다. **구문 인식 토크나이저 + CLI/페이로드 2트랙**으로 설계해야 한다.

## 3. 메뉴 막대 앱 범위와 순서

셋을 한 번에 묶지 말고 **3단계로 분리**한다:
1. **선행(앱 전, T1) — (3) `guard.py` 오탐·미탐 수정**: 평소에도 즉시 이득이 크고 `test_guard.sh`로 결정론적 검증 가능.
2. **메뉴 막대 앱 v1 (T1) — 앱 + `AskUserQuestion` deny + 세션 관측 + 제한적 `Stop` 훅**: 워커 동작을 실기 확인한 뒤 적용하고, 밤사이 실제 어떤 배포가 얼마나 막히는지 아침 목록 실측 데이터를 모은다.
3. **메뉴 막대 앱 v2 (T2) — (2) 검증 게이트 결합 일시 배포 티켓**: 권한 확장(T2)이므로 v1 실측에서 실제 병목이 확인된 배포 유형에 맞춰 `deploy_gate` 검증 + 횟수 제한 + UI 체크리스트로 도입한다.

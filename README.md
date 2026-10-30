# 37writes-claude-kit

1인 개발자 37writes의 Claude Code 플러그인. 맥, 윈도우, 리눅스 어디서든 같은 개발 프로세스를 쓰기 위한 스킬과 훅 모음.

## 설치

### 다른 컴퓨터 (GitHub에서 설치)
Claude Code 안에서:
```
/plugin marketplace add 37writes/37writes-claude-kit
/plugin install kit@37writes
```
업데이트: `/plugin marketplace update 37writes` 후 `/plugin update kit@37writes`

### 이 폴더를 직접 고치면서 쓰기 (개발 모드)
```
claude --plugin-dir ~/Documents/dev/37writes-claude-kit
```
스킬을 수정한 뒤에는 Claude Code를 다시 시작하면 반영된다.

필요 조건: git, Python 3 (윈도우는 Git Bash가 함께 설치된 Git for Windows)

## 쓰는 법: 말로 요청한다

명령을 외우지 않아도 된다. 하고 싶은 일을 그대로 말하면 kit:harness가 의도를 읽고 필요한 절차(기획, 구현, 검증, 기록, 배포)를 고른다.

| 이렇게 말하면 | 일어나는 일 |
|---|---|
| "Python GIL이 뭐야?" | 답만 한다. 파일·기획서·커밋을 만들지 않는다 |
| "로그인 기능 만들어줘" | 등급(T0~T2) 분류 → 기획서(`docs/plans/`) → 구현(필요하면 Orca 워커) → 독립 검증 → 커밋. 기획서에 결과가 남는다 |
| "이 오류 고쳐줘" + 로그 | 읽기 전용 진단 먼저 → 원인이 분명하면 바로 고치고, 아니면 조사부터 |
| "이어서 해줘", "어디까지 했지?" | 모든 worktree의 진행 중 기획서만 모아 첫 미완료 단계부터 이어 한다 (어디까지면 보고만). 끝난·지운 기획서는 보고하지 않는다 |
| "이 프로젝트 구조랑 개발 순서 잡아줘" | 프로젝트 설계 `docs/plans/project.md` (모듈 경계, 기능 목록과 순서) |
| "이 화면 AI 티 안 나게 고쳐줘" | design 절차 (캡처 → 진단 → 방향 선택 → 토큰 → 전/후 비교) |
| "점검해줘" | 빌드·테스트 + 리뷰 결과를 먼저 보고, 고르는 것만 수정 |
| "배포해줘" | 프로필의 배포 방식대로 release 절차. 승인 조건은 harness 공통 규칙 "push와 배포", 완료는 배포한 SHA의 결과로 판정 |
| "이거 블로그로 쓰자" | 브리프(주장별 근거 포함) → 블로그 코디네이터가 글 워커 지휘·검수. 발행은 글마다 승인 |
| (다른 프로젝트에서) "kit의 이 부분 고치고 싶다" | kit 저장소에 이슈만 남기고 하던 일로 돌아간다 |

슬래시 명령(`/kit:plan` 등)으로 직접 불러도 같다.

## 스킬

| 스킬 | 하는 일 |
|---|---|
| `kit:harness` | 작업 요청의 입구. 의도 → 흐름 표, 공통 규칙(등급·배치·다른 모델 반박·승인·push·자동 배포·검증·완료 판정·기록), 이어서 하기 |
| `kit:plan` | 코드를 먼저 읽고 추천값이 달린 질문으로 기획서 또는 프로젝트 설계(`docs/plans/project.md`) 작성 |
| `kit:init` | 프로필(CLAUDE.md)에 작업에 필요한 사실만 보완, commit-msg 훅. 기존 내용은 덮지 않는다 (AGENTS.md만 있으면 `@AGENTS.md` + 프로필) |
| `kit:commit` | 변경을 논리 단위로 나눠 `type(scope): 한국어 요약` 형식으로 커밋 |
| `kit:check` | 프로필의 빌드·테스트 + 언어별 체크리스트 리뷰, 보고 후 승인된 것만 수정 |
| `kit:design` | 캡처 → AI·템플릿 티 체크리스트 진단 → 방향 2~3개 중 선택 → 색·글꼴 토큰(대비 계산) → 전/후 캡처 비교 |
| `kit:release` | 버전·릴리즈 노트·CHANGELOG, 배포(자동 배포 정책이면 `deploy_gate.py`로 검증·확인), Amplify는 그 SHA의 job + 핵심 기능 확인 / exe 묶음·체크섬 / 앱(첫 배포 때 확정) |
| `kit:blog` | 대화·기획서·커밋으로 블로그 글(시리즈 가능). tech-blog의 "블로그 코디네이터" 탭이 글마다 worktree와 글 워커를 띄워 지휘(도표 SVG, 다른 모델 검수, 회사 정보 필터링), 승인받은 글만 발행 |
| `kit:feedback` | 다른 프로젝트에서 떠오른 kit 개선 아이디어를 이 저장소에 GitHub 이슈(feedback 라벨)로 |

## 기록: 기획서와 커밋

따로 쓰는 작업 로그는 없다. 기록은 작업 중 필요한 만큼만 남긴다.

- 질문은 아무 파일도 만들지 않는다. 작은 수정은 커밋 메시지가 기록이다.
- 기능 작업은 기획서(`docs/plans/YYYY-MM-DD-<slug>.md`)의 결정 & 이유, 단계별 결과, `## 남은 일`에 적는다. 단계 결과는 그 단계의 커밋에 같이 들어가고, 기획 커밋부터 그 작업의 모든 커밋 본문에 `Refs: docs/plans/<파일>`이 붙는다.
- **끝난 기획서는 지운다.** 마지막 작업 커밋에 `status: done`(그만두면 `abandoned` + 이유)과 마지막 결과·`## 남은 일`을 넣고, 바로 뒤 삭제 커밋(`docs(plan): <slug> 완료, 기획서 삭제`)에서 기획서와 보고서 폴더를 `git rm`한다. 남은 파일이 곧 진행 중인 작업이라 나중에 헷갈리지 않는다. `docs/plans/project.md`는 남기고 끝난 항목에 `완료 <커밋>`을 적는다.
- 지운 기획서 찾기:
  ```sh
  git log --all --format='%h %s' -- docs/plans/<파일>     # 그 기획서를 건드린 커밋 (맨 위가 삭제 커밋)
  git show <삭제 커밋>^:docs/plans/<파일>                  # 지우기 직전 내용 (done 상태와 결과)
  git log --grep "Refs: docs/plans/<파일>"                # 그 작업의 커밋
  ```

## 자동 배포 (선택)

push가 곧 배포인 레포에서 프로필에 정책 줄을 두면, 정책 안의 배포를 검증 기록과 함께 끝까지 진행할 수 있다. 어떤 배포가 정책 안이고 언제 승인을 받는지(승인 조건)는 harness 공통 규칙 "push와 배포"에 있다.
```
- **자동 배포**: 허용 · 대상 `origin/main` · 검증 `npm ci && npm test` · 제외 `infra/**`, `amplify/backend/**` · 확인 `sh scripts/check_deploy.sh {sha}`
```
- `대상`·`검증`·`확인`은 필수, `제외`는 선택. 하나라도 없거나 형식이 틀리면 정책 없음.
- 순서: `deploy_gate.py verify`(그 SHA의 깨끗한 임시 checkout에서 검증 명령 실행·기록, 검증 명령이 추적 파일을 바꾸면 실패) → `git push <원격> <40자리 SHA>:refs/heads/<브랜치>` → `deploy_gate.py confirm`(확인 명령에 SHA를 넣어 실행, exit 0일 때만 완료).
- guard(위험 명령 확인 훅)가 push 때 대조하는 것: 전체 SHA push 하나, 원격·브랜치가 정책 대상과 같음, push URL = fetch URL, 실제 원격 base에서 fast-forward, base와 SHA의 정책이 같음, 그 SHA의 검증 기록(tree·정책·명령 일치, exit 0), 바뀐 파일이 `제외` 밖이고 시크릿 패턴 없음. 하나라도 어긋나면 확인 창이 뜬다.
- guard가 판단하지 못하는 것(IAM·시크릿·인프라·마이그레이션·데이터 삭제, 태그 push 등)의 승인도 harness 공통 규칙 "push와 배포"에 있다.
- 배포 실패(`confirm` 실패·시간 초과)면 멈추고 SHA·실행 id·롤백 방법을 보고한다. 자동 롤백은 없다.
- **한계**: guard는 Claude의 Bash 명령을 보는 best-effort 확인이지 권한 경계가 아니다. 검증 기록 폴더를 건드리는 명령은 묻지만, 다른 경로로 기록 파일을 고치는 것까지 막지는 못한다. 확인 명령이 HTTP 200만 보면 완료 증거가 되지 않으므로 그 SHA의 배포 실행과 핵심 기능을 확인하게 쓴다.
- 블로그(tech-blog)는 이 정책을 쓰지 않는다 (발행 절차는 blog 스킬).

## /kit 패널

`/kit`을 입력하면 kit 패널이 열리고, 한 번 더 입력하면 닫힙니다. Claude를 거치지 않으므로 토큰을 쓰지 않습니다.

- **스킬**: 설치된 `/kit:*` 명령과 한 줄 설명 (스킬을 추가하면 자동 반영)
- **이 프로젝트**: 구분, 진행 중 기획서(제목·상태·남은 단계). Claude의 답이 끝날 때마다 갱신

패널을 띄울 수 없는 환경(`claude -p` 등)에서는 같은 내용을 텍스트로 보여 줍니다.

## 훅 (자동 실행)

| 훅 | 시점 | 하는 일 |
|---|---|---|
| 이어하기 | 세션 시작 (kit 프로젝트만) | "작업 요청은 kit:harness를 먼저 읽는다" 한 줄과 모든 worktree의 진행 중 기획서 목록을 Claude에게 전달, commit-msg 훅이 없으면 설치. kit 레포에서는 열린 feedback 이슈 표시 |
| Orca 작업 절차 | 세션 시작 (Orca IDE 안에서만, 모든 레포) | 워커/지휘 세션 판정, 지휘 세션은 첫 요청 전에 kit:harness를 읽고, 다른 모델 의견은 Orca 워커 탭으로 |
| 위험 명령 확인 | 명령 실행 직전 (모든 레포) | git push(프로필이 `push: 배포 아님`이면 강제·삭제 push만, 자동 배포 정책 안의 SHA push는 통과), reset --hard, rm -rf ~, DROP TABLE, AWS 삭제, cdk deploy, terraform apply, IAM 권한 변경 등은 사용자 확인 |
| commit-msg (git 훅) | 모든 커밋 | 커밋 메시지 형식 검사. VS Code에서 직접 커밋해도 적용 |

kit 프로젝트 = CLAUDE.md에 프로필 블록(`<!-- 37writes-kit:profile:start -->`)이 있는 git 레포. 예전에 init한 레포(`docs/devlog/`가 있음)도 호환으로 인식한다. `docs/plans/`만 있는 레포는 kit 프로젝트가 아니다. kit 프로젝트가 아니어도 "이어서 해줘"는 동작한다.

## 없앤 기능 (0.15.0)

| 없앤 것 | 이유 | 과거 파일 |
|---|---|---|
| `/kit:devlog` 작업 로그, 답변 끝 devlog 알림(Stop 훅) | 결정·결과는 이미 기획서에 있고 커밋은 `Refs`로 찾는다. 같은 내용을 두 번 적고 알림이 흐름을 끊었다 | 각 레포의 `docs/devlog/`는 그대로 둔다 |
| `/kit:til` 개념 메모 | 배운 것은 기획서의 결정 & 이유에 남는다. 블로그 원료는 대화·기획서·커밋으로 충분하다 | my-notes 저장소는 삭제 (2026-10-30, 사용자 결정). 블로그는 사용자가 지정한 메모 파일만 읽는다 |
| `/kit:weekly` 주간 정리, kit 등록부 쓰기 | 등록부를 읽던 곳이 weekly뿐이었다 | 등록부 `~/.config/37writes-kit/repos.txt`와 my-notes는 삭제 (2026-10-30, 사용자 결정) |

## 커밋 형식
```
feat(auth): 소셜 로그인 추가

- 구글/애플 OAuth 연동
Refs: docs/plans/2026-10-14-social-login.md
```
type: feat, fix, docs, refactor, perf, test, style, build, ci, chore, revert

## 로드맵
- [x] init, commit, devlog(0.15.0에서 제거), 훅
- [x] plan, til(0.15.0에서 제거)
- [x] blog (GitHub Pages, 글마다 핵심 개념 도표)
- [ ] docs (회사/대학원 양식), 애드센스 연결 (개인 도메인 구매 후)
- [x] check, release, weekly(0.15.0에서 제거)
- [x] harness (AWS Deep Insight식 에이전트 작업 절차), 대화 기반 블로그 시리즈
- [x] Orca IDE에서 시작한 세션에 harness 절차 자동 안내 (모든 레포)
- [x] design (AI 티 안 나는 화면, tech-blog 종이 노트로 시범)
- [x] blog를 글마다 worktree로 (말로 시작, 승인 뒤 main 병합), guard에 ampx·deploy.sh 확인
- [x] push가 배포가 아닌 레포는 커밋 승인만으로 push (guard가 프로필의 push 줄을 읽음)
- [x] 기획은 다른 모델이 반박, 배치는 불확실성·분리 가능성으로, 승인 규칙 정리, 검증자가 고른 실패 시나리오
- [x] blog 코디네이터 (tech-blog 본체 탭이 글 워커를 띄우고 검수·병합·정리)
- [x] 0.15.0: 말로 요청하면 harness가 절차를 고름, 기록은 기획서와 커밋(끝나면 기획서 삭제), 모든 worktree에서 이어서 하기, 프로필 자동 배포 정책, 프로젝트 설계(project.md). devlog·til·weekly 제거

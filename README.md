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

## 스킬

| 명령 | 언제 | 하는 일 |
|---|---|---|
| `/kit:init` | 프로젝트당 한 번 | git init, 프로젝트 프로필(CLAUDE.md), `docs/devlog`·`docs/plans`, commit-msg 훅 |
| `/kit:commit` | 커밋할 때 | 변경을 논리 단위로 나눠 `type(scope): 한국어 요약` 형식으로 커밋 |
| `/kit:devlog` | 작업 단위가 끝났을 때 | `docs/devlog/YYYY-MM.md`에 정해진 형식으로 작업 로그 기록 |
| `/kit:plan` | 새 기능을 시작할 때 | 코드를 먼저 읽고 추천값이 달린 질문으로 `docs/plans/` 기획서 작성 (등급, 단계별 담당·완료 조건). 불확실하거나 영향이 큰 기획은 다른 모델이 반박한 뒤 승인, 구현까지 맡기면 다시 묻지 않음 |
| `/kit:harness` | 기능·버그·배포·권한 작업을 시작할 때 (Claude가 알아서 부름) | 위험도 T0~T2 분류, 배치는 불확실성·분리 가능성으로 → 계획(필요하면 다른 모델 반박) → 워커(Orca/서브에이전트)에게 작업 지시 → 독립 검증(검증자가 고른 실패 시나리오 포함) → T2는 승인·미리보기 → 기록·정리 |
| `/kit:til` | 개발 중 새 개념을 알았을 때 | `~/Documents/dev/my-notes/til/`에 개념 메모 저장 (블로그 원료) |
| `/kit:blog` | "이 내용 블로그로 쓰자" 같은 말이나 직접 호출 | 대화나 TIL 메모를 블로그 글(시리즈 가능)로. 출발 세션은 브리프만 써서 tech-blog의 "블로그 코디네이터" 탭에 넘기고, 코디네이터가 글마다 worktree와 글 워커를 띄워 지휘한다(도표 SVG, 다른 모델 검수, 회사 정보 필터링). 코디네이터가 검수하고 승인받으면 main에 병합해 37writes.github.io에 발행 |
| `/kit:design` | 화면을 만들거나 고칠 때 (Claude가 알아서 부름) | 캡처 → AI·템플릿 티 체크리스트 진단 → 방향 2~3개 중 선택 → 색·글꼴 토큰(대비 계산) → 테마 덮어쓰기 적용 → 전/후 캡처 비교 |
| `/kit:check` | 머지·배포 전 | 프로필의 빌드·테스트 실행 + 언어별 체크리스트 리뷰, 보고 후 승인된 것만 수정 (harness 검증 단계에서는 지휘 세션에 보고) |
| `/kit:release` | 배포할 때 | 버전·릴리즈 노트·CHANGELOG, Amplify 배포 확인 / exe 묶음·체크섬 / 앱(첫 배포 때 확정) |
| `/kit:weekly` | 주 1회 | 모든 kit 프로젝트의 devlog·커밋·TIL·블로그를 모아 주간 정리 (my-notes/weekly) |
| `/kit:feedback` | 다른 프로젝트에서 kit 개선 아이디어가 떠올랐을 때 | 대화 맥락을 붙여 이 저장소에 GitHub 이슈(feedback 라벨)로 등록, 하던 작업으로 복귀 |

## /kit 패널

`/kit`을 입력하면 kit 패널이 열리고, 한 번 더 입력하면 닫힙니다. Claude를 거치지 않으므로 토큰을 쓰지 않습니다.

- **스킬**: 설치된 `/kit:*` 명령과 한 줄 설명 (스킬을 추가하면 자동 반영)
- **이 프로젝트**: 구분, 최근 devlog, 기록 안 된 커밋 수, 다음 할 일. Claude의 답이 끝날 때마다 갱신

패널을 띄울 수 없는 환경(`claude -p` 등)에서는 같은 내용을 텍스트로 보여 줍니다.

## 훅 (자동 실행)

| 훅 | 시점 | 하는 일 |
|---|---|---|
| 이어하기 | 세션 시작 | 최근 devlog의 "다음 할 일"을 Claude에게 전달, commit-msg 훅이 없으면 설치, 레포를 kit 등록부에 등록. kit 레포에서는 열린 feedback 이슈 표시 |
| Orca 작업 절차 | 세션 시작 (Orca IDE 안에서만) | 지휘 세션은 첫 요청 전에 /kit:harness를 읽고 등급 분류부터, 다른 모델 의견도 Orca 워커 탭으로, 워커는 지시 범위만 하고 `worker_done`으로 보고하도록 Claude에게 전달. kit 프로필이 없는 레포면 /kit:init 제안 |
| 위험 명령 확인 | 명령 실행 직전 | git push(프로필이 `push: 배포 아님`이면 강제·삭제 push만), reset --hard, rm -rf ~, DROP TABLE, AWS 삭제, cdk deploy, terraform apply, IAM 권한 변경 등은 사용자 확인 |
| devlog 알림 | 답변 끝 | 기록 안 된 커밋이 새로 생기면 한 번 알림 |
| commit-msg (git 훅) | 모든 커밋 | 커밋 메시지 형식 검사. VS Code에서 직접 커밋해도 적용 |

이어하기와 devlog 알림은 kit 프로젝트(`docs/devlog/`가 있는 레포)에서만, Orca 작업 절차와 위험 명령 확인은 모든 레포에서 동작한다.

## 커밋 형식
```
feat(auth): 소셜 로그인 추가

- 구글/애플 OAuth 연동
Refs: docs/plans/2026-10-14-social-login.md
```
type: feat, fix, docs, refactor, perf, test, style, build, ci, chore, revert

## 로드맵
- [x] init, commit, devlog, 훅
- [x] plan, til
- [x] blog (GitHub Pages, 글마다 핵심 개념 도표)
- [ ] docs (회사/대학원 양식), 애드센스 연결 (개인 도메인 구매 후)
- [x] check, release, weekly
- [x] harness (AWS Deep Insight식 에이전트 작업 절차), 대화 기반 블로그 시리즈
- [x] Orca IDE에서 시작한 세션에 harness 절차 자동 안내 (모든 레포)
- [x] design (AI 티 안 나는 화면, tech-blog 종이 노트로 시범)
- [x] blog를 글마다 worktree로 (말로 시작, 승인 뒤 main 병합), guard에 ampx·deploy.sh 확인
- [x] push가 배포가 아닌 레포는 커밋 승인만으로 push (guard가 프로필의 push 줄을 읽음)
- [x] 기획은 다른 모델이 반박, 배치는 불확실성·분리 가능성으로, 승인 규칙 정리, 검증자가 고른 실패 시나리오
- [x] blog 코디네이터 (tech-blog 본체 탭이 글 워커를 띄우고 검수·병합·정리)

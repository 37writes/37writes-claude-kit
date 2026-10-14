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
| `/kit:plan` | 새 기능을 시작할 때 | 코드를 먼저 읽고 추천값이 달린 질문으로 `docs/plans/` 기획서 작성 |
| `/kit:til` | 개발 중 새 개념을 알았을 때 | `~/Documents/dev/my-notes/til/`에 개념 메모 저장 (블로그 원료) |
| `/kit:blog` | 글을 쓰고 싶을 때 | TIL 메모를 블로그 글로 완성, 회사 정보 필터링, 확인 후 37writes.github.io에 발행 |
| `/kit:check` | 머지·배포 전 | 프로필의 빌드·테스트 실행 + 언어별 체크리스트 리뷰, 보고 후 승인된 것만 수정 |
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
| 위험 명령 확인 | 명령 실행 직전 | git push, reset --hard, rm -rf ~, DROP TABLE, AWS 삭제 등은 사용자 확인 |
| devlog 알림 | 답변 끝 | 기록 안 된 커밋이 새로 생기면 한 번 알림 |
| commit-msg (git 훅) | 모든 커밋 | 커밋 메시지 형식 검사. VS Code에서 직접 커밋해도 적용 |

훅은 kit 프로젝트(`docs/devlog/`가 있는 레포)에서만 동작한다.

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
- [x] blog (GitHub Pages)
- [ ] docs (회사/대학원 양식), 애드센스 연결 (개인 도메인 구매 후)
- [x] check, release, weekly

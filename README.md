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

## 훅 (자동 실행)

| 훅 | 시점 | 하는 일 |
|---|---|---|
| 이어하기 | 세션 시작 | 최근 devlog의 "다음 할 일"을 Claude에게 전달, commit-msg 훅이 없으면 설치 |
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
- [ ] plan, check, release, docs (회사/대학원 양식)
- [ ] til, blog (GitHub Pages + 애드센스), weekly

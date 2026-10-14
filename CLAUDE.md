# 37writes-claude-kit 개발 안내

1인 개발자 37writes의 Claude Code 플러그인. 이 레포 자체를 고치는 세션에서 읽는 문서다.
(플러그인 사용법은 README.md)

<!-- 37writes-kit:profile:start -->
## Project Profile (37writes-kit)

- **구분**: 개인
- **설명**: Claude Code 플러그인 (스킬 + 훅). 맥/윈도우/리눅스 공통
- **스택**: Markdown(SKILL.md), Python 3 (훅 스크립트, 표준 라이브러리만), POSIX sh
- **빌드**: `claude plugin validate .`
- **테스트**: 자동 테스트 없음 → 아래 "검증 방법"
- **실행**: 이 Mac은 `~/.zshrc`의 alias `claude='claude --plugin-dir ~/Documents/dev/37writes-claude-kit'`로 항상 로드. 수정 후 Claude Code 재시작하면 반영
- **배포**: GitHub `main` push (공개 레포). 다른 컴퓨터는 `/plugin update kit@37writes`
- **원격**: GitHub `37writes/37writes-claude-kit`

### 작업 규칙
- 커밋: `type(scope): 한국어 요약` 형식 (commit-msg 훅이 검사). 커밋은 /kit:commit 절차를 따른다.
- 작업 로그: `docs/devlog/YYYY-MM.md`, 의미 있는 작업 단위가 끝나면 /kit:devlog 로 기록한다.
- 기획서: `docs/plans/`
- push, 배포, 삭제는 실행 전에 반드시 사용자 확인을 받는다.
<!-- 37writes-kit:profile:end -->

## 구조

```
.claude-plugin/plugin.json       플러그인 이름 "kit" (명령이 /kit:xxx), 버전
.claude-plugin/marketplace.json  마켓플레이스 이름 "37writes" (설치: kit@37writes), 버전 동기화
skills/<이름>/SKILL.md           스킬 9개: init commit devlog plan til blog check release weekly
hooks/hooks.json                 SessionStart(이어하기·훅 설치·등록) / PreToolUse Bash(위험 명령 확인) / Stop(devlog 알림)
scripts/py.sh                    python3 → python → py 순으로 실제 동작하는 Python 실행 (윈도우 스토어 스텁 회피)
scripts/kitlib.py                공통: git 호출(utf-8), kit 레포 판정, devlog 파일, 등록부, JSON 출력
scripts/*.py                     훅과 스킬이 부르는 스크립트
githooks/commit-msg              커밋 형식 검사 git 훅 (sh, Python 불필요)
```

## 핵심 개념과 결정

- **kit 프로젝트 판정**: `docs/devlog/`가 있는 git 레포. 훅은 kit 프로젝트에서만 동작한다.
- **등록부** `~/.config/37writes-kit/repos.txt`: macOS 개인정보 보호(TCC) 때문에 터미널이 `~/Documents`, `~/Desktop` 폴더 목록을 읽지 못한다. 그래서 /kit:weekly는 폴더 탐색 대신 등록부를 쓴다. SessionStart 훅과 `install_githook.py`가 등록한다.
- **git 훅은 clone으로 전파되지 않는다** → SessionStart 훅이 kit 레포에서 commit-msg 훅이 없으면 설치한다. 기존 훅이나 `core.hooksPath`(husky 등)가 있으면 건드리지 않는다.
- **스킬 토큰 비용**: SKILL.md의 `description`은 매 요청 컨텍스트에 들어가므로 짧게. 사용자가 직접 부르는 스킬(init, plan, blog, release, weekly)은 `disable-model-invocation: true`.
- **스킬에서 스크립트 경로**: 스킬 로드 시 "Base directory for this skill"이 주어지므로 `<base directory>/../../scripts/xxx.py`로 참조한다.
- **사용자 보고 언어**: 한국어. 비대화(`claude -p`) 실행에서 영어로 보고한 적이 있어 일부 스킬에 명시했다.
- **커밋 형식**: type은 영어(feat fix docs style refactor perf test build ci chore revert), 요약은 한국어.

## 관련 저장소 (모두 ~/Documents/dev/)

| 폴더 | GitHub | 공개 | 용도 |
|---|---|---|---|
| `37writes-claude-kit` | 37writes/37writes-claude-kit | 공개 | 이 플러그인 |
| `my-notes` | 37writes/my-notes | **비공개** | /kit:til 메모(`til/`), /kit:weekly 정리(`weekly/`). 회사 맥락이 그대로 있으므로 공개 금지 |
| `tech-blog` | 37writes/37writes.github.io | 공개 | 블로그 https://37writes.github.io (Jekyll + Chirpy 7.6, GitHub Actions 배포) |
| `kit_test` | 없음 | - | 스킬 테스트용 레포 |

블로그 메모: 글 `date`가 현재보다 미래면 Jekyll이 빌드에서 뺀다. PWA 오프라인 캐시는 꺼 두었다 (예전 화면이 남는 문제).

## 검증 방법

1. `claude plugin validate .`
2. 훅 스크립트는 JSON을 stdin으로 넣어 직접 실행:
   ```sh
   echo '{"cwd":"<kit 레포 경로>"}' | sh scripts/py.sh scripts/session_start.py
   python3 -c 'import json,sys;print(json.dumps({"tool_input":{"command":sys.argv[1]}}))' "git push" | python3 scripts/guard.py
   ```
3. 스킬은 비대화 모드로 실행해 확인 (질문 단계는 못 하므로 프롬프트에 "추천값으로 진행, 커밋/push 하지 마" 등을 덧붙인다):
   ```sh
   cd ~/Documents/dev/kit_test && claude -p --plugin-dir ~/Documents/dev/37writes-claude-kit \
     --allowedTools "Bash(git:*)" "Read" "Write" -- "/kit:plan ..."
   ```
4. 스크립트를 크게 바꿨으면 `/kit:check scripts`로 점검한다 (실제 버그를 잡은 적 있음).
5. 등록부·HOME을 건드리는 테스트는 `HOME=<임시폴더>`로 격리한다.

## 버전과 배포

- 기능 추가는 minor(0.x.0), 수정은 patch. `plugin.json`과 `marketplace.json`의 version을 **함께** 올린다.
- README의 스킬 표와 로드맵을 갱신한다.
- push 후 다른 컴퓨터: `/plugin marketplace update 37writes` → `/plugin update kit@37writes`

## 남은 일

- `/kit:docs`: 회사·대학원 문서 양식(pptx/docx/md/html)을 받으면 제작
- 애드센스: 개인 도메인 구매(Cloudflare Registrar 추천) 후 블로그에 연결
- `/kit:release`: 첫 실제 배포(Amplify, exe, 앱) 때 절차 확정
- 윈도우 실기 테스트: 훅(py.sh, 인코딩), commit-msg 훅, Git Bash 경로

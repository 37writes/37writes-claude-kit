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
- 작업 등급: T0 바로 처리 / T1 기획서 + 독립 검증 / T2(배포·push·권한·시크릿·데이터 삭제) 사용자 승인 + 미리보기 먼저. 절차는 /kit:harness.
<!-- 37writes-kit:profile:end -->

## 구조

```
.claude-plugin/plugin.json       플러그인 이름 "kit" (명령이 /kit:xxx), 버전
.claude-plugin/marketplace.json  마켓플레이스 이름 "37writes" (설치: kit@37writes), 버전 동기화
skills/<이름>/SKILL.md           스킬 12개: init commit devlog plan harness design til blog check release weekly feedback
hooks/hooks.json                 SessionStart(이어하기·훅 설치·등록, Orca 작업 절차 안내) / PreToolUse Bash(위험 명령 확인) / Stop(devlog 알림)
scripts/py.sh                    python3 → python → py 순으로 실제 동작하는 Python 실행 (윈도우 스토어 스텁 회피)
scripts/kitlib.py                공통: git 호출(utf-8), kit 레포 판정, devlog 파일, 등록부, JSON 출력
scripts/*.py                     훅과 스킬이 부르는 스크립트 (session_text.py: 대화 기록 → 텍스트, /kit:blog용 / shot.py·contrast.py: 캡처·대비, /kit:design용)
githooks/commit-msg              커밋 형식 검사 git 훅 (sh, Python 불필요)
hooks/panel.tsx                  mod(함수 훅 모듈): /kit 명령과 kit 패널. hooks.json의 "modules"에 등록
hooks/panel.test.tsx             패널 테스트 (claude plugin test .)
types/index.d.ts                 패널의 $.state 계약 (plugin.json "types")
```

## 핵심 개념과 결정

- **kit 프로젝트 판정**: `docs/devlog/`가 있는 git 레포. 이어하기·devlog 알림 훅은 kit 프로젝트에서만 동작한다. 위험 명령 확인과 Orca 안내는 모든 레포.
- **Orca 안내** (`scripts/orca_context.py`): Orca IDE 터미널(`TERM_PROGRAM=Orca` 또는 `ORCA_WORKTREE_ID`)에서 시작한 세션이면 어느 레포든 harness 절차 요약을 SessionStart 컨텍스트로 넣는다. 지휘 세션과 워커를 가르는 환경 변수가 없어서 워커는 "지금 작업에 Task·Dispatch ID가 있는 Orca 작업 지시가 걸려 있음"으로 구분한다 (첫 지시로 판정하면 나중에 dispatch되거나 완료 뒤 직접 지시를 받은 세션을 잘못 분류한다). Orca 워커는 사용자 확인 없이 띄운다 (사용자 결정, 2026-10-29). 중요한 건 탭(차례로 일하는 역할)과 worktree(새 작업, 동시에 고치는 워커) 판단이다. guard의 "ask"는 Orca의 `--dangerously-skip-permissions`에서도 확인 창이 뜬다.
- **등록부** `~/.config/37writes-kit/repos.txt`: macOS 개인정보 보호(TCC) 때문에 터미널이 `~/Documents`, `~/Desktop` 폴더 목록을 읽지 못한다. 그래서 /kit:weekly는 폴더 탐색 대신 등록부를 쓴다. SessionStart 훅과 `install_githook.py`가 등록한다.
- **git 훅은 clone으로 전파되지 않는다** → SessionStart 훅이 kit 레포에서 commit-msg 훅이 없으면 설치한다. 기존 훅이나 `core.hooksPath`(husky 등)가 있으면 건드리지 않는다.
- **harness 스킬**: AWS Deep Insight 역할 구조를 옮긴 작업 절차 (T0~T2 등급, 작업 지시, 워커 보고, 독립 검증). Orca가 있으면 워커 실행·메시지·대기·정리는 Orca orchestration 안내서(`orca skills get orchestration`)에 맡기고 kit 규칙과 겹치게 쓰지 않는다 (작업 지시 = Orca Task spec 5항목, 보고 = `worker_done`, T2 승인 = `gate-create`). 배치는 작업 하나 = worktree 하나 = 보드 카드 하나, 역할은 그 안의 탭(`worker-start`), 동시에 파일을 고칠 때만 하위 worktree. 카드 상태는 지휘 세션이 단계마다 갱신한다 (tech-tree-canvas에서 작업 여러 개가 카드 하나에 섞여서, 2026-10-29. 남은 워커 탭 14개는 `user_takeover`로 사용자 소유가 되어 release가 닫지 않은 것이었다). 없으면 서브에이전트, 그것도 아니면 단일 세션 + /kit:check. 프로필의 "작업 등급" 줄이 이 스킬로 안내하므로 모델 호출을 막지 않는다. 배경은 블로그 시리즈 "AI 에이전트에게 팀을 만들어 주기"(2026-10-28).
- **design 스킬**: AI·템플릿 기본값 체크리스트로 진단하고 방향을 골라 다시 디자인한다. Claude가 UI를 만들 때 스스로 불러야 하므로 모델 호출 허용. 캡처는 gstack browse 대신 `scripts/shot.py`(Chrome headless) → 이 Mac에서 browse 바이너리가 바로 종료됐고, 다른 컴퓨터에는 gstack이 없을 수 있어서. 시범은 tech-blog "종이 노트"(2026-10-28).
- **blog 그림**: 글마다 핵심 개념 도표 1개를 직접 쓴 인라인 SVG(블로그 CSS 클래스로 색 지정 → 다크 모드 자동)로 넣고 Codex가 캡처를 보고 검수한다. 검수는 `codex exec`(화면 없음) 대신 Orca 워커 탭(`worker-start --agent codex`)에서 돌리고 결과는 `.blog-review.md`로 받는다 → 사용자가 검수 과정을 보고 싶어 해서 (2026-10-29). GPT 이미지 생성은 이 환경(Bedrock, OpenAI 키 없음)에서 못 써서 기본 절차에서 뺐다. 시범은 tech-blog 글 7편(2026-10-29).
- **blog 흐름** (0.11.0): 글 하나 = tech-blog worktree(`post-<slug>`) 하나 = Orca 카드 하나. 출발 세션(어느 프로젝트든)이 브리프(`.blog-brief.md`, `info/exclude`로 커밋 없이 무시)를 써서 worktree와 에이전트를 띄우고 인계한다. 글 worktree가 쓰기·그림·필터링을 하고 사용자 승인 뒤에만 본체 main에 `--ff-only` 병합·push·정리한다. "블로그로 쓰자" 같은 말로도 시작해야 해서 `disable-model-invocation`을 뺐고, description은 한 줄로 유지했다 (2026-10-29 사용자 결정). Jekyll 빌드는 worktree에 vendor/bundle이 없어서 `PATH`에 Homebrew ruby 3.4 + `BUNDLE_PATH=<본체>/vendor/bundle`로 한다 (시스템 ruby 2.6은 실패).
- **스킬 토큰 비용**: SKILL.md의 `description`은 매 요청 컨텍스트에 들어가므로 짧게. 사용자가 직접 부르는 스킬(init, plan, release, weekly)은 `disable-model-invocation: true`.
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

1. `claude plugin validate .` — "CLAUDE.md at the plugin root is not loaded" 경고는 정상이다. 이 파일은 플러그인 사용자용이 아니라 이 레포를 개발하는 세션용이다.
2. 훅 스크립트는 JSON을 stdin으로 넣어 직접 실행:
   ```sh
   echo '{"cwd":"<kit 레포 경로>"}' | sh scripts/py.sh scripts/session_start.py
   python3 -c 'import json,sys;print(json.dumps({"tool_input":{"command":sys.argv[1]}}))' "git push" | python3 scripts/guard.py
   ```
   guard 규칙은 `sh scripts/test_guard.sh` (ask/통과 케이스 일괄).
3. 스킬은 비대화 모드로 실행해 확인 (질문 단계는 못 하므로 프롬프트에 "추천값으로 진행, 커밋/push 하지 마" 등을 덧붙인다):
   ```sh
   cd ~/Documents/dev/kit_test && claude -p --plugin-dir ~/Documents/dev/37writes-claude-kit \
     --allowedTools "Bash(git:*)" "Read" "Write" -- "/kit:plan ..."
   ```
4. 패널(mod)을 바꿨으면: `claude plugin test .` (단위 + 터미널/데스크톱 마운트), 타입 검사는 `npx -p typescript tsc -p <tsconfig>` (tsconfig는 engine 타입 파일 헤더 참고, 레포 밖에 둔다). `claude -p --plugin-dir . "/kit"`로 명령 동작 확인 (패널 대신 텍스트 출력). 이 레포를 --plugin-dir로 띄운 대화형 세션에서는 저장하면 핫 리로드된다. 테스트의 `$`에는 `$.state`가 없으므로 파싱은 순수 함수로 빼서 테스트한다.
5. 스크립트를 크게 바꿨으면 `/kit:check scripts`로 점검한다 (실제 버그를 잡은 적 있음).
6. 등록부·HOME을 건드리는 테스트는 `HOME=<임시폴더>`로 격리한다.

## 개선 요청 처리

다른 프로젝트에서 /kit:feedback 으로 남긴 아이디어는 이 레포의 GitHub 이슈(`feedback` 라벨)에 쌓인다. 이 레포에서 세션을 시작하면 SessionStart 훅이 열린 이슈 목록을 알려준다.
처리 커밋 본문에 `Closes #번호`를 적으면 push 때 이슈가 닫힌다.

## 버전과 배포

- 기능 추가는 minor(0.x.0), 수정은 patch. `plugin.json`과 `marketplace.json`의 version을 **함께** 올린다.
- README의 스킬 표와 로드맵을 갱신한다.
- push 후 다른 컴퓨터: `/plugin marketplace update 37writes` → `/plugin update kit@37writes`
- push 후 이 Mac: Orca worktree에서 push했으면 본체 `~/Documents/dev/37writes-claude-kit`에서 `git pull --ff-only` (alias가 본체를 로드하므로 안 하면 이전 버전이 뜬다)

## 남은 일

- `/kit:docs`: 회사·대학원 문서 양식(pptx/docx/md/html)을 받으면 제작
- 애드센스: 개인 도메인 구매(Cloudflare Registrar 추천) 후 블로그에 연결
- `/kit:release`: 첫 실제 배포(Amplify, exe, 앱) 때 절차 확정
- 윈도우 실기 테스트: 훅(py.sh, 인코딩), commit-msg 훅, Git Bash 경로

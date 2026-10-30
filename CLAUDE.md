# 37writes-claude-kit 개발 안내

1인 개발자 37writes의 Claude Code 플러그인. 이 레포 자체를 고치는 세션에서 읽는 문서다.
(플러그인 사용법은 README.md)

<!-- 37writes-kit:profile:start -->
## Project Profile (37writes-kit)

- **구분**: 개인
- **설명**: Claude Code 플러그인 (스킬 + 훅). 맥/윈도우/리눅스 공통
- **스택**: Markdown(SKILL.md), Python 3 (훅 스크립트, 표준 라이브러리만), POSIX sh
- **빌드**: `claude plugin validate .`
- **테스트**: `sh scripts/test_guard.sh`, `sh scripts/test_deploy_gate.sh`, `sh scripts/test_plans.sh`, `claude plugin test .` (스킬은 아래 "검증 방법")
- **실행**: 이 Mac은 `~/.zshrc`의 alias `claude='claude --plugin-dir ~/Documents/dev/37writes-claude-kit'`로 항상 로드. 수정 후 Claude Code 재시작하면 반영
- **배포**: GitHub `main` push (공개 레포). 다른 컴퓨터는 `/plugin update kit@37writes`
- **push**: 배포 아님 (공개 레포지만 자동 배포가 없다. 다른 컴퓨터는 직접 `/plugin update`)
- **원격**: GitHub `37writes/37writes-claude-kit`
- **절차**: 커밋 형식 `type(scope): 한국어 요약`(commit-msg 훅). 작업 절차·승인·검증·기록은 /kit:harness
<!-- 37writes-kit:profile:end -->

## 구조

```
.claude-plugin/plugin.json       플러그인 이름 "kit" (명령이 /kit:xxx), 버전
.claude-plugin/marketplace.json  마켓플레이스 이름 "37writes" (설치: kit@37writes), 버전 동기화
skills/<이름>/SKILL.md           스킬 9개: harness plan init commit check design release blog feedback
hooks/hooks.json                 SessionStart(이어하기·훅 설치, Orca 작업 절차 안내) / PreToolUse Bash(위험 명령 확인). Stop 훅 없음
scripts/py.sh                    python3 → python → py 순으로 실제 동작하는 Python 실행 (윈도우 스토어 스텁 회피)
scripts/kitlib.py                공통: git 호출(utf-8), kit 레포 판정, 재개 목록 계산, JSON 출력
scripts/plans.py                 재개 목록 CLI: 모든 worktree의 진행 중 기획서 (`[--cwd DIR] [--json] [--all]`). SessionStart·패널·harness "이어서"가 쓴다
scripts/deploy_gate.py           자동 배포: `verify`(그 SHA의 임시 checkout에서 정책의 검증 명령 실행·기록) / `confirm`(같은 방식으로 정책의 확인 명령) / guard가 부르는 `push_allowed`
scripts/test_*.sh                guard·deploy_gate·plans 테스트 (로컬 fixture, HOME 격리)
scripts/*.py                     훅과 스킬이 부르는 스크립트 (session_text.py: 대화 기록 → 텍스트, blog_coordinator.py: 블로그 코디네이터 탭 찾기, /kit:blog용 / shot.py·contrast.py: 캡처·대비, /kit:design용)
githooks/commit-msg              커밋 형식 검사 git 훅 (sh, Python 불필요)
hooks/panel.tsx                  mod(함수 훅 모듈): /kit 명령과 kit 패널. hooks.json의 "modules"에 등록
hooks/panel.test.tsx             패널 테스트 (claude plugin test .)
types/index.d.ts                 패널의 $.state 계약 (plugin.json "types")
```

## 핵심 개념과 결정

- **kit 프로젝트 판정** (0.15.0): git 루트의 CLAUDE.md에 프로필 표시(`<!-- 37writes-kit:profile:start -->`)가 있는 레포. 호환으로 `docs/devlog/`만 있는 예전 레포도 kit로 본다 (이미 init한 레포의 commit-msg 훅 설치가 꺼지지 않게). `docs/plans/`만 있는 레포는 kit가 아니다 (무관한 레포에 kit를 적용하지 않게, 사용자 지시). 예전 기준이 `docs/devlog/`라 devlog를 없애면 훅이 조용히 꺼질 뻔해서 판정을 먼저 바꿨다. SessionStart 안내·훅 설치는 kit 프로젝트에서만, 위험 명령 확인과 Orca 안내는 모든 레포, harness의 "이어서"는 판정과 상관없이 동작한다.
- **Orca 안내** (`scripts/orca_context.py`): Orca IDE 터미널(`TERM_PROGRAM=Orca` 또는 `ORCA_WORKTREE_ID`)에서 시작한 세션이면 어느 레포든 harness 절차 요약을 SessionStart 컨텍스트로 넣는다. 지휘 세션과 워커를 가르는 환경 변수가 없어서 워커는 "지금 작업에 Task·Dispatch ID가 있는 Orca 작업 지시가 걸려 있음"으로 구분한다 (첫 지시로 판정하면 나중에 dispatch되거나 완료 뒤 직접 지시를 받은 세션을 잘못 분류한다). Orca 워커는 사용자 확인 없이 띄운다 (사용자 결정, 2026-10-29). 지휘 세션은 첫 요청 전에 (질문이라도) Skill 도구로 harness를 불러 읽는다 → "질문이 아닌 작업 요청이면"이라고만 했더니 첫 질문을 T0로 보고 스킬을 읽지 않았고, 이어진 "gpt·agy 의견 물어봐"도 `codex exec`·`agy -p`(화면 없음)로 처리했다 (motion 프로젝트, 2026-10-29). 그래서 다른 모델 의견·검토는 등급과 상관없이 Orca 워커 탭으로 띄운다고 안내문과 harness 1단계에 적었다. 예전에는 kit 프로필이 없는 레포에 /kit:init 제안 줄을 붙였는데 0.15.0에서 뺐고, 규칙 문장(T1 기획서, 배치 기준)도 빼서 역할 판정·harness 먼저 읽기·다른 모델 의견은 Orca 탭만 남겼다 (규칙은 harness 한 곳). 중요한 건 탭(차례로 일하는 역할)과 worktree(새 작업, 동시에 고치는 워커) 판단이다. guard의 "ask"는 Orca의 `--dangerously-skip-permissions`에서도 확인 창이 뜬다.
- **등록부** `~/.config/37writes-kit/repos.txt`: macOS 개인정보 보호(TCC) 때문에 터미널이 `~/Documents`, `~/Desktop` 폴더 목록을 읽지 못해서 /kit:weekly가 폴더 탐색 대신 쓰던 목록이다. 0.15.0에서 weekly를 없애며 쓰기(SessionStart·`install_githook.py`의 등록)를 멈췄다. 읽는 곳이 없어졌기 때문이다. 파일도 2026-10-30 사용자 결정으로 삭제했다.
- **git 훅은 clone으로 전파되지 않는다** → SessionStart 훅이 kit 레포에서 commit-msg 훅이 없으면 설치한다. 기존 훅이나 `core.hooksPath`(husky 등)가 있으면 건드리지 않는다.
- **harness 스킬**: AWS Deep Insight 역할 구조를 옮긴 작업 절차 (T0~T2 등급, 작업 지시, 워커 보고, 독립 검증). Orca가 있으면 워커 실행·메시지·대기·정리는 Orca orchestration 안내서(`orca skills get orchestration`)에 맡기고 kit 규칙과 겹치게 쓰지 않는다 (작업 지시 = Orca Task spec 5항목, 보고 = `worker_done`, T2 승인 = `gate-create`). 배치는 작업 하나 = worktree 하나 = 보드 카드 하나, 역할은 그 안의 탭(`worker-start`), 동시에 파일을 고칠 때만 하위 worktree. 카드 상태는 지휘 세션이 단계마다 갱신한다 (tech-tree-canvas에서 작업 여러 개가 카드 하나에 섞여서, 2026-10-29. 남은 워커 탭 14개는 `user_takeover`로 사용자 소유가 되어 release가 닫지 않은 것이었다). 없으면 서브에이전트, 그것도 아니면 단일 세션 + /kit:check. 프로필의 "절차" 줄(예전 프로필은 "작업 등급" 줄)이 이 스킬로 안내하므로 모델 호출을 막지 않는다. 0.14.0에서 규칙을 harness 한곳에 모으고 plan·check·init·design은 참조만 한다 (문서끼리 어긋나지 않게): 배치는 줄 수가 아니라 불확실성·분리 가능성으로 정하고(1단계 표), 불확실하거나 영향이 큰 기획은 작성자와 다른 실제 모델이 구현 전에 반박한다 (같은 모델 서브에이전트는 반박이 아님, 못 쓰면 멈추고 예외를 묻는다). 실행 모델은 `worker-show`의 `projection.provider.model`로 확인한다 (이번 Run의 Codex 워커 두 번 모두 `launch.effective.model`이 null이었고, Claude 워커는 그 값도 null이라 워커가 자기 모델을 보고, 2026-10-30). 승인은 계획 승인(무엇을 어디까지)과 미리보기(실제 변경이 승인 범위와 같은지)를 구분하고, 구현까지 맡겼으면 다시 묻지 않으며 범위 안 결함 수정은 재승인 없이 한다. 검증자는 재실행 외에 스스로 고른 실패 시나리오 1~3개를 확인한다 → 기획을 작성자 혼자 점검했고, 줄 수로 배치를 정했고, 승인을 두 번 묻거나(plan "바로 구현할까요?") push 등급 표현이 문서마다 달랐다 (사용자 요청, 2026-10-30). 반박은 조건부다 (모든 T1에 붙이면 작은 작업이 느려진다). guard 동작은 그대로. 배경은 블로그 시리즈 "AI 에이전트에게 팀을 만들어 주기"(2026-10-28).
- **harness 중심 흐름** (0.15.0, 2026-10-30): 사용자는 명령을 외우지 않고 말로 요청하고, harness 맨 앞의 의도 표가 흐름과 읽을 파일을 고른다. 규칙(등급·배치·반박·승인·push·자동 배포·검증·완료 판정·기록)은 harness "공통 규칙" 한 곳, 절차는 각 스킬 → 하나로 합치면 첫 요청마다 무겁고 design·blog처럼 스스로 불리는 입구가 사라진다 (교차 검토). plan·init·release는 `disable-model-invocation`이라 Skill 목록에 없어서 harness가 경로로 Read하고, 읽은 SKILL.md 폴더를 base directory로, harness가 파악한 요청을 인자로 본다. harness는 170줄 이하. 프로필의 예전 "작업 규칙" 문장보다 harness가 우선하고 사실 줄은 프로필을 따른다 (이미 init한 다른 프로젝트에 예전 문장이 남아 있어서). 프로필은 사실만 담고 init은 빠진 줄만 보완한다 (기존 내용을 덮지 않음, AGENTS.md만 있으면 `@AGENTS.md` + 프로필 블록). 검토: 반박은 Codex(`docs/plans/2026-10-30-harness-flow.md`의 기획 반박, 이 기획서가 지워진 뒤에는 git 기록에서).
- **기록 = 기획서 + 커밋** (0.15.0): devlog·til·weekly 스킬과 Stop 알림을 없앴다 → 결정·결과는 이미 기획서에 있고 커밋은 `Refs`로 찾으므로 같은 내용을 따로 적을 이유가 없었고, devlog 대체 섹션도 만들지 않고 기획서에 `## 남은 일` 하나만 더했다. 끝난 기획서(`done`·`abandoned`)는 보고서 폴더와 함께 `git rm`한다 (사용자 결정, 2026-10-30: "작업이 완료된 plan md 파일은 자동으로 삭제하게 하자. 나중에 보면 헷갈린다"). 처음에는 마지막 작업 커밋 하나에서 갱신과 삭제를 같이 하게 했는데, 삭제 커밋의 tree에는 파일이 없어 `git show <삭제 커밋>^:`이 미완료 상태(approved·빈 체크박스)를 보였다 (S2 검증 F3, 2026-10-30). 그래서 단계마다 그 커밋에 체크박스·결과를 넣고, 마지막 작업 커밋에 `done`·`## 남은 일`을 넣은 뒤 삭제 커밋을 따로 하나 하며, Refs는 기획 커밋부터 모든 커밋에 필수다 (순서 본문은 harness). 내용은 `git log --all -- docs/plans/<파일>` → `git show <삭제 커밋>^:<경로>`로 읽는다. `docs/plans/project.md`(프로젝트 설계)는 지우지 않고 끝난 항목을 `완료 <커밋>`으로. 과거 `docs/devlog/`, `.git/37writes-kit-reminded`는 그대로 둔다.
- **재개** (0.15.0): `plans.py`가 `git worktree list`의 모든 worktree에서 `docs/plans/*.md`(project.md 제외)를 모아 같은 경로의 복사본을 먼저 비교한다. 어느 복사본이든 `done`·`abandoned`이거나 기본 브랜치에서 지워졌으면 끝난 작업(목록에서 뺌), 활성 복사본끼리 상태·체크박스가 다르면 충돌(자동 재개 안 함) → 오래된 worktree 복사본이 끝난 작업을 다시 재개시키는 반례(Codex 반박). 예전 이어하기는 현재 레포의 마지막 devlog "다음 할 일"만 읽어서 다른 worktree의 진행 중 기획서를 못 봤다.
- **자동 배포** (0.15.0): 프로필 `- **자동 배포**: 허용 · 대상 · 검증 · (제외) · 확인 {sha}` 줄로 정책 안의 배포를 사람 확인 없이 끝까지 진행하는 좁은 경로를 만들었다 (승인 조건·순서의 규칙 본문은 harness "push와 배포", 명령은 release). guard는 전체 SHA refspec 하나(`git push <원격> <SHA>:refs/heads/<브랜치>`), push URL = fetch URL, `ls-remote` base에서 fast-forward, base와 SHA의 정책이 같음, `deploy_gate.py verify` 기록(tree·정책·명령, exit 0), `제외`·시크릿 패턴을 대조하고 하나라도 어긋나면 ask → 움직이는 브랜치 이름이나 push URL 분리로 검증 안 된 커밋이 나갈 수 있다는 반례(Codex 반박). 완료를 `confirm`(그 SHA의 배포 실행 + 핵심 기능)으로 묶은 것은 HTTP 200·최근 실행 성공이 다른 SHA의 결과일 수 있어서다. verify·confirm은 그 SHA의 임시 detached worktree에서 실행하고 검증 명령이 추적 파일을 바꾸면 실패한다 (S2 검증 F1·F2, 2026-10-30: 검증 명령이 파일을 고쳐도 원래 SHA로 성공 기록됐고, 확인 명령은 작업 폴더의 커밋 안 된 스크립트를 읽었다). IAM·시크릿·인프라·마이그레이션·데이터 삭제는 guard가 증명 못 하는 의미 분류라 harness가 판단한다. guard는 best-effort라 기록 보호를 권한 경계처럼 쓰지 않는다. 블로그는 이 정책을 쓰지 않는다.
- **design 스킬**: AI·템플릿 기본값 체크리스트로 진단하고 방향을 골라 다시 디자인한다. Claude가 UI를 만들 때 스스로 불러야 하므로 모델 호출 허용. 캡처는 gstack browse 대신 `scripts/shot.py`(Chrome headless) → 이 Mac에서 browse 바이너리가 바로 종료됐고, 다른 컴퓨터에는 gstack이 없을 수 있어서. 시범은 tech-blog "종이 노트"(2026-10-28).
- **blog 그림**: 글마다 핵심 개념 도표 1개를 직접 쓴 인라인 SVG(블로그 CSS 클래스로 색 지정 → 다크 모드 자동)로 넣고 Codex가 캡처를 보고 검수한다. 검수는 `codex exec`(화면 없음) 대신 Orca 워커 탭(`worker-start --agent codex`, 0.12부터 코디네이터가 띄움)에서 돌리고 결과는 `.blog-review.md`로 받는다 → 사용자가 검수 과정을 보고 싶어 해서 (2026-10-29). GPT 이미지 생성은 이 환경(Bedrock, OpenAI 키 없음)에서 못 써서 기본 절차에서 뺐다. 시범은 tech-blog 글 7편(2026-10-29).
- **blog 흐름** (0.12.0): 역할 셋. 출발 세션(어느 프로젝트든)은 브리프(`~/.config/37writes-kit/blog/<slug>/brief.md`)만 쓰고, tech-blog 본체의 탭 `블로그 코디네이터`(`scripts/blog_coordinator.py`로 찾음, 없으면 `agent launch`로 띄움)에 `terminal send`로 경로를 보낸 뒤 끝난다. 터미널 행의 `title`은 에이전트가 붙이는 자동 제목이라 사용자가 정한 탭 이름과 달라서 `--include-visual-layouts`의 탭 title로 찾는다 (실측, 2026-10-29). 코디네이터는 본체 main에 머물며 한 Run에서 글마다 `worker-start --worktree new-top-level`로 글 worktree(`post-<slug>`) + 글 워커를 띄우고, `question`에 답하고(필요하면 사용자에게), `worker_done` 뒤 직접 검수(범위·빌드·필터 grep·브리프 대조) + Codex 검수 워커를 돌린다. 수정은 직접 하지 않고 retain한 글 워커 탭에 다시 dispatch한다. 사용자 승인 뒤 코디네이터가 `--ff-only` 병합·push·배포 확인·worktree와 브랜치 정리를 한다 → 예전(0.11)엔 글 worktree 에이전트가 쓰기부터 병합·자기 worktree 삭제까지 혼자 해서 지휘·검수하는 쪽이 없었다 (사용자 결정, 2026-10-29). 워커 보고서(`.blog-report.md`, `.blog-review.md`)는 `info/exclude`로 커밋 없이 무시. 발행 승인은 harness의 `gate-create`가 아니라 코디네이터 탭의 대화(AskUserQuestion)로 받는다 (사용자가 그 탭에서 직접 답하고, 승인 범위에 정리까지 넣는다). 코디네이터는 탭 이름으로 찾으므로 `agent launch --surface terminal`로 띄운다 (chat이면 handle이 없어 못 찾는다). `check --wait`는 240초로 짧게 둔다: 대기 중에는 `terminal send`로 온 새 요청과 사용자 입력이 보이지 않고, Bash 도구 한 명령은 최대 10분이다. 독립 검토(2026-10-29)에서 나온 것: 본체 세션이 코디네이터를 둘 만들 수 있음, batch 전체를 ack 전에 처리, Dispatch 종류(글·수정·검수) 기록, 정리 전 `status --porcelain`·`merge-base --is-ancestor` 확인, `rm -r`은 `${SLUG:?}`로. "블로그로 쓰자" 같은 말로도 시작해야 해서 `disable-model-invocation`을 뺐고, description은 한 줄로 유지했다. Jekyll 빌드는 worktree에 vendor/bundle이 없어서 `PATH`에 Homebrew ruby 3.4 + `BUNDLE_PATH=<본체>/vendor/bundle`로 한다 (시스템 ruby 2.6은 실패). 0.15.0: 원료는 현재 대화 → 기획서(지워졌으면 git 기록) → 커밋·diff → 검증 보고서 → 지난 대화이고 TIL은 사용자가 지정할 때만 읽는다. 브리프에 주장별 근거 표를 두고 근거 없는 주장은 `근거 부족`으로 표시해 글 워커가 사실로 쓰지 않는다. 발행 뒤 TIL 메모 발행 표시 커밋·/kit:til 제안 단계는 없앴다. "글 써줘"는 작성·검수까지이고 발행은 글마다 승인.
- **push 확인** (0.13.0): 프로필의 `- **push**: 배포 아님` 줄이 있는 레포에서는 guard가 일반 `git push`를 묻지 않는다 (승인 규칙 본문은 harness "push와 배포"). guard는 강제·삭제 push(`-f`, `--force*`, `--delete`, `+ref`, `:ref`, `--mirror`, `--prune`), 그 줄이 없는 레포(배포가 되는 레포, tech-blog처럼 프로필이 없는 레포), 해석 못 한 명령(`sh -c` 안 등)은 계속 묻는다. 대상 레포는 `cd`·`git -C`를 따라가고 없으면 훅 입력의 `cwd` → 사용자가 커밋을 승인했는데 push에서 한 번 더 확인 창이 떠서 바꿨다 (사용자 결정, 2026-10-29). 키워드로 배포 여부를 추측하지 않고 프로필에 명시한 줄만 믿는다 (없으면 묻는 쪽이 안전). 0.15.0의 자동 배포는 이 위에 더한 좁은 통과 경로다 (아래 "자동 배포").
- **스킬 토큰 비용**: SKILL.md의 `description`은 매 요청 컨텍스트에 들어가므로 짧게. 사용자가 직접 부르는 스킬(init, plan, release)은 `disable-model-invocation: true` (harness가 경로로 Read해서 쓴다).
- **스킬에서 스크립트 경로**: 스킬 로드 시 "Base directory for this skill"이 주어지므로 `<base directory>/../../scripts/xxx.py`로 참조한다.
- **사용자 보고 언어**: 한국어. 비대화(`claude -p`) 실행에서 영어로 보고한 적이 있어 일부 스킬에 명시했다.
- **커밋 형식**: type은 영어(feat fix docs style refactor perf test build ci chore revert), 요약은 한국어.

## 관련 저장소 (모두 ~/Documents/dev/)

| 폴더 | GitHub | 공개 | 용도 |
|---|---|---|---|
| `37writes-claude-kit` | 37writes/37writes-claude-kit | 공개 | 이 플러그인 |
| `my-notes` | 37writes/my-notes | - | 삭제됨 (2026-10-30, 사용자 결정). 예전 TIL·주간 정리 저장소 |
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
   guard 규칙은 `sh scripts/test_guard.sh` (ask/통과 케이스 일괄), 자동 배포는 `sh scripts/test_deploy_gate.sh` (로컬 bare 원격 fixture: 허용, 정책 없음, 범위 밖, 검증 실패, 잘못된 SHA, 움직이는 브랜치 이름, push URL 다름, 병합 후 새 SHA, 배포 실패, 정책 변경, 기록 위조), 재개 목록은 `sh scripts/test_plans.sh` (다른 worktree, done·abandoned·기본 브랜치에서 지워짐 제외, 오래된 복사본, 충돌, 프로필 없는 레포).
3. 스킬은 비대화 모드로 실행해 확인 (질문 단계는 못 하므로 프롬프트에 "추천값으로 진행, 커밋/push 하지 마" 등을 덧붙인다):
   ```sh
   cd ~/Documents/dev/kit_test && claude -p --plugin-dir ~/Documents/dev/37writes-claude-kit \
     --allowedTools "Bash(git:*)" "Read" "Write" -- "/kit:plan ..."
   ```
4. 패널(mod)을 바꿨으면: `claude plugin test .` (단위 + 터미널/데스크톱 마운트), 타입 검사는 `npx -p typescript tsc -p <tsconfig>` (tsconfig는 engine 타입 파일 헤더 참고, 레포 밖에 둔다). `claude -p --plugin-dir . "/kit"`로 명령 동작 확인 (패널 대신 텍스트 출력). 이 레포를 --plugin-dir로 띄운 대화형 세션에서는 저장하면 핫 리로드된다. 테스트의 `$`에는 `$.state`가 없으므로 파싱은 순수 함수로 빼서 테스트한다.
5. 스크립트를 크게 바꿨으면 `/kit:check scripts`로 점검한다 (실제 버그를 잡은 적 있음).
6. HOME을 건드리는 테스트는 `HOME=<임시폴더>`로 격리한다.

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

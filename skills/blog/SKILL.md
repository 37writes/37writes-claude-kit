---
name: blog
description: 대화·기획서·커밋을 기술 블로그 글로 쓴다. "블로그로 쓰자" 같은 요청에 쓴다. 코디네이터가 글마다 worktree 워커를 지휘하고 발행은 harness 승인 규칙대로.
---

# blog: 대화·기획서·커밋 → 블로그 글 (코디네이터가 지휘, 글마다 worktree)

| 저장소 | 경로 | 공개 |
|---|---|---|
| 메모 (사용자가 지정할 때만 원료) | 사용자가 지정한 메모 파일만 읽는다 | 비공개로 다룬다 |
| 블로그 본체 | `~/Documents/dev/tech-blog` (GitHub `37writes/37writes.github.io`, Jekyll + Chirpy) | 공개 |

사용자에게 하는 질문과 보고는 모두 **한국어**로 한다.

블로그는 공개되고 애드센스 수익을 목표로 한다. **회사 정보 유출 방지**와 **독자에게 가치 있는 글**이 최우선이다.
"글 써줘"의 범위와 발행(본체 main 병합·push) 승인 조건은 harness 공통 규칙 "push와 배포"를 따른다. 승인은 K6에서 받는다.

## 역할과 흐름

글 하나 = tech-blog worktree 하나(브랜치 `<branch>`: 보통 `post-<slug>`, Orca 설정에 따라 `<접두사>/post-<slug>`) = Orca 보드 카드 하나 = 코디네이터 Run의 Task 하나. 본체 main은 **코디네이터만** 건드리고, 사용자가 승인한 글만 받는다.

| 역할 | 어디서 | 하는 일 | 절차 |
|---|---|---|---|
| 출발 세션 | 어느 프로젝트든 | 재료를 모아 브리프를 쓰고 코디네이터에게 넘긴 뒤 **끝** | A, B |
| 코디네이터 | 블로그 본체(main), Orca 탭 이름 `블로그 코디네이터` | 글마다 worktree와 글 워커를 띄우고 질문에 답한다. 직접 검수 → 사용자 승인 → 병합·push·배포 확인·정리 | K |
| 글 워커 | 글 worktree | 쓰기·그림·필터링(2~4단계), 브랜치에 커밋, `worker_done`으로 보고 | C |

내 역할 판단:
- 프롬프트에 Task·Dispatch ID가 있는 Orca 작업 지시가 있고 "블로그 글 워커"라고 적혀 있다 → **글 워커** (C)
- "블로그 코디네이터"로 일하라는 지시를 받았거나 "블로그 요청: <경로>"를 받았다 → **코디네이터** (K)
- 그 밖 (어느 프로젝트에서든 "블로그로 쓰자", /kit:blog) → **출발 세션** (A, B). 블로그 본체 세션이라도 B에서 코디네이터가 이미 있으면 그쪽에 넘기고, 없을 때만 그 세션이 K1부터 코디네이터가 된다 (본체에 코디네이터가 둘이면 둘 다 병합·push를 할 수 있다).

`<main>` = 블로그 본체 `~/Documents/dev/tech-blog`(명령에는 절대 경로로 풀어 쓴다), `<slug>` = 글의 영어 slug, `<inbox>` = `$HOME/.config/37writes-kit/blog` (브리프 보관함, 어느 레포에도 커밋되지 않는다. 따옴표 안에서는 `~`가 펼쳐지지 않으므로 `$HOME`으로 쓴다).

## A. 출발 세션: 재료 모으기

원료는 이 순서로 찾는다: 현재 대화 → 관련 기획서 → 커밋과 diff → 검증 보고서 → 지난 대화. 메모는 사용자가 지정한 파일만 읽는다 (메모가 없다고 막지 않는다).

- **현재 대화**: 최종 결정과 실제로 만든 파일을 기준으로 정리한다. 대화는 결론이 여러 번 바뀐다. 중간에 버린 안은 "처음엔 이렇게 했다가 바꿨다"처럼 이유가 있을 때만 쓴다.
- **기획서**: 그 프로젝트의 `docs/plans/`(목표, 결정 & 이유, 기획 반박, 단계 결과). 끝난 작업은 기획서가 지워졌으므로 git 기록에서 찾는다: `git log --all --format='%h %s' -- docs/plans/` → `git show <삭제 커밋>^:docs/plans/<파일>` (보고서 폴더도 같은 방법).
- **커밋과 diff**: `git log --grep "Refs: docs/plans/<파일>"`로 그 작업의 커밋을 찾고, 필요한 부분은 `git show <커밋>`으로 실제 변경을 본다.
- **검증 보고서**: 기획서 옆 보고서 폴더(`docs/plans/<이름>/`의 validation 등). 무엇을 확인했고 무엇이 틀렸었는지가 글의 재료다.
- **지난 대화** ("그 세션에서 한 작업을 글로"): 스크립트는 이 스킬의 base directory 기준 `../../scripts/session_text.py`.
  `python3 "<base directory>/../../scripts/session_text.py" <그 대화를 연 폴더> --list` → 대화 고르기
  `python3 "<base directory>/../../scripts/session_text.py" <폴더> --session <ID> > /tmp/session.txt` → 전체 텍스트 (길면 `--grep 키워드`)
  Orca worktree처럼 폴더 이름을 모르면 `ls ~/.claude/projects/ | grep <이름 일부>`로 찾는다.
- **메모** (사용자가 메모 파일을 지정할 때만): 그 파일만 읽는다. 읽기만 하고 고치거나 커밋하지 않는다.
- 대화에서 인용한 외부 글(공식 문서, 블로그)은 원문을 다시 열어 제목·날짜·수치를 확인한다.
- 내용이 많으면 **시리즈**로 나눈다 (2단계 "시리즈"). 편 구성(편별 제목과 다룰 내용)을 보여주고 AskUserQuestion으로 확인받는다. 브리프는 편마다 따로 쓴다 (코디네이터가 편마다 worktree를 만든다).

**브리프** `<inbox>/<slug>/brief.md` (코디네이터와 글 워커는 이 대화를 볼 수 없으므로 이것만으로 쓸 수 있어야 한다. 글 하나당 하나. 폴더가 이미 있으면 이어 쓰는 글일 수 있으니 사용자에게 묻는다):
- 주제와 독자, 제안 제목(시리즈면 시리즈 이름과 이 편의 번호·제목·다룰 내용·전체 편 목록)
- 핵심 사실과 **최종 결정**, 버린 안과 그 이유
- 읽을 원료 파일의 **절대 경로**, 대화 폴더·세션 ID (`session_text.py` 인자), 사용자가 지정한 메모 경로(있으면)
- 그 프로젝트 CLAUDE.md 프로필의 **구분**(회사/개인/대학원)과 **걸러야 할 회사 관련 항목**(회사·서비스·고객사·레포 이름, 도메인, 계정 ID 등 알고 있는 것을 구체적으로)
- 확인된 사용자 요구(어조, 넣을 것, 뺄 것)
- **주장별 근거 표**: 글에 들어갈 핵심 주장마다 근거(파일 경로·줄, 커밋 해시, 대화 세션 ID와 줄·키워드). 근거를 찾지 못한 주장은 근거 칸에 `근거 부족`이라고 쓴다 (글 워커는 사실로 쓰지 않는다).
  ```markdown
  | 주장 | 근거 |
  |---|---|
  | guard는 전체 SHA push만 자동 허용한다 | `scripts/guard.py` push 판정, 커밋 a1b2c3d |
  | 이 방식으로 배포 시간이 절반으로 줄었다 | 근거 부족 |
  ```

## B. 출발 세션: 코디네이터에게 넘기기

출발 세션은 글 worktree를 만들지 않는다. 코디네이터 탭을 찾아 브리프 경로를 보낸다.

```sh
sh <base directory>/../../scripts/py.sh <base directory>/../../scripts/blog_coordinator.py <main>
# → {"mainWorktreeId": "<main id>", "coordinator": "<handle 또는 null>", "candidates": [...]}
```
본체 worktree에서 탭 이름이 정확히 `블로그 코디네이터`인 Claude 터미널을 찾는다. `terminal list`의 터미널 `title`은 에이전트가 대화 내용으로 붙이는 자동 제목이라 직접 비교하지 않는다 (사용자가 정한 탭 이름은 `--include-visual-layouts`의 탭에만 있다). `candidates`가 둘 이상이면 사용자에게 어느 탭인지 묻는다. `error`면 그 내용을 보고하고 멈춘다.
- `coordinator`가 있으면 그 handle로 보낸다:
  ```sh
  orca terminal send --terminal <handle> --text "블로그 요청: <inbox>/<slug>/brief.md" --enter --wait-submit 10 --json
  ```
  시리즈면 경로를 편 순서대로 공백으로 이어 한 번에 보낸다 (`블로그 요청: <1편 경로> <2편 경로> ...`). `accepted: true`면 전달된 것이다. `turn_started`가 없어도 다시 보내지 않는다 (코디네이터가 기다리는 중이면 대기가 끝난 뒤 받는다). `agent_prompt_blocked`면 코디네이터 탭에 권한 창이나 질문이 떠 있는 것이니 사용자에게 그 탭을 봐 달라고 한다.
- 없으면 코디네이터를 띄운다. 탭 이름으로 찾는 구조라 chat이 아닌 터미널로 띄운다:
  ```sh
  orca agent launch --agent claude --surface terminal --worktree id:<main id> --prompt "너는 블로그 코디네이터다. blog 스킬 K절차로 시작하고 첫 요청을 처리해. 블로그 요청: <inbox>/<slug>/brief.md" --json
  ```
  지금 세션이 블로그 본체 세션이면 띄우지 않고 이 세션이 K1부터 한다.
- 사용자에게 브리프 경로와 "블로그 코디네이터 탭에 넘겼다, 질문·검수·발행 승인은 그 탭에서 한다"를 알린다. 출발 세션은 여기서 끝이다. 지켜보거나 대신 쓰지 않는다.
- **Orca가 없으면**: 사용자에게 "`~/Documents/dev/tech-blog`에서 claude를 열고 '블로그 코디네이터로 <브리프 경로> 처리'라고 하세요"라고 안내한다.

## K. 코디네이터: 지휘·검수·발행

코디네이터는 본체 `<main>`(main 브랜치)에 머문다. 글 파일은 직접 고치지 않고 글 워커에게 시킨다. 본체에서 하는 일은 병합·push와 확인용 명령뿐이다. Orca 명령의 세부(메시지 처리, ack, 복구)는 orchestration 안내서(`orca skills get orchestration`)를 먼저 읽고 따른다.

`<wt>` = 글 worktree 경로, `<wt id>` = 그 Orca worktree id. 기록 파일 (재시작 때 이것으로 이어간다):
- `<inbox>/coordinator.json`: Run id 하나 (`{"run": "<run_id>"}`)
- `<inbox>/<slug>/state.md`: worktree id·경로, 브랜치, Task, Dispatch 목록(종류 `글`·`수정`·`검수`와 상태), 지금 단계, 사용자 승인 여부
- `<inbox>/<slug>/spec.md`: K3에서 보낸 작업 지시 전문 (수정 지시와 새 워커에 다시 쓴다)

### K1. 시작 (세션마다 한 번)
1. **중복 확인 먼저**: `blog_coordinator.py <main>`을 돌려 이 탭이 아닌 후보(`candidates`)가 있으면 이름을 바꾸지 말고 멈춘 뒤, 그 탭에 넘기라고(B) 사용자에게 알린다.
2. 탭 이름을 고정한다 (출발 세션이 이 이름으로 찾는다): `orca terminal rename --terminal "$ORCA_TERMINAL_HANDLE" --title "블로그 코디네이터" --json`. `$ORCA_TERMINAL_HANDLE`이 없으면(chat 등) 사용자에게 알리고, 출발 세션이 찾지 못한다는 점을 말한다.
3. Run: `orca orchestration run-current --json` → 없으면 `<inbox>/coordinator.json`의 Run을 `run-use --id <run_id>`로 이어받고, 그것도 없으면 `orca orchestration run-create --objective "블로그 코디네이터" --json` 후 `coordinator.json`에 적는다. 글 하나가 이 Run의 Task 하나다.
4. 워커 보고서가 커밋되지 않게 한다 (`info/exclude`는 본체와 모든 worktree가 공유하지만 커밋되지 않는다. 블로그 `.gitignore`는 건드리지 않는다):
   ```sh
   EX="$(git -C <main> rev-parse --git-common-dir)/info/exclude"
   for f in .blog-report.md .blog-review.md; do grep -qx "$f" "$EX" || echo "$f" >> "$EX"; done
   ```
5. `git -C <main> status -sb`로 본체 상태를 본다. 더러우면 사용자에게 알린다 (글 쓰기는 진행해도 되고, 병합 직전 6단계 1번에서 다시 막는다).
6. 재시작이면 `<inbox>/*/state.md`로 진행 중인 글을 확인하고 `orca orchestration worker-list --run <run_id> --json`으로 워커 상태를 맞춘 뒤, ack하지 않은 Delivery부터 K4로 처리한다.

### K2. 요청 받기
"블로그 요청: <경로...>"를 받으면 브리프를 읽는다. 항목이 빠졌으면(특히 구분과 걸러야 할 회사 항목) 출발 세션은 이미 끝났으니 사용자에게 묻는다. 같은 이름의 worktree가 이미 있으면(`orca worktree list --repo path:<main>`) 사용자에게 묻는다.
- **그림만 넣기** (이미 발행한 글): 브리프에 대상 글 파일(`_posts/...`), 구분, 넣을 그림의 핵심 문장만 있으면 된다. 작업 지시의 변경을 "3단계(그림)와 그림 글자의 4단계 필터링"으로, 담당을 그 글 파일과 `_includes/figures/<slug>/`로 쓴다.
- **이전 방식 글 worktree** (`.blog-brief.md`가 있고 그 안의 에이전트가 직접 쓰던 것)는 사용자가 코디네이터 탭에서 "이 worktree 넘겨받아"라고 지정할 때만 넘겨받는다. 그 worktree의 기존 에이전트는 스스로 병합·push·삭제하는 옛 절차를 갖고 있으니, 먼저 사용자에게 그 탭을 멈추거나 닫아 달라고 하고 확인을 받는다. 그다음 `.blog-brief.md`를 `<inbox>/<slug>/brief.md`로 복사하고 `state.md`를 만든 뒤 K5부터 한다. 고칠 것이 있으면 그 worktree에 새 글 워커를 띄운다 (`--worktree id:<wt id> --agent claude`, spec은 K3 양식).

### K3. 글 워커 띄우기 (편마다)
```sh
orca orchestration worker-start --worktree new-top-level --repo path:<main> --name post-<slug> \
  --base-branch origin/main --setup skip --display-name "[블로그] <제목>" --comment "<주제>" \
  --agent claude --task-title "글: <slug>" --spec "<작업 지시>" --json
```
- receipt에서 worktree id·경로·**브랜치**(`refs/heads/` 뒤)·Task·Dispatch ID를 읽는다. 바로 안 보이면 `worker-list --run <run_id> --json`과 `orca worktree list --repo path:<main> --json`으로 확인한다. `state.md`(Dispatch 종류 `글`)와 `spec.md`에 적는다.
- `worker-start`가 실패(exit 1)하면 다시 띄우지 않는다. receipt의 `failedStage`·`residualResources`를 보고 안내서의 `references/recovery-and-cleanup.md`를 따른다.
- 카드: `orca worktree set --worktree id:<wt id> --workspace-status in-progress --json`
- 시리즈는 편마다 같은 명령으로 모두 띄운 뒤 기다린다. 같은 날 발행할 편들의 date(편 순서대로 5분 간격)는 코디네이터가 정해 작업 지시에 적는다. 편끼리 `post_url`은 걸지 않는다 (K7 "시리즈 발행 순서"에서 채운다).

**작업 지시** (`--spec`, harness 5항목. 글 워커는 이것과 브리프만 본다. 전문을 `spec.md`에 저장):
```text
너는 블로그 글 워커다. blog 스킬의 "C. 글 워커" 절차를 따른다.
대상: worktree <wt>, 브리프 <inbox>/<slug>/brief.md, 원료는 브리프에 적힌 경로
변경: 2~4단계(글 쓰기, 그림, 공개 전 필터링)를 하고 브랜치에 커밋, <wt>/.blog-report.md 작성 (date: <코디네이터가 정한 값, 시리즈일 때>)
제약: push·main 병합·rebase·worktree 삭제 금지. 본체와 다른 worktree는 수정 금지. 질문은 사용자에게 직접 하지 말고 지시문의 ask로 코디네이터에게
담당: _posts/<날짜>-<slug>.md, _includes/figures/<slug>/, .blog-report.md (도표 CSS를 바꿔야 하면 먼저 ask)
완료 증거: jekyll build·htmlproofer 통과, 커밋 해시, .blog-report.md, worker_done --report-path <wt>/.blog-report.md
```

### K4. 기다리기와 메시지 처리
```sh
orca orchestration check --wait --types "worker_done,escalation,question" --timeout-ms 240000 --json
```
- Bash 도구는 한 명령에 최대 10분이라 `--timeout-ms`는 그보다 짧게 두고 Bash `timeout`을 600000으로 준다. 대기가 끊기거나 빈 결과로 끝나도 실패가 아니다 (아무것도 예약하지 않는다). 다시 기다린다.
- **대기 중에는 새 요청과 사용자 말이 보이지 않는다.** 출발 세션의 `terminal send`와 사용자 입력은 대기 명령이 돌아온 뒤에 들어온다. 그래서 대기는 4분 안쪽으로 짧게 두고, 돌아올 때마다 **쌓인 "블로그 요청"·사용자 메시지를 먼저** 처리한다 (요청이면 K2·K3).
- 한 Delivery에는 여러 글의 메시지가 섞여 온다 (타입 필터와 상관없이 batch 전체). **batch의 모든 행을 처리하고 ack한 다음에** K5 같은 긴 일을 한다. ack 전에 다른 `check --wait`를 부르면 같은 batch가 다시 온다.
  - `question`: 브리프로 답할 수 있으면 `orca orchestration reply --id <message_id> --body "<답>" --json`. 아니면 AskUserQuestion으로 사용자에게 묻고(질문에 글 제목·slug를 넣는다) 그 답을 `reply`한다. 필터링에서 판단이 애매한 항목은 반드시 사용자에게 묻는다.
  - `escalation`: 내용(막힌 이유)을 사용자에게 보고하고, 답이나 결정을 `reply`하거나 수정 지시(K5의 6번)로 보낸다.
  - `worker_done`: `state.md`에서 기대한 Dispatch인지와 종류를 확인한다. `글`·`수정`이면 `.blog-report.md`, `검수`면 `.blog-review.md`를 읽는다. 그 Dispatch는 `worker-retain --dispatch <id> --json`으로 남긴다 (사용자 결정, 2026-10-29: 사용자가 탭에서 과정을 보고, 수정 지시에 같은 탭을 다시 쓴다). `--outcome failed`면 이유를 사용자에게 보고하고 다시 시킬지 묻는다. 처리한 글은 K5 대기 목록에 넣는다.
  - 모두 처리하면 `orca orchestration check --ack <delivery_id> --json`. 그다음 대기 목록의 글로 K5를 한다.
- 단계가 바뀔 때마다 카드 comment와 `state.md`를 갱신한다 (예: "초안 완료, 검수 중").
- **턴을 끝내도 되는 때**: 이 Run에 아직 끝나지 않은 Dispatch가 있으면 턴을 끝내지 않고 대기를 이어간다 (끝내면 워커의 `ask`가 방치된다). 사용자 확인이 필요하면 AskUserQuestion으로 묻는다. 진행 중인 Dispatch가 없고 사용자 답만 기다릴 때만 보고하고 턴을 끝낸다.
- 워커 탭에 권한 창이 떠서 멈춘 것 같으면(`worker-show --dispatch <id> --json`의 `agentWait`) 사용자에게 그 탭을 봐 달라고 한다.

### K5. 코디네이터 검수
워커 보고를 그대로 믿지 않고 직접 확인한다.
1. **범위**: `git -C <wt> log --oneline origin/main..HEAD`, `git -C <wt> diff --stat origin/main...HEAD`. 담당 파일만 바뀌었는지, 커밋 형식, `.blog-*`·`_site`가 커밋되지 않았는지, `git -C <wt> status --porcelain`이 비어 있는지 본다.
2. **빌드**: `<wt>`에서 C절의 빌드 명령(jekyll build, htmlproofer)을 돌린다.
3. **필터링 재점검**: 브리프의 걸러야 할 항목과 4단계 공통 grep을 공개될 것 전체에 직접 돌린다: `git -C <wt> log -p origin/main..HEAD` (커밋 메시지와 모든 변경 파일 포함).
4. **브리프 대조**: 최종 결정이 맞게 쓰였는지, 버린 안을 결론처럼 쓰지 않았는지, 글의 주장이 근거 표에 있고 `근거 부족`인 주장을 사실처럼 쓰지 않았는지, 사용자 요구(넣을 것·뺄 것)를 지켰는지, date가 현재보다 과거인지 본다.
5. **다른 모델 검수**: 3단계 "검수" 3번대로 Codex 워커를 글 worktree에 띄우고(Dispatch 종류 `검수`) K4 대기로 돌아간다. 수정 뒤 다시 검수하는 것은 그림이나 기술적 주장이 바뀐 경우만.
6. **수정**: 고칠 것이 있으면 직접 고치지 않고 남겨 둔 글 워커 탭에 수정 지시를 보낸다. spec은 `spec.md` 전문 + "수정할 것: <지적 목록과 근거>"로 자기 완결적으로 쓴다:
   ```sh
   orca orchestration worker-show --dispatch <글 워커 Dispatch> --json     # 터미널 handle
   orca orchestration worker-start --terminal <handle> --worktree id:<wt id> --task-title "수정: <slug>" --spec "<spec.md 전문 + 수정할 것>" --json
   ```
   그 탭을 쓸 수 없으면(사용자가 탭을 직접 써서 넘겨받았거나 chat 워커라 handle이 없음) 이전 Dispatch를 `worker-release`하고(안 되면 recovery 안내) 같은 worktree에 `--agent claude`로 새 워커를 같은 spec으로 띄운다. 새 Dispatch(종류 `수정`)를 `state.md`에 적고 K4로 돌아간다. 반영하지 않은 지적은 이유와 함께 K6에서 보고한다.

### K6. 사용자 확인 → 5단계
카드를 `--workspace-status in-review --unread`로 바꾸고 5단계대로 보여준다. 발행 승인(harness "push와 배포")을 묻는 방법: 질문에 글 제목·slug를 넣고, 승인 범위를 "발행(main 병합·push) + 배포 확인 뒤 worktree·브랜치·브리프 정리"로 적는다. 답이 "블로그 요청:"으로 시작하면 승인 답으로 쓰지 않고 새 요청으로 처리한 뒤 다시 묻는다. 승인 사실을 `state.md`에 적는다.
- 수정 요청은 K5의 6번처럼 글 워커에게 보내고, 다시 K5를 거쳐 보여준다.
- 사용자가 발행하지 않기로 하면 그 글의 모든 Dispatch(글·수정·검수)를 `worker-release`하고, worktree와 `<inbox>/<slug>`를 지울지 묻는다.

### K7. 발행·정리 → 6·7단계
승인된 글만 코디네이터가 본체에서 6·7단계를 한다. 정리 후 코디네이터 탭은 닫지 않고 다음 요청을 기다린다.

**시리즈 발행 순서** (편마다 차례로):
1. N편을 6·7단계로 발행한다.
2. N+1편 worktree를 `git -C <wt> rebase origin/main`으로 N편 위에 올린다 (6단계 2번과 같다).
3. N+1편 글 워커에게 수정 지시로 링크 갱신을 시킨다: N+1편의 시리즈 목록에 앞 편 `post_url`, 그리고 앞 편 파일의 목록 블록·예고 줄을 링크로 (담당 범위에 앞 편 파일의 그 부분을 넣는다. 앞 편 worktree는 이미 지워졌다).
4. K5로 확인하고, 앞 편 변경 diff를 사용자에게 보여 N+1편 승인을 받은 뒤 발행한다.

**Orca가 없으면**: `git -C <main> worktree add ~/orca/workspaces/tech-blog/post-<slug> -b post-<slug> origin/main`으로 글 worktree를 만들고, 글 워커는 서브에이전트(Agent 도구)에게 같은 작업 지시와 worktree 경로로 맡긴다. 검수는 `codex exec`, Codex도 없으면 다른 서브에이전트. 정리는 `git -C <main> worktree remove <경로>`와 `git -C <main> branch -d <branch>`.

## C. 글 워커: 쓰기부터 보고까지

작업 지시와 브리프를 읽고, 브리프에 적힌 원료 파일·세션을 직접 열어 확인한다. 브리프가 부족하면 지어내지 말고 지시문의 `ask`로 코디네이터에게 묻는다 (사용자에게 직접 묻지 않는다). 브랜치는 `git branch --show-current`로 확인한다. 그다음 2~4단계를 하고 보고한다.

**Jekyll 빌드 (worktree에서)**: `vendor/bundle`과 `_site`는 추적되지 않아 본체에만 있다. 이 Mac에서 확인한 방법:
```sh
M=~/Documents/dev/tech-blog
export PATH=/opt/homebrew/opt/ruby/bin:$PATH          # 시스템 ruby 2.6은 안 됨, Homebrew ruby 3.4 필요
BUNDLE_PATH=$M/vendor/bundle JEKYLL_ENV=production bundle exec jekyll build
BUNDLE_PATH=$M/vendor/bundle bundle exec htmlproofer _site --disable-external
```
- 본체의 gem(`vendor/bundle`)을 `BUNDLE_PATH`로 가리키면 된다. 복사·`bundle install` 불필요. `Gemfile.lock`은 첫 실행에 생기고 `.gitignore` 대상이다.
- `_site`는 worktree 안에 생긴다 (무시됨). 미리보기 서버는 `_site`에서 띄운다 (3단계 검수).
- 안 되면 먼저 `ruby -v`(3.4)와 `ls $M/vendor/bundle/ruby/`를 확인한다. 다른 컴퓨터는 본체에서 `bundle install` 한 번이 필요하다.

**커밋**: 글 파일과 그림(`_includes/figures/<slug>/`)만 브랜치에 커밋한다: `docs(post): <제목>` (시리즈 한 편이면 `docs(post): <시리즈 이름> N편 <제목>`). 도표 CSS를 바꿨으면 `feat(blog): ...`를 따로. `.blog-report.md`와 `_site`는 커밋하지 않는다. **push·main 병합·rebase는 하지 않는다** (코디네이터 일).

**보고** `.blog-report.md` (worktree 루트):
- 글 파일 경로, 제목·카테고리·태그·설명, 커밋 해시
- 필터링 보고: 4단계 "바꾼 것" 목록과 공통 항목 점검 결과
- 그림: 캡처 경로(밝은·어두운·모바일)와 스스로 고친 점
- 확인하지 못한 사실, 보강이 필요한 점

그다음 띄운 미리보기 서버를 끄고, 지시문의 명령으로 `worker_done --outcome succeeded --report-path <wt>/.blog-report.md`(절대 경로)를 보낸다 (못 끝냈으면 `failed`와 이유). 수정 지시를 받으면 고쳐서 커밋하고 보고서를 갱신한 뒤 그 지시의 `worker_done`을 보낸다.

`ask`가 시간 초과로 끝나면(코디네이터가 사용자에게 묻는 중일 수 있다) 새로 묻지 말고 같은 message ID로 다시 기다린다.

## 2. 글 쓰기

원료(대화·기획서·커밋·메모)는 "나를 위한 기록"이고 글은 "처음 보는 독자를 위한 설명"이다. 다시 쓴다.

- **제목**: 검색될 만한 구체적인 제목. 예) "ROS2 QoS: Reliable과 Best Effort, 언제 무엇을 쓸까"
- **구성**: 도입(어떤 문제를 겪었나, 왜 읽어야 하나) → 개념 → 예시 코드 → 주의할 점 → 정리
- **분량**: 핵심을 충분히 설명하되 장황하지 않게. 애드센스는 얇은 글을 싫어하므로, 원료가 너무 적으면 보강할 점을 보고서에 적는다.
- **정확성**: 주장은 브리프의 근거 표에 있는 것만 사실로 쓴다. `근거 부족`이거나 원료에 "(확인 필요)"가 있으면 원료·공식 문서로 확인하고, 확인할 수 없으면 그 문장을 빼거나 코디네이터에게 묻는다. 지어내지 않는다.
- **독창성**: 공식 문서를 옮겨 쓰지 않는다. 직접 겪은 상황과 해결 과정이 글의 가치다.
- 한국어, 용어와 코드는 원문. 문체는 "~합니다".
- 카테고리와 태그는 기존 글(`_posts/`)에서 쓰던 것을 우선 재사용해서 일관성을 지킨다.
- 이미 발행된 관련 글(본체 main에 있는 글)이 있으면 본문에서 `[제목]({% post_url 파일명-확장자제외 %})`로 연결한다 (내부 링크는 체류 시간과 검색 노출에 도움). 글 worktree에는 이 글 하나만 있으므로 **아직 발행 안 된 글에는 `post_url`을 걸지 않는다** (빌드가 깨진다).

**시리즈** (한 주제를 여러 편으로)
- 개념 → 적용 → 실전 사례처럼 앞 편을 읽으면 다음 편이 쉬워지는 순서로 나눈다. 각 편은 따로 읽어도 이해되게 쓴다.
- 모든 편 맨 위에 같은 목록 블록을 둔다. 지금 글은 굵게, **이미 발행된 편만** `post_url` 링크, 아직 없는 편은 링크 없이 제목만 (예고):
  ```markdown
  > **시리즈: <시리즈 이름>**
  > 1. [1편 짧은 제목]({% post_url 2026-10-28-first-slug %})
  > 2. **2편 짧은 제목** ← 지금 글
  > 3. 3편 짧은 제목 (예정)
  ```
- 같은 날 발행하면 편 순서대로 date를 5분씩 띄운다. 카테고리는 모든 편이 같게.
- 편마다 끝에 다음 편 예고 한 줄 (링크 없이). 뒤 편을 발행할 때 그 편에서 앞 편 링크를 걸고, 앞 편의 예고도 링크로 바꾼다. 코디네이터가 뒤 편 글 워커에게 시킨다 (K7 "시리즈 발행 순서").
- 편마다 worktree가 따로이므로 쓰는 동안은 목록에 제목만 두고, 앞 편이 본체 main에 들어온 뒤 rebase해서 링크를 채운다.

파일: `_posts/YYYY-MM-DD-<영어-slug>.md` (발행일 기준). **date는 현재 시각보다 과거여야 한다.** Jekyll은 미래 시각의 글을 빌드에서 빼 버린다 (`date` 명령으로 현재 시각 확인). 같은 날 여러 편이면 몇 분씩 차이를 둔다. 주소는 `https://37writes.github.io/posts/<영어-slug>/`가 된다.

```yaml
---
title: "ROS2 QoS: Reliable과 Best Effort, 언제 무엇을 쓸까"
date: 2026-10-14 15:00:00 +0900
categories: [ROS2, 통신]          # 최대 2단계: [대분류, 소분류]
tags: [ros2, dds, qos]            # 영어 소문자
description: "검색 결과에 보일 요약 120~160자"
---
```

## 3. 그림 넣기

긴 설명보다 잘 그린 도표 한 장이 먼저 이해된다. 글마다 **핵심 개념 1개**(필요하면 어려운 대목에 1개 더)를 도표로 넣는다.
이미 발행한 글에 그림만 넣을 때도 코디네이터가 글 worktree와 글 워커를 띄워 이 단계부터 시키고, K5·K6·K7로 간다 (4단계 필터링은 그림 글자에 적용).
아래에서 `<scripts>` = `<base directory>/../../scripts`.

**무엇을 그릴지**
- 그림과 캡션만 본 독자가 말할 수 있어야 할 **문장 하나**를 정하고, 요소를 3~6개로 줄인다.
- 글의 성격에 맞는 형태를 고른다:

  | 글의 핵심 | 형태 | 예 |
  |---|---|---|
  | 같은 조건, 다른 결과 | 같은 배치 두 칸, 차이만 강조 | 로컬 vs 배포 권한, 브라우저 vs CLI 신뢰 목록 |
  | 흐름·분기 | 위→아래 상자와 선 | git commit 안에서 훅이 도는 자리 |
  | 시간 순서 | 세로 타임라인 | 서명 생성 → 저장 → 만료 |
  | 역할·구조 | 묶음과 그 사이의 전달물 | 사람 / 대화 세션 / 워커 |
  | 계층 | 쌓은 상자 (순서 화살표 없이) | 컨텍스트 4계층 |
- 본문의 표를 그대로 다시 그리지 않는다. 글에 ASCII 흐름도(` ```text `)가 있으면 그림으로 바꾸고 원래 블록은 뺀다.
- 위치: 도입부(문제를 말한 직후)나 그 개념을 다루는 절 바로 아래.

**만들기**: 직접 쓴 인라인 SVG를 `_includes/figures/<slug>/<이름>.svg`에 두고 글에서 부른다.
```html
<figure class="diagram">
{% include figures/<slug>/<이름>.svg %}
<figcaption>결론 한 문장</figcaption>
</figure>
```
- 색·글꼴은 블로그 CSS(`assets/css/jekyll-theme-chirpy.scss`의 `figure.diagram`) 클래스만 쓴다. 색값을 직접 쓰지 않아야 다크 모드가 따라온다.
  `d-strong` 제목 · `d-muted` 보조 · `d-small` 13px(덜 중요한 것만) · `d-mono` 코드 · `d-accent` 실패·문제 지점 · `d-box` 상자 · `d-line` 선 · `d-dot` 타임라인 점
- 폭: 좌우 비교는 넓은 그림(`diagram-wide`, viewBox 폭 480)과 세로로 쌓은 좁은 그림(`diagram-narrow`, 320)을 한 파일에 둘 다 넣는다. 화면 폭에 따라 하나만 보인다 (넓은 그림을 모바일에서 줄이면 글자가 11px까지 작아진다). 세로 흐름은 한 장(`diagram-tall`, 360)으로 둘 다 쓴다.
- 글자: 핵심 문구는 15px 이상. 폭은 한글 한 글자 약 15~16px, 고정폭 약 9px로 어림해 상자를 넘지 않게 한다.
- 성공·실패를 색만으로 나누지 않는다 (✓/✗ + 말).
- `role="img"`와 `aria-labelledby`로 `<title>`(무엇의 그림)과 `<desc>`(관계를 문장으로)를 잇는다. id는 그림마다 다르게 (좁은 그림은 `-n`).
- 본문에 없는 주장, 추정을 사실처럼, 병렬을 순서처럼 그리지 않는다. AI 두뇌·로봇 같은 장식, 가짜 질감, 움직임은 넣지 않는다.
- 사진풍 삽화는 이미지 생성 도구가 연결돼 있을 때만 쓰고, 글자·명령어는 그림 안에 넣지 않는다.

**검수** (1·2는 글 워커, 3·4는 코디네이터)
1. 빌드(C절의 `BUNDLE_PATH`·ruby PATH 형태 그대로: jekyll build와 htmlproofer) 후 `_site`에서 `sh <scripts>/py.sh -m http.server <포트> --bind 127.0.0.1`로 띄운다. 포트는 4100부터 비어 있는 것을 쓴다.
   브라우저 캡처·조작은 **ego lite만** 사용한다. `../design/references/ego-validation.md`와 설치된 `ego-browser skill`을 읽는다. 코디네이터가 목표당 TaskSpace 하나를 만들고 워커별 Page를 할당한다. 모바일/데스크톱·light/dark에서 그림까지 이동해 캡처하고 이미지 도구로 글자 겹침·넘침·선 연결을 확인한다. 에뮬레이션 설정·측정·캡처는 같은 실행에서 한다. `shot.py`/별도 headless로 우회하지 않는다.
2. 새 색 조합을 썼으면 `sh <scripts>/py.sh <scripts>/contrast.py`로 잰다 (상자 바탕 `--paper-deep` 기준도).
3. **다른 모델이 검수**한다 (코디네이터, K5). 내 결론은 주지 않고 글·SVG 경로·캡처 경로만 준다. 물을 것: 본문과 어긋나거나 본문에 없는 주장, 그림·캡션만 보고 핵심을 말할 수 있는가, 위치, title/desc·색·글자 크기, 선 방향, 본문의 기술 설명 중 틀리거나 과장된 문장.
   사용자가 진행을 볼 수 있게 **Orca 탭에서 돌린다** (사용자 결정, 2026-10-29). 코디네이터의 Run으로 글 worktree에 Codex 워커를 띄운다:
   ```sh
   orca orchestration worker-start --worktree id:<wt id> --agent codex --task-title "검수: <slug>" --spec "<작업 지시>" --json
   ```
   따로 기다리지 않고 K4 대기로 돌아간다 (Run inbox 하나에 모든 글의 메시지가 온다).
   - 작업 지시(harness 5항목): 대상 = 글·SVG·캡처 PNG 경로, 변경 = 위 질문의 답을 worktree의 `.blog-review.md`에 쓰기, 제약 = 다른 파일 수정·커밋·push 금지, 담당 범위 = `.blog-review.md` 하나, 완료 증거 = 그 파일과 `worker_done --report-path <wt>/.blog-review.md`. 캡처를 열 수 없으면 SVG 코드로 판단하고 그렇다고 적게 한다.
   - `worker_done`을 받으면(K4) 파일을 읽고, 탭은 `worker-retain`으로 남겨 5단계 보고에 알린다 (사용자가 탭에서 검수 과정을 본다). 7단계 정리에서 release한다.
   - Orca가 없으면 `codex exec -s read-only --color never -i /tmp/fig-<slug>-light.png -o /tmp/fig-review.md - < /tmp/fig-prompt.md` (글 worktree에서), Codex도 없으면 새 서브에이전트에게 같은 내용으로 맡긴다.
4. 검수 결과 중 반영할 것을 골라 글 워커에게 수정 지시로 보내고(K5의 6번), 다시 캡처를 받는다. 반영하지 않은 지적은 이유와 함께 5단계에서 보고한다.

## 4. 공개 전 필터링 (반드시)

브리프의 **구분**(지정한 메모가 원료면 메모의 `category`도)에 따라 다르게 처리하고, **무엇을 바꿨는지 목록으로 보고한다.**

**회사**
- 회사명, 제품·서비스명, 고객사명, 내부 프로젝트·레포 이름 → 삭제하거나 "사내 서비스", "API 서버" 같은 일반 표현으로
- 내부 도메인, URL, IP, 서버·버킷 이름, AWS 계정·리소스 ID, 내부 API 경로 → 예시 값으로 (`example.com`, `my-bucket`)
- 회사 코드를 그대로 옮기지 않는다 → 개념을 보여주는 최소 예시 코드를 새로 쓴다
- 사업 정보 (매출, 일정, 미공개 기능, 장애 영향 범위) → 삭제
- 판단이 애매한 항목은 지우지 말고 묻는다 (글 워커는 코디네이터에게, 코디네이터는 사용자에게)

**대학원**
- 미발표 연구 내용, 실험 데이터, 지도교수·연구실 내부 정보, 과제 정답이 되는 코드 → 사용자에게 공개 가능 여부를 확인한다 (글 워커는 코디네이터를 거쳐서)

**공통 (모든 글)**
- 비밀번호, API 키, 토큰, 개인 이메일·전화번호, 로컬 경로의 사용자 이름(`/Users/이름/`) → 반드시 제거
- 대화가 원료면 회사 작업이 섞여 있기 쉽다. 브리프에 적힌 구분과 걸러야 할 항목을 기준으로 위 규칙을 적용하고, 마지막에 글 파일 전체를 grep으로 점검한다 (회사·서비스·레포 이름, 계정 ID 12자리 `[0-9]{12}`, `AKIA`, `/Users/`, 이메일 `@`). 코디네이터도 K5에서 같은 grep을 다시 돌린다.

## 5. 확인 (코디네이터)

사용자에게 보여준다:
1. 제목, 카테고리, 태그, 설명, 브랜치와 worktree 경로
2. 글 전문 (길면 구성 요약 + 핵심 부분)
3. 필터링 보고: "바꾼 것" 목록. 회사·대학원이 아니어도 공통 항목 점검 결과를 한 줄로.
4. 그림: 캡처(밝은·어두운·모바일)와 검수에서 고친 점, 반영하지 않은 지적과 이유
5. 코디네이터 검수(K5) 결과와 남겨 둔 워커 탭

수정 요청은 글 워커에게 수정 지시로 보내 브랜치에 커밋으로 반영하고, **명시적인 발행 승인**을 받는다. 승인 전에는 본체 main에 아무것도 하지 않는다.

## 6. 발행 (코디네이터, 승인 뒤에만)

1. 본체 `<main>`이 `main` 브랜치이고 깨끗한지 확인한다 (`git -C <main> status -sb`). 아니면 멈추고 사용자에게 알린다. 그다음 `git -C <main> pull --ff-only`.
2. main이 앞서갔으면 `git -C <wt> rebase origin/main` (1번의 pull로 `origin/main`이 최신이다). 충돌이 나면 `git -C <wt> rebase --abort`로 되돌리고, 글 워커에게 **그 수정 지시에 한해 rebase를 허용**한다고 적어 해결을 시킨다. rebase 뒤에는 `git -C <wt> range-diff <rebase 전 HEAD>...HEAD`로 승인받은 내용과 같은지 보고, 글 내용이 달라졌으면 사용자에게 다시 승인을 받는다. 병합 대상이 바뀌었으니 빌드를 다시 돌려 확인한다.
3. 본체에서 `git -C <main> merge --ff-only <branch>` (브랜치는 같은 저장소를 공유하므로 바로 보인다)
4. `git -C <main> push origin main` (위험 명령 확인 훅이 한 번 더 묻는다)
5. 배포 확인: **push한 커밋**의 실행을 본다 (`-L 1`은 이전 성공을 잡을 수 있다):
   ```sh
   SHA=$(git -C <main> rev-parse HEAD)
   gh run list -R 37writes/37writes.github.io --workflow pages-deploy.yml --branch main --commit $SHA --json databaseId,status,conclusion,url
   gh run watch <databaseId> -R 37writes/37writes.github.io --exit-status
   ```
   목록이 비어 있으면 몇 초 뒤 다시 본다. `conclusion`이 success일 때만 다음으로 간다 (보통 1분 안팎). 실패하면 `gh run view <databaseId> --log-failed`로 원인을 보고하고 멈춘다 (정리하지 않는다).
6. 글 주소를 알려준다 (시리즈면 편마다).

## 7. 정리 (코디네이터, 맨 마지막)

배포 성공까지 **모두 끝낸 뒤**에 한다. 정리는 K6의 승인 범위에 들어 있다. 코디네이터는 본체에 있으므로 글 worktree를 지워도 코디네이터 세션은 그대로다.

1. **지우기 전 확인**: 둘 중 하나라도 아니면 멈추고 사용자에게 보고한다 (승인 뒤 워커가 늦게 고친 것이 있을 수 있다).
   ```sh
   git -C <wt> status --porcelain                              # 비어 있어야 한다 (무시 파일 제외)
   git -C <main> merge-base --is-ancestor <branch> main && echo merged
   ```
2. **워커 정리**: 이 글의 Dispatch(글·수정·검수)가 모두 끝난(settled) 상태인지 `state.md`·`worker-list`로 보고, 각각 `orca orchestration worker-release --dispatch <id> --json` (retain도 풀린다). `release_unknown` 등 불확실하면(exit 1) receipt의 복구 안내를 따르고, `terminal close`로 대신하지 않으며 3번으로 넘어가지 않는다.
3. **worktree와 브랜치**:
   ```sh
   orca worktree set --worktree id:<wt id> --workspace-status completed --json
   orca worktree rm --worktree id:<wt id> --force --json      # worktree와 <branch> 브랜치 삭제
   git -C <main> branch --list <branch>                        # 남았으면 git -C <main> branch -d <branch> (이미 병합돼 -d로 충분)
   ```
4. **브리프** (걸러야 할 회사 항목이 적혀 있다). slug가 비면 다른 글까지 지우므로 이 형태 그대로:
   ```sh
   SLUG=<slug>; rm -r "$HOME/.config/37writes-kit/blog/${SLUG:?}"
   ```

사용자에게 글 주소와 정리 결과(지운 worktree·브랜치)를 보고한다. Orca가 없었으면 3번 대신 `git -C <main> worktree remove <경로>`와 `branch -d`.

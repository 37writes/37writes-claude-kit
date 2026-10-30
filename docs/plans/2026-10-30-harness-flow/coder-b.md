# S1b 문서 Coder 보고 (coder-b)

- Task: task_5087e3593fb0 / Dispatch: ctx_d657713ebda9
- 대상: 기획서 `docs/plans/2026-10-30-harness-flow.md`(f0eef97) 설계 1·2·3(문서)·4·5(문서)·6·7
- 실행 모델: Claude Opus 5.5 (`global.anthropic.claude-opus-5-5`, 세션 환경에 표시된 모델 ID)
- 담당 범위 밖(scripts/, hooks/, types/)은 건드리지 않았다.

## 파일별 변경

| 파일 | 변경 |
|---|---|
| `skills/harness/SKILL.md` | 전체 재작성 (144줄). 한 줄 description. 맨 앞 우선순위 문장("프로필의 예전 작업 규칙 문장보다 이 공통 규칙이 우선, 사실 줄은 프로필"), 의도 → 흐름 표(질문·기능·오류·이어서·프로젝트 설계·디자인·점검·배포·블로그·kit 개선), 경로 Read 계약(plan·init·release는 `<base directory>/../X/SKILL.md`, 읽은 폴더 = base directory, 파악한 요청 = 인자). `## 공통 규칙`: 1. 등급과 배치(T0~T2 표, 배치 표, 다른 모델 의견은 Orca 탭), 승인, push와 배포(일반 push, 자동 배포 조건 1~5, 정책과 상관없는 T2, guard는 best-effort), 완료 판정과 기록(SHA 기준 증거, 자동 롤백 없음, 기록 = 기획서 + 커밋, 끝난 기획서 마지막 커밋에서 `git rm`, 지운 기획서 찾기). `## 절차`: 2 계획(조건부 반박), 3 실행(워커 선택, Orca 배치·보드 카드 상태, Task spec 5항목), 4 보고, 5 검증, 6 T2 적용, 7 마무리, 8 이어서(`sh <base directory>/../../scripts/py.sh <base directory>/../../scripts/plans.py`, kit 판정과 무관, 충돌이면 자동 재개 안 함). devlog 언급 없음 |
| `skills/plan/SKILL.md` | 프로젝트 설계 섹션(`docs/plans/project.md`, `type: project`, 끝난 항목 `완료 <커밋>`, 지우지 않음), 작업 기획서에 `## 남은 일`, `status: ... done \| abandoned`(abandoned는 이유), 조사 대상(CLAUDE.md·AGENTS.md·README·project.md·진행 중 기획서·코드, 지운 기획서는 git 기록), 끝난 기획서 삭제 한 줄, /kit:init 안내 제거(프로필 없어도 진행), 등급·승인 정의는 harness 참조만 |
| `skills/init/SKILL.md` | 전체 재작성: 보완 절차. 기존 CLAUDE.md·AGENTS.md·README·빌드 설정을 먼저 읽고 빠진 줄만 묻는다. 사실만 담은 프로필 블록 + `절차` 줄, 자동 배포 줄 형식은 설계 5 그대로 (push가 곧 배포일 때만 5번째 질문). 기존 내용은 덮지 않고, 예전 "작업 규칙" 문장은 사용자가 원할 때만 바꾼다. AGENTS.md만 있으면 `@AGENTS.md` + 프로필 블록. docs/devlog·등록부·devlog 안내 없음 |
| `skills/commit/SKILL.md` | devlog 언급 제거(docs 행 "README, 기획서, 주석", 마지막 devlog 제안 → 기획서 갱신을 그 단계 커밋에), 삭제 커밋에도 Refs, push 단계는 harness "push와 배포" 참조 |
| `skills/release/SKILL.md` | 승인·자동 배포·완료 판정은 harness 참조. "배포 push" 블록: 정책이 있으면 `deploy_gate.py verify --sha <SHA>` → `git push <원격> <SHA>:refs/heads/<브랜치>` → `deploy_gate.py confirm --sha <SHA>`, 정책이 없으면 배포 승인 뒤 push. Amplify 확인은 `jobSummaries[?commitId=='<SHA>']` job + 핵심 기능 결과, HTTP 200만으로 완료 아님. 마무리에서 기획서 삭제, 보고에 SHA |
| `skills/check/SKILL.md` | 범위 안 결함 수정은 harness "승인" 참조 한 줄 |
| `skills/design/SKILL.md` | 7단계의 T2 정의 → harness "승인", "push와 배포" 참조 |
| `skills/blog/SKILL.md` | description·제목을 대화·기획서·커밋으로. 원료 순서 대화 → 기획서(지워졌으면 `git log`/`git show`) → 커밋·diff → 검증 보고서 → 지난 대화, TIL은 사용자가 지정할 때만. 브리프에 주장별 근거 표와 `근거 부족` 표시, K5.4 검수에서 그 표와 대조. 옛 7단계(my-notes 발행 표시 커밋, /kit:til 제안) 삭제 후 8 → 7로 번호 이동, 내부 참조("6·7단계" 등) 갱신. "글 써줘"는 작성·검수까지, 발행은 글마다 승인 |
| `skills/feedback/SKILL.md` | 대상 목록에서 devlog·til·weekly 제거 (harness, init, commit, plan, design, blog, check, release, feedback, hook, 패널, 새 스킬, 기타). 예시도 plan으로 |
| `skills/devlog`, `skills/til`, `skills/weekly` | `git rm` |
| `docs/plans/` | 끝난 기획서 7개 `git rm`: 2026-10-28-design-skill, 2026-10-29-blog-coordinator, 2026-10-29-blog-worktree-flow, 2026-10-29-harness-orca-board, 2026-10-29-harness-orca-session-start, 2026-10-29-orca-harness-context, 2026-10-30-planning-multi-agent (+ 보고서 폴더 `2026-10-30-planning-multi-agent/`, 다른 6개는 폴더 없음). 7개 모두 `status: done` 확인 후 삭제. `2026-10-30-harness-flow.md`와 그 폴더, `docs/devlog/`는 그대로 |
| `README.md` | "쓰는 법: 말로 요청한다"(10행 표), 스킬 표(9개), "기록: 기획서와 커밋"(삭제 규칙, 지운 기획서 찾는 git 명령), "자동 배포 (선택)"(정책 줄 예, 필수·선택 항목, 순서, guard 통과 조건, 정책과 상관없이 승인받는 것, 실패 시 보고, 한계: best-effort이고 권한 경계가 아님), /kit 패널(진행 중 기획서), 훅 표(Stop 없음, kit 판정 설명), "없앤 기능 (0.15.0)" 표, 로드맵 0.15.0 |
| `CLAUDE.md` | 프로필 블록 새 형식(테스트 줄에 test_*.sh, "작업 규칙" → "절차" 줄), 구조(스킬 9개, plans.py·deploy_gate.py·test_*.sh, Stop 훅 없음), 핵심 결정 갱신(kit 판정, Orca 안내, 등록부, harness, 토큰 비용) + 새 결정(harness 중심 흐름, 기록 = 기획서 + 커밋, 재개, 자동 배포, blog 0.15.0 문단, push 확인과 자동 배포 관계), my-notes 행, 검증 방법 2·6. 다른 기존 결정 기록은 유지 |
| `.claude-plugin/plugin.json`, `marketplace.json` | version 0.15.0, description에서 작업 로그·TIL·주간 정리 제거 |

## 해석 (지시에 명시되지 않아 내가 정한 것)

1. harness 섹션 번호 "1. 등급과 배치", "3. 실행"을 유지했다. `scripts/orca_context.py` 안내문이 "harness 1단계 / 3단계"를 가리키고 scripts/는 담당 밖이라서.
2. init은 `docs/plans/`를 미리 만들지 않는다 (plan이 처음 쓸 때 만든다). kit 판정이 프로필 표시로 바뀌어 폴더가 필요 없어서.
3. release의 태그 push(`--follow-tags`, `git push <원격> vX.Y.Z`)는 자동 배포 정책이 다루지 않으므로 늘 따로 확인받는다고 적었다 (guard 조건 1이 전체 SHA refspec 하나라서 태그 push는 어차피 통과하지 않음).
4. blog의 단계 번호를 하나씩 당겼다 (옛 8 → 7). 코디네이터 문단 안 참조도 같이 고쳤다.
5. feedback 대상 목록에 기존에 빠져 있던 harness·design·패널을 넣었다.
6. README·CLAUDE.md의 훅·패널·plans.py·deploy_gate.py 설명은 기획서 설계 2·3·5 계약대로 썼다. 이 worktree의 scripts/는 아직 옛 코드다 (Coder A가 병렬 구현 중).
7. README·CLAUDE.md의 devlog 줄은 과거 기록·호환 설명으로만 남겼다 (아래 grep).

## 실행한 명령과 결과

```text
$ claude plugin validate .
✔ Validation passed with warnings   (경고: ICON_MISSING, 예전과 같음)

$ wc -l skills/harness/SKILL.md
144 skills/harness/SKILL.md          (≤ 170)

$ grep -rn "kit:devlog\|kit:til\|kit:weekly\|devlog" skills README.md CLAUDE.md .claude-plugin
skills/, .claude-plugin/: 0줄
README.md:102  kit 판정 호환 (예전 init 레포의 docs/devlog/도 kit로 인식)
README.md:108-110  "없앤 기능 (0.15.0)" 표 (devlog·til·weekly, 과거 파일은 그대로)
README.md:122, 134  로드맵 과거 기록 ("0.15.0에서 제거")
CLAUDE.md:42  kit 판정 호환·결정 이유
CLAUDE.md:44  등록부 과거 기록 (weekly가 쓰던 목록)
CLAUDE.md:48  기록 결정 (devlog·til·weekly를 없앤 이유, 과거 docs/devlog/는 그대로)
CLAUDE.md:49  재개 결정 (예전 이어하기가 devlog를 읽던 방식)
CLAUDE.md:53  blog 0.15.0 문단 (/kit:til 제안 단계를 없앴다)
→ 모두 과거 기록·호환 설명

$ grep -rn "T2\|배포가 되는\|push 줄\|배포 아님" skills --include=SKILL.md | grep -v "^skills/harness/"
skills/init/SKILL.md:14   프로필이 없으면 push·배포는 묻는 쪽 (프로필 사실의 결과, 정의 아님)
skills/init/SKILL.md:67   프로필 템플릿의 push 줄 형식
skills/init/SKILL.md:75   push 줄 값을 고르는 기준 (프로필 사실을 정하는 법, guard가 읽는 줄 형식)
skills/init/SKILL.md:92   "이후 push는 프로필 push 줄과 harness 공통 규칙을 따른다" (참조)
skills/plan/SKILL.md:132  기획서 템플릿의 "## 승인 필요 (T2만)" 제목
skills/plan/SKILL.md:155  "harness 절차(작업 지시, 독립 검증, T2 미리보기)" (참조)
skills/release/SKILL.md:74  태그 push는 따로 확인 (정책이 다루지 않는 것, 머리말의 harness 참조를 따름)
→ T2·push·배포 등급을 정의하는 문장은 harness에만 있다. init의 줄은 프로필 형식(사실)이다.

$ git diff HEAD | grep "^+" | grep "/Users/"
(없음)  새 로컬 절대 경로 없음. `~/`는 기존에 있던 경로(`~/.config/37writes-kit/...`, CLAUDE.md의 개발 모드 경로)만
```

## 남은 위험

- 문서는 기획서 계약대로 `plans.py [--cwd DIR] [--json] [--all]`, `deploy_gate.py verify|confirm [--repo DIR] [--sha REV]`를 가리킨다. S1a 구현이 계약과 다르면 harness 8단계, release "배포 push", README·CLAUDE.md를 함께 맞춰야 한다.
- 이 worktree의 SessionStart 안내는 아직 옛 문구("작업 로그는 docs/devlog/")를 낸다. S1a가 `session_start.py`를 바꾸기 전까지 문서와 다르다.
- README의 훅 표·패널 설명(진행 중 기획서, Stop 훅 없음)은 S1a의 hooks.json·panel.tsx 변경이 합쳐져야 맞다.
- harness·init·plan의 실제 동작(경로 Read 계약, init 보완, project.md)은 비대화 실행으로 확인하지 않았다 (검증 단계의 몫).
- push·배포·커밋 외 원격 작업은 하지 않았다.

## 재작업 (S1b-r)

- Task: task_ec5318307c98 / Dispatch: ctx_f8fdad589746. 근거: `validation.md`의 C b+d, C c-3, B, F3·F4·F5와 검증 중 사용자 결정(my-notes·등록부 삭제). 실행 모델 Claude Opus 5.5 (`global.anthropic.claude-opus-5-5`).
- 시작 HEAD `1d47d0f` (Coder A 코드 포함). scripts/·hooks/·types/·기획서 본문은 건드리지 않았다.

### 변경

| 항목 | 파일 | 변경 |
|---|---|---|
| F3 마무리 순서 | harness "완료 판정과 기록"·7 마무리, plan 6단계·프로젝트 설계, commit Refs·마지막 줄, release 4, README "기록", CLAUDE.md 기록 결정 | 단계마다 그 커밋에 체크박스·결과 → 마지막 작업 커밋에 `status: done`(`abandoned` + 이유)·마지막 결과·`## 남은 일` → 바로 이어 삭제 커밋 `docs(plan): <slug> 완료, 기획서 삭제`(본문 Refs + 결과 한 줄 + 사용자만 할 남은 확인). 작은 작업도 같은 두 커밋 순서. "따로 정리 커밋을 만들지 않는다" 삭제. Refs는 기획 커밋부터 모든 커밋에 필수 (commit의 "Refs (선택)" → "기획서가 있는 작업이면 필수", plan 6.2 기획 커밋에도 Refs). `git show <삭제 커밋>^:`이 done 상태를 보인다고 명시. project.md의 `완료 <커밋>`은 삭제 커밋. CLAUDE.md에 이유(S2 검증 F3, 2026-10-30) |
| F4 정의 한 곳 | harness "push와 배포", release:11·74, README 36·72·79·82, CLAUDE.md 50·54, init 49·67·76 | 태그 push·릴리즈 생성·파일 전달은 매번 확인 → harness "정책이 다루지 않는 것"으로 옮김. release는 "배포 승인/확인을 받고 = harness가 정한 승인" 참조만. README는 "줄이 없으면 매번 승인", "정책을 처음 넣거나 바꾸는 push … 승인" 등을 "승인 조건은 harness 'push와 배포'"로, guard 조건은 "guard가 대조하는 것"(동작 설명)으로. CLAUDE.md 50·54는 배경·이유만 두고 "규칙 본문은 harness". init의 "(=배포마다 승인)", "(없으면 배포는 매번 승인)", push 템플릿 "(승인한 커밋은 바로 push)" → 참조 또는 사실("push해도 배포되지 않음")로 |
| F5 이어서 | harness 8, README 32 | 기본은 `plans.py`(기계용 `--json`)의 활성 목록만 보고, 끝난·지운 기획서는 읽거나 보고하지 않음. `--all`(5개 제한 없이 + 끝난 작업의 오래된 복사본 진단)은 사용자가 묻거나 충돌·"상태 확인 필요"를 풀 때만 |
| my-notes·등록부 삭제 | CLAUDE.md 44·48·53·my-notes 행, README 109·110, blog:10·37·47·54·297 | "그대로 둔다" → "2026-10-30 사용자 결정으로 삭제". 기록 결정의 보존 목록은 `docs/devlog/`, `.git/37writes-kit-reminded`만. my-notes 행은 "삭제됨 (2026-10-30, 사용자 결정)" 한 줄(공개 금지 사유 제거). blog의 TIL 메모 행·본문은 my-notes 경로 없이 "사용자가 지정한 메모 파일만 읽는다" |
| deploy_gate 동작 | harness 조건 4, release verify 주석, README 순서, CLAUDE.md 구조·자동 배포 결정 | "그 SHA의 깨끗한 임시 checkout에서 실행, 검증 명령이 추적 파일을 바꾸면 실패". CLAUDE.md에 이유(S2 F1·F2). "제자리"·"HEAD == SHA" 표현은 원래 없었다 |

### 실행한 명령과 결과

```text
$ claude plugin validate .
✔ Validation passed with warnings          (ICON_MISSING만)

$ wc -l skills/harness/SKILL.md
149                                          (≤ 170)

$ grep -rn "따로 정리 커밋" skills README.md CLAUDE.md
(0건)

$ grep -rn "my-notes\|repos.txt" skills README.md CLAUDE.md
README.md:109   없앤 기능 표: my-notes 저장소는 삭제 (2026-10-30, 사용자 결정)
README.md:110   없앤 기능 표: 등록부 repos.txt와 my-notes는 삭제 (2026-10-30, 사용자 결정)
CLAUDE.md:44    등록부 결정: 쓰기 중단 이유 + "파일도 2026-10-30 사용자 결정으로 삭제"
CLAUDE.md:65    관련 저장소: my-notes 삭제됨 (2026-10-30, 사용자 결정)
→ 삭제 사실 기록뿐

$ git diff | grep "^+" | grep -c "/Users/"
0
```

**승인 정의 직접 확인**: `grep -rnE "승인|확인을 받|묻는다|묻지 않|겸한다|매번" skills README.md CLAUDE.md | grep -v ^skills/harness/` 결과를 한 줄씩 읽었다. 남은 것은 (1) harness 참조 문장(commit:50, design:94, plan:14·153, check:10, release:11, init:13·49·76, README:36·72·79, CLAUDE.md:18·50·54), (2) 절차 안에서 "승인을 받는다/확인을 받고"처럼 harness가 정한 승인을 쓰는 단계(release:20·21·56·72·74·83, plan:155), (3) 사용자 질문 방법(init:12·34·43, design:55·83, plan:13·59·78), (4) guard 동작 설명(init:75 "훅은 `배포 아님`일 때만 일반 push를 묻지 않는다", README 훅 표), (5) 과거 기록(README 로드맵 130~132), (6) blog 발행 승인(blog:16·164 등, README:37·53). (6)은 blog 고유 절차이고 harness 의도 표에도 "발행은 글마다 승인"이 있다. check:9·81 "보고 먼저, 수정은 승인 뒤"는 harness "점검 요청"과 같은 내용을 check 절차가 실행 단계로 쓰는 것이다. 승인 여부를 harness와 다르게 또는 harness 없이 새로 정하는 문장은 찾지 못했다.

### 남은 위험

- 삭제 커밋을 따로 두는 순서가 실제 새 세션에서 지켜지는지(특히 커밋 하나짜리 작은 작업)는 재검증(C b+d 재실행)에서 확인해야 한다.
- harness 8의 `--all` 제한이 런타임에서 지켜지는지(C c-3 재실행)는 미검증.
- (6)·check:9를 "정의"로 볼지는 검증자 판단 여지가 있다. 그렇게 보면 blog K6·check 머리말도 참조로 줄여야 한다.
- deploy_gate의 임시 checkout 동작 설명은 지휘 세션이 전한 Coder A의 변경 내용을 따랐다. 이 worktree의 scripts/는 아직 그 변경 전일 수 있다.

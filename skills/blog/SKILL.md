---
name: blog
description: 대화나 TIL 메모를 기술 블로그 글로 쓴다. "블로그로 쓰자" 같은 요청에 쓴다. 글마다 전용 worktree, 승인 후 main 병합.
---

# blog: 대화·TIL 메모 → 블로그 글 (글마다 worktree, 승인 후 발행)

| 저장소 | 경로 | 공개 |
|---|---|---|
| 메모 (원료) | `~/Documents/dev/my-notes/til/` | 비공개 |
| 블로그 본체 | `~/Documents/dev/tech-blog` (GitHub `37writes/37writes.github.io`, Jekyll + Chirpy) | 공개 |

사용자에게 하는 질문과 보고는 모두 **한국어**로 한다.

블로그는 공개되고 애드센스 수익을 목표로 한다. **회사 정보 유출 방지**와 **독자에게 가치 있는 글**이 최우선이다.

## 흐름

글 하나 = tech-blog worktree 하나(브랜치 `post-<slug>`) = Orca 보드 카드 하나. 본체 main은 사용자가 승인한 글만 받는다.

| 단계 | 어디서 | 내용 |
|---|---|---|
| A | 출발 세션 (어느 프로젝트든) | 재료를 모아 브리프 작성, 시리즈면 편 구성 확인 |
| B | 출발 세션 | 글 worktree 생성, 브리프 전달, 에이전트 실행 후 **인계 끝** |
| C | 글 worktree | 2~5단계: 글 쓰기, 그림, 필터링, 확인. 브랜치에 커밋 |
| D | 글 worktree → 본체 | 사용자 **명시적 승인** 뒤에만: main에 병합, push, 정리 (6~8단계) |

사용자가 "이 내용 블로그로 쓰자"처럼 말로 시작해도 되고 /kit:blog로 불러도 된다. 지금 있는 곳이 글 worktree(`.blog-brief.md`가 있고 브랜치가 `post-*`)면 A·B는 건너뛰고 C부터 한다.

## A. 출발 세션: 재료 모으기

원료는 현재 대화 + 그 프로젝트의 결과 파일이다. 필요하면 지난 대화와 TIL 메모를 더한다.

- **현재 대화**: 최종 결정과 실제로 만든 파일을 기준으로 정리한다. 대화는 결론이 여러 번 바뀐다. 중간에 버린 안은 "처음엔 이렇게 했다가 바꿨다"처럼 이유가 있을 때만 쓴다.
- **결과 파일**: 그 프로젝트의 문서·설정을 읽어 대화와 맞춰 본다.
- **지난 대화** ("그 세션에서 한 작업을 글로"): 스크립트는 이 스킬의 base directory 기준 `../../scripts/session_text.py`.
  `python3 "<base directory>/../../scripts/session_text.py" <그 대화를 연 폴더> --list` → 대화 고르기
  `python3 "<base directory>/../../scripts/session_text.py" <폴더> --session <ID> > /tmp/session.txt` → 전체 텍스트 (길면 `--grep 키워드`)
  Orca worktree처럼 폴더 이름을 모르면 `ls ~/.claude/projects/ | grep <이름 일부>`로 찾는다.
- **TIL 메모**: 인자로 주제나 파일이 오면 그것을 쓴다. 없으면 `my-notes/til/`에서 `status: draft` 메모를 날짜순 표(제목, 날짜, category, tags)로 보여주고 AskUserQuestion으로 고르게 한다. 같은 주제의 메모 여러 개를 한 글로 묶는 것도 제안할 수 있다. (`git pull --ff-only`로 최신화)
- 대화에서 인용한 외부 글(공식 문서, 블로그)은 원문을 다시 열어 제목·날짜·수치를 확인한다.
- 내용이 많으면 **시리즈**로 나눈다 (2단계 "시리즈"). 편 구성(편별 제목과 다룰 내용)을 보여주고 AskUserQuestion으로 확인받는다. 편마다 글 worktree를 따로 만든다.

**브리프** (글 worktree의 에이전트는 이 대화를 볼 수 없으므로 이것만으로 쓸 수 있어야 한다. 글 하나당 하나):
- 주제와 독자, 제안 제목(시리즈면 시리즈 이름과 이 편의 번호·제목·다룰 내용·전체 편 목록)
- 핵심 사실과 **최종 결정**, 버린 안과 그 이유
- 읽을 원료 파일의 **절대 경로**, 대화 폴더·세션 ID (`session_text.py` 인자), TIL 메모 경로(있으면)
- 그 프로젝트 CLAUDE.md 프로필의 **구분**(회사/개인/대학원)과 **걸러야 할 회사 관련 항목**(회사·서비스·고객사·레포 이름, 도메인, 계정 ID 등 알고 있는 것을 구체적으로)
- 확인된 사용자 요구(어조, 넣을 것, 뺄 것)
- 메모가 원료인지 여부 (7단계용)

## B. 글 worktree 만들고 인계

`<main>` = 블로그 본체 `~/Documents/dev/tech-blog`(절대 경로로 풀어 쓴다), `<slug>` = 글의 영어 slug.

```sh
orca worktree create --repo path:<main> --name post-<slug> --no-parent --base-branch origin/main --setup skip --comment "<주제>" --json
orca worktree set --worktree id:<id> --display-name "[블로그] <제목>" --workspace-status in-progress
```
- `<id>`와 경로는 create의 JSON 출력에서 읽는다. 같은 이름이 이미 있으면 사용자에게 묻는다 (이어 쓰는 글일 수 있다).
- `--no-parent`: 출발 세션의 worktree와 부모-자식으로 묶지 않는다 (블로그 글은 독립 작업).
- 브리프를 `<worktree>/.blog-brief.md`에 쓰고, **커밋 없이** 무시되게 한다. 블로그 `.gitignore`는 건드리지 않는다:
  ```sh
  EX="$(git -C <worktree> rev-parse --git-common-dir)/info/exclude"
  grep -qx '.blog-brief.md' "$EX" || echo '.blog-brief.md' >> "$EX"
  ```
  (info/exclude는 본체와 모든 worktree가 공유하지만 커밋되지 않는다.)
- 에이전트 실행:
  ```sh
  orca agent launch --agent claude --worktree id:<id> --prompt "블로그 글 워크트리다. .blog-brief.md를 읽고 blog 스킬의 글 워크트리 절차(C)로 진행" --json
  ```
- 사용자에게 **카드 이름("[블로그] 제목")과 worktree 경로**를 알린다. 시리즈면 편마다. 출발 세션은 여기서 끝이다. 글 worktree를 지켜보거나 대신 쓰지 않는다 (인계).
- **Orca가 없으면**: `git -C <main> worktree add ~/orca/workspaces/tech-blog/post-<slug> -b post-<slug> origin/main` (또는 본체 옆 `../tech-blog-post-<slug>`)로 만들고, 브리프와 exclude는 같게 한 뒤, 사용자에게 "그 폴더에서 claude를 열어 '.blog-brief.md 읽고 blog 스킬 C 절차로 진행'이라고 하세요"라고 안내한다.

## C. 글 worktree: 쓰기부터 확인까지

브랜치 `post-<slug>`의 이 worktree에서 한다. 먼저 `.blog-brief.md`를 읽고, 적힌 원료 파일·세션을 직접 열어 확인한다. 브리프가 부족하면 지어내지 말고 사용자에게 묻는다. 그다음 2~5단계를 진행한다.

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

**커밋**: 글 파일과 그림(`_includes/figures/<slug>/`)만 브랜치에 커밋한다: `docs(post): <제목>` (시리즈 한 편이면 `docs(post): <시리즈 이름> N편 <제목>`). 도표 CSS를 바꿨으면 `feat(blog): ...`를 따로. `.blog-brief.md`와 `_site`는 커밋하지 않는다. **push도 main 병합도 아직 하지 않는다.**

## 2. 글 쓰기

메모는 "나를 위한 기록"이고 글은 "처음 보는 독자를 위한 설명"이다. 다시 쓴다.

- **제목**: 검색될 만한 구체적인 제목. 예) "ROS2 QoS: Reliable과 Best Effort, 언제 무엇을 쓸까"
- **구성**: 도입(어떤 문제를 겪었나, 왜 읽어야 하나) → 개념 → 예시 코드 → 주의할 점 → 정리
- **분량**: 핵심을 충분히 설명하되 장황하지 않게. 애드센스는 얇은 글을 싫어하므로, 메모 내용이 너무 적으면 보강할 점을 사용자에게 알린다.
- **정확성**: 메모에 "(확인 필요)"가 있으면 공식 문서 등으로 확인하거나, 확인할 수 없으면 그 문장을 빼거나 사용자에게 묻는다. 지어내지 않는다.
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
- 편마다 끝에 다음 편 예고 한 줄 (링크 없이). 뒤 편을 발행할 때 그 편에서 앞 편 링크를 걸고, 앞 편의 예고도 링크로 바꾸는 후속 커밋을 같은 worktree에서 한다.
- 편마다 worktree가 따로이므로 앞 편이 발행된 뒤(본체 main에 들어온 뒤)에 다음 편 worktree를 만들면 `post_url`을 쓸 수 있다. 동시에 쓰면 목록은 제목만 두고 발행 때 링크를 채운다.

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
이미 발행한 글에 그림만 넣을 때도 글 worktree를 만들어 이 단계부터 하고 5·6단계로 간다 (4단계 필터링은 그림 글자에 적용).
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

**검수**
1. 빌드(C절의 `BUNDLE_PATH`·ruby PATH 형태 그대로: jekyll build와 htmlproofer) 후 `_site`에서 `sh <scripts>/py.sh -m http.server 4100 --bind 127.0.0.1`로 띄워 그림이 있는 글을 캡처한다:
   `sh <scripts>/py.sh <scripts>/shot.py <url> /tmp/fig-light.png --theme light` (`--theme dark`, `--mobile`도). 긴 페이지는 `--height`를 늘리고 `sips -c <높이> <폭> --cropOffset <y> <x>`로 잘라서 Read로 본다. 글자 겹침·넘침, 선 연결을 확인한다.
2. 새 색 조합을 썼으면 `sh <scripts>/py.sh <scripts>/contrast.py`로 잰다 (상자 바탕 `--paper-deep` 기준도).
3. **다른 모델이 검수**한다. 내 결론은 주지 않고 글·SVG 경로·캡처만 준다. Codex가 있으면:
   `codex exec -s read-only --color never -i /tmp/fig-light.png -o /tmp/fig-review.md - < /tmp/fig-prompt.md` (블로그 폴더에서)
   prompt에 물을 것: 본문과 어긋나거나 본문에 없는 주장, 그림·캡션만 보고 핵심을 말할 수 있는가, 위치, title/desc·색·글자 크기, 선 방향. Codex가 없으면 새 서브에이전트에게 같은 내용으로 맡긴다.
4. 검수 결과를 반영하고 다시 캡처한다. 반영하지 않은 지적은 이유와 함께 5단계에서 보고한다.

## 4. 공개 전 필터링 (반드시)

브리프의 **구분**(메모가 원료면 메모의 `category`)에 따라 다르게 처리하고, **무엇을 바꿨는지 목록으로 보고한다.**

**회사**
- 회사명, 제품·서비스명, 고객사명, 내부 프로젝트·레포 이름 → 삭제하거나 "사내 서비스", "API 서버" 같은 일반 표현으로
- 내부 도메인, URL, IP, 서버·버킷 이름, AWS 계정·리소스 ID, 내부 API 경로 → 예시 값으로 (`example.com`, `my-bucket`)
- 회사 코드를 그대로 옮기지 않는다 → 개념을 보여주는 최소 예시 코드를 새로 쓴다
- 사업 정보 (매출, 일정, 미공개 기능, 장애 영향 범위) → 삭제
- 판단이 애매한 항목은 지우지 말고 사용자에게 묻는다

**대학원**
- 미발표 연구 내용, 실험 데이터, 지도교수·연구실 내부 정보, 과제 정답이 되는 코드 → 사용자에게 공개 가능 여부를 확인한다

**공통 (모든 글)**
- 비밀번호, API 키, 토큰, 개인 이메일·전화번호, 로컬 경로의 사용자 이름(`/Users/이름/`) → 반드시 제거
- 대화가 원료면 회사 작업이 섞여 있기 쉽다. 브리프에 적힌 구분과 걸러야 할 항목을 기준으로 위 규칙을 적용하고, 마지막에 글 파일 전체를 grep으로 점검한다 (회사·서비스·레포 이름, 계정 ID 12자리 `[0-9]{12}`, `AKIA`, `/Users/`, 이메일 `@`).

## 5. 확인

사용자에게 보여준다:
1. 제목, 카테고리, 태그, 설명, 브랜치와 worktree 경로
2. 글 전문 (길면 구성 요약 + 핵심 부분)
3. 필터링 보고: "바꾼 것" 목록. 회사·대학원이 아니어도 공통 항목 점검 결과를 한 줄로.
4. 그림: 캡처(밝은·어두운·모바일)와 검수에서 고친 점

수정 요청은 브랜치에 커밋으로 반영하고, **명시적인 발행 승인**을 받는다. 승인 전에는 본체 main에 아무것도 하지 않는다.

## 6. 발행 (D, 승인 뒤에만)

1. 본체 `<main>`이 `main` 브랜치이고 깨끗한지 확인한다 (`git -C <main> status -sb`). 아니면 멈추고 사용자에게 알린다. 그다음 `git -C <main> pull --ff-only`.
2. main이 앞서갔으면 글 worktree에서 `git fetch origin && git rebase origin/main`. 충돌이 나면 멈추고 보고한다. 병합 대상이 바뀌었으니 빌드를 다시 돌려 확인한다.
3. 본체에서 `git -C <main> merge --ff-only post-<slug>` (브랜치는 같은 저장소를 공유하므로 바로 보인다)
4. `git -C <main> push origin main` (위험 명령 확인 훅이 한 번 더 묻는다)
5. 배포 확인: **push한 커밋**의 실행을 본다 (`-L 1`은 이전 성공을 잡을 수 있다):
   ```sh
   SHA=$(git -C <main> rev-parse HEAD)
   gh run list -R 37writes/37writes.github.io --workflow pages-deploy.yml --branch main --commit $SHA --json databaseId,status,conclusion,url
   gh run watch <databaseId> -R 37writes/37writes.github.io --exit-status
   ```
   목록이 비어 있으면 몇 초 뒤 다시 본다. `conclusion`이 success일 때만 다음으로 간다 (보통 1분 안팎). 실패하면 `gh run view <databaseId> --log-failed`로 원인을 보고하고 멈춘다 (정리하지 않는다).
6. 글 주소를 알려준다 (시리즈면 편마다).

## 7. 메모 정리

원료가 TIL 메모일 때만 한다. 본체 main에서 `my-notes` 원본 메모의 front matter를 갱신한다:
```yaml
status: posted
posted_url: https://37writes.github.io/posts/<slug>/
```
my-notes에서 커밋 (`docs(til): <제목> 발행 표시`)하고, 원격이 있으면 push 여부를 묻는다. 답을 받은 뒤 8단계로 간다. 대화가 원료였으면 하지 않고, 남길 개념이 있으면 /kit:til을 제안한다.

## 8. worktree 정리 (맨 마지막)

배포 성공과 7단계(메모 정리)까지 **모두 끝낸 뒤**에 한다. `orca worktree rm`은 이 에이전트 세션도 끝내므로 rm이 마지막 명령이다. 그 전에 사용자에게 글 주소와 정리 사실, 브랜치가 남을 때의 안내를 보고한다.
```sh
orca worktree set --worktree id:<id> --workspace-status completed
orca worktree rm --worktree id:<id> --force --json     # worktree와 post-<slug> 브랜치 삭제
```
브랜치가 남으면(Orca가 병합을 증명하지 못한 경우) 사용자가 본체에서 `git -C <main> branch -d post-<slug>`로 지운다 (이미 병합돼 `-D`는 필요 없다). Orca가 없었으면 `git -C <main> worktree remove <경로>`.

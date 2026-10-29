---
name: init
description: 현재 폴더를 37writes kit 프로젝트로 초기화한다. git init, 프로젝트 프로필(CLAUDE.md), docs/devlog, 커밋 규칙 훅 설치.
disable-model-invocation: true
---

# init: 프로젝트 초기화

새 프로젝트를 시작할 때, 또는 기존 레포를 kit 방식으로 처음 관리할 때 한 번 실행한다.
이미 초기화된 레포에서 다시 실행하면 프로필 갱신 모드로 동작한다.

전체 원칙: **알아낼 수 있는 건 직접 알아내고, 사용자에게는 알아낼 수 없는 것만 묻는다.**
되돌리기 어려운 작업(원격 저장소 생성, push)은 반드시 확인을 받는다.

## 1. 현재 상태 파악

다음을 확인한다.
- git 레포인지 (`git rev-parse --show-toplevel`), 원격 저장소 (`git remote -v`)
- `CLAUDE.md`에 `<!-- 37writes-kit:profile:start -->` 블록이 있는지 → 있으면 **갱신 모드**: 현재 프로필을 보여주고 바꿀 항목만 묻는다
- 스택 자동 감지 (해당 파일 존재 여부로 판단, 여러 개면 모두 기록)

| 파일 | 스택 |
|---|---|
| `*.sln`, `*.csproj` | C# / .NET |
| `CMakeLists.txt`, `Makefile` + `*.cpp` | C++ |
| `package.xml` + (`CMakeLists.txt` 또는 `setup.py`) | ROS2 |
| `pyproject.toml`, `requirements.txt`, `setup.py` | Python |
| `Package.swift`, `*.xcodeproj` | Swift |
| `pom.xml`, `build.gradle*` | Java |
| `package.json` | Node / 웹 (프레임워크는 dependencies로 판단) |
| `amplify.yml`, `amplify/` | AWS Amplify 배포 |

빌드/테스트/실행 명령도 파일에서 추론한다 (`package.json`의 scripts, `Makefile` 타깃, `colcon build` 등).

## 2. git 저장소 준비 (git 레포가 아닐 때만)

1. `git init -b main`
2. 감지한 스택에 맞는 `.gitignore` 작성 (이미 있으면 건드리지 않음). `.env`, 비밀키, 빌드 산출물(`bin/`, `obj/`, `build/`, `install/`, `log/`, `node_modules/`, `__pycache__/` 등)은 반드시 포함.

## 3. 사용자에게 질문

AskUserQuestion으로 **한 번에** 묻는다. 감지 결과로 답할 수 있는 항목은 추천값으로 제시한다.

1. **구분**: 회사 / 대학원 / 개인
2. **배포 방식**: AWS Amplify (브랜치 push 시 자동) / 실행파일 전달 (exe 등) / 앱 스토어 / 아직 없음
3. **원격 저장소** (없을 때만): GitHub / CodeCommit / 나중에
4. 감지한 빌드·테스트 명령이 맞는지 (틀리면 Other로 입력)

## 4. 프로젝트 프로필 작성

`CLAUDE.md`에 아래 블록을 넣는다. 파일이 없으면 만들고, 있으면 **기존 내용은 그대로 두고** 블록만 추가하거나 블록 안만 교체한다.

```markdown
<!-- 37writes-kit:profile:start -->
## Project Profile (37writes-kit)

- **구분**: 회사 | 대학원 | 개인
- **설명**: 한 줄 설명
- **스택**: 예) Python 3.11, FastAPI
- **빌드**: `명령`
- **테스트**: `명령` (없으면 "없음")
- **실행**: `명령`
- **배포**: 예) AWS Amplify — main 브랜치 push 시 자동 배포
- **push**: 배포 아님 (승인한 커밋은 바로 push) | 배포 (main push 시 자동 배포, 따로 확인)
- **원격**: GitHub `owner/repo` | CodeCommit `repo-name`

### 작업 규칙
- 커밋: `type(scope): 한국어 요약` 형식 (commit-msg 훅이 검사). 커밋은 /kit:commit 절차를 따른다.
- 작업 로그: `docs/devlog/YYYY-MM.md`, 의미 있는 작업 단위가 끝나면 /kit:devlog 로 기록한다.
- 기획서: `docs/plans/`
- 배포, 삭제, 배포가 되는 push는 실행 전에 반드시 사용자 확인을 받는다. push가 배포가 아니면(위 push 줄) 사용자가 커밋을 요청하거나 승인할 때 push까지 승인한 것으로 보고 커밋 뒤 바로 push한다.
- 작업 등급: T0 바로 처리 / T1 기획서 + 독립 검증 / T2(배포·배포가 되는 push·권한·시크릿·데이터 삭제) 사용자 승인 + 미리보기 먼저. 절차는 /kit:harness.
<!-- 37writes-kit:profile:end -->
```

CLAUDE.md는 매 세션 통째로 읽히므로 프로필은 짧게 둔다. 자세한 절차는 스킬에 있다.
**push 줄**은 배포 방식 답으로 정한다: AWS Amplify(브랜치 push 시 자동)처럼 push가 곧 배포면 `배포 (...)`, 실행파일 전달·앱 스토어·아직 없음이면 `배포 아님 (승인한 커밋은 바로 push)`. 위험 명령 확인 훅이 이 줄을 보고 일반 push를 묻지 않는다 (`배포 아님`으로 시작할 때만).

갱신 모드에서 기존 프로필에 "작업 등급"이나 "push" 줄이 없으면 추가를 제안하고, 작업 규칙의 push 문장도 위 양식으로 바꾼다.

구분이 **회사**면 `/blog` 등으로 외부에 글을 쓸 때 회사 이름, 내부 코드, 주소, 고객 정보를 걸러야 한다는 점을 설명 줄에 덧붙인다.

## 5. 폴더와 훅

1. `docs/devlog/README.md`를 만든다 (이 폴더가 kit 프로젝트의 표시이므로 git에 반드시 포함되어야 한다):
   ```markdown
   # Devlog
   월별 작업 로그입니다 (`YYYY-MM.md`). 37writes-kit의 /kit:devlog 가 작성합니다.
   ```
2. `docs/plans/` 폴더 (비어 있으면 `.gitkeep`)
3. commit-msg 훅 설치. 이 스킬의 base directory 기준으로 `../../scripts/install_githook.py`를 실행한다:
   `python3 "<base directory>/../../scripts/install_githook.py" "<레포 루트>"` (python3가 없으면 python)
   - 결과 메시지를 그대로 사용자에게 전달한다. 기존 훅이 있어 건너뛴 경우 그 이유를 설명한다.
   - 이 스크립트는 레포를 kit 등록부(`~/.config/37writes-kit/repos.txt`)에도 등록한다. /kit:weekly가 이 목록으로 프로젝트를 찾는다.
   - 참고: git 훅은 clone으로 복사되지 않는다. 다른 컴퓨터에서는 kit 플러그인의 SessionStart 훅이 자동으로 설치한다.

## 6. 원격 저장소 (사용자가 선택한 경우만, 실행 전 확인)

- GitHub: `gh repo create <이름> --private --source . --remote origin` (공개 여부는 다시 확인)
- CodeCommit: `aws codecommit create-repository --repository-name <이름>` 후 `git remote add origin <clone-url-http>`. 사용할 AWS 프로필/리전을 먼저 확인한다.
- push는 하지 않는다. 사용자가 원할 때 따로 한다.

## 7. 첫 커밋

변경된 kit 관련 파일만 (`CLAUDE.md`, `.gitignore`, `docs/`) 스테이징해서 커밋한다:
`chore(kit): 37writes-kit 초기화`

기존 코드 변경 사항이 섞여 있으면 함께 커밋하지 않는다.

## 8. 마무리 보고

짧게 정리한다: 감지한 스택, 작성한 프로필 요약, 설치한 훅, 만든 폴더, 다음에 쓸 명령 (`/kit:devlog`, `/kit:commit`).

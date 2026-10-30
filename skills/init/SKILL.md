---
name: init
description: 프로젝트 프로필(CLAUDE.md)에 작업에 필요한 사실만 보완하고 커밋 규칙 훅을 설치한다. 새 폴더면 git init부터.
disable-model-invocation: true
---

# init: 프로필 보완

harness가 작업에 필요한 사실(빌드·테스트·배포·push)을 찾지 못했을 때 읽는 보완 절차다. 사용자가 `/kit:init`으로 직접 불러도 같다.
harness가 이 파일을 경로로 읽었으면 그 요청을 인자로 보고, 이 파일이 있는 폴더를 base directory로 쓴다.

전체 원칙: **이미 있는 문서를 먼저 읽고, 작업에 필요한데 없는 사실만 더한다. 기존 내용은 덮거나 다시 쓰지 않는다.** 알아낼 수 있는 건 직접 알아내고 사용자에게는 알아낼 수 없는 것만 묻는다.
작업 절차·등급·승인·검증·기록은 프로필에 쓰지 않는다 (harness 공통 규칙에 있다). 되돌리기 어려운 원격 저장소 생성은 반드시 확인을 받고, 이 절차 중에는 push하지 않는다.
사용자가 프로필을 원하지 않으면 만들지 않고 진행한다. 그때 push·배포는 묻는 쪽(push 줄·자동 배포 줄 없음과 같다)이다.

## 1. 먼저 읽기

- git 레포인지 (`git rev-parse --show-toplevel`), 원격 저장소 (`git remote -v`)
- `CLAUDE.md`, `AGENTS.md`, `README*`, 빌드 설정(아래 표의 파일, `package.json` scripts, `Makefile` 타깃 등)
- `CLAUDE.md`에 `<!-- 37writes-kit:profile:start -->` 블록이 있으면 그 안에서 **빠진 줄만** 찾는다
- 스택 자동 감지 (여러 개면 모두 기록)

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

README·AGENTS.md에 이미 적힌 사실(빌드 명령 등)은 그대로 옮겨 쓰고 묻지 않는다.

## 2. git 저장소 준비 (git 레포가 아닐 때만)

1. `git init -b main`
2. 감지한 스택에 맞는 `.gitignore` 작성 (이미 있으면 건드리지 않음). `.env`, 비밀키, 빌드 산출물(`bin/`, `obj/`, `build/`, `install/`, `log/`, `node_modules/`, `__pycache__/` 등)은 반드시 포함.

## 3. 질문 (모르는 것만)

AskUserQuestion으로 **한 번에** 묻는다. 감지 결과로 답할 수 있는 항목은 추천값으로 제시하고, 이미 알아낸 항목은 묻지 않는다.

1. **구분**: 회사 / 대학원 / 개인
2. **배포 방식**: AWS Amplify (브랜치 push 시 자동) / 실행파일 전달 (exe 등) / 앱 스토어 / 아직 없음
3. **원격 저장소** (없을 때만): GitHub / CodeCommit / 나중에
4. 감지한 빌드·테스트 명령이 맞는지 (틀리면 Other로 입력)
5. push가 곧 배포인 레포에서만: **자동 배포** 정책을 둘지 (기본은 두지 않음 = 배포마다 승인). 두면 검증 명령과 확인 명령을 함께 정한다 (4번 형식)

## 4. 프로필 블록

`CLAUDE.md`에 아래 블록을 넣는다. 파일이 있으면 **블록 밖은 그대로** 두고 블록을 추가하거나, 블록이 있으면 빠진 줄만 채운다.
`CLAUDE.md`가 없고 `AGENTS.md`만 있으면 `@AGENTS.md` 한 줄과 이 블록만 담은 `CLAUDE.md`를 만든다 (AGENTS.md 내용을 복사하지 않는다). 둘 다 없으면 블록만 담아 만든다.

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
- **push**: 배포 아님 (승인한 커밋은 바로 push) | 배포 (main push 시 자동 배포)
- **자동 배포**: 허용 · 대상 `origin/main` · 검증 `npm ci && npm test` · 제외 `infra/**`, `amplify/backend/**` · 확인 `sh scripts/check_deploy.sh {sha}`
- **원격**: GitHub `owner/repo` | CodeCommit `repo-name`
- **절차**: 커밋 형식 `type(scope): 한국어 요약`(commit-msg 훅). 작업 절차·승인·검증·기록은 /kit:harness
<!-- 37writes-kit:profile:end -->
```

- CLAUDE.md는 매 세션 통째로 읽히므로 사실만 짧게 둔다.
- **push 줄**은 배포 방식으로 정한다: push가 곧 배포(Amplify 브랜치 자동 배포 등)면 `배포 (...)`, 실행파일 전달·앱 스토어·아직 없음이면 `배포 아님 (...)`. 위험 명령 확인 훅은 `배포 아님`으로 시작할 때만 일반 push를 묻지 않는다.
- **자동 배포 줄**은 사용자가 원할 때만 넣는다 (없으면 배포는 매번 승인). `대상`(원격/브랜치), `검증`(셸 명령), `확인`(`{sha}`를 받아 그 SHA에 묶인 배포 실행 성공과 핵심 기능 결과를 확인하고 성공이면 exit 0인 명령)은 필수, `제외`(glob 목록)는 선택이다. 하나라도 없거나 형식이 틀리면 정책 없음으로 본다. 확인 명령이 HTTP 200만 보면 완료 증거가 되지 않으니 사용자와 핵심 기능 확인을 정한다. 정책을 처음 넣거나 바꾸는 push는 자동 배포 대상이 아니다 (harness 공통 규칙 "push와 배포").
- 구분이 **회사**면 외부에 글을 쓸 때 회사 이름, 내부 코드, 주소, 고객 정보를 걸러야 한다는 점을 설명 줄에 덧붙인다.
- 블록 안에 예전 "작업 규칙" 문장(작업 로그, 등급·push 정의 등)이 있으면 보여 주고, 사용자가 원하면 `절차` 한 줄로 바꾼다. 원하지 않으면 그대로 둔다 (harness 공통 규칙이 우선한다).

## 5. commit-msg 훅

```sh
sh "<base directory>/../../scripts/py.sh" "<base directory>/../../scripts/install_githook.py" "<레포 루트>"
```
- 결과 메시지를 그대로 전달한다. 기존 훅이나 `core.hooksPath`가 있어 건너뛴 경우 그 이유를 설명한다.
- git 훅은 clone으로 복사되지 않는다. 다른 컴퓨터에서는 kit의 SessionStart 훅이 프로필이 있는 레포에 자동으로 설치한다.

## 6. 원격 저장소 (사용자가 선택한 경우만, 실행 전 확인)

- GitHub: `gh repo create <이름> --private --source . --remote origin` (공개 여부는 다시 확인)
- CodeCommit: `aws codecommit create-repository --repository-name <이름>` 후 `git remote add origin <clone-url-http>`. 사용할 AWS 프로필/리전을 먼저 확인한다.
- push는 하지 않는다. 이후 push는 프로필 push 줄과 harness 공통 규칙을 따른다.

## 7. 커밋

이 절차에서 바꾼 파일만 (`CLAUDE.md`, 새로 만든 `.gitignore`) 스테이징해서 커밋한다: `chore(kit): 프로젝트 프로필 추가` (보완이면 `chore(kit): 프로젝트 프로필 보완`).
기존 코드 변경 사항이 섞여 있으면 함께 커밋하지 않는다. harness 작업 중에 불렸으면 그 작업의 승인 범위 안일 때만 커밋하고, 아니면 변경을 보여 주고 묻는다.

## 8. 보고

짧게: 감지한 스택, 더하거나 채운 프로필 줄(바꾸지 않은 기존 내용은 그대로라는 점), 설치한 훅, 남은 빈 항목. 직접 불렸으면 "이제 하고 싶은 일을 말로 요청하면 된다"고 한 줄 덧붙인다.

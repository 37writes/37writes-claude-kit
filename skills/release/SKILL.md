---
name: release
description: 프로필의 배포 방식(Amplify / 실행파일 전달 / 앱)에 맞춰 버전, 릴리즈 노트, 빌드, 배포와 SHA 기준 배포 확인까지 진행한다.
disable-model-invocation: true
---

# release: 배포

사용자에게 하는 질문과 보고는 모두 **한국어**로 한다.
harness가 이 파일을 경로로 읽었으면 그 요청을 인자로 보고, 이 파일이 있는 폴더를 base directory로 쓴다. 아래 `<scripts>` = `<base directory>/../../scripts`.
배포는 되돌리기 어렵다. 승인·자동 배포·완료 판정은 harness 공통 규칙("승인", "push와 배포", "완료 판정과 기록")을 따른다. 아래의 **"배포 승인"**, **"확인을 받고"**는 그 규칙이 정한 승인이다 (언제 계획 승인으로 충분한지, 태그 push·릴리즈 생성·파일 전달처럼 매번 확인하는 것도 거기).

**배포 push** (브랜치 push가 배포일 때, 모든 방식 공통):
- 자동 배포 정책이 있으면 정확히 이 순서로 한다 (`<SHA>`는 `git rev-parse HEAD`의 40자리 전체, 병합 등으로 바뀌면 1부터 다시):
  ```sh
  sh <scripts>/py.sh <scripts>/deploy_gate.py verify --sha <SHA>          # 그 SHA의 깨끗한 임시 checkout에서 검증 명령 실행·기록 (추적 파일을 바꾸면 실패)
  git push <원격> <SHA>:refs/heads/<브랜치>                                 # 정책 대상과 같은 원격·브랜치, 옵션 없이
  sh <scripts>/py.sh <scripts>/deploy_gate.py confirm --sha <SHA>         # 정책의 확인 명령, exit 0일 때만 배포 완료
  ```
  `verify`가 실패하면 push하지 않고 멈춘다. guard가 확인 창을 띄우면 정책 밖이라는 뜻이니 우회하지 않고 이유를 보고한 뒤 배포 승인을 받는다.
- 정책이 없으면 배포 승인 뒤 push한다.
- `confirm`이 실패하거나 시간 초과면 멈추고, 반영된 SHA·실행 id·롤백 방법을 보고한다. 자동으로 되돌리지 않는다.

## 1. 사전 점검 (모든 배포 방식 공통)

- `CLAUDE.md` 프로필의 **배포** 항목을 읽는다. 비어 있거나 "없음"이면 배포 방식을 묻고 프로필에 기록한다.
- 작업 트리가 깨끗한가 (`git status`). 커밋 안 된 변경이 있으면 멈추고 알린다.
- 배포할 브랜치가 맞는가, 원격보다 뒤처지지 않았는가 (`git fetch` 후 비교).
- 빌드와 테스트가 통과하는가: /kit:check 의 자동 검증 단계만 실행한다. 실패하면 멈춘다.

## 2. 버전과 릴리즈 노트

- 마지막 태그: `git describe --tags --abbrev=0` (없으면 첫 릴리즈, 기본 `v0.1.0`)
- 그 이후 커밋을 type별로 모아 다음 버전을 **제안**한다:
  `!` 또는 `BREAKING CHANGE` → major, `feat` → minor, 그 외 → patch. 사용자가 최종 결정한다.
- 릴리즈 노트 (한국어, 사용자 관점으로 다시 쓴다. 커밋 메시지를 그대로 나열하지 않는다):
  ```markdown
  ## v1.2.0 (2026-10-14)

  ### 새 기능
  - ...
  ### 수정
  - ...
  ### 기타
  - ...
  ```
- `CHANGELOG.md` 맨 위에 추가한다 (없으면 만든다).
- 버전이 코드에 있으면 함께 올린다: `*.csproj`의 `<Version>`, `package.json`, `pyproject.toml`, `Info.plist`/Xcode 설정, `package.xml` 등.
- 커밋: `chore(release): vX.Y.Z` → 태그: `git tag -a vX.Y.Z -m "vX.Y.Z"`

## 3. 배포 방식별

### A. AWS Amplify (브랜치 push = 배포)
1. 프로필에 Amplify **앱 ID**, **배포 브랜치**가 없으면 확인해서 기록한다:
   `aws amplify list-apps --query "apps[].[name,appId,defaultDomain]" --output table` (프로필의 AWS 프로필/리전 사용)
2. 배포 승인 뒤 위 "배포 push"대로 push한다. 태그는 따로 확인을 받고 `git push <원격> vX.Y.Z`.
3. 빌드 확인은 **push한 SHA에 묶인 job**으로 한다 (`--max-items 1`의 최근 job은 이전 커밋일 수 있다):
   `aws amplify list-jobs --app-id <앱ID> --branch-name <브랜치> --query "jobSummaries[?commitId=='<SHA>']"`
   그 job의 상태가 `SUCCEED`/`FAILED`가 될 때까지 30초 간격으로 확인한다 (보통 수 분). 자동 배포 정책의 `확인` 명령도 이 형태로 쓴다.
4. 실패하면 `aws amplify get-job ...`의 로그 URL을 알려주고 원인을 같이 본다.
5. 성공하면 배포 주소에서 **핵심 기능 결과**를 확인한다 (계획의 완료 조건, 예: 로그인 뒤 보고서 1건 생성). HTTP 200만으로 완료라고 하지 않는다. 사용자만 할 수 있는 확인은 기획서 `## 남은 일`로.

### B. 실행파일 전달 (C# exe 등)
1. 빌드 (프로젝트에 맞게, 처음이면 옵션을 사용자와 정해 프로필에 기록):
   `dotnet publish <프로젝트> -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -o release/vX.Y.Z/app`
   - WinForms/WPF 앱은 Windows에서 빌드하는 것이 안전하다. macOS에서 실행 중이면 알린다.
2. 전달 묶음을 만든다: `release/<앱이름>-vX.Y.Z-win-x64.zip`
   - 안에 실행파일, 필요한 설정 파일, `릴리즈노트.txt` (2단계 노트를 텍스트로)
   - 개발용 설정, 비밀값, 디버그 파일(`*.pdb`)은 넣지 않는다
3. SHA-256 체크섬을 함께 남긴다 (`shasum -a 256` / PowerShell `Get-FileHash`).
4. `release/`는 `.gitignore`에 있어야 한다 (없으면 추가).
5. 원격이 GitHub이고 사용자가 원하면 확인을 받고 `gh release create vX.Y.Z <zip> --notes-file <노트>`.
   회사 프로젝트는 전달 경로(메일, 사내 공유 폴더 등)를 사용자에게 맡기고, 전달할 파일과 안내 문구만 준비한다.
6. 확인을 받고 `git push origin <브랜치> --follow-tags` (태그 push 확인은 harness "push와 배포").

### C. 앱 (iOS / Android)
아직 첫 배포 전이다. 처음 진행할 때 사용자와 함께 절차를 확정하고 이 섹션을 갱신한다.
- 기본 방향: iOS는 TestFlight 내부 테스트부터, Android는 Play Console 내부 테스트 트랙부터
- 버전 번호(사용자에게 보이는 버전)와 빌드 번호(매번 증가)를 구분해서 올린다
- 서명 인증서, 키스토어, 비밀번호는 절대 저장소에 넣지 않는다

### D. 그 외 (라이브러리, ROS2 패키지, 배포 없음)
태그와 릴리즈 노트까지만 하고, 확인을 받고 `git push origin <브랜치> --follow-tags`.

## 4. 마무리

- 진행 중이던 기획서가 이번 릴리즈로 끝났다면 결과(버전, 배포한 SHA, 확인 결과)와 `status: done`을 적어 커밋한 뒤, harness 공통 규칙 "완료 판정과 기록"대로 삭제 커밋으로 지운다. 기록은 릴리즈 노트·CHANGELOG·커밋이다.
- 최종 보고: 버전, 배포한 SHA, 배포 결과(주소나 파일 경로, 확인한 핵심 기능), 체크섬, 남은 할 일

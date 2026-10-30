---
name: check
description: 변경 사항을 프로젝트의 빌드·테스트로 검증하고 언어별 체크리스트로 리뷰한다. 머지·배포 전이나 "점검해줘"라고 할 때 사용.
---

# check: 빌드·테스트 + 언어별 리뷰

사용자에게 하는 질문과 보고는 모두 **한국어**로 한다.
**먼저 보고하고, 고치는 건 승인받은 뒤에** 한다. 점검 단계에서는 코드를 수정하지 않는다.
harness 검증 단계(5)로 쓸 때는 결과를 지휘 세션에 보고한다. 범위 안 결함의 수정은 harness 공통 규칙 "승인"을 따른다.

## 1. 범위 정하기

- 인자가 없으면: 커밋 안 된 변경 + 현재 브랜치에서 기본 브랜치(main/master) 이후의 커밋
  (`git diff`, `git diff --staged`, `git log <base>..HEAD`, `git diff <base>...HEAD`)
- 인자가 경로면 그 경로 전체, `all`이면 레포 전체 (큰 레포면 핵심 모듈 위주로 하고 범위를 알린다)
- 진행 중인 기획서(`docs/plans/`에서 `status: in-progress`)가 있으면 함께 읽는다

## 2. 자동 검증 (프로필 명령 기준)

`CLAUDE.md` 프로필의 **빌드**, **테스트** 명령을 실행한다. 명령이 "미정/없음"이면 아래 표로 추론하되, 실행 전에 어떤 명령을 쓸지 알린다.
**도구를 새로 설치하지 않는다.** 프로젝트에 이미 설정된 도구만 쓴다.

| 스택 | 빌드 | 테스트 | 정적 검사 (설정돼 있을 때만) |
|---|---|---|---|
| C# | `dotnet build` | `dotnet test` | 빌드 경고 |
| C++ | `cmake --build build` | `ctest --test-dir build` | clang-tidy |
| ROS2 | `colcon build --packages-select <pkg>` | `colcon test` + `colcon test-result --verbose` | ament_lint |
| Python | - | `pytest` 또는 `python -m unittest` | ruff, mypy |
| Swift | `swift build` / `xcodebuild` | `swift test` | swiftlint |
| Java | `./gradlew build` / `mvn -q compile` | `./gradlew test` / `mvn test` | - |
| Web | `npm run build` | `npm test` | `npm run lint`, `tsc --noEmit` |

- 오래 걸리는 명령은 타임아웃을 넉넉히 주고, 실패하면 핵심 오류 줄만 추려서 보고한다.
- 테스트가 없으면 "테스트 없음"이라고 분명히 적고, 변경을 확인할 수동 절차를 제안한다.

## 3. 리뷰

변경된 코드를 직접 읽고 아래를 본다. **추측성 지적은 하지 않는다.** 문제라고 판단하면 실제 코드 흐름(호출부, 입력값)을 따라가 확인한 것만 보고한다.

**공통**
- 정확성: 경계값, 빈 값/null, 오류 처리 누락, 예외 삼킴, 잘못된 조건
- 기획서와 일치하는가 (범위, 완료 기준)
- 보안: 비밀값 하드코딩, 로그에 민감정보, 입력 검증 누락, SQL/명령 주입, 안전하지 않은 역직렬화
- 리소스: 파일·소켓·DB 연결 해제, 무한 대기, 타임아웃 없음

**언어별**

| 스택 | 특히 볼 것 |
|---|---|
| C# | `IDisposable`을 `using` 없이 사용, `async void`, `.Result`/`.Wait()` 교착, null 참조, UI 스레드 밖에서 UI 접근 |
| C++ | 소유권과 수명 (dangling 참조/포인터), RAII 미사용, 미정의 동작, 정수 오버플로, 스레드 경합 |
| ROS2 | 퍼블리셔/구독자 QoS 불일치, 콜백 안의 긴 블로킹 작업, 파라미터 선언 누락, 타이머·executor 설정, 메시지 단위(미터/라디안) |
| Python | 가변 기본 인자, bare `except`, 경로·인코딩 하드코딩 (윈도우 호환), 리소스 `with` 미사용 |
| Swift | 강제 언래핑(`!`), 클로저의 강한 참조 순환(`[weak self]`), 메인 스레드 밖 UI 갱신 |
| Java | 리소스 미해제(try-with-resources), `equals`/`hashCode` 불일치, NPE 가능성 |
| Web | XSS(사용자 입력 그대로 렌더링), 비밀값이 클라이언트 번들에 포함, CORS 설정, 인증 토큰 저장 위치 |
| AWS | IAM `*` 권한, 공개 S3, Amplify 환경변수에 비밀값, 리전 하드코딩 |

## 4. 보고

```text
## 점검 결과: <범위>

자동 검증: 빌드 ✅ / 테스트 ✅ 12개 통과 / 정적 검사 ⚠️ 경고 2개

🔴 반드시 고칠 것
1. path/file.py:42 — 무엇이 문제인지 → 어떤 상황에서 어떻게 깨지는지 → 제안

🟡 고치면 좋은 것
2. ...

🟢 사소한 것 (선택)
3. ...

독립 시나리오 (harness 검증일 때)
1. <시나리오> — 선택 이유 / 재현 명령 / 실제 결과 / 미검증
```

- 문제가 없으면 "발견된 문제 없음"과 무엇을 확인했는지만 짧게.
- 번호로 고를 수 있게 하고, **어떤 것을 고칠지 묻는다** (따로 요청한 점검일 때). 승인된 것만 고치고, 고친 뒤 테스트를 다시 돌린다.
- 수정 커밋은 /kit:commit 규칙을 따른다 (보통 `fix(...)`).

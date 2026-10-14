---
name: weekly
description: 이 컴퓨터의 모든 kit 프로젝트 devlog와 커밋, TIL, 블로그 글을 기간별로 모아 주간 정리를 만든다.
disable-model-invocation: true
---

# weekly: 주간 정리

사용자에게 하는 질문과 보고는 모두 **한국어**로 한다.

## 1. 기간

- 기본: 오늘을 포함한 최근 7일
- 인자: `이번 주`(월요일~오늘), `지난 주`(지난 월~일), `2026-10`(그 달), `2026-10-01~2026-10-14`
- 인자에 `회사`/`대학원`/`개인`이 있으면 그 구분의 프로젝트만 (예: `/kit:weekly 지난 주 회사`)

## 2. 수집

1. devlog와 커밋: 이 스킬의 base directory 기준 `../../scripts/collect_devlog.py`를 실행한다.
   `python3 "<base directory>/../../scripts/collect_devlog.py" --since YYYY-MM-DD --until YYYY-MM-DD`
   - 레포 목록은 등록부(`~/.config/37writes-kit/repos.txt`)에서 온다. kit 레포에서 세션을 시작하면 자동 등록된다.
   - 커밋 수가 "user.email 미설정"으로 나온 레포는 내 커밋을 가릴 수 없어 집계하지 않은 것이다. 정리에 그렇게 표시한다.
   - 등록부가 비어 있거나 빠진 프로젝트가 있다고 하면 `--root <폴더>`로 추가 탐색한다.
   - 다른 컴퓨터에서 한 작업은 그 레포를 `git pull` 해야 보인다. 수집 전에 각 레포의 원격 상태를 확인하고 (`git fetch` 후 `git status -sb`), 뒤처진 레포가 있으면 pull할지 묻는다.
2. TIL: `~/Documents/dev/my-notes/til/`에서 기간 안에 만든 메모 (front matter의 date)
3. 블로그: `~/Documents/dev/tech-blog/_posts/`에서 기간 안에 발행한 글

## 3. 정리 문서

파일: `~/Documents/dev/my-notes/weekly/YYYY-Www.md` (ISO 주차, 예 `2026-W42.md`). 월 단위면 `YYYY-MM.md`.

```markdown
---
period: 2026-10-08 ~ 2026-10-14
---

# 2026-W42 주간 정리

## 한 줄 요약
이번 주의 핵심을 한두 문장으로.

## 프로젝트별
### sola-api (회사)
- 한 일: devlog의 요약과 한 일을 묶어서 (항목 나열이 아니라 흐름으로)
- 주요 결정: devlog의 "결정 & 이유"에서
- 커밋: feat 3, fix 2, docs 1

### 대학원 과제 (대학원)
...

## 배운 것
- TIL 제목 목록 (블로그 발행 여부 표시)

## 블로그
- 발행한 글 제목과 주소

## 숫자로 보기
| 프로젝트 | 구분 | 작업일 | 커밋 | 환경 |
|---|---|---|---|---|
| sola-api | 회사 | 4일 | 6 | macOS, Windows |

## 다음 주 할 일
각 프로젝트 devlog에서 체크되지 않은 "다음 할 일"을 프로젝트별로 모은다. 이미 끝난 것으로 보이는 항목은 제외한다.

## 돌아보기
- 잘된 점 / 막혔던 점을 데이터에 근거해 1~2개씩 (예: "ROS2 빌드 문제로 이틀 소요")
- 다음 주에 시도할 것 1개
```

규칙:
- devlog에 없는 내용을 지어내지 않는다. 기록이 적은 프로젝트는 짧게 쓴다.
- 기록이 없는 날이 많으면 "devlog 기록이 적음"을 알려 기록 습관을 상기시킨다.

## 4. 확인과 저장

1. 정리 내용을 보여주고, 수정 요청을 반영한다.
2. my-notes에 저장하고 커밋한다: `docs(weekly): 2026-W42 주간 정리`. 원격 push는 묻고 한다.
3. 회사 보고용이 필요하다고 하면, 회사 프로젝트만 골라 공식 문체로 다시 정리한다 (문서 양식은 추후 /kit:docs에서).

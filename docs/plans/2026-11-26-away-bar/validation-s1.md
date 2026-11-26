검증 모델: `global.openai.gpt-6.2-astra` (Codex 세션의 `turn_context.model`)

# S1 독립 검증: 완료 보류

기존 테스트는 **358건 통과, 0건 실패**다. 커밋 메시지에 들어 있는 배포 용어의 오탐은 사라졌지만, 기획서에서 명시한 파일·디렉터리 이름에서도 여전히 확인을 요청한다. 실행되는 위험 명령에 대한 새 미탐이 없다고 판정할 근거는 없다.

## 재실행 및 변경 범위

브랜치 `37writes/away-mode`, base `20ee4399`, HEAD `a2c5957a`. 깨끗한 작업 트리에서 아래 스크립트를 각각 `sh scripts/<파일>`로 실행했다. 각 스크립트의 `ok`·`FAIL` 행을 세고 종료 코드도 별도로 확인했다.

| 파일 | 통과 | 실패 | 종료 코드 |
|---|---:|---:|---:|
| `test_guard.sh` | 148 | 0 | 0 |
| `test_away.sh` | 103 | 0 | 0 |
| `test_deploy_gate.sh` | 56 | 0 | 0 |
| `test_plans.sh` | 32 | 0 | 0 |
| `test_profile_check.sh` | 19 | 0 | 0 |

Git 전송 프로토콜은 `file`로 제한했다. 배포 게이트 테스트의 push는 테스트가 만든 로컬 bare 저장소 안에서만 일어났다. `git diff --stat HEAD^...HEAD`의 변경 파일은 `scripts/guard.py`, `scripts/test_guard.sh`, `docs/plans/2026-11-26-away-bar.md`뿐이다.

## 두 버전의 실제 판정

각 입력은 실행하지 않고 두 버전의 `guard.py`에 stdin JSON으로 전달했다. 모든 행에서 종료 코드는 0이다. `none`은 표준 출력이 비었다는 뜻이다.

| 입력 (`tool_input.command`) | base | HEAD | 분류 |
|---|---|---|---|
| `git commit -m "document terraform apply"` | ask | none | 오탐 해소. 문구는 커밋 메시지다. |
| `mkdir -p "terraform apply"` | ask | ask | 기존 오탐. 문구는 디렉터리 이름이다. |
| `touch "terraform apply.md"` | ask | ask | 기존 오탐. 문구는 문서 파일명이다. |
| `tee "terraform apply.log"` | ask | ask | 기존 오탐. 문구는 출력 파일명이다. |
| `find docs -name "terraform apply.md"` | ask | ask | 기존 오탐. `-name`의 인자는 검색 패턴이다. |
| `python3 -c "print('terraform apply')"` | ask | ask | 기존 오탐. 문자열만 출력한다. |

앞의 세 파일명 사례는 S1이 명시한 범위다. `scripts/guard.py:348`의 데이터 명령 목록에는 `mkdir`, `touch`, `tee`가 없고 `tee`는 파이프 필터 목록에만 있다. 파일명 위치를 구분하는 회귀 테스트를 권한다. `find`와 `python3` 사례는 기획 범위 밖의 잔여 오탐이다. 둘은 다른 인자에서 코드를 실행할 수 있으므로 명령 전체를 예외 처리해서는 안 된다.

재현 예시(레포 루트에서 실행, 마지막 인자를 표의 문자열로 바꿔 사용):

```sh
tmp=$(mktemp -d)
for rev in HEAD^ HEAD; do
  mkdir -p "$tmp/$rev" "$tmp/home"
  for f in guard.py kitlib.py deploy_gate.py away.py; do
    git show "$rev:scripts/$f" > "$tmp/$rev/$f" || exit 1
  done
done
probe() {
  python3 -c 'import json,sys; print(json.dumps({"cwd":"/tmp","tool_input":{"command":sys.argv[1]}}))' "$2" |
    env HOME="$tmp/home" PYTHONDONTWRITEBYTECODE=1 python3 "$tmp/$1/guard.py"
}
for rev in HEAD^ HEAD; do probe "$rev" 'touch "terraform apply.md"'; done
```

## 해석 오류·지연 및 미검증 범위

독립 입력에서 두 버전 모두 예외 종료나 15초 초과는 관찰되지 않았다. 다음은 실제 전달한 입력을 Python 문자열 표현으로 나타낸 것이다. 모두 `none → none`이었다. 별도 Python 프로세스에서 매 호출에 `timeout=15`를 적용했다.

```python
[
    "printf %s sample", "printf %s " + "x" * 65536, "printf x\n" * 1000,
    'echo "sample', "cat <<-NOTE\n\tsample\n\tNOTE", "cat <<A <<B\none\nA\ntwo\nB",
    "printf sample | cat | wc -c", 'printf %s "$(printf %s sample)"',
    "cat <(printf sample)", "printf a & printf b; printf c",
    "f() { printf sample; }; f", "case sample in sample) printf ok;; esac",
    "printf sam\\\nple",
]
```

64 KiB 인자에서 base 0.175초·HEAD 0.076초, 1,000줄에서 각각 0.056초·0.062초였다(인터프리터 기동 포함, 각 1회). 이 측정은 입력 크기 전반에 대한 시간 상한을 보장하지 않는다.

**새 미탐은 미판정이다.** 실제 위험 명령이 확인 훅을 우회하는 입력의 제작·재현은 수행하지 않았다. 정적 검토에서 `data_command`와 `safe_consumer`가 주로 명령 이름으로 인자와 파이프 입력의 실행 여부를 추정한다는 점을 확인했다. 이름만으로 데이터라고 확정할 수 없는 옵션은 보수적으로 판정하고, 인자와 본문이 실행 위치에서도 검사되는지는 테스트 전용 무해한 표식 규칙으로 확인할 것을 권한다.

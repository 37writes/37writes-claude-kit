#!/bin/sh
# 맥/리눅스/윈도우(Git Bash) 공통 Python 실행기.
# 윈도우의 python3 스토어 스텁처럼 실제로는 동작하지 않는 명령은 건너뛴다.
for c in python3 python py; do
  if command -v "$c" >/dev/null 2>&1 && "$c" -c "import sys" >/dev/null 2>&1; then
    exec "$c" "$@"
  fi
done
echo "37writes-kit: python을 찾을 수 없어 훅을 건너뜁니다" >&2
exit 0

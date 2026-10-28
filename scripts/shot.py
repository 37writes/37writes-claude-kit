"""설치된 Chrome/Edge/Chromium의 headless 모드로 화면을 캡처한다. /kit:design이 전/후를 비교할 때 사용.

사용:
  shot.py <url> <저장할 png> [--mobile] [--theme light|dark] [--width 1280] [--height 1000]
  - --mobile: 390px 폭. headless 창은 약 500px보다 좁아지지 않으므로 390px iframe 안에 띄워 찍는다
    (X-Frame-Options·CSP frame-ancestors로 iframe을 막는 사이트는 빈 화면이 찍힌다 → 로컬 빌드로 찍는다)
  - --theme: prefers-color-scheme를 정해 찍는다. 안 주면 이 컴퓨터의 시스템 설정을 따른다
    (사이트가 저장한 모드 선택은 headless 새 프로필이라 영향이 없다)
  - 웹폰트가 늦게 뜨는 페이지를 위해 가상 시간 5초를 기다린 뒤 찍는다
"""
import argparse
import html
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile

import kitlib  # noqa: F401  (윈도우 콘솔 utf-8 출력 설정)

CANDIDATES = [
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
    "/Applications/Chromium.app/Contents/MacOS/Chromium",
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
    os.path.join(os.environ.get("LOCALAPPDATA", ""), "Google", "Chrome", "Application", "chrome.exe"),
]
NAMES = ["google-chrome", "google-chrome-stable", "chromium", "chromium-browser", "chrome",
         "microsoft-edge", "microsoft-edge-stable", "msedge"]


def find_browser():
    for path in CANDIDATES:
        if os.path.exists(path):
            return path
    for name in NAMES:
        path = shutil.which(name)
        if path:
            return path
    return None


def main():
    p = argparse.ArgumentParser()
    p.add_argument("url")
    p.add_argument("out")
    p.add_argument("--mobile", action="store_true")
    p.add_argument("--theme", choices=["light", "dark"])
    p.add_argument("--width", type=int, default=1280)
    p.add_argument("--height", type=int, default=1000)
    a = p.parse_args()

    browser = find_browser()
    if not browser:
        print("Chrome, Edge, Chromium을 찾지 못했습니다.")
        return 2

    target, width = a.url, a.width
    frame = None
    if a.mobile:
        width = 390
        fd, frame = tempfile.mkstemp(suffix=".html")
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(f'<body style="margin:0"><iframe src="{html.escape(a.url, quote=True)}" width="390" '
                    f'height="{a.height}" style="border:0;display:block"></iframe></body>')
        target = pathlib.Path(frame).as_uri()

    extra = []
    if a.theme:
        extra.append(f"--blink-settings=preferredColorScheme={0 if a.theme == 'dark' else 1}")

    out = os.path.abspath(a.out)
    if os.path.exists(out):
        os.remove(out)  # 예전 캡처가 남아 있으면 실패해도 성공으로 보이므로
    try:
        result = subprocess.run(
            [browser, "--headless=new", "--disable-gpu", "--hide-scrollbars",
             "--virtual-time-budget=5000", f"--window-size={width},{a.height}",
             f"--screenshot={out}", *extra, target],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=60,
        )
    except subprocess.TimeoutExpired:
        print("캡처 시간이 초과됐습니다 (60초).")
        return 1
    finally:
        if frame:
            os.remove(frame)

    if result.returncode != 0 or not os.path.exists(out):
        print(f"캡처하지 못했습니다 (브라우저 종료 코드 {result.returncode}).")
        return 1
    print(out)
    return 0


if __name__ == "__main__":
    sys.exit(main())

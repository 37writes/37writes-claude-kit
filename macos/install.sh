#!/bin/sh
# AwayBar 빌드·설치: sh macos/install.sh  →  ~/Applications/AwayBar.app
# 배포용이 아니다 (공증·Developer ID 없음). 이 Mac에서 빌드해 이 Mac에서 쓴다.
set -eu
cd "$(dirname "$0")"
APP="${AWAYBAR_APP:-$HOME/Applications/AwayBar.app}"
VERSION=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' ../.claude-plugin/plugin.json | head -1)

swift build -c release
BIN="$(swift build -c release --show-bin-path)/AwayBar"

STAGE=$(mktemp -d); trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/AwayBar.app/Contents/MacOS"
cp "$BIN" "$STAGE/AwayBar.app/Contents/MacOS/AwayBar"
# away.py 사본을 앱 안에 넣는다: macOS가 앱의 ~/Documents 읽기를 막으면 kit 폴더를 못 찾는다 (읽을 수 있으면 kit 폴더가 우선)
mkdir -p "$STAGE/AwayBar.app/Contents/Resources/kit/scripts"
cp ../scripts/away.py ../scripts/kitlib.py "$STAGE/AwayBar.app/Contents/Resources/kit/scripts/"
cat > "$STAGE/AwayBar.app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>com.37writes.awaybar</string>
  <key>CFBundleName</key><string>AwayBar</string>
  <key>CFBundleDisplayName</key><string>자리 비움</string>
  <key>CFBundleExecutable</key><string>AwayBar</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION:-0.0.0}</string>
  <key>CFBundleVersion</key><string>${VERSION:-0.0.0}</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

# 서명: Apple Development 인증서가 있으면 그것으로, 없으면 ad-hoc
IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\(Apple Development: [^"]*\)".*/\1/p' | head -1)
codesign --force --sign "${IDENTITY:--}" "$STAGE/AwayBar.app"

# 실행 중이면 끝내고 바꾼다 (자리 비움 모드 자체는 away.py 상태라 앱을 꺼도 그대로다)
# 바꿀 그 번들에서 뜬 것만 끝낸다 (다른 경로에 시험 설치할 때 쓰던 앱을 닫지 않게)
for pid in $(pgrep -x AwayBar 2>/dev/null); do
  [ "$(ps -p "$pid" -o comm= 2>/dev/null)" = "$APP/Contents/MacOS/AwayBar" ] && kill "$pid" 2>/dev/null
done
mkdir -p "$(dirname "$APP")"
rm -rf "$APP"
cp -R "$STAGE/AwayBar.app" "$APP"
echo "설치: $APP (서명: ${IDENTITY:-ad-hoc})"
echo "실행: open \"$APP\""

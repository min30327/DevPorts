#!/bin/bash
# DevPorts.app をビルドする
#
#   ./build.sh            → build/DevPorts.app を作成（この Mac のアーキテクチャのみ）
#   ./build.sh --install  → 上記に加えて ~/Applications にコピーして起動
#   ./build.sh --dist     → Apple Silicon / Intel 両対応でビルドし、build/DevPorts-<version>.zip を作成
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="DevPorts"
BUNDLE_ID="io.github.min30327.DevPorts"
VERSION="$(cat VERSION)"
BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
APP="build/${APP_NAME}.app"
MODE="${1:-}"

if [[ "$MODE" == "--dist" ]]; then
    ARCH_ARGS=(--arch arm64 --arch x86_64)
else
    ARCH_ARGS=()
fi

swift build -c release "${ARCH_ARGS[@]+"${ARCH_ARGS[@]}"}"
BIN="$(swift build -c release "${ARCH_ARGS[@]+"${ARCH_ARGS[@]}"}" --show-bin-path)/${APP_NAME}"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/${APP_NAME}"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key><string>${APP_NAME}</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP" >/dev/null
echo "Built: $APP ($(lipo -archs "$APP/Contents/MacOS/${APP_NAME}"))"

case "$MODE" in
--install)
    DEST="$HOME/Applications"
    mkdir -p "$DEST"
    pkill -x "$APP_NAME" 2>/dev/null || true
    rm -rf "$DEST/${APP_NAME}.app"
    cp -R "$APP" "$DEST/"
    open "$DEST/${APP_NAME}.app"
    echo "Installed: $DEST/${APP_NAME}.app"
    ;;
--dist)
    ZIP="build/${APP_NAME}-${VERSION}.zip"
    rm -f "$ZIP"
    ditto -c -k --keepParent "$APP" "$ZIP"
    echo "Packaged: $ZIP"
    ;;
esac

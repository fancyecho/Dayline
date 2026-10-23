#!/bin/bash
# 构建 build/Dayline.app（release、去符号、本地 ad-hoc 签名）。
# UNIVERSAL=1 scripts/build-app.sh 可同时构建 Apple 芯片和 Intel 版本。
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "${UNIVERSAL:-0}" == "1" ]]; then
    ARCH_FLAGS=(--arch arm64 --arch x86_64)
else
    ARCH_FLAGS=()
fi

swift build -c release ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}
BIN_DIR="$(swift build -c release ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)"

APP="build/Dayline.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Dayline" "$APP/Contents/MacOS/Dayline"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
strip -x "$APP/Contents/MacOS/Dayline"
codesign --force --sign - "$APP"

echo "已生成 $APP"

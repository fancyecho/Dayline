#!/bin/bash
# 打包发布版：运行测试 → 构建通用版 App → 压缩 → 用更新私钥签名。
#
#   scripts/release.sh                         只在 build/ 里生成 Dayline.zip 和 Dayline.zip.sig
#   scripts/release.sh --publish NOTES.md      再用 gh 创建 GitHub Release，NOTES.md 是更新说明
#
# 版本号取自 Resources/Info.plist 的 CFBundleShortVersionString，标签为 v<版本号>。
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)"
TAG="v$VERSION"

# App 内置的公钥必须和本机私钥配对，否则发出去的更新谁都装不上。
EMBEDDED_KEY="$(sed -n 's/.*publicKey = "\(.*\)".*/\1/p' Sources/Dayline/Updater.swift)"
SIGNING_KEY="$(swift scripts/sign-update.swift public-key)"
if [[ "$EMBEDDED_KEY" != "$SIGNING_KEY" ]]; then
    echo "Updater.swift 里的公钥与本机私钥不匹配，停止发布。" >&2
    exit 1
fi

swift test
UNIVERSAL=1 scripts/build-app.sh

rm -f build/Dayline.zip build/Dayline.zip.sig
ditto -c -k --keepParent build/Dayline.app build/Dayline.zip
swift scripts/sign-update.swift sign build/Dayline.zip > build/Dayline.zip.sig
echo "已生成 build/Dayline.zip（$TAG）和签名"

if [[ "${1:-}" == "--publish" ]]; then
    NOTES="${2:?用法：scripts/release.sh --publish <更新说明文件>}"
    gh release create "$TAG" build/Dayline.zip build/Dayline.zip.sig \
        --title "Dayline $VERSION" --notes-file "$NOTES"
fi

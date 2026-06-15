#!/usr/bin/env bash
#
# Build Lexed as a proper macOS .app bundle.
#
# Running the raw SwiftPM binary works, but macOS only shows the Microphone and
# Speech Recognition permission prompts for a code-signed .app whose Info.plist
# carries the usage-description strings. This script assembles that bundle.
#
# Usage:  ./scripts/build-app.sh [--open]
#
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="release"
APP_NAME="Lexed"
BUILD_DIR=".build/${CONFIG}"
APP="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS="${APP}/Contents"
ENTITLEMENTS="Sources/Lexed/Lexed.entitlements"

echo "▸ Building (${CONFIG})…"
swift build -c "${CONFIG}"

echo "▸ Assembling ${APP_NAME}.app…"
rm -rf "${APP}"
mkdir -p "${CONTENTS}/MacOS" "${CONTENTS}/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${CONTENTS}/MacOS/${APP_NAME}"
cp "Sources/Lexed/Info.plist" "${CONTENTS}/Info.plist"

# Bundle.module resolves resources from the app's Resources directory.
if [ -d "${BUILD_DIR}/${APP_NAME}_${APP_NAME}.bundle" ]; then
    cp -R "${BUILD_DIR}/${APP_NAME}_${APP_NAME}.bundle" "${CONTENTS}/Resources/"
fi

echo "▸ Code signing (ad-hoc) with entitlements…"
codesign --force --deep \
    --sign - \
    --entitlements "${ENTITLEMENTS}" \
    --options runtime \
    "${APP}"

echo "✓ Built ${APP}"

if [[ "${1:-}" == "--open" ]]; then
    echo "▸ Launching…"
    open "${APP}"
fi

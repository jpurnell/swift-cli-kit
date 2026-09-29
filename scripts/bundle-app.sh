#!/usr/bin/env bash
# bundle-app.sh - assemble QGDashboardApp into a double-clickable macOS .app.
#
#   scripts/bundle-app.sh            # -> build/Quality Gate Dashboard.app
#
# Builds the release binary, wraps it with Info.plist into a .app bundle, and
# ad-hoc code-signs it so it launches without a developer certificate.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Quality Gate Dashboard"
EXECUTABLE="QGDashboardApp"
BUNDLE="$ROOT/build/$APP_NAME.app"
CONTENTS="$BUNDLE/Contents"

echo "Building release binary..."
swift build -c release --product "$EXECUTABLE" --package-path "$ROOT"
BIN="$ROOT/.build/release/$EXECUTABLE"
if [ ! -x "$BIN" ]; then
    echo "error: $BIN not found"
    exit 1
fi

echo "Assembling $BUNDLE ..."
rm -rf "$BUNDLE"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BIN" "$CONTENTS/MacOS/$EXECUTABLE"
cp "$ROOT/packaging/QGDashboardApp-Info.plist" "$CONTENTS/Info.plist"
printf 'APPL????' > "$CONTENTS/PkgInfo"

echo "Ad-hoc code-signing..."
codesign --force --sign - "$BUNDLE" >/dev/null 2>&1 || \
    echo "  (codesign skipped - bundle still runnable locally)"

echo "Built: $BUNDLE"
echo "  open \"$BUNDLE\""

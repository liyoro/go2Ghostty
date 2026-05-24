#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$PROJECT_DIR/.." && pwd)"
APP_NAME="go2Ghostty"
BUNDLE_ID="dev.local.go2Ghostty"
BUILD_DIR="$PROJECT_DIR/.build-direct"
STAGE_DIR="$PROJECT_DIR/dist"
APP_DIR="$STAGE_DIR/$APP_NAME.app"
RELEASE_DIR="$ROOT_DIR/Release"
SUPPORT_DIR="$PROJECT_DIR/.build-support"

cd "$PROJECT_DIR"
mkdir -p "$SUPPORT_DIR/home" "$SUPPORT_DIR/cache" "$SUPPORT_DIR/module-cache"
export HOME="$SUPPORT_DIR/home"
export XDG_CACHE_HOME="$SUPPORT_DIR/cache"
export CLANG_MODULE_CACHE_PATH="$SUPPORT_DIR/module-cache"
mkdir -p "$BUILD_DIR"

SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
swiftc -O \
    -target arm64-apple-macos13 \
    -sdk "$SDK_PATH" \
    -module-cache-path "$SUPPORT_DIR/module-cache" \
    -framework AppKit \
    "$PROJECT_DIR/script/generate_icon.swift" \
    -o "$BUILD_DIR/generate_icon"
"$BUILD_DIR/generate_icon" "$PROJECT_DIR/Resources/AppIcon.iconset" "$PROJECT_DIR/Resources/AppIcon.icns"

swiftc -parse-as-library -O \
    -target arm64-apple-macos13 \
    -sdk "$SDK_PATH" \
    -module-cache-path "$SUPPORT_DIR/module-cache" \
    -framework AppKit \
    -framework ApplicationServices \
    "$PROJECT_DIR/Sources/$APP_NAME/main.swift" \
    -o "$BUILD_DIR/$APP_NAME-arm64"

swiftc -parse-as-library -O \
    -target x86_64-apple-macos13 \
    -sdk "$SDK_PATH" \
    -module-cache-path "$SUPPORT_DIR/module-cache" \
    -framework AppKit \
    -framework ApplicationServices \
    "$PROJECT_DIR/Sources/$APP_NAME/main.swift" \
    -o "$BUILD_DIR/$APP_NAME-x86_64"

lipo -create "$BUILD_DIR/$APP_NAME-arm64" "$BUILD_DIR/$APP_NAME-x86_64" -output "$BUILD_DIR/$APP_NAME"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BUILD_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$PROJECT_DIR/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>go2Ghostty reads the front Finder folder and opens Ghostty at that location.</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"
codesign --force --sign - "$APP_DIR"

mkdir -p "$RELEASE_DIR"
rm -rf "$RELEASE_DIR/$APP_NAME.app"
cp -R "$APP_DIR" "$RELEASE_DIR/$APP_NAME.app"

echo "$RELEASE_DIR/$APP_NAME.app"

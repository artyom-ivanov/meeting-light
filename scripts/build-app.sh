#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="MeetingLight"
BUNDLE_ID="com.meetinglight.app"
BUILD_DIR="$PROJECT_DIR/.build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
SIGN_IDENTITY="Developer ID Application: Artyom Ivanov (453ZXYW34S)"
TEAM_ID="453ZXYW34S"

echo "==> Building release binary..."
cd "$PROJECT_DIR"
swift build -c release --arch arm64 --arch x86_64 2>&1

echo "==> Creating app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$CONTENTS/MacOS"
mkdir -p "$CONTENTS/Resources"

cp "$BUILD_DIR/apple/Products/Release/$APP_NAME" "$CONTENTS/MacOS/$APP_NAME" 2>/dev/null \
  || cp "$BUILD_DIR/release/$APP_NAME" "$CONTENTS/MacOS/$APP_NAME"

ICON_SOURCE="$PROJECT_DIR/Sources/MeetingLight/AppIcon.png"
if [ -f "$ICON_SOURCE" ]; then
    echo "==> Generating app icon..."
    ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
    rm -rf "$ICONSET_DIR"
    mkdir -p "$ICONSET_DIR"

    for SIZE in 16 32 128 256 512; do
        sips -z $SIZE $SIZE "$ICON_SOURCE" --out "$ICONSET_DIR/icon_${SIZE}x${SIZE}.png" > /dev/null 2>&1
        DOUBLE=$((SIZE * 2))
        sips -z $DOUBLE $DOUBLE "$ICON_SOURCE" --out "$ICONSET_DIR/icon_${SIZE}x${SIZE}@2x.png" > /dev/null 2>&1
    done

    iconutil -c icns "$ICONSET_DIR" -o "$CONTENTS/Resources/AppIcon.icns"
    rm -rf "$ICONSET_DIR"
    echo "    Icon generated."
else
    echo "    (No icon source found at Sources/MeetingLight/AppIcon.png, skipping)"
fi

cat > "$CONTENTS/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>Meeting Light</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# Entitlements for hardened runtime (required for notarization)
ENTITLEMENTS="$BUILD_DIR/entitlements.plist"
cat > "$ENTITLEMENTS" << 'ENT'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
</dict>
</plist>
ENT

echo "==> Signing with Developer ID..."
codesign --force --options runtime --deep \
    --entitlements "$ENTITLEMENTS" \
    --sign "$SIGN_IDENTITY" \
    "$APP_DIR"

echo "==> Verifying signature..."
codesign --verify --deep --strict "$APP_DIR"
spctl --assess --type execute --verbose "$APP_DIR" 2>&1 || true

echo "==> Creating ZIP for notarization..."
ZIP_PATH="$BUILD_DIR/$APP_NAME.zip"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

echo "==> Submitting for notarization..."
echo "    (This may take a few minutes...)"
xcrun notarytool submit "$ZIP_PATH" \
    --team-id "$TEAM_ID" \
    --keychain-profile "notarytool-profile" \
    --wait 2>&1 || {
    echo ""
    echo "    If this failed with auth error, create a keychain profile first:"
    echo "    xcrun notarytool store-credentials notarytool-profile --team-id $TEAM_ID --apple-id YOUR_APPLE_ID --password APP_SPECIFIC_PASSWORD"
    echo ""
    echo "    Generate an app-specific password at: https://appleid.apple.com/account/manage"
    echo "    (Sign in > App-Specific Passwords > Generate)"
    exit 1
}

echo "==> Stapling notarization ticket..."
xcrun stapler staple "$APP_DIR"

rm -f "$ZIP_PATH" "$ENTITLEMENTS"

echo "==> Creating DMG..."
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"
DMG_TEMP="$BUILD_DIR/dmg-staging"
rm -f "$DMG_PATH"
rm -rf "$DMG_TEMP"
mkdir -p "$DMG_TEMP"

cp -r "$APP_DIR" "$DMG_TEMP/"
ln -s /Applications "$DMG_TEMP/Applications"

hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_TEMP" \
    -ov -format UDZO \
    "$DMG_PATH"

rm -rf "$DMG_TEMP"

codesign --force --sign "$SIGN_IDENTITY" "$DMG_PATH"

echo "==> Notarizing DMG..."
xcrun notarytool submit "$DMG_PATH" \
    --team-id "$TEAM_ID" \
    --keychain-profile "notarytool-profile" \
    --wait 2>&1

xcrun stapler staple "$DMG_PATH"

echo ""
echo "==> Done! Ready to distribute:"
echo "    $DMG_PATH"
echo ""
echo "    Users open the DMG and drag MeetingLight to Applications."

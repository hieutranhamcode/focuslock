#!/bin/bash
# Builds FocusLock.app from AppSource/main.swift.
# Run this once on a machine with Xcode Command Line Tools to produce the .app.
# Afterwards you can just copy/drag FocusLock.app to another machine,
# no rebuild needed (it's a universal binary — Apple Silicon + Intel).

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR/AppSource/main.swift"
ICON="$SCRIPT_DIR/AppSource/Assets/AppIcon.icns"
APP_NAME="FocusLock"
APP_BUNDLE="$SCRIPT_DIR/$APP_NAME.app"
BUNDLE_ID="com.kira.focuslock"

echo "==> Cleaning previous build (if any)"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

echo "==> Compiling for arm64"
swiftc -O -target arm64-apple-macosx13.0 "$SRC" -o "/tmp/${APP_NAME}-arm64"

echo "==> Compiling for x86_64"
swiftc -O -target x86_64-apple-macosx13.0 "$SRC" -o "/tmp/${APP_NAME}-x86_64"

echo "==> Combining into a universal binary"
lipo -create "/tmp/${APP_NAME}-arm64" "/tmp/${APP_NAME}-x86_64" -output "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
rm -f "/tmp/${APP_NAME}-arm64" "/tmp/${APP_NAME}-x86_64"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

if [ -f "$ICON" ]; then
    echo "==> Copying app icon"
    cp "$ICON" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
else
    echo "==> No icon found at $ICON, skipping (app will use the default icon)"
fi

echo "==> Writing Info.plist"
cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>$APP_NAME</string>
	<key>CFBundleIdentifier</key>
	<string>$BUNDLE_ID</string>
	<key>CFBundleName</key>
	<string>$APP_NAME</string>
	<key>CFBundleDisplayName</key>
	<string>$APP_NAME</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSUIElement</key>
	<true/>
	<key>LSMinimumSystemVersion</key>
	<string>13.0</string>
	<key>NSHighResolutionCapable</key>
	<true/>
</dict>
</plist>
PLIST_EOF

echo "==> Ad-hoc code signing"
codesign --force --deep -s - "$APP_BUNDLE"

echo ""
echo "✅ Build done: $APP_BUNDLE"
echo ""
echo "Next steps:"
echo "  1. Drag '$APP_NAME.app' into /Applications"
echo "  2. Open it the first time: right-click → Open (unsigned/ad-hoc app, macOS will warn once)"
echo "  3. Grant Accessibility + Input Monitoring to '$APP_NAME' in System Settings"
echo "  4. From the menu bar, click the lock icon → enable 'Start at Login'"

#!/bin/bash
set -e

APP_NAME="ProjectLumina"
EXECUTABLE_NAME="ProjectLumina"
BUILD_DIR=".build/release"
APP_BUNDLE_PATH="$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE_PATH/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "🚀 Building Release version..."
swift build -c release

echo "📦 Creating App Bundle Structure..."
rm -rf "$APP_BUNDLE_PATH"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

echo "📄 Copying Executable..."
cp "$BUILD_DIR/$EXECUTABLE_NAME" "$MACOS_DIR/"

echo "📄 Copying Resources..."
if [ -f "appsettings.json" ]; then
    cp "appsettings.json" "$RESOURCES_DIR/"
fi

echo "📝 Generating Info.plist..."
cat <<EOF > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$EXECUTABLE_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.shawnwang.$APP_NAME</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "✨ Done! App bundled successfully at $APP_BUNDLE_PATH"

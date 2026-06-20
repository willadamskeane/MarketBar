#!/bin/bash
set -e

APP_DIR="MarketBar.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

echo "🔨 Compiling Swift source files..."
swiftc -sdk $(xcrun --show-sdk-path) -O \
    Sources/MarketBar/Models/*.swift \
    Sources/MarketBar/Services/*.swift \
    Sources/MarketBar/Views/*.swift \
    Sources/MarketBar/App/*.swift \
    -o "$MACOS_DIR/MarketBar"

echo "📝 Creating Info.plist..."
cat << 'EOF' > "$APP_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.txt">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MarketBar</string>
    <key>CFBundleIdentifier</key>
    <string>com.will.MarketBar</string>
    <key>CFBundleName</key>
    <string>MarketBar</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

echo "🎉 MarketBar.app successfully built!"

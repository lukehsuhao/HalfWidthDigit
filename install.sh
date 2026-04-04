#!/bin/bash
set -e

APP_NAME="HalfWidthDigit"
BINARY_SRC="$(cd "$(dirname "$0")" && pwd)/.build/release/$APP_NAME"
INSTALL_DIR="$HOME/.local/bin"
PLIST_PATH="$HOME/Library/LaunchAgents/com.halfwidthdigit.plist"

# Build if needed
if [ ! -f "$BINARY_SRC" ]; then
    echo "Building..."
    cd "$(dirname "$0")"
    swift build -c release
fi

# Install binary
mkdir -p "$INSTALL_DIR"
cp "$BINARY_SRC" "$INSTALL_DIR/$APP_NAME"
chmod +x "$INSTALL_DIR/$APP_NAME"
echo "✓ Installed to $INSTALL_DIR/$APP_NAME"

# Create LaunchAgent
cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.halfwidthdigit</string>
    <key>ProgramArguments</key>
    <array>
        <string>${INSTALL_DIR}/${APP_NAME}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/halfwidthdigit.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/halfwidthdigit.log</string>
</dict>
</plist>
EOF
echo "✓ LaunchAgent created at $PLIST_PATH"

# Load the agent
launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"
echo "✓ LaunchAgent loaded (will auto-start on login)"

echo ""
echo "⚠️  首次啟動需要授權「輔助使用」權限："
echo "   系統設定 → 隱私權與安全性 → 輔助使用 → 允許 $APP_NAME"
echo ""
echo "Done! Menu bar should show ½ icon."

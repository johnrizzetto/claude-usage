#!/bin/bash
set -e
cd "$(dirname "$0")"

echo "Building ClaudeUsage..."
swift build -c release

APP_DIR="$HOME/Applications/ClaudeUsage.app"
BINARY=".build/release/ClaudeUsage"

echo "Updating app bundle..."
mkdir -p "$APP_DIR/Contents/MacOS"
cp "$BINARY" "$APP_DIR/Contents/MacOS/ClaudeUsage"
chmod +x "$APP_DIR/Contents/MacOS/ClaudeUsage"

echo "Restarting..."
pkill -x ClaudeUsage 2>/dev/null || true
sleep 0.5
open "$APP_DIR"
echo "Done — ClaudeUsage is running in your menu bar."

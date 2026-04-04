#!/bin/bash
set -e

BASE_URL="https://maccleaner.apps.caodev.top"
APP_NAME="MacCleanerApp"
INSTALL_DIR="/Applications"

# macOS only
if [ "$(uname)" != "Darwin" ]; then
  echo "Error: MacCleaner requires macOS." >&2
  exit 1
fi

echo "Fetching latest version..."
VERSION=$(curl -fsSL "$BASE_URL/latest.txt")

if [ -z "$VERSION" ]; then
  echo "Error: Could not determine latest version." >&2
  exit 1
fi

echo "Installing MacCleaner $VERSION..."

TMP_DIR=$(mktemp -d)
ZIP_PATH="$TMP_DIR/MacCleaner.zip"

curl -fsSL "$BASE_URL/releases/MacCleaner-$VERSION.zip" -o "$ZIP_PATH"
unzip -q "$ZIP_PATH" -d "$TMP_DIR"

if [ -d "$INSTALL_DIR/$APP_NAME.app" ]; then
  echo "Removing existing installation..."
  rm -rf "$INSTALL_DIR/$APP_NAME.app"
fi

mv "$TMP_DIR/$APP_NAME.app" "$INSTALL_DIR/"
rm -rf "$TMP_DIR"

echo ""
echo "MacCleaner $VERSION installed to $INSTALL_DIR/$APP_NAME.app"
echo ""
echo "First launch: right-click the app and choose Open"
echo "(macOS Gatekeeper requires this for unsigned apps)"

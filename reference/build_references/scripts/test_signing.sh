#!/bin/bash
# Quick test script for signing process
# Usage: ./test_signing.sh <path_to_existing_app_bundle>

set -e

APP_PATH="$1"
if [ -z "$APP_PATH" ]; then
    echo "Usage: $0 <path_to_app_bundle>"
    echo "Example: $0 /Users/strattenwaldt/Desktop/Basil/builds/outputs/20250806_154437/Basil.app"
    exit 1
fi

if [ ! -d "$APP_PATH" ]; then
    echo "Error: App bundle not found at $APP_PATH"
    exit 1
fi

echo "🧪 Testing signing process on: $APP_PATH"

# Remove any existing signatures to start clean
echo "🧹 Removing existing signatures..."
codesign --remove-signature "$APP_PATH" 2>/dev/null || true

# Test just the deep signing script
DEEP_SIGN_SCRIPT="$(dirname "$0")/deep_sign_app.sh"
ENTITLEMENTS_PATH="$(dirname "$0")/../../../BasilClient/Sources/Support/Basil.entitlements"

echo "🔍 Running deep signing..."
if "$DEEP_SIGN_SCRIPT" "$APP_PATH" --entitlements "$ENTITLEMENTS_PATH"; then
    echo "✅ Deep signing completed"
else
    echo "❌ Deep signing failed"
    exit 1
fi

echo "🔐 Testing final app bundle signing..."
SIGNING_IDENTITY="Developer ID Application: Baobab Group LLC (D4X8TSBQJC)"
if codesign --sign "$SIGNING_IDENTITY" --entitlements "$ENTITLEMENTS_PATH" --timestamp --options runtime "$APP_PATH"; then
    echo "✅ Final app bundle signing completed"
else
    echo "❌ Final app bundle signing failed"
    exit 1
fi

echo "🔍 Verifying signatures..."
if codesign --verify --deep --strict "$APP_PATH"; then
    echo "✅ Signature verification passed"
else
    echo "❌ Signature verification failed"
    exit 1
fi

echo "🎉 All signing tests passed!" 
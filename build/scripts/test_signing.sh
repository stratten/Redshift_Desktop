#!/bin/bash
# Test signing script for Redshift
# Tests the complete signing process on a packaged app

set -e

APP_PATH="$1"
if [ -z "$APP_PATH" ]; then
    echo "Usage: $0 <path_to_Redshift.app>"
    echo "Example: $0 dist/mac/Redshift.app"
    exit 1
fi

if [ ! -d "$APP_PATH" ]; then
    echo "Error: App bundle not found at $APP_PATH"
    exit 1
fi

echo "🧪 Testing signing process on: $APP_PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENTITLEMENTS_PATH="$SCRIPT_DIR/../entitlements.mac.plist"

echo "🔍 Running deep signing..."
if "$SCRIPT_DIR/deep_sign_app.sh" "$APP_PATH" --entitlements "$ENTITLEMENTS_PATH"; then
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

echo "🔍 Checking Gatekeeper assessment..."
if spctl -a -t exec -vv "$APP_PATH"; then
    echo "✅ Gatekeeper assessment passed"
else
    echo "⚠️  Gatekeeper assessment pending (needs notarization)"
fi

echo "🎉 All signing tests passed!"


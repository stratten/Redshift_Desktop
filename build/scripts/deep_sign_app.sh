#!/bin/bash
# Deep Code Signing Script for Redshift
# Signs all .dylib, .so, .node, and executable files within an Electron app bundle
# Adapted from Basil signing process

set -e

# Configuration
SIGNING_IDENTITY="Developer ID Application: Baobab Group LLC (D4X8TSBQJC)"
ENTITLEMENTS_PATH=""

# Function for logging with timestamp
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

print_usage() {
    echo "Usage: $0 <app_path> [--entitlements <path>]"
    echo ""
    echo "Deep signs all binaries within Redshift.app for notarization."
    echo ""
    echo "Arguments:"
    echo "  app_path              Path to Redshift.app bundle"
    echo "  --entitlements path   Path to entitlements file (optional)"
    echo ""
    echo "What this script signs:"
    echo "  - All .dylib files (dynamic libraries)"
    echo "  - All .so files (Python extensions)"
    echo "  - All .node files (Node.js native modules)"
    echo "  - All Python and bundled executables"
    echo "  - Electron framework"
    exit 1
}

# Parse arguments
APP_PATH=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --entitlements)
            ENTITLEMENTS_PATH="$2"
            shift 2
            ;;
        -h|--help)
            print_usage
            ;;
        *)
            if [[ -z "$APP_PATH" ]]; then
                APP_PATH="$1"
            else
                echo "Error: Unknown argument $1"
                print_usage
            fi
            shift
            ;;
    esac
done

if [[ -z "$APP_PATH" ]]; then
    echo "Error: App path is required"
    print_usage
fi

if [[ ! -d "$APP_PATH" ]]; then
    echo "Error: App not found at $APP_PATH"
    exit 1
fi

# Build signing command
if [[ -n "$ENTITLEMENTS_PATH" && -f "$ENTITLEMENTS_PATH" ]]; then
    SIGN_CMD="codesign --force --timestamp --options runtime --entitlements \"$ENTITLEMENTS_PATH\" --sign \"$SIGNING_IDENTITY\""
    log "Using entitlements: $ENTITLEMENTS_PATH"
else
    SIGN_CMD="codesign --force --timestamp --options runtime --sign \"$SIGNING_IDENTITY\""
    log "No entitlements file specified - using hardened runtime for all binaries"
fi

log "🔍 Starting deep code signing for: $APP_PATH"
log "🔐 Signing identity: $SIGNING_IDENTITY"

# Function to sign a file
sign_file() {
    local file="$1"
    local relative_path="${file#$APP_PATH/}"
    
    echo "  📝 Signing: $relative_path"
    
    # Check if it's a universal binary
    if file "$file" | grep -q "universal binary"; then
        eval "$SIGN_CMD --all-architectures \"$file\"" 2>/dev/null || {
            echo "  ⚠️  Failed to sign universal binary: $relative_path"
            return 1
        }
    else
        eval "$SIGN_CMD \"$file\"" 2>/dev/null || {
            echo "  ⚠️  Failed to sign: $relative_path"
            return 1
        }
    fi
}

# Export function
export -f sign_file
export SIGN_CMD
export APP_PATH

# Count files to sign
DYLIB_COUNT=$(find -L "$APP_PATH" -name "*.dylib" | wc -l | tr -d ' ')
SO_COUNT=$(find -L "$APP_PATH" -name "*.so" | wc -l | tr -d ' ')
NODE_COUNT=$(find -L "$APP_PATH" -name "*.node" | wc -l | tr -d ' ')

log "📊 Found binaries to sign:"
log "    - $DYLIB_COUNT .dylib files"
log "    - $SO_COUNT .so files (Python extensions)"
log "    - $NODE_COUNT .node files (Node.js native modules)"

# Remove problematic files
log "🧹 Removing unsignable files..."
find "$APP_PATH" -name "*.o" -delete 2>/dev/null || true
find "$APP_PATH" -name "*.a" -delete 2>/dev/null || true
log "   Removed .o and .a files"

# Sign Python bundled binaries first (deepest level)
if [[ -d "$APP_PATH/Contents/Resources/python" ]]; then
    log "🐍 Signing Python runtime..."
    find -L "$APP_PATH/Contents/Resources/python" -name "*.dylib" -exec bash -c 'sign_file "$0"' {} \;
    find -L "$APP_PATH/Contents/Resources/python" -name "*.so" -exec bash -c 'sign_file "$0"' {} \;
    
    # Sign Python executable
    if [[ -f "$APP_PATH/Contents/Resources/python/python/bin/python3.11" ]]; then
        log "  📝 Signing Python executable..."
        sign_file "$APP_PATH/Contents/Resources/python/python/bin/python3.11"
    fi
fi

# Sign Python dependencies
if [[ -d "$APP_PATH/Contents/Resources/python-deps" ]]; then
    log "📦 Signing Python dependencies..."
    find -L "$APP_PATH/Contents/Resources/python-deps" -name "*.dylib" -exec bash -c 'sign_file "$0"' {} \;
    find -L "$APP_PATH/Contents/Resources/python-deps" -name "*.so" -exec bash -c 'sign_file "$0"' {} \;
fi

# Sign Node.js native modules (sqlite3, usb, etc.)
if [[ $NODE_COUNT -gt 0 ]]; then
    log "📦 Signing Node.js native modules..."
    find -L "$APP_PATH" -name "*.node" -exec bash -c 'sign_file "$0"' {} \;
fi

# Sign remaining .dylib files
if [[ $DYLIB_COUNT -gt 0 ]]; then
    log "🔗 Signing remaining .dylib files..."
    find -L "$APP_PATH" -name "*.dylib" -exec bash -c '
        # Skip already signed Python runtime dylibs
        if [[ "$0" != */Resources/python/* && "$0" != */Resources/python-deps/* ]]; then
            sign_file "$0"
        fi
    ' {} \;
fi

# Sign Electron Helper apps (must be signed before main app)
log "⚡ Signing Electron Helper apps..."
find "$APP_PATH/Contents/Frameworks" -name "*.app" -maxdepth 2 | while read helper_app; do
    helper_name=$(basename "$helper_app")
    echo "  📦 Signing: $helper_name"
    eval "$SIGN_CMD --deep \"$helper_app\"" || {
        echo "  ⚠️  Failed to sign $helper_name"
        exit 1
    }
done

# Sign Electron Framework (after helpers)
log "🏗️ Signing Electron Framework..."
if [[ -d "$APP_PATH/Contents/Frameworks/Electron Framework.framework" ]]; then
    eval "$SIGN_CMD \"$APP_PATH/Contents/Frameworks/Electron Framework.framework/Versions/A/Electron Framework\"" || {
        echo "  ⚠️  Failed to sign Electron Framework binary"
        exit 1
    }
    eval "$SIGN_CMD \"$APP_PATH/Contents/Frameworks/Electron Framework.framework\"" || {
        echo "  ⚠️  Failed to sign Electron Framework bundle"
        exit 1
    }
fi

# Sign Squirrel framework (auto-updater) - CRITICAL for notarization
log "🐿️  Signing Squirrel Framework..."
if [[ -d "$APP_PATH/Contents/Frameworks/Squirrel.framework" ]]; then
    # Sign ShipIt executable first (deepest component)
    if [[ -f "$APP_PATH/Contents/Frameworks/Squirrel.framework/Versions/A/Resources/ShipIt" ]]; then
        echo "  📝 Signing ShipIt executable..."
        sign_file "$APP_PATH/Contents/Frameworks/Squirrel.framework/Versions/A/Resources/ShipIt" || {
            echo "  ⚠️  Failed to sign ShipIt"
            exit 1
        }
    fi
    
    # Sign any dylibs in Squirrel framework
    find "$APP_PATH/Contents/Frameworks/Squirrel.framework" -name "*.dylib" -exec bash -c 'sign_file "$0"' {} \;
    
    # Sign the main Squirrel binary
    if [[ -f "$APP_PATH/Contents/Frameworks/Squirrel.framework/Versions/A/Squirrel" ]]; then
        echo "  📝 Signing Squirrel framework binary..."
        eval "$SIGN_CMD \"$APP_PATH/Contents/Frameworks/Squirrel.framework/Versions/A/Squirrel\"" || {
            echo "  ⚠️  Failed to sign Squirrel binary"
            exit 1
        }
    fi
    
    # Sign the framework bundle itself
    echo "  📝 Signing Squirrel framework bundle..."
    eval "$SIGN_CMD \"$APP_PATH/Contents/Frameworks/Squirrel.framework\"" || {
        echo "  ⚠️  Failed to sign Squirrel framework bundle"
        exit 1
    }
    log "  ✅ Squirrel framework signed successfully"
else
    log "  ℹ️  Squirrel framework not found (auto-update disabled)"
fi

# Sign other framework executables
log "🔧 Signing remaining framework executables..."
find "$APP_PATH/Contents/Frameworks" -type f -perm +111 \( ! -name "*.dylib" ! -name "*.so" ! -name "*.node" \) | while read executable; do
    # Skip already processed files
    if [[ "$executable" =~ Squirrel\.framework.*ShipIt$ ]] || [[ "$executable" =~ Squirrel\.framework.*Squirrel$ ]]; then
        continue  # Already signed above
    fi
    # Skip .app bundles (already signed)
    if [[ ! "$executable" =~ \.app/ ]]; then
        # Check if it's a Mach-O binary
        if file "$executable" | grep -q "Mach-O"; then
            echo "  📝 Signing: $(basename "$executable")"
            sign_file "$executable"
        fi
    fi
done

log "✅ Deep code signing completed successfully"
log "📦 Signing main app bundle..."

# Sign the main app bundle (CRITICAL FINAL STEP)
eval "$SIGN_CMD --deep \"$APP_PATH\"" || {
    echo "❌ Failed to sign main app bundle"
    exit 1
}

log "✅ Main app bundle signed successfully"
log "🎉 All signing completed!"


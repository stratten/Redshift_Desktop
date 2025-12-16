#!/bin/bash
# Master build and signing script for Redshift
# Coordinates the complete build, sign, and package process

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
  echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"
}

error() {
  echo -e "${RED}[$(date '+%H:%M:%S')] ERROR:${NC} $1"
}

warning() {
  echo -e "${YELLOW}[$(date '+%H:%M:%S')] WARNING:${NC} $1"
}

print_usage() {
    echo "Usage: $0 [--skip-build] [--skip-notarize] [--skip-dmg] [--arm64-only] [--x64-only]"
    echo ""
    echo "Complete build, sign, and package process for Redshift"
    echo ""
    echo "Options:"
    echo "  --skip-build      Skip the npm build step (use existing build)"
    echo "  --skip-notarize   Skip notarization (faster, for testing)"
    echo "  --skip-dmg        Skip DMG creation (only create signed .app)"
    echo "  --arm64-only      Build only ARM64 (Apple Silicon)"
    echo "  --x64-only        Build only x64 (Intel)"
    echo ""
    echo "Environment variables needed for notarization:"
    echo "  APPLE_ID          Your Apple ID email"
    echo "  APPLE_ID_PASSWORD App-specific password"
    echo "  APPLE_TEAM_ID     Your team ID (D4X8TSBQJC)"
    exit 1
}

# Parse arguments
SKIP_BUILD=false
SKIP_NOTARIZE=false
SKIP_DMG=false
ARCH_FLAG=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --skip-notarize)
            SKIP_NOTARIZE=true
            shift
            ;;
        --skip-dmg)
            SKIP_DMG=true
            shift
            ;;
        --arm64-only)
            ARCH_FLAG="--arm64"
            shift
            ;;
        --x64-only)
            ARCH_FLAG="--x64"
            shift
            ;;
        -h|--help)
            print_usage
            ;;
        *)
            error "Unknown argument: $1"
            print_usage
            ;;
    esac
done

cd "$PROJECT_ROOT"

log "🚀 Starting Redshift build and sign process"
log "📂 Project root: $PROJECT_ROOT"

# Create builds directory with timestamp
BUILD_TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
BUILDS_DIR="$PROJECT_ROOT/builds"
BUILD_OUTPUT_DIR="$BUILDS_DIR/build_$BUILD_TIMESTAMP"
mkdir -p "$BUILD_OUTPUT_DIR"

log "📦 Build artifacts will be saved to: $BUILD_OUTPUT_DIR"

# Check Python is bundled
if [[ ! -f "resources/python/python/bin/python3.11" ]]; then
    error "Python runtime not found. Run ./scripts/setup-python.sh first"
    exit 1
fi
log "✅ Python runtime verified"

# Check code signing certificate
if ! security find-identity -v -p codesigning | grep -q "Developer ID Application: Baobab Group LLC"; then
    error "Code signing certificate not found in keychain"
    exit 1
fi
log "✅ Code signing certificate verified"

# Build the app (unsigned)
if [[ "$SKIP_BUILD" == false ]]; then
    log "🔨 Building Redshift (unsigned)..."
    npm run pack $ARCH_FLAG
    log "✅ Build completed"
else
    warning "Skipping build step"
fi

# Find and sign all built apps
declare -a APP_PATHS
if [[ "$ARCH_FLAG" == "--arm64" ]]; then
    APP_PATHS=("$PROJECT_ROOT/dist/mac-arm64/Redshift.app")
elif [[ "$ARCH_FLAG" == "--x64" ]]; then
    APP_PATHS=("$PROJECT_ROOT/dist/mac/Redshift.app")
else
    # Build both architectures
    if [[ -d "$PROJECT_ROOT/dist/mac-arm64/Redshift.app" ]]; then
        APP_PATHS+=("$PROJECT_ROOT/dist/mac-arm64/Redshift.app")
    fi
    if [[ -d "$PROJECT_ROOT/dist/mac/Redshift.app" ]]; then
        APP_PATHS+=("$PROJECT_ROOT/dist/mac/Redshift.app")
    fi
fi

if [[ ${#APP_PATHS[@]} -eq 0 ]]; then
    error "No built apps found in dist/"
    error "Expected locations: dist/mac-arm64/Redshift.app or dist/mac/Redshift.app"
    exit 1
fi

# Sign each app
for APP_PATH in "${APP_PATHS[@]}"; do
    if [[ ! -d "$APP_PATH" ]]; then
        warning "App not found: $APP_PATH"
        continue
    fi
    
    log "📦 Processing: $APP_PATH"
    
    # Deep sign the app
    log "🔏 Deep signing all binaries..."
    if "$SCRIPT_DIR/deep_sign_app.sh" "$APP_PATH" --entitlements "$PROJECT_ROOT/build/entitlements.mac.plist"; then
        log "✅ Deep signing completed"
    else
        error "Deep signing failed for: $APP_PATH"
        exit 1
    fi
    
    # Verify signing
    log "🔍 Verifying code signature..."
    if codesign --verify --deep --strict "$APP_PATH" 2>&1; then
        log "✅ Code signature verified"
    else
        error "Code signature verification failed"
        codesign --verify --deep --strict --verbose=4 "$APP_PATH" 2>&1 | head -20
        exit 1
    fi
done

# Notarize if requested
if [[ "$SKIP_NOTARIZE" == false ]]; then
    log "📤 Starting notarization process..."
    
    for APP_PATH in "${APP_PATHS[@]}"; do
        if [[ -d "$APP_PATH" ]]; then
            log "📦 Notarizing: $(basename "$APP_PATH")"
            if "$SCRIPT_DIR/notarize_app.sh" "$APP_PATH"; then
                log "✅ App notarized successfully"
            else
                warning "Notarization failed for $(basename "$APP_PATH")"
                warning "Make sure credentials are stored with: xcrun notarytool store-credentials notarytool-password"
            fi
        fi
    done
else
    warning "Skipping notarization"
fi

# Create DMG files if requested
declare -a DMG_PATHS
if [[ "$SKIP_DMG" == false ]]; then
    log "💿 Creating DMG files..."
    
    for APP_PATH in "${APP_PATHS[@]}"; do
        if [[ ! -d "$APP_PATH" ]]; then
            continue
        fi
        
        # Determine DMG name based on architecture
        APP_DIR=$(dirname "$APP_PATH")
        DMG_NAME="Redshift-$(basename "$APP_DIR").dmg"
        DMG_PATH="$PROJECT_ROOT/dist/$DMG_NAME"
        
        log "📦 Creating DMG for $(basename "$APP_PATH")..."
        
        # Create DMG
        if hdiutil create -volname "Redshift" \
                         -srcfolder "$APP_PATH" \
                         -ov \
                         -format UDZO \
                         "$DMG_PATH" > /dev/null 2>&1; then
            log "✅ DMG created: $DMG_PATH"
            DMG_PATHS+=("$DMG_PATH")
            
            # Sign the DMG
            log "🔏 Signing DMG..."
            if codesign --sign "Developer ID Application: Baobab Group LLC" \
                       --timestamp \
                       "$DMG_PATH" > /dev/null 2>&1; then
                log "✅ DMG signed"
            else
                warning "Failed to sign DMG (will still work)"
            fi
            
            # Notarize DMG if requested
            if [[ "$SKIP_NOTARIZE" == false ]]; then
                if [[ ! -z "$APPLE_ID" ]] || xcrun notarytool list-credentials 2>/dev/null | grep -q "notarytool-password"; then
                    log "📤 Notarizing DMG..."
                    if "$SCRIPT_DIR/notarize_app.sh" "$DMG_PATH"; then
                        log "✅ DMG notarized and stapled"
                    else
                        warning "DMG notarization failed (DMG will still work)"
                    fi
                fi
            fi
        else
            error "Failed to create DMG"
        fi
    done
else
    warning "Skipping DMG creation"
fi

# Copy artifacts to build output directory
log "📋 Copying artifacts to build directory..."

# Copy .app bundles
for APP_PATH in "${APP_PATHS[@]}"; do
    if [[ -d "$APP_PATH" ]]; then
        APP_NAME=$(basename "$APP_PATH")
        ARCH_NAME=$(basename "$(dirname "$APP_PATH")")
        cp -R "$APP_PATH" "$BUILD_OUTPUT_DIR/${APP_NAME%.app}-${ARCH_NAME}.app"
        log "  ✅ Copied: ${APP_NAME%.app}-${ARCH_NAME}.app"
    fi
done

# Copy DMG files
for DMG_PATH in "${DMG_PATHS[@]}"; do
    if [[ -f "$DMG_PATH" ]]; then
        cp "$DMG_PATH" "$BUILD_OUTPUT_DIR/"
        log "  ✅ Copied: $(basename "$DMG_PATH")"
    fi
done

# Create build info file
cat > "$BUILD_OUTPUT_DIR/build_info.txt" <<EOF
Build Date: $(date)
Build Timestamp: $BUILD_TIMESTAMP
Architecture: ${ARCH_FLAG:-"universal (arm64 + x64)"}
Notarized: $([ "$SKIP_NOTARIZE" == false ] && echo "Yes" || echo "No")
DMG Created: $([ "$SKIP_DMG" == false ] && echo "Yes" || echo "No")

Artifacts:
$(ls -lh "$BUILD_OUTPUT_DIR" | tail -n +2)
EOF

log "🎉 Build and sign process complete!"
log ""
log "📦 Build artifacts saved to:"
log "  $BUILD_OUTPUT_DIR"
log ""
log "📂 Contents:"
for APP_PATH in "${APP_PATHS[@]}"; do
    if [[ -d "$APP_PATH" ]]; then
        APP_NAME=$(basename "$APP_PATH")
        ARCH_NAME=$(basename "$(dirname "$APP_PATH")")
        log "  ✅ ${APP_NAME%.app}-${ARCH_NAME}.app ($(du -sh "$APP_PATH" | cut -f1))"
    fi
done

if [[ ${#DMG_PATHS[@]} -gt 0 ]]; then
    for DMG_PATH in "${DMG_PATHS[@]}"; do
        if [[ -f "$DMG_PATH" ]]; then
            log "  ✅ $(basename "$DMG_PATH") ($(du -sh "$DMG_PATH" | cut -f1))"
        fi
    done
fi

log ""
log "Next steps:"
if [[ ${#DMG_PATHS[@]} -gt 0 ]]; then
    log "  1. Test the DMG: open \"$BUILD_OUTPUT_DIR/$(basename "${DMG_PATHS[0]}")\""
    log "  2. Test on another Mac (to verify Gatekeeper)"
    log "  3. Distribute: Upload DMG to your website or distribution platform"
else
    log "  1. Test the app: open \"$BUILD_OUTPUT_DIR/$(basename "${APP_PATHS[0]%.app}")-$(basename "$(dirname "${APP_PATHS[0]}")").app\""
    log "  2. Create DMG with: ./build/scripts/build_and_sign.sh --skip-build"
    log "  3. Test on another Mac (to verify Gatekeeper)"
fi


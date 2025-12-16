#!/bin/bash
# Exit on error
set -e

# Parse command line arguments
CREATE_DMG=false
NOTARIZE=false
SHOW_HELP=false
# Add code signing configuration
DEVELOPER_ID_CERT="Developer ID Application: Baobab Group LLC (D4X8TSBQJC)"
USE_DEVELOPER_ID=true

for arg in "$@"; do
    case $arg in
        --create-dmg)
            CREATE_DMG=true
            shift
            ;;
        --notarize)
            NOTARIZE=true
            CREATE_DMG=true  # Notarization requires DMG creation
            shift
            ;;
        --ad-hoc)
            USE_DEVELOPER_ID=false
            shift
            ;;
        -h|--help)
            SHOW_HELP=true
            shift
            ;;
        *)
            echo "Unknown argument: $arg"
            SHOW_HELP=true
            ;;
    esac
done

if [ "$SHOW_HELP" = true ]; then
    echo "Usage: $0 [options]"
    echo ""
    echo "Builds the complete Basil application bundle."
    echo ""
    echo "Options:"
    echo "  --create-dmg    Create a DMG disk image after building the application"
    echo "  --notarize      Create DMG and submit to Apple for notarization (requires setup)"
    echo "  --ad-hoc        Use ad-hoc signing instead of Developer ID (for development)"
    echo "  -h, --help      Show this help message"
    echo ""
    echo "Output:"
    echo "  Creates timestamped directory in builds/outputs/ with:"
    echo "  - Basil.app (master application bundle)"
    echo "  - Individual backend/ and frontend/ components"
    echo "  - Optional Basil-TIMESTAMP.dmg (if --create-dmg specified)"
    echo ""
    echo "Notarization Setup (run once before using --notarize):"
    echo "  xcrun notarytool store-credentials \"notarytool-password\" \\"
    echo "    --apple-id \"your-apple-id@example.com\" \\"
    echo "    --team-id \"D4X8TSBQJC\" \\"
    echo "    --password \"your-app-specific-password\""
    exit 0
fi

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
COMMON_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"
ROOT_DIR="$( cd "$COMMON_DIR/../.." && pwd )"

# Build hardening functions
diagnostic_build_check() {
    echo "🔍 Diagnostic build environment check..."
    
    # Poetry health check (diagnostic only)
    local package_count=$(/opt/homebrew/bin/poetry run pip list 2>/dev/null | wc -l)
    if [ "$package_count" -gt 150 ]; then
        echo "   Poetry: ✅ Healthy ($package_count packages)"
    elif [ "$package_count" -gt 50 ]; then
        echo "   Poetry: ⚠️ Degraded ($package_count packages)"
    else
        echo "   Poetry: ❌ Unhealthy ($package_count packages) - may need 'poetry install'"
    fi
    
    # Poetry lock file sync check (diagnostic only)
    if /opt/homebrew/bin/poetry check --lock 2>/dev/null; then
        echo "   Poetry lock: ✅ In sync"
    else
        echo "   Poetry lock: ⚠️ Out of sync - may need 'poetry lock'"
    fi
    
    # Disk space check (diagnostic only)
    local available_gb=$(df -h . | tail -1 | awk '{print $4}' | sed 's/G.*//')
    if [ "$available_gb" -gt 10 ] 2>/dev/null; then
        echo "   Disk space: ✅ Sufficient (${available_gb}GB)"
    elif [ "$available_gb" -gt 5 ] 2>/dev/null; then
        echo "   Disk space: ⚠️ Low (${available_gb}GB)"
    else
        local disk_info=$(df -h . | tail -1 | awk '{print $4}')
        echo "   Disk space: ℹ️ Available: $disk_info"
    fi
    
    echo "ℹ️ Diagnostic complete - build will continue regardless of warnings"
}

backup_successful_build_state() {
    local backup_dir="$ROOT_DIR/builds/environment_backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup Poetry state
    /opt/homebrew/bin/poetry env info > "$backup_dir/poetry_env_info.txt"
    /opt/homebrew/bin/poetry run pip freeze > "$backup_dir/requirements_snapshot.txt"
    /opt/homebrew/bin/poetry config --list > "$backup_dir/poetry_config.txt"
    
    # Backup build script state
    cp "$ROOT_DIR/builds/common/scripts/build_backend.sh" "$backup_dir/"
    cp "$ROOT_DIR/pyproject.toml" "$backup_dir/"
    cp "$ROOT_DIR/poetry.lock" "$backup_dir/"
    
    # Keep only last 10 backups
    ls -dt builds/environment_backups/* 2>/dev/null | tail -n +11 | xargs rm -rf 2>/dev/null || true
    
    echo "✅ Environment state backed up to: $backup_dir"
}

# Timestamp for the main output directory
TIMESTAMP=$(date "+%Y%m%d_%H%M%S")
MAIN_OUTPUT_DIR="$ROOT_DIR/builds/outputs/$TIMESTAMP"

# Define PYTHON_CMD to use python3 if available, otherwise python
if command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
elif command -v python &> /dev/null; then
    PYTHON_CMD="python"
else
    echo "❌ Error: Python interpreter (python3 or python) not found. Please install Python."
    exit 1
fi
echo "🐍 Using Python command: $PYTHON_CMD"

# Diagnostic environment check (informational only)
diagnostic_build_check

# Define sub-directories for backend and frontend packages
BACKEND_DEST_DIR="$MAIN_OUTPUT_DIR/backend"
FRONTEND_APP_DEST_DIR="$MAIN_OUTPUT_DIR/frontend" # This will contain BasilClient.app

# Log file for this master script
PRIMARY_LOG_FILE="$MAIN_OUTPUT_DIR/build_app.log"

# Secondary debug log file location
DEBUG_LOG_DIR="$ROOT_DIR/BasilDebugLogs" # At project root
DEBUG_LOG_FILE="$DEBUG_LOG_DIR/build_app_$TIMESTAMP.log" # Timestamped to distinguish different build runs' logs

# Function for logging with timestamp
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Create directories
mkdir -p "$MAIN_OUTPUT_DIR"
mkdir -p "$DEBUG_LOG_DIR"
mkdir -p "$BACKEND_DEST_DIR"
mkdir -p "$FRONTEND_APP_DEST_DIR"

# Start logging for this script (tee to console and file)
exec &> >(tee -a "$PRIMARY_LOG_FILE" -a "$DEBUG_LOG_FILE")

log "==================== MASTER APPLICATION BUILD STARTING ===================="
log "Root Project Directory: $ROOT_DIR"
log "Main Output Directory: $MAIN_OUTPUT_DIR"
log "Backend Destination: $BACKEND_DEST_DIR"
log "Frontend App Destination: $FRONTEND_APP_DEST_DIR"

# --- 0. Reset TCC Permissions (for development) ---
log "🛡️ STEP 0: Resetting TCC permissions for Basil components..."
if [ -f "$SCRIPT_DIR/reset_basil_permissions.sh" ]; then
    if ! "$SCRIPT_DIR/reset_basil_permissions.sh"; then
        log "⚠️ Warning: reset_basil_permissions.sh script executed but reported an error. Check its output."
        # Decide if this should be a fatal error. For now, let's warn and continue.
    else
        log "✅ TCC permissions reset successfully."
    fi
else
    log "⚠️ Warning: reset_basil_permissions.sh not found at $SCRIPT_DIR/reset_basil_permissions.sh. Skipping permission reset."
fi

# --- Determine signing identity for all builds ---
if [ "$USE_DEVELOPER_ID" = true ]; then
    SIGNING_IDENTITY="$DEVELOPER_ID_CERT"
    log "🔐 Using Developer ID signing: $DEVELOPER_ID_CERT"
else
    SIGNING_IDENTITY="-"
    log "🔐 Using ad-hoc signing for development"
fi

# --- 1. Build Backend --- 
log "🔩 STEP 1: Building Backend..."
# Pass the intended backend destination directly to build_backend.sh
if ! "$SCRIPT_DIR/build_backend.sh" "$BACKEND_DEST_DIR" "$SIGNING_IDENTITY"; then
    log "❌ Backend build failed! Check $BACKEND_DEST_DIR/build.log for details."
    exit 1
fi
log "✅ Backend build successful. Output at: $BACKEND_DEST_DIR"

# --- 2. Build Frontend --- 
log "🖥️ STEP 2: Building Frontend (.app bundle)..."
CLIENT_SRC_ABS_PATH="$ROOT_DIR/BasilClient"

log "Building frontend with signing identity: $SIGNING_IDENTITY"

if ! "$SCRIPT_DIR/build_frontend.sh" "$CLIENT_SRC_ABS_PATH" "$FRONTEND_APP_DEST_DIR" "$SIGNING_IDENTITY"; then
    log "❌ Frontend build failed! Check console output from build_frontend.sh for details."
    exit 1
fi
log "✅ Frontend build successful. BasilClient.app should be at: $FRONTEND_APP_DEST_DIR/BasilClient.app"

log "==================== MASTER APPLICATION BUILD FINISHED ===================="
log "Build artifacts are in: $MAIN_OUTPUT_DIR"

# --- PHASE 4: Create Master Application Bundle ---
log "PHASE 4: Creating Master Application Bundle (Basil.app)..."

MASTER_APP_NAME="Basil.app"
MASTER_APP_PATH="$MAIN_OUTPUT_DIR/$MASTER_APP_NAME"
MASTER_APP_CONTENTS_PATH="$MASTER_APP_PATH/Contents"
MASTER_APP_MACOS_PATH="$MASTER_APP_CONTENTS_PATH/MacOS"
MASTER_APP_RESOURCES_PATH="$MASTER_APP_CONTENTS_PATH/Resources"

log "Creating directory structure for $MASTER_APP_NAME..."
mkdir -p "$MASTER_APP_MACOS_PATH"
mkdir -p "$MASTER_APP_RESOURCES_PATH"

# Copy the entire BasilClient.app as the foundation
CLIENT_APP_SRC_PATH="$FRONTEND_APP_DEST_DIR/BasilClient.app"
if [ -d "$CLIENT_APP_SRC_PATH" ]; then
    log "Copying BasilClient.app as foundation for $MASTER_APP_NAME..."
    cp -R "$CLIENT_APP_SRC_PATH/"* "$MASTER_APP_PATH/"
    log "✅ BasilClient.app copied as foundation"
else
    log "❌ Error: BasilClient.app not found at $CLIENT_APP_SRC_PATH. Cannot create $MASTER_APP_NAME."
    exit 1
fi

log "Copying backend into $MASTER_APP_NAME Resources..."
if [ -d "$BACKEND_DEST_DIR" ]; then
    cp -R "$BACKEND_DEST_DIR/" "$MASTER_APP_RESOURCES_PATH/backend/"
    log "✅ Backend copied to $MASTER_APP_RESOURCES_PATH/backend/"
else
    log "❌ Error: Backend not found at $BACKEND_DEST_DIR. Cannot package into $MASTER_APP_NAME."
    exit 1
fi

log "Copying Frameworks directory into $MASTER_APP_NAME..."
FRAMEWORKS_SRC_DIR="$MAIN_OUTPUT_DIR/Frameworks"
if [ -d "$FRAMEWORKS_SRC_DIR" ]; then
    cp -R "$FRAMEWORKS_SRC_DIR/" "$MASTER_APP_RESOURCES_PATH/Frameworks/"
    log "✅ Frameworks directory copied successfully"
else
    log "⚠️ Warning: Frameworks directory not found at $FRAMEWORKS_SRC_DIR - app may not be self-contained"
fi

log "Copying common dependencies (ffmpeg, sox, etc.) into $MASTER_APP_NAME Resources/dependencies/libs..."
COMMON_DEPS_SRC_DIR="$ROOT_DIR/builds/common/dependencies/libs"
MASTER_APP_DEPS_LIBS_PATH="$MASTER_APP_RESOURCES_PATH/dependencies/libs"

mkdir -p "$MASTER_APP_DEPS_LIBS_PATH"

if [ -d "$COMMON_DEPS_SRC_DIR" ] && [ -n "$(find "$COMMON_DEPS_SRC_DIR" -maxdepth 1 -type f -print -quit)" ]; then
    cp -R "$COMMON_DEPS_SRC_DIR/"* "$MASTER_APP_DEPS_LIBS_PATH/"
    log "✅ Common dependencies copied to $MASTER_APP_DEPS_LIBS_PATH"
else
    log "⚠️ Warning: Common dependencies source directory $COMMON_DEPS_SRC_DIR is empty or not found. App may be missing critical libraries like ffmpeg."
fi

# Update bundle identifier and app name
log "Updating bundle identifier for master app..."
MASTER_BUNDLE_ID="com.stratten.basil"
if plutil -replace CFBundleIdentifier -string "$MASTER_BUNDLE_ID" "$MASTER_APP_CONTENTS_PATH/Info.plist"; then
    log "🔧 Updated CFBundleIdentifier to $MASTER_BUNDLE_ID in master Info.plist"
else
    log "❌ ERROR: Failed to update CFBundleIdentifier in master Info.plist."
fi

# Update bundle name to "Basil"
if plutil -replace CFBundleName -string "Basil" "$MASTER_APP_CONTENTS_PATH/Info.plist"; then
    log "🔧 Updated CFBundleName to Basil in master Info.plist"
else
    log "❌ ERROR: Failed to update CFBundleName in master Info.plist."
fi

# Update bundle display name to "Basil" for system UI and permission dialogs
if plutil -replace CFBundleDisplayName -string "Basil" "$MASTER_APP_CONTENTS_PATH/Info.plist"; then
    log "🔧 Updated CFBundleDisplayName to Basil in master Info.plist"
else
    log "❌ ERROR: Failed to update CFBundleDisplayName in master Info.plist."
fi

# Ensure CFBundleExecutable points to BasilClient (the actual executable)
if plutil -replace CFBundleExecutable -string "BasilClient" "$MASTER_APP_CONTENTS_PATH/Info.plist"; then
    log "🔧 Set CFBundleExecutable to BasilClient in master Info.plist"
else
    log "❌ ERROR: Failed to set CFBundleExecutable in master Info.plist."
fi

log "✅ Master application $MASTER_APP_NAME created at $MASTER_APP_PATH"

# Deep sign all binaries FIRST for notarization compatibility
log "🔍 Deep signing all binaries within the application..."
DEEP_SIGN_SCRIPT="$SCRIPT_DIR/deep_sign_app.sh"
ENTITLEMENTS_PATH="$ROOT_DIR/BasilClient/Sources/Support/Basil.entitlements"

if [ -x "$DEEP_SIGN_SCRIPT" ]; then
    if "$DEEP_SIGN_SCRIPT" "$MASTER_APP_PATH" --entitlements "$ENTITLEMENTS_PATH"; then
        log "✅ Deep signing completed successfully"
    else
        log "❌ ERROR: Deep signing failed"
        exit 1
    fi
else
    log "❌ ERROR: Deep signing script not found or not executable at $DEEP_SIGN_SCRIPT"
    exit 1
fi

# Handle relocatable Python bundled in backend (no Python.framework)
RELOC_PY_DIR="$MASTER_APP_PATH/Contents/Resources/backend/python"
if [ -d "$RELOC_PY_DIR" ]; then
    log "🐍 Found bundled relocatable Python at $RELOC_PY_DIR"
    # Sign Python binaries and extensions to satisfy Gatekeeper
    if [ "$SIGNING_IDENTITY" != "-" ]; then
        find "$RELOC_PY_DIR" -type f \( -name "*.dylib" -o -name "*.so" -o -perm -111 \) -print0 | while IFS= read -r -d '' bin; do
            codesign --force --sign "$SIGNING_IDENTITY" --timestamp --options runtime "$bin" 2>/dev/null || true
        done
        # Ensure main interpreter is signed with entitlements
        if [ -f "$RELOC_PY_DIR/bin/python3" ]; then
            codesign --force --sign "$SIGNING_IDENTITY" --entitlements "$ENTITLEMENTS_PATH" --timestamp --options runtime "$RELOC_PY_DIR/bin/python3" 2>/dev/null || true
        fi
        if [ -f "$RELOC_PY_DIR/bin/python3.11" ]; then
            codesign --force --sign "$SIGNING_IDENTITY" --entitlements "$ENTITLEMENTS_PATH" --timestamp --options runtime "$RELOC_PY_DIR/bin/python3.11" 2>/dev/null || true
        fi
    else
        log "ℹ️ Ad-hoc signing selected; skipping Developer ID signing for relocatable Python"
    fi
    log "✅ Relocatable Python prepared (no framework bundle present)"
else
    log "ℹ️ No Python.framework expected. Using bundled relocatable Python at Resources/backend/python"
fi

# Sign the master application with entitlements
log "🔐 Code signing master application with entitlements..."

# Use the same signing identity determined earlier
if [ "$SIGNING_IDENTITY" = "-" ]; then
    SIGN_OPTIONS=""
    log "Using ad-hoc signing for development"
else
    SIGN_OPTIONS="--timestamp --options runtime"
    log "Using Developer ID certificate: $SIGNING_IDENTITY"
fi

# First, explicitly re-sign the main executable to ensure consistency
MAIN_EXECUTABLE_PATH="$MASTER_APP_MACOS_PATH/BasilClient"
if [ -f "$MAIN_EXECUTABLE_PATH" ]; then
    log "🖋️ Re-signing main executable: $MAIN_EXECUTABLE_PATH"
    codesign --force --sign "$SIGNING_IDENTITY" --entitlements "$ENTITLEMENTS_PATH" $SIGN_OPTIONS "$MAIN_EXECUTABLE_PATH"
    log "✅ Main executable re-signed successfully"
else
    log "❌ ERROR: Main executable not found at $MAIN_EXECUTABLE_PATH"
    exit 1
fi

# Finally, sign the master application bundle
log "🖋️ Signing master application bundle: $MASTER_APP_PATH"
if ! codesign --force --sign "$SIGNING_IDENTITY" --entitlements "$ENTITLEMENTS_PATH" $SIGN_OPTIONS "$MASTER_APP_PATH"; then
    log "❌ ERROR: Failed to sign master application bundle"
    exit 1
fi
log "✅ Code signing successful for $MASTER_APP_NAME"

log "🎉 BUILD COMPLETE! Master application ready at: $MASTER_APP_PATH"
log "To run: open \"$MASTER_APP_PATH\""

# --- End of Phase 4 ---

# --- PHASE 5: Create DMG (Optional) ---
if [ "$CREATE_DMG" = true ]; then
    log "🎁 PHASE 5: Creating DMG Distribution Package..."
    
    # The create_dmg.sh script looks for the latest build automatically
    # Since we just created the build, it will find our $MAIN_OUTPUT_DIR
    DMG_SCRIPT_PATH="$SCRIPT_DIR/create_dmg.sh"
    
    if [ -x "$DMG_SCRIPT_PATH" ]; then
        log "Calling DMG creation script: $DMG_SCRIPT_PATH"
        if "$DMG_SCRIPT_PATH"; then
            log "✅ DMG created successfully!"
            # The DMG script outputs the final DMG path, but we can also determine it
            DMG_PATH="$MAIN_OUTPUT_DIR/Basil-$TIMESTAMP.dmg"
            if [ -f "$DMG_PATH" ]; then
                DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
                log "📦 DMG Distribution Package: $DMG_PATH"
                log "📊 DMG Size: $DMG_SIZE"
            fi
        else
            log "⚠️ Warning: DMG creation failed, but application bundle is still available"
        fi
    else
        log "❌ Error: DMG creation script not found or not executable at $DMG_SCRIPT_PATH"
        log "   Application bundle is still available at $MASTER_APP_PATH"
    fi
else
    log "ℹ️  DMG creation skipped. Use --create-dmg flag to create distribution package."
fi

# --- PHASE 6: Notarize (Optional) ---
if [ "$NOTARIZE" = true ]; then
    log "🍎 PHASE 6: Submitting for Apple Notarization..."
    
    NOTARIZE_SCRIPT="$SCRIPT_DIR/notarize_app.sh"
    DMG_FILE="$MAIN_OUTPUT_DIR/Basil-$TIMESTAMP.dmg"
    
    if [ ! -f "$NOTARIZE_SCRIPT" ]; then
        log "❌ ERROR: Notarization script not found at $NOTARIZE_SCRIPT"
        exit 1
    fi
    
    if [ ! -f "$DMG_FILE" ]; then
        log "❌ ERROR: DMG not found at $DMG_FILE. Cannot submit for notarization."
        exit 1
    fi
    
    log "🚀 Submitting app and DMG for notarization..."
    log "   This process may take 5-15 minutes depending on Apple's servers."
    
    if "$NOTARIZE_SCRIPT" "$MASTER_APP_PATH" --dmg "$DMG_FILE"; then
        log "✅ Notarization completed successfully!"
        log "🛡️ Your app should now launch without malware warnings on other machines."
        log "📦 Notarized DMG: $DMG_FILE"
        if [ -f "$DMG_FILE" ]; then
            FINAL_DMG_SIZE=$(du -h "$DMG_FILE" | cut -f1)
            log "📊 Final DMG Size: $FINAL_DMG_SIZE"
        fi
    else
        log "❌ ERROR: Notarization failed. Check the output above for details."
        log "   The app bundle and DMG are still available, but may show warnings on other machines."
        log "   You can manually notarize later using: $NOTARIZE_SCRIPT $MASTER_APP_PATH --dmg $DMG_FILE"
        exit 1
    fi
else
    log "ℹ️  Notarization skipped. Use --notarize flag to submit to Apple for malware scanning."
    if [ "$CREATE_DMG" = true ]; then
        log "   Manual notarization: $SCRIPT_DIR/notarize_app.sh $MASTER_APP_PATH --dmg $MAIN_OUTPUT_DIR/Basil-$TIMESTAMP.dmg"
    fi
fi

log "==================== FULL APPLICATION BUILD AND PACKAGING COMPLETE ===================="
log "Final application bundle: $MASTER_APP_PATH"
if [ "$CREATE_DMG" = true ] && [ -f "$MAIN_OUTPUT_DIR/Basil-$TIMESTAMP.dmg" ]; then
    log "Final distribution package: $MAIN_OUTPUT_DIR/Basil-$TIMESTAMP.dmg"
fi 

# Backup successful build state
backup_successful_build_state 
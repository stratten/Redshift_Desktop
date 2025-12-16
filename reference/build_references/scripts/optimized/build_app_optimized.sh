#!/bin/bash
# Exit on error
set -e

# Parse command line arguments
CREATE_DMG=false
SHOW_HELP=false

for arg in "$@"; do
    case $arg in
        --create-dmg)
            CREATE_DMG=true
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
    echo "  -h, --help      Show this help message"
    echo ""
    echo "Output:"
    echo "  Creates timestamped directory in builds/outputs/ with:"
    echo "  - Basil.app (master application bundle)"
    echo "  - Individual backend/ and frontend/ components"
    echo "  - Optional Basil-TIMESTAMP.dmg (if --create-dmg specified)"
    exit 0
fi

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR="$( cd "$SCRIPT_DIR/../../../.." && pwd )"

# Timestamp for the main output directory
TIMESTAMP=$(date "+%Y%m%d_%H%M%S")
MAIN_OUTPUT_DIR="$ROOT_DIR/builds/outputs/$TIMESTAMP"

# Define sub-directories for backend and frontend packages
BACKEND_DEST_DIR="$MAIN_OUTPUT_DIR/backend"
FRONTEND_APP_DEST_DIR="$MAIN_OUTPUT_DIR/frontend" # This will contain BasilClient.app

# Log file for this master script
LOG_FILE="$MAIN_OUTPUT_DIR/build_app.log"

# Function for logging with timestamp
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Create directories
mkdir -p "$MAIN_OUTPUT_DIR"
mkdir -p "$BACKEND_DEST_DIR"
mkdir -p "$FRONTEND_APP_DEST_DIR"

# Start logging for this script (tee to console and file)
exec &> >(tee -a "$LOG_FILE")

log "==================== MASTER APPLICATION BUILD STARTING ===================="
log "Root Project Directory: $ROOT_DIR"
log "Main Output Directory: $MAIN_OUTPUT_DIR"
log "Backend Destination: $BACKEND_DEST_DIR"
log "Frontend App Destination: $FRONTEND_APP_DEST_DIR"

# --- 1. Build Backend --- 
log "🔩 STEP 1: Building Backend..."
# Pass the intended backend destination directly to build_backend.sh
# This requires build_backend.sh to be modified to accept this as its primary output location.
# For now, we assume build_backend.sh is modified to use the passed argument.
# If not, the alternative is to find the latest build and copy, which is less clean.
if ! "$SCRIPT_DIR/build_backend_optimized.sh" "$BACKEND_DEST_DIR"; then
    log "❌ Backend build failed! Check $BACKEND_DEST_DIR/build.log for details."
    exit 1
fi
log "✅ Backend build successful. Output at: $BACKEND_DEST_DIR"


# --- 2. Build Frontend --- 
log "🖥️ STEP 2: Building Frontend (.app bundle)..."
CLIENT_SRC_ABS_PATH="$ROOT_DIR/BasilClient"
if ! "$SCRIPT_DIR/../build_frontend.sh" "$CLIENT_SRC_ABS_PATH" "$FRONTEND_APP_DEST_DIR"; then
    log "❌ Frontend build failed! Check console output from build_frontend.sh for details."
    exit 1
fi
log "✅ Frontend build successful. BasilClient.app should be at: $FRONTEND_APP_DEST_DIR/BasilClient.app"


# --- 3. Prepare Launcher Script --- 
# The launcher_script.sh is designed to run from a directory that contains 
# 'backend' and 'frontend' subdirectories.
# So, we copy it into $MAIN_OUTPUT_DIR.
LAUNCHER_SCRIPT_DEST_PATH="$MAIN_OUTPUT_DIR/launch_basil.sh"
log "🚀 STEP 3: Preparing Master Launcher Script..."
cp "$SCRIPT_DIR/../launcher_script.sh" "$LAUNCHER_SCRIPT_DEST_PATH"
chmod +x "$LAUNCHER_SCRIPT_DEST_PATH"
log "✅ Master Launcher script copied to $LAUNCHER_SCRIPT_DEST_PATH"
log "   This script expects to find ./backend and ./frontend relative to its location."

# --- (Future Steps) --- 
# TODO: Add steps for creating a DMG from $MAIN_OUTPUT_DIR
# This would involve: 
#   - Creating a temporary DMG build folder.
#   - Copying $FRONTEND_APP_DEST_DIR/BasilClient.app into it.
#   - Copying $BACKEND_DEST_DIR (as a hidden folder or into BasilClient.app/Contents/Resources) 
#   - Copying the LAUNCHER_SCRIPT_DEST_PATH (perhaps modified to be the main app executable or called by it)
#   - Using hdiutil to create the DMG.

log "==================== MASTER APPLICATION BUILD FINISHED ===================="
log "Build artifacts are in: $MAIN_OUTPUT_DIR"
log "To run the application (using the prepared launcher):
  cd "$MAIN_OUTPUT_DIR"
  ./launch_basil.sh
"

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

# Ensure CFBundleExecutable points to BasilClient (the actual executable)
if plutil -replace CFBundleExecutable -string "BasilClient" "$MASTER_APP_CONTENTS_PATH/Info.plist"; then
    log "🔧 Set CFBundleExecutable to BasilClient in master Info.plist"
else
    log "❌ ERROR: Failed to set CFBundleExecutable in master Info.plist."
fi

log "✅ Master application $MASTER_APP_NAME created at $MASTER_APP_PATH"

# Sign the master application with entitlements
log "🔐 Code signing master application with entitlements..."
ENTITLEMENTS_PATH="$ROOT_DIR/BasilClient/Sources/Support/Basil.entitlements"
if [ -f "$ENTITLEMENTS_PATH" ]; then
    if codesign --force --deep --sign - --entitlements "$ENTITLEMENTS_PATH" "$MASTER_APP_PATH"; then
        log "✅ Code signing successful for $MASTER_APP_NAME"
    else
        log "⚠️ Warning: Code signing failed for $MASTER_APP_NAME, but proceeding..."
    fi
else
    log "⚠️ Warning: Entitlements file not found at $ENTITLEMENTS_PATH, signing without entitlements..."
    if codesign --force --deep --sign - "$MASTER_APP_PATH"; then
        log "✅ Code signing successful for $MASTER_APP_NAME (without entitlements)"
    else
        log "⚠️ Warning: Code signing failed for $MASTER_APP_NAME, but proceeding..."
    fi
fi

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

log "==================== FULL APPLICATION BUILD AND PACKAGING COMPLETE ===================="
log "Final application bundle: $MASTER_APP_PATH"
if [ "$CREATE_DMG" = true ] && [ -f "$MAIN_OUTPUT_DIR/Basil-$TIMESTAMP.dmg" ]; then
    log "Final distribution package: $MAIN_OUTPUT_DIR/Basil-$TIMESTAMP.dmg"
fi 
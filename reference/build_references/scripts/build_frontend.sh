#!/bin/bash
# Exit on error
set -e

# Arguments:
# $1: Absolute path to the BasilClient source directory (e.g., /Users/user/Desktop/Basil/BasilClient)
# $2: Absolute path to the frontend destination directory (e.g., /Users/user/Desktop/Basil/builds/output/YYYYMMDD_HHMMSS/frontend)
# $3: (Optional) Code signing identity - defaults to ad-hoc ("-") if not provided

CLIENT_SRC_DIR="$1"
FRONTEND_DEST_DIR="$2"
CODE_SIGN_IDENTITY="${3:--}"  # Use provided identity or default to ad-hoc

# Function for logging with timestamp
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

if [ -z "$CLIENT_SRC_DIR" ] || [ -z "$FRONTEND_DEST_DIR" ]; then
  log "❌ ERROR: Source directory or destination directory not provided."
  log "Usage: ./build_frontend.sh <path_to_BasilClient_src> <path_to_frontend_dest_dir> [code_sign_identity]"
  exit 1
fi

log "🚀 Starting Frontend Build Script..."
log "Client Source: $CLIENT_SRC_DIR"
log "Frontend Destination Root: $FRONTEND_DEST_DIR"

# Ensure script is running from its own directory to resolve relative paths if any (though we use absolute)
cd "$CLIENT_SRC_DIR"
log "Current directory: $(pwd)"

# Generate standard production icons before building
log "🎨 Generating standard production icons..."
SCRIPTS_DIR="$(dirname "$CLIENT_SRC_DIR")/scripts"
PYTHON_CMD="python3"

if [ -f "$SCRIPTS_DIR/generate_icons.py" ]; then
    if ! $PYTHON_CMD "$SCRIPTS_DIR/generate_icons.py" --variant=standard; then
        log "❌ Error: Failed to generate standard production icons. Please check scripts/generate_icons.py"
        exit 1
    fi
    log "✅ Standard production icons generated successfully"
else
    log "⚠️ Warning: Icon generation script not found at $SCRIPTS_DIR/generate_icons.py"
fi

log "🧹 Cleaning previous Swift build artifacts (full clean of .build)..."
rm -rf .build
log "🧹 Cleaning Swift package state..."
swift package clean
swift package reset
# swift package resolve # Uncomment if you face resolution issues; usually not needed if Package.resolved is committed

log "📦 Building Swift application (release configuration)..."
if ! swift build --configuration release -Xswiftc -suppress-warnings; then
    log "❌ Swift build failed!"
    exit 1
fi
log "✅ Swift application built successfully."

# Define paths for the .app bundle
APP_NAME="BasilClient.app"
APP_BUNDLE_PATH="$FRONTEND_DEST_DIR/$APP_NAME"
log "🛠️ Creating application bundle at: $APP_BUNDLE_PATH"

# Create bundle structure
mkdir -p "$APP_BUNDLE_PATH/Contents/MacOS"
mkdir -p "$APP_BUNDLE_PATH/Contents/Resources"
mkdir -p "$APP_BUNDLE_PATH/Contents/Frameworks" # For any bundled frameworks/dylibs later

log "📄 Copying Info.plist..."
INFO_PLIST_PATH="Sources/Support/Info.plist"
if [ -f "$INFO_PLIST_PATH" ]; then
    cp "$INFO_PLIST_PATH" "$APP_BUNDLE_PATH/Contents/"
else
    log "⚠️ Warning: $INFO_PLIST_PATH not found. The app bundle will be missing Info.plist."
fi

log "📦 Copying executable..."
# Default Swift executable name matches the package name (now BasilClient)
BUILT_EXECUTABLE_NAME="BasilClient"
BUILT_EXECUTABLE_PATH=".build/release/$BUILT_EXECUTABLE_NAME"

if [ -f "$BUILT_EXECUTABLE_PATH" ]; then
    cp "$BUILT_EXECUTABLE_PATH" "$APP_BUNDLE_PATH/Contents/MacOS/$BUILT_EXECUTABLE_NAME"
else
    log "❌ Error: Executable not found at $BUILT_EXECUTABLE_PATH. Check your Swift package's target name."
    exit 1
fi

log "🎨 Copying application icon..."
# Always (re)generate AppIcon.icns from the freshly created AppIcon.appiconset
APPICONSET_DIR="$CLIENT_SRC_DIR/Sources/Resources/Assets.xcassets/AppIcon.appiconset"
TEMP_ICONSET_DIR=".build/AppIcon.iconset"
mkdir -p "$TEMP_ICONSET_DIR"

if [ -d "$APPICONSET_DIR" ]; then
    log "🎨 Rebuilding AppIcon.icns from asset catalog..."
    rm -rf "$TEMP_ICONSET_DIR"
    mkdir -p "$TEMP_ICONSET_DIR"
    for size in 16 32 64 128 256 512 1024; do
        [ -f "$APPICONSET_DIR/icon_${size}x${size}.png" ] && cp "$APPICONSET_DIR/icon_${size}x${size}.png" "$TEMP_ICONSET_DIR/icon_${size}x${size}.png"
        [ -f "$APPICONSET_DIR/icon_${size}x${size}@2x.png" ] && cp "$APPICONSET_DIR/icon_${size}x${size}@2x.png" "$TEMP_ICONSET_DIR/icon_${size}x${size}@2x.png"
    done
    if /usr/bin/iconutil -c icns "$TEMP_ICONSET_DIR" -o "$APP_BUNDLE_PATH/Contents/Resources/AppIcon.icns"; then
        log "✅ AppIcon.icns regenerated and copied to app bundle."
    else
        log "⚠️ Warning: Failed to regenerate AppIcon.icns; continuing without custom icon."
    fi
else
    log "⚠️ Warning: AppIcon.appiconset not found at $APPICONSET_DIR."
fi

# Copy additional client resources including Assets.xcassets
log "📦 Copying additional client resources..."
CLIENT_RESOURCES_DIR="Sources/Resources"
if [ -d "$CLIENT_RESOURCES_DIR" ]; then
    log "📁 Copying from $CLIENT_RESOURCES_DIR to app bundle resources..."
    cp -R "$CLIENT_RESOURCES_DIR/"* "$APP_BUNDLE_PATH/Contents/Resources/"
    log "✅ Client resources copied successfully"
else
    log "⚠️ Warning: Client resources directory not found at $CLIENT_RESOURCES_DIR"
fi

# --- Copy Dependencies (Frameworks) ---
log "📦 Copying framework dependencies (e.g., HotKey.framework)..."
# SPM usually puts framework products directly in the .build/release directory
# The exact name might vary if HotKey package product name is different or if it's a .dylib
# Assuming HotKey.framework is the target
BUILT_FRAMEWORK_PATH=".build/release/HotKey.framework"
DEST_FRAMEWORKS_DIR="$APP_BUNDLE_PATH/Contents/Frameworks"

if [ -d "$BUILT_FRAMEWORK_PATH" ]; then
    cp -R "$BUILT_FRAMEWORK_PATH" "$DEST_FRAMEWORKS_DIR/"
    log "✅ Copied HotKey.framework to $DEST_FRAMEWORKS_DIR"
else
    log "⚠️ Warning: HotKey.framework not found at $BUILT_FRAMEWORK_PATH. If it's a dynamic dependency, the app may crash."
    log "   (Looking for .build/release/HotKey.framework)"
fi
# --- End Copy Dependencies ---

# Specifically copy status bar icons if they exist as standalone PNG files
log "🎨 Ensuring status bar icons are available..."
STATUS_BAR_ICONS=("StatusBarIcon.png" "StatusBarIconActive.png" "StatusBarIconRecording.png")
for icon in "${STATUS_BAR_ICONS[@]}"; do
    ICON_PATH="$CLIENT_RESOURCES_DIR/$icon"
    if [ -f "$ICON_PATH" ]; then
        cp "$ICON_PATH" "$APP_BUNDLE_PATH/Contents/Resources/"
        log "✅ Copied $icon to app bundle"
    else
        log "⚠️ Warning: Status bar icon $icon not found at $ICON_PATH"
    fi
done

# Copy StatusBarResources directory if it exists (for development compatibility)
if [ -d "Sources/StatusBarResources" ]; then
    log "📦 Copying StatusBarResources directory..."
    cp -R "Sources/StatusBarResources" "$APP_BUNDLE_PATH/Contents/Resources/StatusBarResources"
    log "✅ StatusBarResources copied successfully"
fi

# --- Code Signing ---
log "🔐 Signing application bundle..."

ENTITLEMENTS_PATH="$CLIENT_SRC_DIR/Sources/Support/Basil.entitlements"

if [ ! -f "$ENTITLEMENTS_PATH" ]; then
    log "❌ Error: Entitlements file not found at $ENTITLEMENTS_PATH"
    exit 1
fi

log "📝 Using entitlements file: $ENTITLEMENTS_PATH"

# Sign the main executable first
log "🖋️ Signing main executable: $APP_BUNDLE_PATH/Contents/MacOS/$BUILT_EXECUTABLE_NAME"
codesign --force --sign "$CODE_SIGN_IDENTITY" --entitlements "$ENTITLEMENTS_PATH" --timestamp --options runtime "$APP_BUNDLE_PATH/Contents/MacOS/$BUILT_EXECUTABLE_NAME"

# Then sign the application bundle itself
log "🖋️ Signing application bundle: $APP_BUNDLE_PATH"
codesign --force --sign "$CODE_SIGN_IDENTITY" --entitlements "$ENTITLEMENTS_PATH" --timestamp --options runtime "$APP_BUNDLE_PATH"

log "✅ Application bundle signed."
# --- End Code Signing ---

log "✅ Frontend .app bundle created successfully at $APP_BUNDLE_PATH" 
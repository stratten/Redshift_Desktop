#!/bin/bash
# Deep Code Signing Script for Basil
# Signs all .dylib, .so, and executable files within an app bundle

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
    echo "Deep signs all binaries within a macOS app bundle for notarization."
    echo ""
    echo "Arguments:"
    echo "  app_path              Path to the .app bundle"
    echo "  --entitlements path   Path to entitlements file (optional)"
    echo ""
    echo "What this script signs:"
    echo "  - All .dylib files (dynamic libraries)"
    echo "  - All .so files (Python extensions)"
    echo "  - All executable files"
    echo "  - Excludes: .o files, .a files, scripts, test data"
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

# Build signing command with universal binary support
if [[ -n "$ENTITLEMENTS_PATH" && -f "$ENTITLEMENTS_PATH" ]]; then
    SIGN_CMD="codesign --force --timestamp --options runtime --entitlements \"$ENTITLEMENTS_PATH\" --sign \"$SIGNING_IDENTITY\""
    log "Using entitlements: $ENTITLEMENTS_PATH"
else
    # For executables without entitlements, still need hardened runtime for notarization
    SIGN_CMD="codesign --force --timestamp --options runtime --sign \"$SIGNING_IDENTITY\""
    log "No entitlements file specified - using hardened runtime for all binaries"
fi

log "🔍 Starting deep code signing for: $APP_PATH"
log "🔐 Signing identity: $SIGNING_IDENTITY"

# Function to sign a file with universal binary support
sign_file() {
    local file="$1"
    local relative_path="${file#$APP_PATH/}"
    
    echo "  📝 Signing: $relative_path"
    
    # Check if it's a universal binary and sign all architectures
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

# Export the function so it can be used with find -exec
export -f sign_file
export SIGN_CMD
export APP_PATH
export SIGNING_IDENTITY

# Count files to sign (follow symlinks with -L)
DYLIB_COUNT=$(find -L "$APP_PATH" -name "*.dylib" | wc -l | tr -d ' ')
SO_COUNT=$(find -L "$APP_PATH" -name "*.so" | wc -l | tr -d ' ')
EXEC_COUNT=$(find -L "$APP_PATH" -type f -perm +111 ! -name "*.dylib" ! -name "*.so" ! -name "*.py" ! -name "*.txt" ! -name "*.json" ! -name "*.plist" ! -name "*.md" ! -name "*.rst" ! -name "*.cfg" ! -name "*.ini" ! -name "*.conf" ! -name "*.yml" ! -name "*.yaml" ! -name "*.xml" ! -name "*.html" ! -name "*.css" ! -name "*.js" ! -name "*.sh" ! -name "*.pl" ! -name "*.rb" ! -name "*.gz" ! -name "*.tar" ! -name "*.zip" ! -name "*.o" ! -name "*.a" | wc -l | tr -d ' ')

TOTAL_COUNT=$((DYLIB_COUNT + SO_COUNT + EXEC_COUNT))
log "📊 Found $TOTAL_COUNT binaries to sign:"
log "    - $DYLIB_COUNT .dylib files"
log "    - $SO_COUNT .so files" 
log "    - $EXEC_COUNT executables"

if [[ $TOTAL_COUNT -eq 0 ]]; then
    log "✅ No binaries found to sign"
    exit 0
fi

# Handle JAR files with embedded binaries
log "📦 Processing JAR files with embedded binaries..."
JAR_COUNT=$(find -L "$APP_PATH" -name "*.jar" | wc -l | tr -d ' ')
if [[ $JAR_COUNT -gt 0 ]]; then
    log "   Found $JAR_COUNT JAR files to process"
    find -L "$APP_PATH" -name "*.jar" | while read -r jar_file; do
        jar_name=$(basename "$jar_file")
        log "   🔍 Checking $jar_name for embedded binaries..."
        
        # Extract JAR to temporary directory
        temp_dir=$(mktemp -d)
        original_dir=$(pwd)
        cd "$temp_dir"
        unzip -q "$jar_file" 2>/dev/null || { cd "$original_dir"; rm -rf "$temp_dir"; continue; }
        
        # Find and sign binaries in extracted JAR
        binary_files=$(find . -name "*.dylib" -o -name "*.jnilib" 2>/dev/null)
        if [[ -n "$binary_files" ]]; then
            echo "     Found binaries to sign in $jar_name"
            echo "$binary_files" | while read -r binary; do
                if [[ -f "$binary" ]]; then
                    echo "     📝 Signing embedded binary: $binary"
                    eval "$SIGN_CMD \"$binary\"" 2>/dev/null || echo "     ⚠️  Failed to sign: $binary"
                fi
            done
            
            echo "     📦 Repackaging $jar_name with signed binaries..."
            zip -qr "$jar_file" . 2>/dev/null || echo "     ⚠️  Failed to repackage $jar_name"
        else
            echo "     No binaries found in $jar_name"
        fi
        
        cd "$original_dir"
        rm -rf "$temp_dir"
    done
else
    log "   No JAR files found"
fi

# Remove problematic files that can't be signed
log "🧹 Removing unsignable files..."
find "$APP_PATH" -name "*.o" -delete
find "$APP_PATH" -name "*.a" -delete
log "   Removed .o and .a files (unsignable)"

# Sign .dylib files
if [[ $DYLIB_COUNT -gt 0 ]]; then
    log "🔗 Signing .dylib files..."
    find -L "$APP_PATH" -name "*.dylib" -exec bash -c '
        # Sign Python framework dylibs individually to avoid bundle format ambiguity
        sign_file "$0"
    ' {} \;
fi

# Sign .so files (Python extension modules)
if [[ $SO_COUNT -gt 0 ]]; then
    log "🐍 Signing .so files (Python extensions)..."
    find -L "$APP_PATH" -name "*.so" -exec bash -c '
        # Sign Python framework .so files individually to avoid bundle format ambiguity
        sign_file "$0"
    ' {} \;
fi

# Sign .jnilib files (Java native libraries)
JNILIB_COUNT=$(find -L "$APP_PATH" -name "*.jnilib" | wc -l | tr -d ' ')
if [[ $JNILIB_COUNT -gt 0 ]]; then
    log "☕ Signing .jnilib files..."
    find -L "$APP_PATH" -name "*.jnilib" -exec bash -c 'sign_file "$0"' {} \;
fi

# Sign executables (excluding common non-binary files and scripts) 
if [[ $EXEC_COUNT -gt 0 ]]; then
    log "⚡ Signing executable files..."
    find -L "$APP_PATH" -type f -perm +111 \
        ! -name "*.dylib" ! -name "*.so" ! -name "*.jnilib" \
        ! -name "*.py" ! -name "*.txt" ! -name "*.json" ! -name "*.plist" \
        ! -name "*.md" ! -name "*.rst" ! -name "*.cfg" ! -name "*.ini" \
        ! -name "*.conf" ! -name "*.yml" ! -name "*.yaml" ! -name "*.xml" \
        ! -name "*.html" ! -name "*.css" ! -name "*.js" ! -name "*.sh" \
        ! -name "*.pl" ! -name "*.rb" ! -name "*.gz" ! -name "*.tar" \
        ! -name "*.zip" ! -name "*.jar" \
        -exec bash -c '
            # Skip script files, main executable, and Python framework binaries
            if file "$0" | grep -q "script\|text"; then
                echo "  ℹ️  Skipping script: ${0##*/}"
            elif [[ "$0" == */Contents/MacOS/* ]]; then
                echo "  ℹ️  Skipping main executable (signed separately): ${0##*/}"
            else
                # Sign all executables including Python framework binaries
                sign_file "$0"
            fi
        ' {} \;
fi

# Sign framework bundles last (after all their internal binaries are signed)
log "🏗️ Signing framework bundles..."
find -L "$APP_PATH" -name "*.framework" -type d | while read framework; do
    relative_path="${framework#$APP_PATH/}"
    
    # Skip Python framework - we handle it separately in build_app.sh after removing embedded Python.app
    if [[ "$framework" == *"Python.framework" ]]; then
        echo "  ℹ️  Skipping Python.framework (handled separately to avoid bundle format ambiguity)"
        continue
    fi
    
    echo "  📦 Signing framework bundle: $relative_path"
    
    # Standard framework signing
    eval "$SIGN_CMD \"$framework\"" 2>/dev/null || {
        echo "  ⚠️  Failed to sign framework bundle: $relative_path"
        exit 1
    }
done

log "✅ Deep code signing completed successfully"
log "📦 App bundle is ready for notarization" 
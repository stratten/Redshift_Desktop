#!/opt/homebrew/bin/bash

# Use relocatable Python for self-contained backend builds
# This eliminates Poetry dependencies and Python.framework bundling complexity

# Exit on error
set -e

# Get absolute paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Path to our relocatable Python distribution
RELOCATABLE_PYTHON_DIR="$SCRIPT_DIR/../python/python"
RELOCATABLE_PYTHON_BIN="$RELOCATABLE_PYTHON_DIR/bin/python3"

# Build hardening functions
diagnostic_build_check() {
    echo "🔍 Diagnostic build environment check..."
    
    # Check relocatable Python
    if [ -x "$RELOCATABLE_PYTHON_BIN" ]; then
        local python_version=$("$RELOCATABLE_PYTHON_BIN" --version 2>&1)
        echo "   Relocatable Python: ✅ Available ($python_version)"
    else
        echo "   Relocatable Python: ❌ Not found at $RELOCATABLE_PYTHON_BIN"
        echo "   Run: Download python-build-standalone Python 3.11.13 to builds/common/python/"
        return 1
    fi
    
    # Check pip in relocatable Python
    if [ -x "$RELOCATABLE_PYTHON_DIR/bin/pip" ]; then
        local pip_version=$("$RELOCATABLE_PYTHON_DIR/bin/pip" --version 2>&1 | head -1)
        echo "   Relocatable pip: ✅ Available ($pip_version)"
    else
        echo "   Relocatable pip: ❌ Not found"
        return 1
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
    
    echo "ℹ️ Diagnostic complete"
}

# Get the directory where this script is located
BUILD_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"
SRC_DIR="$ROOT_DIR/Basil/src"
CONFIG_DIR="$ROOT_DIR/Basil/src/config"

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "❌ ERROR: Incorrect number of arguments supplied to build_backend.sh"
    echo "Usage: $0 <BACKEND_DEST> [SIGNING_IDENTITY]"
    echo "  BACKEND_DEST: Directory where the built backend will be placed"
    echo "  SIGNING_IDENTITY: Optional code signing identity (e.g., 'Developer ID Application: ...')"
    exit 1
fi

BACKEND_DEST="$1"
SIGNING_IDENTITY="${2:-"-"}"  # Default to ad-hoc signing if not provided

# Validate the provided backend destination directory
if [ -z "$BACKEND_DEST" ]; then
    echo "❌ ERROR: BACKEND_DEST argument is empty or not provided."
    exit 1
fi

# Ensure BACKEND_DEST is an absolute path
if [[ "$BACKEND_DEST" != /* ]]; then
    BACKEND_DEST="$(pwd)/$BACKEND_DEST"
fi

echo "🔧 Backend Build Configuration:"
echo "   Backend Destination: $BACKEND_DEST"
echo "   Signing Identity: $SIGNING_IDENTITY"
echo "   Root Directory: $ROOT_DIR"
echo "   Source Directory: $SRC_DIR"
echo "   Relocatable Python: $RELOCATABLE_PYTHON_BIN"

# Create the backend destination directory structure
mkdir -p "$BACKEND_DEST"

# Set up logging to both console and file
LOG_FILE="$BACKEND_DEST/backend_build.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Output_DIR is the parent of BACKEND_DEST, e.g., .../output/TIMESTAMP/
# This might be useful if any script operations needed to reference that parent.
OUTPUT_DIR="$(dirname "$BACKEND_DEST")"

# Directory for libraries (relative to the script's location or root)
LIBS_DIR="$BUILD_DIR/dependencies/libs"

# Diagnostic environment check
if ! diagnostic_build_check; then
    echo "❌ ERROR: Environment check failed. Cannot proceed with build."
    exit 1
fi

# Verify relocatable Python works
echo "🐍 Verifying relocatable Python..."
PYTHON_VERSION=$("$RELOCATABLE_PYTHON_BIN" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
echo "🐍 Using relocatable Python: $("$RELOCATABLE_PYTHON_BIN" -c 'import sys; print(sys.executable)') (Version: $PYTHON_VERSION)"

PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)

if ! ( [ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -eq 11 ] ); then
    echo "❌ ERROR: Incorrect Python version. Found $PYTHON_VERSION, but project requires Python 3.11."
    exit 1
fi

# Ensure output directories exist
mkdir -p "$LIBS_DIR"

# Generate requirements.txt from Poetry (we still use Poetry for development dependency management)
PROJECT_ROOT_FOR_POETRY="$ROOT_DIR"
if [ -f "$PROJECT_ROOT_FOR_POETRY/poetry.lock" ]; then
    # Try to find Poetry command
    POETRY_CMD=""
    if command -v /opt/homebrew/bin/poetry &> /dev/null; then
        POETRY_CMD="/opt/homebrew/bin/poetry"
    elif command -v poetry &> /dev/null; then
        POETRY_CMD="poetry"
    else
        echo "❌ ERROR: Poetry not found. Please install Poetry to generate requirements.txt."
        exit 1
    fi
    
    echo "📦 Generating requirements.txt with Poetry from $PROJECT_ROOT_FOR_POETRY using $POETRY_CMD..."
    (cd "$PROJECT_ROOT_FOR_POETRY" && $POETRY_CMD run pip freeze | grep -v "^datasets=" | grep -v -E "(^basil|^-e.*basil)" > "$BACKEND_DEST/requirements.txt")
    if [ ! -f "$BACKEND_DEST/requirements.txt" ]; then
        echo "❌ ERROR: requirements.txt was not created by poetry from $PROJECT_ROOT_FOR_POETRY."
        exit 1
    fi
    echo "✅ requirements.txt generated successfully"
else
    if [ -f "$SRC_DIR/requirements.txt" ]; then
        echo "📦 Copying requirements.txt from $SRC_DIR to $BACKEND_DEST..."
        cp "$SRC_DIR/requirements.txt" "$BACKEND_DEST/requirements.txt"
        if [ ! -f "$BACKEND_DEST/requirements.txt" ]; then
            echo "❌ ERROR: Failed to copy requirements.txt to $BACKEND_DEST."
            exit 1
        fi
    else
        echo "⚠️ No poetry.lock found at $PROJECT_ROOT_FOR_POETRY/poetry.lock and no requirements.txt found at $SRC_DIR/requirements.txt."
        echo "❌ ERROR: Cannot proceed without dependency information."
        exit 1
    fi
fi

# Copy the entire relocatable Python distribution to backend
cd "$BACKEND_DEST"
echo "🐍 Copying relocatable Python distribution..."
cp -R "$RELOCATABLE_PYTHON_DIR" "$BACKEND_DEST/python"

# Create the Python environment using the bundled Python
echo "🐍 Installing dependencies using bundled Python..."
BUNDLED_PYTHON="$BACKEND_DEST/python/bin/python3"
BUNDLED_PIP="$BACKEND_DEST/python/bin/pip"

# Install dependencies from the generated requirements.txt
if [ -f "$BACKEND_DEST/requirements.txt" ]; then
    echo "🐍 Installing dependencies from requirements.txt into bundled Python..."
    "$BUNDLED_PIP" install -r "$BACKEND_DEST/requirements.txt"
else
    echo "❌ ERROR: requirements.txt not found at $BACKEND_DEST/requirements.txt."
    exit 1
fi

# Copy backend source code
cd "$SRC_DIR"
echo "📦 Copying backend source code..."
rsync -av --progress \
    --exclude='__pycache__/' \
    --exclude='*.pyc' \
    --exclude='build/' \
    --exclude='dist/' \
    --exclude='.pytest_cache/' \
    --exclude='*.egg-info/' \
    --exclude='.git/' \
    --exclude='.vscode/' \
    --exclude='.idea/' \
    --exclude='*.log' \
    --exclude='server_port' \
    --exclude='.server_port' \
    ./ "$BACKEND_DEST/src/"

echo "✅ Backend source code copied successfully"

# --- Bundle OpenWakeWord Models ---
echo "📦 Downloading and bundling OpenWakeWord models for wake word detection..."
MODELS_DIR="$BACKEND_DEST/wake_word_models"
mkdir -p "$MODELS_DIR"

# Download the hey_jarvis model using the Python environment
echo "  Downloading hey_jarvis model..."
cd "$BACKEND_DEST"
"$BACKEND_DEST/python/bin/python" -c "
try:
    from openwakeword.utils import download_models
    import os
    models_dir = '$MODELS_DIR'
    os.makedirs(models_dir, exist_ok=True)
    
    # Download hey_jarvis model
    print('Downloading hey_jarvis model...')
    download_models(model_names=['hey_jarvis'], target_directory=models_dir)
    print(f'✅ OpenWakeWord models downloaded to {models_dir}')
    
    # List downloaded files
    import glob
    model_files = glob.glob(os.path.join(models_dir, '*.onnx'))
    print(f'Downloaded model files: {model_files}')
    
except ImportError as e:
    print(f'❌ Error: OpenWakeWord not installed in virtual environment: {e}')
    exit(1)
except Exception as e:
    print(f'❌ Error downloading OpenWakeWord models: {e}')
    exit(1)
"

if [ $? -eq 0 ]; then
    echo "✅ OpenWakeWord models downloaded successfully"
    # List the downloaded models for verification
    echo "📋 Downloaded wake word models:"
    ls -la "$MODELS_DIR"
    
    # Copy support models to OpenWakeWord package directory
    echo "📦 Copying OpenWakeWord support models to package directory..."
    OWW_PACKAGE_MODELS_DIR="$BACKEND_DEST/python/lib/python3.11/site-packages/openwakeword/resources/models"
    mkdir -p "$OWW_PACKAGE_MODELS_DIR"
    if [ -d "$OWW_PACKAGE_MODELS_DIR" ]; then
        cp "$MODELS_DIR/melspectrogram.onnx" "$OWW_PACKAGE_MODELS_DIR/" 2>/dev/null || echo "⚠️ melspectrogram.onnx not found"
        cp "$MODELS_DIR/embedding_model.onnx" "$OWW_PACKAGE_MODELS_DIR/" 2>/dev/null || echo "⚠️ embedding_model.onnx not found"
        cp "$MODELS_DIR/silero_vad.onnx" "$OWW_PACKAGE_MODELS_DIR/" 2>/dev/null || echo "⚠️ silero_vad.onnx not found"
        echo "✅ Support models copied to OpenWakeWord package directory"
    else
        echo "⚠️ OpenWakeWord package models directory not found: $OWW_PACKAGE_MODELS_DIR"
    fi
else
    echo "❌ ERROR: Failed to download OpenWakeWord models"
    exit 1
fi
# --- End OpenWakeWord Model Bundling ---

# Copy backend startup script
echo "📦 Copying backend startup script..."
BACKEND_STARTUP_SCRIPT="$SCRIPT_DIR/start_backend.sh"
if [ -f "$BACKEND_STARTUP_SCRIPT" ]; then
    cp "$BACKEND_STARTUP_SCRIPT" "$BACKEND_DEST/start_backend.sh"
    chmod +x "$BACKEND_DEST/start_backend.sh"
    echo "✅ Backend startup script copied to $BACKEND_DEST/start_backend.sh"
else
    echo "⚠️ Warning: Backend startup script not found at $BACKEND_STARTUP_SCRIPT"
fi

# Copy required libraries (e.g., sox) directly to backend destination
echo "📦 Copying required libraries directly to backend destination..."
if [ -f "/opt/homebrew/Cellar/sox/14.4.2_6/lib/libsox.dylib" ]; then
    # Copy directly to backend destination instead of creating symlinks
    cp "/opt/homebrew/Cellar/sox/14.4.2_6/lib/libsox.dylib" "$BACKEND_DEST/libsox.dylib"
    cp "/opt/homebrew/Cellar/sox/14.4.2_6/lib/libsox.3.dylib" "$BACKEND_DEST/libsox.3.dylib" 2>/dev/null || :
    
    # Also copy to common libs directory for reference
    mkdir -p "$LIBS_DIR"
    cp "/opt/homebrew/Cellar/sox/14.4.2_6/lib/libsox.dylib" "$LIBS_DIR/"
    cp "/opt/homebrew/Cellar/sox/14.4.2_6/lib/libsox.3.dylib" "$LIBS_DIR/" 2>/dev/null || :
    
    echo "✅ libsox copied as actual files (not symlinks) to $BACKEND_DEST"
else
    echo "⚠️ Warning: libsox not found at expected Homebrew location"
fi

# Copy tesseract executable and dependencies
echo "📦 Copying tesseract executable and primary dependencies..."
mkdir -p "$BACKEND_DEST/bin"
mkdir -p "$BACKEND_DEST/dependencies/libs"

# Destination for all bundled dylibs
BUNDLED_LIBS_DIR="$BACKEND_DEST/dependencies/libs"

# --- Bundle Tesseract using CMake ---
echo "📦 Bundling Tesseract using CMake..."
CMAKE_BUNDLER_DIR="$ROOT_DIR/builds/common/cmake/TesseractBundler"
CMAKE_BUILD_DIR="$BACKEND_DEST/tesseract_cmake_build" # Temporary build dir for CMake

# Ensure CMAKE_INSTALL_PREFIX is absolute for CMake to correctly install into bundle structure
# BACKEND_DEST is already absolute due to earlier script logic.
CMAKE_INSTALL_PREFIX_ABS="$BACKEND_DEST"

echo "  CMake Source Dir: $CMAKE_BUNDLER_DIR"
echo "  CMake Build Dir (temp): $CMAKE_BUILD_DIR"
echo "  CMake Install Prefix (target): $CMAKE_INSTALL_PREFIX_ABS"

# It's good practice to remove the CMake build directory if it exists from a previous run
rm -rf "$CMAKE_BUILD_DIR"
mkdir -p "$CMAKE_BUILD_DIR"

# Run CMake configuration
echo "  Configuring Tesseract CMake project..."
cmake -S "$CMAKE_BUNDLER_DIR" -B "$CMAKE_BUILD_DIR" -DCMAKE_INSTALL_PREFIX="$CMAKE_INSTALL_PREFIX_ABS"
if [ $? -ne 0 ]; then
    echo "❌ ERROR: CMake configuration for Tesseract failed."
    exit 1
fi

# Run CMake install
echo "  Installing Tesseract via CMake..."
cmake --install "$CMAKE_BUILD_DIR" --verbose
if [ $? -ne 0 ]; then
    echo "❌ ERROR: CMake installation for Tesseract failed."
    exit 1
fi

# Cleanup temporary CMake build directory
echo "  Cleaning up temporary CMake build directory: $CMAKE_BUILD_DIR"
rm -rf "$CMAKE_BUILD_DIR"
echo "✅ Tesseract bundled successfully using CMake."
# --- End of CMake Tesseract Bundling ---

# --- Bundle Libsndfile and Dependencies using CMake & Fix Python's soundfile module ---
echo "📦 Bundling Libsndfile and its dependencies via CMake..."
LIBSNDFILE_BUNDLER_CMAKE_DIR="${ROOT_DIR}/builds/common/cmake/LibsndfileBundler"
# Temporary build directory for this CMake project, inside BACKEND_DEST for self-containment during build
LIBSNDFILE_BUNDLER_CMAKE_BUILD_DIR="${BACKEND_DEST}/libsndfile_cmake_build"

# CMAKE_INSTALL_PREFIX_ABS is already defined and set to BACKEND_DEST for Tesseract. We use the same.
# LibsndfileBundler's CMakeLists.txt will install into "dependencies/libs_sndfile_bundle" under this prefix.
EFFECTIVE_STAGED_LIBSNDFILE_DYLIBS_PATH="${CMAKE_INSTALL_PREFIX_ABS}/dependencies/libs_sndfile_bundle"

echo "  LibsndfileBundler CMake Source Dir: ${LIBSNDFILE_BUNDLER_CMAKE_DIR}"
echo "  LibsndfileBundler CMake Build Dir (temp): ${LIBSNDFILE_BUNDLER_CMAKE_BUILD_DIR}"
echo "  LibsndfileBundler CMake Install Prefix (target root): ${CMAKE_INSTALL_PREFIX_ABS}"
echo "  Effective path for staged good dylibs: ${EFFECTIVE_STAGED_LIBSNDFILE_DYLIBS_PATH}"

rm -rf "${LIBSNDFILE_BUNDLER_CMAKE_BUILD_DIR}" # Clean previous build
mkdir -p "${LIBSNDFILE_BUNDLER_CMAKE_BUILD_DIR}"

echo "  Configuring LibsndfileBundler CMake project..."
cmake -S "${LIBSNDFILE_BUNDLER_CMAKE_DIR}" -B "${LIBSNDFILE_BUNDLER_CMAKE_BUILD_DIR}" -DCMAKE_INSTALL_PREFIX="${CMAKE_INSTALL_PREFIX_ABS}"
if [ $? -ne 0 ]; then
    echo "❌ ERROR: CMake configuration for LibsndfileBundler failed."
    exit 1
fi

echo "  Installing LibsndfileBundler artifacts via CMake..."
# Using --build and --install separately can sometimes be more reliable or offer better logging.
cmake --build "${LIBSNDFILE_BUNDLER_CMAKE_BUILD_DIR}" --verbose
if [ $? -ne 0 ]; then
    echo "❌ ERROR: CMake build for LibsndfileBundler failed."
    exit 1
fi
DEVELOPER_ID_CERT="$SIGNING_IDENTITY" cmake --install "${LIBSNDFILE_BUNDLER_CMAKE_BUILD_DIR}" --verbose
if [ $? -ne 0 ]; then
    echo "❌ ERROR: CMake installation for LibsndfileBundler failed."
    exit 1
fi

echo "  Cleaning up temporary CMake build directory for Libsndfile: ${LIBSNDFILE_BUNDLER_CMAKE_BUILD_DIR}"
rm -rf "${LIBSNDFILE_BUNDLER_CMAKE_BUILD_DIR}"
echo "✅ Libsndfile and dependencies bundled via CMake into ${EFFECTIVE_STAGED_LIBSNDFILE_DYLIBS_PATH}"

# Now, fix the Python soundfile module to use these bundled libraries.
# The venv is located at $BACKEND_DEST/venv
FINAL_VENV_PATH_FOR_FIX_SCRIPT="${BACKEND_DEST}/python"

echo "🔧 Running fix_soundfile_module_dylibs.sh to point Python's soundfile to our new dylibs..."
FIX_SOUNDFILE_SCRIPT_PATH="${LIBSNDFILE_BUNDLER_CMAKE_DIR}/fix_soundfile_module_dylibs.sh" # Path to the .sh script itself
chmod +x "${FIX_SOUNDFILE_SCRIPT_PATH}"

echo "  Calling ${FIX_SOUNDFILE_SCRIPT_PATH} with:"
echo "    Venv Path: ${FINAL_VENV_PATH_FOR_FIX_SCRIPT}"
echo "    Staged Libsndfile Bundle Dir (containing good dylibs): ${EFFECTIVE_STAGED_LIBSNDFILE_DYLIBS_PATH}"

if [ ! -d "${FINAL_VENV_PATH_FOR_FIX_SCRIPT}" ]; then
    echo "🔴 ERROR: Final Venv Path for fix_soundfile_module_dylibs.sh does not exist: ${FINAL_VENV_PATH_FOR_FIX_SCRIPT}"
    exit 1
fi
if [ ! -d "${EFFECTIVE_STAGED_LIBSNDFILE_DYLIBS_PATH}" ]; then
    echo "🔴 ERROR: Staged dylibs path for fix_soundfile_module_dylibs.sh does not exist: ${EFFECTIVE_STAGED_LIBSNDFILE_DYLIBS_PATH}"
    echo "         Expected CMake to create it via LibsndfileBundler."
    exit 1
fi

"${FIX_SOUNDFILE_SCRIPT_PATH}" "${FINAL_VENV_PATH_FOR_FIX_SCRIPT}" "${EFFECTIVE_STAGED_LIBSNDFILE_DYLIBS_PATH}"
if [ $? -ne 0 ]; then
    echo "❌ ERROR: fix_soundfile_module_dylibs.sh failed."
    exit 1
fi
echo "✅ fix_soundfile_module_dylibs.sh completed successfully."
# --- End of Libsndfile Bundling and Python soundfile fix ---

echo "======================================================================"
echo "🚀 INTENDING TO START FFmpeg Bundler Section 🚀"
echo "======================================================================"
# --- Bundle FFmpeg using CMake ---
echo "📦 Bundling FFmpeg and its dependencies via CMake..."
FFMPEG_BUNDLER_CMAKE_DIR="${ROOT_DIR}/builds/common/cmake/FFmpegBundler"
# Temporary build directory for this CMake project, inside BACKEND_DEST
FFMPEG_BUNDLER_CMAKE_BUILD_DIR="${BACKEND_DEST}/ffmpeg_cmake_build"

# CMAKE_INSTALL_PREFIX_ABS is already defined and set to BACKEND_DEST.
# FFmpegBundler's CMakeLists.txt will install into bin/ and dependencies/libs/ under this prefix.

echo "  FFmpegBundler CMake Source Dir: ${FFMPEG_BUNDLER_CMAKE_DIR}"
echo "  FFmpegBundler CMake Build Dir (temp): ${FFMPEG_BUNDLER_CMAKE_BUILD_DIR}"
echo "  FFmpegBundler CMake Install Prefix (target root): ${CMAKE_INSTALL_PREFIX_ABS}"

rm -rf "${FFMPEG_BUNDLER_CMAKE_BUILD_DIR}" # Clean previous build
mkdir -p "${FFMPEG_BUNDLER_CMAKE_BUILD_DIR}"

echo "  STEP 1: Configuring FFmpegBundler CMake project..."
cmake -S "${FFMPEG_BUNDLER_CMAKE_DIR}" -B "${FFMPEG_BUNDLER_CMAKE_BUILD_DIR}" -DCMAKE_INSTALL_PREFIX="${CMAKE_INSTALL_PREFIX_ABS}"
FFMPEG_CMAKE_CONFIG_EC=$?
echo "  STEP 1 EXIT CODE: ${FFMPEG_CMAKE_CONFIG_EC}"
if [ $FFMPEG_CMAKE_CONFIG_EC -ne 0 ]; then
    echo "❌ ERROR: CMake configuration for FFmpegBundler failed. Exit Code: ${FFMPEG_CMAKE_CONFIG_EC}"
    exit 1
fi
echo "  STEP 1 COMPLETED."

echo "  STEP 2: Building FFmpegBundler artifacts via CMake..."
cmake --build "${FFMPEG_BUNDLER_CMAKE_BUILD_DIR}" --verbose
FFMPEG_CMAKE_BUILD_EC=$?
echo "  STEP 2 EXIT CODE: ${FFMPEG_CMAKE_BUILD_EC}"
if [ $FFMPEG_CMAKE_BUILD_EC -ne 0 ]; then
    echo "❌ ERROR: CMake build for FFmpegBundler failed. Exit Code: ${FFMPEG_CMAKE_BUILD_EC}"
    exit 1
fi
echo "  STEP 2 COMPLETED."

echo "  STEP 3: Installing FFmpegBundler artifacts (triggers prepare_ffmpeg_bundle.sh)..."
DEVELOPER_ID_CERT="$SIGNING_IDENTITY" cmake --install "${FFMPEG_BUNDLER_CMAKE_BUILD_DIR}" --verbose
FFMPEG_CMAKE_INSTALL_EC=$?
echo "  STEP 3 EXIT CODE: ${FFMPEG_CMAKE_INSTALL_EC}"
if [ $FFMPEG_CMAKE_INSTALL_EC -ne 0 ]; then
    echo "❌ ERROR: CMake installation for FFmpegBundler (and execution of prepare_ffmpeg_bundle.sh) failed. Exit Code: ${FFMPEG_CMAKE_INSTALL_EC}"
    exit 1
fi
echo "  STEP 3 COMPLETED."

echo "  Cleaning up temporary CMake build directory for FFmpeg: ${FFMPEG_BUNDLER_CMAKE_BUILD_DIR}"
rm -rf "${FFMPEG_BUNDLER_CMAKE_BUILD_DIR}"
echo "✅ FFmpeg and dependencies bundled successfully using FFmpegBundler CMake project."
# --- End of FFmpeg Bundling ---
echo "======================================================================"
echo "🏁 COMPLETED FFmpeg Bundler Section 🏁"
echo "======================================================================"

# --- CRITICAL: Verify FFmpeg Bundling Actually Works ---
echo "🔍 VERIFYING FFmpeg bundling success..."
BUNDLED_FFMPEG_PATH="${BACKEND_DEST}/bin/ffmpeg"
BUNDLED_FFMPEG_DEPS_DIR="${BACKEND_DEST}/dependencies/libs"

echo "  Checking bundled FFmpeg executable: ${BUNDLED_FFMPEG_PATH}"
if [ -f "${BUNDLED_FFMPEG_PATH}" ]; then
    echo "  ✅ FFmpeg executable exists"
    
    # Check if executable
    if [ -x "${BUNDLED_FFMPEG_PATH}" ]; then
        echo "  ✅ FFmpeg executable has execute permissions"
        
        # Test FFmpeg version (critical test)
        echo "  🧪 Testing FFmpeg version command..."
        if FFMPEG_VERSION_OUTPUT=$("${BUNDLED_FFMPEG_PATH}" -version 2>&1); then
            echo "  ✅ FFmpeg version test PASSED"
            echo "  📋 FFmpeg version info:"
            echo "${FFMPEG_VERSION_OUTPUT}" | head -n 3 | sed 's/^/      /'
        else
            echo "  ❌ ERROR: FFmpeg version test FAILED"
            echo "  📋 FFmpeg version error output:"
            echo "${FFMPEG_VERSION_OUTPUT}" | sed 's/^/      /'
            echo "  🚨 This will cause voice command audio capture to fail!"
            # Don't exit - let build continue but warn loudly
        fi
        
        # FFmpeg audio device access will be handled at runtime with proper permissions
        echo "  ℹ️  FFmpeg bundled successfully - audio device access will be requested at runtime"
        echo "  📋 Voice commands use dual capture architecture (FFmpeg + Swift AudioCaptureService)"
        
    else
        echo "  ❌ ERROR: FFmpeg executable lacks execute permissions"
        echo "  🔧 Attempting to fix permissions..."
        chmod +x "${BUNDLED_FFMPEG_PATH}"
        if [ -x "${BUNDLED_FFMPEG_PATH}" ]; then
            echo "  ✅ Execute permissions fixed"
        else
            echo "  ❌ ERROR: Could not fix execute permissions"
        fi
    fi
else
    echo "  ❌ ERROR: FFmpeg executable not found at ${BUNDLED_FFMPEG_PATH}"
    echo "  🚨 Voice command functionality will completely fail!"
fi

# Verify FFmpeg dependencies directory
echo "  Checking FFmpeg dependencies: ${BUNDLED_FFMPEG_DEPS_DIR}"
if [ -d "${BUNDLED_FFMPEG_DEPS_DIR}" ]; then
    FFMPEG_DYLIB_COUNT=$(find "${BUNDLED_FFMPEG_DEPS_DIR}" -name "*.dylib" | wc -l)
    echo "  ✅ FFmpeg dependencies directory exists with ${FFMPEG_DYLIB_COUNT} dylib files"
    
    # List key FFmpeg libraries
    echo "  📋 Key FFmpeg libraries found:"
    find "${BUNDLED_FFMPEG_DEPS_DIR}" -name "libav*.dylib" -o -name "libsw*.dylib" | head -n 8 | sed 's/^/      /'
else
    echo "  ❌ ERROR: FFmpeg dependencies directory not found"
    echo "  🚨 FFmpeg will fail to run due to missing dependencies!"
fi

echo "🔍 FFmpeg bundling verification complete"
echo "======================================================================"
# --- End FFmpeg Verification ---

# Copy additional audio libraries (libsndfile, portaudio)
# libsndfile is now handled by LibsndfileBundler, portaudio might still be needed if not pulled in by ffmpeg.
echo "📦 Checking/Copying additional audio libraries (PortAudio)..."

# portaudio (for audio capture - if not already handled by another bundler)
# We should verify if ffmpeg or other dependencies already bundle portaudio correctly.
# For now, let's keep this direct copy minimal and verify its necessity later.
PORTAUDIO_COPIED_FLAG=false
for portaudio_lib_pattern in "/opt/homebrew/lib/libportaudio.dylib" "/opt/homebrew/lib/libportaudio.2.dylib" "/opt/homebrew/lib/libportaudiocpp.dylib" "/opt/homebrew/lib/libportaudiocpp.0.dylib"; do
    # Use find to handle cases where the exact symlink/file might not exist but a version does
    # This is a bit safer than direct -f checks on patterns
    found_portaudio_lib=$(find /opt/homebrew/lib -maxdepth 1 -name "$(basename "$portaudio_lib_pattern")" -print -quit)
    if [ -n "$found_portaudio_lib" ] && [ -f "$found_portaudio_lib" ]; then
        echo "  Found PortAudio library: $found_portaudio_lib"
        # Ensure target directory exists
        mkdir -p "$BUNDLED_LIBS_DIR" # BUNDLED_LIBS_DIR defined earlier as ${BACKEND_DEST}/dependencies/libs
        cp "$found_portaudio_lib" "$BUNDLED_LIBS_DIR/"
        PORTAUDIO_COPIED_FLAG=true
    fi
done

if [ "$PORTAUDIO_COPIED_FLAG" = true ]; then
    echo "✅ PortAudio libraries copied to $BUNDLED_LIBS_DIR (if found)."
    echo "   Further path fixing for PortAudio might be needed if it has its own dependencies not covered by FFmpegBundler."
    echo "   Consider creating a PortAudioBundler if issues persist."
else
    echo "⚠️ No PortAudio libraries matching patterns found in /opt/homebrew/lib, or they failed to copy."
    echo "   Audio capture functionality might be affected if PortAudio is required and not bundled by another process."
fi

# Create startup scripts for the bundled Python
echo "📦 Creating startup scripts for relocatable Python..."

# Create start_backend.sh that uses the bundled Python
echo "ℹ️ Using copied advanced start_backend.sh; skipping heredoc generation"

# Verify the bundled Python distribution is working
echo "🔍 Verifying bundled Python distribution..."
if "$BACKEND_DEST/python/bin/python3" --version; then
    echo "✅ Bundled Python is working correctly"
else
    echo "❌ ERROR: Bundled Python verification failed"
    exit 1
fi

# Test importing key dependencies
echo "🔍 Testing key dependencies..."
"$BACKEND_DEST/python/bin/python3" -c "
import sys
print(f'Python version: {sys.version}')
print(f'Python executable: {sys.executable}')

# Test key imports
try:
    import uvicorn
    print('✅ uvicorn imported successfully')
except ImportError as e:
    print(f'❌ uvicorn import failed: {e}')

try:
    import anthropic
    print('✅ anthropic imported successfully')
except ImportError as e:
    print(f'❌ anthropic import failed: {e}')

try:
    import soundfile
    print('✅ soundfile imported successfully')
except ImportError as e:
    print(f'❌ soundfile import failed: {e}')
" || echo "⚠️ Warning: Some dependency tests failed, but build will continue"

echo "✅ Backend build complete! Backend artifacts saved to: $BACKEND_DEST"
echo "   Build log: $LOG_FILE" 
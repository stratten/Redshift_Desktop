#!/bin/bash

# =============================================================================
# FFmpeg Bundling Test Script
# =============================================================================
# This script isolates the FFmpeg bundling process for rapid iteration
# and testing without requiring full builds.
#
# Usage: ./test_ffmpeg_bundling.sh [output_dir]
# =============================================================================

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
BUILD_OUTPUT_DIR="${1:-${PROJECT_ROOT}/builds/test_ffmpeg_output}"
BACKEND_DEST="${BUILD_OUTPUT_DIR}/backend"

echo "======================================================================="
echo "🧪 FFmpeg Bundling Test Script"
echo "======================================================================="
echo "Project Root: ${PROJECT_ROOT}"
echo "Test Output Dir: ${BUILD_OUTPUT_DIR}"
echo "Backend Dest: ${BACKEND_DEST}"
echo "======================================================================="

# Clean up previous test output
if [ -d "${BUILD_OUTPUT_DIR}" ]; then
    echo "🧹 Cleaning up previous test output..."
    rm -rf "${BUILD_OUTPUT_DIR}"
fi

# Create directory structure
echo "📁 Creating test directory structure..."
mkdir -p "${BACKEND_DEST}/bin"
mkdir -p "${BACKEND_DEST}/dependencies/libs"

# =============================================================================
# FFmpeg Bundling Section (Extracted from build_backend.sh)
# =============================================================================

echo ""
echo "======================================================================="
echo "🎬 STARTING FFmpeg Bundler Section 🎬"
echo "======================================================================="

# Check if CMake is available
if ! command -v cmake &> /dev/null; then
    echo "❌ ERROR: CMake is not installed or not in PATH"
    echo "Please install CMake: brew install cmake"
    exit 1
fi

# Navigate to FFmpeg bundler directory
FFMPEG_BUNDLER_DIR="${PROJECT_ROOT}/builds/common/cmake/FFmpegBundler"
if [ ! -d "${FFMPEG_BUNDLER_DIR}" ]; then
    echo "❌ ERROR: FFmpeg bundler directory not found: ${FFMPEG_BUNDLER_DIR}"
    exit 1
fi

echo "🔧 Using FFmpeg bundler from: ${FFMPEG_BUNDLER_DIR}"

# Create temporary CMake build directory
TEMP_CMAKE_BUILD_DIR="${BACKEND_DEST}/ffmpeg_cmake_build"
mkdir -p "${TEMP_CMAKE_BUILD_DIR}"

echo "📦 Configuring FFmpeg bundling with CMake..."
cd "${TEMP_CMAKE_BUILD_DIR}"

# Configure CMake with destination paths
cmake "${FFMPEG_BUNDLER_DIR}" \
    -DCMAKE_INSTALL_PREFIX="${BACKEND_DEST}" \
    -DFFMPEG_DEST_BIN="${BACKEND_DEST}/bin" \
    -DFFMPEG_DEST_LIBS="${BACKEND_DEST}/dependencies/libs"

if [ $? -ne 0 ]; then
    echo "❌ ERROR: CMake configuration failed"
    exit 1
fi

echo "🏗️ Building and installing FFmpeg bundle..."
make install

FFMPEG_CMAKE_EXIT_CODE=$?
echo "FFmpeg CMake Exit Code: ${FFMPEG_CMAKE_EXIT_CODE}"

if [ ${FFMPEG_CMAKE_EXIT_CODE} -ne 0 ]; then
    echo "❌ ERROR: FFmpeg bundling failed with exit code ${FFMPEG_CMAKE_EXIT_CODE}"
    exit 1
fi

echo "✅ FFmpeg and dependencies bundled successfully using FFmpegBundler CMake project."

# Clean up temporary CMake build directory
echo "🧹 Cleaning up temporary CMake build directory for FFmpeg: ${TEMP_CMAKE_BUILD_DIR}"
rm -rf "${TEMP_CMAKE_BUILD_DIR}"

echo "======================================================================="
echo "🏁 COMPLETED FFmpeg Bundler Section 🏁"
echo "======================================================================="

# =============================================================================
# FFmpeg Verification Section (Enhanced from build_backend.sh)
# =============================================================================

echo ""
echo "🔍 VERIFYING FFmpeg bundling success..."
BUNDLED_FFMPEG_PATH="${BACKEND_DEST}/bin/ffmpeg"
BUNDLED_FFMPEG_DEPS_DIR="${BACKEND_DEST}/dependencies/libs"

echo "  Checking bundled FFmpeg executable: ${BUNDLED_FFMPEG_PATH}"
if [ -f "${BUNDLED_FFMPEG_PATH}" ]; then
    echo "  ✅ FFmpeg executable exists"
    
    # Check if executable has proper permissions
    if [ -x "${BUNDLED_FFMPEG_PATH}" ]; then
        echo "  ✅ FFmpeg executable has execute permissions"
    else
        echo "  ⚠️ FFmpeg executable lacks execute permissions, fixing..."
        chmod +x "${BUNDLED_FFMPEG_PATH}"
        echo "  ✅ Execute permissions fixed"
    fi
    
    # Test FFmpeg version - this will reveal library linking issues
    echo "  🧪 Testing FFmpeg version command..."
    if "${BUNDLED_FFMPEG_PATH}" -version > /dev/null 2> /tmp/ffmpeg_version_error.txt; then
        echo "  ✅ FFmpeg version test PASSED"
        FFMPEG_VERSION=$("${BUNDLED_FFMPEG_PATH}" -version 2>/dev/null | head -1)
        echo "  📋 FFmpeg version: ${FFMPEG_VERSION}"
    else
        echo "  ❌ ERROR: FFmpeg version test FAILED"
        echo "  📋 FFmpeg version error output:"
        sed 's/^/      /' /tmp/ffmpeg_version_error.txt
        echo "  🚨 This will cause voice command audio capture to fail!"
    fi
    
    # FFmpeg audio device access will be handled at runtime with proper permissions
    echo "  ℹ️  FFmpeg bundled successfully - audio device access will be requested at runtime"
    echo "  📋 Voice commands use dual capture architecture (FFmpeg + Swift AudioCaptureService)"
    
else
    echo "  ❌ ERROR: FFmpeg executable not found at expected location"
    echo "  🚨 Voice command functionality will be completely non-functional!"
fi

# Check dependencies directory
echo "  Checking FFmpeg dependencies: ${BUNDLED_FFMPEG_DEPS_DIR}"
if [ -d "${BUNDLED_FFMPEG_DEPS_DIR}" ]; then
    DYLIB_COUNT=$(find "${BUNDLED_FFMPEG_DEPS_DIR}" -name "*.dylib" | wc -l)
    echo "  ✅ FFmpeg dependencies directory exists with ${DYLIB_COUNT} dylib files"
    
    # List key FFmpeg libraries to verify they're present
    echo "  📋 Key FFmpeg libraries found:"
    find "${BUNDLED_FFMPEG_DEPS_DIR}" -name "libswresample*" -o -name "libavcodec*" -o -name "libavdevice*" -o -name "libavfilter*" -o -name "libavformat*" -o -name "libswscale*" | head -10 | sed 's/^/      /'
else
    echo "  ❌ ERROR: FFmpeg dependencies directory not found"
    echo "  🚨 FFmpeg will fail to load required libraries!"
fi

echo "🔍 FFmpeg bundling verification complete"

# =============================================================================
# Enhanced Diagnostics for Missing Dependencies
# =============================================================================

echo ""
echo "======================================================================="
echo "🔬 ENHANCED DEPENDENCY ANALYSIS"
echo "======================================================================="

if [ -f "${BUNDLED_FFMPEG_PATH}" ]; then
    echo "🔍 Analyzing FFmpeg dependency tree..."
    
    # Use otool to check what libraries FFmpeg expects
    echo "📋 FFmpeg direct dependencies:"
    otool -L "${BUNDLED_FFMPEG_PATH}" | sed 's/^/    /'
    
    echo ""
    echo "🔍 Checking for missing dependencies in error output..."
    if [ -f /tmp/ffmpeg_version_error.txt ]; then
        echo "📋 Missing libraries identified from error:"
        grep "Library not loaded:" /tmp/ffmpeg_version_error.txt | sed 's/^/    /' | head -10
        
        echo ""
        echo "🔍 Searching for missing libraries in system..."
        MISSING_LIBS=$(grep "Library not loaded:" /tmp/ffmpeg_version_error.txt | sed 's/.*@rpath\///g' | sed 's/ .*//g' | sort -u)
        
        for lib in $MISSING_LIBS; do
            echo "  🔍 Searching for ${lib}..."
            SYSTEM_LOCATIONS=$(find /opt/homebrew /usr/local -name "${lib}" 2>/dev/null | head -3)
            if [ -n "$SYSTEM_LOCATIONS" ]; then
                echo "    ✅ Found in system:"
                echo "$SYSTEM_LOCATIONS" | sed 's/^/      /'
            else
                echo "    ❌ Not found in common system locations"
            fi
        done
    fi
fi

echo ""
echo "======================================================================="
echo "📊 TEST SUMMARY"
echo "======================================================================="
echo "Test Output Directory: ${BUILD_OUTPUT_DIR}"
echo "FFmpeg Executable: ${BUNDLED_FFMPEG_PATH}"
echo "Dependencies Directory: ${BUNDLED_FFMPEG_DEPS_DIR}"

if [ -f "${BUNDLED_FFMPEG_PATH}" ] && "${BUNDLED_FFMPEG_PATH}" -version > /dev/null 2>&1; then
    echo "🎉 SUCCESS: FFmpeg bundling test PASSED"
    echo "✅ FFmpeg is properly bundled and functional"
else
    echo "💥 FAILURE: FFmpeg bundling test FAILED"
    echo "❌ FFmpeg bundling needs additional work"
    echo ""
    echo "💡 Next steps:"
    echo "   1. Review the missing dependencies listed above"
    echo "   2. Modify the FFmpeg bundler to include missing libraries"
    echo "   3. Re-run this test script to verify fixes"
fi

echo "=======================================================================" 
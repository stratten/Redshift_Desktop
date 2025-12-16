cmake_minimum_required(VERSION 3.15)
project(FFmpegBundler LANGUAGES C CXX)

# --- Locate Homebrew and FFmpeg ---
find_program(HOMEBREW_EXECUTABLE brew)
if(NOT HOMEBREW_EXECUTABLE)
    message(FATAL_ERROR "Homebrew (brew) not found. Please install Homebrew.")
endif()

execute_process(
    COMMAND ${HOMEBREW_EXECUTABLE} --prefix
    OUTPUT_VARIABLE HOMEBREW_PREFIX
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
)
if(NOT HOMEBREW_PREFIX)
    message(FATAL_ERROR "Could not determine Homebrew prefix.")
endif()
message(STATUS "Found Homebrew prefix: ${HOMEBREW_PREFIX}")

find_program(FFMPEG_EXECUTABLE_PATH ffmpeg PATHS "${HOMEBREW_PREFIX}/bin" NO_DEFAULT_PATH)
if(NOT FFMPEG_EXECUTABLE_PATH)
    message(FATAL_ERROR "ffmpeg executable not found in ${HOMEBREW_PREFIX}/bin")
endif()
message(STATUS "Found ffmpeg executable: ${FFMPEG_EXECUTABLE_PATH}")

# Resolve the ffmpeg executable to its real path to avoid installing a symlink
get_filename_component(REAL_FFMPEG_EXECUTABLE_PATH "${FFMPEG_EXECUTABLE_PATH}" REALPATH)
if(NOT EXISTS "${REAL_FFMPEG_EXECUTABLE_PATH}")
    message(FATAL_ERROR "Resolved ffmpeg executable REALPATH does not exist: ${REAL_FFMPEG_EXECUTABLE_PATH} (from ${FFMPEG_EXECUTABLE_PATH})")
endif()
message(STATUS "Resolved ffmpeg executable REALPATH: ${REAL_FFMPEG_EXECUTABLE_PATH}")

# --- Define FFmpeg's Homebrew lib directory ---
# This is typically ${HOMEBREW_PREFIX}/opt/ffmpeg/lib which then symlinks to the Cellar
set(FFMPEG_OPT_LIB_DIR "${HOMEBREW_PREFIX}/opt/ffmpeg/lib")
if(NOT IS_DIRECTORY "${FFMPEG_OPT_LIB_DIR}")
    # Fallback: try to get Cellar path if /opt/ffmpeg/lib doesn't exist (less common)
    execute_process(
        COMMAND ${HOMEBREW_EXECUTABLE} --prefix ffmpeg
        OUTPUT_VARIABLE FFMPEG_CELLAR_PATH_OUTPUT
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
    )
    if(FFMPEG_CELLAR_PATH_OUTPUT AND IS_DIRECTORY "${FFMPEG_CELLAR_PATH_OUTPUT}/lib")
        set(FFMPEG_OPT_LIB_DIR "${FFMPEG_CELLAR_PATH_OUTPUT}/lib")
        message(STATUS "Used FFmpeg Cellar lib directory: ${FFMPEG_OPT_LIB_DIR}")
    else()
        message(FATAL_ERROR "FFmpeg library directory not found at ${HOMEBREW_PREFIX}/opt/ffmpeg/lib or via 'brew --prefix ffmpeg'. Output: ${FFMPEG_CELLAR_PATH_OUTPUT}")
    endif()
else()
    message(STATUS "Using FFmpeg opt lib directory: ${FFMPEG_OPT_LIB_DIR}")
endif()


# --- List of primary FFmpeg dylibs to bundle ---
set(FFMPEG_PRIMARY_DYLIBS
    libavcodec
    libavdevice
    libavfilter
    libavformat
    libavutil
    libpostproc
    libswresample
    libswscale
)

set(FFMPEG_PRIMARY_DYLIBS_PATHS "")
foreach(lib_base_name ${FFMPEG_PRIMARY_DYLIBS})
    # find_library will search for e.g. libavcodec.61.dylib, libavcodec.dylib
    find_library(FOUND_DYLIB_PATH
        NAMES "${lib_base_name}.*.dylib" "${lib_base_name}.dylib" # Prefer versioned, then unversioned
        PATHS "${FFMPEG_OPT_LIB_DIR}"
        NO_DEFAULT_PATH
    )

    if(FOUND_DYLIB_PATH)
        # Resolve symlinks to get the actual file path (likely in Cellar)
        file(REAL_PATH "${FOUND_DYLIB_PATH}" ACTUAL_DYLIB_FILE_PATH)
        if(EXISTS "${ACTUAL_DYLIB_FILE_PATH}")
            message(STATUS "Found primary FFmpeg dylib: ${ACTUAL_DYLIB_FILE_PATH} (from symlink/path: ${FOUND_DYLIB_PATH})")
            list(APPEND FFMPEG_PRIMARY_DYLIBS_PATHS "${ACTUAL_DYLIB_FILE_PATH}")
        else()
            message(WARNING "Primary FFmpeg dylib ${lib_base_name} resolved to non-existent REAL_PATH ${ACTUAL_DYLIB_FILE_PATH} from ${FOUND_DYLIB_PATH}.")
        endif()
    else()
        message(WARNING "Primary FFmpeg dylib ${lib_base_name} not found in ${FFMPEG_OPT_LIB_DIR}. This might be okay if it's not a direct critical dependency or has an unexpected name.")
    endif()
    unset(FOUND_DYLIB_PATH CACHE) # Important for find_library in a loop
endforeach()

if(NOT FFMPEG_PRIMARY_DYLIBS_PATHS)
    message(FATAL_ERROR "No primary FFmpeg dylibs were successfully located. Check FFMPEG_PRIMARY_DYLIBS list and the path ${FFMPEG_OPT_LIB_DIR}.")
endif()

# --- Installation ---
# Use provided destination variables or fall back to CMAKE_INSTALL_PREFIX
if(NOT FFMPEG_DEST_BIN)
    set(FFMPEG_DEST_BIN "${CMAKE_INSTALL_PREFIX}/bin")
endif()
if(NOT FFMPEG_DEST_LIBS)
    set(FFMPEG_DEST_LIBS "${CMAKE_INSTALL_PREFIX}/dependencies/libs")
endif()

message(STATUS "FFmpeg installation destinations:")
message(STATUS "  Executable: ${FFMPEG_DEST_BIN}")
message(STATUS "  Libraries: ${FFMPEG_DEST_LIBS}")

# Install ffmpeg executable (the actual file, not a symlink)
install(
    PROGRAMS "${REAL_FFMPEG_EXECUTABLE_PATH}"
    DESTINATION "${FFMPEG_DEST_BIN}"
    RENAME "ffmpeg"
)
message(STATUS "Installing actual ffmpeg executable from ${REAL_FFMPEG_EXECUTABLE_PATH} to: ${FFMPEG_DEST_BIN}/ffmpeg")

# Install primary FFmpeg dylibs (using their actual resolved paths)
foreach(ACTUAL_DYLIB_FULL_PATH ${FFMPEG_PRIMARY_DYLIBS_PATHS})
    get_filename_component(DYLIB_BASENAME "${ACTUAL_DYLIB_FULL_PATH}" NAME) # Gets the actual versioned name
    install(
        FILES "${ACTUAL_DYLIB_FULL_PATH}"
        DESTINATION "${FFMPEG_DEST_LIBS}"
        RENAME "${DYLIB_BASENAME}" # Install with its true name e.g. libavcodec.61.dylib
    )
    message(STATUS "Installing primary FFmpeg dylib ${DYLIB_BASENAME} from ${ACTUAL_DYLIB_FULL_PATH} to: ${FFMPEG_DEST_LIBS}/")
endforeach()

# Special handling for libjxl_cms if libjxl was bundled
set(JXL_PATH "${FFMPEG_DEST_LIBS}/libjxl.0.11.dylib")
set(JXL_CMS_ORIGINAL_PATH "/opt/homebrew/opt/jpeg-xl/lib/libjxl_cms.0.11.dylib") # Path based on 'brew --prefix jpeg-xl'
set(JXL_CMS_DEST_PATH "${FFMPEG_DEST_LIBS}/libjxl_cms.0.11.dylib")
if(EXISTS ${JXL_PATH} AND EXISTS ${JXL_CMS_ORIGINAL_PATH} AND NOT EXISTS ${JXL_CMS_DEST_PATH})
  message(STATUS "FFmpegBundler: Manually copying libjxl_cms.0.11.dylib because libjxl.0.11.dylib was found in bundle.")
  execute_process(COMMAND ${CMAKE_COMMAND} -E copy_if_different ${JXL_CMS_ORIGINAL_PATH} ${JXL_CMS_DEST_PATH}
                  RESULT_VARIABLE copy_res_jxl_cms
                  OUTPUT_VARIABLE copy_out_jxl_cms
                  ERROR_VARIABLE copy_err_jxl_cms)
  if(NOT copy_res_jxl_cms EQUAL 0)
      message(WARNING "FFmpegBundler: Failed to copy libjxl_cms.0.11.dylib. Error: ${copy_err_jxl_cms}")
  endif()
elseif(EXISTS ${JXL_PATH} AND NOT EXISTS ${JXL_CMS_ORIGINAL_PATH})
    message(WARNING "FFmpegBundler: libjxl.0.11.dylib is bundled, but original libjxl_cms.0.11.dylib not found at ${JXL_CMS_ORIGINAL_PATH}.")
endif()

# Script to fix dylib paths and sign
set(PREPARE_SCRIPT_PATH "${CMAKE_CURRENT_SOURCE_DIR}/prepare_ffmpeg_bundle.sh")

install(CODE "
    # Ensure the script is executable before trying to run it directly
    execute_process(COMMAND chmod +x \"${PREPARE_SCRIPT_PATH}\")

    # Execute the script, relying on its shebang
    execute_process(
        COMMAND \"${PREPARE_SCRIPT_PATH}\" \"${CMAKE_INSTALL_PREFIX}\"
        RESULT_VARIABLE result
    )

    # Check result
    if(NOT result EQUAL 0)
        message(FATAL_ERROR \"prepare_ffmpeg_bundle.sh failed (Exit Code: ${result}). Check install output for script details.\")
    endif()
") # End of install(CODE)

message(STATUS "FFmpegBundler CMake configuration complete. prepare_ffmpeg_bundle.sh will run at install time.") 
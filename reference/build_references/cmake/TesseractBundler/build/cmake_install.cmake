# Install script for directory: /Users/strattenwaldt/Desktop/Basil/builds/common/cmake/TesseractBundler

# Set the install prefix
if(NOT DEFINED CMAKE_INSTALL_PREFIX)
  set(CMAKE_INSTALL_PREFIX "/Users/strattenwaldt/Desktop/Basil/builds/common/cmake/TesseractBundler/test_install")
endif()
string(REGEX REPLACE "/$" "" CMAKE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}")

# Set the install configuration name.
if(NOT DEFINED CMAKE_INSTALL_CONFIG_NAME)
  if(BUILD_TYPE)
    string(REGEX REPLACE "^[^A-Za-z0-9_]+" ""
           CMAKE_INSTALL_CONFIG_NAME "${BUILD_TYPE}")
  else()
    set(CMAKE_INSTALL_CONFIG_NAME "")
  endif()
  message(STATUS "Install configuration: \"${CMAKE_INSTALL_CONFIG_NAME}\"")
endif()

# Set the component getting installed.
if(NOT CMAKE_INSTALL_COMPONENT)
  if(COMPONENT)
    message(STATUS "Install component: \"${COMPONENT}\"")
    set(CMAKE_INSTALL_COMPONENT "${COMPONENT}")
  else()
    set(CMAKE_INSTALL_COMPONENT)
  endif()
endif()

# Is this installation the result of a crosscompile?
if(NOT DEFINED CMAKE_CROSSCOMPILING)
  set(CMAKE_CROSSCOMPILING "FALSE")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "TesseractRuntime" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/bin" TYPE FILE PERMISSIONS OWNER_EXECUTE OWNER_READ GROUP_EXECUTE GROUP_READ WORLD_EXECUTE WORLD_READ FILES "/opt/homebrew/opt/tesseract/bin/tesseract")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "TesseractRuntime" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/dependencies/libs" TYPE FILE PERMISSIONS OWNER_EXECUTE OWNER_READ GROUP_EXECUTE GROUP_READ WORLD_EXECUTE WORLD_READ RENAME "libtesseract.5.dylib" FILES "/opt/homebrew/Cellar/tesseract/5.5.0_1/lib/libtesseract.5.dylib")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "TesseractRuntime" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/dependencies/libs" TYPE FILE PERMISSIONS OWNER_EXECUTE OWNER_READ GROUP_EXECUTE GROUP_READ WORLD_EXECUTE WORLD_READ RENAME "libleptonica.6.dylib" FILES "/opt/homebrew/Cellar/leptonica/1.85.0/lib/libleptonica.6.dylib")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "TesseractRuntime" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/dependencies/libs" TYPE FILE PERMISSIONS OWNER_EXECUTE OWNER_READ GROUP_EXECUTE GROUP_READ WORLD_EXECUTE WORLD_READ RENAME "libarchive.13.dylib" FILES "/opt/homebrew/Cellar/libarchive/3.8.0/lib/libarchive.13.dylib")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "TesseractRuntime" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/dependencies/libs" TYPE FILE PERMISSIONS OWNER_EXECUTE OWNER_READ GROUP_EXECUTE GROUP_READ WORLD_EXECUTE WORLD_READ RENAME "libpng16.16.dylib" FILES "/opt/homebrew/Cellar/libpng/1.6.48/lib/libpng16.16.dylib")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "TesseractRuntime" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/dependencies/libs" TYPE FILE PERMISSIONS OWNER_EXECUTE OWNER_READ GROUP_EXECUTE GROUP_READ WORLD_EXECUTE WORLD_READ RENAME "libjpeg.8.dylib" FILES "/opt/homebrew/Cellar/jpeg-turbo/3.1.0/lib/libjpeg.8.3.2.dylib")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "TesseractRuntime" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/dependencies/libs" TYPE FILE PERMISSIONS OWNER_EXECUTE OWNER_READ GROUP_EXECUTE GROUP_READ WORLD_EXECUTE WORLD_READ RENAME "libgif.dylib" FILES "/opt/homebrew/Cellar/giflib/5.2.2/lib/libgif.7.2.0.dylib")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "TesseractRuntime" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/dependencies/libs" TYPE FILE PERMISSIONS OWNER_EXECUTE OWNER_READ GROUP_EXECUTE GROUP_READ WORLD_EXECUTE WORLD_READ RENAME "libtiff.6.dylib" FILES "/opt/homebrew/Cellar/libtiff/4.7.0/lib/libtiff.6.dylib")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "TesseractRuntime" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/dependencies/libs" TYPE FILE PERMISSIONS OWNER_EXECUTE OWNER_READ GROUP_EXECUTE GROUP_READ WORLD_EXECUTE WORLD_READ RENAME "libwebp.7.dylib" FILES "/opt/homebrew/Cellar/webp/1.5.0/lib/libwebp.7.1.10.dylib")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "TesseractRuntime" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/dependencies/libs" TYPE FILE PERMISSIONS OWNER_EXECUTE OWNER_READ GROUP_EXECUTE GROUP_READ WORLD_EXECUTE WORLD_READ RENAME "libwebpmux.3.dylib" FILES "/opt/homebrew/Cellar/webp/1.5.0/lib/libwebpmux.3.1.1.dylib")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "TesseractRuntime" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/dependencies/libs" TYPE FILE PERMISSIONS OWNER_EXECUTE OWNER_READ GROUP_EXECUTE GROUP_READ WORLD_EXECUTE WORLD_READ RENAME "libsharpyuv.0.dylib" FILES "/opt/homebrew/Cellar/webp/1.5.0/lib/libsharpyuv.0.1.1.dylib")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "TesseractRuntime" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/dependencies/libs" TYPE FILE PERMISSIONS OWNER_EXECUTE OWNER_READ GROUP_EXECUTE GROUP_READ WORLD_EXECUTE WORLD_READ RENAME "libopenjp2.7.dylib" FILES "/opt/homebrew/Cellar/openjpeg/2.5.3/lib/libopenjp2.2.5.3.dylib")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "TesseractRuntime" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/dependencies/libs" TYPE FILE PERMISSIONS OWNER_EXECUTE OWNER_READ GROUP_EXECUTE GROUP_READ WORLD_EXECUTE WORLD_READ RENAME "liblzma.5.dylib" FILES "/opt/homebrew/Cellar/xz/5.8.1/lib/liblzma.5.dylib")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "TesseractRuntime" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/dependencies/libs" TYPE FILE PERMISSIONS OWNER_EXECUTE OWNER_READ GROUP_EXECUTE GROUP_READ WORLD_EXECUTE WORLD_READ RENAME "libzstd.1.dylib" FILES "/opt/homebrew/Cellar/zstd/1.5.7/lib/libzstd.1.5.7.dylib")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "TesseractRuntime" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/dependencies/libs" TYPE FILE PERMISSIONS OWNER_EXECUTE OWNER_READ GROUP_EXECUTE GROUP_READ WORLD_EXECUTE WORLD_READ RENAME "liblz4.1.dylib" FILES "/opt/homebrew/Cellar/lz4/1.10.0/lib/liblz4.1.10.0.dylib")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "TesseractRuntime" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/dependencies/libs" TYPE FILE PERMISSIONS OWNER_EXECUTE OWNER_READ GROUP_EXECUTE GROUP_READ WORLD_EXECUTE WORLD_READ RENAME "libb2.1.dylib" FILES "/opt/homebrew/Cellar/libb2/0.98.1/lib/libb2.1.dylib")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "TesseractData" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/share/tessdata" TYPE DIRECTORY FILES "/opt/homebrew/opt/tesseract/share/tessdata/")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "TesseractRuntime" OR NOT CMAKE_INSTALL_COMPONENT)
  
    message(STATUS "Fixing Tesseract dylib paths via script...")
    execute_process(
        COMMAND "/Users/strattenwaldt/Desktop/Basil/builds/common/cmake/TesseractBundler/fix_tesseract_dylibs.sh" "/Users/strattenwaldt/Desktop/Basil/builds/common/cmake/TesseractBundler/test_install"
        RESULT_VARIABLE _fix_res
        OUTPUT_VARIABLE _fix_out
        ERROR_VARIABLE _fix_err
    )
    # Escape special characters for messages within the install(CODE) string
    string(REPLACE "\"" "\\\"" _fix_out_escaped "")
    string(REPLACE "\"" "\\\"" _fix_err_escaped "")
    string(REPLACE "\\" "\\\\" _fix_out_escaped "") # Escape backslashes
    string(REPLACE "\\" "\\\\" _fix_err_escaped "") # Escape backslashes

    if(NOT _fix_res EQUAL 0)
        message(FATAL_ERROR "fix_tesseract_dylibs.sh failed (Code: )")
        message(FATAL_ERROR "Output: ")
        message(FATAL_ERROR "Error: ")
    else()
        message(STATUS "fix_tesseract_dylibs.sh successful.")
        # Combine out and err for status. Ensure it's a single clean string for the message.
        set(_combined_output "Output (stdout and stderr from script):  ")
        message(STATUS "")
    endif()

endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "TesseractRuntime" OR NOT CMAKE_INSTALL_COMPONENT)
  
    message(STATUS "Performing ad-hoc code signing on Tesseract components...")
    set(CODESIGN_IDENTITY "-") # Ad-hoc signing
    set(SIGN_FLAGS "--force" "--sign" "")

    set(STAGED_EXE_PATH "/Users/strattenwaldt/Desktop/Basil/builds/common/cmake/TesseractBundler/test_install/bin/tesseract")
    if(EXISTS ${STAGED_EXE_PATH})
        message(STATUS "Signing executable via script: ${STAGED_EXE_PATH}")
        execute_process(COMMAND "/Users/strattenwaldt/Desktop/Basil/builds/common/cmake/TesseractBundler/sign_adhoc.sh" ${STAGED_EXE_PATH} RESULT_VARIABLE RES)
        if(NOT RES EQUAL 0)
            message(FATAL_ERROR "Failed to sign executable (via script): ${STAGED_EXE_PATH}")
        endif()
    else()
        message(WARNING "Tesseract executable not found at ${STAGED_EXE_PATH} for signing.")
    endif()

    file(GLOB DYLIBS "/Users/strattenwaldt/Desktop/Basil/builds/common/cmake/TesseractBundler/test_install/dependencies/libs/*.dylib")
    foreach(DYLIB_PATH ${DYLIBS})
        message(STATUS "Signing dylib via script: ${DYLIB_PATH}")
        execute_process(COMMAND "/Users/strattenwaldt/Desktop/Basil/builds/common/cmake/TesseractBundler/sign_adhoc.sh" ${DYLIB_PATH} RESULT_VARIABLE RES)
        if(NOT RES EQUAL 0)
            message(FATAL_ERROR "Failed to sign dylib (via script): ${DYLIB_PATH}")
        endif()
    endforeach()
    message(STATUS "Ad-hoc code signing complete.")

endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "TesseractRuntime" OR NOT CMAKE_INSTALL_COMPONENT)
  
    message(STATUS "Verifying signatures of Tesseract components...")
    set(STAGED_EXE_PATH "/Users/strattenwaldt/Desktop/Basil/builds/common/cmake/TesseractBundler/test_install/bin/tesseract")
    if(EXISTS ${STAGED_EXE_PATH})
        message(STATUS "Verifying executable: ${STAGED_EXE_PATH}")
        execute_process(COMMAND codesign --verify --deep --strict --verbose=4 ${STAGED_EXE_PATH} RESULT_VARIABLE RES OUTPUT_VARIABLE OUT ERROR_VARIABLE ERR)
        if(NOT RES EQUAL 0)
            message(WARNING "Signature verification FAILED for executable: ${STAGED_EXE_PATH}
Stdout: ${OUT}
Stderr: ${ERR}")
        else()
            message(STATUS "Signature VERIFIED for executable: ${STAGED_EXE_PATH}")
        endif()
    endif()
    # Could add dylib verification here too if needed
    message(STATUS "Signature verification step complete.")

endif()

string(REPLACE ";" "\n" CMAKE_INSTALL_MANIFEST_CONTENT
       "${CMAKE_INSTALL_MANIFEST_FILES}")
if(CMAKE_INSTALL_LOCAL_ONLY)
  file(WRITE "/Users/strattenwaldt/Desktop/Basil/builds/common/cmake/TesseractBundler/build/install_local_manifest.txt"
     "${CMAKE_INSTALL_MANIFEST_CONTENT}")
endif()
if(CMAKE_INSTALL_COMPONENT)
  if(CMAKE_INSTALL_COMPONENT MATCHES "^[a-zA-Z0-9_.+-]+$")
    set(CMAKE_INSTALL_MANIFEST "install_manifest_${CMAKE_INSTALL_COMPONENT}.txt")
  else()
    string(MD5 CMAKE_INST_COMP_HASH "${CMAKE_INSTALL_COMPONENT}")
    set(CMAKE_INSTALL_MANIFEST "install_manifest_${CMAKE_INST_COMP_HASH}.txt")
    unset(CMAKE_INST_COMP_HASH)
  endif()
else()
  set(CMAKE_INSTALL_MANIFEST "install_manifest.txt")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  file(WRITE "/Users/strattenwaldt/Desktop/Basil/builds/common/cmake/TesseractBundler/build/${CMAKE_INSTALL_MANIFEST}"
     "${CMAKE_INSTALL_MANIFEST_CONTENT}")
endif()

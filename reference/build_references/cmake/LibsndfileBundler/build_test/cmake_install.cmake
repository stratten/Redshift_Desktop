# Install script for directory: /Users/strattenwaldt/Desktop/Basil/builds/common/cmake/LibsndfileBundler

# Set the install prefix
if(NOT DEFINED CMAKE_INSTALL_PREFIX)
  set(CMAKE_INSTALL_PREFIX "/Users/strattenwaldt/Desktop/Basil/builds/common/cmake/LibsndfileBundler/test_install_dir")
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

# Set path to fallback-tool for dependency-resolution.
if(NOT DEFINED CMAKE_OBJDUMP)
  set(CMAKE_OBJDUMP "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/objdump")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "RuntimeLibraries" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/dependencies/libs_sndfile_bundle" TYPE FILE PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE RENAME "libsndfile.1.dylib" FILES "/opt/homebrew/Cellar/libsndfile/1.2.2_1/lib/libsndfile.1.0.37.dylib")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "RuntimeLibraries" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/dependencies/libs_sndfile_bundle" TYPE FILE PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE RENAME "libogg.0.dylib" FILES "/opt/homebrew/Cellar/libogg/1.3.5/lib/libogg.0.8.5.dylib")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "RuntimeLibraries" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/dependencies/libs_sndfile_bundle" TYPE FILE PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE RENAME "libvorbis.0.dylib" FILES "/opt/homebrew/Cellar/libvorbis/1.3.7/lib/libvorbis.0.dylib")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "RuntimeLibraries" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/dependencies/libs_sndfile_bundle" TYPE FILE PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE RENAME "libvorbisenc.2.dylib" FILES "/opt/homebrew/Cellar/libvorbis/1.3.7/lib/libvorbisenc.2.dylib")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "RuntimeLibraries" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/dependencies/libs_sndfile_bundle" TYPE FILE PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE RENAME "libFLAC.14.dylib" FILES "/opt/homebrew/Cellar/flac/1.5.0/lib/libFLAC.14.dylib")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "RuntimeLibraries" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/dependencies/libs_sndfile_bundle" TYPE FILE PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE RENAME "libopus.0.dylib" FILES "/opt/homebrew/Cellar/opus/1.5.2/lib/libopus.0.dylib")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "RuntimeLibraries" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/dependencies/libs_sndfile_bundle" TYPE FILE PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE RENAME "libmpg123.0.dylib" FILES "/opt/homebrew/Cellar/mpg123/1.32.10/lib/libmpg123.0.dylib")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "RuntimeLibraries" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/dependencies/libs_sndfile_bundle" TYPE FILE PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE RENAME "libmp3lame.0.dylib" FILES "/opt/homebrew/Cellar/lame/3.100/lib/libmp3lame.0.dylib")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "RuntimeLibraries" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/dependencies/libs_sndfile_bundle" TYPE DIRECTORY FILES "" USE_SOURCE_PERMISSIONS)
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "RuntimeLibraries" OR NOT CMAKE_INSTALL_COMPONENT)
  
    message(STATUS \"Running prepare_libsndfile_bundle_dylibs.sh to fix dylib IDs and paths in bundle: /Users/strattenwaldt/Desktop/Basil/builds/common/cmake/LibsndfileBundler/test_install_dir/dependencies/libs_sndfile_bundle\")
    # We pass CMAKE_INSTALL_PREFIX, the script will know to look in INSTALL_SUBDIR
    execute_process(
        COMMAND bash "/Users/strattenwaldt/Desktop/Basil/builds/common/cmake/LibsndfileBundler/prepare_libsndfile_bundle_dylibs.sh" "/Users/strattenwaldt/Desktop/Basil/builds/common/cmake/LibsndfileBundler/test_install_dir" "dependencies/libs_sndfile_bundle"
        RESULT_VARIABLE _fix_res
        OUTPUT_VARIABLE _fix_out
        ERROR_VARIABLE _fix_err
    )
    # Escape special characters for messages
    string(REPLACE \"\\\"\" \"\\\\\\\"\" _fix_out_escaped \"\")
    string(REPLACE \"\\\"\" \"\\\\\\\"\" _fix_err_escaped \"\")
    string(REPLACE \"\\\\\" \"\\\\\\\\\" _fix_out_escaped \"\")
    string(REPLACE \"\\\\\" \"\\\\\\\\\" _fix_err_escaped \"\")

    if(NOT _fix_res EQUAL 0)
        message(FATAL_ERROR \"prepare_libsndfile_bundle_dylibs.sh failed (Code: ). Output: []. Error: []\")
    else()
        message(STATUS \"prepare_libsndfile_bundle_dylibs.sh successful. Output: [ ]\")
    endif()

endif()

string(REPLACE ";" "\n" CMAKE_INSTALL_MANIFEST_CONTENT
       "${CMAKE_INSTALL_MANIFEST_FILES}")
if(CMAKE_INSTALL_LOCAL_ONLY)
  file(WRITE "/Users/strattenwaldt/Desktop/Basil/builds/common/cmake/LibsndfileBundler/build_test/install_local_manifest.txt"
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
  file(WRITE "/Users/strattenwaldt/Desktop/Basil/builds/common/cmake/LibsndfileBundler/build_test/${CMAKE_INSTALL_MANIFEST}"
     "${CMAKE_INSTALL_MANIFEST_CONTENT}")
endif()

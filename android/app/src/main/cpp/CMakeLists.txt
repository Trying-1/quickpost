cmake_minimum_required(VERSION 3.18)
project(myffmpeg)

# FFmpeg prefix path (adjust if needed)
set(FFMPEG_PREFIX "/home/trexx/ffmpeg-android/prefix/arm64-v8a")

# Include directories
include_directories(${FFMPEG_PREFIX}/include)

# Link directories
link_directories(${FFMPEG_PREFIX}/lib)

# Add the native library
add_library(myffmpeg SHARED
    myffmpeg.cpp
    ffmpeg_common.cpp
    ffmpeg_text_overlay.cpp
    myvideocrop.cpp
    video_text_overlay.cpp
)

## Linker options
# Ensure the shared library is compatible with 16 KB memory page sizes.
# This is required for Google Play on Android 15+.
target_link_options(myffmpeg PRIVATE "-Wl,-z,max-page-size=0x4000")

# Link against FFmpeg libraries and system libraries
target_link_libraries(myffmpeg
    avcodec
    avformat
    avfilter
    avutil
    swresample
    swscale
    freetype
    fribidi
    harfbuzz
    log
)

# Set C++ standard
set_target_properties(myffmpeg PROPERTIES
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED ON
)

# FFmpeg Integration Guide

## Overview

This document explains how FFmpeg is integrated into the QuickPost Flutter Android app for video processing with text overlays, filters, and encoding.

---

## Table of Contents

1. [Architecture](#architecture)
2. [Integration Layers](#integration-layers)
3. [Build Process](#build-process)
4. [FFmpeg Libraries](#ffmpeg-libraries)
5. [Native Code Structure](#native-code-structure)
6. [Adding New Features](#adding-new-features)
7. [Troubleshooting](#troubleshooting)

---

## Architecture

### High-Level Flow

```
Flutter UI (Dart)
    ↓
MethodChannel ("com.quickpost.app/processor")
    ↓
MainActivity (Kotlin)
    ↓
FFmpegTextOverlay (Kotlin Bridge)
    ↓
JNI Layer (C++)
    ↓
FFmpeg C Libraries
    ↓
Video Processing (Decode → Filter → Encode)
    ↓
Output Video File
```

### Three-Layer Integration

1. **Flutter/Dart Layer** - UI and user interaction
2. **Kotlin/Android Layer** - Platform-specific logic and file handling
3. **Native C++ Layer** - FFmpeg video processing

---

## Integration Layers

### Layer 1: Flutter UI (`lib/screens/text_box_overlay/text_box_overlay_screen.dart`)

**Responsibility**: User interface and parameter collection

**Key Features**:
- Video selection
- Text input and formatting
- Color picker (hex input)
- Encoding settings (preset, CRF)
- Text box position control (top/bottom)
- Progress indicator

**MethodChannel Call**:
```dart
final result = await platform.invokeMethod('addTextToVideo', {
  'inputPath': selectedVideo.path,
  'outputPath': outputPath,
  'text': _textController.text,
  'fontSize': _fontSize,
  'fontColor': _textColor,      // e.g., "#000000"
  'boxColor': _boxColor,         // e.g., "#FFFFFF"
  'position': _textBoxPosition,  // "top" or "bottom"
  'preset': _preset,             // "veryfast", "fast", etc.
  'crf': _crf,                   // 0-51 (quality)
});
```

---

### Layer 2: Kotlin/Android (`android/app/src/main/kotlin/com/quickpost/app/`)

#### MainActivity.kt

**Responsibility**: MethodChannel handler and file management

**Key Functions**:
- `addTextToVideo()` - MethodChannel handler
- `getVideoOutputPath()` - Determine output file location
- `moveVideoToGallery()` - Register video with Android MediaStore

**Flow**:
```kotlin
"addTextToVideo" MethodChannel call
    ↓
Parse arguments (inputPath, outputPath, text, colors, position, preset, crf)
    ↓
Call FFmpegTextOverlay.addTextToVideo()
    ↓
Wait for native processing
    ↓
Call moveVideoToGallery() to register with MediaStore
    ↓
Return result to Flutter
```

#### FFmpegTextOverlay.kt

**Responsibility**: JNI bridge to native code

**Key Code**:
```kotlin
object FFmpegTextOverlay {
    init {
        System.loadLibrary("myffmpeg")
    }
    
    external fun nativeAddTextToVideo(
        inputPath: String,
        outputPath: String,
        text: String,
        x: Int,
        y: Int,
        fontSize: Int,
        fontColor: String,
        boxColor: String,
        position: String,
        fontPath: String,
        preset: String,
        crf: Int
    ): Int
    
    fun addTextToVideo(...): Int {
        return nativeAddTextToVideo(...)
    }
}
```

---

### Layer 3: Native C++ (`android/app/src/main/cpp/`)

**Responsibility**: FFmpeg video processing

#### File Structure

```
android/app/src/main/cpp/
├── CMakeLists.txt              ← Build configuration
├── myffmpeg.cpp                ← JNI entry point (thin dispatcher)
├── ffmpeg_common.h/.cpp        ← Shared FFmpeg utilities
├── ffmpeg_text_overlay.h/.cpp  ← Text overlay feature
└── (future: ffmpeg_blur.h/.cpp, ffmpeg_watermark.h/.cpp, etc.)
```

#### myffmpeg.cpp - JNI Dispatcher

**Responsibility**: Entry point from Java/Kotlin

**Function**:
```cpp
extern "C" JNIEXPORT jint JNICALL
Java_com_quickpost_app_FFmpegTextOverlay_nativeAddTextToVideo(
    JNIEnv* env,
    jobject thiz,
    jstring inputPath,
    jstring outputPath,
    jstring text,
    jint x,
    jint y,
    jint fontSize,
    jstring fontColor,
    jstring boxColor,
    jstring position,
    jstring fontPath,
    jstring preset,
    jint crf
)
```

**Flow**:
1. Extract JNI strings
2. Convert hex colors (#RRGGBB → 0xRRGGBB)
3. Initialize TextOverlayContext
4. Call processing pipeline:
   - `ffmpeg_open_input()` - Open input video
   - `ffmpeg_setup_decoder()` - Setup video decoder
   - `ffmpeg_setup_encoder()` - Setup x264 encoder with preset/CRF
   - `ffmpeg_setup_audio_passthrough()` - Copy audio unchanged
   - `text_overlay_setup_filter()` - Create filter graph
   - `text_overlay_process_frames()` - Decode → Filter → Encode
5. Cleanup and return status code

#### ffmpeg_common.h/.cpp - Shared Utilities

**Provides**:
- `FFmpegContext` struct - unified context for all operations
- `ffmpeg_init_context()` - initialize context
- `ffmpeg_open_input()` - open input file, find streams
- `ffmpeg_setup_decoder()` - allocate and open decoder
- `ffmpeg_setup_encoder()` - allocate encoder, set preset/CRF
- `ffmpeg_setup_audio_passthrough()` - setup audio stream copying
- `ffmpeg_cleanup()` - free all resources
- `ffmpeg_release_jni_strings()` - release JNI references

**Key Struct**:
```cpp
struct FFmpegContext {
    AVFormatContext* ifmt_ctx;      // Input file context
    AVFormatContext* ofmt_ctx;      // Output file context
    AVCodecContext* dec_ctx;        // Video decoder context
    AVCodecContext* enc_ctx;        // Video encoder context
    const AVCodec* decoder;         // Decoder codec
    const AVCodec* encoder;         // Encoder codec (libx264)
    AVStream* out_stream;           // Output video stream
    AVStream* audio_out_stream;     // Output audio stream
    int video_stream_idx;           // Input video stream index
    int audio_stream_idx;           // Input audio stream index
    AVRational video_time_base;     // Consistent time base
};
```

#### ffmpeg_text_overlay.h/.cpp - Text Overlay Feature

**Provides**:
- `TextOverlayContext` struct - extends FFmpegContext with filter components
- `text_overlay_init_context()` - initialize context
- `text_overlay_setup_filter()` - build FFmpeg filter graph
- `text_overlay_process_frames()` - main processing loop
- `text_overlay_cleanup()` - cleanup filter and frames

**Filter Graph**:
```
Input Video
    ↓
[pad] - Add space for text box (top or bottom)
    ↓
[drawbox] - Draw colored box
    ↓
[drawtext] - Render text with specified font/color
    ↓
Output Video
```

**Filter Examples**:

Top position:
```
pad=w=1920:h=1080+80:x=0:y=80:color=#FFFFFF@1.0,
drawbox=x=0:y=0:w=1920:h=80:color=#FFFFFF@1.0:t=fill,
drawtext=fontfile='/system/fonts/Roboto-Regular.ttf':text='Hello':fontcolor=0x000000:fontsize=32:x=(w-text_w)/2:y=20
```

Bottom position:
```
pad=w=1920:h=1080+80:x=0:y=0:color=#FFFFFF@1.0,
drawbox=x=0:y=1080:w=1920:h=80:color=#FFFFFF@1.0:t=fill,
drawtext=fontfile='/system/fonts/Roboto-Regular.ttf':text='Hello':fontcolor=0x000000:fontsize=32:x=(w-text_w)/2:y=1100
```

---

## Build Process

### CMakeLists.txt Configuration

```cmake
cmake_minimum_required(VERSION 3.18)
project(myffmpeg)

# FFmpeg prefix path (custom-compiled)
set(FFMPEG_PREFIX "/home/trexx/ffmpeg-android/prefix/arm64-v8a")

# Include FFmpeg headers
include_directories(${FFMPEG_PREFIX}/include)

# Link FFmpeg libraries
link_directories(${FFMPEG_PREFIX}/lib)

# Compile native library
add_library(myffmpeg SHARED
    myffmpeg.cpp
    ffmpeg_common.cpp
    ffmpeg_text_overlay.cpp
)

# Link against FFmpeg and system libraries
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

# C++ standard
set_target_properties(myffmpeg PROPERTIES
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED ON
)
```

### Compilation Steps

1. **NDK Compilation**:
   - Android NDK 27.3.13750724 compiles C++ code
   - Produces `libmyffmpeg.so` for arm64-v8a architecture

2. **Linking**:
   - Links against custom-compiled FFmpeg libraries
   - Includes text rendering libraries (freetype, harfbuzz, fribidi)

3. **APK Packaging**:
   - `libmyffmpeg.so` packaged in APK
   - FFmpeg `.so` files in `jniLibs/arm64-v8a/`

---

## FFmpeg Libraries

### Core Libraries

| Library | Purpose |
|---------|---------|
| `libavformat` | Container format handling (MP4, MKV, etc.) |
| `libavcodec` | Codec operations (H.264, VP9, etc.) |
| `libavfilter` | Filter graph processing |
| `libavutil` | Utility functions |
| `libswscale` | Image scaling and format conversion |
| `libswresample` | Audio resampling |

### Text Rendering Libraries

| Library | Purpose |
|---------|---------|
| `libfreetype` | Font rendering |
| `libharfbuzz` | Text shaping |
| `libfribidi` | Bidirectional text support |

### Encoder

| Encoder | Purpose |
|---------|---------|
| `libx264` | H.264 video encoding |

---

## Native Code Structure

### Error Handling

All functions return error codes:
- `0` = Success
- Negative values = Errors

**Common Error Codes**:
```cpp
-1  = Cannot open input file
-2  = Cannot find stream info
-3  = No video stream found
-4  = Decoder not found
-5  = Cannot allocate decoder context
-6  = Cannot open decoder
-7  = Cannot create output context
-8  = libx264 encoder not found
-9  = Cannot allocate encoder context
-10 = Cannot open encoder
-11 = Cannot create output stream
-12 = Cannot allocate filter graph
-13 = Filter not found
-14 = Cannot create buffer source
-15 = Cannot create buffer sink
-16 = Cannot parse filter graph
-17 = Cannot configure filter graph
-18 = Cannot open output file
-19 = Cannot write header
-20 = Cannot allocate frame/packet
```

### Logging

All logging uses Android's native logging:
```cpp
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, "myffmpeg", __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, "myffmpeg", __VA_ARGS__)
```

**View logs**:
```bash
adb logcat | grep myffmpeg
```

### Memory Management

- All FFmpeg contexts allocated with `av_*_alloc()`
- Freed in cleanup section with `av_*_free()`
- Audio stream copied without re-encoding (no extra context)
- Filter graph freed once (frees all contained contexts)

---

## Adding New Features

### Example: Adding Blur Filter

#### 1. Create Feature Module

**`ffmpeg_blur.h`**:
```cpp
#ifndef FFMPEG_BLUR_H
#define FFMPEG_BLUR_H

#include "ffmpeg_common.h"

struct BlurContext {
    FFmpegContext ffmpeg_ctx;
    AVFilterGraph* filter_graph;
    AVFilterContext* buffersrc_ctx;
    AVFilterContext* buffersink_ctx;
    // ... frame/packet pointers
};

int blur_init_context(BlurContext* ctx);
int blur_setup_filter(BlurContext* ctx, float radius);
int blur_process_frames(BlurContext* ctx, const char* output_file);
void blur_cleanup(BlurContext* ctx);

#endif
```

**`ffmpeg_blur.cpp`**:
```cpp
#include "ffmpeg_blur.h"

int blur_init_context(BlurContext* ctx) {
    // Initialize context
}

int blur_setup_filter(BlurContext* ctx, float radius) {
    // Create filter graph with blur filter
    // snprintf(filter_str, sizeof(filter_str), "boxblur=%.1f", radius);
}

int blur_process_frames(BlurContext* ctx, const char* output_file) {
    // Decode, filter, encode frames
}

void blur_cleanup(BlurContext* ctx) {
    // Cleanup
}
```

#### 2. Create Kotlin Bridge

**`BlurProcessor.kt`**:
```kotlin
object BlurProcessor {
    init {
        System.loadLibrary("myffmpeg")
    }
    
    external fun nativeApplyBlur(
        inputPath: String,
        outputPath: String,
        radius: Float,
        preset: String,
        crf: Int
    ): Int
    
    fun applyBlur(...): Int {
        return nativeApplyBlur(...)
    }
}
```

#### 3. Add JNI Entry Point

**In `myffmpeg.cpp`**:
```cpp
extern "C" JNIEXPORT jint JNICALL
Java_com_quickpost_app_BlurProcessor_nativeApplyBlur(
    JNIEnv* env,
    jobject thiz,
    jstring inputPath,
    jstring outputPath,
    jfloat radius,
    jstring preset,
    jint crf
) {
    // Similar flow to text overlay
    BlurContext ctx;
    blur_init_context(&ctx);
    
    if ((ret = ffmpeg_open_input(&ctx.ffmpeg_ctx, input_file)) < 0) {
        goto cleanup;
    }
    // ... setup decoder, encoder, audio
    if ((ret = blur_setup_filter(&ctx, radius)) < 0) {
        goto cleanup;
    }
    if ((ret = blur_process_frames(&ctx, output_file)) < 0) {
        goto cleanup;
    }
    
cleanup:
    blur_cleanup(&ctx);
    return ret;
}
```

#### 4. Update CMakeLists.txt

```cmake
add_library(myffmpeg SHARED
    myffmpeg.cpp
    ffmpeg_common.cpp
    ffmpeg_text_overlay.cpp
    ffmpeg_blur.cpp  # Add new file
)
```

#### 5. Create Flutter UI

Create a new screen similar to `TextBoxOverlayScreen` for blur controls.

---

## Troubleshooting

### Build Errors

#### "unknown type name 'JNIEnv'"
- **Cause**: Missing `#include <jni.h>`
- **Fix**: Add `#include <jni.h>` to header files

#### "use of undeclared identifier 'av_opt_set'"
- **Cause**: Missing `#include <libavutil/opt.h>`
- **Fix**: Add to FFmpeg includes in header

#### "libx264 encoder not found"
- **Cause**: FFmpeg compiled without x264 support
- **Fix**: Rebuild FFmpeg with `--enable-libx264`

### Runtime Errors

#### "Cannot open input file"
- **Cause**: Invalid file path or permission denied
- **Fix**: Verify file exists and app has read permission

#### "No video stream found"
- **Cause**: Input file has no video stream
- **Fix**: Verify input is a valid video file

#### "Segmentation fault (SIGSEGV)"
- **Cause**: Memory access violation, usually in cleanup
- **Fix**: Check for double-free or null pointer dereference

### Performance Issues

#### Slow encoding
- **Cause**: x264 preset too slow
- **Fix**: Use faster preset (veryfast, fast, medium)

#### High memory usage
- **Cause**: Large video resolution or slow preset
- **Fix**: Reduce resolution or use faster preset

### Debugging

**View native logs**:
```bash
adb logcat | grep myffmpeg
```

**Add debug logging**:
```cpp
LOGI("Variable value: %d", variable);
LOGE("Error occurred: %s", error_message);
```

**Check FFmpeg version**:
```cpp
LOGI("FFmpeg version: %s", av_version_info());
```

---

## Performance Tuning

### x264 Presets (Fastest to Slowest)

| Preset | Speed | Quality | Use Case |
|--------|-------|---------|----------|
| ultrafast | Fastest | Lowest | Real-time streaming |
| superfast | Very fast | Low | Quick preview |
| veryfast | Fast | Medium | Default |
| fast | Medium | Good | Balanced |
| medium | Slow | Better | High quality |
| slow | Very slow | Best | Archive |

### CRF Values

- **0-18**: Visually lossless to high quality
- **18-28**: Good quality (recommended: 23)
- **28-51**: Lower quality

---

## Related Documentation

- [REFACTORING_NOTES.md](./REFACTORING_NOTES.md) - Architecture overview
- [CPP_HEADERS_AND_IMPLEMENTATION.md](./CPP_HEADERS_AND_IMPLEMENTATION.md) - C++ file structure
- [Android NDK Documentation](https://developer.android.com/ndk)
- [FFmpeg Documentation](https://ffmpeg.org/documentation.html)

---

## Summary

FFmpeg is integrated into QuickPost through a three-layer architecture:

1. **Flutter UI** - Collects user input and displays results
2. **Kotlin Bridge** - Handles platform-specific logic and file management
3. **Native C++** - Performs actual video processing using FFmpeg

The modular design allows easy addition of new video processing features by creating new feature modules that reuse the common FFmpeg setup utilities.

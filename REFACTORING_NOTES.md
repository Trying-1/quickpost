# FFmpeg Native Code Refactoring

## Overview
The monolithic `myffmpeg.cpp` has been refactored into a modular architecture to support multiple video processing features while maintaining clean separation of concerns.

## New Structure

### Files Created

#### 1. `ffmpeg_common.h` / `ffmpeg_common.cpp`
**Purpose**: Shared FFmpeg utilities and common setup logic

**Provides**:
- `FFmpegContext` struct - unified context for input/output/codec management
- `ffmpeg_init_context()` - initialize context
- `ffmpeg_open_input()` - open input file and find streams
- `ffmpeg_setup_decoder()` - setup video decoder
- `ffmpeg_setup_encoder()` - setup output format and x264 encoder
- `ffmpeg_setup_audio_passthrough()` - setup audio stream copying
- `ffmpeg_cleanup()` - cleanup all FFmpeg resources
- `ffmpeg_release_jni_strings()` - release JNI string references

**Benefits**:
- Reusable across all video processing features
- Centralized error handling
- Consistent time_base management
- Audio passthrough logic in one place

#### 2. `ffmpeg_text_overlay.h` / `ffmpeg_text_overlay.cpp`
**Purpose**: Text overlay feature implementation

**Provides**:
- `TextOverlayContext` struct - extends FFmpegContext with filter graph components
- `text_overlay_init_context()` - initialize text overlay context
- `text_overlay_setup_filter()` - build and configure FFmpeg filter graph
- `text_overlay_process_frames()` - decode, filter, and encode frames
- `text_overlay_cleanup()` - cleanup text overlay resources

**Features**:
- Supports top/bottom text box positioning
- Hex color input (#RRGGBB format)
- Configurable font, size, and colors
- Filter graph: pad → drawbox → drawtext

#### 3. `myffmpeg.cpp` (Refactored)
**Purpose**: Thin JNI dispatcher layer

**Changes**:
- Removed 500+ lines of implementation details
- Now acts as a clean entry point
- Delegates to specialized modules
- Cleaner error handling flow

**Current flow**:
```
JNI Entry (myffmpeg.cpp)
  ↓
Initialize TextOverlayContext
  ↓
ffmpeg_open_input() → ffmpeg_setup_decoder()
  ↓
ffmpeg_setup_encoder() → ffmpeg_setup_audio_passthrough()
  ↓
text_overlay_setup_filter()
  ↓
text_overlay_process_frames()
  ↓
Cleanup & return
```

## Adding New Features

To add a new video processing feature (e.g., blur, fade, watermark):

### 1. Create Feature Module
```
android/app/src/main/cpp/
├── ffmpeg_blur.h
├── ffmpeg_blur.cpp
```

### 2. Define Feature Context
```cpp
struct BlurContext {
    FFmpegContext ffmpeg_ctx;
    // Feature-specific fields
    AVFilterGraph* filter_graph;
    // ...
};
```

### 3. Implement Feature Functions
```cpp
int blur_init_context(BlurContext* ctx);
int blur_setup_filter(BlurContext* ctx, float radius);
int blur_process_frames(BlurContext* ctx, const char* output_file);
void blur_cleanup(BlurContext* ctx);
```

### 4. Create Kotlin Bridge
```kotlin
// BlurProcessor.kt
object BlurProcessor {
    external fun nativeApplyBlur(
        inputPath: String,
        outputPath: String,
        radius: Float,
        preset: String,
        crf: Int
    ): Int
}
```

### 5. Add JNI Entry Point
```cpp
// In a new file or myffmpeg.cpp
extern "C" JNIEXPORT jint JNICALL
Java_com_quickpost_app_BlurProcessor_nativeApplyBlur(...) {
    // Initialize, setup, process, cleanup
}
```

### 6. Update CMakeLists.txt
```cmake
add_library(myffmpeg SHARED
    myffmpeg.cpp
    ffmpeg_common.cpp
    ffmpeg_text_overlay.cpp
    ffmpeg_blur.cpp  # Add new file
)
```

## Benefits of This Architecture

- **Modularity**: Each feature is self-contained
- **Maintainability**: Easy to find and modify feature-specific code
- **Reusability**: Common FFmpeg setup shared across features
- **Scalability**: Add new features without touching existing code
- **Testability**: Each module can be tested independently
- **Readability**: Clear separation of concerns

## Compilation

The CMakeLists.txt now compiles:
- `myffmpeg.cpp` - JNI dispatcher
- `ffmpeg_common.cpp` - shared utilities
- `ffmpeg_text_overlay.cpp` - text overlay implementation

All linked against FFmpeg libraries (avcodec, avformat, avfilter, avutil, swscale, swresample, freetype, fribidi, harfbuzz).

## Future Improvements

1. **Progress Reporting**: Implement real native-to-Flutter progress via callbacks
2. **Error Messages**: Return detailed error strings to Flutter
3. **Cancellation**: Add support for cancelling long-running operations
4. **Presets**: Create preset configurations for common use cases
5. **Batch Processing**: Process multiple videos in sequence

# Extending FFmpeg Features

## Overview

This guide explains how to enable additional FFmpeg features and codecs in the future, and how to integrate them into the QuickPost app.

---

## Table of Contents

1. [Understanding Current Capabilities](#understanding-current-capabilities)
2. [Identifying New Features](#identifying-new-features)
3. [Rebuilding FFmpeg](#rebuilding-ffmpeg)
4. [Integration Steps](#integration-steps)
5. [Common Features Reference](#common-features-reference)
6. [Complete Example: Adding VP9 Support](#complete-example-adding-vp9-support)
7. [Troubleshooting](#troubleshooting)

---

## Understanding Current Capabilities

### Currently Enabled Features

Your FFmpeg build currently includes:

**Video Codecs**:
- H.264 (libx264) ✅

**Text Rendering**:
- FreeType ✅
- HarfBuzz ✅
- Fribidi ✅

**Core Libraries**:
- libavcodec, libavformat, libavfilter, libavutil ✅
- libswscale, libswresample ✅

### What's NOT Enabled

**Video Codecs** (not available):
- VP8/VP9 (libvpx)
- AV1 (libaom)
- HEVC/H.265 (libx265)
- Theora (libtheora)

**Audio Codecs** (not available):
- MP3 (libmp3lame)
- Opus (libopus)
- Vorbis (libvorbis)

**Filters** (not available):
- Video stabilization (libvidstab)
- Advanced image processing (libzimg)
- Denoise filters

**Protocols** (not available):
- RTMP streaming (librtmp)
- SRT protocol (libsrt)
- SSH (libssh)

---

## Identifying New Features

### Step 1: Determine Your Need

Ask yourself:
- What video processing do I want to add?
- What codec should the output use?
- What filters do I need?

### Step 2: Find the FFmpeg Feature Name

Common mappings:

| Use Case | FFmpeg Feature | Library |
|----------|----------------|---------|
| VP9 video encoding | VP9 codec | libvpx |
| AV1 video encoding | AV1 codec | libaom |
| H.265 video encoding | HEVC codec | libx265 |
| MP3 audio | MP3 codec | libmp3lame |
| Opus audio | Opus codec | libopus |
| Video stabilization | vidstab filter | libvidstab |
| Image upscaling | zscale filter | libzimg |
| RTMP streaming | RTMP protocol | librtmp |

### Step 3: Check FFmpeg Documentation

Visit [FFmpeg Documentation](https://ffmpeg.org/documentation.html) to understand:
- Available options for the feature
- Filter parameters
- Codec-specific settings

---

## Rebuilding FFmpeg

### Prerequisites

Ensure you have:
- Android NDK 27.3.13750724
- FFmpeg source code
- External library sources (if needed)

### Step 1: Navigate to FFmpeg Directory

```bash
cd /home/trexx/ffmpeg-android
```

### Step 2: Clean Previous Build

```bash
make clean
rm -rf prefix/arm64-v8a/*
```

### Step 3: Reconfigure with New Options

```bash
./configure \
  --prefix=/home/trexx/ffmpeg-android/prefix/arm64-v8a \
  --enable-cross-compile \
  --arch=arm64 \
  --target-os=android \
  --cc=clang \
  --cxx=clang++ \
  --sysroot=$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/sysroot \
  --enable-libx264 \
  --enable-libvpx \        # NEW: Add VP8/VP9
  --enable-libopus \       # NEW: Add Opus audio
  --enable-libvidstab \    # NEW: Add video stabilization
  --enable-gpl \           # Required for some features
  --enable-nonfree \       # Required for some features
  --disable-doc \          # Skip documentation
  --disable-programs       # Skip command-line tools
```

### Step 4: Build and Install

```bash
# Build (use all CPU cores)
make -j$(nproc)

# Install to prefix directory
make install

# Verify installation
ls -la /home/trexx/ffmpeg-android/prefix/arm64-v8a/lib/
```

### Step 5: Verify New Libraries

Check that new `.a` files exist:

```bash
ls /home/trexx/ffmpeg-android/prefix/arm64-v8a/lib/ | grep -E "libvpx|libopus|libvidstab"
```

---

## Integration Steps

### Step 1: Update CMakeLists.txt

Add new libraries to the link list:

```cmake
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
    x264
    vpx          # NEW: Add VP8/VP9
    opus         # NEW: Add Opus
    vidstab      # NEW: Add video stabilization
    log
)
```

**Location**: `/home/trexx/projects/quickpost/android/app/src/main/cpp/CMakeLists.txt`

### Step 2: Create Feature Module

Create `.h` and `.cpp` files for the new feature:

**Header file** (`ffmpeg_<feature>.h`):
```cpp
#ifndef FFMPEG_<FEATURE>_H
#define FFMPEG_<FEATURE>_H

#include "ffmpeg_common.h"

struct <Feature>Context {
    FFmpegContext ffmpeg_ctx;
    AVFilterGraph* filter_graph;
    AVFilterContext* buffersrc_ctx;
    AVFilterContext* buffersink_ctx;
    AVPacket* pkt;
    AVFrame* frame;
    AVFrame* filt_frame;
    AVPacket* enc_pkt;
    int frame_count;
};

int <feature>_init_context(<Feature>Context* ctx);
int <feature>_setup_filter(<Feature>Context* ctx, /* parameters */);
int <feature>_process_frames(<Feature>Context* ctx, const char* output_file);
void <feature>_cleanup(<Feature>Context* ctx);

#endif
```

**Implementation file** (`ffmpeg_<feature>.cpp`):
```cpp
#include "ffmpeg_<feature>.h"

int <feature>_init_context(<Feature>Context* ctx) {
    if (!ctx) return -1;
    
    ffmpeg_init_context(&ctx->ffmpeg_ctx);
    ctx->filter_graph = nullptr;
    ctx->buffersrc_ctx = nullptr;
    ctx->buffersink_ctx = nullptr;
    ctx->pkt = nullptr;
    ctx->frame = nullptr;
    ctx->filt_frame = nullptr;
    ctx->enc_pkt = nullptr;
    ctx->frame_count = 0;
    
    return 0;
}

int <feature>_setup_filter(<Feature>Context* ctx, /* parameters */) {
    // Build filter graph
    // Create buffer source and sink
    // Parse and configure filter
}

int <feature>_process_frames(<Feature>Context* ctx, const char* output_file) {
    // Open output file
    // Allocate frames/packets
    // Main processing loop: decode → filter → encode
    // Flush encoders
}

void <feature>_cleanup(<Feature>Context* ctx) {
    // Free all resources
}
```

### Step 3: Add JNI Entry Point

In `myffmpeg.cpp`, add a new JNI function:

```cpp
extern "C" JNIEXPORT jint JNICALL
Java_com_quickpost_app_<Feature>Processor_native<Feature>(
    JNIEnv* env,
    jobject thiz,
    jstring inputPath,
    jstring outputPath,
    /* other parameters */
) {
    // Get JNI strings
    const char* input_file = env->GetStringUTFChars(inputPath, nullptr);
    const char* output_file = env->GetStringUTFChars(outputPath, nullptr);
    
    int ret = 0;
    
    // Initialize context
    <Feature>Context ctx;
    <feature>_init_context(&ctx);
    
    // Setup pipeline
    if ((ret = ffmpeg_open_input(&ctx.ffmpeg_ctx, input_file)) < 0) {
        goto cleanup;
    }
    if ((ret = ffmpeg_setup_decoder(&ctx.ffmpeg_ctx)) < 0) {
        goto cleanup;
    }
    if ((ret = ffmpeg_setup_encoder(&ctx.ffmpeg_ctx, output_file, preset_str, crf)) < 0) {
        goto cleanup;
    }
    if ((ret = ffmpeg_setup_audio_passthrough(&ctx.ffmpeg_ctx)) < 0) {
        goto cleanup;
    }
    if ((ret = <feature>_setup_filter(&ctx, /* parameters */)) < 0) {
        goto cleanup;
    }
    if ((ret = <feature>_process_frames(&ctx, output_file)) < 0) {
        goto cleanup;
    }
    
cleanup:
    <feature>_cleanup(&ctx);
    env->ReleaseStringUTFChars(inputPath, input_file);
    env->ReleaseStringUTFChars(outputPath, output_file);
    
    return ret;
}
```

### Step 4: Create Kotlin Bridge

Create `<Feature>Processor.kt`:

```kotlin
object <Feature>Processor {
    init {
        System.loadLibrary("myffmpeg")
    }
    
    external fun native<Feature>(
        inputPath: String,
        outputPath: String,
        /* parameters */
    ): Int
    
    fun <feature>(
        inputPath: String,
        outputPath: String,
        /* parameters */
    ): Int {
        return native<Feature>(inputPath, outputPath, /* parameters */)
    }
}
```

**Location**: `android/app/src/main/kotlin/com/quickpost/app/<Feature>Processor.kt`

### Step 5: Update CMakeLists.txt (Add Source File)

```cmake
add_library(myffmpeg SHARED
    myffmpeg.cpp
    ffmpeg_common.cpp
    ffmpeg_text_overlay.cpp
    ffmpeg_<feature>.cpp  # ADD THIS
)
```

### Step 6: Create Flutter UI

Create a new screen for the feature (similar to `TextBoxOverlayScreen`):

**Location**: `lib/screens/<feature>/<feature>_screen.dart`

```dart
class <Feature>Screen extends StatefulWidget {
  @override
  State<<Feature>Screen> createState() => _<Feature>ScreenState();
}

class _<Feature>ScreenState extends State<<Feature>Screen> {
  static const platform = MethodChannel('com.quickpost.app/processor');
  
  Future<void> _process<Feature>() async {
    try {
      final result = await platform.invokeMethod('<feature>', {
        'inputPath': selectedVideo.path,
        'outputPath': outputPath,
        /* other parameters */
      });
      
      if (result == 0) {
        // Success
      } else {
        // Error
      }
    } catch (e) {
      // Handle error
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // UI implementation
  }
}
```

### Step 7: Add MethodChannel Handler

In `MainActivity.kt`, add handler:

```kotlin
channel.setMethodCallHandler { call, result ->
    when (call.method) {
        "<feature>" -> {
            val inputPath = call.argument<String>("inputPath")
            val outputPath = call.argument<String>("outputPath")
            // ... get other parameters
            
            val ret = <Feature>Processor.<feature>(
                inputPath!!,
                outputPath!!,
                /* parameters */
            )
            
            if (ret == 0) {
                moveVideoToGallery(outputPath)
                result.success(0)
            } else {
                result.error("NATIVE_ERROR", "Error code: $ret", null)
            }
        }
    }
}
```

---

## Common Features Reference

### VP9 Video Encoding

**Enable in FFmpeg**:
```bash
--enable-libvpx
```

**CMakeLists.txt**:
```cmake
target_link_libraries(myffmpeg ... vpx ...)
```

**Encoder Setup**:
```cpp
encoder = avcodec_find_encoder_by_name("libvpx-vp9");
av_opt_set_int(enc_ctx->priv_data, "crf", quality, 0);
```

**Filter**: None needed (just encode)

---

### AV1 Video Encoding

**Enable in FFmpeg**:
```bash
--enable-libaom
```

**CMakeLists.txt**:
```cmake
target_link_libraries(myffmpeg ... aom ...)
```

**Encoder Setup**:
```cpp
encoder = avcodec_find_encoder_by_name("libaom-av1");
av_opt_set_int(enc_ctx->priv_data, "crf", quality, 0);
```

---

### Opus Audio Encoding

**Enable in FFmpeg**:
```bash
--enable-libopus
```

**CMakeLists.txt**:
```cmake
target_link_libraries(myffmpeg ... opus ...)
```

**Encoder Setup**:
```cpp
encoder = avcodec_find_encoder_by_name("libopus");
av_opt_set_int(enc_ctx->priv_data, "b", bitrate, 0);
```

---

### Video Stabilization

**Enable in FFmpeg**:
```bash
--enable-libvidstab
```

**CMakeLists.txt**:
```cmake
target_link_libraries(myffmpeg ... vidstab ...)
```

**Filter Graph**:
```cpp
snprintf(filter_str, sizeof(filter_str),
         "vidstabdetect=shakiness=5:accuracy=15,"
         "vidstabtransform=smoothing=%.1f", smoothing);
```

---

### Image Upscaling (zscale)

**Enable in FFmpeg**:
```bash
--enable-libzimg
```

**CMakeLists.txt**:
```cmake
target_link_libraries(myffmpeg ... zimg ...)
```

**Filter Graph**:
```cpp
snprintf(filter_str, sizeof(filter_str),
         "zscale=w=%d:h=%d:filter=lanczos",
         new_width, new_height);
```

---

## Complete Example: Adding VP9 Support

### Step 1: Rebuild FFmpeg

```bash
cd /home/trexx/ffmpeg-android

./configure \
  --prefix=/home/trexx/ffmpeg-android/prefix/arm64-v8a \
  --enable-cross-compile \
  --arch=arm64 \
  --target-os=android \
  --cc=clang \
  --cxx=clang++ \
  --sysroot=$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/sysroot \
  --enable-libx264 \
  --enable-libvpx \
  --disable-doc \
  --disable-programs

make clean
make -j$(nproc)
make install
```

### Step 2: Update CMakeLists.txt

```cmake
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
    x264
    vpx          # ADD THIS
    log
)
```

### Step 3: Create ffmpeg_vp9_encoder.h

```cpp
#ifndef FFMPEG_VP9_ENCODER_H
#define FFMPEG_VP9_ENCODER_H

#include "ffmpeg_common.h"

struct VP9Context {
    FFmpegContext ffmpeg_ctx;
    AVPacket* pkt;
    AVFrame* frame;
    AVPacket* enc_pkt;
    int frame_count;
};

int vp9_init_context(VP9Context* ctx);
int vp9_setup_encoder(VP9Context* ctx, const char* output_file, int quality);
int vp9_process_frames(VP9Context* ctx, const char* output_file);
void vp9_cleanup(VP9Context* ctx);

#endif
```

### Step 4: Create ffmpeg_vp9_encoder.cpp

```cpp
#include "ffmpeg_vp9_encoder.h"

int vp9_init_context(VP9Context* ctx) {
    if (!ctx) return -1;
    ffmpeg_init_context(&ctx->ffmpeg_ctx);
    ctx->pkt = nullptr;
    ctx->frame = nullptr;
    ctx->enc_pkt = nullptr;
    ctx->frame_count = 0;
    return 0;
}

int vp9_setup_encoder(VP9Context* ctx, const char* output_file, int quality) {
    FFmpegContext* ffmpeg_ctx = &ctx->ffmpeg_ctx;
    
    // Create output format context
    avformat_alloc_output_context2(&ffmpeg_ctx->ofmt_ctx, nullptr, nullptr, output_file);
    if (!ffmpeg_ctx->ofmt_ctx) {
        LOGE("Cannot create output context");
        return -7;
    }
    
    // Find VP9 encoder
    ffmpeg_ctx->encoder = avcodec_find_encoder_by_name("libvpx-vp9");
    if (!ffmpeg_ctx->encoder) {
        LOGE("libvpx-vp9 encoder not found");
        return -8;
    }
    
    ffmpeg_ctx->enc_ctx = avcodec_alloc_context3(ffmpeg_ctx->encoder);
    if (!ffmpeg_ctx->enc_ctx) {
        LOGE("Cannot allocate encoder context");
        return -9;
    }
    
    // Configure encoder
    ffmpeg_ctx->enc_ctx->height = ffmpeg_ctx->dec_ctx->height;
    ffmpeg_ctx->enc_ctx->width = ffmpeg_ctx->dec_ctx->width;
    ffmpeg_ctx->enc_ctx->sample_aspect_ratio = ffmpeg_ctx->dec_ctx->sample_aspect_ratio;
    ffmpeg_ctx->enc_ctx->pix_fmt = AV_PIX_FMT_YUV420P;
    ffmpeg_ctx->enc_ctx->time_base = ffmpeg_ctx->video_time_base;
    ffmpeg_ctx->enc_ctx->bit_rate = 2000000;
    
    // VP9-specific options
    ffmpeg_ctx->enc_ctx->thread_count = 0;
    av_opt_set_int(ffmpeg_ctx->enc_ctx->priv_data, "crf", quality, 0);
    av_opt_set(ffmpeg_ctx->enc_ctx->priv_data, "deadline", "good", 0);
    
    if (avcodec_open2(ffmpeg_ctx->enc_ctx, ffmpeg_ctx->encoder, nullptr) < 0) {
        LOGE("Cannot open VP9 encoder");
        return -10;
    }
    
    // Create output stream
    ffmpeg_ctx->out_stream = avformat_new_stream(ffmpeg_ctx->ofmt_ctx, ffmpeg_ctx->encoder);
    if (!ffmpeg_ctx->out_stream) {
        LOGE("Cannot create output stream");
        return -11;
    }
    
    avcodec_parameters_from_context(ffmpeg_ctx->out_stream->codecpar, ffmpeg_ctx->enc_ctx);
    ffmpeg_ctx->out_stream->time_base = ffmpeg_ctx->enc_ctx->time_base;
    
    return 0;
}

int vp9_process_frames(VP9Context* ctx, const char* output_file) {
    FFmpegContext* ffmpeg_ctx = &ctx->ffmpeg_ctx;
    
    // Open output file
    if (!(ffmpeg_ctx->ofmt_ctx->oformat->flags & AVFMT_NOFILE)) {
        if (avio_open(&ffmpeg_ctx->ofmt_ctx->pb, output_file, AVIO_FLAG_WRITE) < 0) {
            LOGE("Cannot open output file");
            return -18;
        }
    }
    
    if (avformat_write_header(ffmpeg_ctx->ofmt_ctx, nullptr) < 0) {
        LOGE("Cannot write header");
        return -19;
    }
    
    // Allocate frames/packets
    ctx->pkt = av_packet_alloc();
    ctx->frame = av_frame_alloc();
    
    if (!ctx->pkt || !ctx->frame) {
        LOGE("Cannot allocate frame/packet");
        return -20;
    }
    
    // Process frames
    while (av_read_frame(ffmpeg_ctx->ifmt_ctx, ctx->pkt) >= 0) {
        if (ctx->pkt->stream_index != ffmpeg_ctx->video_stream_idx) {
            av_packet_unref(ctx->pkt);
            continue;
        }
        
        if (avcodec_send_packet(ffmpeg_ctx->dec_ctx, ctx->pkt) < 0) {
            LOGE("Error sending packet to decoder");
            av_packet_unref(ctx->pkt);
            continue;
        }
        
        while (avcodec_receive_frame(ffmpeg_ctx->dec_ctx, ctx->frame) == 0) {
            if (avcodec_send_frame(ffmpeg_ctx->enc_ctx, ctx->frame) < 0) {
                LOGE("Error sending frame to encoder");
                break;
            }
            
            ctx->enc_pkt = av_packet_alloc();
            while (avcodec_receive_packet(ffmpeg_ctx->enc_ctx, ctx->enc_pkt) == 0) {
                ctx->enc_pkt->stream_index = ffmpeg_ctx->out_stream->index;
                av_packet_rescale_ts(ctx->enc_pkt, ffmpeg_ctx->enc_ctx->time_base, 
                                     ffmpeg_ctx->out_stream->time_base);
                av_interleaved_write_frame(ffmpeg_ctx->ofmt_ctx, ctx->enc_pkt);
                av_packet_unref(ctx->enc_pkt);
            }
            av_packet_free(&ctx->enc_pkt);
        }
        
        av_packet_unref(ctx->pkt);
        ctx->frame_count++;
        if (ctx->frame_count % 30 == 0) {
            LOGI("Processed %d frames", ctx->frame_count);
        }
    }
    
    // Flush encoder
    avcodec_send_frame(ffmpeg_ctx->enc_ctx, nullptr);
    ctx->enc_pkt = av_packet_alloc();
    while (avcodec_receive_packet(ffmpeg_ctx->enc_ctx, ctx->enc_pkt) == 0) {
        ctx->enc_pkt->stream_index = 0;
        av_packet_rescale_ts(ctx->enc_pkt, ffmpeg_ctx->enc_ctx->time_base, 
                             ffmpeg_ctx->out_stream->time_base);
        av_interleaved_write_frame(ffmpeg_ctx->ofmt_ctx, ctx->enc_pkt);
        av_packet_unref(ctx->enc_pkt);
    }
    av_packet_free(&ctx->enc_pkt);
    
    av_write_trailer(ffmpeg_ctx->ofmt_ctx);
    
    LOGI("VP9 encoding completed. Total frames: %d", ctx->frame_count);
    return 0;
}

void vp9_cleanup(VP9Context* ctx) {
    if (!ctx) return;
    
    if (ctx->pkt) av_packet_free(&ctx->pkt);
    if (ctx->frame) av_frame_free(&ctx->frame);
    if (ctx->enc_pkt) av_packet_free(&ctx->enc_pkt);
    
    ffmpeg_cleanup(&ctx->ffmpeg_ctx);
}
```

### Step 5: Add JNI Entry Point in myffmpeg.cpp

```cpp
extern "C" JNIEXPORT jint JNICALL
Java_com_quickpost_app_VP9Encoder_nativeEncodeVP9(
    JNIEnv* env,
    jobject thiz,
    jstring inputPath,
    jstring outputPath,
    jint quality
) {
    const char* input_file = env->GetStringUTFChars(inputPath, nullptr);
    const char* output_file = env->GetStringUTFChars(outputPath, nullptr);
    
    LOGI("Starting VP9 encoding: input=%s, output=%s, quality=%d", 
         input_file, output_file, quality);
    
    int ret = 0;
    VP9Context ctx;
    vp9_init_context(&ctx);
    
    if ((ret = ffmpeg_open_input(&ctx.ffmpeg_ctx, input_file)) < 0) {
        goto cleanup;
    }
    if ((ret = ffmpeg_setup_decoder(&ctx.ffmpeg_ctx)) < 0) {
        goto cleanup;
    }
    if ((ret = vp9_setup_encoder(&ctx, output_file, quality)) < 0) {
        goto cleanup;
    }
    if ((ret = ffmpeg_setup_audio_passthrough(&ctx.ffmpeg_ctx)) < 0) {
        goto cleanup;
    }
    if ((ret = vp9_process_frames(&ctx, output_file)) < 0) {
        goto cleanup;
    }
    
    LOGI("VP9 encoding completed successfully");
    
cleanup:
    vp9_cleanup(&ctx);
    env->ReleaseStringUTFChars(inputPath, input_file);
    env->ReleaseStringUTFChars(outputPath, output_file);
    
    return ret;
}
```

### Step 6: Create VP9Encoder.kt

```kotlin
object VP9Encoder {
    init {
        System.loadLibrary("myffmpeg")
    }
    
    external fun nativeEncodeVP9(
        inputPath: String,
        outputPath: String,
        quality: Int
    ): Int
    
    fun encodeVP9(inputPath: String, outputPath: String, quality: Int): Int {
        return nativeEncodeVP9(inputPath, outputPath, quality)
    }
}
```

### Step 7: Update CMakeLists.txt

```cmake
add_library(myffmpeg SHARED
    myffmpeg.cpp
    ffmpeg_common.cpp
    ffmpeg_text_overlay.cpp
    ffmpeg_vp9_encoder.cpp  # ADD THIS
)
```

### Step 8: Add MethodChannel Handler in MainActivity.kt

```kotlin
channel.setMethodCallHandler { call, result ->
    when (call.method) {
        "encodeVP9" -> {
            val inputPath = call.argument<String>("inputPath")
            val outputPath = call.argument<String>("outputPath")
            val quality = call.argument<Int>("quality") ?: 30
            
            val ret = VP9Encoder.encodeVP9(inputPath!!, outputPath!!, quality)
            
            if (ret == 0) {
                moveVideoToGallery(outputPath)
                result.success(0)
            } else {
                result.error("NATIVE_ERROR", "VP9 encoding failed with code: $ret", null)
            }
        }
    }
}
```

### Step 9: Create Flutter UI Screen

Create `lib/screens/vp9_encoder/vp9_encoder_screen.dart` with video selection, quality slider, and process button.

### Step 10: Build and Test

```bash
cd /home/trexx/projects/quickpost
flutter clean
flutter run
```

---

## Troubleshooting

### Build Errors

#### "libvpx not found"
- **Cause**: FFmpeg not rebuilt with libvpx
- **Fix**: Rebuild FFmpeg with `--enable-libvpx`

#### "undefined reference to 'vpx_codec_encode'"
- **Cause**: CMakeLists.txt not updated with new library
- **Fix**: Add `vpx` to `target_link_libraries`

#### "encoder not found"
- **Cause**: Encoder name incorrect or not enabled
- **Fix**: Check FFmpeg documentation for correct encoder name

### Runtime Errors

#### "libvpx-vp9 encoder not found"
- **Cause**: FFmpeg compiled without VP9 support
- **Fix**: Rebuild FFmpeg with `--enable-libvpx`

#### "Cannot open encoder"
- **Cause**: Encoder options invalid
- **Fix**: Check encoder-specific options in FFmpeg docs

### Performance Issues

#### Slow VP9 encoding
- **Cause**: Default deadline is "best"
- **Fix**: Use `av_opt_set(enc_ctx->priv_data, "deadline", "good", 0)`

---

## Summary

To add new FFmpeg features:

1. **Rebuild** FFmpeg with `--enable-<feature>`
2. **Update** CMakeLists.txt with new library
3. **Create** feature module (.h/.cpp)
4. **Add** JNI entry point
5. **Create** Kotlin bridge
6. **Add** MethodChannel handler
7. **Create** Flutter UI
8. **Build** and test

The modular architecture makes this process straightforward and repeatable!

---

## Related Documentation

- [FFMPEG_INTEGRATION.md](./FFMPEG_INTEGRATION.md) - FFmpeg integration overview
- [REFACTORING_NOTES.md](./REFACTORING_NOTES.md) - Architecture and modularity
- [CPP_HEADERS_AND_IMPLEMENTATION.md](./CPP_HEADERS_AND_IMPLEMENTATION.md) - C++ file structure
- [FFmpeg Official Documentation](https://ffmpeg.org/documentation.html)
- [FFmpeg Encoders](https://ffmpeg.org/ffmpeg-codecs.html#Encoders)
- [FFmpeg Filters](https://ffmpeg.org/ffmpeg-filters.html)

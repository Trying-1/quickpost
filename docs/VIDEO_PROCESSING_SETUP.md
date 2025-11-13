# Video Processing Setup - Image to Video with Fade-In Effect

## Overview
This feature converts images to videos with smooth fade-in effects using native Kotlin code for optimal performance.

## Architecture

### Flutter Side
- **Screen**: `lib/screens/image_to_video_screen.dart`
- **Method Channel**: `com.igpostmaker.video/processor`
- **Communication**: Bidirectional (Flutter ↔ Kotlin)

### Kotlin Side
- **MainActivity**: `android/app/src/main/kotlin/com/example/igpostmakermobile/MainActivity.kt`
- **VideoProcessor**: `android/app/src/main/kotlin/com/example/igpostmakermobile/VideoProcessor.kt`

## Features Implemented

### 1. Flutter UI (`image_to_video_screen.dart`)
- ✅ Image picker integration
- ✅ Video settings controls (duration, fade-in duration)
- ✅ Real-time progress tracking
- ✅ Success/Error dialogs
- ✅ Output path display

### 2. Kotlin Video Processing (`VideoProcessor.kt`)
- ✅ MediaCodec for H.264 encoding
- ✅ MediaMuxer for MP4 container
- ✅ Fade-in effect implementation
- ✅ Progress callback system
- ✅ Image scaling and centering
- ✅ 1080x1350 output (Instagram format)
- ✅ 30 FPS, 6 Mbps bitrate

### 3. Method Channel Communication
- ✅ `createFadeInVideo` - Main processing method
- ✅ `onProgress` - Progress updates (0.0 to 1.0)
- ✅ `onComplete` - Success callback with output path
- ✅ `onError` - Error handling

## Video Specifications

```kotlin
VIDEO_WIDTH = 1080
VIDEO_HEIGHT = 1350
FRAME_RATE = 30
BIT_RATE = 6000000 (6 Mbps)
FORMAT = H.264 (AVC)
CONTAINER = MP4
```

## User Controls

1. **Duration**: 1-10 seconds (adjustable slider)
2. **Fade-In Duration**: 0.5-3.0 seconds (adjustable slider)
3. **Image Selection**: Gallery picker
4. **Progress Bar**: Real-time encoding progress

## Output

- **Location**: `Movies/Instagram Post Maker/`
- **Naming**: `fade_in_video_[timestamp].mp4`
- **Format**: MP4 with H.264 video codec

## How It Works

### Fade-In Algorithm
```kotlin
val alpha = if (frameIndex < fadeInFrames) {
    frameIndex.toFloat() / fadeInFrames.toFloat()
} else {
    1.0f
}
```

### Frame Generation
1. Load and scale image to fit 1080x1350
2. For each frame:
   - Calculate alpha based on fade-in progress
   - Draw black background
   - Draw image with calculated alpha
   - Encode frame
3. Mux frames into MP4 container

## Navigation

New tab added to bottom navigation:
- **Icon**: `Icons.video_call`
- **Label**: "Image to Video"
- **Index**: 3 (4th tab)

## Testing

To test the feature:
1. Run the app: `flutter run`
2. Navigate to "Image to Video" tab
3. Select an image from gallery
4. Adjust duration and fade-in settings
5. Tap "Create Video"
6. Monitor progress bar
7. Check output in Movies folder

## Future Enhancements

Potential additions:
- [ ] Fade-out effect
- [ ] Multiple transition types (slide, zoom, etc.)
- [ ] Audio support
- [ ] Multiple images to slideshow
- [ ] Custom resolution options
- [ ] Export to different formats
- [ ] Video preview before saving

## Permissions Required

Already configured in AndroidManifest.xml:
- ✅ READ_EXTERNAL_STORAGE
- ✅ WRITE_EXTERNAL_STORAGE
- ✅ READ_MEDIA_IMAGES (Android 13+)

## Dependencies

No additional dependencies required! Uses native Android APIs:
- MediaCodec
- MediaMuxer
- MediaFormat
- Bitmap processing

## Error Handling

Errors are caught and reported back to Flutter:
- Invalid image path
- Encoding failures
- File I/O errors
- Memory issues

All errors display in user-friendly dialogs.

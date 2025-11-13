# 🎬 Video Creator Feature

## Overview

The Video Creator feature allows users to create professional videos from images with various effects, audio, and customizable settings. It supports multiple video templates including fade effects, zoom effects, and image sequences.

## Architecture

### Flutter Layer (UI)
```
lib/screens/video_creator/
├── video_creator_screen.dart          # Main screen
└── widgets/
    ├── template_selector_widget.dart  # Template selection UI
    ├── image_preview_widget.dart      # Single image preview
    ├── multi_image_selector_widget.dart # Multi-image grid selector
    ├── audio_selector_widget.dart     # Audio file picker
    ├── duration_selector_widget.dart  # Video duration input
    └── create_button_widget.dart      # Create/cancel controls
```

### Template System
```
lib/templates/video/
├── video_template_base.dart           # Abstract base class
├── video_template_registry.dart       # Template registry
├── fade_in_template.dart              # Fade-in effect
├── zoom_in_template.dart              # Zoom-in effect
└── image_sequence_template.dart       # Multi-image slideshow
```

### Native Android Layer (Video Processing)
```
android/app/src/main/kotlin/com/example/igpostmakermobile/
├── MainActivity.kt                    # Platform channel handler
├── VideoProcessor.kt                  # Core video encoding
└── templates/video/
    ├── VideoTemplate.kt               # Template interface
    ├── VideoTemplateRegistry.kt       # Template registry
    ├── PlainTemplate.kt               # No effects
    ├── FadeInTemplate.kt              # Fade-in effect
    ├── ZoomInTemplate.kt              # Zoom-in effect
    └── ImageSequenceTemplate.kt       # Multi-image logic
```

## Features

### 1. Video Templates

#### Fade In Template
- **Effect**: Image fades in from black
- **Settings**:
  - Fade duration: 0.5-3.0 seconds
  - Zoom scale: 1.0-2.0x
  - Zoom duration: 0.5-5.0 seconds

#### Zoom In Template
- **Effect**: Image zooms in smoothly
- **Settings**:
  - Zoom scale: 1.0-2.0x
  - Zoom duration: 0.5-5.0 seconds

#### Image Sequence Template ⭐ NEW
- **Effect**: Slideshow of multiple images
- **Settings**:
  - Duration per image: 0.01-60.0 seconds (text input)
  - Sequence mode: Sequential or Random
  - Allow repeat: Loop images to fill duration
- **Features**:
  - Multi-image grid selector
  - Drag to reorder images
  - Remove individual images
  - Clear all button

### 2. Video Duration Control

- **Input Type**: Text field (replaced slider for precision)
- **Range**: 1-60 seconds
- **Behavior**: 
  - Without audio: Uses selected duration
  - With audio: Uses minimum of (selected duration, audio duration)

### 3. Audio Integration

- **Supported Formats**: MP3, M4A, WAV, AAC
- **Features**:
  - Audio file picker
  - Duration display
  - Audio preview playback
  - Remove audio option
- **Behavior**: Audio is merged with video, trimmed to match video duration

### 4. Video Output

- **Resolution**: 1080×1920 (9:16 portrait)
- **Frame Rate**: 30 fps
- **Codec**: H.264/AVC (High Profile, Level 4.2)
- **Bitrate**: 8 Mbps
- **Format**: MP4
- **Location**: `/storage/emulated/0/Movies/Instagram Post Maker/`
- **Naming**: `{template_name}_{timestamp}.mp4`

## Technical Implementation

### Video Encoding Process

1. **Frame Generation**
   ```kotlin
   totalFrames = duration × 30 fps
   frameInterval = 1/30 seconds = 33.33ms
   ```

2. **Frame Timing** (Critical for correct playback)
   ```kotlin
   // Throttle frame submission to 30 fps
   targetTime = startTime + (frameIndex × frameInterval)
   wait(targetTime - currentTime)
   ```

3. **Template Effects**
   - Each template calculates per-frame transformations
   - Alpha, scale, and position are interpolated
   - Frames are rendered to Surface input

4. **Audio Merging**
   - Video-only file created first
   - Audio track extracted and merged using MediaMuxer
   - Both tracks synchronized to same duration

### Platform Channel Communication

```dart
// Flutter → Android
final result = await platform.invokeMethod('createVideo', {
  'duration': 7,
  'template': 'image_sequence',
  'imagePaths': ['path1', 'path2', ...],
  'durationPerImage': 2.0,
  'sequenceMode': 'sequential',
  'allowRepeat': true,
  'audioPath': 'audio.mp3',
});

// Android → Flutter (Progress)
methodChannel.invokeMethod('onProgress', 0.5); // 50%

// Android → Flutter (Complete)
methodChannel.invokeMethod('onComplete', '/path/to/video.mp4');
```

### Image Sequence Logic

```kotlin
fun getImageIndexForFrame(
    frameIndex: Int,
    imageCount: Int,
    framesPerImage: Int,
    isRandom: Boolean,
    allowRepeat: Boolean
): Int {
    val sequencePosition = frameIndex / framesPerImage
    
    return if (isRandom) {
        (sequencePosition * 31) % imageCount
    } else {
        if (allowRepeat) {
            sequencePosition % imageCount  // Loop
        } else {
            minOf(sequencePosition, imageCount - 1)  // Stay on last
        }
    }
}
```

## User Interface

### Main Screen Layout

```
┌─────────────────────────────────┐
│  Video Creator                  │
├─────────────────────────────────┤
│                                 │
│  📋 Template Selection          │
│  ┌───┐ ┌───┐ ┌───┐             │
│  │ F │ │ Z │ │ S │ ...         │
│  └───┘ └───┘ └───┘             │
│                                 │
│  🖼️ Image Selection             │
│  [Select Image] [Gallery]       │
│  OR                             │
│  ┌─────┬─────┐                 │
│  │ 1   │ 2   │  (Grid)         │
│  ├─────┼─────┤                 │
│  │ 3   │ 4   │                 │
│  └─────┴─────┘                 │
│                                 │
│  🎵 Audio (Optional)            │
│  [Select Audio] [▶️ Play]       │
│                                 │
│  ⏱️ Duration                    │
│  [7] seconds                    │
│                                 │
│  ⚙️ Template Settings           │
│  • Duration per image: [2.0]s   │
│  • Mode: [Sequential] [Random]  │
│  • Repeat: [✓]                  │
│                                 │
│  [Create Video]                 │
│                                 │
└─────────────────────────────────┘
```

### Progress Dialog

```
┌─────────────────────────────────┐
│  Creating Video...              │
│                                 │
│  ████████████░░░░░░░░ 65%      │
│                                 │
│  [Cancel]                       │
└─────────────────────────────────┘
```

### Success Dialog

```
┌─────────────────────────────────┐
│  ✓ Success!                     │
│                                 │
│  Video created successfully!    │
│                                 │
│  Saved to:                      │
│  /storage/.../image_sequence... │
│                                 │
│  [OK]  [OPEN]                   │
└─────────────────────────────────┘
```

## Key Fixes & Improvements

### 1. Frame Timing Fix (Critical)
**Problem**: Videos played at wrong speed (e.g., 7s video played in 4s)  
**Cause**: Frames submitted too fast, causing incorrect presentation timestamps  
**Solution**: Throttle frame submission to exactly 30 fps intervals

```kotlin
val frameIntervalNs = 1_000_000_000L / 30  // 33.33ms
Thread.sleep(waitTimeNs / 1_000_000, (waitTimeNs % 1_000_000).toInt())
```

### 2. Duration Input Field
**Problem**: Slider limited to 1-10 seconds, not precise  
**Solution**: Text input field allowing 1-60 seconds with 1-second precision

### 3. Duration Per Image Input
**Problem**: Slider limited to 0.5-5.0 seconds  
**Solution**: Text input field allowing 0.01-60.0 seconds for precise control

### 4. Strict Duration Enforcement
**Problem**: Video duration didn't match selected duration  
**Solution**: 
- Always use user-selected duration
- With audio: `min(videoDuration, audioDuration)`
- Images repeat or get skipped to fill exact duration

### 5. File Naming
**Problem**: All videos named `fade_in_video_xxx.mp4`  
**Solution**: Named by template: `{template}_xxx.mp4`

### 6. Frame Draining
**Problem**: Not all frames encoded (e.g., 89/90 frames)  
**Solution**: Improved encoder draining logic to ensure all frames written

### 7. File Saving
**Problem**: `renameTo()` failed silently across storage locations  
**Solution**: Use `copyTo()` instead for reliable file transfer

## Performance

### Encoding Speed
- **Single Image**: ~Real-time (7s video = ~7s encoding)
- **Image Sequence**: ~Real-time (throttled to 30 fps)
- **With Audio**: +1-2s for merging

### Memory Usage
- **Single Image**: ~50 MB
- **Image Sequence (10 images)**: ~200 MB
- **Peak**: ~300 MB during encoding

### File Sizes
- **7s video (no audio)**: ~3-4 MB
- **7s video (with audio)**: ~4-5 MB
- **Bitrate**: 8 Mbps (high quality)

## Error Handling

### Common Errors

1. **"Image path is required"**
   - User didn't select an image
   - Solution: Validate before creating video

2. **"At least one image required"** (Image Sequence)
   - No images selected in grid
   - Solution: Disable create button until images selected

3. **"Failed to create video"**
   - Encoding error or out of memory
   - Solution: Show error dialog, log details

4. **"Null check operator used on null value"**
   - Missing parameter in platform channel
   - Solution: Provide default values in MainActivity

## Future Enhancements

### Planned Features
- [ ] More templates (slide, rotate, pan)
- [ ] Text overlay on videos
- [ ] Filters and color adjustments
- [ ] Transition effects between images
- [ ] Custom aspect ratios (16:9, 1:1, 4:5)
- [ ] Video quality settings (HD, Full HD, 4K)
- [ ] Background music library
- [ ] Video trimming/editing
- [ ] Batch video creation

### Performance Improvements
- [ ] Hardware acceleration (GPU encoding)
- [ ] Background processing
- [ ] Incremental progress updates
- [ ] Pause/resume encoding
- [ ] Memory optimization for large image sets

## Testing

### Manual Test Cases

1. **Single Image Video**
   - Select fade_in template
   - Pick 1 image
   - Set duration to 5s
   - Create video
   - ✓ Video is exactly 5 seconds
   - ✓ Fade effect works

2. **Image Sequence**
   - Select image_sequence template
   - Pick 10 images
   - Set duration to 10s
   - Set duration per image to 1s
   - Enable repeat
   - Create video
   - ✓ Video is exactly 10 seconds
   - ✓ All images shown once

3. **With Audio**
   - Select any template
   - Pick image(s)
   - Set duration to 10s
   - Pick 7s audio file
   - Create video
   - ✓ Video is 7 seconds (min of 10 and 7)
   - ✓ Audio plays throughout

4. **Cancel Operation**
   - Start creating video
   - Click cancel during progress
   - ✓ Process stops
   - ✓ No file created

## Troubleshooting

### Video plays at wrong speed
- **Check**: Frame timing throttle is enabled
- **Fix**: Ensure `Thread.sleep()` in frame submission loop

### Video duration doesn't match
- **Check**: Logs show correct `totalFrames`
- **Fix**: Verify duration calculation and frame count

### Images not repeating
- **Check**: `allowRepeat` setting
- **Fix**: Enable repeat toggle in UI

### Audio not syncing
- **Check**: Audio duration vs video duration
- **Fix**: Ensure both tracks have same duration in muxer

### Out of memory
- **Check**: Number of images and resolution
- **Fix**: Reduce image count or downscale images

---

**Status**: ✅ Production Ready  
**Last Updated**: 2025-10-28  
**Version**: 1.0.0

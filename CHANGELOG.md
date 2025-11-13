# Changelog

All notable changes to Instagram Post Maker Mobile will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-10-28

### Added - Video Creator Feature ⭐
- **Video Templates System**
  - Fade In template with customizable fade duration
  - Zoom In template with adjustable zoom scale and duration
  - Image Sequence template for multi-image slideshows
  - Template registry for easy extensibility

- **Image Sequence Template**
  - Multi-image grid selector with drag-to-reorder
  - Sequential and random playback modes
  - Repeat toggle to loop images
  - Duration per image control (0.01-60s precision)
  - Visual feedback showing calculated video duration

- **Video Duration Control**
  - Text input field for precise duration (1-60 seconds)
  - Replaced slider for better precision
  - Strict duration enforcement
  - Smart audio integration (uses minimum of video/audio duration)

- **Audio Integration**
  - Audio file picker (MP3, M4A, WAV, AAC)
  - Audio duration display
  - Preview playback controls
  - Automatic audio/video synchronization

- **Video Creation UI**
  - Real-time progress tracking (0-100%)
  - Cancel button during encoding
  - Success dialog with file path
  - Open button to view created video
  - Snackbar notifications

- **Video Output**
  - 1080×1920 HD resolution (9:16 portrait)
  - 30 fps frame rate
  - H.264/AVC codec (High Profile)
  - 8 Mbps bitrate
  - Template-based file naming

### Fixed
- **Critical: Frame Timing Issue**
  - Videos were playing at wrong speed (e.g., 7s video played in 4s)
  - Fixed by throttling frame submission to exactly 30 fps
  - Added `KEY_CAPTURE_RATE` to video format metadata
  - Ensures correct presentation timestamps

- **Duration Mismatch**
  - Video duration now strictly matches user selection
  - With audio: uses minimum of (video duration, audio duration)
  - Images repeat or skip to fill exact duration

- **File Saving Failures**
  - Replaced `renameTo()` with `copyTo()` for cross-storage reliability
  - Added media scanner notification for gallery visibility

- **Incomplete Frame Encoding**
  - Improved encoder draining logic
  - All frames now properly encoded (e.g., 210/210 instead of 209/210)
  - Added `INFO_TRY_AGAIN_LATER` handling

- **File Naming**
  - Videos now named by template: `{template}_{timestamp}.mp4`
  - Previously all named `fade_in_video_xxx.mp4`

### Changed
- **Duration Selector Widget**
  - Changed from slider to text input field
  - Increased maximum from 10s to 60s
  - Better precision for exact durations

- **Duration Per Image Input**
  - Changed from slider to text input field
  - Range: 0.01-60.0 seconds
  - Allows decimal precision

- **Template Selector UI**
  - Expandable horizontal scroll
  - Card-based layout matching PostMakerScreen
  - Better visual hierarchy

### Technical
- **Platform Channel Communication**
  - Flutter ↔ Android bidirectional messaging
  - Progress updates via method channel
  - Error handling with detailed messages

- **Video Encoding Pipeline**
  - MediaCodec with Surface input
  - Frame-by-frame rendering with timing control
  - MediaMuxer for audio/video merging
  - Proper resource cleanup

- **Memory Management**
  - Bitmap recycling after use
  - Temporary file cleanup
  - Efficient multi-image handling

### Documentation
- Added comprehensive VIDEO_CREATOR.md
- Updated PROJECT_STRUCTURE.md with video creator
- Created docs/README.md as documentation index
- Added this CHANGELOG.md

## [0.9.0] - Previous Version

### Features
- Image post creation with 6 social media templates
- Single image and 2×2 grid layouts
- 35+ custom fonts
- Live preview with pan/zoom
- High-resolution export (4x)
- Image cropping tools
- Video cropping tools

---

## Version History

- **1.0.0** (2025-10-28) - Video Creator Feature Release
- **0.9.0** - Image Post Maker Base Features

## Upgrade Notes

### From 0.9.0 to 1.0.0
- No breaking changes
- New video creator accessible from 4th tab in bottom navigation
- All existing image post features remain unchanged
- New dependencies: None (uses existing packages)

## Known Issues

### Fixed in 1.0.0
- ✅ Video duration mismatch
- ✅ Incorrect file naming
- ✅ Missing frames in output
- ✅ File save failures
- ✅ Imprecise duration control

### Active Issues
- None currently

## Future Releases

### Planned for 1.1.0
- More video templates (slide, rotate, pan)
- Text overlay on videos
- Video filters and color adjustments
- Transition effects between images

### Planned for 1.2.0
- Custom aspect ratios (16:9, 1:1, 4:5)
- Video quality settings (HD, Full HD, 4K)
- Background music library
- Video trimming/editing

### Planned for 2.0.0
- Batch video creation
- Cloud storage integration
- Video templates marketplace
- Advanced editing tools

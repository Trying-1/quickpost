# Instagram Post Maker Mobile 📱

A Flutter mobile app for creating stunning Instagram posts with customizable templates and a unique 2×2 grid layout!

## ✨ Features

### 🎨 Multiple Templates
- **Instagram Post** (1080×1350)
- **Instagram Grid** (1080×1350 with 2×2 images) ⭐ NEW
- **Instagram Story** (1080×1920)
- **Facebook Post** (1200×630)
- **Twitter Post** (1200×675)
- **LinkedIn Post** (1200×627)

### 🖼️ Image Modes
- **Single Image**: Classic post with one image
- **Grid Mode**: 2×2 grid with 4 images ⭐ NEW
  - Tap individual cells to select
  - Or use "Pick All" for batch selection
  - Clear all with one button

### ✍️ Text & Fonts
- Multi-line text overlay
- 30+ custom fonts included
- Real-time preview
- Auto font-size adjustment

### 🎯 Advanced Features
- **Image Adjustments** (Collapsible Panel)
  - Scale/Zoom controls (0.5× to 1.5×)
  - X/Y Position sliders (-300 to +300)
  - Manual input fields for precise control
  - Long-press for continuous adjustment
  - Reset all button
- **Text Styling**
  - Color picker for text
  - Background color customization
  - Text shadow toggle
  - Glow effect with radius control
  - Letter spacing adjustment
  - Font size multiplier
- **Smart Save System**
  - Save button in image section header
  - Disabled until preview is ready
  - Shows "Loading..." while rendering
  - Direct widget capture (WYSIWYG)
  - Beautiful success dialog with "Open in Gallery"
- **Live Preview**
  - Real-time drag and pinch gestures
  - Interactive image positioning
  - What you see is what you get
- **High-Quality Export**
  - 4× resolution capture
  - Lossless PNG output
  - Exact preview replication
- **Auto-save to Gallery**
  - Saves to Pictures/Instagram Post Maker/
  - Fallback to Download and DCIM
  - One-tap gallery opening
- **Three Tabs**: Post Maker, Image Cropper, Video Cropper

## 🚀 Quick Start

```bash
# Install dependencies
flutter pub get

# Run on device/emulator
flutter run

# Build APK
flutter build apk
```

## 📱 Usage

### Creating a Standard Post

1. Select template (Instagram Post, Facebook, etc.)
2. Tap "Gallery" or "Camera" to add image
3. **Adjust Image** (optional)
   - Drag to reposition
   - Pinch to zoom
   - Use sliders for precise control
   - Or expand "Image Adjustments" panel
4. Enter text in text field
5. **Style Text** (optional)
   - Select a font
   - Change text/background colors
   - Add shadow or glow effects
   - Adjust letter spacing
6. Wait for "Save" button to enable (shows "Loading..." while rendering)
7. Tap "Save" - Success dialog appears
8. Tap "Open" to view in gallery or "Close" to continue

### Creating a Grid Post ⭐

1. Select "Grid Post" template
2. Tap grid cells to add images individually
   - OR -
3. Tap "Pick All Images" to select 4 at once
4. Enter text
5. Select font
6. Tap "Save Post"

## 📂 Project Structure

```
lib/
├── main.dart                          # App entry (49 lines)
├── screens/
│   ├── post_maker_screen.dart        # Main post maker
│   ├── image_cropper_screen.dart     # Bulk image cropping
│   └── video_cropper_screen.dart     # Video trimming
├── templates/
│   ├── template_definitions.dart     # All template configs
│   └── base_template_widget.dart     # Template rendering
├── font_selector.dart                # Font selection
├── image_crop_editor.dart            # Crop utilities
└── image_generator.dart              # Export logic
```

## 🎨 Grid Template

The unique 2×2 grid template allows you to create eye-catching Instagram posts with multiple images:

```
┌─────────────────────┐
│   Text Box (20%)    │  ← Your text here
├──────────┬──────────┤
│  Image 1 │  Image 2 │
│          │          │  ← 2×2 grid
├──────────┼──────────┤
│  Image 3 │  Image 4 │
│          │          │
└──────────┴──────────┘
```

## 🛠️ Technical Stack

- **Framework**: Flutter 3.0+
- **State Management**: StatefulWidget
- **Image Processing**: `image` package
- **Permissions**: `permission_handler`
- **Image Picker**: `image_picker`
- **Platform**: Android & iOS

## 📦 Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  image_picker: ^1.0.4
  path_provider: ^2.1.1
  permission_handler: ^11.0.1
  image: ^4.1.3
  device_info_plus: ^9.1.1
  video_player: ^2.8.1
  open_file: ^3.3.2  # For opening saved images in gallery
```

## 🎯 Key Features

### Post Maker
- ✅ 6 social media templates
- ✅ Single & grid image modes
- ✅ 35+ custom fonts
- ✅ Pan/zoom controls
- ✅ Live preview
- ✅ High-quality export

### Image Cropper
- ✅ Batch image processing
- ✅ Crop multiple images
- ✅ Previous/Next navigation
- ✅ Export all at once

### Video Cropper
- ✅ Video trimming
- ✅ Timeline scrubbing
- ✅ Export cropped videos

## 📝 Permissions

The app requires:
- **Photos** (READ_MEDIA_IMAGES on Android 13+)
- **Storage** (Android ≤12)
- **Camera** (for taking photos)

Permissions are requested just-in-time when needed.

## 💾 Export

### Save Process
1. **Widget Capture**: Direct capture of preview widget (WYSIWYG)
2. **High Resolution**: 4× pixel ratio for crisp output
3. **Resize**: Downscaled to exact dimensions with cubic interpolation
4. **Format**: Lossless PNG for maximum quality

### Save Locations
Posts are saved to:
- `Pictures/Instagram Post Maker/` (preferred)
- `Download/Instagram Post Maker/` (fallback)
- `DCIM/Instagram Post Maker/` (alternative)

### File Format
- **Format**: PNG (lossless)
- **Resolution**: Template-specific (e.g., 1080×1350 for Instagram)
- **Quality**: Maximum (no compression artifacts)
- **Naming**: `instagram_post_[timestamp].png`

### Post-Save Actions
- Beautiful success dialog with file path
- "Open" button launches gallery app
- "Close" button returns to editor
- Debug logging for troubleshooting

## 🎨 Fonts

30+ high-quality Google Fonts included:
- AllertaSans, AlumniSans, Barrio, Bellota
- BhuTukaExpandedOne, Bokor, Caramel
- Explora, GrandifloraOne, KleeOne
- Lacquer, LuckiestGuy, MajorMonoDisplay
- Metrophobic, Michroma, NewRocker
- NewTegomin, Poppins, ProtestRevolution
- SourGummy, and more!

## 🔧 Architecture

### Clean Code Organization
- **main.dart**: 49 lines (app entry)
- **screens/**: Separate file per screen
- **templates/**: Template logic & configs
- **Clear separation**: Each file has one job

### Easy to Extend
```dart
// Add new template:
// 1. Edit templates/template_definitions.dart
'new_template': TemplateConfig(
  id: 'new_template',
  name: 'New Template',
  width: 1080.0,
  height: 1080.0,
  icon: Icons.star,
  color: Colors.blue,
),
// 2. Done! 🎉
```

## 🐛 Known Issues & Solutions

### Fixed Issues ✅
- ✅ **Widget capture inconsistency**: Now captures preview widget directly (WYSIWYG)
- ✅ **Scale range errors**: Values automatically clamped to valid ranges
- ✅ **GlobalKey conflicts**: Unique keys for each operation
- ✅ **Image loading timing**: Smart callback system ensures preview is ready
- ✅ **Save button state**: Disabled until preview fully loads

### Current Status
- Production ready ✅
- All major bugs resolved ✅
- WYSIWYG export working perfectly ✅

## 📄 License

MIT License

## 🤝 Contributing

Contributions welcome! Please:
1. Fork the repo
2. Create feature branch
3. Make changes
4. Submit pull request

## 📧 Support

For issues or questions, please open a GitHub issue.

## 🎉 Changelog

### Version 1.1.0 (Latest)
- ✅ **WYSIWYG Export**: Direct preview widget capture
- ✅ **Image Adjustments Panel**: Collapsible controls for scale/position
- ✅ **Text Styling**: Color, shadow, glow, spacing controls
- ✅ **Smart Save Button**: Disabled until preview ready, shows loading state
- ✅ **Success Dialog**: Beautiful UI with "Open in Gallery" button
- ✅ **PNG Export**: Lossless quality (was JPEG)
- ✅ **Bug Fixes**: Scale clamping, GlobalKey conflicts, timing issues
- ✅ **No Snackbars**: Clean UI without intrusive notifications

### Version 1.0.0
- ✅ Initial release
- ✅ 6 social media templates
- ✅ Grid template (2×2 images)
- ✅ 35+ custom fonts
- ✅ Image & video cropping
- ✅ High-quality export
- ✅ Clean code architecture

---

**Made with ❤️ using Flutter**

🚀 **Status**: Production Ready  
⭐ **Grid Template**: Fully Functional  
📱 **Platforms**: Android & iOS

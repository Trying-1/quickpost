# Application Architecture

## Overview

This is a Flutter-based mobile application for creating social media posts with images, text, and various templates. The app uses a hybrid architecture combining Flutter UI with native Android functionality for media operations.

---

## Architecture Layers

```
┌─────────────────────────────────────────────────────────────┐
│                     Presentation Layer                       │
│  (UI Screens, Widgets, State Management)                    │
├─────────────────────────────────────────────────────────────┤
│                     Business Logic Layer                     │
│  (Controllers, Utilities, Image Processing)                 │
├─────────────────────────────────────────────────────────────┤
│                     Data Layer                               │
│  (Models, Templates, Configuration)                         │
├─────────────────────────────────────────────────────────────┤
│                     Platform Layer                           │
│  (Native Android via Method Channels)                       │
└─────────────────────────────────────────────────────────────┘
```

---

## Directory Structure

```
lib/
├── screens/                    # UI Screens
│   ├── image_post/            # Post Maker functionality
│   │   └── post_maker_screen.dart
│   ├── image_cropper/         # Image cropping functionality
│   │   └── image_cropper_screen.dart
│   ├── video_creator/         # Video creation from images
│   │   └── video_creator_screen.dart
│   └── audio_library/         # Audio management
│       ├── audio_library_screen.dart
│       └── audio_extraction_screen.dart
│
├── widgets/                    # Reusable UI Components
│   ├── base_template_widget.dart  # Main template widget
│   └── video/                 # Video-related widgets
│
├── templates/                  # Template Definitions
│   └── image_post/
│       ├── single_image_template.dart
│       ├── grid_template.dart
│       └── template_definitions.dart
│
├── models/                     # Data Models
│   ├── template_config.dart
│   └── font_info.dart
│
├── utils/                      # Utility Classes
│   ├── image_generator.dart   # Image generation & saving
│   ├── font_selector.dart     # Font management
│   └── image_crop_editor.dart # Crop utilities
│
└── main.dart                   # App entry point

android/
└── app/src/main/kotlin/com/example/igpostmakermobile/
    └── MainActivity.kt         # Native Android code
```

---

## Core Components

### 1. Presentation Layer

#### Post Maker Screen (`post_maker_screen.dart`)
**Purpose:** Main screen for creating posts with images and text

**Key Features:**
- Template selection (Single Image, Grid)
- Text input with styling options
- Image import and management
- Real-time preview
- Export to gallery

**State Management:**
- Uses `StatefulWidget` with local state
- Controllers: `TextEditingController`, `TemplateViewController`
- State variables for styling, images, templates

**Key Methods:**
- `_savePost()` - Captures widget and saves to gallery
- `_pickImage()` / `_pickAllGridImages()` - Image selection
- `_buildPreviewSection()` - Renders live preview

#### Image Cropper Screen (`image_cropper_screen.dart`)
**Purpose:** Bulk image cropping with persistent settings

**Key Features:**
- Multi-image import
- Individual crop settings per image
- Drag-and-drop reordering
- Rotation and flip transformations
- Batch export

**State Management:**
- `List<File?>` for selected images
- `List<CroppedImageData>` for crop settings
- Current image index tracking

**Key Methods:**
- `_loadCurrentImage()` - Loads and restores crop settings
- `_saveCurrentCropSettings()` - Persists crop data
- `_cropImageAtIndex()` - Processes individual image
- `_exportAllCroppedImages()` - Batch export

#### Video Creator Screen (`video_creator_screen.dart`)
**Purpose:** Creates videos from images with audio

**Key Features:**
- Image-to-video conversion
- Audio track integration
- Duration control
- FFmpeg processing

#### Base Template Widget (`base_template_widget.dart`)
**Purpose:** Reusable template renderer for posts

**Key Features:**
- Text box with customizable styling
- Image display with zoom/pan controls
- Grid layout support (2x2)
- Export-ready rendering

**Widget Lifecycle:**
- `initState()` - Initialize controllers
- `didUpdateWidget()` - Handle prop changes, trigger image loading
- `build()` - Render template with current state

---

### 2. Business Logic Layer

#### Image Generator (`image_generator.dart`)
**Purpose:** Handles image generation and gallery saving

**Key Methods:**
```dart
static Future<String?> savePostToGallery({
  required String text,
  File? imageFile,
  TemplateTransform? transform,
  FontInfo? selectedFont,
  GlobalKey? templateKey,
})
```

**Process Flow:**
1. Request storage permissions
2. Capture widget as image (if templateKey provided)
3. Fallback to traditional generation (if imageFile provided)
4. Save to multiple directory paths (Pictures, Download, DCIM)
5. Trigger media scanner for gallery visibility
6. Return saved file path

**Media Scanning:**
```dart
static Future<void> _scanMediaFile(String filePath, String mimeType)
```
- Uses MethodChannel to call native Android MediaScanner
- Ensures files appear in gallery immediately

#### Template View Controller (`template_config.dart`)
**Purpose:** Manages image transformation state

**Properties:**
- `scale` - Image zoom level
- `offsetX`, `offsetY` - Image position
- `areaWidth`, `areaHeight` - Display area dimensions
- `imagePixelWidth`, `imagePixelHeight` - Original image dimensions

**Methods:**
- `saveInitialState()` - Store default values
- `reset()` - Restore to initial state

#### Font Selector (`font_selector.dart`)
**Purpose:** Font management and selection

**Features:**
- Predefined font list with weights and styles
- Font preview rendering
- Font info model

---

### 3. Data Layer

#### Template Configuration (`template_config.dart`)
**Purpose:** Define template metadata

**Structure:**
```dart
class TemplateConfig {
  final String id;
  final String name;
  final String description;
  final double width;
  final double height;
  final IconData icon;
  final Color color;
  final bool isGrid;
}
```

#### Template Definitions (`template_definitions.dart`)
**Purpose:** Central registry of available templates

**Templates:**
- `single_image_post` - Single image with text (1080x1350)
- `grid_post` - 2x2 grid with text (1080x1350)

#### Cropped Image Data
**Purpose:** Store crop settings per image

**Structure:**
```dart
class CroppedImageData {
  File? file;                    // Cropped image file
  int cropX, cropY;              // Crop coordinates (pixels)
  int cropWidth, cropHeight;     // Crop dimensions (pixels)
  double displayCropX, displayCropY;        // UI crop position
  double displayCropWidth, displayCropHeight; // UI crop size
  double displayImageWidth, displayImageHeight; // Display dimensions
  int rotation;                  // Rotation angle (0, 90, 180, 270)
  bool flipHorizontal;           // Horizontal flip state
  bool flipVertical;             // Vertical flip state
}
```

---

### 4. Platform Layer

#### Native Android Integration (`MainActivity.kt`)

**Method Channel:** `com.igpostmaker.video/processor`

**Exposed Methods:**

1. **scanMediaFile**
   ```kotlin
   private fun scanMediaFile(filePath: String, mimeType: String)
   ```
   - Notifies Android MediaStore about new files
   - Makes files visible in gallery apps
   - Uses `MediaScannerConnection.scanFile()`

2. **pickAudio** (existing)
   - Native audio file picker

3. **pickVideo** (existing)
   - Native video file picker

**Implementation:**
```kotlin
class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.igpostmaker.video/processor"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scanMediaFile" -> {
                        val filePath = call.argument<String>("filePath")
                        val mimeType = call.argument<String>("mimeType")
                        if (filePath != null) {
                            scanMediaFile(filePath, mimeType ?: "image/*")
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGUMENT", "File path is required", null)
                        }
                    }
                    // ... other methods
                }
            }
    }
}
```

---

## Data Flow

### Post Creation Flow

```
User Input
    ↓
[Post Maker Screen]
    ↓
Select Template → [Template Definitions]
    ↓
Add Images → [Image Picker]
    ↓
Add Text → [Text Controller]
    ↓
Apply Styling → [State Variables]
    ↓
Preview → [Base Template Widget]
    ↓
Save Button
    ↓
[Image Generator]
    ↓
Capture Widget → [RepaintBoundary]
    ↓
Save to Storage → [File System]
    ↓
Scan Media → [Method Channel] → [MainActivity.kt]
    ↓
Gallery Visibility ✓
```

### Image Cropping Flow

```
User Input
    ↓
[Image Cropper Screen]
    ↓
Import Images → [Image Picker]
    ↓
Select Image → [Current Index]
    ↓
Adjust Crop → [Crop State]
    ↓
Save Settings → [CroppedImageData]
    ↓
Navigate → [Previous/Next]
    ↓
Restore Settings → [Load from CroppedImageData]
    ↓
Export All
    ↓
Auto-crop uncropped → [_cropImageAtIndex]
    ↓
Save to Gallery → [Image Generator]
    ↓
Media Scan → [Method Channel]
```

---

## State Management Strategy

### Local State (StatefulWidget)
- Used for screen-specific state
- Simple and effective for isolated screens
- No external dependencies

### Controllers
- `TextEditingController` - Text input management
- `TemplateViewController` - Image transformation state
- Custom controllers for specific features

### State Persistence
- Crop settings stored in `CroppedImageData` objects
- Template configuration in const definitions
- No database or shared preferences needed

---

## Image Processing Pipeline

### Widget Capture Method
```dart
static Future<Uint8List?> _captureWidgetAsImage(GlobalKey key) async {
  RenderRepaintBoundary boundary = key.currentContext!.findRenderObject();
  ui.Image image = await boundary.toImage(pixelRatio: 3.0);
  ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData?.buffer.asUint8List();
}
```

**Advantages:**
- Captures exactly what user sees
- Supports custom fonts
- Handles complex layouts (grid mode)
- High quality output (3x pixel ratio)

### Image Cropping Pipeline
```
Original Image (File)
    ↓
Load as ui.Image
    ↓
Calculate crop coordinates
    ↓
Convert to img.Image (image package)
    ↓
Apply crop (img.copyCrop)
    ↓
Encode as JPEG
    ↓
Save to temp directory
    ↓
Store in CroppedImageData
```

---

## Permission Handling

### Required Permissions
- `Permission.storage` - File system access
- `Permission.photos` - Photo library access (Android 13+)

### Permission Strategy
```dart
await Permission.storage.request();
await Permission.photos.request();
```

**Approach:**
- Request minimally invasive permissions
- Avoid `MANAGE_EXTERNAL_STORAGE` (requires Settings navigation)
- Request at point of use, not app startup

---

## File Storage Strategy

### Save Locations (Priority Order)
1. `/storage/emulated/0/Pictures/Instagram Post Maker/`
2. `/storage/emulated/0/Download/Instagram Post Maker/`
3. `/storage/emulated/0/DCIM/Instagram Post Maker/`
4. External storage directory (fallback)

### File Naming
- Posts: `post_<timestamp>.png`
- Cropped images: `cropped_<index>_<timestamp>.jpg`
- Videos: `video_<timestamp>.mp4`

### Media Scanning
- Immediate scan after save
- Ensures gallery visibility
- Uses native Android MediaScanner

---

## Key Design Patterns

### 1. Widget Composition
- Small, reusable widgets
- Clear separation of concerns
- Template widget as base component

### 2. State Lifting
- State managed at appropriate level
- Pass callbacks for child-to-parent communication
- Controllers for shared state

### 3. Method Channel Pattern
- Flutter-to-Native communication
- Single channel for related operations
- Type-safe method calls

### 4. Factory Pattern
- Template definitions as const factories
- Centralized template registry
- Easy to add new templates

### 5. Strategy Pattern
- Different save strategies (widget capture vs traditional)
- Fallback mechanisms
- Flexible image processing

---

## Performance Considerations

### Image Loading
- Async loading with progress indicators
- Image caching by Flutter framework
- Efficient memory management

### Widget Capture
- High pixel ratio (3.0) for quality
- Async capture to avoid blocking UI
- Temporary delay for rendering

### Batch Operations
- Process images sequentially to avoid memory issues
- Progress feedback during export
- Efficient file I/O

---

## Error Handling

### Strategy
- Try-catch blocks around critical operations
- User-friendly error messages
- Graceful degradation (fallback paths)

### Example
```dart
try {
  // Primary operation
  await saveToGallery();
} catch (e) {
  // Show error dialog
  // Log error
  // Attempt recovery
}
```

---

## Testing Considerations

### Unit Testing
- Utility functions (image processing, calculations)
- Model classes
- Business logic

### Widget Testing
- Individual widgets
- User interactions
- State changes

### Integration Testing
- Full user flows
- File system operations
- Permission handling

---

## Future Architecture Improvements

### Potential Enhancements
1. **State Management Library** - Consider Riverpod/Bloc for complex state
2. **Repository Pattern** - Abstract data sources
3. **Dependency Injection** - Better testability
4. **Background Processing** - For heavy operations
5. **Caching Layer** - For templates and fonts
6. **Analytics Integration** - User behavior tracking
7. **Cloud Storage** - Backup and sync

### Scalability
- Current architecture supports adding new templates easily
- Method channel can accommodate more native features
- Widget-based approach allows UI customization

---

## Dependencies

### Core Flutter Packages
- `image_picker` - Image/video selection
- `image` - Image processing
- `permission_handler` - Permission management
- `path_provider` - File path access
- `open_file` - File opening

### Native Dependencies
- Android MediaScanner
- Android Storage Access Framework

---

## Security Considerations

### File Access
- Scoped storage compliance (Android 10+)
- Minimal permission requests
- Secure file paths

### Data Privacy
- No network requests
- No data collection
- Local-only processing

---

## Maintenance Guidelines

### Adding New Templates
1. Create template definition in `lib/templates/image_post/`
2. Add to `template_definitions.dart`
3. Update template selector UI
4. Test with various content

### Adding New Features
1. Identify appropriate layer
2. Follow existing patterns
3. Update documentation
4. Test thoroughly

### Code Style
- Follow Flutter/Dart conventions
- Meaningful variable names
- Comment complex logic
- Keep methods focused and small

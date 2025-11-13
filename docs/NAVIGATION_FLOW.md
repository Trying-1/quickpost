# Navigation Flow & App Structure

## App Entry Point

```
main.dart
    ↓
MaterialApp
    ↓
PostMakerScreen (Home)
```

---

## Main Navigation Structure

### Bottom Navigation Bar (4 Tabs)

```
┌─────────────────────────────────────────────────────────┐
│                    Post Maker Screen                     │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  [Post Maker] [Image Cropper] [Image to Video] [Audios] │
│       0              1                2             3    │
└─────────────────────────────────────────────────────────┘
```

**Navigation State:** `_currentBottomNavIndex`

**Tab Switching Logic:**
```dart
setState(() {
  _currentBottomNavIndex = index;
});
```

---

## Screen Hierarchy

### 1. Post Maker (Index 0)
**Route:** Home screen (default)
**Widget:** `PostMakerScreen` body content
**Purpose:** Create social media posts with images and text

**Sub-sections:**
- Template Selector (sticky top)
- Preview Section (sticky)
- Controls Section (scrollable)
  - Text Input
  - Image Section
  - Text Styling
  - Image Adjustments

**No Navigation:** Self-contained screen

---

### 2. Image Cropper (Index 1)
**Route:** Embedded in `PostMakerScreen`
**Widget:** `ImageCropperScreen`
**Purpose:** Bulk image cropping with persistent settings

**Entry Points:**
- Bottom navigation tab
- No direct route navigation

**Exit:**
- Bottom navigation to other tabs
- No back button (embedded)

**Floating Action Button:** Add more images

---

### 3. Image to Video (Index 2)
**Route:** Embedded in `PostMakerScreen`
**Widget:** `VideoCreatorScreen`
**Purpose:** Create videos from images with audio

**Entry Points:**
- Bottom navigation tab

**Exit:**
- Bottom navigation to other tabs

---

### 4. My Audios (Index 3)
**Route:** Embedded in `PostMakerScreen`
**Widget:** `AudioLibraryScreenWithFolders`
**Purpose:** Manage audio library

**Entry Points:**
- Bottom navigation tab

**Exit:**
- Bottom navigation to other tabs

**Floating Action Button:** 
- Opens `AudioExtractionScreen` via push navigation

---

## Navigation Patterns

### 1. Tab-Based Navigation (Primary)
**Type:** Bottom Navigation Bar
**Implementation:** Index-based state switching
**Screens:** Post Maker, Image Cropper, Video Creator, Audio Library

**Code:**
```dart
body: _currentBottomNavIndex == 0
    ? _buildPostMakerBody()
    : _currentBottomNavIndex == 1
        ? const ImageCropperScreen()
        : _currentBottomNavIndex == 2
            ? const VideoCreatorScreen()
            : const AudioLibraryScreenWithFolders(),
```

**Characteristics:**
- Instant switching (no animation)
- State preserved per tab
- No back button needed
- No route stack

---

### 2. Push Navigation (Secondary)
**Type:** Material Route Push
**Used For:** Modal screens and secondary features

**Example: Audio Extraction**
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const AudioExtractionScreen(),
  ),
);
```

**Characteristics:**
- Slide-in animation
- Back button in AppBar
- Route stack maintained
- Can pop back

---

### 3. Dialog Navigation (Tertiary)
**Type:** Modal dialogs
**Used For:** Confirmations, results, errors

**Types:**
1. **Loading Dialog** - During save operations
2. **Success Dialog** - Post saved successfully
3. **Error Dialog** - Operation failed
4. **Confirmation Dialog** - User confirmations

**Example:**
```dart
showDialog(
  context: context,
  barrierDismissible: false,
  builder: (BuildContext context) {
    return Dialog(
      child: // Dialog content
    );
  },
);
```

**Exit:**
```dart
Navigator.of(context).pop();
```

---

## Screen State Management

### Post Maker Screen State
**Persisted Across Tab Switches:** ✓

**State Variables:**
- `_selectedTemplate` - Current template
- `_selectedImage` - Single image mode
- `_gridImages` - Grid mode images
- `_textController` - Text content
- `_selectedFont` - Font selection
- Text styling options (color, shadow, glow, etc.)
- Image adjustments (scale, position)
- `_isPreviewReady` - Preview loading state
- `_showPlaceholder` - Placeholder visibility

**State Preservation:**
- State maintained when switching tabs
- Returns to same state when navigating back
- No state reset on tab switch

---

### Image Cropper Screen State
**Persisted Across Tab Switches:** ✓

**State Variables:**
- `_selectedImages` - List of imported images
- `_croppedImages` - Crop data per image
- `_currentImageIndex` - Current image being edited
- Crop area properties (x, y, width, height)
- Transform properties (rotation, flip)

**State Preservation:**
- Images remain loaded
- Crop settings preserved per image
- Current index maintained

---

### Video Creator Screen State
**Persisted Across Tab Switches:** ✓

**State Variables:**
- Selected images
- Audio track
- Video settings

---

### Audio Library Screen State
**Persisted Across Tab Switches:** ✓

**State Variables:**
- Audio file list
- Folder structure
- Selected audio

---

## Navigation Flow Diagrams

### Complete App Navigation Map

```
┌─────────────────────────────────────────────────────────────┐
│                         App Start                            │
│                        (main.dart)                           │
└────────────────────────┬────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│                    PostMakerScreen                           │
│                  (Bottom Navigation)                         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ Post Maker   │  │Image Cropper │  │Image to Video│     │
│  │   (Tab 0)    │  │   (Tab 1)    │  │   (Tab 2)    │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│                                                              │
│  ┌──────────────┐                                           │
│  │  My Audios   │──────────────┐                           │
│  │   (Tab 3)    │              │ FAB                        │
│  └──────────────┘              ↓                            │
│                     ┌──────────────────────┐                │
│                     │ Audio Extraction     │                │
│                     │  (Push Navigation)   │                │
│                     └──────────────────────┘                │
└─────────────────────────────────────────────────────────────┘
```

---

### Post Maker Flow

```
Start
  ↓
Select Template
  ├─→ Single Image
  │     ↓
  │   Import Image
  │     ↓
  │   Add Text (optional)
  │     ↓
  │   Apply Styling
  │     ↓
  │   Adjust Image
  │     ↓
  │   Preview
  │     ↓
  │   Save
  │
  └─→ Grid (2x2)
        ↓
      Import All Images (or one by one)
        ↓
      Add Text (optional)
        ↓
      Apply Styling
        ↓
      Preview
        ↓
      Save
          ↓
        [Success Dialog]
          ├─→ Close
          └─→ Open File
```

---

### Image Cropper Flow

```
Start
  ↓
Import Images (bulk)
  ↓
┌─────────────────────┐
│ For Each Image:     │
│   ↓                 │
│ Set Crop Area       │
│   ↓                 │
│ Apply Rotation/Flip │
│   ↓                 │
│ Navigate Next       │
│   ↓                 │
│ [Settings Saved]    │
└─────────────────────┘
  ↓
Export All
  ↓
[Auto-crop uncropped images]
  ↓
Save to Gallery
  ↓
[Success Dialog]
```

---

### Video Creator Flow

```
Start
  ↓
Import Images
  ↓
Select Audio (optional)
  ↓
Set Duration
  ↓
Preview
  ↓
Create Video
  ↓
[Processing Dialog]
  ↓
Save to Gallery
  ↓
[Success Dialog]
```

---

### Audio Extraction Flow

```
My Audios Tab
  ↓
[FAB] Extract Audio
  ↓
AudioExtractionScreen (Push)
  ↓
Select Video
  ↓
Extract Audio
  ↓
[Processing]
  ↓
Save to Library
  ↓
[Success]
  ↓
Back to My Audios
```

---

## User Journey Examples

### Journey 1: Create Single Image Post

```
1. App Launch
   └─→ Post Maker (Tab 0) - Default

2. Select Template
   └─→ "Single Image" template

3. Add Image
   └─→ Tap "Add image" button in preview
   └─→ Image picker opens
   └─→ Select image
   └─→ Image loads in preview

4. Add Text
   └─→ Tap text field
   └─→ Enter text
   └─→ Text appears in preview

5. Style Text (optional)
   └─→ Change color
   └─→ Add shadow/glow
   └─→ Adjust font size
   └─→ Change letter spacing

6. Adjust Image (optional)
   └─→ Zoom in/out
   └─→ Pan position
   └─→ Reset if needed

7. Save
   └─→ Tap "Save" button
   └─→ Loading dialog appears
   └─→ Success dialog shows
   └─→ Options: Close or Open File

8. Done
   └─→ Image in gallery
```

---

### Journey 2: Bulk Image Cropping

```
1. Navigate to Image Cropper
   └─→ Tap "Image Cropper" tab (Tab 1)

2. Import Images
   └─→ Tap "Select Images" or FAB
   └─→ Multi-select images
   └─→ Images load in list

3. Crop First Image
   └─→ Adjust crop area (drag corners/edges)
   └─→ Rotate if needed
   └─→ Flip if needed

4. Move to Next Image
   └─→ Tap "Next" button
   └─→ [Crop settings saved automatically]
   └─→ Next image loads

5. Repeat for Each Image
   └─→ Set crop for each
   └─→ Or skip (will use default)

6. Export All
   └─→ Tap "Export All" button
   └─→ [Uncropped images auto-cropped]
   └─→ Processing dialog
   └─→ Success dialog

7. Done
   └─→ All images in gallery
```

---

### Journey 3: Create Grid Post

```
1. Post Maker Tab
   └─→ Already on Tab 0

2. Select Grid Template
   └─→ Tap "Grid Post" template

3. Import All Images
   └─→ Tap "Import All (4)" button
   └─→ Select 4 images
   └─→ Images load in grid preview

4. Reorder (optional)
   └─→ Drag images in list to reorder
   └─→ Preview updates

5. Remove Image (optional)
   └─→ Tap delete button on image
   └─→ Import replacement

6. Add Text
   └─→ Enter text in text field
   └─→ Text appears above grid

7. Save
   └─→ Tap "Save" button
   └─→ Processing
   └─→ Success

8. Done
   └─→ Grid post in gallery
```

---

## Navigation State Persistence

### What Persists:
✓ Tab selection
✓ Screen state within each tab
✓ Text input
✓ Image selections
✓ Crop settings
✓ Template selection
✓ Styling options

### What Doesn't Persist:
✗ Dialog state (closes on navigation)
✗ Loading states
✗ Error messages
✗ Temporary UI states

---

## Back Button Behavior

### Android Back Button

**In Main Screen (Any Tab):**
- Exits app (no confirmation)

**In Pushed Screen (e.g., Audio Extraction):**
- Pops back to previous screen
- Returns to tab that launched it

**In Dialog:**
- Closes dialog (if dismissible)
- Returns to underlying screen

---

## Deep Linking (Future)

### Potential Routes:
```
/                          → Post Maker
/post-maker                → Post Maker
/image-cropper             → Image Cropper
/video-creator             → Video Creator
/audio-library             → Audio Library
/audio-extraction          → Audio Extraction
```

**Not Currently Implemented**

---

## Navigation Best Practices

### Current Implementation

1. **Tab Navigation**
   - Fast switching
   - No animations
   - State preserved

2. **Push Navigation**
   - For secondary screens
   - Clear back navigation
   - Proper route stack

3. **Dialog Navigation**
   - For temporary content
   - Non-blocking when appropriate
   - Clear dismiss actions

### Recommendations

1. **Maintain Current Pattern**
   - Tab-based for main features
   - Push for auxiliary features
   - Dialogs for feedback

2. **State Management**
   - Keep state at appropriate level
   - Preserve across tab switches
   - Clear when appropriate

3. **User Feedback**
   - Loading indicators
   - Success/error dialogs
   - Progress feedback

---

## Navigation Transitions

### Tab Switching
**Animation:** None (instant)
**Duration:** 0ms
**Type:** State change only

### Push Navigation
**Animation:** Slide from right
**Duration:** 300ms (default Material)
**Type:** MaterialPageRoute

### Dialog
**Animation:** Fade + Scale
**Duration:** 200ms (default)
**Type:** Dialog route

---

## Error Handling in Navigation

### Navigation Errors
```dart
try {
  Navigator.push(context, route);
} catch (e) {
  // Handle navigation error
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Navigation error: $e')),
  );
}
```

### Back Navigation Safety
```dart
if (Navigator.canPop(context)) {
  Navigator.pop(context);
} else {
  // Handle root screen
}
```

---

## Future Navigation Enhancements

### Potential Improvements

1. **Named Routes**
   ```dart
   MaterialApp(
     routes: {
       '/': (context) => PostMakerScreen(),
       '/cropper': (context) => ImageCropperScreen(),
       '/video': (context) => VideoCreatorScreen(),
     },
   )
   ```

2. **Route Guards**
   - Check permissions before navigation
   - Validate state before screen access

3. **Navigation Analytics**
   - Track screen views
   - Monitor user flows
   - Identify drop-off points

4. **Deep Linking**
   - Open specific screens from external links
   - Share specific content

5. **Navigation History**
   - Track user journey
   - Provide breadcrumbs
   - Enable advanced back navigation

---

## Navigation Testing

### Test Cases

1. **Tab Switching**
   - Switch between all tabs
   - Verify state preservation
   - Check performance

2. **Push Navigation**
   - Navigate to secondary screens
   - Verify back button works
   - Check route stack

3. **Dialog Navigation**
   - Open/close dialogs
   - Test dismissible behavior
   - Verify underlying screen state

4. **Back Button**
   - Test Android back button
   - Verify app exit
   - Check dialog dismissal

5. **State Persistence**
   - Switch tabs with data
   - Verify data remains
   - Check memory usage

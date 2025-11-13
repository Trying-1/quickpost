# Changelog - October 30, 2025

## Major Updates and Improvements

### 1. Image Gallery Visibility Fix
**Issue:** Images saved from Post Maker and Image Cropper were not appearing in phone gallery's "All" section.

**Solution:**
- Implemented native Android MediaStore scanning via MethodChannel
- Added `scanMediaFile` method in `MainActivity.kt`
- Integrated media scanning in `image_generator.dart` and `image_cropper_screen.dart`
- Fixed channel name mismatch: Changed from `com.example.igpostmakermobile/video_creator` to `com.igpostmaker.video/processor`

**Files Modified:**
- `android/app/src/main/kotlin/com/example/igpostmakermobile/MainActivity.kt`
- `lib/utils/image_generator.dart`
- `lib/screens/image_cropper/image_cropper_screen.dart`

---

### 2. Image Cropper - Persistent Crop Settings
**Issue:** Crop settings were lost when navigating between images in bulk import mode.

**Solution:**
- Enhanced `CroppedImageData` class with mutable fields for display crop settings
- Added `_saveCurrentCropSettings()` method to preserve crop position, size, rotation, and flip settings
- Updated `_loadCurrentImage()` to restore saved settings when switching between images
- Modified `_previousImage()` and `_nextImage()` to save settings before navigation

**Features:**
- Each image remembers its individual crop settings
- Navigate freely between images without losing crop adjustments
- Export all images with their custom crops

**Files Modified:**
- `lib/screens/image_cropper/image_cropper_screen.dart`

---

### 3. Image Cropper - Export All & Remove Image
**Issue:** Export All button was disabled until images were manually cropped; no way to remove unwanted images.

**Solution:**
- Export All button now always enabled when images are imported
- Added `_cropImageAtIndex()` method to auto-crop uncropped images during export
- Added remove image button next to image counter
- Implemented `_removeCurrentImage()` method with proper index adjustment

**Features:**
- Import multiple images, set crops for some, export all (uncropped use default 60% centered crop)
- Remove unwanted images with delete button
- Batch export workflow

**Files Modified:**
- `lib/screens/image_cropper/image_cropper_screen.dart`

---

### 4. Post Maker - Grid Template Bulk Import
**Issue:** Grid template required importing 4 images one by one.

**Solution:**
- Added "Import All (4)" button above grid image list
- Added "Clear All" button to remove all grid images at once
- Button only visible in grid mode
- Uses existing `_pickAllGridImages()` method

**Files Modified:**
- `lib/screens/image_post/post_maker_screen.dart`

---

### 5. Post Maker - Grid Mode Preview & Save Fixes
**Issue:** 
- "Add image" button remained visible after importing grid images
- Save button stuck on "Loading..." indefinitely
- Null check error when saving grid posts

**Solution:**
- Fixed "Add image" button visibility check for grid mode
- Added `frameBuilder` to grid image widgets to detect when images load
- Made `imageFile` parameter optional in `ImageGenerator.savePostToGallery()`
- Updated save logic to pass `null` for imageFile in grid mode
- Grid posts now save via widget capture

**Files Modified:**
- `lib/screens/image_post/post_maker_screen.dart`
- `lib/widgets/base_template_widget.dart`
- `lib/utils/image_generator.dart`

---

### 6. Removed Instagram Branding
**Issue:** App had Instagram-specific naming, limiting its general-purpose appeal.

**Solution:**
- Renamed template files:
  - `instagram_post_template.dart` → `single_image_template.dart`
  - `instagram_grid_template.dart` → `grid_template.dart`
- Updated template IDs:
  - `instagram_post` → `single_image_post`
  - `instagram_grid` → `grid_post`
- Updated template names:
  - `instagramPostTemplate` → `singleImageTemplate`
  - `instagramGridTemplate` → `gridTemplate`
- Changed display names:
  - "Instagram Post" → "Single Image"
  - "Images (2x2 Grid)" → "2x2 Grid"
- Updated file naming: `instagram_post_*.png` → `post_*.png`

**Files Modified:**
- `lib/templates/image_post/single_image_template.dart` (renamed)
- `lib/templates/image_post/grid_template.dart` (renamed)
- `lib/templates/image_post/template_definitions.dart`
- `lib/screens/image_post/post_maker_screen.dart`
- `lib/utils/image_generator.dart`

---

### 7. Preview Widget UI Improvements
**Issue:** Preview had padding and rounded corners that cropped the image edges.

**Solution:**
- Removed padding from preview container
- Removed rounded corners and background
- Changed from `Container` with `BoxDecoration` to simple `SizedBox`
- Added subtle shadow for visual separation (10% opacity, 10px blur, 4px offset)

**Files Modified:**
- `lib/screens/image_post/post_maker_screen.dart`

---

### 8. Placeholder Text in Saved Images Fix
**Issue:** When saving without entering text, the placeholder "Tap to add text..." was captured in output images.

**Solution:**
- Added `showPlaceholder` parameter to `InstagramPostTemplate` widget
- Made TextField's `hintText` conditional based on `showPlaceholder` flag
- Added `_showPlaceholder` state variable in post maker
- Hide placeholder before capture, restore after save (using `finally` block)
- Updated loading dialog to show "Saving without text..." when appropriate

**Features:**
- Saves with text: Normal behavior
- Saves without text: Empty text box (no placeholder)
- Placeholder returns immediately after save completes

**Files Modified:**
- `lib/widgets/base_template_widget.dart`
- `lib/screens/image_post/post_maker_screen.dart`

---

## Technical Improvements

### Method Channel Integration
- Established proper Flutter-to-Native communication for media scanning
- Consistent channel naming across codebase

### State Management
- Improved crop settings persistence across navigation
- Better preview state tracking for grid mode

### Error Handling
- Added null safety for grid mode operations
- Proper cleanup in `finally` blocks

### Code Organization
- Separated template definitions into individual files
- Generic naming for platform-agnostic branding

---

## Files Summary

### New Files
- `lib/templates/image_post/single_image_template.dart`
- `lib/templates/image_post/grid_template.dart`

### Deleted Files
- `lib/templates/image_post/instagram_post_template.dart`
- `lib/templates/image_post/instagram_grid_template.dart`
- `lib/screens/video_cropper/video_cropper_screen.dart` (removed earlier)
- `android/app/src/main/kotlin/com/example/igpostmakermobile/VideoProcessor.kt` (removed earlier)

### Modified Files
- `lib/screens/image_post/post_maker_screen.dart`
- `lib/screens/image_cropper/image_cropper_screen.dart`
- `lib/widgets/base_template_widget.dart`
- `lib/utils/image_generator.dart`
- `lib/templates/image_post/template_definitions.dart`
- `android/app/src/main/kotlin/com/example/igpostmakermobile/MainActivity.kt`

---

## User Experience Improvements

1. **Gallery Integration:** All saved images now appear automatically in phone gallery
2. **Efficient Workflow:** Bulk image operations with persistent settings
3. **Flexible Export:** Export all images even if not all are manually cropped
4. **Clean Output:** No placeholder text in saved images when text is empty
5. **Better Preview:** Full image visible without cropping from padding/corners
6. **Generic Branding:** Platform-agnostic naming for wider appeal
7. **Grid Mode:** Streamlined bulk import and proper save functionality

---

## Next Steps / Known Issues

- None currently identified
- All major features working as expected
- Gallery visibility confirmed working
- Grid mode fully functional
- Placeholder text issue resolved

# Project Structure and Cleanup Guide

## Overview

This guide explains the QuickPost project structure, what folders are necessary, what can be deleted, and how to optimize your project size.

---

## Table of Contents

1. [Project Structure](#project-structure)
2. [Folder Breakdown](#folder-breakdown)
3. [What to Keep vs. Delete](#what-to-keep-vs-delete)
4. [Storage Analysis](#storage-analysis)
5. [Safe Cleanup Steps](#safe-cleanup-steps)
6. [Rebuilding After Cleanup](#rebuilding-after-cleanup)

---

## Project Structure

### Complete Project Layout

```
/home/trexx/
├── projects/
│   └── quickpost/                          (Your Flutter App - ~1-2GB)
│       ├── android/
│       │   ├── app/
│       │   │   ├── src/
│       │   │   │   ├── main/
│       │   │   │   │   ├── cpp/            (Native C++ code)
│       │   │   │   │   │   ├── CMakeLists.txt
│       │   │   │   │   │   ├── myffmpeg.cpp
│       │   │   │   │   │   ├── ffmpeg_common.h/.cpp
│       │   │   │   │   │   └── ffmpeg_text_overlay.h/.cpp
│       │   │   │   │   ├── kotlin/         (Kotlin bridge code)
│       │   │   │   │   ├── java/
│       │   │   │   │   └── res/
│       │   │   │   └── androidTest/
│       │   │   ├── build/                  (Build artifacts - can be deleted)
│       │   │   └── build.gradle
│       │   ├── gradle/
│       │   └── build.gradle
│       ├── lib/                            (Dart/Flutter code)
│       │   └── screens/
│       │       └── text_box_overlay/
│       │           └── text_box_overlay_screen.dart
│       ├── docs/                           (Documentation)
│       │   ├── FFMPEG_INTEGRATION.md
│       │   ├── EXTENDING_FFMPEG_FEATURES.md
│       │   ├── CPP_HEADERS_AND_IMPLEMENTATION.md
│       │   ├── REFACTORING_NOTES.md
│       │   └── PROJECT_STRUCTURE_AND_CLEANUP.md
│       ├── pubspec.yaml
│       ├── pubspec.lock
│       ├── .gitignore
│       ├── README.md
│       └── ffmpegcompilation/              (❌ CAN DELETE - 2-3GB)
│           ├── ffmpeg-source/
│           ├── build/
│           └── prefix/
│
├── ffmpeg-android/                         (✅ KEEP - 500MB-1GB)
│   ├── ffmpeg-source/                      (FFmpeg source code)
│   ├── build/                              (Build artifacts)
│   └── prefix/
│       └── arm64-v8a/                      (✅ ESSENTIAL - Used by CMake)
│           ├── include/                    (FFmpeg headers)
│           │   ├── libavcodec/
│           │   ├── libavformat/
│           │   ├── libavfilter/
│           │   ├── libavutil/
│           │   ├── libswscale/
│           │   ├── libswresample/
│           │   └── ...
│           └── lib/                        (Compiled libraries)
│               ├── libavcodec.a
│               ├── libavformat.a
│               ├── libavfilter.a
│               ├── libavutil.a
│               ├── libswscale.a
│               ├── libswresample.a
│               ├── libx264.a
│               ├── libfreetype.a
│               ├── libharfbuzz.a
│               ├── libfribidi.a
│               └── ...
│
└── Android/
    └── Sdk/
        └── ndk/
            └── 27.3.13750724/              (✅ KEEP - Android NDK)
```

---

## Folder Breakdown

### Essential Folders (KEEP)

#### 1. `/home/trexx/projects/quickpost/android/app/src/main/`

**Contains**: Source code for Android app
- `cpp/` - Native C++ code for FFmpeg
- `kotlin/` - Kotlin bridge and MainActivity
- `java/` - Java code
- `res/` - Android resources (layouts, drawables, etc.)

**Size**: ~50-100MB
**Keep**: ✅ YES - Core app code

**What's inside**:
```
cpp/
├── CMakeLists.txt              ← Build configuration
├── myffmpeg.cpp                ← JNI dispatcher
├── ffmpeg_common.h/.cpp        ← Shared utilities
└── ffmpeg_text_overlay.h/.cpp  ← Text overlay feature

kotlin/
├── MainActivity.kt             ← MethodChannel handler
├── FFmpegTextOverlay.kt        ← JNI bridge
└── ...
```

#### 2. `/home/trexx/projects/quickpost/lib/`

**Contains**: Dart/Flutter code
- UI screens
- State management
- Business logic

**Size**: ~50-100MB
**Keep**: ✅ YES - Core app code

#### 3. `/home/trexx/ffmpeg-android/prefix/arm64-v8a/`

**Contains**: Compiled FFmpeg libraries and headers
- `include/` - FFmpeg header files
- `lib/` - Compiled `.a` static libraries

**Size**: ~500MB-1GB
**Keep**: ✅ YES - **ESSENTIAL for building**

**Referenced by**: `CMakeLists.txt`
```cmake
set(FFMPEG_PREFIX "/home/trexx/ffmpeg-android/prefix/arm64-v8a")
include_directories(${FFMPEG_PREFIX}/include)
link_directories(${FFMPEG_PREFIX}/lib)
```

#### 4. `/home/trexx/Android/Sdk/ndk/27.3.13750724/`

**Contains**: Android NDK toolchain
**Size**: ~500MB-1GB
**Keep**: ✅ YES - Required for C++ compilation

---

### Temporary/Unnecessary Folders (CAN DELETE)

#### 1. `/home/trexx/projects/quickpost/ffmpegcompilation/` ❌

**Contains**: FFmpeg source code and build artifacts
- FFmpeg source files
- Build intermediate files
- Object files (.o)
- Temporary build files

**Size**: ~2-3GB
**Keep**: ❌ NO - Not needed after compilation

**Why delete**:
- FFmpeg already compiled into `/home/trexx/ffmpeg-android/prefix/arm64-v8a/`
- Source code not referenced by project
- Only needed if you want to recompile FFmpeg
- Takes up significant disk space

**When you might need it**:
- If you want to modify FFmpeg source code
- If you want to enable new features (but you can rebuild in `/home/trexx/ffmpeg-android/` instead)

#### 2. `/home/trexx/projects/quickpost/build/` ❌

**Contains**: Flutter build artifacts
- Compiled APK/AAB files
- Intermediate build files
- CMake build outputs

**Size**: ~500MB-1GB
**Keep**: ❌ NO - Regenerated on each build

**Safe to delete**: Yes, run `flutter clean` to remove

**When to delete**:
- After successful build
- Before committing to git (should be in `.gitignore`)
- To free up space

#### 3. `/home/trexx/projects/quickpost/.dart_tool/` ❌

**Contains**: Dart build cache
**Size**: ~100-500MB
**Keep**: ❌ NO - Regenerated automatically

**Safe to delete**: Yes, regenerated on next `flutter pub get`

#### 4. `/home/trexx/projects/quickpost/.gradle/` ❌

**Contains**: Gradle build cache
**Size**: ~100-500MB
**Keep**: ❌ NO - Regenerated automatically

**Safe to delete**: Yes, regenerated on next build

---

## What to Keep vs. Delete

### Summary Table

| Folder | Location | Size | Keep? | Reason |
|--------|----------|------|-------|--------|
| `android/app/src/main/cpp/` | Inside project | 50-100MB | ✅ YES | Native C++ source code |
| `android/app/src/main/kotlin/` | Inside project | 50-100MB | ✅ YES | Kotlin bridge code |
| `lib/` | Inside project | 50-100MB | ✅ YES | Flutter/Dart code |
| `docs/` | Inside project | 1-5MB | ✅ YES | Documentation |
| `pubspec.yaml` | Inside project | <1MB | ✅ YES | Dependencies |
| `ffmpegcompilation/` | Inside project | 2-3GB | ❌ NO | Source code (not needed) |
| `build/` | Inside project | 500MB-1GB | ❌ NO | Build artifacts |
| `.dart_tool/` | Inside project | 100-500MB | ❌ NO | Build cache |
| `.gradle/` | Inside project | 100-500MB | ❌ NO | Build cache |
| `ffmpeg-android/prefix/arm64-v8a/` | Home directory | 500MB-1GB | ✅ YES | **ESSENTIAL** - Compiled libs |
| `ffmpeg-android/ffmpeg-source/` | Home directory | 500MB | ❓ OPTIONAL | Source code (keep if you might rebuild) |
| `ffmpeg-android/build/` | Home directory | 500MB | ❌ NO | Build artifacts |
| `Android/Sdk/ndk/` | Home directory | 500MB-1GB | ✅ YES | Android NDK |

---

## Storage Analysis

### Before Cleanup

```
/home/trexx/projects/quickpost/
├── android/                    ~500MB
├── lib/                        ~100MB
├── build/                      ~1GB        ← Can delete
├── .dart_tool/                 ~300MB      ← Can delete
├── .gradle/                    ~300MB      ← Can delete
├── ffmpegcompilation/          ~2-3GB      ← Can delete
└── Other files                 ~100MB
                               ─────────
TOTAL PROJECT SIZE:            ~4-5GB

/home/trexx/ffmpeg-android/    ~1-2GB      ← KEEP
/home/trexx/Android/Sdk/ndk/   ~1GB        ← KEEP
```

**Total disk usage**: ~6-8GB

### After Cleanup

```
/home/trexx/projects/quickpost/
├── android/                    ~500MB
├── lib/                        ~100MB
├── docs/                       ~5MB
└── Other files                 ~100MB
                               ─────────
TOTAL PROJECT SIZE:            ~700MB

/home/trexx/ffmpeg-android/    ~1-2GB      ← KEEP
/home/trexx/Android/Sdk/ndk/   ~1GB        ← KEEP
```

**Total disk usage**: ~2.7-3.7GB

**Space saved**: ~3-4GB! 🎉

---

## Safe Cleanup Steps

### Step 1: Verify Project References

Check if `ffmpegcompilation` is referenced anywhere:

```bash
# Search for references
grep -r "ffmpegcompilation" /home/trexx/projects/quickpost/

# Should return nothing
```

### Step 2: Verify CMakeLists.txt Points to Correct Location

```bash
# Check the FFmpeg prefix path
cat /home/trexx/projects/quickpost/android/app/src/main/cpp/CMakeLists.txt | grep FFMPEG_PREFIX
```

**Expected output**:
```
set(FFMPEG_PREFIX "/home/trexx/ffmpeg-android/prefix/arm64-v8a")
```

**NOT**:
```
set(FFMPEG_PREFIX "/home/trexx/projects/quickpost/ffmpegcompilation/...")
```

### Step 3: Backup (Optional but Recommended)

```bash
# Create backup before deletion
tar -czf ~/ffmpegcompilation_backup.tar.gz \
    /home/trexx/projects/quickpost/ffmpegcompilation/

# Or just move it
mv /home/trexx/projects/quickpost/ffmpegcompilation \
   /home/trexx/ffmpegcompilation_backup
```

### Step 4: Delete Unnecessary Folders

```bash
# Delete FFmpeg compilation folder (2-3GB saved)
rm -rf /home/trexx/projects/quickpost/ffmpegcompilation

# Delete build artifacts (1GB saved)
rm -rf /home/trexx/projects/quickpost/build

# Delete Dart cache (300MB saved)
rm -rf /home/trexx/projects/quickpost/.dart_tool

# Delete Gradle cache (300MB saved)
rm -rf /home/trexx/projects/quickpost/.gradle
```

### Step 5: Verify Deletion

```bash
# Check project size
du -sh /home/trexx/projects/quickpost/

# Should be ~700MB-1GB instead of 4-5GB
```

### Step 6: Verify Build Still Works

```bash
cd /home/trexx/projects/quickpost

# Clean and rebuild
flutter clean
flutter pub get
flutter run

# Should build successfully
```

---

## Rebuilding After Cleanup

### If Build Fails

**Error**: "Cannot find FFmpeg headers"

**Solution**:
1. Verify `/home/trexx/ffmpeg-android/prefix/arm64-v8a/` exists
2. Check CMakeLists.txt has correct path
3. Run `flutter clean` and try again

### If You Need to Rebuild FFmpeg

If you deleted the source and need to rebuild:

```bash
# Go to FFmpeg directory (not inside project)
cd /home/trexx/ffmpeg-android

# Check if source exists
ls ffmpeg-source/

# If not, you'll need to download FFmpeg again
# But the compiled version in prefix/ is still usable
```

---

## Git Configuration

### .gitignore

Make sure your `.gitignore` includes:

```gitignore
# Build artifacts
build/
.dart_tool/
.gradle/
.idea/

# FFmpeg compilation (if you keep it)
ffmpegcompilation/

# Android build
android/.gradle/
android/local.properties
android/app/debug/
android/app/release/

# iOS build
ios/Pods/
ios/Flutter/Flutter.podspec

# General
*.iml
*.log
.DS_Store
```

This prevents large build artifacts from being committed to git.

---

## Folder Dependencies

### What Depends on What

```
CMakeLists.txt
    ↓
    References: /home/trexx/ffmpeg-android/prefix/arm64-v8a/
    ↓
    Needs: include/ and lib/ folders
    ↓
    ✅ ESSENTIAL - Cannot delete

ffmpegcompilation/
    ↓
    Not referenced by any build files
    ↓
    ❌ CAN DELETE - Safe to remove

build/
    ↓
    Generated by Flutter/Gradle
    ↓
    ❌ CAN DELETE - Regenerated on next build

.dart_tool/
    ↓
    Generated by Flutter
    ↓
    ❌ CAN DELETE - Regenerated on next `flutter pub get`
```

---

## Recommended Cleanup Schedule

### Immediate (Do Now)
- Delete `ffmpegcompilation/` (2-3GB)
- Delete `build/` (1GB)
- Delete `.dart_tool/` (300MB)
- Delete `.gradle/` (300MB)

**Savings**: ~3.6-4.3GB

### Before Committing to Git
- Ensure `.gitignore` includes build folders
- Run `flutter clean`
- Verify `.gitignore` is working

### Periodically
- Run `flutter clean` after major changes
- Delete old build artifacts
- Check project size with `du -sh`

---

## Troubleshooting

### Q: Can I delete `/home/trexx/ffmpeg-android/ffmpeg-source/`?

**A**: Yes, but only if you don't plan to rebuild FFmpeg with new features. If you might need to add VP9, AV1, or other codecs later, keep it.

### Q: What if I accidentally deleted something important?

**A**: 
- If you deleted `ffmpegcompilation/`: No problem, it's not needed
- If you deleted `ffmpeg-android/prefix/arm64-v8a/`: You need to rebuild FFmpeg
- If you deleted project source code: Restore from git

### Q: How do I know if the build is using the right FFmpeg?

**A**: Check the build output:
```bash
flutter run -v | grep FFMPEG_PREFIX
```

Should show:
```
-I/home/trexx/ffmpeg-android/prefix/arm64-v8a/include
```

### Q: Can I move `ffmpeg-android/` to a different location?

**A**: Yes, but then update CMakeLists.txt:
```cmake
set(FFMPEG_PREFIX "/new/location/prefix/arm64-v8a")
```

---

## Summary

### Keep These
- ✅ `/home/trexx/projects/quickpost/android/app/src/main/cpp/` - Source code
- ✅ `/home/trexx/projects/quickpost/lib/` - Flutter code
- ✅ `/home/trexx/ffmpeg-android/prefix/arm64-v8a/` - **ESSENTIAL**
- ✅ `/home/trexx/Android/Sdk/ndk/` - Android NDK

### Delete These
- ❌ `/home/trexx/projects/quickpost/ffmpegcompilation/` - 2-3GB saved
- ❌ `/home/trexx/projects/quickpost/build/` - 1GB saved
- ❌ `/home/trexx/projects/quickpost/.dart_tool/` - 300MB saved
- ❌ `/home/trexx/projects/quickpost/.gradle/` - 300MB saved

**Total savings**: ~3.6-4.3GB

---

## Related Documentation

- [FFMPEG_INTEGRATION.md](./FFMPEG_INTEGRATION.md) - FFmpeg integration overview
- [EXTENDING_FFMPEG_FEATURES.md](./EXTENDING_FFMPEG_FEATURES.md) - How to add new features
- [REFACTORING_NOTES.md](./REFACTORING_NOTES.md) - Architecture overview

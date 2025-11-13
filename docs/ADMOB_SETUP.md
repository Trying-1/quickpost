# AdMob Setup Guide - Quick Post

## 📋 Overview

AdMob integration with centralized control for easy enable/disable of ads.

---

## 🎯 Quick Control

### Enable/Disable ALL Ads

Open `lib/config/ad_config.dart` and change:

```dart
static const bool adsEnabled = true; // Set to false to disable ALL ads
```

**That's it!** One line controls everything.

---

## 🔧 Configuration File

### Location: `lib/config/ad_config.dart`

This file controls:
- ✅ Enable/disable all ads globally
- ✅ Enable/disable ads per screen
- ✅ Ad Unit IDs (test and production)
- ✅ Interstitial frequency
- ✅ Test mode toggle

### Key Settings:

```dart
// Master control
static const bool adsEnabled = true; // Turn off all ads

// Per-screen control
static const bool showBannerInPostMaker = true;
static const bool showBannerInImageCropper = true;
static const bool showBannerInVideoCreator = true;
static const bool showBannerInAudioLibrary = false;

// Interstitial control
static const bool showInterstitialAfterExport = true;
static const int interstitialFrequency = 3; // Show every 3 exports

// Test mode
static const bool useTestAds = true; // false for production
```

---

## 📱 Getting Your AdMob IDs

### Step 1: Create AdMob Account
1. Go to https://admob.google.com/
2. Sign in with Google account
3. Click "Get Started"

### Step 2: Create App
1. Click "Apps" → "Add App"
2. Select "Android"
3. Enter app name: "Quick Post"
4. Click "Add"
5. **Copy your App ID** (looks like: `ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX`)

### Step 3: Create Ad Units

#### Banner Ad Unit:
1. Click "Ad units" → "Add ad unit"
2. Select "Banner"
3. Name: "Quick Post Banner"
4. Click "Create ad unit"
5. **Copy the Ad Unit ID**

#### Interstitial Ad Unit:
1. Click "Ad units" → "Add ad unit"
2. Select "Interstitial"
3. Name: "Quick Post Interstitial"
4. Click "Create ad unit"
5. **Copy the Ad Unit ID**

---

## 🔑 Adding Your Real Ad IDs

### Step 1: Update AndroidManifest.xml

File: `android/app/src/main/AndroidManifest.xml`

Replace this line:
```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-3940256099942544~3347511713"/>
```

With your real App ID:
```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX"/>
```

### Step 2: Update ad_config.dart

File: `lib/config/ad_config.dart`

Replace test IDs with your real Ad Unit IDs:

```dart
// Android Ad Unit IDs
static const String androidBannerAdUnitId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX'; // Your Banner ID
static const String androidInterstitialAdUnitId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX'; // Your Interstitial ID
```

### Step 3: Test Mode (Automatic)

**No action needed!** The app automatically:
- Uses **test ads** in debug mode (`flutter run`)
- Uses **real ads** in release mode (`flutter build appbundle --release`)

This is controlled by Flutter's `kDebugMode` in `lib/config/ad_config.dart`

---

## 🧪 Testing Ads

### Automatic Test/Production Mode:
- **Debug mode** (`flutter run`) → Automatically uses TEST ads
- **Release mode** (`flutter build appbundle --release`) → Automatically uses REAL ads
- No manual switching needed!

### Test Ad IDs (Used in Debug Mode):
- Banner: `ca-app-pub-3940256099942544/6300978111`
- Interstitial: `ca-app-pub-3940256099942544/1033173712`
- App ID: `ca-app-pub-3940256099942544~3347511713`

### Production Ad IDs (Used in Release Mode):
- Banner: `ca-app-pub-5829296907403264/7317233331`
- Interstitial: `ca-app-pub-5829296907403264/3245469845`
- App ID: `ca-app-pub-5829296907403264~3334590442`

### Testing Steps:
1. Run app in debug: `flutter run`
2. Check console: Should see "🧪 AdMob: Running in DEBUG mode - Using TEST ads"
3. Navigate to Post Maker screen
4. Banner ad should appear at bottom (with "Test Ad" label)
5. Export 3 posts → Interstitial ad shows (test ad)

---

## 📍 Where Ads Appear
### Banner Ads (Bottom of Screen):
- ✅ Post Maker Screen
- ✅ Image Cropper Screen
- ✅ Video Creator Screen
- ❌ Audio Library (disabled by default)
 - Refresh rate: Controlled by AdMob dashboard
 - Collapses when no ad is loaded (no space reserved)
 - Listener-driven load: `onAdLoaded` fires when ad is ready
 - Dashboard-based capping: Configure frequency capping in AdMob dashboard

### Interstitial Ads (Full Screen):
- Shows after export/save/create actions
- Frequency capping: Controlled by AdMob dashboard
- Shows between actions, not during editing
{{ ... }}

### How Banner Loading Works Now
- Widget creates a `BannerAd` with callbacks in `lib/widgets/ad_banner_widget.dart`.
- Space is only shown after `onAdLoaded` fires; otherwise it returns `SizedBox.shrink()`.
- Errors in loading dispose the ad and keep the UI layout unchanged.

---

## 🎨 Adding Ads to Screens

### Example: Add Banner to Post Maker

```dart
import '../widgets/ad_banner_widget.dart';

// In your build method:
Column(
  children: [
    // Your existing content
    Expanded(
      child: YourContent(),
    ),
    
    // Add banner at bottom
    AdBannerWidget(screenName: 'post_maker'),
  ],
)
```

### Example: Show Interstitial After Export

```dart
import '../services/ad_service.dart';

// After successful export:
await saveImage();

// Show ad
AdService().showInterstitialAfterExport();
```

---

## ⚙️ Customization Options

### Disable Ads in Specific Screen

In `lib/config/ad_config.dart`:

```dart
static const bool showBannerInImageCropper = false; // No ads in cropper
```

### Ad Frequency & Refresh Rate

**Banner refresh** and **interstitial frequency capping** are handled by AdMob dashboard:
1. Go to AdMob Console → Ad Units
2. Select your ad unit
3. Configure frequency capping and refresh settings
4. Changes apply automatically without code updates

### Files Involved (Ads)
- `lib/services/ad_service.dart` → creates `BannerAd` with `onAdLoaded`/`onAdFailedToLoad`.
- `lib/widgets/ad_banner_widget.dart` → shows banner only when loaded (collapses otherwise).

---

## 🚀 Production Checklist

Before publishing:

- [x] Get real AdMob App ID from Google AdMob ✅
- [x] Create Banner and Interstitial ad units ✅
- [x] Update `AndroidManifest.xml` with real App ID ✅
- [x] Update `ad_config.dart` with real Ad Unit IDs ✅
- [x] Automatic test/production mode configured ✅
- [ ] Test ads work in debug build (test ads)
- [ ] Test ads work in release build (real ads)
- [ ] Verify ads show correctly
- [ ] Check ad frequency is acceptable

---

## 📊 Revenue Optimization Tips

### Best Practices:
1. **Don't overdo it**: Too many ads = bad UX = uninstalls
2. **Strategic placement**: Show ads after user completes action (export)
3. **Frequency**: Every 3-5 actions is good balance
4. **Banner position**: Bottom of screen, non-intrusive
5. **No ads during editing**: Only between actions

### Current Setup (Balanced):
- Banner ads: Bottom of main screens
- Interstitial: Every 3 exports
- No ads during active editing
- Easy to disable if needed

---

## 🐛 Troubleshooting

### Ads Not Showing:

**Check 1: Is ads enabled?**
```dart
// In ad_config.dart
static const bool adsEnabled = true; // Must be true
```

**Check 2: Is AdService initialized?**
```dart
// In main.dart
await AdService().initialize();
```

**Check 3: Internet permission?**
```xml
<!-- In AndroidManifest.xml -->
<uses-permission android:name="android.permission.INTERNET" />
```

**Check 4: Test mode enabled?**
```dart
// In ad_config.dart
static const bool useTestAds = true; // Should be true for testing
```

### Test Ads Not Loading:

- Check internet connection
- Wait 10-30 seconds (ads take time to load)
- Check logcat for errors: `flutter logs`
- Verify Ad Unit IDs are correct test IDs

### Real Ads Not Loading:

- Wait 24-48 hours after creating ad units (AdMob activation time)
- Verify App ID and Ad Unit IDs are correct
- Check AdMob dashboard for approval status
- Ensure you're running in **release mode**: `flutter build appbundle --release`
- Check console for "💰 AdMob: Running in RELEASE mode - Using REAL ads"

---

## 📱 Files Modified

### New Files Created:
- `lib/config/ad_config.dart` - Ad configuration
- `lib/services/ad_service.dart` - Ad management service
- `lib/widgets/ad_banner_widget.dart` - Reusable banner widget

### Modified Files:
- `pubspec.yaml` - Added google_mobile_ads dependency
- `android/app/src/main/AndroidManifest.xml` - Added AdMob permissions and App ID

---

## 💰 Revenue Estimates

### Conservative Estimates:
- **1,000 daily active users**
- **5 ad impressions per user per day**
- **$1-3 CPM** (cost per 1000 impressions)
- **Monthly revenue**: $150-450

### Optimistic Estimates:
- **10,000 daily active users**
- **10 ad impressions per user per day**
- **$3-5 CPM**
- **Monthly revenue**: $9,000-15,000

*Actual revenue varies by geography, ad quality, user engagement*

---

## 🔄 Quick Commands

### Install dependencies:
```bash
flutter pub get
```

### Test with ads:
```bash
flutter run
```

### Build release with ads:
```bash
flutter build appbundle --release
```

### Check ad logs:
```bash
flutter logs | grep -i "ad"
```

---

## 📞 Support

### AdMob Help:
- https://support.google.com/admob/
- https://developers.google.com/admob/android/quick-start

### Quick Post Ad Issues:
- Check `lib/config/ad_config.dart` first
- Verify all IDs are correct
- Test with test ads before production

---

**Last Updated:** October 31, 2025  
**AdMob SDK Version:** 5.1.0  
**Mode:** Automatic (Test in debug, Real in release) ✅

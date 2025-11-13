# App Signing Guide - Quick Post

## 📋 Overview

Quick Post uses **Google Play App Signing** with an upload keystore. This guide explains how the signing works and how to set it up on a new machine.

---

## 🔐 What is App Signing?

### Google Play App Signing (Recommended)
- **Upload Key**: You create and manage this (used to sign APK/AAB before upload)
- **App Signing Key**: Google creates and manages this (used to sign the final APK distributed to users)

### Benefits:
- ✅ Google manages the app signing key securely
- ✅ If you lose your upload key, Google can reset it
- ✅ More secure distribution
- ✅ Easier key management

---

## 📁 Files You Need to Keep Safe

### Critical Files (NEVER commit to git):

1. **`android/key.properties`**
   ```properties
   storePassword=quickpost2025
   keyPassword=quickpost2025
   keyAlias=upload
   storeFile=upload-keystore.jks
   ```
   - Contains credentials for the keystore
   - Already in `.gitignore`
   - **Keep this file secure and backed up**

2. **`android/app/upload-keystore.jks`**
   - The actual keystore file
   - Already in `.gitignore`
   - **Keep this file secure and backed up**

### Files Safe to Commit:

- ✅ `android/app/build.gradle.kts` - Reads from key.properties (no passwords)
- ✅ `.gitignore` - Protects sensitive files

---

## 💾 Backup Strategy

### What to Backup:

Create a secure backup folder with these files:

```
quick-post-signing-backup/
├── key.properties              ← Credentials file
├── upload-keystore.jks         ← Keystore file
└── keystore-info.txt           ← Notes (see below)
```

### keystore-info.txt (Create this for reference):

```txt
Quick Post - Keystore Information
==================================

Keystore File: upload-keystore.jks
Key Alias: upload
Store Password: quickpost2025
Key Password: quickpost2025

Created: October 30, 2025
Validity: 10,000 days (until ~2053)

Key Algorithm: RSA
Key Size: 2048 bits

Certificate Details:
- CN: Quick Post
- OU: Development
- O: Quick Post
- L: Unknown
- ST: Unknown
- C: IN

IMPORTANT:
- This is the UPLOAD key for Google Play App Signing
- Google manages the actual app signing key
- Keep this file secure - needed for all app updates
- If lost, contact Google Play support for key reset
```

### Where to Store Backup:

**Option 1: Encrypted Cloud Storage** (Recommended)
- Google Drive (in encrypted zip)
- Dropbox (in encrypted zip)
- 1Password / LastPass (secure notes)

**Option 2: Physical Storage**
- USB drive (encrypted)
- External hard drive (encrypted)
- Keep in safe location

**Option 3: Password Manager**
- Store keystore file and credentials in password manager
- Most secure option

⚠️ **NEVER:**
- Commit to public GitHub
- Share via email unencrypted
- Store in public cloud without encryption
- Share passwords in plain text

---

## 🔄 Setting Up on a New Machine

### Scenario: You cloned the repo on a new machine

When you clone the repository, these files will be **missing** (because they're in `.gitignore`):
- `android/key.properties`
- `android/app/upload-keystore.jks`

### Step-by-Step Setup:

#### 1. Clone the Repository
```bash
git clone https://github.com/yourusername/igpostmakermobile.git
cd igpostmakermobile
```

#### 2. Restore the Keystore File
Copy your backed-up keystore to the correct location:

```bash
# Copy from your backup location
cp /path/to/backup/upload-keystore.jks android/app/upload-keystore.jks
```

#### 3. Create key.properties File
Create the file `android/key.properties` with your credentials:

```bash
cat > android/key.properties << 'EOF'
storePassword=quickpost2025
keyPassword=quickpost2025
keyAlias=upload
storeFile=upload-keystore.jks
EOF
```

Or create it manually with a text editor.

#### 4. Verify Setup
Check that files are in place:

```bash
# Check keystore exists
ls -la android/app/upload-keystore.jks

# Check key.properties exists
cat android/key.properties

# Verify they're ignored by git
git status
# Should NOT show these files
```

#### 5. Test Build
Try building a release:

```bash
flutter clean
flutter pub get
flutter build appbundle --release
```

If successful, you'll see:
```
✓ Built build/app/outputs/bundle/release/app-release.aab
```

---

## 🛠️ How It Works

### Build Process:

1. **Developer runs:** `flutter build appbundle --release`

2. **Gradle reads:** `android/key.properties`
   ```kotlin
   val keystoreProperties = Properties()
   keystoreProperties.load(FileInputStream(rootProject.file("key.properties")))
   ```

3. **Gradle signs AAB** with upload key from `upload-keystore.jks`

4. **Upload to Play Console:** Upload the signed AAB

5. **Google re-signs:** Google signs with their app signing key

6. **Users download:** APK signed by Google's key

### File Structure:

```
android/
├── key.properties              ← Credentials (git ignored)
├── app/
│   ├── upload-keystore.jks     ← Keystore (git ignored)
│   └── build.gradle.kts        ← Reads key.properties
└── .gitignore                  ← Protects sensitive files
```

---

## 🚨 Troubleshooting

### Error: "key.properties not found"

**Problem:** Missing credentials file

**Solution:**
```bash
# Create key.properties in android/ directory
cat > android/key.properties << 'EOF'
storePassword=quickpost2025
keyPassword=quickpost2025
keyAlias=upload
storeFile=upload-keystore.jks
EOF
```

### Error: "upload-keystore.jks not found"

**Problem:** Missing keystore file

**Solution:**
```bash
# Copy from backup
cp /path/to/backup/upload-keystore.jks android/app/upload-keystore.jks
```

### Error: "Keystore was tampered with, or password was incorrect"

**Problem:** Wrong password in key.properties

**Solution:**
- Check password in `key.properties`
- Verify it matches your backup notes
- Password is case-sensitive

### Error: "Failed to read key from keystore"

**Problem:** Wrong key alias

**Solution:**
- Check `keyAlias` in `key.properties`
- Should be: `keyAlias=upload`

---

## 🔄 Updating Passwords (If Needed)

If you want to change passwords later:

### 1. Change Keystore Password:
```bash
keytool -storepasswd -keystore android/app/upload-keystore.jks
```

### 2. Change Key Password:
```bash
keytool -keypasswd -alias upload -keystore android/app/upload-keystore.jks
```

### 3. Update key.properties:
Update the passwords in `android/key.properties` to match.

---

## 📱 First Time Upload to Play Console

### Steps:

1. **Build the AAB:**
   ```bash
   flutter build appbundle --release
   ```

2. **Locate the AAB:**
   ```
   build/app/outputs/bundle/release/app-release.aab
   ```

3. **Upload to Play Console:**
   - Go to Google Play Console
   - Create new app
   - Go to "Release" → "Production"
   - Upload `app-release.aab`

4. **Opt-in to App Signing:**
   - Google will prompt you to opt-in
   - Choose "Let Google manage my app signing key"
   - Google will generate the app signing key
   - Your upload key will be registered

5. **Complete the Release:**
   - Fill in store listing
   - Add screenshots
   - Set pricing
   - Submit for review

---

## 🔐 Security Best Practices

### DO:
- ✅ Keep keystore and key.properties in secure backup
- ✅ Use strong passwords (change from default if needed)
- ✅ Store in encrypted location
- ✅ Use password manager
- ✅ Keep multiple backups in different locations
- ✅ Document keystore details

### DON'T:
- ❌ Commit keystore to git
- ❌ Share passwords in plain text
- ❌ Email keystore unencrypted
- ❌ Store in public cloud unencrypted
- ❌ Use same password for multiple apps
- ❌ Share keystore with untrusted parties

---

## 📝 Quick Reference

### File Locations:
```
android/key.properties              ← Credentials
android/app/upload-keystore.jks     ← Keystore
```

### Build Commands:
```bash
# Build AAB (for Play Store)
flutter build appbundle --release

# Build APK (for testing)
flutter build apk --release

# Clean build
flutter clean && flutter pub get
```

### Verify Setup:
```bash
# Check files exist
ls -la android/key.properties
ls -la android/app/upload-keystore.jks

# Check git ignores them
git status
```

---

## 🆘 Lost Your Keystore?

### If you lose the upload key:

1. **Don't panic!** With Google Play App Signing, you can recover.

2. **Contact Google Play Support:**
   - Go to Play Console
   - Help → Contact Support
   - Request upload key reset

3. **Google will:**
   - Verify your identity
   - Reset your upload key
   - You can generate a new upload key

4. **Important:**
   - This only works with Google Play App Signing
   - Without it, you'd lose access to your app forever
   - This is why we use Google Play App Signing!

---

## 📞 Support

If you have issues with signing:

1. Check this guide first
2. Verify all files are in correct locations
3. Check passwords match
4. Try clean build: `flutter clean`
5. Check Google Play Console documentation

---

**Last Updated:** October 30, 2025  
**App:** Quick Post v1.0.0  
**Keystore:** upload-keystore.jks (RSA 2048-bit)

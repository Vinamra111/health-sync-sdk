# Build APK to Desktop - Quick Guide

**Get the test app APK on your Desktop in 2 minutes!**

---

## 🚀 Quick Method

### Step 1: Run the Build Script

**Open Command Prompt or PowerShell in the project root:**

```bash
cd C:\SDK_StandardizingHealthDataV0\test-app
build-to-desktop.bat
```

**The script will:**
1. ✅ Clean previous builds
2. ✅ Install dependencies
3. ✅ Build debug APK (~2-3 minutes)
4. ✅ Copy APK to your Desktop
5. ✅ Create installation instructions

### Step 2: Find on Desktop

After build completes, check your Desktop for:

1. **HealthSync-Test-App.apk** (~50 MB)
2. **HealthSync-Installation-Instructions.txt**

---

## 📱 Install on Phone

### Method 1: Email (Easiest)

1. Email the APK to yourself
2. Open email on phone
3. Download attachment
4. Tap APK to install
5. Allow "Install from Unknown Sources" if prompted

### Method 2: USB Cable (Fastest)

```bash
# Connect phone via USB
# Enable USB Debugging on phone
# Run in command prompt:
cd Desktop
adb install HealthSync-Test-App.apk
```

### Method 3: Cloud Storage

1. Upload APK to Google Drive/Dropbox
2. Open Drive on phone
3. Download APK
4. Tap to install

### Method 4: Direct Transfer

1. Connect phone via USB cable
2. Copy APK to phone's Download folder
3. Open Files app on phone
4. Navigate to Downloads
5. Tap APK to install

---

## ⚡ Alternative: Manual Build

If the script doesn't work, build manually:

```bash
cd C:\SDK_StandardizingHealthDataV0\test-app

# Install dependencies
flutter pub get

# Build APK
flutter build apk --debug

# Copy to Desktop
copy build\app\outputs\flutter-apk\app-debug.apk %USERPROFILE%\Desktop\HealthSync-Test-App.apk
```

---

## 📋 What You'll Get

**On Desktop:**
- ✅ HealthSync-Test-App.apk (~50 MB)
- ✅ Installation instructions text file

**APK Details:**
- **Package:** com.healthsync.testapp
- **Min Android:** 8.0 (API 26)
- **Target Android:** 14 (API 34)
- **Type:** Debug APK
- **Features:** Full SDK test suite

---

## 🎯 After Installation

1. **Install Health Connect**
   - If not already installed
   - Get from Google Play Store

2. **Open HealthSync Test App**
   - Tap app icon
   - App auto-initializes

3. **Connect to Health Connect**
   - Tap "Connect to Health Connect"
   - Grant permissions

4. **Test SDK**
   - Request steps permission
   - Fetch steps data
   - View results!

---

## ⚠️ Common Issues

### "Build failed"

**Solution:**
```bash
flutter clean
flutter pub get
flutter build apk --debug
```

### "Flutter not found"

**Solution:**
- Verify Flutter is installed
- Check PATH includes Flutter
- Run `flutter doctor`

### "APK not on Desktop"

**Solution:**
- Check build completed successfully
- Look for APK in: `test-app\build\app\outputs\flutter-apk\`
- Manually copy to Desktop

### "Can't install on phone"

**Solution:**
- Enable "Install from Unknown Sources" in phone settings
- Check phone is Android 8.0+
- Ensure enough storage space

---

## 🔍 Verification

After running script, verify:

- [ ] APK exists on Desktop
- [ ] APK size is ~40-60 MB
- [ ] Instructions file created
- [ ] Can open APK properties (right-click)

---

## 📊 Expected Output

```
========================================
 HealthSync SDK Test App Builder
 Building APK for Desktop...
========================================

[OK] Flutter found

[1/5] Cleaning previous builds...
[OK] Clean complete

[2/5] Installing dependencies...
[OK] Dependencies installed

[3/5] Building DEBUG APK...
This may take a few minutes...
[OK] Build complete

[INFO] APK Size: 52 MB

[4/5] Copying APK to Desktop...
[OK] APK copied to Desktop

[5/5] Creating installation instructions...
[OK] Instructions created

========================================
 BUILD SUCCESSFUL!
========================================

Files created on Desktop:

1. HealthSync-Test-App.apk
   - Size: 52 MB
   - Ready to install on phone

2. HealthSync-Installation-Instructions.txt
   - Step-by-step guide
   - Multiple installation methods
```

---

## 🎉 Success Checklist

After build completes:

- [ ] Check Desktop for APK file
- [ ] Verify APK size (40-60 MB is normal)
- [ ] Read installation instructions
- [ ] Choose installation method
- [ ] Transfer to phone
- [ ] Install and open app
- [ ] Test SDK functionality

---

## 📞 Need Help?

If you encounter issues:

1. Check [test-app/README.md](test-app/README.md)
2. Check [test-app/QUICKSTART.md](test-app/QUICKSTART.md)
3. Review Flutter installation guide
4. Check Flutter version: `flutter doctor`

---

**Estimated Time:** 2-3 minutes to build + 1-2 minutes to transfer

**Total:** ~5 minutes from start to installed on phone!

---

**Last Updated:** January 2026

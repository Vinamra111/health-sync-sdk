# Install HealthSync Test App on Phone

**Simple visual guide to get the app on your phone**

---

## 📱 Step-by-Step with Pictures

### Step 1: Build the APK

**Find this file on your computer:**
```
C:\SDK_StandardizingHealthDataV0\BUILD-APK.bat
```

**Double-click it!**

You'll see:
```
=============================================
 HealthSync SDK Test App
 One-Click APK Builder
=============================================

This will:
 1. Build the test app APK
 2. Copy it to your Desktop
 3. Create installation instructions

Time required: 2-3 minutes

Press any key to continue...
```

**Press any key and wait ~2-3 minutes**

---

### Step 2: Find APK on Desktop

**Go to your Desktop, you'll see:**

```
🖥️ Desktop
  📄 HealthSync-Test-App.apk (52 MB)
  📄 HealthSync-Installation-Instructions.txt
```

---

### Step 3: Transfer to Phone

**Choose ONE method:**

#### Option A: Email (Recommended)

```
1. Right-click HealthSync-Test-App.apk
2. Send To → Mail recipient
3. Email it to yourself
4. On phone: Open email
5. Download the APK attachment
```

#### Option B: USB Cable

```
1. Connect phone to computer with USB cable
2. On computer: Open phone in File Explorer
3. Drag APK to phone's "Download" folder
4. Done!
```

#### Option C: Google Drive

```
1. Upload HealthSync-Test-App.apk to Google Drive
2. On phone: Open Google Drive app
3. Find the APK file
4. Tap to download
```

#### Option D: Nearby Share (Windows 11)

```
1. Right-click APK
2. Share → Nearby Share
3. Select your phone
4. Accept on phone
```

---

### Step 4: Install on Phone

**On your phone:**

```
1. Open "Files" or "Downloads" app
2. Find "HealthSync-Test-App.apk"
3. Tap the APK file
4. Tap "Install"
```

**If you see "Install blocked":**

```
1. Tap "Settings"
2. Enable "Allow from this source"
3. Go back
4. Tap "Install" again
```

**Wait ~10 seconds for installation**

You'll see: **"App installed"**

---

### Step 5: Open the App

**Find the app icon:**

```
📱 App Drawer or Home Screen
   🏥 HealthSync Test
```

**Tap to open!**

---

## 🎯 First Use Guide

### After opening the app:

**Screen 1: Initial State**
```
┌─────────────────────────────┐
│ HealthSync SDK Test         │
├─────────────────────────────┤
│                             │
│ Status: Not Initialized     │
│ [Auto-initializing...]      │
│                             │
└─────────────────────────────┘
```

**After ~1 second:**
```
┌─────────────────────────────┐
│ ✓ Initialized               │
│ Health Connect: installed   │
│                             │
│ [Connect to Health Connect] │
└─────────────────────────────┘
```

**Tap "Connect to Health Connect"**

**You'll see system dialog:**
```
┌─────────────────────────────┐
│ Allow HealthSync Test to    │
│ access your health data?    │
│                             │
│ ☐ Steps                     │
│ ☐ Heart Rate                │
│ ☐ Sleep                     │
│                             │
│ [Deny]  [Allow]             │
└─────────────────────────────┘
```

**Tap "Allow"**

**Back in app:**
```
┌─────────────────────────────┐
│ ✓ Connected                 │
│                             │
│ [Request Steps Permission]  │
│ [Fetch Steps Data]          │
└─────────────────────────────┘
```

**Tap "Request Steps Permission"**

**Grant permission in system dialog**

**Then tap "Fetch Steps Data"**

**You'll see:**
```
┌─────────────────────────────┐
│ Steps Data (15 records)     │
├─────────────────────────────┤
│ 🚶 5,432 steps              │
│    6 Jan 2026, 10:30        │
│                             │
│ 🚶 8,234 steps              │
│    5 Jan 2026, 18:45        │
│                             │
│ 🚶 3,567 steps              │
│    5 Jan 2026, 12:20        │
│                             │
│ (scroll for more...)        │
└─────────────────────────────┘
```

**🎉 Success! SDK is working!**

---

## ✅ Quick Checklist

Installation:
- [ ] Double-clicked BUILD-APK.bat
- [ ] APK appeared on Desktop
- [ ] Transferred APK to phone
- [ ] Installed APK on phone
- [ ] Opened app

Testing:
- [ ] App opened without crash
- [ ] SDK initialized (green check)
- [ ] Connected to Health Connect
- [ ] Requested steps permission
- [ ] Fetched steps data
- [ ] Data displayed correctly

---

## ⚠️ Troubleshooting

### Problem: "Can't find BUILD-APK.bat"

**Location:**
```
C:\SDK_StandardizingHealthDataV0\BUILD-APK.bat
```

**Or use:**
```
C:\SDK_StandardizingHealthDataV0\test-app\build-to-desktop.bat
```

### Problem: "Flutter not found"

**You need Flutter installed first!**

1. Download: https://flutter.dev/docs/get-started/install/windows
2. Install Flutter
3. Run `flutter doctor`
4. Try again

### Problem: "App not installed"

**On phone:**
```
Settings → Security → Unknown Sources
Enable for your file manager/browser
```

### Problem: "Health Connect not available"

**Install Health Connect:**
```
Play Store → Search "Health Connect"
Install the official Google app
Restart HealthSync Test app
```

### Problem: "No steps data"

**Add test data:**
```
1. Open Health Connect app
2. Add manual steps entry
3. Go back to HealthSync Test app
4. Tap "Fetch Steps Data" again
```

---

## 📊 Expected File Sizes

| File | Size | Location |
|------|------|----------|
| BUILD-APK.bat | 1 KB | Project root |
| HealthSync-Test-App.apk | 40-60 MB | Desktop after build |
| Instructions.txt | 5 KB | Desktop after build |

---

## 🎯 What You're Testing

When you use this app, you're validating:

✅ **SDK Integration** - Can developers integrate the SDK?
✅ **Initialization** - Does SDK initialize correctly?
✅ **Connection** - Does Health Connect connection work?
✅ **Permissions** - Do permission requests work?
✅ **Data Fetching** - Can real data be fetched?
✅ **Error Handling** - Are errors handled gracefully?
✅ **Performance** - Is it fast and responsive?
✅ **UI/UX** - Is the experience smooth?

---

## 💡 Tips

**For Best Results:**

1. **Use Android 14+** - Full Health Connect support
2. **Add Sample Data** - Add steps in Health Connect first
3. **Grant All Permissions** - Test complete flow
4. **Try Error Scenarios** - Deny permission, then retry
5. **Check Performance** - Should be fast and smooth

**Report:**
- Any crashes
- Slow performance
- Confusing errors
- Missing features
- UI issues

---

## 🚀 Quick Summary

```
1. Double-click: BUILD-APK.bat
2. Wait: 2-3 minutes
3. Find: APK on Desktop
4. Transfer: To phone (email/USB/cloud)
5. Install: Tap APK on phone
6. Open: HealthSync Test app
7. Test: Follow in-app buttons
8. Done: SDK validated!
```

**Total Time: ~10 minutes from start to finish**

---

**Ready? Double-click BUILD-APK.bat now!** 🚀

---

**Last Updated:** January 2026

# Fix Flutter PATH Issue

**Quick guide to fix "Flutter not found" error**

---

## 🚀 Quick Fix - Run This First

**Double-click:**
```
C:\SDK_StandardizingHealthDataV0\INSTALL-FLUTTER.bat
```

This script will:
1. Check if Flutter is installed
2. Find Flutter on your system
3. Add it to PATH automatically
4. Let you build the APK immediately

---

## Option 1: Flutter Already Installed (Just Fix PATH)

### Step 1: Find Flutter Location

**Common locations:**
- `C:\flutter`
- `C:\src\flutter`
- `C:\Users\YourName\flutter`
- `D:\flutter`

### Step 2: Add to PATH

**Quick Method (Run as Administrator):**
```bash
setx PATH "%PATH%;C:\flutter\bin"
```
*(Replace `C:\flutter` with your actual Flutter location)*

**GUI Method:**
1. Press **Windows Key**
2. Type: **"Environment Variables"**
3. Click **"Edit system environment variables"**
4. Click **"Environment Variables"** button
5. Under **"User variables"**, select **"Path"**
6. Click **"Edit"**
7. Click **"New"**
8. Add: `C:\flutter\bin` (your Flutter location)
9. Click **OK** on all windows
10. **Restart Command Prompt**

### Step 3: Verify

```bash
flutter --version
```

Should show Flutter version info.

### Step 4: Build APK

```bash
C:\SDK_StandardizingHealthDataV0\BUILD-APK.bat
```

---

## Option 2: Install Flutter (Not Installed)

### Quick Install Steps

**1. Download Flutter**

Download from: https://docs.flutter.dev/get-started/install/windows

Or direct link:
```
https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.16.9-stable.zip
```

**2. Extract to C:\flutter**

Right-click ZIP → Extract All → Choose `C:\`

You should have: `C:\flutter\bin\flutter.bat`

**3. Add to PATH**

Run as Administrator:
```bash
setx PATH "%PATH%;C:\flutter\bin"
```

**4. Verify Installation**

Open **new** Command Prompt:
```bash
flutter doctor
```

**5. Accept Android Licenses**

```bash
flutter doctor --android-licenses
```

Press `y` to accept all.

**6. Build APK**

```bash
C:\SDK_StandardizingHealthDataV0\BUILD-APK.bat
```

---

## Option 3: Use Flutter Installed Elsewhere

If Flutter is installed in a different location:

**1. Find Flutter**

Search your computer for: `flutter.bat`

**2. Note the Path**

Example: `D:\development\flutter\bin\flutter.bat`

The PATH you need: `D:\development\flutter\bin`

**3. Add to PATH**

```bash
setx PATH "%PATH%;D:\development\flutter\bin"
```

**4. Restart Command Prompt**

Close and reopen Command Prompt.

**5. Test**

```bash
flutter --version
```

**6. Build**

```bash
C:\SDK_StandardizingHealthDataV0\BUILD-APK.bat
```

---

## ⚡ Super Quick One-Liner Fix

**If Flutter is at `C:\flutter`:**

Run as Administrator:
```bash
setx PATH "%PATH%;C:\flutter\bin" && C:\SDK_StandardizingHealthDataV0\BUILD-APK.bat
```

**If Flutter is at `%USERPROFILE%\flutter`:**

Run as Administrator:
```bash
setx PATH "%PATH%;%USERPROFILE%\flutter\bin" && C:\SDK_StandardizingHealthDataV0\BUILD-APK.bat
```

---

## 🔍 Troubleshooting

### "flutter: command not found" persists

**Solution:** Restart Command Prompt or restart computer.

### "setx: command not found"

**Solution:** Run Command Prompt as Administrator.

### "Android SDK not found"

**Solution:**
```bash
flutter doctor
```
Follow instructions to install Android SDK.

### Still not working?

**Run the helper script:**
```bash
C:\SDK_StandardizingHealthDataV0\INSTALL-FLUTTER.bat
```

It will diagnose and fix the issue automatically.

---

## 📋 Complete Installation Checklist

After fixing PATH, verify everything:

```bash
# Check Flutter
flutter --version

# Check Flutter health
flutter doctor

# Accept Android licenses
flutter doctor --android-licenses

# Verify everything is OK
flutter doctor -v
```

All should show ✓ or at least no critical errors.

---

## ✅ After Flutter is Fixed

**Just run:**
```bash
C:\SDK_StandardizingHealthDataV0\BUILD-APK.bat
```

APK will appear on Desktop in 2-3 minutes! 🚀

---

**Quick Summary:**

1. **Run:** `INSTALL-FLUTTER.bat` (auto-fixes PATH)
2. **Or manually add:** `C:\flutter\bin` to PATH
3. **Restart** Command Prompt
4. **Run:** `BUILD-APK.bat`
5. **Done!** APK on Desktop

---

**Last Updated:** January 2026

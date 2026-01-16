# Fix Build Error - SSL Certificate Issue

## 🔍 The Problem

```
PKIX path building failed: unable to find valid certification path to requested target
```

**This means:** Gradle can't download Flutter artifacts due to SSL certificate issues.

**Common causes:**
- Corporate firewall/proxy
- Antivirus software (Avast, McAfee, Norton, etc.)
- VPN software
- Security software blocking SSL connections

---

## ✅ Quick Solutions (Try in Order)

### Solution 1: Temporarily Disable Antivirus

**If you have antivirus (Avast, McAfee, Norton, etc.):**

1. **Temporarily disable** SSL scanning or HTTPS scanning
2. Run `REBUILD-APK.bat` again
3. Re-enable antivirus after build

**Why this works:** Antivirus software intercepts SSL connections with its own certificate

---

### Solution 2: Use Different Network

1. **Disconnect from corporate/work network**
2. **Connect to:** Mobile hotspot or home WiFi
3. Run `REBUILD-APK.bat` again

**Why this works:** Corporate networks often have SSL inspection

---

### Solution 3: Precache Flutter Artifacts

Run this first to download all needed files:

```bash
C:\flutter\bin\flutter.bat precache --android
```

Then build:

```bash
cd C:\SDK_StandardizingHealthDataV0\test-app
C:\flutter\bin\flutter.bat build apk --debug
```

---

### Solution 4: Update Java Certificates

**Run Command Prompt as Administrator:**

```bash
cd C:\SDK_StandardizingHealthDataV0\test-app
set JAVA_OPTS=-Djavax.net.ssl.trustStoreType=Windows-ROOT
flutter build apk --debug
```

---

### Solution 5: Check Gradle Properties

Create/edit: `android/gradle.properties`

Add these lines:

```properties
systemProp.https.proxyHost=
systemProp.https.proxyPort=
systemProp.http.nonProxyHosts=*.google.com|*.googleapis.com
```

---

## 🎯 Recommended Approach

### Option A: Quick Test (If on corporate network)

1. **Use mobile hotspot** from your phone
2. Run `REBUILD-APK.bat`
3. Should work immediately

### Option B: Fix Permanently

1. **Identify interfering software:**
   - Check if antivirus is running
   - Check if VPN is active
   - Check if on corporate network

2. **Temporary workaround:**
   - Disable antivirus SSL scanning
   - OR disconnect VPN
   - OR switch networks

3. **Build APK**
4. **Re-enable security** after build

---

## 🔧 Manual Build Process

If scripts don't work, try manual steps:

```bash
# Step 1: Open Command Prompt
cd C:\SDK_StandardizingHealthDataV0\test-app

# Step 2: Precache (downloads all artifacts)
C:\flutter\bin\flutter.bat precache --android

# Step 3: Clean
C:\flutter\bin\flutter.bat clean

# Step 4: Get dependencies
C:\flutter\bin\flutter.bat pub get

# Step 5: Build with verbose output
C:\flutter\bin\flutter.bat build apk --debug --verbose

# Step 6: Copy to Desktop
copy build\app\outputs\flutter-apk\app-debug.apk %USERPROFILE%\Desktop\HealthSync-Test-App.apk
```

---

## 📊 What Each Error Means

### "PKIX path building failed"
**Cause:** SSL certificate chain can't be verified
**Fix:** Antivirus or firewall issue - try Solution 1 or 2

### "unable to find valid certification path"
**Cause:** Java doesn't trust the SSL certificate
**Fix:** Corporate/security software - try Solution 4

### "The server may not support the client's requested TLS protocol"
**Cause:** TLS version mismatch (rare)
**Fix:** Update Java/Flutter

---

## ✅ After Successful Build

You'll see:

```
✓ Built build\app\outputs\flutter-apk\app-debug.apk (XX MB)
```

Then APK will be on your Desktop!

---

## 🎯 Quick Decision Tree

```
Is antivirus running?
├─ YES → Disable SSL scanning → Build
└─ NO
    ├─ On corporate network?
    │  ├─ YES → Use mobile hotspot → Build
    │  └─ NO
    │      ├─ VPN active?
    │      │  ├─ YES → Disconnect VPN → Build
    │      │  └─ NO → Run precache first → Build
```

---

## 💡 Pro Tip

**Fastest solution for most users:**
1. Enable mobile hotspot on your phone
2. Connect PC to hotspot
3. Run `REBUILD-APK.bat`
4. Usually builds successfully!

---

**Still stuck?** Run this to see detailed logs:

```bash
cd C:\SDK_StandardizingHealthDataV0\test-app
C:\flutter\bin\flutter.bat build apk --debug --verbose > build-log.txt 2>&1
```

Then check `build-log.txt` for details.

---

**Most common fix:** Temporarily disable antivirus or switch to mobile hotspot! 📱

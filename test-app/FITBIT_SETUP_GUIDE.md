# Fitbit Integration Setup Guide

Complete guide for setting up and testing Fitbit integration in the HealthSync test app.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Fitbit Developer Account Setup](#fitbit-developer-account-setup)
3. [Creating a Fitbit Application](#creating-a-fitbit-application)
4. [Installing the Test App](#installing-the-test-app)
5. [Configuring Fitbit Credentials](#configuring-fitbit-credentials)
6. [Testing the OAuth Flow](#testing-the-oauth-flow)
7. [Fetching Health Data](#fetching-health-data)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before starting, ensure you have:
- **Android device** running Android 8.0 (API 26) or higher
- **Fitbit account** (free account works)
- **Active Fitbit device** (optional, but recommended for real data)
- **Internet connection** on your Android device

---

## Fitbit Developer Account Setup

### Step 1: Create Fitbit Developer Account

1. Go to [https://dev.fitbit.com/](https://dev.fitbit.com/)
2. Click **"Register"** in the top right
3. Log in with your existing Fitbit account or create a new one
4. Accept the Fitbit Developer Terms of Service

---

## Creating a Fitbit Application

### Step 2: Register a New Application

1. Go to [https://dev.fitbit.com/apps](https://dev.fitbit.com/apps)
2. Click **"Register a new app"**
3. Fill in the application details:

   | Field | Value |
   |-------|-------|
   | **Application Name** | HealthSync Test App |
   | **Description** | Testing Fitbit integration for HealthSync SDK |
   | **Application Website** | http://localhost (or your website) |
   | **Organization** | Your name or company |
   | **Organization Website** | http://localhost (or your website) |
   | **Terms of Service URL** | http://localhost (optional) |
   | **Privacy Policy URL** | http://localhost (optional) |
   | **OAuth 2.0 Application Type** | **Personal** ⚠️ IMPORTANT |
   | **Redirect URL** | `healthsync://fitbit/callback` ⚠️ CRITICAL |
   | **Default Access Type** | Read & Write |

4. Click **"Register"** or **"Save"**

### Step 3: Get Your Credentials

After registration, you'll see your app details page with:
- **OAuth 2.0 Client ID**: A 6-8 character alphanumeric string (e.g., `23ABCD`)
- **Client Secret**: A 32+ character hexadecimal string

⚠️ **IMPORTANT**: Keep these credentials secure. The Client Secret is shown only once.

---

## Installing the Test App

### Method 1: Transfer APK via WhatsApp (Recommended)

1. Locate the APK file on your computer:
   ```
   C:\SDK_StandardizingHealthDataV0\test-app\build\app\outputs\flutter-apk\app-debug.apk
   ```

2. Send the APK file to yourself via WhatsApp Web or Email

3. On your Android device:
   - Download the APK from WhatsApp/Email
   - Tap the downloaded APK file
   - If prompted, enable **"Install from Unknown Sources"** for WhatsApp/Chrome
   - Tap **"Install"**

### Method 2: USB Transfer

1. Connect your Android device to your computer via USB
2. Copy the APK file to your device's Downloads folder
3. On your device:
   - Open **Files** app
   - Navigate to **Downloads**
   - Tap the APK file
   - Tap **"Install"**

---

## Configuring Fitbit Credentials

### Step 4: Open the Test App

1. Launch **"HealthSync Test"** app on your device
2. Navigate to the **"Fitbit"** tab

### Step 5: Enter Credentials

1. Tap the **Settings icon** (gear icon) in the status card
2. Fill in the configuration:
   - **Client ID**: Paste your OAuth 2.0 Client ID from Fitbit
   - **Client Secret**: Paste your Client Secret from Fitbit
   - **Redirect URI**: Should be pre-filled as `healthsync://fitbit/callback`
     - ⚠️ This MUST match exactly what you configured on Fitbit

3. Tap **"Validate"** to check if the format is correct
4. Tap **"Save Settings"**

The app will reload and show **"Ready - Click 'Connect to Fitbit'"**

---

## Testing the OAuth Flow

### Step 6: Connect to Fitbit

1. Tap **"Connect to Fitbit (OAuth)"** button
2. The Fitbit authorization page will open in your browser
3. **Log in** to your Fitbit account if prompted
4. Review the requested permissions
5. Tap **"Allow"** to authorize the app

### Step 7: Automatic Callback

The app will automatically:
- Receive the authorization code via deep link
- Validate the OAuth state for security
- Exchange the code for access tokens
- Save the tokens securely
- Show **"Connected successfully!"** message

### What Happens Behind the Scenes

```
┌─────────────┐         ┌─────────────┐         ┌─────────────┐
│   Test App  │────1───>│   Fitbit    │         │  Deep Link  │
│             │<───2────│   OAuth     │────3───>│   Handler   │
│             │         │   Server    │         │             │
│             │<───────────────4──────────────────│             │
│ Save Tokens │                                   └─────────────┘
└─────────────┘
```

1. App launches OAuth URL with state and PKCE challenge
2. User authorizes in browser
3. Fitbit redirects to `healthsync://fitbit/callback?code=...&state=...`
4. App automatically receives callback, validates state, and exchanges code

---

## Fetching Health Data

### Step 8: Fetch Steps Data

1. After successful connection, tap **"Fetch Steps (7 days)"**
2. The app will fetch your last 7 days of step data
3. View the results in the **"Fetched Data"** section
4. Toggle **"Day-wise"** to see aggregated daily totals

### Step 9: Fetch Sleep Data

1. Tap **"Fetch Sleep (7 days)"**
2. The app will fetch your last 7 days of sleep data
3. Results are displayed below steps data

### Understanding the Data

The fetched data includes:
- **Raw Records**: Individual data points from Fitbit API
- **Day-wise Aggregation**: Total steps per day
- **Record Count**: Number of individual records per day

---

## Troubleshooting

### "Please configure Fitbit credentials"

**Problem**: Credentials not saved or invalid

**Solution**:
1. Open Settings (gear icon)
2. Re-enter your Client ID and Client Secret
3. Ensure no extra spaces or characters
4. Save and retry

---

### "Authorization failed: Invalid OAuth state"

**Problem**: Possible CSRF attack or stale OAuth session

**Solution**:
1. Disconnect from Fitbit (if connected)
2. Close and reopen the app
3. Try connecting again
4. If issue persists, clear app data and reconfigure

---

### "Network error. Please check your internet connection."

**Problem**: No internet or Fitbit API unreachable

**Solution**:
1. Verify your device has internet access
2. Try opening https://www.fitbit.com in your browser
3. If Fitbit is down, wait and retry later
4. Check if firewall/VPN is blocking requests

---

### "Could not launch OAuth URL"

**Problem**: No browser app found or URL malformed

**Solution**:
1. Ensure you have a browser app installed (Chrome, Firefox, etc.)
2. Check Settings → Apps → Default apps → Browser
3. Verify Client ID is correct (6-8 alphanumeric characters)
4. Re-enter credentials in Settings

---

### "No authorization code received"

**Problem**: OAuth callback not captured or user denied access

**Solution**:
1. Ensure you clicked **"Allow"** on the Fitbit authorization page
2. Check if the redirect URL in Fitbit app settings matches exactly:
   - Configured in Fitbit: `healthsync://fitbit/callback`
   - In app settings: `healthsync://fitbit/callback`
3. Ensure no typos (case-sensitive, no trailing slashes)
4. Try uninstalling and reinstalling the app

---

### "Invalid token response from Fitbit"

**Problem**: Client Secret is incorrect or expired

**Solution**:
1. Go to [https://dev.fitbit.com/apps](https://dev.fitbit.com/apps)
2. Click on your application
3. Verify or regenerate Client Secret
4. Update in app Settings
5. Try connecting again

---

### Deep Link Not Working

**Problem**: Android not redirecting back to app

**Solution**:
1. Check AndroidManifest.xml has the intent filter (dev only)
2. Ensure scheme is `healthsync` and host is `fitbit`
3. Try reinstalling the app
4. Clear default app associations:
   - Settings → Apps → HealthSync Test → Open by default → Clear

---

### "Request timed out"

**Problem**: Slow internet or Fitbit API delay

**Solution**:
1. Ensure stable internet connection
2. Try again in a few minutes
3. Check Fitbit API status: [https://dev.fitbit.com/build/reference/web-api/developer-guide/api-status/](https://dev.fitbit.com/build/reference/web-api/developer-guide/api-status/)

---

## Security Features

The Fitbit integration includes:

1. **OAuth 2.0 + PKCE**: Industry-standard authorization
2. **State Validation**: CSRF attack protection
3. **Secure Storage**: Encrypted credential and token storage
4. **Automatic Token Refresh**: Seamless re-authentication
5. **Deep Link Validation**: Ensures callbacks are legitimate

---

## API Rate Limits

Fitbit API has the following limits:
- **150 requests per hour** per user
- Exceeded limits return HTTP 429 errors
- The SDK handles rate limiting automatically

---

## Data Types Supported

The Fitbit plugin supports:
- Steps
- Heart Rate & Resting Heart Rate
- Sleep (duration, stages)
- Activity & Exercise
- Calories (total & active)
- Distance
- Blood Oxygen (SpO2)
- Weight
- Heart Rate Variability (HRV)
- VO2 Max
- Respiratory Rate
- Body Temperature

---

## Additional Resources

- **Fitbit Developer Docs**: [https://dev.fitbit.com/build/reference/web-api/](https://dev.fitbit.com/build/reference/web-api/)
- **OAuth 2.0 Spec**: [https://tools.ietf.org/html/rfc6749](https://tools.ietf.org/html/rfc6749)
- **PKCE Spec**: [https://tools.ietf.org/html/rfc7636](https://tools.ietf.org/html/rfc7636)

---

## Support

For issues with:
- **The SDK**: Check the HealthSync repository
- **Fitbit API**: Visit [Fitbit Community Forums](https://community.fitbit.com/t5/Web-API-Development/bd-p/WebAPIDevelopment)
- **This Test App**: Contact the development team

---

**Last Updated**: 2026-01-07
**App Version**: 1.0.0
**SDK Version**: 1.0.0

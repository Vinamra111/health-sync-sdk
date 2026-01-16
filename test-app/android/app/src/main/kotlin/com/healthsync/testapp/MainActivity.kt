package com.healthsync.testapp

import io.flutter.embedding.android.FlutterFragmentActivity

/**
 * MainActivity for HealthSync Test App
 *
 * CRITICAL: Must extend FlutterFragmentActivity (not FlutterActivity)
 * This is required for Health Connect permissions because:
 * - registerForActivityResult() is only available in ComponentActivity
 * - FlutterFragmentActivity extends ComponentActivity
 * - FlutterActivity does not extend ComponentActivity
 */
class MainActivity: FlutterFragmentActivity() {
}

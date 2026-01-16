/// Health Connect Onboarding System
///
/// Provides comprehensive onboarding flow for Health Connect setup including:
/// - SDK status checking and verification
/// - Play Store update/install handling
/// - "Update loop bug" mitigation with retry logic
/// - Device-specific optimizations
/// - Permission management
/// - Native step tracking detection
///
/// **Quick Start:**
/// ```dart
/// import 'package:health_sync_flutter/src/onboarding/onboarding.dart';
///
/// // Create service
/// final service = HealthConnectOnboardingService();
///
/// // Check and initialize
/// final result = await service.checkAndInitialize(
///   requiredPermissions: ['Steps', 'HeartRate'],
/// );
///
/// // Handle result
/// if (result.requiresSdkUpdate) {
///   await service.openPlayStore();
///   await service.verifyAfterUpdate();
/// } else if (result.requiresPermissions) {
///   await service.requestPermissions(result.requestedPermissions!);
/// } else if (result.isComplete) {
///   // Ready to use Health Connect!
/// }
/// ```
///
/// **Reactive UI with Streams:**
/// ```dart
/// service.stateStream.listen((state) {
///   print('State: ${state.displayName}');
/// });
///
/// service.resultStream.listen((result) {
///   updateUI(result);
/// });
/// ```
library onboarding;

// Core service
export 'health_connect_onboarding_service.dart';

// Models
export 'models/onboarding_state.dart';
export 'models/onboarding_result.dart';
export 'models/sdk_status.dart';
export 'models/device_profile.dart';

// Components
export 'components/sdk_status_checker.dart';
export 'components/retry_orchestrator.dart';
export 'components/device_advisor.dart';

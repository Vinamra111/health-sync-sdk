import 'package:flutter_test/flutter_test.dart';
import 'package:health_sync_flutter/src/onboarding/models/onboarding_state.dart';

void main() {
  group('OnboardingState', () {
    test('has all expected states', () {
      expect(OnboardingState.values.length, 13);
      expect(OnboardingState.values, contains(OnboardingState.initial));
      expect(OnboardingState.values, contains(OnboardingState.checking));
      expect(OnboardingState.values, contains(OnboardingState.updateRequired));
      expect(OnboardingState.values, contains(OnboardingState.sdkUnavailable));
      expect(OnboardingState.values, contains(OnboardingState.updating));
      expect(OnboardingState.values, contains(OnboardingState.installing));
      expect(OnboardingState.values, contains(OnboardingState.verifying));
      expect(OnboardingState.values, contains(OnboardingState.sdkReady));
      expect(OnboardingState.values, contains(OnboardingState.permissionsNeeded));
      expect(OnboardingState.values, contains(OnboardingState.requestingPermissions));
      expect(OnboardingState.values, contains(OnboardingState.complete));
      expect(OnboardingState.values, contains(OnboardingState.restartRequired));
      expect(OnboardingState.values, contains(OnboardingState.failed));
    });

    group('requiresUserAction', () {
      test('returns true for states needing user action', () {
        expect(OnboardingState.updateRequired.requiresUserAction, true);
        expect(OnboardingState.sdkUnavailable.requiresUserAction, true);
        expect(OnboardingState.permissionsNeeded.requiresUserAction, true);
        expect(OnboardingState.restartRequired.requiresUserAction, true);
      });

      test('returns false for automated states', () {
        expect(OnboardingState.initial.requiresUserAction, false);
        expect(OnboardingState.checking.requiresUserAction, false);
        expect(OnboardingState.verifying.requiresUserAction, false);
        expect(OnboardingState.complete.requiresUserAction, false);
      });
    });

    group('isTerminal', () {
      test('returns true for terminal states', () {
        expect(OnboardingState.complete.isTerminal, true);
        expect(OnboardingState.failed.isTerminal, true);
        expect(OnboardingState.restartRequired.isTerminal, true);
      });

      test('returns false for non-terminal states', () {
        expect(OnboardingState.checking.isTerminal, false);
        expect(OnboardingState.updateRequired.isTerminal, false);
        expect(OnboardingState.verifying.isTerminal, false);
      });
    });

    group('isLoading', () {
      test('returns true for loading/processing states', () {
        expect(OnboardingState.checking.isLoading, true);
        expect(OnboardingState.updating.isLoading, true);
        expect(OnboardingState.installing.isLoading, true);
        expect(OnboardingState.verifying.isLoading, true);
        expect(OnboardingState.requestingPermissions.isLoading, true);
      });

      test('returns false for non-loading states', () {
        expect(OnboardingState.initial.isLoading, false);
        expect(OnboardingState.updateRequired.isLoading, false);
        expect(OnboardingState.complete.isLoading, false);
      });
    });

    group('isSuccess', () {
      test('returns true only for complete state', () {
        expect(OnboardingState.complete.isSuccess, true);
      });

      test('returns false for all other states', () {
        expect(OnboardingState.initial.isSuccess, false);
        expect(OnboardingState.checking.isSuccess, false);
        expect(OnboardingState.failed.isSuccess, false);
      });
    });

    group('isError', () {
      test('returns true only for failed state', () {
        expect(OnboardingState.failed.isError, true);
      });

      test('returns false for all other states', () {
        expect(OnboardingState.initial.isError, false);
        expect(OnboardingState.complete.isError, false);
      });
    });

    group('canRetry', () {
      test('returns true for retryable states', () {
        expect(OnboardingState.failed.canRetry, true);
        expect(OnboardingState.updateRequired.canRetry, true);
        expect(OnboardingState.sdkUnavailable.canRetry, true);
      });

      test('returns false for non-retryable states', () {
        expect(OnboardingState.complete.canRetry, false);
        expect(OnboardingState.checking.canRetry, false);
      });
    });

    group('displayName', () {
      test('returns human-readable names', () {
        expect(OnboardingState.initial.displayName, 'Initializing');
        expect(OnboardingState.checking.displayName, 'Checking Health Connect');
        expect(OnboardingState.updateRequired.displayName, 'Update Required');
        expect(OnboardingState.complete.displayName, 'Setup Complete');
      });
    });

    group('description', () {
      test('returns detailed descriptions', () {
        expect(
          OnboardingState.updateRequired.description,
          contains('Health Connect needs to be updated'),
        );
        expect(
          OnboardingState.verifying.description,
          contains('Verifying Health Connect'),
        );
      });
    });

    group('userAction', () {
      test('returns action label for actionable states', () {
        expect(
          OnboardingState.updateRequired.userAction,
          'Tap "Update" to open the Play Store',
        );
        expect(
          OnboardingState.sdkUnavailable.userAction,
          'Tap "Install" to open the Play Store',
        );
        expect(
          OnboardingState.permissionsNeeded.userAction,
          'Tap "Grant Permissions" to continue',
        );
      });

      test('returns null for non-actionable states', () {
        expect(OnboardingState.checking.userAction, isNull);
        expect(OnboardingState.verifying.userAction, isNull);
        expect(OnboardingState.complete.userAction, isNull);
      });
    });
  });
}

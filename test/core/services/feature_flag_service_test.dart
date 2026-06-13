import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:el7reef/core/constants/feature_flags.dart';
import 'package:el7reef/core/services/feature_flag_service.dart';

void main() {
  tearDown(Get.reset);

  test(
    'FeatureFlags uses local defaults when no runtime service is registered',
    () {
      expect(FeatureFlags.socialUiEnabled, isFalse);
      expect(FeatureFlags.guestIdentityEnabled, isTrue);
    },
  );

  test('FeatureFlags reads runtime overrides from FeatureFlagService', () {
    Get.put(
      FeatureFlagService(
        overrides: const {
          FeatureFlagKey.socialUiEnabled: true,
          FeatureFlagKey.guestIdentityEnabled: false,
        },
      ),
    );

    expect(FeatureFlags.socialUiEnabled, isTrue);
    expect(FeatureFlags.guestIdentityEnabled, isFalse);
  });

  test('remote defaults expose stable Firebase Remote Config keys', () {
    expect(
      FeatureFlagService.remoteDefaults,
      containsPair('social_ui_enabled', false),
    );
    expect(
      FeatureFlagService.remoteDefaults,
      containsPair('guest_identity_enabled', true),
    );
  });
}

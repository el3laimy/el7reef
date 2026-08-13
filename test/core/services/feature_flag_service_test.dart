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
      expect(FeatureFlags.fanVotingEnabled, isFalse);
      expect(FeatureFlags.disputesEnabled, isFalse);
      expect(FeatureFlags.prideGrowthLinksEnabled, isFalse);
      expect(FeatureFlags.postMatchPrideHubEnabled, isFalse);
      expect(FeatureFlags.functionalGlassEnabled, isFalse);
      expect(FeatureFlags.prideShareCatalogV2Enabled, isFalse);
      expect(FeatureFlags.prideVideoExportEnabled, isFalse);
      expect(FeatureFlags.reduceGlassBlurEnabled, isFalse);
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
    expect(
      FeatureFlagService.remoteDefaults,
      containsPair('fan_voting_enabled', false),
    );
    expect(
      FeatureFlagService.remoteDefaults,
      containsPair('disputes_enabled', false),
    );
    expect(
      FeatureFlagService.remoteDefaults,
      containsPair('pride_growth_links_enabled', false),
    );
    expect(
      FeatureFlagService.remoteDefaults,
      containsPair('post_match_pride_hub_enabled', false),
    );
    expect(
      FeatureFlagService.remoteDefaults,
      containsPair('reduce_glass_blur_enabled', false),
    );
    expect(
      FeatureFlagService.remoteDefaults,
      containsPair('functional_glass_enabled', false),
    );
    expect(
      FeatureFlagService.remoteDefaults,
      containsPair('pride_share_catalog_v2_enabled', false),
    );
    expect(
      FeatureFlagService.remoteDefaults,
      containsPair('pride_video_export_enabled', false),
    );
  });
}

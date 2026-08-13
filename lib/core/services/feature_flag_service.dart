import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:get/get.dart';

import '../utils/app_logger.dart';

enum FeatureFlagKey {
  fantasyUiEnabled('fantasy_ui_enabled', false),
  activityFeedEnabled('activity_feed_enabled', false),
  challengesUiEnabled('challenges_ui_enabled', false),
  friendlyMatchTopLevelEnabled('friendly_match_top_level_enabled', false),
  socialUiEnabled('social_ui_enabled', false),
  organizerAdvancedOpsEnabled('organizer_advanced_ops_enabled', false),
  goldenRatingUiEnabled('golden_rating_ui_enabled', false),
  profileSettingsUiEnabled('profile_settings_ui_enabled', false),
  profileSharingUiEnabled('profile_sharing_ui_enabled', false),
  guestIdentityEnabled('guest_identity_enabled', true),
  hybridTournamentRegistrationEnabled(
    'hybrid_tournament_registration_enabled',
    true,
  ),
  matchdayUiEnabled('matchday_ui_enabled', true),
  fanVotingEnabled('fan_voting_enabled', false),
  disputesEnabled('disputes_enabled', false),
  prideGrowthLinksEnabled('pride_growth_links_enabled', false),
  postMatchPrideHubEnabled('post_match_pride_hub_enabled', false),
  functionalGlassEnabled('functional_glass_enabled', false),
  prideShareCatalogV2Enabled('pride_share_catalog_v2_enabled', false),
  prideVideoExportEnabled('pride_video_export_enabled', false),
  reduceGlassBlurEnabled('reduce_glass_blur_enabled', false);

  final String remoteKey;
  final bool defaultValue;

  const FeatureFlagKey(this.remoteKey, this.defaultValue);
}

class FeatureFlagService extends GetxService {
  FeatureFlagService({
    FirebaseRemoteConfig? remoteConfig,
    Map<FeatureFlagKey, bool> overrides = const {},
  }) : _remoteConfig = remoteConfig,
       _overrides = Map<FeatureFlagKey, bool>.from(overrides);

  FirebaseRemoteConfig? _remoteConfig;
  final Map<FeatureFlagKey, bool> _overrides;

  static Map<String, bool> get remoteDefaults {
    return {
      for (final key in FeatureFlagKey.values) key.remoteKey: key.defaultValue,
    };
  }

  static bool defaultValueFor(FeatureFlagKey key) => key.defaultValue;

  Future<FeatureFlagService> init() async {
    final remoteConfig = _remoteConfig ?? FirebaseRemoteConfig.instance;
    _remoteConfig = remoteConfig;
    try {
      await remoteConfig.setDefaults(remoteDefaults);
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );
      await remoteConfig.activate();
      unawaited(_fetchForNextStartup(remoteConfig));
    } catch (error, stackTrace) {
      AppLogger.warning(
        'FeatureFlagService.init',
        'Using local feature flag defaults after Remote Config failure.',
      );
      AppLogger.error('FeatureFlagService.init', error, stackTrace);
    }
    return this;
  }

  Future<void> _fetchForNextStartup(FirebaseRemoteConfig remoteConfig) async {
    try {
      await remoteConfig.fetch();
    } catch (error, stackTrace) {
      AppLogger.warning(
        'FeatureFlagService.fetchForNextStartup',
        'Remote Config refresh deferred; active cached values remain in use.',
      );
      AppLogger.error(
        'FeatureFlagService.fetchForNextStartup',
        error,
        stackTrace,
      );
    }
  }

  bool isEnabled(FeatureFlagKey key) {
    final override = _overrides[key];
    if (override != null) return override;
    final remoteConfig = _remoteConfig;
    if (remoteConfig == null) return key.defaultValue;
    return remoteConfig.getBool(key.remoteKey);
  }
}

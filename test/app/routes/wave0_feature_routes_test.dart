import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:el7reef/app/routes/app_pages.dart';
import 'package:el7reef/app/routes/app_routes.dart';
import 'package:el7reef/core/services/feature_flag_service.dart';
import 'package:el7reef/core/widgets/feature_unavailable_screen.dart';
import 'package:el7reef/features/match/bindings/fan_voting_binding.dart';
import 'package:el7reef/features/match/controllers/fan_voting_controller.dart';
import 'package:el7reef/features/match/views/fan_voting_screen.dart';
import 'package:el7reef/features/organizer/bindings/dispute_viewer_binding.dart';
import 'package:el7reef/features/organizer/controllers/dispute_viewer_controller.dart';
import 'package:el7reef/features/organizer/views/dispute_viewer_screen.dart';

void main() {
  tearDown(Get.reset);

  test('unsafe Wave 0 routes fail closed with local defaults', () {
    expect(_pageFor(AppRoutes.mvpVote), isA<FeatureUnavailableScreen>());
    expect(_pageFor(AppRoutes.disputeViewer), isA<FeatureUnavailableScreen>());

    expect(() => FanVotingBinding().dependencies(), returnsNormally);
    expect(() => DisputeViewerBinding().dependencies(), returnsNormally);
    expect(Get.isRegistered<FanVotingController>(), isFalse);
    expect(Get.isRegistered<DisputeViewerController>(), isFalse);
  });

  test('Wave 0 routes can only open behind explicit runtime overrides', () {
    Get.put(
      FeatureFlagService(
        overrides: const {
          FeatureFlagKey.fanVotingEnabled: true,
          FeatureFlagKey.disputesEnabled: true,
        },
      ),
    );

    expect(_pageFor(AppRoutes.mvpVote), isA<FanVotingScreen>());
    expect(_pageFor(AppRoutes.disputeViewer), isA<DisputeViewerScreen>());
  });
}

Object _pageFor(String routeName) {
  return AppPages.routes.firstWhere((route) => route.name == routeName).page();
}

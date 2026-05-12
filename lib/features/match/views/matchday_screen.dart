import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../controllers/matchday_controller.dart';
import '../widgets/matchday_widgets.dart';

class MatchdayScreen extends GetView<MatchdayController> {
  const MatchdayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('يوم المباراة'),
        actions: [
          IconButton(
            onPressed: controller.loadMatchday,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Obx(() {
          if (controller.isLoading.value && controller.match.value == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (controller.errorMessage.value.isNotEmpty &&
              controller.match.value == null) {
            return MatchdayErrorState(
              message: controller.errorMessage.value,
              onRetry: controller.loadMatchday,
            );
          }

          return RefreshIndicator(
            onRefresh: controller.loadMatchday,
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.all(AppDimensions.pagePadding),
              children: [
                MatchdayHeader(controller: controller),
                const SizedBox(height: AppDimensions.md),
                if (controller.selectedSide != null) ...[
                  MatchdayQuickStats(controller: controller),
                  const SizedBox(height: AppDimensions.md),
                  MatchdayProgressStepper(controller: controller),
                  const SizedBox(height: AppDimensions.md),
                  MatchdaySideSelector(controller: controller),
                  const SizedBox(height: AppDimensions.md),
                  MatchdayAttendanceSection(controller: controller),
                  const SizedBox(height: AppDimensions.md),
                  MatchdayLineupSection(controller: controller),
                  const SizedBox(height: AppDimensions.md),
                  MatchdaySubstitutionSection(controller: controller),
                ] else ...[
                  MatchdaySideSelector(controller: controller),
                ],
                const SizedBox(height: AppDimensions.xl),
              ],
            ),
          );
        }),
      ),
    );
  }
}

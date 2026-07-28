import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/lineup/formation_library.dart';
import '../../../core/widgets/el7reef_button.dart';
import '../../../core/widgets/el7reef_glass_surface.dart';
import '../../team/controllers/team_controller.dart';
import '../controllers/match_controller.dart';

void showCreateMatchSheetGlobal() {
  final controller = Get.find<MatchController>();
  Get.bottomSheet(
    CreateMatchSheet(controller: controller),
    isScrollControlled: true,
  );
}

class CreateMatchSheet extends StatefulWidget {
  final MatchController controller;
  const CreateMatchSheet({super.key, required this.controller});

  @override
  State<CreateMatchSheet> createState() => _CreateMatchSheetState();
}

class _CreateMatchSheetState extends State<CreateMatchSheet> {
  final _locationController = TextEditingController();
  final _selectedTeamSize = 5.obs;
  final RxBool _playAsTeam = false.obs;
  final RxnString _selectedTeamId = RxnString();

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasTeamController = Get.isRegistered<TeamController>();
    final teamCtrl = hasTeamController ? Get.find<TeamController>() : null;

    return El7reefSolidSurface(
      elevated: true,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppDimensions.radiusXl),
      ),
      padding:
          EdgeInsets.symmetric(
            horizontal: AppDimensions.lg,
            vertical: AppDimensions.lg,
          ).copyWith(
            bottom: MediaQuery.of(context).viewInsets.bottom + AppDimensions.lg,
          ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            Text('ابدأ مباراة جديدة ⚽', style: AppTextStyles.headlineMedium),
            const SizedBox(height: AppDimensions.sm),
            Text(
              'أنشئ المباراة وادعُ اللاعبين للانضمام',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: AppDimensions.lg),

            if (teamCtrl != null && teamCtrl.myTeams.isNotEmpty) ...[
              Text('كيف ستلعب هذه المباراة؟', style: AppTextStyles.titleSmall),
              const SizedBox(height: AppDimensions.sm),
              Obx(
                () => Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('كلاعب فردي (Pickup)')),
                        selected: !_playAsTeam.value,
                        onSelected: (val) {
                          if (val) {
                            _playAsTeam.value = false;
                            _selectedTeamId.value = null;
                          }
                        },
                        selectedColor: AppColors.primarySurface,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('باسم فريقي')),
                        selected: _playAsTeam.value,
                        onSelected: (val) {
                          if (val) {
                            _playAsTeam.value = true;
                            if (teamCtrl.myTeams.isNotEmpty) {
                              _selectedTeamId.value = teamCtrl.myTeams.first.id;
                            }
                          }
                        },
                        selectedColor: AppColors.primarySurface,
                      ),
                    ),
                  ],
                ),
              ),
              Obx(() {
                if (_playAsTeam.value && teamCtrl.myTeams.isNotEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: AppDimensions.md),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'اختر فريقك',
                        border: OutlineInputBorder(),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedTeamId.value,
                          isExpanded: true,
                          items: teamCtrl.myTeams.map((team) {
                            return DropdownMenuItem(
                              value: team.id,
                              child: Text(team.name),
                            );
                          }).toList(),
                          onChanged: (val) {
                            _selectedTeamId.value = val;
                          },
                        ),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              }),
              const SizedBox(height: AppDimensions.md),
            ],

            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'المكان (اختياري)',
                prefixIcon: Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppDimensions.md),

            Text('عدد اللاعبين لكل فريق', style: AppTextStyles.titleSmall),
            const SizedBox(height: AppDimensions.sm),
            Obx(
              () => Wrap(
                spacing: AppDimensions.sm,
                runSpacing: AppDimensions.sm,
                children: supportedPlayerCounts
                    .map((size) {
                      return ChoiceChip(
                        label: Text('${size}v$size'),
                        selected: _selectedTeamSize.value == size,
                        onSelected: (_) => _selectedTeamSize.value = size,
                        selectedColor: AppColors.primarySurface,
                      );
                    })
                    .toList(growable: false),
              ),
            ),
            const SizedBox(height: AppDimensions.lg),

            Obx(
              () => El7reefButton(
                text: 'إنشاء المباراة',
                icon: Icons.play_arrow_rounded,
                isLoading: widget.controller.isLoading.value,
                onPressed: () async {
                  final uid = widget.controller.authService.currentUserId;
                  if (uid == null) return;

                  final isTeam =
                      _playAsTeam.value && _selectedTeamId.value != null;

                  final matchId = await widget.controller.createMatch(
                    teamAIds: [uid],
                    teamBIds: [],
                    teamAId: isTeam ? _selectedTeamId.value : null,
                    location: _locationController.text.trim().isNotEmpty
                        ? _locationController.text.trim()
                        : null,
                    teamSize: _selectedTeamSize.value,
                  );
                  Get.back();
                  if (matchId != null) {
                    Get.toNamed(AppRoutes.matchLobbyById(matchId));
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

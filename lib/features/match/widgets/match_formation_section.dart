import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/lineup/formation_engine.dart';
import '../../../core/lineup/formation_library.dart';
import '../../../core/lineup/lineup_types.dart';
import '../../../core/lineup/lineup_utils.dart';
import '../../../domain/entities/player.dart';
import '../../lineup/widgets/bench_bar.dart';
import '../../lineup/widgets/professional_pitch_card.dart';
import '../controllers/match_lobby_controller.dart';

class MatchFormationSection extends StatelessWidget {
  final MatchLobbyController controller;

  const MatchFormationSection({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final uid = controller.currentUserId;
      final isTeamA = controller.teamAPlayers.any((player) => player.id == uid);
      final isTeamB = controller.teamBPlayers.any((player) => player.id == uid);

      if (!isTeamA && !isTeamB && !controller.isOrganizer) {
        return const Padding(
          padding: EdgeInsets.all(AppDimensions.md),
          child: Text(
            'يجب الانضمام للمباراة أولاً لعرض خطة اللعب',
            textAlign: TextAlign.center,
          ),
        );
      }

      final side = isTeamA || controller.isOrganizer ? 'A' : 'B';
      final players = side == 'A'
          ? controller.teamAPlayers
          : controller.teamBPlayers;
      final playerCount = controller.effectiveTeamSize;
      final formationCode = getDefaultFormation(playerCount);
      final lineupPlayers = players.map(_lineupPlayerFromPlayer).toList();
      final generatedSlots = FormationEngine.generateFormationSlots(
        playerCount: playerCount,
        formationCode: formationCode,
      );
      final assigned = LineupUtils.assignPlayersToGeneratedSlots(
        slots: generatedSlots,
        starters: lineupPlayers.take(playerCount).toList(growable: false),
      );
      final onPitch = assigned.slots
          .map((slot) => slot.occupantKey)
          .whereType<String>()
          .toSet();
      final playersByKey = {
        for (final player in lineupPlayers) player.key: player,
      };
      final bench = lineupPlayers
          .where((player) => !onPitch.contains(player.key))
          .toList(growable: false);

      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.pagePadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('معاينة التشكيلة', style: AppTextStyles.titleLarge),
                      Text(
                        '${playerCount}v$playerCount • $formationCode',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (controller.isOrganizer)
                  TextButton.icon(
                    onPressed: () => _showGuestDialog(context, side),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: const Text('ضيف'),
                  ),
              ],
            ),
            const SizedBox(height: AppDimensions.sm),
            ProfessionalPitchCard(
              slots: assigned.slots,
              playersByKey: playersByKey,
              formationCode: formationCode,
              playerCount: playerCount,
              teamName: side == 'A' ? 'فريق A' : 'فريق B',
              presentationMode: true,
            ),
            const SizedBox(height: AppDimensions.md),
            BenchBar(
              players: bench,
              compact: true,
              onAddGuest: controller.isOrganizer
                  ? () => _showGuestDialog(context, side)
                  : null,
            ),
          ],
        ),
      );
    });
  }

  LineupPlayer _lineupPlayerFromPlayer(Player player) {
    return LineupPlayer(
      id: player.id,
      name: player.name,
      photoUrl: player.photoThumbUrl ?? player.photoUrl,
      preferredPosition: player.position,
      isRegistered: !player.isGuest,
    );
  }

  void _showGuestDialog(BuildContext context, String side) {
    Get.dialog(_LobbyGuestDialog(controller: controller, side: side));
  }
}

class _LobbyGuestDialog extends StatefulWidget {
  final MatchLobbyController controller;
  final String side;

  const _LobbyGuestDialog({required this.controller, required this.side});

  @override
  State<_LobbyGuestDialog> createState() => _LobbyGuestDialogState();
}

class _LobbyGuestDialogState extends State<_LobbyGuestDialog> {
  final _nameController = TextEditingController();
  var _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    final saved = await widget.controller.addGuestPlayer(
      _nameController.text,
      widget.side,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (saved) {
      Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة لاعب ضيف'),
      content: TextField(
        controller: _nameController,
        decoration: const InputDecoration(labelText: 'اسم اللاعب'),
        autofocus: true,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Get.back(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('إضافة'),
        ),
      ],
    );
  }
}

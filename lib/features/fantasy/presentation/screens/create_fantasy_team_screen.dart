import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/fantasy_create_team_controller.dart';
import '../models/fantasy_market_player.dart';
import '../widgets/fantasy_lifecycle_banner.dart';
import 'player_picker_screen.dart';
import '../../../../core/widgets/tier_badge_widget.dart';

class CreateFantasyTeamScreen extends GetView<FantasyCreateTeamController> {
  const CreateFantasyTeamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF081120),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Obx(() => Text('بناء التشكيلة - ${controller.leagueTitle.value}')),
        actions: [
          IconButton(
            tooltip: 'تجديد البيانات',
            onPressed: controller.loadDraft,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.slots.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.errorMessage.isNotEmpty && controller.slots.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                controller.errorMessage.value,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final starters =
            controller.slots.where((slot) => slot.isStarting).toList();
        final bench = controller.slots.where((slot) => !slot.isStarting).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            _buildHeaderCard(),
            if (controller.lifecycle.value != null) ...[
              const SizedBox(height: 16),
              FantasyLifecycleBanner(lifecycle: controller.lifecycle.value),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: controller.teamNameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'اسم الفريق',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF102038),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: controller.marketPlayers.isEmpty
                            || !controller.canEditDraft
                        ? null
                        : controller.autoPick,
                    icon: const Icon(Icons.flash_on_rounded),
                    label: const Text('Auto Pick'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: !controller.canEditDraft
                        ? null
                        : () {
                            for (var i = 0; i < controller.slots.length; i++) {
                              controller.clearSlot(i);
                            }
                          },
                    icon: const Icon(Icons.layers_clear_rounded),
                    label: const Text('تفريغ'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SectionTitle(
              title: 'الأساسيون',
              subtitle: '${starters.length} خانة',
            ),
            const SizedBox(height: 12),
            ...List.generate(starters.length, (index) {
              final slotIndex = controller.slots.indexOf(starters[index]);
              return _buildSlotCard(context, slotIndex, starters[index]);
            }),
            const SizedBox(height: 20),
            _SectionTitle(
              title: 'دكة البدلاء',
              subtitle: '${bench.length} خانة',
            ),
            const SizedBox(height: 12),
            ...List.generate(bench.length, (index) {
              final slotIndex = controller.slots.indexOf(bench[index]);
              return _buildSlotCard(context, slotIndex, bench[index]);
            }),
          ],
        );
      }),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Obx(
            () => FilledButton.icon(
              onPressed: controller.isSaving.value || !controller.canEditDraft
                  ? null
                  : controller.saveTeam,
              icon: controller.isSaving.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline_rounded),
              label: Text(
                controller.isSaving.value ? 'جارٍ الحفظ...' : 'حفظ التشكيلة',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10233C), Color(0xFF0A1628)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Obx(
        () => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              controller.leagueTitle.value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'التزم بالميزانية وبقواعد الفئات: ذهبي واحد، فضيان كحد أقصى.',
              style: TextStyle(color: Colors.white70, height: 1.5),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _HeaderMetric(
                    label: 'الميزانية',
                    value: '${controller.remainingBudget.toStringAsFixed(1)}M',
                    color: const Color(0xFF22C55E),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _HeaderMetric(
                    label: 'اللاعبون',
                    value: '${controller.selectedCount}/${controller.totalSlotCount}',
                    color: const Color(0xFF38BDF8),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _HeaderMetric(
                    label: 'الخطة',
                    value: controller.teamSize.value.value.toString(),
                    color: const Color(0xFFF59E0B),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotCard(
    BuildContext context,
    int index,
    FantasyDraftSlot slot,
  ) {
    final selected = slot.selectedPlayer;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF102038),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        leading: selected == null
            ? CircleAvatar(
                backgroundColor: const Color(0xFF1D4ED8).withValues(alpha: 0.18),
                child: Text(
                  slot.requiredPosition,
                  style: const TextStyle(
                    color: Color(0xFF93C5FD),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              )
            : TierBadgeWidget(tier: selected.value.tier),
        title: Text(
          selected?.displayName ?? slot.label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: selected == null
              ? Text(
                  'اختر لاعباً لمركز ${slot.requiredPosition}',
                  style: const TextStyle(color: Colors.white60),
                )
              : Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _SlotBadge(label: slot.requiredPosition),
                    _SlotBadge(label: '${selected.value.currentPrice}M'),
                    _SlotBadge(label: '${selected.value.totalFantasyPoints} pts'),
                  ],
                ),
        ),
        trailing: Wrap(
          spacing: 8,
          children: [
            if (selected != null)
              IconButton(
                onPressed: controller.canEditDraft
                    ? () => controller.clearSlot(index)
                    : null,
                icon: const Icon(Icons.close_rounded, color: Colors.white54),
              ),
            FilledButton(
              onPressed: controller.canEditDraft
                  ? () => _openPicker(context, index, slot)
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
              ),
              child: Text(selected == null ? 'اختيار' : 'تبديل'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPicker(
    BuildContext context,
    int index,
    FantasyDraftSlot slot,
  ) async {
    final availableBudget =
        controller.remainingBudget + (slot.selectedPlayer?.value.currentPrice ?? 0);
    final result = await Get.to<FantasyMarketPlayer>(
      () => PlayerPickerScreen(
        players: controller.marketPlayers.toList(),
        requiredPosition: slot.requiredPosition,
        selectedPlayerIds: controller.selectedPlayerIds,
        currentPlayerId: slot.selectedPlayer?.player.id,
        availableBudget: availableBudget,
      ),
    );

    if (result != null) {
      controller.assignPlayerToSlot(index, result);
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 8),
        Text(subtitle, style: const TextStyle(color: Colors.white54)),
      ],
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HeaderMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotBadge extends StatelessWidget {
  final String label;

  const _SlotBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }
}

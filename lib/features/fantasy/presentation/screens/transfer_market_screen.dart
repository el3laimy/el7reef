import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/transfer_market_controller.dart';
import '../models/fantasy_market_player.dart';
import '../models/fantasy_squad_member.dart';
import '../widgets/fantasy_lifecycle_banner.dart';
import 'player_picker_screen.dart';
import '../../../../core/widgets/tier_badge_widget.dart';

class TransferMarketScreen extends GetView<TransferMarketController> {
  const TransferMarketScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF081120),
      appBar: AppBar(
        title: Obx(() => Text('انتقالات ${controller.leagueTitle.value}')),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: controller.loadData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.squad.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.errorMessage.isNotEmpty && controller.squad.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                controller.errorMessage.value,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          );
        }

        if (controller.team.value == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'أنشئ فريقك أولاً قبل الدخول إلى سوق الانتقالات.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            _buildMetrics(),
            if (controller.lifecycle.value != null) ...[
              const SizedBox(height: 16),
              FantasyLifecycleBanner(lifecycle: controller.lifecycle.value),
            ],
            const SizedBox(height: 16),
            if (controller.wildcardActive)
              const _InfoBanner(
                title: 'Wildcard مفعّل',
                subtitle: 'الصفقات الإضافية لن تخصم نقاطاً طالما الخاصية نشطة.',
                color: Color(0xFFF59E0B),
              )
            else
              const _InfoBanner(
                title: 'الوضع القياسي',
                subtitle: 'سيتم خصم 4 نقاط لكل انتقال إضافي بعد انتهاء التبديلات المجانية.',
                color: Color(0xFF38BDF8),
              ),
            const SizedBox(height: 20),
            const Text(
              'اختر لاعباً للاستبدال',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            ...controller.squad.map(
              (member) => _buildMemberCard(context, member),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildMetrics() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF10233C), Color(0xFF0A1628)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Metric(
              label: 'المتبقي',
              value: '${controller.budget.toStringAsFixed(1)}M',
              color: const Color(0xFF22C55E),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _Metric(
              label: 'تبديلات مجانية',
              value: '${controller.freeTransfers}',
              color: const Color(0xFF38BDF8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _Metric(
              label: 'الحالة',
              value: controller.wildcardActive ? 'Wildcard' : 'Normal',
              color: const Color(0xFFF59E0B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(BuildContext context, FantasySquadMember member) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF102038),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: TierBadgeWidget(tier: member.marketPlayer.value.tier),
        title: Text(
          member.marketPlayer.displayName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _Tag(label: member.marketPlayer.positionCode),
              _Tag(label: '${member.marketPlayer.value.currentPrice}M'),
              if (!member.slot.isStartingXI)
                _Tag(label: 'Bench ${member.slot.benchPriority}'),
            ],
          ),
        ),
        trailing: FilledButton(
          onPressed: controller.isSubmitting.value || !controller.canTransfer
              ? null
              : () => _replaceMember(context, member),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF38BDF8),
          ),
          child: const Text('استبدال'),
        ),
      ),
    );
  }

  Future<void> _replaceMember(
    BuildContext context,
    FantasySquadMember member,
  ) async {
    final availableBudget =
        controller.budget + member.marketPlayer.value.currentPrice;
    final replacement = await Get.to<FantasyMarketPlayer>(
      () => PlayerPickerScreen(
        players: controller.marketPlayers.toList(),
        requiredPosition: member.slot.isStartingXI
            ? member.marketPlayer.positionCode
            : 'SUB',
        selectedPlayerIds:
            controller.selectedIdsExcluding(member.marketPlayer.player.id),
        currentPlayerId: member.marketPlayer.player.id,
        availableBudget: availableBudget,
      ),
    );

    if (replacement != null) {
      await controller.replacePlayer(
        member: member,
        replacement: replacement,
      );
    }
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Metric({
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;

  const _InfoBanner({
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white70, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;

  const _Tag({required this.label});

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

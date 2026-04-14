import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../domain/entities/fantasy_slot.dart';
import '../../../../core/widgets/tier_badge_widget.dart';
import '../controllers/fantasy_team_controller.dart';
import '../models/fantasy_squad_member.dart';
import '../widgets/fantasy_lifecycle_banner.dart';

class FantasyTeamScreen extends GetView<FantasyTeamController> {
  const FantasyTeamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF081120),
      appBar: AppBar(
        title: const Text('فريقي'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: controller.loadTeam,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value &&
            controller.team.value == null &&
            controller.errorMessage.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.errorMessage.isNotEmpty && controller.team.value == null) {
          return _InfoState(
            title: controller.errorMessage.value,
            subtitle: 'حاول لاحقاً أو أعد تسجيل الدخول.',
          );
        }

        final team = controller.team.value;
        if (team == null) {
          return _InfoState(
            title: 'لا يوجد فريق فانتازي بعد',
            subtitle: 'ابدأ ببناء تشكيلتك الأولى ثم ارجع هنا لإدارة الفريق.',
            actionLabel: 'أنشئ فريقي',
            onPressed: controller.openDraft,
          );
        }

        if (!controller.isJoinedLeague) {
          return _InfoState(
            title: 'فريقك غير منضم لهذا الدوري بعد',
            subtitle:
                'يمكنك استخدام نفس التشكيلة الحالية وربطها بهذا الدوري من شاشة الانضمام.',
            actionLabel: 'ضم فريقي',
            onPressed: controller.openDraft,
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
          children: [
            _buildSummary(team.teamName),
            if (controller.lifecycle.value != null) ...[
              const SizedBox(height: 16),
              FantasyLifecycleBanner(lifecycle: controller.lifecycle.value),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: controller.canOpenTransfers
                        ? controller.openTransfers
                        : null,
                    icon: const Icon(Icons.swap_horiz_rounded),
                    label: const Text('الانتقالات'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF38BDF8),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Get.toNamed(
                        AppRoutes.fantasyLeaderboardForLeague(controller.leagueId),
                      );
                    },
                    icon: const Icon(Icons.emoji_events_outlined),
                    label: const Text('الترتيب'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionTitle(
              title: 'الأساسيون',
              subtitle: '${controller.starters.length} لاعب',
            ),
            const SizedBox(height: 12),
            ...controller.starters.map(_buildSquadMemberCard),
            const SizedBox(height: 20),
            _SectionTitle(
              title: 'البدلاء',
              subtitle: '${controller.bench.length} لاعب',
            ),
            const SizedBox(height: 12),
            ...controller.bench.map(_buildSquadMemberCard),
            const SizedBox(height: 20),
            _SectionTitle(
              title: 'آخر الانتقالات',
              subtitle: '${controller.transferHistory.length} عملية',
            ),
            const SizedBox(height: 12),
            if (controller.transferHistory.isEmpty)
              const _SimpleCard(
                child: Text(
                  'لم يتم تنفيذ أي انتقالات بعد.',
                  style: TextStyle(color: Colors.white70),
                ),
              )
            else
              ...controller.transferHistory.map(_buildTransferHistoryCard),
          ],
        );
      }),
    );
  }

  Widget _buildSummary(String teamName) {
    final team = controller.team.value!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF10233C), Color(0xFF0A1628)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            teamName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'مرتبط بـ ${team.leagueIds.length} دوري | خواص نشطة: ${team.activeChips.isEmpty ? 'لا يوجد' : team.activeChips.join(', ')}',
            style: const TextStyle(color: Colors.white70, height: 1.5),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  label: 'النقاط',
                  value: '${team.totalPoints}',
                  color: const Color(0xFF38BDF8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatBox(
                  label: 'الجولة',
                  value: '${team.currentGameweekPoints}',
                  color: const Color(0xFF22C55E),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatBox(
                  label: 'المتبقي',
                  value: '${team.budget.toStringAsFixed(1)}M',
                  color: const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSquadMemberCard(FantasySquadMember member) {
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
        title: Row(
          children: [
            Expanded(
              child: Text(
                member.marketPlayer.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (member.isCaptain || member.isViceCaptain)
              Chip(
                label: Text(member.isCaptain ? 'C' : 'V'),
                side: BorderSide.none,
                backgroundColor:
                    member.isCaptain ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
                labelStyle: const TextStyle(color: Colors.black),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _MetaBadge(label: member.marketPlayer.positionCode),
              _MetaBadge(label: '${member.marketPlayer.value.currentPrice}M'),
              _MetaBadge(label: '${member.slot.pointsEarned} pts'),
              if (!member.slot.isStartingXI)
                _MetaBadge(label: 'Bench ${member.slot.benchPriority}'),
            ],
          ),
        ),
        trailing: member.slot.isStartingXI && !controller.isRoundLocked
            ? PopupMenuButton<FantasyPlayerRole>(
                color: const Color(0xFF102038),
                onSelected: (role) {
                  if (role == FantasyPlayerRole.captain) {
                    controller.setCaptain(member.slot.id);
                  } else if (role == FantasyPlayerRole.viceCaptain) {
                    controller.setViceCaptain(member.slot.id);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: FantasyPlayerRole.captain,
                    child: Text('تعيين كابتن',
                        style: TextStyle(color: Colors.white)),
                  ),
                  PopupMenuItem(
                    value: FantasyPlayerRole.viceCaptain,
                    child: Text('تعيين نائب',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
                child: const Icon(Icons.more_vert_rounded, color: Colors.white70),
              )
            : null,
      ),
    );
  }

  Widget _buildTransferHistoryCard(TransferHistoryEntry entry) {
    return _SimpleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${entry.playerOutName} -> ${entry.playerInName}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'الجولة ${entry.record.gameweek} | التكلفة ${entry.record.cost} | ${_formatDate(entry.record.timestamp)}',
            style: const TextStyle(color: Colors.white60),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime timestamp) {
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
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

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBox({
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

class _MetaBadge extends StatelessWidget {
  final String label;

  const _MetaBadge({required this.label});

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

class _SimpleCard extends StatelessWidget {
  final Widget child;

  const _SimpleCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF102038),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }
}

class _InfoState extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onPressed;

  const _InfoState({
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield_outlined, size: 54, color: Colors.white54),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60),
            ),
            if (actionLabel != null && onPressed != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onPressed,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

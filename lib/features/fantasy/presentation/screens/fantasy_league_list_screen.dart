import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../controllers/fantasy_home_controller.dart';

class FantasyLeagueListScreen extends GetView<FantasyHomeController> {
  const FantasyLeagueListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF081120),
      appBar: AppBar(
        title: const Text('دوريات الفانتازي'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: controller.loadData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.leagues.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.errorMessage.isNotEmpty && controller.leagues.isEmpty) {
          return _FantasyInfoState(
            title: controller.errorMessage.value,
            subtitle: 'حاول التحديث بعد لحظات.',
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            _buildSummaryCard(),
            const SizedBox(height: 24),
            const Text(
              'الدوريات المتاحة',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            ...controller.leagues.map(_buildLeagueTile),
          ],
        );
      }),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (controller.currentTeam.value == null) {
            Get.toNamed(AppRoutes.fantasyPickTeamForLeague('global'));
          } else {
            Get.toNamed(AppRoutes.fantasyTeamForLeague('global'));
          }
        },
        backgroundColor: const Color(0xFF38BDF8),
        icon: const Icon(Icons.auto_awesome, color: Colors.white),
        label: Text(
          controller.currentTeam.value == null ? 'ابنِ فريقي' : 'فريقي',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final team = controller.currentTeam.value;

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
      child: team == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ابدأ أول مغامرة فانتازي',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'ابنِ تشكيلتك، انضم للدوري العالمي أو لدورات مفعّل عليها الفانتازي، ثم تابع ترتيبك الحقيقي.',
                  style: TextStyle(color: Colors.white70, height: 1.5),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    Get.toNamed(AppRoutes.fantasyPickTeamForLeague('global'));
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                  ),
                  child: const Text('أنشئ فريقي الآن'),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  team.teamName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'فريقك مرتبط حالياً بـ ${team.leagueIds.length} دوري',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _MetricChip(
                        label: 'النقاط',
                        value: '${team.totalPoints}',
                        valueColor: const Color(0xFF38BDF8),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricChip(
                        label: 'الجولة',
                        value: '${team.currentGameweekPoints}',
                        valueColor: const Color(0xFF22C55E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MetricChip(
                        label: 'الميزانية',
                        value: '${team.budget.toStringAsFixed(1)}M',
                        valueColor: const Color(0xFFF59E0B),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricChip(
                        label: 'الترتيب العالمي',
                        value: controller.globalRank.value == 0
                            ? '-'
                            : '#${controller.globalRank.value}',
                        valueColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildLeagueTile(FantasyLeagueSummary league) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF102038),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        leading: CircleAvatar(
          backgroundColor: league.isGlobal
              ? const Color(0xFFF59E0B).withValues(alpha: 0.16)
              : const Color(0xFF22C55E).withValues(alpha: 0.16),
          child: Icon(
            league.isGlobal ? Icons.public_rounded : Icons.emoji_events_rounded,
            color:
                league.isGlobal ? const Color(0xFFF59E0B) : const Color(0xFF22C55E),
          ),
        ),
        title: Text(
          league.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            league.subtitle,
            style: const TextStyle(color: Colors.white60),
          ),
        ),
        trailing: league.joined
            ? const Chip(
                label: Text('منضم'),
                side: BorderSide.none,
                backgroundColor: Color(0xFF1D4ED8),
                labelStyle: TextStyle(color: Colors.white),
              )
            : OutlinedButton(
                onPressed: () {
                  Get.toNamed(AppRoutes.fantasyPickTeamForLeague(league.id));
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF38BDF8)),
                ),
                child: const Text(
                  'انضم',
                  style: TextStyle(color: Color(0xFF38BDF8)),
                ),
              ),
        onTap: () {
          if (league.joined) {
            Get.toNamed(AppRoutes.fantasyTeamForLeague(league.id));
          } else {
            Get.toNamed(AppRoutes.fantasyLeaderboardForLeague(league.id));
          }
        },
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _MetricChip({
    required this.label,
    required this.value,
    required this.valueColor,
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
              color: valueColor,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _FantasyInfoState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _FantasyInfoState({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome_outlined, color: Colors.white54, size: 48),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }
}

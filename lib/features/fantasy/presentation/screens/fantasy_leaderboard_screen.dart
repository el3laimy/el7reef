import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../controllers/fantasy_leaderboard_controller.dart';
import '../widgets/fantasy_lifecycle_banner.dart';

class FantasyLeaderboardScreen extends GetView<FantasyLeaderboardController> {
  const FantasyLeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF081120),
      appBar: AppBar(
        title: Obx(() => Text('ترتيب ${controller.leagueTitle.value}')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: controller.loadLeaderboard,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.entries.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.errorMessage.isNotEmpty && controller.entries.isEmpty) {
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

        if (controller.entries.isEmpty) {
          final hasTeam = controller.currentTeam.value != null;
          final ctaLabel = !hasTeam
              ? 'ابنِ فريقي'
              : controller.isJoinedLeague
                  ? 'فريقي'
                  : 'ضم فريقي';
          final ctaRoute = controller.isJoinedLeague
              ? AppRoutes.fantasyTeamForLeague(controller.leagueId)
              : AppRoutes.fantasyPickTeamForLeague(controller.leagueId);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              if (controller.lifecycle.value != null)
                FantasyLifecycleBanner(lifecycle: controller.lifecycle.value),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.emoji_events_outlined,
                        color: Colors.white54, size: 56),
                    const SizedBox(height: 12),
                    const Text(
                      'لا يوجد ترتيب بعد',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'كن أول من ينضم إلى هذا الدوري ويبدأ السباق.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        Get.toNamed(ctaRoute);
                      },
                      child: Text(ctaLabel),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        final podium = controller.entries.take(3).toList();
        final rest = controller.entries.length > 3
            ? controller.entries.sublist(3)
            : const <FantasyLeaderboardEntry>[];

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            if (controller.lifecycle.value != null) ...[
              FantasyLifecycleBanner(lifecycle: controller.lifecycle.value),
              const SizedBox(height: 16),
            ],
            _buildPodium(podium),
            const SizedBox(height: 20),
            const Text(
              'كل الترتيب',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(controller.entries.length, (index) {
              final entry = controller.entries[index];
              return _buildRow(index + 1, entry);
            }),
            if (rest.isEmpty) const SizedBox(height: 8),
          ],
        );
      }),
      floatingActionButton: Obx(() {
        if (controller.currentUserId == null) {
          return const SizedBox.shrink();
        }

        final hasTeam = controller.currentTeam.value != null;
        final joined = controller.isJoinedLeague;
        final label = joined
            ? 'فريقي'
            : hasTeam
                ? 'ضم فريقي'
                : 'ابنِ فريقي';

        return FloatingActionButton.extended(
          onPressed: () {
            Get.toNamed(
                joined
                    ? AppRoutes.fantasyTeamForLeague(controller.leagueId)
                    : AppRoutes.fantasyPickTeamForLeague(controller.leagueId),
            );
          },
          backgroundColor: const Color(0xFF38BDF8),
          label: Text(label),
          icon: Icon(joined ? Icons.shield_rounded : Icons.group_add_rounded),
        );
      }),
    );
  }

  Widget _buildPodium(List<FantasyLeaderboardEntry> entries) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF10233C), Color(0xFF0A1628)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(entries.length, (index) {
          final entry = entries[index];
          final rank = index + 1;
          final height = rank == 1 ? 150.0 : rank == 2 ? 120.0 : 100.0;
          final color = rank == 1
              ? const Color(0xFFF59E0B)
              : rank == 2
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFFB45309);

          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  radius: rank == 1 ? 28 : 24,
                  backgroundColor: color.withValues(alpha: 0.18),
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  entry.team.teamName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.managerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 88,
                  height: height,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Center(
                    child: Text(
                      '${entry.team.totalPoints}',
                      style: TextStyle(
                        color: color,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildRow(int rank, FantasyLeaderboardEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: entry.isMine
            ? const Color(0xFF0F2745)
            : const Color(0xFF102038),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: entry.isMine
              ? const Color(0xFF38BDF8)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.team.teamName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (entry.isMine)
                      const Chip(
                        label: Text('فريقي'),
                        side: BorderSide.none,
                        backgroundColor: Color(0xFF38BDF8),
                        labelStyle: TextStyle(color: Colors.white),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  entry.managerName,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.team.currentGameweekPoints} GW',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                '${entry.team.totalPoints}',
                style: const TextStyle(
                  color: Color(0xFF38BDF8),
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

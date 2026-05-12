import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' as intl;

import '../../../app/routes/app_routes.dart';
import '../../../core/enums/match_status.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/entities/knockout_tie.dart';
import '../controllers/tournament_operations_controller.dart';

class TournamentBracketScreen extends GetView<TournamentOperationsController> {
  const TournamentBracketScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ScaffoldListScreen(
      title: 'Bracket',
      child: Obx(() {
        final bracket = controller.knockoutBracket.value;
        if (bracket == null) {
          return const _StateMessage(
            title: 'لا يوجد bracket بعد',
            message: 'ابدأ الإقصاء بعد اكتمال المؤهلين.',
          );
        }
        final tiesByRound = <int, List<KnockoutTie>>{};
        final matchById = {
          for (final fixture in controller.knockoutFixtures)
            fixture.id: fixture,
        };
        for (final tie in controller.knockoutTies) {
          tiesByRound
              .putIfAbsent(tie.roundIndex, () => <KnockoutTie>[])
              .add(tie);
        }
        final sortedRounds = tiesByRound.keys.toList(growable: true)..sort();
        final finalRoundIndex = sortedRounds.isEmpty ? 0 : sortedRounds.last;
        final finalTie = tiesByRound[finalRoundIndex]?.firstOrNull;

        return ListView(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ملخص الإقصاء',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text('Format: Single Elimination'),
                    Text(
                      'Qualifiers: ${bracket.qualifierParticipantIds.length}',
                    ),
                    Text(
                      bracket.championParticipantId == null
                          ? 'البطل لم يتحدد بعد'
                          : 'البطل: ${controller.participantLabelFor(bracket.championParticipantId)}',
                    ),
                  ],
                ),
              ),
            ),
            if (finalTie != null) ...[
              const SizedBox(height: 12),
              _KnockoutFinalSummaryCard(
                tie: finalTie,
                match: finalTie.matchId == null
                    ? null
                    : matchById[finalTie.matchId!],
                controller: controller,
              ),
            ],
            const SizedBox(height: 12),
            ...sortedRounds.expand(
              (roundIndex) => <Widget>[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _knockoutRoundLabel(
                      roundIndex,
                      maxRoundIndex: finalRoundIndex,
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ...tiesByRound[roundIndex]!.map(
                  (tie) => _KnockoutTieCard(
                    tie: tie,
                    match: tie.matchId == null ? null : matchById[tie.matchId!],
                    controller: controller,
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ],
        );
      }),
    );
  }
}

class _KnockoutFinalSummaryCard extends StatelessWidget {
  final KnockoutTie tie;
  final Match? match;
  final TournamentOperationsController controller;

  const _KnockoutFinalSummaryCard({
    required this.tie,
    required this.match,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFF8F4E8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ملخص النهائي',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '${controller.participantLabelFor(tie.participantAId)} vs ${controller.participantLabelFor(tie.participantBId)}',
            ),
            const SizedBox(height: 4),
            Text(
              tie.winnerParticipantId == null
                  ? 'لم يُحسم النهائي بعد.'
                  : 'الفائز الحالي: ${controller.participantLabelFor(tie.winnerParticipantId)}',
            ),
            if (match != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetricChip(label: 'Score', value: _matchScoreLabel(match)),
                  _MetricChip(
                    label: 'Status',
                    value: _matchStatusLabel(match!.status),
                  ),
                  _MetricChip(
                    label: 'Schedule',
                    value: _formatDateTime(match!.scheduledAt),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        Get.toNamed(AppRoutes.matchDetailsById(match!.id)),
                    icon: const Icon(Icons.sports_soccer),
                    label: const Text('Matchday'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _scoreActionForMatch(controller, match!),
                    icon: Icon(_scoreActionIcon(match!)),
                    label: Text(_scoreActionLabel(match!)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _KnockoutTieCard extends StatelessWidget {
  final KnockoutTie tie;
  final Match? match;
  final TournamentOperationsController controller;

  const _KnockoutTieCard({
    required this.tie,
    required this.match,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${controller.participantLabelFor(tie.participantAId)} vs ${controller.participantLabelFor(tie.participantBId)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Slot ${tie.slotNumber + 1}${tie.nextTieId == null ? '' : ' • الفائز يتقدم للمرحلة التالية'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: tie.winnerParticipantId == null
                        ? const Color(0xFFF4F4F4)
                        : const Color(0xFFE7F7ED),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    tie.winnerParticipantId == null ? 'Pending' : 'Winner Set',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricChip(label: 'Ready', value: tie.isReady ? 'Yes' : 'No'),
                if (match != null)
                  _MetricChip(label: 'Score', value: _matchScoreLabel(match)),
                if (match != null)
                  _MetricChip(
                    label: 'Status',
                    value: _matchStatusLabel(match!.status),
                  ),
                if (match != null)
                  _MetricChip(
                    label: 'Schedule',
                    value: _formatDateTime(match!.scheduledAt),
                  ),
              ],
            ),
            if (tie.winnerParticipantId != null) ...[
              const SizedBox(height: 12),
              Text(
                'الفائز: ${controller.participantLabelFor(tie.winnerParticipantId)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (match != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        Get.toNamed(AppRoutes.matchDetailsById(match!.id)),
                    icon: const Icon(Icons.sports_soccer),
                    label: const Text('Matchday'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _scoreActionForMatch(controller, match!),
                    icon: Icon(_scoreActionIcon(match!)),
                    label: Text(_scoreActionLabel(match!)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScaffoldListScreen extends StatelessWidget {
  final String title;
  final Widget child;

  const _ScaffoldListScreen({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  final String title;
  final String message;

  const _StateMessage({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetricChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value'),
      visualDensity: VisualDensity.compact,
    );
  }
}

VoidCallback? _scoreActionForMatch(
  TournamentOperationsController controller,
  Match match,
) {
  if (controller.isActing.value) {
    return null;
  }
  return switch (match.status) {
    MatchStatus.live => () => Get.toNamed(
      AppRoutes.scoreApprovalForMatch(match.id),
    ),
    MatchStatus.completed ||
    MatchStatus.pendingReview => () => controller.approveFixtureScore(match.id),
    MatchStatus.settled => null,
    _ => null,
  };
}

String _scoreActionLabel(Match match) => switch (match.status) {
  MatchStatus.live => 'Submit Score',
  MatchStatus.completed => 'Approve Score',
  MatchStatus.pendingReview => 'Review & Approve',
  MatchStatus.settled => 'Approved',
  _ => 'Score Review',
};

IconData _scoreActionIcon(Match match) => switch (match.status) {
  MatchStatus.live => Icons.edit_note,
  MatchStatus.completed || MatchStatus.pendingReview => Icons.verified_outlined,
  MatchStatus.settled => Icons.check_circle_outline,
  _ => Icons.rule_folder_outlined,
};

String _knockoutRoundLabel(int roundIndex, {required int maxRoundIndex}) {
  final distanceFromFinal = maxRoundIndex - roundIndex;
  return switch (distanceFromFinal) {
    0 => 'النهائي',
    1 => 'نصف النهائي',
    2 => 'ربع النهائي',
    _ => 'Round ${roundIndex + 1}',
  };
}

String _matchStatusLabel(MatchStatus status) => switch (status) {
  MatchStatus.open => 'Open',
  MatchStatus.full => 'Full',
  MatchStatus.live => 'Live',
  MatchStatus.pendingReview => 'Pending Review',
  MatchStatus.completed => 'Completed',
  MatchStatus.settled => 'Settled',
  MatchStatus.ratingWindow => 'Rating Window',
  MatchStatus.frozen => 'Frozen',
  MatchStatus.cancelled => 'Cancelled',
};

String _formatDateTime(DateTime? value) {
  if (value == null) {
    return 'غير محدد';
  }
  return intl.DateFormat('yyyy/MM/dd – HH:mm').format(value);
}

String _matchScoreLabel(Match? match) {
  if (match == null || match.scoreTeamA == null || match.scoreTeamB == null) {
    return '-';
  }
  return '${match.scoreTeamA} - ${match.scoreTeamB}';
}

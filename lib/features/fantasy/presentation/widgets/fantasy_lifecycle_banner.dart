import 'package:flutter/material.dart';

import '../../../../core/enums/fantasy_league_phase.dart';
import '../../../../domain/entities/fantasy_league_lifecycle.dart';

class FantasyLifecycleBanner extends StatelessWidget {
  final FantasyLeagueLifecycle? lifecycle;

  const FantasyLifecycleBanner({
    super.key,
    required this.lifecycle,
  });

  @override
  Widget build(BuildContext context) {
    final state = lifecycle;
    if (state == null) {
      return const SizedBox.shrink();
    }

    final accentColor = _accentColor(state);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _phaseLabel(state.phase),
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _Chip(
                label: 'GW ${state.currentGameweek}',
                color: accentColor,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _statusMessage(state),
            style: const TextStyle(color: Colors.white70, height: 1.5),
          ),
          if (state.deadlineAt != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Chip(
                  label: state.isLocked ? 'Locked' : 'Open',
                  color: accentColor,
                ),
                _Chip(
                  label: 'الموعد: ${_formatDate(state.deadlineAt!)}',
                  color: Colors.white54,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _phaseLabel(FantasyLeaguePhase phase) {
    return switch (phase) {
      FantasyLeaguePhase.upcoming => 'الدوري لم يبدأ بعد',
      FantasyLeaguePhase.draft => 'مرحلة بناء التشكيلة',
      FantasyLeaguePhase.live => 'الجولة جارية',
      FantasyLeaguePhase.transferWindow => 'نافذة الانتقالات مفتوحة',
      FantasyLeaguePhase.locked => 'الجولة مغلقة',
      FantasyLeaguePhase.settled => 'الجولة تم اعتمادها',
      FantasyLeaguePhase.completed => 'الدوري انتهى',
      FantasyLeaguePhase.cancelled => 'الدوري ملغي',
    };
  }

  String _statusMessage(FantasyLeagueLifecycle lifecycle) {
    if (lifecycle.phase == FantasyLeaguePhase.transferWindow) {
      return 'يمكنك تنفيذ الانتقالات حالياً قبل انطلاق الجولة التالية.';
    }
    if (lifecycle.isSettled) {
      return 'تم احتساب واعتماد نتائج هذه الجولة، ويمكنك مراجعة النقاط والترتيب.';
    }
    if (lifecycle.isLocked) {
      return 'الجولة مغلقة حالياً، لذلك التعديلات المباشرة على التشكيلة والانتقالات متوقفة.';
    }
    if (lifecycle.allowsDraftEdits) {
      return 'التشكيلة ما زالت قابلة للتعديل قبل موعد الإغلاق.';
    }
    return 'الدوري في حالة نشطة حالياً، راقب الموعد النهائي وحالة الجولة قبل أي تعديل.';
  }

  Color _accentColor(FantasyLeagueLifecycle lifecycle) {
    if (lifecycle.phase == FantasyLeaguePhase.transferWindow) {
      return const Color(0xFF22C55E);
    }
    if (lifecycle.isLocked || lifecycle.isSettled) {
      return const Color(0xFFF59E0B);
    }
    return const Color(0xFF38BDF8);
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

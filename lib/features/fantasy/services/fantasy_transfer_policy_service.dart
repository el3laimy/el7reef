import '../../../domain/entities/fantasy_chip.dart';
import '../../../domain/entities/fantasy_league_lifecycle.dart';
import '../../../domain/entities/fantasy_team.dart';
import '../../../core/enums/fantasy_league_phase.dart';

class FreeTransferSyncResult {
  final FantasyTeam team;
  final bool changed;
  final int roundsAdvanced;
  final bool migratedLegacyTracking;

  const FreeTransferSyncResult({
    required this.team,
    required this.changed,
    required this.roundsAdvanced,
    this.migratedLegacyTracking = false,
  });
}

class TransferPolicyDecision {
  final bool isAllowed;
  final String policyPhase;
  final FantasyLeaguePhase lifecyclePhase;
  final String? blockedReason;
  final bool usedFreeTransfer;
  final bool hitApplied;
  final bool wildcardApplied;
  final int freeTransfersBefore;
  final int freeTransfersAfter;
  final int pointsDelta;

  const TransferPolicyDecision({
    required this.isAllowed,
    required this.policyPhase,
    required this.lifecyclePhase,
    this.blockedReason,
    this.usedFreeTransfer = false,
    this.hitApplied = false,
    this.wildcardApplied = false,
    this.freeTransfersBefore = 0,
    this.freeTransfersAfter = 0,
    this.pointsDelta = 0,
  });

  String get executionLabelAr {
    if (!isAllowed) {
      return blockedReason ?? 'الانتقالات غير متاحة حالياً.';
    }
    if (wildcardApplied) {
      return 'الانتقال مجاني بسبب Wildcard.';
    }
    if (usedFreeTransfer) {
      return 'سيتم استهلاك تبديل مجاني.';
    }
    if (hitApplied) {
      return 'سيتم خصم 4 نقاط لعدم وجود تبديلات مجانية.';
    }
    return 'الانتقال متاح دون خصم إضافي.';
  }
}

/// Applies gameweek-based refill rules for fantasy free transfers.
class FantasyTransferPolicyService {
  final int refillPerGameweek;
  final int maxCarryOverFreeTransfers;
  final Set<FantasyLeaguePhase> globalAllowedTransferPhases;
  final Set<FantasyLeaguePhase> tournamentAllowedTransferPhases;

  const FantasyTransferPolicyService({
    this.refillPerGameweek = 1,
    this.maxCarryOverFreeTransfers = 2,
    this.globalAllowedTransferPhases = const {
      FantasyLeaguePhase.draft,
      FantasyLeaguePhase.transferWindow,
    },
    this.tournamentAllowedTransferPhases = const {
      FantasyLeaguePhase.draft,
      FantasyLeaguePhase.transferWindow,
    },
  });

  FreeTransferSyncResult syncTeamForLifecycle({
    required FantasyTeam team,
    required FantasyLeagueLifecycle lifecycle,
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();
    final targetGameweek = lifecycle.currentGameweek;

    if (targetGameweek <= 0) {
      return FreeTransferSyncResult(
        team: team,
        changed: false,
        roundsAdvanced: 0,
      );
    }

    // Legacy teams may not know which gameweek their current balance belongs to.
    // We align them first without granting catch-up refills unexpectedly.
    if (team.freeTransfersGameweek <= 0) {
      return FreeTransferSyncResult(
        team: team.copyWith(
          freeTransfersGameweek: targetGameweek,
          updatedAt: effectiveNow,
        ),
        changed: true,
        roundsAdvanced: 0,
        migratedLegacyTracking: true,
      );
    }

    if (targetGameweek <= team.freeTransfersGameweek) {
      return FreeTransferSyncResult(
        team: team,
        changed: false,
        roundsAdvanced: 0,
      );
    }

    final roundsAdvanced = targetGameweek - team.freeTransfersGameweek;
    final normalizedFreeTransfers = team.freeTransfers < 0 ? 0 : team.freeTransfers;

    final refreshedFreeTransfers =
        normalizedFreeTransfers > maxCarryOverFreeTransfers
            ? normalizedFreeTransfers
            : (normalizedFreeTransfers + (roundsAdvanced * refillPerGameweek))
                .clamp(0, maxCarryOverFreeTransfers);

    final updatedTeam = team.copyWith(
      freeTransfers: refreshedFreeTransfers,
      freeTransfersGameweek: targetGameweek,
      updatedAt: effectiveNow,
    );

    return FreeTransferSyncResult(
      team: updatedTeam,
      changed: updatedTeam.freeTransfers != team.freeTransfers ||
          updatedTeam.freeTransfersGameweek != team.freeTransfersGameweek,
      roundsAdvanced: roundsAdvanced,
    );
  }

  TransferPolicyDecision evaluateTransfer({
    required FantasyTeam team,
    required FantasyLeagueLifecycle lifecycle,
  }) {
    final policyPhase = buildPolicyPhase(lifecycle);
    final freeTransfersBefore = team.freeTransfers < 0 ? 0 : team.freeTransfers;
    final wildcardApplied = _isWildcardActive(team, lifecycle.currentGameweek);

    if (lifecycle.isLocked) {
      return TransferPolicyDecision(
        isAllowed: false,
        policyPhase: policyPhase,
        lifecyclePhase: lifecycle.phase,
        blockedReason: _blockedReasonForLifecycle(lifecycle),
        freeTransfersBefore: freeTransfersBefore,
        freeTransfersAfter: freeTransfersBefore,
      );
    }

    final allowedPhases = lifecycle.isGlobal
        ? globalAllowedTransferPhases
        : tournamentAllowedTransferPhases;
    if (!allowedPhases.contains(lifecycle.phase)) {
      return TransferPolicyDecision(
        isAllowed: false,
        policyPhase: policyPhase,
        lifecyclePhase: lifecycle.phase,
        blockedReason: _blockedReasonForLifecycle(lifecycle),
        freeTransfersBefore: freeTransfersBefore,
        freeTransfersAfter: freeTransfersBefore,
      );
    }

    if (freeTransfersBefore > 0) {
      return TransferPolicyDecision(
        isAllowed: true,
        policyPhase: policyPhase,
        lifecyclePhase: lifecycle.phase,
        usedFreeTransfer: true,
        freeTransfersBefore: freeTransfersBefore,
        freeTransfersAfter: freeTransfersBefore - 1,
      );
    }

    if (wildcardApplied) {
      return TransferPolicyDecision(
        isAllowed: true,
        policyPhase: policyPhase,
        lifecyclePhase: lifecycle.phase,
        wildcardApplied: true,
        freeTransfersBefore: freeTransfersBefore,
        freeTransfersAfter: freeTransfersBefore,
      );
    }

    return TransferPolicyDecision(
      isAllowed: true,
      policyPhase: policyPhase,
      lifecyclePhase: lifecycle.phase,
      hitApplied: true,
      freeTransfersBefore: freeTransfersBefore,
      freeTransfersAfter: freeTransfersBefore,
      pointsDelta: -4,
    );
  }

  String buildPolicyPhase(FantasyLeagueLifecycle lifecycle) {
    final scope = lifecycle.isGlobal ? 'global' : 'tournament';
    return '${scope}_${lifecycle.phase.name}';
  }

  String describePolicyPhase(String policyPhase) {
    switch (policyPhase) {
      case 'global_draft':
        return 'دوري عام - بناء/تعديل';
      case 'global_transferWindow':
        return 'دوري عام - نافذة انتقالات';
      case 'global_live':
        return 'دوري عام - الجولة مباشرة';
      case 'global_locked':
        return 'دوري عام - مغلق';
      case 'global_settled':
        return 'دوري عام - بانتظار الجولة التالية';
      case 'tournament_draft':
        return 'بطولة - مرحلة التسجيل';
      case 'tournament_transferWindow':
        return 'بطولة - نافذة انتقالات';
      case 'tournament_live':
        return 'بطولة - الجولة جارية';
      case 'tournament_locked':
        return 'بطولة - مغلقة';
      case 'tournament_settled':
        return 'بطولة - جولة منتهية';
      case 'tournament_completed':
        return 'بطولة - مكتملة';
      case 'tournament_cancelled':
        return 'بطولة - ملغاة';
      default:
        return policyPhase;
    }
  }

  String _blockedReasonForLifecycle(FantasyLeagueLifecycle lifecycle) {
    switch (lifecycle.phase) {
      case FantasyLeaguePhase.upcoming:
        return 'سوق الانتقالات لم يفتح بعد لهذه الجولة.';
      case FantasyLeaguePhase.draft:
      case FantasyLeaguePhase.transferWindow:
        return 'سوق الانتقالات مغلق حالياً لهذه الجولة.';
      case FantasyLeaguePhase.live:
        return 'الانتقالات متوقفة أثناء لعب الجولة الحالية.';
      case FantasyLeaguePhase.locked:
        return 'الجولة مغلقة حالياً ولا يمكن تنفيذ انتقالات.';
      case FantasyLeaguePhase.settled:
        return 'تمت تسوية هذه الجولة. انتظر فتح الجولة التالية.';
      case FantasyLeaguePhase.completed:
        return 'انتهى هذا الدوري ولا يمكن تنفيذ انتقالات جديدة.';
      case FantasyLeaguePhase.cancelled:
        return 'تم إلغاء هذا الدوري ولا يمكن تنفيذ انتقالات.';
    }
  }

  bool _isWildcardActive(FantasyTeam team, int currentGameweek) {
    return team.hasActiveChip(
          ChipType.wildcardGroups,
          gameweek: currentGameweek,
        ) ||
        team.hasActiveChip(
          ChipType.wildcardKnockout,
          gameweek: currentGameweek,
        );
  }
}

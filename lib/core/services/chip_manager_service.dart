import '../../domain/entities/fantasy_chip.dart';
import '../../domain/entities/fantasy_league_lifecycle.dart';
import '../../domain/entities/fantasy_team.dart';

/// خدمة إدارة الخواص (Chips Manager) لفرض قوانين قياسية وصارمة على نظام الدعم الفني
class ChipManagerService {
  const ChipManagerService();

  String? getUnavailableReason({
    required FantasyTeam currentTeam,
    required ChipType targetChip,
    required FantasyLeagueLifecycle lifecycle,
  }) {
    if (lifecycle.isLocked) {
      return 'الجولة مغلقة حالياً، لذلك لا يمكن تفعيل أي خاصية الآن.';
    }

    if (!lifecycle.allowsTransfers && !lifecycle.allowsDraftEdits) {
      return 'هذه المرحلة لا تسمح بتفعيل الخواص حالياً.';
    }

    if (currentTeam.activeChipsForGameweek(lifecycle.currentGameweek).isNotEmpty) {
      return 'يمكن تفعيل خاصية واحدة فقط في الجولة نفسها.';
    }

    if (targetChip != ChipType.emergencySub &&
        currentTeam.hasConsumedChip(targetChip)) {
      return 'لقد قمت باستخدام ${targetChip.displayName} مسبقاً، وهي متاحة مرة واحدة فقط.';
    }

    return null;
  }

  /// محاولة تفعيل خاصية (Chip) جديدة وإرجاع نسخة محدثة من الفريق
  ///
  /// يرمي `Exception` في حال:
  /// - وجود خاصية أخرى مفعلة في نفس الجولة.
  /// - إذا تم استخدام هذه الخاصية مسبقاً طوال عمر البطولة (عدا الاضطراري).
  FantasyTeam activateChip({
    required FantasyTeam currentTeam,
    required ChipType targetChip,
    required FantasyLeagueLifecycle lifecycle,
    DateTime? now,
  }) {
    final blockReason = getUnavailableReason(
      currentTeam: currentTeam,
      targetChip: targetChip,
      lifecycle: lifecycle,
    );
    if (blockReason != null) {
      throw Exception(blockReason);
    }

    final activatedAt = now ?? DateTime.now();
    final updatedUsages = List<ChipUsage>.from(currentTeam.chipUsages)
      ..add(
        ChipUsage(
          chipType: targetChip,
          gameweek: lifecycle.currentGameweek,
          activatedAt: activatedAt,
        ),
      );

    return currentTeam.copyWith(
      chipUsages: updatedUsages,
      updatedAt: activatedAt,
    );
  }

  bool canActivateChip({
    required FantasyTeam currentTeam,
    required ChipType targetChip,
    required FantasyLeagueLifecycle lifecycle,
  }) {
    return getUnavailableReason(
          currentTeam: currentTeam,
          targetChip: targetChip,
          lifecycle: lifecycle,
        ) ==
        null;
  }

  /// أداة للتحقق السريع في واجهة المستخدم إذا كانت الخاصية استُهلكت ليتم تعطيل الزر (Greyed Out)
  static bool isChipExhausted(ChipType chip, FantasyTeam currentTeam) {
    if (chip == ChipType.emergencySub) {
      return false;
    }

    return currentTeam.hasConsumedChip(chip);
  }
}

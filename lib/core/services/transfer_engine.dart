import 'package:uuid/uuid.dart';

import '../../domain/entities/fantasy_league_lifecycle.dart';
import '../../domain/entities/fantasy_team.dart';
import '../../domain/entities/fantasy_slot.dart';
import '../../domain/entities/player_fantasy_value.dart';
import '../../domain/entities/transfer_record.dart';
import '../../domain/repositories/fantasy_repository.dart';
import 'fantasy_transfer_policy_service.dart';
import 'tier_system_engine.dart';

/// محرك الانتقالات (الميركاتو) الخاص بالفانتازي
/// مسؤول عن التحقق من قوانين التبديلات (الميزانية، الندرة، التكلفة) وإتمامها
class TransferEngine {
  final FantasyRepository _repository;
  final FantasyTransferPolicyService _transferPolicyService;
  final Uuid _uuid = const Uuid();

  TransferEngine(
    this._repository, {
    FantasyTransferPolicyService? transferPolicyService,
  }) : _transferPolicyService =
            transferPolicyService ?? const FantasyTransferPolicyService();

  /// تنفيذ عملية شراء وبيع لاعب مع التحقق التام من جميع القوانين المطبقة
  ///
  /// يرمي `Exception` في حال وجود خرق لأي قانون كالآتي:
  /// - نقص الميزانية.
  /// - خرق نظام المستويات (Tier).
  Future<void> executeTransfer({
    required FantasyTeam currentTeam,
    required FantasyLeagueLifecycle lifecycle,
    required FantasySlot slotToReplace,
    required PlayerFantasyValue playerOutValue,
    required PlayerFantasyValue playerInValue,
    required List<PlayerFantasyValue> fullTeamValues,
  }) async {
    final policyDecision = _transferPolicyService.evaluateTransfer(
      team: currentTeam,
      lifecycle: lifecycle,
    );
    if (!policyDecision.isAllowed) {
      throw Exception(policyDecision.blockedReason ?? 'الانتقالات غير متاحة حالياً.');
    }

    // 1. حساب الميزانية المتاحة للمدرب بعد البيع
    // המيزانية الحالية + سعر بيع اللاعب الحالي
    final double virtualBudget = currentTeam.budget + playerOutValue.currentPrice;

    // 2. التحقق من القدرة المالية لشراء اللاعب الجديد
    if (virtualBudget < playerInValue.currentPrice) {
      throw Exception('عذراً، الميزانية لا تكفي لإتمام هذه الصفقة.');
    }

    // 3. تجهيز قائمة التقييمات الافتراضية للتحقق من قوانين الندرة (Tiers)
    final List<PlayerFantasyValue> virtualTeamTiers = List.from(fullTeamValues);
    virtualTeamTiers.removeWhere((p) => p.playerId == playerOutValue.playerId);
    virtualTeamTiers.add(playerInValue);

    // 4. التحقق من أن التشكيلة لن تخرق قوانين (Gold / Silver)
    final String? tierValidationError = TierSystemEngine.validateTeamTiers(virtualTeamTiers);
    if (tierValidationError != null) {
      throw Exception(tierValidationError);
    }

    // 5. تطبيق قرار السياسة بعد التحقق من التشكيلة والميزانية.
    final transferCost = policyDecision.pointsDelta;
    final newFreeTransfers = policyDecision.freeTransfersAfter;

    // 6. تجهيز كيان الفريق الجديد بالبيانات المالية المحدثة
    final double updatedBudget = double.parse((virtualBudget - playerInValue.currentPrice).toStringAsFixed(1));
    
    final FantasyTeam updatedTeam = currentTeam.copyWith(
      budget: updatedBudget,
      freeTransfers: newFreeTransfers,
      totalTransfers: currentTeam.totalTransfers + 1,
      // يتم خصم النقاط فوراً من إجمالي نقاط الفريق (Hit)
      totalPoints: currentTeam.totalPoints + transferCost,
    );

    // 7. تحديث خانة اللاعب
    final FantasySlot updatedSlot = slotToReplace.copyWith(
      playerId: playerInValue.playerId,
      // تتصفير النقاط التي جلبها اللاعب السابق لهذه الخانة ليبدأ الجديد من الصفر
      pointsEarned: 0, 
    );

    // 8. صياغة أرشيف التبديل لتوثيقه
    final TransferRecord record = TransferRecord(
      id: _uuid.v4(),
      fantasyTeamId: updatedTeam.id,
      playerOutId: playerOutValue.playerId,
      playerInId: playerInValue.playerId,
      gameweek: lifecycle.currentGameweek,
      cost: transferCost,
      usedFreeTransfer: policyDecision.usedFreeTransfer,
      hitApplied: policyDecision.hitApplied,
      wildcardApplied: policyDecision.wildcardApplied,
      policyPhase: policyDecision.policyPhase,
      timestamp: DateTime.now(),
    );

    // 9. تنفيذ العملية بأمان وبشكل ذري (Transaction) عبر المستودع
    await _repository.processTransfer(
      updatedTeam,
      record,
      [updatedSlot], // نمرر الخانة المحدثة
    );
  }
}

/// سجل التبديلات (Transfers) الخاصة بفريق الفانتازي
class TransferRecord {
  /// المعرف الفريد لعملية التبديل
  final String id;
  
  /// معرف فريق الفانتازي الذي قام بالتبديل
  final String fantasyTeamId;
  
  /// اللاعب الذي تم إخراجه من التشكيلة (تم بيعه)
  final String playerOutId;
  
  /// اللاعب الذي تم إدخاله للتشكيلة (تم شراؤه)
  final String playerInId;
  
  /// جولة التبديل (رقم الأسبوع أو الجولة الحالية)
  final int gameweek;
  
  /// تكلفة التبديل بالنقاط (0 إذا كان مجانياً، -4 إذا كان تبديلاً إضافياً)
  final int cost;

  /// هل استهلك هذا الانتقال تبديلًا مجانيًا من الرصيد الحالي.
  final bool usedFreeTransfer;

  /// هل فُرضت عقوبة نقاط على هذا الانتقال.
  final bool hitApplied;

  /// هل تمت حماية الانتقال بواسطة Wildcard نشطة.
  final bool wildcardApplied;

  /// المرحلة السياسية/التشغيلية التي سُمح فيها بالانتقال.
  final String policyPhase;

  /// سبب المنع إن وُجد. يكون `null` للانتقالات الناجحة المحفوظة فعليًا.
  final String? blockedReason;
  
  /// وقت إتمام التبديل
  final DateTime timestamp;

  const TransferRecord({
    required this.id,
    required this.fantasyTeamId,
    required this.playerOutId,
    required this.playerInId,
    required this.gameweek,
    required this.cost,
    this.usedFreeTransfer = false,
    this.hitApplied = false,
    this.wildcardApplied = false,
    this.policyPhase = 'unknown',
    this.blockedReason,
    required this.timestamp,
  });

  TransferRecord copyWith({
    String? id,
    String? fantasyTeamId,
    String? playerOutId,
    String? playerInId,
    int? gameweek,
    int? cost,
    bool? usedFreeTransfer,
    bool? hitApplied,
    bool? wildcardApplied,
    String? policyPhase,
    String? blockedReason,
    bool clearBlockedReason = false,
    DateTime? timestamp,
  }) {
    return TransferRecord(
      id: id ?? this.id,
      fantasyTeamId: fantasyTeamId ?? this.fantasyTeamId,
      playerOutId: playerOutId ?? this.playerOutId,
      playerInId: playerInId ?? this.playerInId,
      gameweek: gameweek ?? this.gameweek,
      cost: cost ?? this.cost,
      usedFreeTransfer: usedFreeTransfer ?? this.usedFreeTransfer,
      hitApplied: hitApplied ?? this.hitApplied,
      wildcardApplied: wildcardApplied ?? this.wildcardApplied,
      policyPhase: policyPhase ?? this.policyPhase,
      blockedReason:
          clearBlockedReason ? null : blockedReason ?? this.blockedReason,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

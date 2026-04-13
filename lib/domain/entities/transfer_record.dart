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
  
  /// وقت إتمام التبديل
  final DateTime timestamp;

  const TransferRecord({
    required this.id,
    required this.fantasyTeamId,
    required this.playerOutId,
    required this.playerInId,
    required this.gameweek,
    required this.cost,
    required this.timestamp,
  });

  TransferRecord copyWith({
    String? id,
    String? fantasyTeamId,
    String? playerOutId,
    String? playerInId,
    int? gameweek,
    int? cost,
    DateTime? timestamp,
  }) {
    return TransferRecord(
      id: id ?? this.id,
      fantasyTeamId: fantasyTeamId ?? this.fantasyTeamId,
      playerOutId: playerOutId ?? this.playerOutId,
      playerInId: playerInId ?? this.playerInId,
      gameweek: gameweek ?? this.gameweek,
      cost: cost ?? this.cost,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

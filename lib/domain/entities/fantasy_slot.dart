/// دور اللاعب المختار في تشكيلة الفانتازي
enum FantasyPlayerRole {
  /// لاعب عادي
  none,
  /// كابتن (تتضاعف نقاطه)
  captain,
  /// نائب الكابتن (تتضاعف نقاطه لو الكابتن لم يلعب)
  viceCaptain,
}

/// يمثل خانة أو مركزاً محدداً داخل تشكيلة الفانتازي الخاصة بالمستخدم
class FantasySlot {
  /// المعرف الفريد لهذه الخانة 
  final String id;
  
  /// معرف فريق الفانتازي الذي تنتمي له هذه الخانة
  final String fantasyTeamId;
  
  /// اللاعب الذي تم إدراجه في هذه الخانة
  final String playerId;
  
  /// هل اللاعب أساسي أم احتياطي؟
  final bool isStartingXI;
  
  /// ترتيب نزول اللاعب من على الدكة (مثلاً: 1 يعني البديل الأول، 2 الثاني..)
  /// القيمة 0 تعني أن اللاعب أساسي
  final int benchPriority;
  
  /// هل اللاعب تم إقصاؤه نهائياً من البطولة (ومطلوب تغييره إجبارياً)؟
  final bool isEliminated;
  
  /// هل اللاعب كابتن أو نائب كابتن؟
  final FantasyPlayerRole role;
  
  /// إجمالي النقاط التي حصدها اللاعب خصيصاً وهو داخل هذه الخانة
  final int pointsEarned;

  const FantasySlot({
    required this.id,
    required this.fantasyTeamId,
    required this.playerId,
    required this.isStartingXI,
    this.benchPriority = 0,
    this.isEliminated = false,
    this.role = FantasyPlayerRole.none,
    this.pointsEarned = 0,
  });

  FantasySlot copyWith({
    String? id,
    String? fantasyTeamId,
    String? playerId,
    bool? isStartingXI,
    int? benchPriority,
    bool? isEliminated,
    FantasyPlayerRole? role,
    int? pointsEarned,
  }) {
    return FantasySlot(
      id: id ?? this.id,
      fantasyTeamId: fantasyTeamId ?? this.fantasyTeamId,
      playerId: playerId ?? this.playerId,
      isStartingXI: isStartingXI ?? this.isStartingXI,
      benchPriority: benchPriority ?? this.benchPriority,
      isEliminated: isEliminated ?? this.isEliminated,
      role: role ?? this.role,
      pointsEarned: pointsEarned ?? this.pointsEarned,
    );
  }
}

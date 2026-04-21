/// كيان جلسة تصويت الجماهير (Fan Voting)
/// يتيح للجماهير التصويت على لقب "رجل المباراة" (MOM) بشكل مستقل عن اختيار المنظم
class FanVotingSession {
  /// المعرف الفريد للجلسة (غالباً هو نفسه معرف المباراة)
  final String id;

  /// معرف المباراة السارية
  final String matchId;

  /// متى يفتح باب التصويت للجماهير
  final DateTime opensAt;

  /// متى يغلق الباب (مثلاً 90 دقيقة من بدايتها)
  final DateTime closesAt;

  /// إجمالي عدد الأصوات التي تم استقبالها في هذا التصويت
  final int totalVotes;

  /// قاموس يربط معرف اللاعب بعدد الأصوات التي تلقاها {playerId: votesCount}
  final Map<String, int> playerVotes;

  /// قائمة اللاعبين الرسميين المؤهلين للتصويت في هذه المباراة.
  final List<String> eligiblePlayerIds;

  /// الفائز بتصويت الجماهير بعد إغلاق الجلسة
  final String? winnerPlayerId;

  const FanVotingSession({
    required this.id,
    required this.matchId,
    required this.opensAt,
    required this.closesAt,
    this.totalVotes = 0,
    this.playerVotes = const {},
    this.eligiblePlayerIds = const [],
    this.winnerPlayerId,
  });

  /// تحقق مما إذا كان باب التصويت مفتوحاً في الوقت الحالي للجمهور
  bool get isOpen {
    final now = DateTime.now();
    return now.isAfter(opensAt) && now.isBefore(closesAt);
  }

  /// تحقق من غلق باب التصويت
  bool get isClosed {
    return DateTime.now().isAfter(closesAt);
  }

  FanVotingSession copyWith({
    String? id,
    String? matchId,
    DateTime? opensAt,
    DateTime? closesAt,
    int? totalVotes,
    Map<String, int>? playerVotes,
    List<String>? eligiblePlayerIds,
    String? winnerPlayerId,
  }) {
    return FanVotingSession(
      id: id ?? this.id,
      matchId: matchId ?? this.matchId,
      opensAt: opensAt ?? this.opensAt,
      closesAt: closesAt ?? this.closesAt,
      totalVotes: totalVotes ?? this.totalVotes,
      playerVotes: playerVotes ?? this.playerVotes,
      eligiblePlayerIds: eligiblePlayerIds ?? this.eligiblePlayerIds,
      winnerPlayerId: winnerPlayerId ?? this.winnerPlayerId,
    );
  }
}

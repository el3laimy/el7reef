/// مركز اللاعب الذي أثر على طريقة حساب نقاط الفانتازي في هذه المباراة
enum MatchPosition {
  goalkeeper,
  defender,
  midfielder,
  forward,
  mixed // في حالة لعب في أكثر من مركز ولا يمكن تحديده بشكل واضح
}

/// إحصائيات اللاعب في مباراة واحدة
/// تُستخدم لاحقاً كأساس متين لحساب نقاط الفانتازي أو التقييمات الشخصية
class PlayerMatchStats {
  /// معرف اللاعب
  final String playerId;
  
  /// معرف المباراة السارية
  final String matchId;
  
  /// معرف الفريق الذي مثله اللاعب في هذه المباراة
  final String teamId;

  /// هل شارك اللاعب فعلياً في هذه المباراة؟
  final bool played;
  
  /// المركز الذي لعبه (ضروري لحساب فوارق النقاط كمثال: هدف الحارس بـ 12 نقطة)
  final MatchPosition position;

  /// إحصاءات أساسية
  final int goals;
  final int assists;
  final int saves; // مهمات حراس المرمى بشكل خاص
  final int tackles;
  
  /// هل خرج فريقه بشباك نظيفة أثناء مشاركته؟
  final bool cleanSheet;
  
  /// هل حصل اللاعب على بطاقة صفراء في المباراة؟
  final bool yellowCard;
  
  /// هل حصل اللاعب على بطاقة حمراء في المباراة؟
  final bool redCard;
  
  /// إجمالي تقييم اللاعب في هذه المباراة (0-10) حسب تقييم المنظم التلقائي أو اليدوي
  final double rating;

  const PlayerMatchStats({
    required this.playerId,
    required this.matchId,
    required this.teamId,
    this.played = true,
    this.position = MatchPosition.mixed,
    this.goals = 0,
    this.assists = 0,
    this.saves = 0,
    this.tackles = 0,
    this.cleanSheet = false,
    this.yellowCard = false,
    this.redCard = false,
    this.rating = 0.0,
  });

  PlayerMatchStats copyWith({
    String? playerId,
    String? matchId,
    String? teamId,
    bool? played,
    MatchPosition? position,
    int? goals,
    int? assists,
    int? saves,
    int? tackles,
    bool? cleanSheet,
    bool? yellowCard,
    bool? redCard,
    double? rating,
  }) {
    return PlayerMatchStats(
      playerId: playerId ?? this.playerId,
      matchId: matchId ?? this.matchId,
      teamId: teamId ?? this.teamId,
      played: played ?? this.played,
      position: position ?? this.position,
      goals: goals ?? this.goals,
      assists: assists ?? this.assists,
      saves: saves ?? this.saves,
      tackles: tackles ?? this.tackles,
      cleanSheet: cleanSheet ?? this.cleanSheet,
      yellowCard: yellowCard ?? this.yellowCard,
      redCard: redCard ?? this.redCard,
      rating: rating ?? this.rating,
    );
  }
}

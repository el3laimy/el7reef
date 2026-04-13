import '../../core/enums/match_status.dart';

/// كيان المباراة — قلب نظام التقييم
class Match {
  final String id;
  final String organizerId;
  final String? teamAId;
  final String? teamBId;
  final List<String> teamAPlayerIds;
  final List<String> teamBPlayerIds;
  final MatchStatus status;
  final int? scoreTeamA;
  final int? scoreTeamB;
  final String? mvpPlayerId;
  final String? location;
  final double? latitude;
  final double? longitude;
  final bool isOrganized;      // هل جزء من دورة؟
  final String? tournamentId;
  final bool isGoldenRating;   // منظم فعّل التقييم المميز
  final bool isAnomaly;        // اكتشف كشذوذ
  final bool isFrozen;         // مجمّد من المنظم
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  const Match({
    required this.id,
    required this.organizerId,
    this.teamAId,
    this.teamBId,
    this.teamAPlayerIds = const [],
    this.teamBPlayerIds = const [],
    this.status = MatchStatus.open,
    this.scoreTeamA,
    this.scoreTeamB,
    this.mvpPlayerId,
    this.location,
    this.latitude,
    this.longitude,
    this.isOrganized = false,
    this.tournamentId,
    this.isGoldenRating = false,
    this.isAnomaly = false,
    this.isFrozen = false,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
  });

  /// هل انتهت وعندنا نتيجة؟
  bool get isCompleted =>
      status == MatchStatus.completed ||
      status == MatchStatus.settled ||
      status == MatchStatus.ratingWindow;

  /// هل النتيجة شاذة؟ (مثل 15-0)
  bool get hasAnomalousScore {
    if (scoreTeamA == null || scoreTeamB == null) return false;
    final diff = (scoreTeamA! - scoreTeamB!).abs();
    return scoreTeamA! + scoreTeamB! >= 15 || diff >= 10;
  }

  /// الفائز: A, B, أو draw
  String? get winner {
    if (scoreTeamA == null || scoreTeamB == null) return null;
    if (scoreTeamA! > scoreTeamB!) return 'A';
    if (scoreTeamB! > scoreTeamA!) return 'B';
    return 'draw';
  }

  Match copyWith({
    String? id,
    String? organizerId,
    String? teamAId,
    String? teamBId,
    List<String>? teamAPlayerIds,
    List<String>? teamBPlayerIds,
    MatchStatus? status,
    int? scoreTeamA,
    int? scoreTeamB,
    String? mvpPlayerId,
    String? location,
    double? latitude,
    double? longitude,
    bool? isOrganized,
    String? tournamentId,
    bool? isGoldenRating,
    bool? isAnomaly,
    bool? isFrozen,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return Match(
      id: id ?? this.id,
      organizerId: organizerId ?? this.organizerId,
      teamAId: teamAId ?? this.teamAId,
      teamBId: teamBId ?? this.teamBId,
      teamAPlayerIds: teamAPlayerIds ?? this.teamAPlayerIds,
      teamBPlayerIds: teamBPlayerIds ?? this.teamBPlayerIds,
      status: status ?? this.status,
      scoreTeamA: scoreTeamA ?? this.scoreTeamA,
      scoreTeamB: scoreTeamB ?? this.scoreTeamB,
      mvpPlayerId: mvpPlayerId ?? this.mvpPlayerId,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isOrganized: isOrganized ?? this.isOrganized,
      tournamentId: tournamentId ?? this.tournamentId,
      isGoldenRating: isGoldenRating ?? this.isGoldenRating,
      isAnomaly: isAnomaly ?? this.isAnomaly,
      isFrozen: isFrozen ?? this.isFrozen,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

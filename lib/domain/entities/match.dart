import '../../core/enums/lineup_requirement.dart';
import '../../core/enums/match_status.dart';
import '../../core/enums/tournament_ops_enums.dart';

/// كيان المباراة — قلب نظام التقييم
class Match {
  final String id;
  final String organizerId;
  final String? teamAId;
  final String? teamBId;
  final List<String> teamAPlayerIds;
  final List<String> teamBPlayerIds;
  final String? teamAParticipantId;
  final String? teamBParticipantId;
  final MatchStatus status;
  final int? scoreTeamA;
  final int? scoreTeamB;
  final String? mvpPlayerId;
  final String? location;
  final double? latitude;
  final double? longitude;
  final int teamSize;
  final bool isOrganized; // هل جزء من دورة؟
  final String? tournamentId;
  final bool isGoldenRating; // منظم فعّل التقييم المميز
  final bool isAnomaly; // اكتشف كشذوذ
  final bool isFrozen; // مجمّد من المنظم
  final TournamentStageType? stageType;
  final String? groupId;
  final String? groupStageId;
  final String? knockoutTieId;
  final int? roundIndex;
  final int? slotNumber;
  final DateTime? scheduledAt;
  final DateTime? publishedAt;
  final String? venueId;
  final FixtureStatus fixtureStatus;
  final LineupRequirement lineupRequirement;
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
    this.teamAParticipantId,
    this.teamBParticipantId,
    this.status = MatchStatus.open,
    this.scoreTeamA,
    this.scoreTeamB,
    this.mvpPlayerId,
    this.location,
    this.latitude,
    this.longitude,
    this.teamSize = 5,
    this.isOrganized = false,
    this.tournamentId,
    this.isGoldenRating = false,
    this.isAnomaly = false,
    this.isFrozen = false,
    this.stageType,
    this.groupId,
    this.groupStageId,
    this.knockoutTieId,
    this.roundIndex,
    this.slotNumber,
    this.scheduledAt,
    this.publishedAt,
    this.venueId,
    this.fixtureStatus = FixtureStatus.draft,
    this.lineupRequirement = LineupRequirement.none,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
  });

  /// هل انتهت وعندنا نتيجة؟
  bool get isCompleted =>
      status == MatchStatus.completed ||
      status == MatchStatus.settled ||
      status == MatchStatus.ratingWindow;

  /// نتائج البطولة لا تُحتسب إلا بعد الاعتماد النهائي.
  bool get isOfficialTournamentResult =>
      status == MatchStatus.settled && scoreTeamA != null && scoreTeamB != null;

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
    String? teamAParticipantId,
    String? teamBParticipantId,
    MatchStatus? status,
    int? scoreTeamA,
    int? scoreTeamB,
    String? mvpPlayerId,
    String? location,
    double? latitude,
    double? longitude,
    int? teamSize,
    bool? isOrganized,
    String? tournamentId,
    bool? isGoldenRating,
    bool? isAnomaly,
    bool? isFrozen,
    TournamentStageType? stageType,
    String? groupId,
    String? groupStageId,
    String? knockoutTieId,
    int? roundIndex,
    int? slotNumber,
    DateTime? scheduledAt,
    DateTime? publishedAt,
    String? venueId,
    FixtureStatus? fixtureStatus,
    LineupRequirement? lineupRequirement,
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
      teamAParticipantId: teamAParticipantId ?? this.teamAParticipantId,
      teamBParticipantId: teamBParticipantId ?? this.teamBParticipantId,
      status: status ?? this.status,
      scoreTeamA: scoreTeamA ?? this.scoreTeamA,
      scoreTeamB: scoreTeamB ?? this.scoreTeamB,
      mvpPlayerId: mvpPlayerId ?? this.mvpPlayerId,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      teamSize: teamSize ?? this.teamSize,
      isOrganized: isOrganized ?? this.isOrganized,
      tournamentId: tournamentId ?? this.tournamentId,
      isGoldenRating: isGoldenRating ?? this.isGoldenRating,
      isAnomaly: isAnomaly ?? this.isAnomaly,
      isFrozen: isFrozen ?? this.isFrozen,
      stageType: stageType ?? this.stageType,
      groupId: groupId ?? this.groupId,
      groupStageId: groupStageId ?? this.groupStageId,
      knockoutTieId: knockoutTieId ?? this.knockoutTieId,
      roundIndex: roundIndex ?? this.roundIndex,
      slotNumber: slotNumber ?? this.slotNumber,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      publishedAt: publishedAt ?? this.publishedAt,
      venueId: venueId ?? this.venueId,
      fixtureStatus: fixtureStatus ?? this.fixtureStatus,
      lineupRequirement: lineupRequirement ?? this.lineupRequirement,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

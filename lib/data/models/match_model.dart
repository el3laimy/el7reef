import '../../core/enums/lineup_requirement.dart';
import '../../core/enums/match_status.dart';
import '../../core/enums/tournament_ops_enums.dart';
import '../../core/lineup/formation_library.dart';
import '../../core/utils/app_logger.dart';
import '../../domain/entities/match.dart';

/// نموذج بيانات المباراة — تحويل Firestore
class MatchModel {
  final String id;
  final String organizerId;
  final String? teamAId;
  final String? teamBId;
  final List<String> teamAPlayerIds;
  final List<String> teamBPlayerIds;
  final String? teamAParticipantId;
  final String? teamBParticipantId;
  final String status;
  final int? scoreTeamA;
  final int? scoreTeamB;
  final String? mvpPlayerId;
  final String? location;
  final double? latitude;
  final double? longitude;
  final int teamSize;
  final bool isOrganized;
  final String? tournamentId;
  final String? challengeId;
  final bool isGoldenRating;
  final bool isAnomaly;
  final bool isFrozen;
  final String? stageType;
  final String? groupId;
  final String? groupStageId;
  final String? knockoutTieId;
  final int? roundIndex;
  final int? slotNumber;
  final DateTime? scheduledAt;
  final DateTime? publishedAt;
  final String? venueId;
  final String fixtureStatus;
  final String lineupRequirement;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancelledBy;
  final String? cancelReason;

  const MatchModel({
    required this.id,
    required this.organizerId,
    this.teamAId,
    this.teamBId,
    this.teamAPlayerIds = const [],
    this.teamBPlayerIds = const [],
    this.teamAParticipantId,
    this.teamBParticipantId,
    this.status = 'open',
    this.scoreTeamA,
    this.scoreTeamB,
    this.mvpPlayerId,
    this.location,
    this.latitude,
    this.longitude,
    this.teamSize = 5,
    this.isOrganized = false,
    this.tournamentId,
    this.challengeId,
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
    this.fixtureStatus = 'draft',
    this.lineupRequirement = 'none',
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
    this.cancelledBy,
    this.cancelReason,
  });

  factory MatchModel.fromJson(Map<String, dynamic> json, String docId) {
    final rawTeamSize = (json['teamSize'] as num?)?.toInt();
    final normalizedTeamSize = normalizeMatchTeamSize(rawTeamSize);
    if (rawTeamSize != null && rawTeamSize != normalizedTeamSize) {
      AppLogger.warning(
        'MatchModel.fromJson',
        'Invalid teamSize "$rawTeamSize" for match "$docId"; falling back to $normalizedTeamSize.',
      );
    }
    return MatchModel(
      id: docId,
      organizerId: json['organizerId'] as String? ?? '',
      teamAId: json['teamAId'] as String?,
      teamBId: json['teamBId'] as String?,
      teamAPlayerIds:
          (json['teamAPlayerIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      teamBPlayerIds:
          (json['teamBPlayerIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      teamAParticipantId: json['teamAParticipantId'] as String?,
      teamBParticipantId: json['teamBParticipantId'] as String?,
      status: json['status'] as String? ?? 'open',
      scoreTeamA: (json['scoreTeamA'] as num?)?.toInt(),
      scoreTeamB: (json['scoreTeamB'] as num?)?.toInt(),
      mvpPlayerId: json['mvpPlayerId'] as String?,
      location: json['location'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      teamSize: normalizedTeamSize,
      isOrganized: json['isOrganized'] as bool? ?? false,
      tournamentId: json['tournamentId'] as String?,
      challengeId: json['challengeId'] as String?,
      isGoldenRating: json['isGoldenRating'] as bool? ?? false,
      isAnomaly: json['isAnomaly'] as bool? ?? false,
      isFrozen: json['isFrozen'] as bool? ?? false,
      stageType: json['stageType'] as String?,
      groupId: json['groupId'] as String?,
      groupStageId: json['groupStageId'] as String?,
      knockoutTieId: json['knockoutTieId'] as String?,
      roundIndex: (json['roundIndex'] as num?)?.toInt(),
      slotNumber: (json['slotNumber'] as num?)?.toInt(),
      scheduledAt: json['scheduledAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['scheduledAt'] as num).toInt(),
            )
          : null,
      publishedAt: json['publishedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['publishedAt'] as num).toInt(),
            )
          : null,
      venueId: json['venueId'] as String?,
      fixtureStatus:
          json['fixtureStatus'] as String? ?? FixtureStatus.draft.name,
      lineupRequirement: json['lineupRequirement'] as String? ?? 'none',
      createdAt: json['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['createdAt'] as num).toInt(),
            )
          : DateTime.now(),
      startedAt: json['startedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['startedAt'] as num).toInt(),
            )
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['completedAt'] as num).toInt(),
            )
          : null,
      cancelledAt: json['cancelledAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['cancelledAt'] as num).toInt(),
            )
          : null,
      cancelledBy: json['cancelledBy'] as String?,
      cancelReason: json['cancelReason'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'organizerId': organizerId,
    'teamAId': teamAId,
    'teamBId': teamBId,
    'teamAPlayerIds': teamAPlayerIds,
    'teamBPlayerIds': teamBPlayerIds,
    'teamAParticipantId': teamAParticipantId,
    'teamBParticipantId': teamBParticipantId,
    'status': status,
    'scoreTeamA': scoreTeamA,
    'scoreTeamB': scoreTeamB,
    'mvpPlayerId': mvpPlayerId,
    'location': location,
    'latitude': latitude,
    'longitude': longitude,
    'teamSize': normalizeMatchTeamSize(teamSize),
    'isOrganized': isOrganized,
    'tournamentId': tournamentId,
    'challengeId': challengeId,
    'isGoldenRating': isGoldenRating,
    'isAnomaly': isAnomaly,
    'isFrozen': isFrozen,
    'stageType': stageType,
    'groupId': groupId,
    'groupStageId': groupStageId,
    'knockoutTieId': knockoutTieId,
    'roundIndex': roundIndex,
    'slotNumber': slotNumber,
    'scheduledAt': scheduledAt?.millisecondsSinceEpoch,
    'publishedAt': publishedAt?.millisecondsSinceEpoch,
    'venueId': venueId,
    'fixtureStatus': fixtureStatus,
    'lineupRequirement': lineupRequirement,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'startedAt': startedAt?.millisecondsSinceEpoch,
    'completedAt': completedAt?.millisecondsSinceEpoch,
    'cancelledAt': cancelledAt?.millisecondsSinceEpoch,
    'cancelledBy': cancelledBy,
    'cancelReason': cancelReason,
  };

  Match toEntity() => Match(
    id: id,
    organizerId: organizerId,
    teamAId: teamAId,
    teamBId: teamBId,
    teamAPlayerIds: teamAPlayerIds,
    teamBPlayerIds: teamBPlayerIds,
    teamAParticipantId: teamAParticipantId,
    teamBParticipantId: teamBParticipantId,
    status: _parseStatus(status),
    scoreTeamA: scoreTeamA,
    scoreTeamB: scoreTeamB,
    mvpPlayerId: mvpPlayerId,
    location: location,
    latitude: latitude,
    longitude: longitude,
    teamSize: normalizeMatchTeamSize(teamSize),
    isOrganized: isOrganized,
    tournamentId: tournamentId,
    challengeId: challengeId,
    isGoldenRating: isGoldenRating,
    isAnomaly: isAnomaly,
    isFrozen: isFrozen,
    stageType: stageType == null
        ? null
        : TournamentStageType.values.firstWhere(
            (value) => value.name == stageType,
            orElse: () => TournamentStageType.groupStage,
          ),
    groupId: groupId,
    groupStageId: groupStageId,
    knockoutTieId: knockoutTieId,
    roundIndex: roundIndex,
    slotNumber: slotNumber,
    scheduledAt: scheduledAt,
    publishedAt: publishedAt,
    venueId: venueId,
    fixtureStatus: FixtureStatus.values.firstWhere(
      (value) => value.name == fixtureStatus,
      orElse: () => FixtureStatus.draft,
    ),
    lineupRequirement: LineupRequirement.values.firstWhere(
      (value) => value.name == lineupRequirement,
      orElse: () => LineupRequirement.none,
    ),
    createdAt: createdAt,
    startedAt: startedAt,
    completedAt: completedAt,
    cancelledAt: cancelledAt,
    cancelledBy: cancelledBy,
    cancelReason: cancelReason,
  );

  factory MatchModel.fromEntity(Match m) => MatchModel(
    id: m.id,
    organizerId: m.organizerId,
    teamAId: m.teamAId,
    teamBId: m.teamBId,
    teamAPlayerIds: m.teamAPlayerIds,
    teamBPlayerIds: m.teamBPlayerIds,
    teamAParticipantId: m.teamAParticipantId,
    teamBParticipantId: m.teamBParticipantId,
    status: m.status.name,
    scoreTeamA: m.scoreTeamA,
    scoreTeamB: m.scoreTeamB,
    mvpPlayerId: m.mvpPlayerId,
    location: m.location,
    latitude: m.latitude,
    longitude: m.longitude,
    teamSize: normalizeMatchTeamSize(m.teamSize),
    isOrganized: m.isOrganized,
    tournamentId: m.tournamentId,
    challengeId: m.challengeId,
    isGoldenRating: m.isGoldenRating,
    isAnomaly: m.isAnomaly,
    isFrozen: m.isFrozen,
    stageType: m.stageType?.name,
    groupId: m.groupId,
    groupStageId: m.groupStageId,
    knockoutTieId: m.knockoutTieId,
    roundIndex: m.roundIndex,
    slotNumber: m.slotNumber,
    scheduledAt: m.scheduledAt,
    publishedAt: m.publishedAt,
    venueId: m.venueId,
    fixtureStatus: m.fixtureStatus.name,
    lineupRequirement: m.lineupRequirement.name,
    createdAt: m.createdAt,
    startedAt: m.startedAt,
    completedAt: m.completedAt,
    cancelledAt: m.cancelledAt,
    cancelledBy: m.cancelledBy,
    cancelReason: m.cancelReason,
  );

  static MatchStatus _parseStatus(String v) => MatchStatus.values.firstWhere(
    (e) => e.name == v,
    orElse: () => MatchStatus.open,
  );
}

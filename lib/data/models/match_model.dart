import '../../core/enums/match_status.dart';
import '../../domain/entities/match.dart';

/// نموذج بيانات المباراة — تحويل Firestore
class MatchModel {
  final String id;
  final String organizerId;
  final String? teamAId;
  final String? teamBId;
  final List<String> teamAPlayerIds;
  final List<String> teamBPlayerIds;
  final String status;
  final int? scoreTeamA;
  final int? scoreTeamB;
  final String? mvpPlayerId;
  final String? location;
  final double? latitude;
  final double? longitude;
  final bool isOrganized;
  final String? tournamentId;
  final bool isGoldenRating;
  final bool isAnomaly;
  final bool isFrozen;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  const MatchModel({
    required this.id,
    required this.organizerId,
    this.teamAId,
    this.teamBId,
    this.teamAPlayerIds = const [],
    this.teamBPlayerIds = const [],
    this.status = 'open',
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

  factory MatchModel.fromJson(Map<String, dynamic> json, String docId) {
    return MatchModel(
      id: docId,
      organizerId: json['organizerId'] as String? ?? '',
      teamAId: json['teamAId'] as String?,
      teamBId: json['teamBId'] as String?,
      teamAPlayerIds: (json['teamAPlayerIds'] as List<dynamic>?)
              ?.map((e) => e as String).toList() ?? [],
      teamBPlayerIds: (json['teamBPlayerIds'] as List<dynamic>?)
              ?.map((e) => e as String).toList() ?? [],
      status: json['status'] as String? ?? 'open',
      scoreTeamA: (json['scoreTeamA'] as num?)?.toInt(),
      scoreTeamB: (json['scoreTeamB'] as num?)?.toInt(),
      mvpPlayerId: json['mvpPlayerId'] as String?,
      location: json['location'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      isOrganized: json['isOrganized'] as bool? ?? false,
      tournamentId: json['tournamentId'] as String?,
      isGoldenRating: json['isGoldenRating'] as bool? ?? false,
      isAnomaly: json['isAnomaly'] as bool? ?? false,
      isFrozen: json['isFrozen'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch((json['createdAt'] as num).toInt())
          : DateTime.now(),
      startedAt: json['startedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch((json['startedAt'] as num).toInt())
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch((json['completedAt'] as num).toInt())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'organizerId': organizerId,
    'teamAId': teamAId,
    'teamBId': teamBId,
    'teamAPlayerIds': teamAPlayerIds,
    'teamBPlayerIds': teamBPlayerIds,
    'status': status,
    'scoreTeamA': scoreTeamA,
    'scoreTeamB': scoreTeamB,
    'mvpPlayerId': mvpPlayerId,
    'location': location,
    'latitude': latitude,
    'longitude': longitude,
    'isOrganized': isOrganized,
    'tournamentId': tournamentId,
    'isGoldenRating': isGoldenRating,
    'isAnomaly': isAnomaly,
    'isFrozen': isFrozen,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'startedAt': startedAt?.millisecondsSinceEpoch,
    'completedAt': completedAt?.millisecondsSinceEpoch,
  };

  Match toEntity() => Match(
    id: id,
    organizerId: organizerId,
    teamAId: teamAId,
    teamBId: teamBId,
    teamAPlayerIds: teamAPlayerIds,
    teamBPlayerIds: teamBPlayerIds,
    status: _parseStatus(status),
    scoreTeamA: scoreTeamA,
    scoreTeamB: scoreTeamB,
    mvpPlayerId: mvpPlayerId,
    location: location,
    latitude: latitude,
    longitude: longitude,
    isOrganized: isOrganized,
    tournamentId: tournamentId,
    isGoldenRating: isGoldenRating,
    isAnomaly: isAnomaly,
    isFrozen: isFrozen,
    createdAt: createdAt,
    startedAt: startedAt,
    completedAt: completedAt,
  );

  factory MatchModel.fromEntity(Match m) => MatchModel(
    id: m.id,
    organizerId: m.organizerId,
    teamAId: m.teamAId,
    teamBId: m.teamBId,
    teamAPlayerIds: m.teamAPlayerIds,
    teamBPlayerIds: m.teamBPlayerIds,
    status: m.status.name,
    scoreTeamA: m.scoreTeamA,
    scoreTeamB: m.scoreTeamB,
    mvpPlayerId: m.mvpPlayerId,
    location: m.location,
    latitude: m.latitude,
    longitude: m.longitude,
    isOrganized: m.isOrganized,
    tournamentId: m.tournamentId,
    isGoldenRating: m.isGoldenRating,
    isAnomaly: m.isAnomaly,
    isFrozen: m.isFrozen,
    createdAt: m.createdAt,
    startedAt: m.startedAt,
    completedAt: m.completedAt,
  );

  static MatchStatus _parseStatus(String v) =>
      MatchStatus.values.firstWhere((e) => e.name == v,
          orElse: () => MatchStatus.open);
}

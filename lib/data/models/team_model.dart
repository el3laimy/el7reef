import '../../domain/entities/team.dart';

/// نموذج بيانات الفريق — تحويل من/إلى Firestore
class TeamModel {
  final String id;
  final String name;
  final String? logoUrl;
  final String ownerId;
  final List<String> viceCaptainIds;
  final List<String> playerIds;
  final List<String> invitedIds;
  final double avgRating;
  final List<String> tournamentIds;
  final int wins;
  final int draws;
  final int losses;
  final DateTime createdAt;

  const TeamModel({
    required this.id,
    required this.name,
    this.logoUrl,
    required this.ownerId,
    this.viceCaptainIds = const [],
    this.playerIds = const [],
    this.invitedIds = const [],
    this.avgRating = 1000.0,
    this.tournamentIds = const [],
    this.wins = 0,
    this.draws = 0,
    this.losses = 0,
    required this.createdAt,
  });

  factory TeamModel.fromJson(Map<String, dynamic> json, String docId) {
    return TeamModel(
      id: docId,
      name: json['name'] as String? ?? '',
      logoUrl: json['logoUrl'] as String?,
      ownerId: json['ownerId'] as String? ?? json['captainId'] as String? ?? '', // Fallback for old data
      viceCaptainIds: (json['viceCaptainIds'] as List<dynamic>?)
              ?.map((e) => e as String).toList() ?? [],
      playerIds: (json['playerIds'] as List<dynamic>?)
              ?.map((e) => e as String).toList() ?? [],
      invitedIds: (json['invitedIds'] as List<dynamic>?)
              ?.map((e) => e as String).toList() ?? [],
      avgRating: (json['avgRating'] as num?)?.toDouble() ?? 1000.0,
      tournamentIds: (json['tournamentIds'] as List<dynamic>?)
              ?.map((e) => e as String).toList() ?? [],
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      draws: (json['draws'] as num?)?.toInt() ?? 0,
      losses: (json['losses'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch((json['createdAt'] as num).toInt())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'nameLower': name.toLowerCase(),
      'logoUrl': logoUrl,
      'ownerId': ownerId,
      'viceCaptainIds': viceCaptainIds,
      'playerIds': playerIds,
      'invitedIds': invitedIds,
      'avgRating': avgRating,
      'tournamentIds': tournamentIds,
      'wins': wins,
      'draws': draws,
      'losses': losses,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  Team toEntity() {
    return Team(
      id: id, name: name, logoUrl: logoUrl, ownerId: ownerId,
      viceCaptainIds: viceCaptainIds, playerIds: playerIds, invitedIds: invitedIds, avgRating: avgRating,
      tournamentIds: tournamentIds, wins: wins, draws: draws,
      losses: losses, createdAt: createdAt,
    );
  }

  factory TeamModel.fromEntity(Team team) {
    return TeamModel(
      id: team.id, name: team.name, logoUrl: team.logoUrl,
      ownerId: team.ownerId, viceCaptainIds: team.viceCaptainIds, playerIds: team.playerIds,
      invitedIds: team.invitedIds,
      avgRating: team.avgRating, tournamentIds: team.tournamentIds,
      wins: team.wins, draws: team.draws, losses: team.losses,
      createdAt: team.createdAt,
    );
  }
}

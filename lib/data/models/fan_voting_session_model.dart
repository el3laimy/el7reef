import '../../domain/entities/fan_voting_session.dart';

class FanVotingSessionModel {
  final String id;
  final String matchId;
  final DateTime opensAt;
  final DateTime closesAt;
  final int totalVotes;
  final Map<String, int> playerVotes;
  final String? winnerPlayerId;

  const FanVotingSessionModel({
    required this.id,
    required this.matchId,
    required this.opensAt,
    required this.closesAt,
    required this.totalVotes,
    required this.playerVotes,
    this.winnerPlayerId,
  });

  factory FanVotingSessionModel.fromJson(Map<String, dynamic> json, String docId) {
    return FanVotingSessionModel(
      id: docId,
      matchId: json['matchId'] as String? ?? '',
      opensAt: json['opensAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['opensAt'] as int)
          : DateTime.now(),
      closesAt: json['closesAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['closesAt'] as int)
          : DateTime.now().add(const Duration(minutes: 90)),
      totalVotes: (json['totalVotes'] as num?)?.toInt() ?? 0,
      playerVotes: (json['playerVotes'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, (e as num).toInt()),
          ) ?? {},
      winnerPlayerId: json['winnerPlayerId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'matchId': matchId,
      'opensAt': opensAt.millisecondsSinceEpoch,
      'closesAt': closesAt.millisecondsSinceEpoch,
      'totalVotes': totalVotes,
      'playerVotes': playerVotes,
      'winnerPlayerId': winnerPlayerId,
    };
  }

  FanVotingSession toEntity() {
    return FanVotingSession(
      id: id,
      matchId: matchId,
      opensAt: opensAt,
      closesAt: closesAt,
      totalVotes: totalVotes,
      playerVotes: playerVotes,
      winnerPlayerId: winnerPlayerId,
    );
  }

  factory FanVotingSessionModel.fromEntity(FanVotingSession entity) {
    return FanVotingSessionModel(
      id: entity.id,
      matchId: entity.matchId,
      opensAt: entity.opensAt,
      closesAt: entity.closesAt,
      totalVotes: entity.totalVotes,
      playerVotes: entity.playerVotes,
      winnerPlayerId: entity.winnerPlayerId,
    );
  }
}

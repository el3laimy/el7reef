import '../../domain/entities/player_match_stats.dart';

class PlayerMatchStatsModel {
  final String playerId;
  final String matchId;
  final String teamId;
  final bool played;
  final String position;
  final int goals;
  final int assists;
  final int saves;
  final int tackles;
  final bool cleanSheet;
  final bool yellowCard;
  final bool redCard;
  final double rating;

  const PlayerMatchStatsModel({
    required this.playerId,
    required this.matchId,
    required this.teamId,
    required this.played,
    required this.position,
    required this.goals,
    required this.assists,
    required this.saves,
    required this.tackles,
    required this.cleanSheet,
    required this.yellowCard,
    required this.redCard,
    required this.rating,
  });

  factory PlayerMatchStatsModel.fromJson(Map<String, dynamic> json, String docId) {
    return PlayerMatchStatsModel(
      playerId: json['playerId'] as String? ?? docId,
      matchId: json['matchId'] as String? ?? '',
      teamId: json['teamId'] as String? ?? '',
      played: json['played'] as bool? ?? true,
      position: json['position'] as String? ?? 'mixed',
      goals: (json['goals'] as num?)?.toInt() ?? 0,
      assists: (json['assists'] as num?)?.toInt() ?? 0,
      saves: (json['saves'] as num?)?.toInt() ?? 0,
      tackles: (json['tackles'] as num?)?.toInt() ?? 0,
      cleanSheet: json['cleanSheet'] as bool? ?? false,
      yellowCard: json['yellowCard'] as bool? ?? false,
      redCard: json['redCard'] as bool? ?? false,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'playerId': playerId,
      'matchId': matchId,
      'teamId': teamId,
      'played': played,
      'position': position,
      'goals': goals,
      'assists': assists,
      'saves': saves,
      'tackles': tackles,
      'cleanSheet': cleanSheet,
      'yellowCard': yellowCard,
      'redCard': redCard,
      'rating': rating,
    };
  }

  PlayerMatchStats toEntity() {
    return PlayerMatchStats(
      playerId: playerId,
      matchId: matchId,
      teamId: teamId,
      played: played,
      position: MatchPosition.values.firstWhere(
        (e) => e.name == position,
        orElse: () => MatchPosition.mixed,
      ),
      goals: goals,
      assists: assists,
      saves: saves,
      tackles: tackles,
      cleanSheet: cleanSheet,
      yellowCard: yellowCard,
      redCard: redCard,
      rating: rating,
    );
  }

  factory PlayerMatchStatsModel.fromEntity(PlayerMatchStats entity) {
    return PlayerMatchStatsModel(
      playerId: entity.playerId,
      matchId: entity.matchId,
      teamId: entity.teamId,
      played: entity.played,
      position: entity.position.name,
      goals: entity.goals,
      assists: entity.assists,
      saves: entity.saves,
      tackles: entity.tackles,
      cleanSheet: entity.cleanSheet,
      yellowCard: entity.yellowCard,
      redCard: entity.redCard,
      rating: entity.rating,
    );
  }
}

import '../../core/enums/tournament_ops_enums.dart';

class GroupStandingEntry {
  final String participantId;
  final String displayName;
  final int played;
  final int wins;
  final int draws;
  final int losses;
  final int goalsFor;
  final int goalsAgainst;
  final int rank;
  final int randomDrawOrder;

  const GroupStandingEntry({
    required this.participantId,
    required this.displayName,
    this.played = 0,
    this.wins = 0,
    this.draws = 0,
    this.losses = 0,
    this.goalsFor = 0,
    this.goalsAgainst = 0,
    this.rank = 0,
    this.randomDrawOrder = 0,
  });

  int get points => (wins * 3) + draws;
  int get goalDifference => goalsFor - goalsAgainst;

  GroupStandingEntry copyWith({
    String? participantId,
    String? displayName,
    int? played,
    int? wins,
    int? draws,
    int? losses,
    int? goalsFor,
    int? goalsAgainst,
    int? rank,
    int? randomDrawOrder,
  }) {
    return GroupStandingEntry(
      participantId: participantId ?? this.participantId,
      displayName: displayName ?? this.displayName,
      played: played ?? this.played,
      wins: wins ?? this.wins,
      draws: draws ?? this.draws,
      losses: losses ?? this.losses,
      goalsFor: goalsFor ?? this.goalsFor,
      goalsAgainst: goalsAgainst ?? this.goalsAgainst,
      rank: rank ?? this.rank,
      randomDrawOrder: randomDrawOrder ?? this.randomDrawOrder,
    );
  }
}

class GroupStandingSnapshot {
  final String id;
  final String tournamentId;
  final String groupStageId;
  final String groupId;
  final List<GroupStandingsMetric> tiebreakerOrder;
  final List<GroupStandingEntry> entries;
  final List<String> qualifierParticipantIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GroupStandingSnapshot({
    required this.id,
    required this.tournamentId,
    required this.groupStageId,
    required this.groupId,
    this.tiebreakerOrder = const [
      GroupStandingsMetric.points,
      GroupStandingsMetric.goalDifference,
      GroupStandingsMetric.goalsFor,
      GroupStandingsMetric.randomDraw,
    ],
    this.entries = const [],
    this.qualifierParticipantIds = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  GroupStandingSnapshot copyWith({
    String? id,
    String? tournamentId,
    String? groupStageId,
    String? groupId,
    List<GroupStandingsMetric>? tiebreakerOrder,
    List<GroupStandingEntry>? entries,
    List<String>? qualifierParticipantIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GroupStandingSnapshot(
      id: id ?? this.id,
      tournamentId: tournamentId ?? this.tournamentId,
      groupStageId: groupStageId ?? this.groupStageId,
      groupId: groupId ?? this.groupId,
      tiebreakerOrder: tiebreakerOrder ?? this.tiebreakerOrder,
      entries: entries ?? this.entries,
      qualifierParticipantIds:
          qualifierParticipantIds ?? this.qualifierParticipantIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

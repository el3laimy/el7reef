import '../../core/enums/tournament_ops_enums.dart';
import '../../domain/entities/group_standing_snapshot.dart';

class GroupStandingEntryModel {
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

  const GroupStandingEntryModel({
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

  factory GroupStandingEntryModel.fromJson(Map<String, dynamic> json) {
    return GroupStandingEntryModel(
      participantId: json['participantId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      played: (json['played'] as num?)?.toInt() ?? 0,
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      draws: (json['draws'] as num?)?.toInt() ?? 0,
      losses: (json['losses'] as num?)?.toInt() ?? 0,
      goalsFor: (json['goalsFor'] as num?)?.toInt() ?? 0,
      goalsAgainst: (json['goalsAgainst'] as num?)?.toInt() ?? 0,
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      randomDrawOrder: (json['randomDrawOrder'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'participantId': participantId,
      'displayName': displayName,
      'played': played,
      'wins': wins,
      'draws': draws,
      'losses': losses,
      'goalsFor': goalsFor,
      'goalsAgainst': goalsAgainst,
      'rank': rank,
      'randomDrawOrder': randomDrawOrder,
    };
  }

  GroupStandingEntry toEntity() {
    return GroupStandingEntry(
      participantId: participantId,
      displayName: displayName,
      played: played,
      wins: wins,
      draws: draws,
      losses: losses,
      goalsFor: goalsFor,
      goalsAgainst: goalsAgainst,
      rank: rank,
      randomDrawOrder: randomDrawOrder,
    );
  }

  factory GroupStandingEntryModel.fromEntity(GroupStandingEntry entity) {
    return GroupStandingEntryModel(
      participantId: entity.participantId,
      displayName: entity.displayName,
      played: entity.played,
      wins: entity.wins,
      draws: entity.draws,
      losses: entity.losses,
      goalsFor: entity.goalsFor,
      goalsAgainst: entity.goalsAgainst,
      rank: entity.rank,
      randomDrawOrder: entity.randomDrawOrder,
    );
  }
}

class GroupStandingSnapshotModel {
  final String id;
  final String tournamentId;
  final String groupStageId;
  final String groupId;
  final List<String> tiebreakerOrder;
  final List<GroupStandingEntryModel> entries;
  final List<String> qualifierParticipantIds;
  final int createdAt;
  final int updatedAt;

  const GroupStandingSnapshotModel({
    required this.id,
    required this.tournamentId,
    required this.groupStageId,
    required this.groupId,
    this.tiebreakerOrder = const [],
    this.entries = const [],
    this.qualifierParticipantIds = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory GroupStandingSnapshotModel.fromJson(
    Map<String, dynamic> json,
    String docId,
  ) {
    return GroupStandingSnapshotModel(
      id: docId,
      tournamentId: json['tournamentId'] as String? ?? '',
      groupStageId: json['groupStageId'] as String? ?? '',
      groupId: json['groupId'] as String? ?? '',
      tiebreakerOrder:
          (json['tiebreakerOrder'] as List<dynamic>?)
              ?.map((value) => value as String)
              .toList(growable: false) ??
          const [],
      entries:
          (json['entries'] as List<dynamic>?)
              ?.map(
                (value) => GroupStandingEntryModel.fromJson(
                  value as Map<String, dynamic>,
                ),
              )
              .toList(growable: false) ??
          const [],
      qualifierParticipantIds:
          (json['qualifierParticipantIds'] as List<dynamic>?)
              ?.map((value) => value as String)
              .toList(growable: false) ??
          const [],
      createdAt:
          (json['createdAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      updatedAt:
          (json['updatedAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tournamentId': tournamentId,
      'groupStageId': groupStageId,
      'groupId': groupId,
      'tiebreakerOrder': tiebreakerOrder,
      'entries': entries.map((value) => value.toJson()).toList(),
      'qualifierParticipantIds': qualifierParticipantIds,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  GroupStandingSnapshot toEntity() {
    return GroupStandingSnapshot(
      id: id,
      tournamentId: tournamentId,
      groupStageId: groupStageId,
      groupId: groupId,
      tiebreakerOrder: tiebreakerOrder
          .map(
            (value) => GroupStandingsMetric.values.firstWhere(
              (metric) => metric.name == value,
              orElse: () => GroupStandingsMetric.randomDraw,
            ),
          )
          .toList(growable: false),
      entries: entries.map((value) => value.toEntity()).toList(growable: false),
      qualifierParticipantIds: qualifierParticipantIds,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt),
    );
  }

  factory GroupStandingSnapshotModel.fromEntity(GroupStandingSnapshot entity) {
    return GroupStandingSnapshotModel(
      id: entity.id,
      tournamentId: entity.tournamentId,
      groupStageId: entity.groupStageId,
      groupId: entity.groupId,
      tiebreakerOrder: entity.tiebreakerOrder
          .map((metric) => metric.name)
          .toList(),
      entries: entity.entries.map(GroupStandingEntryModel.fromEntity).toList(),
      qualifierParticipantIds: entity.qualifierParticipantIds,
      createdAt: entity.createdAt.millisecondsSinceEpoch,
      updatedAt: entity.updatedAt.millisecondsSinceEpoch,
    );
  }
}

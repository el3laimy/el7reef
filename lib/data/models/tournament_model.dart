import '../../core/enums/tournament_enums.dart';
import '../../domain/entities/tournament.dart';
import '../../domain/entities/tournament_group_standings_config.dart';
import '../../domain/entities/tournament_assistant.dart';

/// نموذج بيانات الدورة — Firestore serialization
class TournamentModel {
  final String id;
  final String organizerId;
  final String name;
  final String? description;
  final String? location;
  final String format;
  final int teamSize;
  final int maxTeams;
  final int? prizePool;
  final String? prizeDescription;
  final String status;
  final List<String> registeredTeamIds;
  final List<TournamentAssistant> assistants;
  final List<String> groupRoundIds;
  final List<String> knockoutRoundIds;
  final bool isFantasyEnabled;
  final int? registrationDeadline;
  final int? startDate;
  final int? endDate;
  final int? participantListFinalizedAt;
  final int? activeParticipantCount;
  final String? currentGroupStageId;
  final String? currentKnockoutBracketId;
  final String? winnerParticipantId;
  final bool needsManualOpsMigration;
  final TournamentGroupStandingsConfig groupStandingsConfig;
  final int createdAt;

  const TournamentModel({
    required this.id,
    required this.organizerId,
    required this.name,
    this.description,
    this.location,
    required this.format,
    required this.teamSize,
    required this.maxTeams,
    this.prizePool,
    this.prizeDescription,
    this.status = 'upcoming',
    this.registeredTeamIds = const [],
    this.assistants = const [],
    this.groupRoundIds = const [],
    this.knockoutRoundIds = const [],
    this.isFantasyEnabled = true,
    this.registrationDeadline,
    this.startDate,
    this.endDate,
    this.participantListFinalizedAt,
    this.activeParticipantCount,
    this.currentGroupStageId,
    this.currentKnockoutBracketId,
    this.winnerParticipantId,
    this.needsManualOpsMigration = false,
    this.groupStandingsConfig = const TournamentGroupStandingsConfig(),
    required this.createdAt,
  });

  factory TournamentModel.fromJson(Map<String, dynamic> json, String docId) {
    return TournamentModel(
      id: docId,
      organizerId: json['organizerId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      location: json['location'] as String?,
      format: json['format'] as String? ?? 'groupsOnly',
      teamSize: (json['teamSize'] as num?)?.toInt() ?? 5,
      maxTeams: (json['maxTeams'] as num?)?.toInt() ?? 8,
      prizePool: (json['prizePool'] as num?)?.toInt(),
      prizeDescription: json['prizeDescription'] as String?,
      status: json['status'] as String? ?? 'upcoming',
      registeredTeamIds:
          (json['registeredTeamIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      assistants:
          (json['assistants'] as List<dynamic>?)
              ?.map(
                (e) => TournamentAssistant.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      groupRoundIds:
          (json['groupRoundIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      knockoutRoundIds:
          (json['knockoutRoundIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      isFantasyEnabled: json['isFantasyEnabled'] as bool? ?? true,
      registrationDeadline: (json['registrationDeadline'] as num?)?.toInt(),
      startDate: (json['startDate'] as num?)?.toInt(),
      endDate: (json['endDate'] as num?)?.toInt(),
      participantListFinalizedAt: (json['participantListFinalizedAt'] as num?)
          ?.toInt(),
      activeParticipantCount: (json['activeParticipantCount'] as num?)?.toInt(),
      currentGroupStageId: json['currentGroupStageId'] as String?,
      currentKnockoutBracketId: json['currentKnockoutBracketId'] as String?,
      winnerParticipantId: json['winnerParticipantId'] as String?,
      needsManualOpsMigration:
          json['needsManualOpsMigration'] as bool? ?? false,
      groupStandingsConfig: TournamentGroupStandingsConfig.fromJson(
        json['groupStandingsConfig'] as Map<String, dynamic>?,
      ),
      createdAt:
          (json['createdAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'organizerId': organizerId,
      'name': name,
      'description': description,
      'location': location,
      'format': format,
      'teamSize': teamSize,
      'maxTeams': maxTeams,
      'prizePool': prizePool,
      'prizeDescription': prizeDescription,
      'status': status,
      'registeredTeamIds': registeredTeamIds,
      'assistants': assistants.map((e) => e.toJson()).toList(),
      'isFantasyEnabled': isFantasyEnabled,
      'registrationDeadline': registrationDeadline,
      'startDate': startDate,
      'endDate': endDate,
      'participantListFinalizedAt': participantListFinalizedAt,
      'activeParticipantCount': activeParticipantCount,
      'currentGroupStageId': currentGroupStageId,
      'currentKnockoutBracketId': currentKnockoutBracketId,
      'winnerParticipantId': winnerParticipantId,
      'needsManualOpsMigration': needsManualOpsMigration,
      'groupStandingsConfig': groupStandingsConfig.toJson(),
      'createdAt': createdAt,
    };

    if (groupRoundIds.isNotEmpty) {
      data['groupRoundIds'] = groupRoundIds;
    }
    if (knockoutRoundIds.isNotEmpty) {
      data['knockoutRoundIds'] = knockoutRoundIds;
    }

    return data;
  }

  Tournament toEntity() => Tournament(
    id: id,
    organizerId: organizerId,
    name: name,
    description: description,
    location: location,
    format: _parseFormat(format),
    teamSize: TournamentTeamSize.fromInt(teamSize),
    maxTeams: maxTeams,
    prizePool: prizePool,
    prizeDescription: prizeDescription,
    status: _parseStatus(status),
    registeredTeamIds: registeredTeamIds,
    assistants: assistants,
    groupRoundIds: groupRoundIds,
    knockoutRoundIds: knockoutRoundIds,
    isFantasyEnabled: isFantasyEnabled,
    registrationDeadline: registrationDeadline != null
        ? DateTime.fromMillisecondsSinceEpoch(registrationDeadline!)
        : null,
    startDate: startDate != null
        ? DateTime.fromMillisecondsSinceEpoch(startDate!)
        : null,
    endDate: endDate != null
        ? DateTime.fromMillisecondsSinceEpoch(endDate!)
        : null,
    participantListFinalizedAt: participantListFinalizedAt != null
        ? DateTime.fromMillisecondsSinceEpoch(participantListFinalizedAt!)
        : null,
    activeParticipantCount: activeParticipantCount,
    currentGroupStageId: currentGroupStageId,
    currentKnockoutBracketId: currentKnockoutBracketId,
    winnerParticipantId: winnerParticipantId,
    needsManualOpsMigration: needsManualOpsMigration,
    groupStandingsConfig: groupStandingsConfig,
    createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
  );

  factory TournamentModel.fromEntity(Tournament t) => TournamentModel(
    id: t.id,
    organizerId: t.organizerId,
    name: t.name,
    description: t.description,
    location: t.location,
    format: t.format.name,
    teamSize: t.teamSize.value,
    maxTeams: t.maxTeams,
    prizePool: t.prizePool,
    prizeDescription: t.prizeDescription,
    status: t.status.name,
    registeredTeamIds: t.registeredTeamIds,
    assistants: t.assistants,
    groupRoundIds: t.groupRoundIds,
    knockoutRoundIds: t.knockoutRoundIds,
    isFantasyEnabled: t.isFantasyEnabled,
    registrationDeadline: t.registrationDeadline?.millisecondsSinceEpoch,
    startDate: t.startDate?.millisecondsSinceEpoch,
    endDate: t.endDate?.millisecondsSinceEpoch,
    participantListFinalizedAt:
        t.participantListFinalizedAt?.millisecondsSinceEpoch,
    activeParticipantCount: t.activeParticipantCount,
    currentGroupStageId: t.currentGroupStageId,
    currentKnockoutBracketId: t.currentKnockoutBracketId,
    winnerParticipantId: t.winnerParticipantId,
    needsManualOpsMigration: t.needsManualOpsMigration,
    groupStandingsConfig: t.groupStandingsConfig,
    createdAt: t.createdAt.millisecondsSinceEpoch,
  );

  static TournamentFormat _parseFormat(String v) =>
      TournamentFormat.values.firstWhere(
        (e) => e.name == v,
        orElse: () => TournamentFormat.groupsOnly,
      );

  static TournamentStatus _parseStatus(String v) => TournamentStatus.values
      .firstWhere((e) => e.name == v, orElse: () => TournamentStatus.upcoming);
}

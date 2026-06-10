import '../../core/enums/tournament_enums.dart';
import 'tournament_group_standings_config.dart';
import 'tournament_assistant.dart';

/// كيان الدورة — يمثل بطولة كرة القدم الشعبية
class Tournament {
  final String id;
  final String organizerId;
  final String name;
  final String? description;
  final String? location;
  final TournamentFormat format;
  final TournamentTeamSize teamSize;
  final int maxTeams;
  final TournamentVisibility visibility;
  final bool discoverable;
  final List<String> participantViewerIds;
  final int? prizePool;
  final String? prizeDescription;
  final TournamentStatus status;
  final List<String> registeredTeamIds; // Legacy compatibility only.
  final List<TournamentAssistant> assistants;
  final List<String> groupRoundIds; // Legacy read-only compatibility only.
  final List<String> knockoutRoundIds; // Legacy read-only compatibility only.
  final bool isFantasyEnabled;
  final DateTime? registrationDeadline;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? participantListFinalizedAt;
  final int? activeParticipantCount;
  final String? currentGroupStageId;
  final String? currentKnockoutBracketId;
  final String? winnerParticipantId;
  final bool needsManualOpsMigration;
  final TournamentGroupStandingsConfig groupStandingsConfig;
  final DateTime createdAt;

  const Tournament({
    required this.id,
    required this.organizerId,
    required this.name,
    this.description,
    this.location,
    required this.format,
    required this.teamSize,
    required this.maxTeams,
    this.visibility = TournamentVisibility.public,
    this.discoverable = true,
    this.participantViewerIds = const [],
    this.prizePool,
    this.prizeDescription,
    this.status = TournamentStatus.upcoming,
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

  /// هل التسجيل مفتوح؟
  bool get isRegistrationOpen => status == TournamentStatus.registration;

  /// هل يمكن إضافة فريق جديد؟
  bool get canRegister => isRegistrationOpen && teamCount < maxTeams;

  bool get isPublic => visibility == TournamentVisibility.public;

  bool get isDiscoverable => isPublic && discoverable;

  /// عدد الفرق الحالي
  int get teamCount => activeParticipantCount ?? registeredTeamIds.length;

  /// نسبة الامتلاء
  double get fillRate => maxTeams == 0 ? 0 : teamCount / maxTeams;

  bool get hasOperationalParticipants => participantListFinalizedAt != null;

  Tournament copyWith({
    String? id,
    String? organizerId,
    String? name,
    String? description,
    String? location,
    TournamentFormat? format,
    TournamentTeamSize? teamSize,
    int? maxTeams,
    TournamentVisibility? visibility,
    bool? discoverable,
    List<String>? participantViewerIds,
    int? prizePool,
    String? prizeDescription,
    TournamentStatus? status,
    List<String>? registeredTeamIds,
    List<TournamentAssistant>? assistants,
    List<String>? groupRoundIds,
    List<String>? knockoutRoundIds,
    bool? isFantasyEnabled,
    DateTime? registrationDeadline,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? participantListFinalizedAt,
    int? activeParticipantCount,
    String? currentGroupStageId,
    String? currentKnockoutBracketId,
    String? winnerParticipantId,
    bool? needsManualOpsMigration,
    TournamentGroupStandingsConfig? groupStandingsConfig,
    DateTime? createdAt,
  }) {
    return Tournament(
      id: id ?? this.id,
      organizerId: organizerId ?? this.organizerId,
      name: name ?? this.name,
      description: description ?? this.description,
      location: location ?? this.location,
      format: format ?? this.format,
      teamSize: teamSize ?? this.teamSize,
      maxTeams: maxTeams ?? this.maxTeams,
      visibility: visibility ?? this.visibility,
      discoverable: discoverable ?? this.discoverable,
      participantViewerIds: participantViewerIds ?? this.participantViewerIds,
      prizePool: prizePool ?? this.prizePool,
      prizeDescription: prizeDescription ?? this.prizeDescription,
      status: status ?? this.status,
      registeredTeamIds: registeredTeamIds ?? this.registeredTeamIds,
      assistants: assistants ?? this.assistants,
      groupRoundIds: groupRoundIds ?? this.groupRoundIds,
      knockoutRoundIds: knockoutRoundIds ?? this.knockoutRoundIds,
      isFantasyEnabled: isFantasyEnabled ?? this.isFantasyEnabled,
      registrationDeadline: registrationDeadline ?? this.registrationDeadline,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      participantListFinalizedAt:
          participantListFinalizedAt ?? this.participantListFinalizedAt,
      activeParticipantCount:
          activeParticipantCount ?? this.activeParticipantCount,
      currentGroupStageId: currentGroupStageId ?? this.currentGroupStageId,
      currentKnockoutBracketId:
          currentKnockoutBracketId ?? this.currentKnockoutBracketId,
      winnerParticipantId: winnerParticipantId ?? this.winnerParticipantId,
      needsManualOpsMigration:
          needsManualOpsMigration ?? this.needsManualOpsMigration,
      groupStandingsConfig: groupStandingsConfig ?? this.groupStandingsConfig,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// إدخال نتيجة مجموعة للترتيب
class GroupStanding {
  final String teamId;
  final String teamName;
  final int played;
  final int wins;
  final int draws;
  final int losses;
  final int goalsFor;
  final int goalsAgainst;

  const GroupStanding({
    required this.teamId,
    required this.teamName,
    this.played = 0,
    this.wins = 0,
    this.draws = 0,
    this.losses = 0,
    this.goalsFor = 0,
    this.goalsAgainst = 0,
  });

  int get points => (wins * 3) + draws;
  int get goalDifference => goalsFor - goalsAgainst;

  /// مقارنة للترتيب: نقاط → فارق أهداف → أهداف مسجلة
  int compareTo(GroupStanding other) {
    if (points != other.points) return other.points.compareTo(points);
    if (goalDifference != other.goalDifference) {
      return other.goalDifference.compareTo(goalDifference);
    }
    return other.goalsFor.compareTo(goalsFor);
  }
}

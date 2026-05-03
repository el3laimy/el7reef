import 'participant_ref.dart';

enum MatchEventType { goal, mvp }

enum MatchEventStatus { active, voided }

class MatchEvent {
  final String id;
  final String matchId;
  final String? tournamentId;
  final MatchEventType eventType;
  final String sideKey;
  final ParticipantRef actor;
  final int? minute;
  final String createdBy;
  final DateTime createdAt;
  final MatchEventStatus status;

  const MatchEvent({
    required this.id,
    required this.matchId,
    this.tournamentId,
    required this.eventType,
    required this.sideKey,
    required this.actor,
    this.minute,
    required this.createdBy,
    required this.createdAt,
    this.status = MatchEventStatus.active,
  });

  bool get isGoal => eventType == MatchEventType.goal;
  bool get isMvp => eventType == MatchEventType.mvp;
  bool get isActive => status == MatchEventStatus.active;

  MatchEvent copyWith({
    String? id,
    String? matchId,
    Object? tournamentId = _unset,
    MatchEventType? eventType,
    String? sideKey,
    ParticipantRef? actor,
    Object? minute = _unset,
    String? createdBy,
    DateTime? createdAt,
    MatchEventStatus? status,
  }) {
    return MatchEvent(
      id: id ?? this.id,
      matchId: matchId ?? this.matchId,
      tournamentId: identical(tournamentId, _unset)
          ? this.tournamentId
          : tournamentId as String?,
      eventType: eventType ?? this.eventType,
      sideKey: sideKey ?? this.sideKey,
      actor: actor ?? this.actor,
      minute: identical(minute, _unset) ? this.minute : minute as int?,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
    );
  }
}

const Object _unset = Object();

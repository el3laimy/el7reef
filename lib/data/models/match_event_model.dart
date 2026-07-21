import '../../domain/entities/match_event.dart';
import '../../core/firestore/firestore_date_adapter.dart';
import 'participant_ref_model.dart';

class MatchEventModel {
  final String id;
  final String matchId;
  final String? tournamentId;
  final String eventType;
  final String sideKey;
  final ParticipantRefModel actor;
  final int? minute;
  final String createdBy;
  final DateTime createdAt;
  final String status;

  const MatchEventModel({
    required this.id,
    required this.matchId,
    this.tournamentId,
    required this.eventType,
    required this.sideKey,
    required this.actor,
    this.minute,
    required this.createdBy,
    required this.createdAt,
    this.status = 'active',
  });

  factory MatchEventModel.fromJson(Map<String, dynamic> json, String docId) {
    final actorJson = json['actor'];
    return MatchEventModel(
      id: docId,
      matchId: json['matchId'] as String? ?? '',
      tournamentId: json['tournamentId'] as String?,
      eventType: json['eventType'] as String? ?? MatchEventType.goal.name,
      sideKey: json['sideKey'] as String? ?? '',
      actor: actorJson is Map<String, dynamic>
          ? ParticipantRefModel.fromJson(actorJson)
          : throw const FormatException('MatchEvent.actor is required.'),
      minute: (json['minute'] as num?)?.toInt(),
      createdBy: json['createdBy'] as String? ?? '',
      createdAt: _dateFromMs(json['createdAt']),
      status: json['status'] as String? ?? MatchEventStatus.active.name,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'matchId': matchId,
      'tournamentId': tournamentId,
      'eventType': eventType,
      'sideKey': sideKey,
      'actor': actor.toJson(),
      'minute': minute,
      'createdBy': createdBy,
      'createdAt': FirestoreDateAdapter.write(createdAt),
      'status': status,
    };
  }

  MatchEvent toEntity() {
    return MatchEvent(
      id: id,
      matchId: matchId,
      tournamentId: tournamentId,
      eventType: _parseEventType(eventType),
      sideKey: sideKey,
      actor: actor.toEntity(),
      minute: minute,
      createdBy: createdBy,
      createdAt: createdAt,
      status: _parseStatus(status),
    );
  }

  factory MatchEventModel.fromEntity(MatchEvent event) {
    return MatchEventModel(
      id: event.id,
      matchId: event.matchId,
      tournamentId: event.tournamentId,
      eventType: event.eventType.name,
      sideKey: event.sideKey,
      actor: ParticipantRefModel.fromEntity(event.actor),
      minute: event.minute,
      createdBy: event.createdBy,
      createdAt: event.createdAt,
      status: event.status.name,
    );
  }

  static MatchEventType _parseEventType(String value) {
    return MatchEventType.values.firstWhere(
      (entry) => entry.name == value,
      orElse: () => MatchEventType.goal,
    );
  }

  static MatchEventStatus _parseStatus(String value) {
    return MatchEventStatus.values.firstWhere(
      (entry) => entry.name == value,
      orElse: () => MatchEventStatus.active,
    );
  }

  static DateTime _dateFromMs(Object? value) {
    return FirestoreDateAdapter.readOr(value, DateTime.now());
  }
}

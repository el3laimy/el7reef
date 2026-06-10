import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firebase_paths.dart';
import '../../data/repositories/match_event_repository_impl.dart';
import '../../data/repositories/tournament_assistant_permission_repository_impl.dart';
import '../utils/app_logger.dart';
import '../../domain/entities/match_event.dart';
import '../../domain/entities/participant_ref.dart';
import '../../domain/entities/tournament_assistant_permission.dart';
import '../../domain/repositories/match_event_repository.dart';
import '../../domain/repositories/tournament_assistant_permission_repository.dart';

class MatchGoalDraft {
  final String sideKey;
  final ParticipantRef actor;
  final int? minute;
  final String? eventId;

  const MatchGoalDraft({
    required this.sideKey,
    required this.actor,
    this.minute,
    this.eventId,
  });
}

class MatchEventService {
  final MatchEventRepository _repository;
  final TournamentAssistantPermissionRepository _assistantPermissionRepository;
  final FirebaseFirestore _firestore;

  MatchEventService({
    MatchEventRepository? repository,
    TournamentAssistantPermissionRepository? assistantPermissionRepository,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _repository =
           repository ?? MatchEventRepositoryImpl(firestore: firestore),
       _assistantPermissionRepository =
           assistantPermissionRepository ??
           TournamentAssistantPermissionRepositoryImpl(firestore: firestore);

  CollectionReference<Map<String, dynamic>> get _matchesRef =>
      _firestore.collection(FirebasePaths.matches);

  Future<MatchEvent> recordGoal({
    String? eventId,
    required String matchId,
    String? tournamentId,
    required String sideKey,
    required ParticipantRef actor,
    int? minute,
    required String createdBy,
    DateTime? now,
  }) async {
    final createdAt = now ?? DateTime.now();
    final matchTournamentId = await _assertCanCreateMatchEvent(
      matchId: matchId,
      tournamentId: tournamentId,
      actorId: createdBy,
    );
    final event = MatchEvent(
      id: _eventId(eventId, prefix: 'goal', matchId: matchId, now: createdAt),
      matchId: _required(matchId, 'matchId'),
      tournamentId: matchTournamentId,
      eventType: MatchEventType.goal,
      sideKey: _sideKey(sideKey),
      actor: _actor(actor),
      minute: _minute(minute),
      createdBy: _required(createdBy, 'createdBy'),
      createdAt: createdAt,
    );
    await _repository.createEvent(event);
    return event;
  }

  Future<List<MatchEvent>> recordGoals({
    required String matchId,
    String? tournamentId,
    required List<MatchGoalDraft> goals,
    required String createdBy,
    DateTime? now,
  }) async {
    if (goals.isEmpty) {
      throw ArgumentError('goals must not be empty.');
    }
    final recorded = <MatchEvent>[];
    var index = 0;
    for (final goal in goals) {
      final goalTime = (now ?? DateTime.now()).add(
        Duration(microseconds: index),
      );
      recorded.add(
        await recordGoal(
          eventId: goal.eventId,
          matchId: matchId,
          tournamentId: tournamentId,
          sideKey: goal.sideKey,
          actor: goal.actor,
          minute: goal.minute,
          createdBy: createdBy,
          now: goalTime,
        ),
      );
      index += 1;
    }
    return recorded;
  }

  Future<MatchEvent> recordMvp({
    String? eventId,
    required String matchId,
    String? tournamentId,
    required String sideKey,
    required ParticipantRef actor,
    required String createdBy,
    DateTime? now,
  }) async {
    final createdAt = now ?? DateTime.now();
    final matchTournamentId = await _assertCanCreateMatchEvent(
      matchId: matchId,
      tournamentId: tournamentId,
      actorId: createdBy,
    );
    final event = MatchEvent(
      id: _eventId(eventId, prefix: 'mvp', matchId: matchId, now: createdAt),
      matchId: _required(matchId, 'matchId'),
      tournamentId: matchTournamentId,
      eventType: MatchEventType.mvp,
      sideKey: _sideKey(sideKey),
      actor: _actor(actor),
      createdBy: _required(createdBy, 'createdBy'),
      createdAt: createdAt,
    );
    await _repository.createEvent(event);
    return event;
  }

  Future<void> voidEvent(String eventId) {
    return _repository.voidEvent(_required(eventId, 'eventId'));
  }

  Future<List<MatchEvent>> getMatchEvents(String matchId) {
    return _repository.getEventsByMatchId(_required(matchId, 'matchId'));
  }

  Future<List<MatchEvent>> getEventsForActor({
    required ParticipantRefKind actorKind,
    required String actorId,
  }) {
    return _repository.getEventsByActor(
      actorKind: actorKind.name,
      actorId: _required(actorId, 'actorId'),
    );
  }

  Future<List<MatchEvent>> getTournamentGoalEvents(String tournamentId) {
    return _repository.getGoalEventsByTournamentId(
      _required(tournamentId, 'tournamentId'),
    );
  }

  Future<MatchEvent?> getMvpEvent(String matchId) {
    return _repository.getMvpEventByMatchId(_required(matchId, 'matchId'));
  }

  String _eventId(
    String? eventId, {
    required String prefix,
    required String matchId,
    required DateTime now,
  }) {
    final normalized = _normalizeOptional(eventId);
    if (normalized != null) {
      return normalized;
    }
    return '$prefix-$matchId-${now.microsecondsSinceEpoch}';
  }

  ParticipantRef _actor(ParticipantRef actor) {
    return ParticipantRef(
      kind: actor.kind,
      id: _required(actor.id, 'actor.id'),
      displayName: _required(actor.displayName, 'actor.displayName'),
      linkedPlayerId: _normalizeOptional(actor.linkedPlayerId),
    );
  }

  String _sideKey(String value) {
    final normalized = _required(value, 'sideKey').toUpperCase();
    if (normalized != 'A' && normalized != 'B') {
      throw ArgumentError('sideKey must be A or B.');
    }
    return normalized;
  }

  int? _minute(int? value) {
    if (value != null && value < 0) {
      throw ArgumentError('minute must be zero or greater.');
    }
    return value;
  }

  String _required(String value, String fieldName) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('$fieldName is required.');
    }
    return trimmed;
  }

  String? _normalizeOptional(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  Future<String?> _assertCanCreateMatchEvent({
    required String matchId,
    required String? tournamentId,
    required String actorId,
  }) async {
    final normalizedMatchId = _required(matchId, 'matchId');
    final normalizedActorId = _required(actorId, 'createdBy');
    final normalizedTournamentId = _normalizeOptional(tournamentId);
    final snapshot = await _matchesRef.doc(normalizedMatchId).get();
    if (!snapshot.exists || snapshot.data() == null) {
      throw Exception('تعذر العثور على المباراة المطلوبة.');
    }
    final data = snapshot.data()!;
    final organizerId = data['organizerId'] is String
        ? data['organizerId'] as String
        : '';
    final matchTournamentId = data['tournamentId'] is String
        ? _normalizeOptional(data['tournamentId'] as String)
        : null;
    if (normalizedTournamentId != null &&
        matchTournamentId != normalizedTournamentId) {
      throw Exception('بيانات البطولة لا تطابق المباراة.');
    }
    if (organizerId == normalizedActorId) {
      return matchTournamentId;
    }
    if (matchTournamentId == null) {
      throw Exception('لا تملك صلاحية تسجيل أحداث هذه المباراة.');
    }
    final TournamentAssistantPermission? assistantPermission;
    try {
      assistantPermission = await _assistantPermissionRepository
          .getAssistantPermission(matchTournamentId, normalizedActorId);
    } catch (error) {
      AppLogger.warning(
        'MatchEventService.getTournamentIdForActor.permissionLookup',
        error,
      );
      throw Exception('لا تملك صلاحية تسجيل أحداث هذه المباراة.');
    }
    if (assistantPermission == null || !assistantPermission.isActive) {
      throw Exception('لا تملك صلاحية تسجيل أحداث هذه المباراة.');
    }
    if (!assistantPermission.hasPermission(
      TournamentAssistantPermissionKey.canRecordGoalsAndMvp,
    )) {
      throw Exception('لا تملك صلاحية تسجيل أحداث هذه المباراة.');
    }
    return matchTournamentId;
  }
}

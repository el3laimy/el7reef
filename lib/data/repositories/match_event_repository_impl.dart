import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errors/firebase_error_handler.dart';
import '../../core/constants/firebase_paths.dart';
import '../../domain/entities/match_event.dart';
import '../../domain/repositories/match_event_repository.dart';
import '../models/match_event_model.dart';

class MatchEventRepositoryImpl implements MatchEventRepository {
  final FirebaseFirestore _firestore;

  MatchEventRepositoryImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _eventsRef =>
      _firestore.collection(FirebasePaths.matchEvents);

  @override
  Future<void> createEvent(MatchEvent event) async {
    return FirebaseErrorHandler.guard(() async {
      final model = MatchEventModel.fromEntity(event);
      await _eventsRef.doc(event.id).set(model.toJson());
    });
  }

  @override
  Future<List<MatchEvent>> getEventsByMatchId(String matchId) async {
    return FirebaseErrorHandler.guard(() async {
      final snapshot = await _eventsRef
          .where('matchId', isEqualTo: matchId)
          .where('status', isEqualTo: MatchEventStatus.active.name)
          .get();
      final events = snapshot.docs
          .map((doc) => MatchEventModel.fromJson(doc.data(), doc.id).toEntity())
          .toList(growable: true);
      events.sort(_compareEvents);
      return events;
    });
  }

  @override
  Future<List<MatchEvent>> getEventsByActor({
    required String actorKind,
    required String actorId,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      final snapshot = await _eventsRef
          .where('actor.kind', isEqualTo: actorKind)
          .where('actor.id', isEqualTo: actorId)
          .where('status', isEqualTo: MatchEventStatus.active.name)
          .get();
      final events = snapshot.docs
          .map((doc) => MatchEventModel.fromJson(doc.data(), doc.id).toEntity())
          .toList(growable: true);
      events.sort(_compareEvents);
      return events;
    });
  }

  @override
  Future<List<MatchEvent>> getGoalEventsByTournamentId(
    String tournamentId,
  ) async {
    return FirebaseErrorHandler.guard(() async {
      final snapshot = await _eventsRef
          .where('tournamentId', isEqualTo: tournamentId)
          .where('eventType', isEqualTo: MatchEventType.goal.name)
          .where('status', isEqualTo: MatchEventStatus.active.name)
          .get();
      final events = snapshot.docs
          .map((doc) => MatchEventModel.fromJson(doc.data(), doc.id).toEntity())
          .toList(growable: true);
      events.sort(_compareEvents);
      return events;
    });
  }

  @override
  Future<MatchEvent?> getMvpEventByMatchId(String matchId) async {
    return FirebaseErrorHandler.guard(() async {
      final snapshot = await _eventsRef
          .where('matchId', isEqualTo: matchId)
          .where('eventType', isEqualTo: MatchEventType.mvp.name)
          .where('status', isEqualTo: MatchEventStatus.active.name)
          .get();
      if (snapshot.docs.isEmpty) {
        return null;
      }
      final events = snapshot.docs
          .map((doc) => MatchEventModel.fromJson(doc.data(), doc.id).toEntity())
          .toList(growable: true);
      events.sort(_compareEvents);
      return events.last;
    });
  }

  @override
  Future<void> voidEvent(String eventId) async {
    return FirebaseErrorHandler.guard(() async {
      await _eventsRef.doc(eventId).update({
        'status': MatchEventStatus.voided.name,
      });
    });
  }

  int _compareEvents(MatchEvent left, MatchEvent right) {
    final minuteCompare = (left.minute ?? 1 << 30).compareTo(
      right.minute ?? 1 << 30,
    );
    if (minuteCompare != 0) {
      return minuteCompare;
    }
    final createdCompare = left.createdAt.compareTo(right.createdAt);
    if (createdCompare != 0) {
      return createdCompare;
    }
    return left.id.compareTo(right.id);
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errors/firebase_error_handler.dart';
import '../../core/constants/firebase_paths.dart';
import '../../data/models/tournament_participant_model.dart';
import '../../domain/entities/tournament_participant.dart';
import '../../domain/repositories/tournament_participant_repository.dart';

class TournamentParticipantRepositoryImpl
    implements TournamentParticipantRepository {
  final FirebaseFirestore _firestore;

  TournamentParticipantRepositoryImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _participantsRef =>
      _firestore.collection(FirebasePaths.tournamentParticipants);

  @override
  Future<TournamentParticipant?> getParticipant(String participantId) async {
    return FirebaseErrorHandler.guard(() async {
      final doc = await _participantsRef.doc(participantId).get();
      if (!doc.exists || doc.data() == null) {
        return null;
      }
      return TournamentParticipantModel.fromJson(doc.data()!, doc.id).toEntity();
    });
  }

  @override
  Future<void> createParticipant(TournamentParticipant participant) async {
    return FirebaseErrorHandler.guard(() async {
      await _participantsRef
          .doc(participant.id)
          .set(TournamentParticipantModel.fromEntity(participant).toJson());
    });
  }

  @override
  Future<void> updateParticipant(TournamentParticipant participant) async {
    return FirebaseErrorHandler.guard(() async {
      await _participantsRef
          .doc(participant.id)
          .update(TournamentParticipantModel.fromEntity(participant).toJson());
    });
  }

  @override
  Future<void> deleteParticipant(String participantId) async {
    return FirebaseErrorHandler.guard(() async {
      await _participantsRef.doc(participantId).delete();
    });
  }

  @override
  Future<List<TournamentParticipant>> getTournamentParticipants(
    String tournamentId,
  ) async {
    return FirebaseErrorHandler.guard(() async {
      final snapshot = await _participantsRef
          .where('tournamentId', isEqualTo: tournamentId)
          .get();
      final participants = snapshot.docs
          .map(
            (doc) => TournamentParticipantModel.fromJson(
              doc.data(),
              doc.id,
            ).toEntity(),
          )
          .toList(growable: true);
      participants.sort((left, right) {
        final leftSeed = left.seed ?? 1 << 20;
        final rightSeed = right.seed ?? 1 << 20;
        if (leftSeed != rightSeed) {
          return leftSeed.compareTo(rightSeed);
        }
        return left.displayName.compareTo(right.displayName);
      });
      return participants;
    });
  }

  @override
  Future<TournamentParticipant?> getParticipantBySource({
    required String tournamentId,
    required String sourceEntityId,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      final snapshot = await _participantsRef
          .where('tournamentId', isEqualTo: tournamentId)
          .where('sourceEntityId', isEqualTo: sourceEntityId)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) {
        return null;
      }
      final doc = snapshot.docs.first;
      return TournamentParticipantModel.fromJson(doc.data(), doc.id).toEntity();
    });
  }
}

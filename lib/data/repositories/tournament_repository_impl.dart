import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firebase_paths.dart';
import '../../core/enums/tournament_enums.dart';
import '../../core/errors/firebase_error_handler.dart';
import '../../domain/entities/tournament.dart';
import '../../domain/repositories/tournament_repository.dart';
import '../models/tournament_model.dart';

/// تنفيذ مستودع الدورة مع Firestore
class TournamentRepositoryImpl implements TournamentRepository {
  final FirebaseFirestore _firestore;

  TournamentRepositoryImpl({
    FirebaseFirestore? db,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? db ?? FirebaseFirestore.instance;

  CollectionReference get _col =>
      _firestore.collection(FirebasePaths.tournaments);
  CollectionReference<Map<String, dynamic>> get _participantsRef =>
      _firestore.collection(FirebasePaths.tournamentParticipants);
  CollectionReference<Map<String, dynamic>> get _membershipsRef =>
      _firestore.collection(FirebasePaths.tournamentMemberships);

  CollectionReference<Map<String, dynamic>> _followersRef(String tournamentId) {
    return _firestore
        .collection(FirebasePaths.tournaments)
        .doc(tournamentId)
        .collection('followers');
  }

  @override
  Future<Tournament?> getTournament(String tournamentId) async {
    return FirebaseErrorHandler.guard(() async {
      final doc = await _col.doc(tournamentId).get();
      if (!doc.exists || doc.data() == null) return null;
      return TournamentModel.fromJson(
        doc.data()! as Map<String, dynamic>,
        doc.id,
      ).toEntity();
    });
  }

  @override
  Future<void> createTournament(Tournament tournament) async {
    return FirebaseErrorHandler.guard(() async {
      final model = TournamentModel.fromEntity(tournament);
      final now = DateTime.now().millisecondsSinceEpoch;
      final batch = _firestore.batch();
      batch.set(_col.doc(tournament.id), model.toJson());
      batch.set(
        _membershipsRef.doc('${tournament.organizerId}_${tournament.id}'),
        {
          'tournamentId': tournament.id,
          'userId': tournament.organizerId,
          'role': 'organizer',
          'createdAt': now,
        },
      );
      await batch.commit();
    });
  }

  @override
  Future<void> updateTournament(Tournament tournament) async {
    return FirebaseErrorHandler.guard(() async {
      final model = TournamentModel.fromEntity(tournament);
      await _col.doc(tournament.id).update(model.toJson());
    });
  }

  @override
  Future<List<Tournament>> getDiscoverableTournaments({int limit = 20}) async {
    return FirebaseErrorHandler.guard(() async {
      final snapshots = await Future.wait([
        _col
            .where('discoverable', isEqualTo: true)
            .where('visibility', isEqualTo: TournamentVisibility.public.name)
            .where('isFeatured', isEqualTo: true)
            .orderBy('featuredPriority')
            .limit(5)
            .get(),
        _col
            .where('discoverable', isEqualTo: true)
            .where('visibility', isEqualTo: TournamentVisibility.public.name)
            .where(
              'status',
              whereIn: [
                TournamentStatus.upcoming.name,
                TournamentStatus.registration.name,
                TournamentStatus.groupStage.name,
                TournamentStatus.transferWindow.name,
                TournamentStatus.knockoutStage.name,
              ],
            )
            .orderBy('createdAt', descending: true)
            .limit(limit)
            .get(),
      ]);

      final byId = <String, Tournament>{
        for (final tournament in _mapTournamentDocs(snapshots.first.docs))
          tournament.id: tournament,
        for (final tournament in _mapTournamentDocs(snapshots.last.docs))
          tournament.id: tournament,
      };

      final tournaments = byId.values.toList(growable: true);
      tournaments.sort((left, right) {
        if (left.isFeatured != right.isFeatured) {
          return left.isFeatured ? -1 : 1;
        }
        if (left.isFeatured) {
          final priority = left.featuredPriority.compareTo(
            right.featuredPriority,
          );
          if (priority != 0) return priority;
        }
        return right.createdAt.compareTo(left.createdAt);
      });
      return tournaments.take(limit).toList(growable: false);
    });
  }

  @override
  Future<List<Tournament>> getLiveTournaments({int limit = 20}) {
    return getDiscoverableTournaments(limit: limit);
  }

  @override
  Future<List<Tournament>> getOrganizerTournaments(String organizerId) async {
    return FirebaseErrorHandler.guard(() async {
      final snap = await _membershipsRef
          .where('userId', isEqualTo: organizerId)
          .where('role', isEqualTo: 'organizer')
          .get();
      final tournamentIds = snap.docs
          .map((doc) => doc.data()['tournamentId'] as String?)
          .whereType<String>()
          .toSet()
          .toList(growable: false);
      if (tournamentIds.isEmpty) {
        return const <Tournament>[];
      }

      final docs = await Future.wait(
        tournamentIds.map((id) => _col.doc(id).get()),
      );
      final tournaments = _mapTournamentDocs(
        docs.where((doc) => doc.exists && doc.data() != null),
      );
      tournaments.sort(
        (left, right) => right.createdAt.compareTo(left.createdAt),
      );
      return tournaments;
    });
  }

  @override
  Future<List<Tournament>> getPlayerTournaments(String teamId) async {
    return FirebaseErrorHandler.guard(() async {
      final participantSnap = await _participantsRef
          .where('sourceType', isEqualTo: 'registeredTeam')
          .where('sourceEntityId', isEqualTo: teamId)
          .get();
      final tournamentIds = participantSnap.docs
          .map((doc) => doc.data()['tournamentId'] as String?)
          .whereType<String>()
          .toSet()
          .toList(growable: false);

      if (tournamentIds.isNotEmpty) {
        final docs = await Future.wait(
          tournamentIds.map((id) => _col.doc(id).get()),
        );
        final tournaments = _mapTournamentDocs(
          docs.where((doc) => doc.exists && doc.data() != null),
        );
        tournaments.sort(
          (left, right) => right.createdAt.compareTo(left.createdAt),
        );
        return tournaments;
      }

      final legacySnap = await _col
          .where('registeredTeamIds', arrayContains: teamId)
          .orderBy('createdAt', descending: true)
          .get();
      return _mapTournamentDocs(legacySnap.docs);
    });
  }

  @override
  Future<List<Tournament>> getFollowedTournaments(String userId) async {
    return FirebaseErrorHandler.guard(() async {
      final snap = await _firestore
          .collectionGroup('followers')
          .where('userId', isEqualTo: userId)
          .get();
      final tournamentIds = snap.docs
          .map(
            (doc) =>
                doc.data()['tournamentId'] as String? ??
                doc.reference.parent.parent?.id,
          )
          .whereType<String>()
          .toSet()
          .toList(growable: false);
      if (tournamentIds.isEmpty) {
        return const <Tournament>[];
      }

      final docs = await Future.wait(
        tournamentIds.map((id) => _col.doc(id).get()),
      );
      final tournaments = _mapTournamentDocs(
        docs.where((doc) => doc.exists && doc.data() != null),
      );
      tournaments.sort(
        (left, right) => right.createdAt.compareTo(left.createdAt),
      );
      return tournaments;
    });
  }

  @override
  Future<bool> isFollowingTournament(String tournamentId, String userId) async {
    return FirebaseErrorHandler.guard(() async {
      final doc = await _followersRef(tournamentId).doc(userId).get();
      return doc.exists;
    });
  }

  @override
  Future<void> followTournament(String tournamentId, String userId) async {
    return FirebaseErrorHandler.guard(() async {
      await _followersRef(tournamentId).doc(userId).set({
        'tournamentId': tournamentId,
        'userId': userId,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  @override
  Future<void> unfollowTournament(String tournamentId, String userId) async {
    return FirebaseErrorHandler.guard(() async {
      await _followersRef(tournamentId).doc(userId).delete();
    });
  }

  @override
  Future<void> registerTeam(String tournamentId, String teamId) async {
    return FirebaseErrorHandler.guard(() async {
      await _col.doc(tournamentId).update({
        'registeredTeamIds': FieldValue.arrayUnion([teamId]),
      });
    });
  }

  @override
  Future<void> unregisterTeam(String tournamentId, String teamId) async {
    return FirebaseErrorHandler.guard(() async {
      await _col.doc(tournamentId).update({
        'registeredTeamIds': FieldValue.arrayRemove([teamId]),
      });
    });
  }

  List<Tournament> _mapTournamentDocs(Iterable<DocumentSnapshot> docs) {
    return docs
        .map(
          (d) => TournamentModel.fromJson(
            d.data()! as Map<String, dynamic>,
            d.id,
          ).toEntity(),
        )
        .toList(growable: true);
  }
}

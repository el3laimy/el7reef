import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errors/firebase_error_handler.dart';
import '../../core/constants/firebase_paths.dart';
import '../../domain/entities/tournament_registration.dart';
import '../../domain/repositories/tournament_registration_repository.dart';
import '../models/tournament_registration_model.dart';

class TournamentRegistrationRepositoryImpl
    implements TournamentRegistrationRepository {
  final FirebaseFirestore _firestore;

  TournamentRegistrationRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _registrationsRef =>
      _firestore.collection(FirebasePaths.tournamentRegistrations);

  @override
  Future<TournamentRegistration?> getRegistration(String registrationId) async {
    return FirebaseErrorHandler.guard(() async {
      final doc = await _registrationsRef.doc(registrationId).get();
      if (!doc.exists || doc.data() == null) {
        return null;
      }
      return TournamentRegistrationModel.fromJson(doc.data()!, doc.id).toEntity();
    });
  }

  @override
  Future<void> createRegistration(TournamentRegistration registration) async {
    return FirebaseErrorHandler.guard(() async {
      final model = TournamentRegistrationModel.fromEntity(registration);
      await _registrationsRef.doc(registration.id).set(model.toJson());
    });
  }

  @override
  Future<void> updateRegistration(TournamentRegistration registration) async {
    return FirebaseErrorHandler.guard(() async {
      final model = TournamentRegistrationModel.fromEntity(registration);
      await _registrationsRef.doc(registration.id).update(model.toJson());
    });
  }

  @override
  Future<List<TournamentRegistration>> getTournamentRegistrations(
    String tournamentId,
  ) async {
    return FirebaseErrorHandler.guard(() async {
      final snapshot = await _registrationsRef
          .where('tournamentId', isEqualTo: tournamentId)
          .get();
      final registrations = snapshot.docs
          .map((doc) => TournamentRegistrationModel.fromJson(doc.data(), doc.id).toEntity())
          .toList(growable: true);
      registrations.sort((left, right) => left.createdAt.compareTo(right.createdAt));
      return registrations;
    });
  }

  @override
  Future<List<TournamentRegistration>> getApprovedTournamentRegistrations(
    String tournamentId,
  ) async {
    return FirebaseErrorHandler.guard(() async {
      final snapshot = await _registrationsRef
          .where('tournamentId', isEqualTo: tournamentId)
          .where('status', isEqualTo: 'approved')
          .get();
      final registrations = snapshot.docs
          .map((doc) => TournamentRegistrationModel.fromJson(doc.data(), doc.id).toEntity())
          .toList(growable: true);
      registrations.sort((left, right) => left.updatedAt.compareTo(right.updatedAt));
      return registrations;
    });
  }

  @override
  Future<List<TournamentRegistration>> getTournamentRegistrationsForTeamIds({
    required String tournamentId,
    required List<String> teamIds,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      final normalizedTeamIds = teamIds
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList(growable: false);
      if (normalizedTeamIds.isEmpty) {
        return const <TournamentRegistration>[];
      }

      final byId = <String, TournamentRegistration>{};
      for (final chunk in _chunkIds(normalizedTeamIds)) {
        final snapshot = await _registrationsRef
            .where('tournamentId', isEqualTo: tournamentId)
            .where('teamId', whereIn: chunk)
            .get();
        for (final doc in snapshot.docs) {
          byId[doc.id] = TournamentRegistrationModel.fromJson(doc.data(), doc.id).toEntity();
        }
      }
      final registrations = byId.values.toList(growable: true);
      registrations.sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
      return registrations;
    });
  }

  @override
  Future<TournamentRegistration?> getRegistrationByTeamId({
    required String tournamentId,
    required String teamId,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      final snapshot = await _registrationsRef
          .where('tournamentId', isEqualTo: tournamentId)
          .where('teamId', isEqualTo: teamId)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) {
        return null;
      }
      final doc = snapshot.docs.first;
      return TournamentRegistrationModel.fromJson(doc.data(), doc.id).toEntity();
    });
  }

  @override
  Future<TournamentRegistration?> getRegistrationByGuestTeamId({
    required String tournamentId,
    required String guestTeamId,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      final snapshot = await _registrationsRef
          .where('tournamentId', isEqualTo: tournamentId)
          .where('guestTeamId', isEqualTo: guestTeamId)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) {
        return null;
      }
      final doc = snapshot.docs.first;
      return TournamentRegistrationModel.fromJson(doc.data(), doc.id).toEntity();
    });
  }

  @override
  Future<List<TournamentRegistration>> getRegistrationsByTeamId(
    String teamId,
  ) async {
    return FirebaseErrorHandler.guard(() async {
      final snapshot = await _registrationsRef.where('teamId', isEqualTo: teamId).get();
      final registrations = snapshot.docs
          .map((doc) => TournamentRegistrationModel.fromJson(doc.data(), doc.id).toEntity())
          .toList(growable: true);
      registrations.sort((left, right) => right.createdAt.compareTo(left.createdAt));
      return registrations;
    });
  }

  @override
  Future<List<TournamentRegistration>> getRegistrationsByGuestTeamId(
    String guestTeamId,
  ) async {
    return FirebaseErrorHandler.guard(() async {
      final snapshot =
          await _registrationsRef.where('guestTeamId', isEqualTo: guestTeamId).get();
      final registrations = snapshot.docs
          .map((doc) => TournamentRegistrationModel.fromJson(doc.data(), doc.id).toEntity())
          .toList(growable: true);
      registrations.sort((left, right) => right.createdAt.compareTo(left.createdAt));
      return registrations;
    });
  }

  List<List<String>> _chunkIds(List<String> ids) {
    const chunkSize = 10;
    final chunks = <List<String>>[];
    for (var i = 0; i < ids.length; i += chunkSize) {
      final end = i + chunkSize > ids.length ? ids.length : i + chunkSize;
      chunks.add(ids.sublist(i, end));
    }
    return chunks;
  }
}

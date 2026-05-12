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
}

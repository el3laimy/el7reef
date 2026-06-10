import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firebase_paths.dart';
import '../../core/enums/tournament_enums.dart';
import '../../core/enums/tournament_ops_enums.dart';
import '../../data/models/tournament_model.dart';
import '../../data/models/tournament_registration_model.dart';
import '../../domain/entities/tournament.dart';
import '../../domain/entities/tournament_registration.dart';
import '../utils/app_logger.dart';
import 'tournament_participant_service.dart';

class TournamentOpsMigrationReport {
  final String tournamentId;
  final int approvedRegistrationsBackfilled;
  final int legacyTeamsBackfilled;
  final int totalParticipants;
  final bool needsManualOpsMigration;

  const TournamentOpsMigrationReport({
    required this.tournamentId,
    required this.approvedRegistrationsBackfilled,
    required this.legacyTeamsBackfilled,
    required this.totalParticipants,
    required this.needsManualOpsMigration,
  });
}

class TournamentOpsMigrationService {
  final FirebaseFirestore _firestore;
  final TournamentParticipantService _participantService;

  TournamentOpsMigrationService({
    FirebaseFirestore? firestore,
    TournamentParticipantService? participantService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _participantService =
           participantService ??
           TournamentParticipantService(firestore: firestore);

  CollectionReference<Map<String, dynamic>> get _tournamentsRef =>
      _firestore.collection(FirebasePaths.tournaments);
  CollectionReference<Map<String, dynamic>> get _registrationsRef =>
      _firestore.collection(FirebasePaths.tournamentRegistrations);

  Future<TournamentOpsMigrationReport> backfillTournament({
    required String tournamentId,
    String actorId = 'system::migration',
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final tournament = await _loadTournament(tournamentId);
    final registrations = await _loadRegistrations(tournamentId);
    var approvedRegistrationsBackfilled = 0;
    for (final registration in registrations.where(
      (value) => value.status.name == 'approved',
    )) {
      await _participantService.syncApprovedRegistration(
        registration: registration,
        actorId: actorId,
        now: effectiveNow,
        refreshTournamentSummary: false,
      );
      approvedRegistrationsBackfilled += 1;
    }

    var legacyTeamsBackfilled = 0;
    for (final teamId in tournament.registeredTeamIds) {
      try {
        await _participantService.addManualParticipant(
          tournamentId: tournamentId,
          sourceType: TournamentParticipantSourceType.registeredTeam,
          sourceEntityId: teamId,
          actorId: actorId,
          now: effectiveNow,
          refreshTournamentSummary: false,
        );
        legacyTeamsBackfilled += 1;
      } catch (error) {
        AppLogger.warning(
          'TournamentOpsMigrationService.backfillTournament.legacyTeam',
          error,
        );
        // The participant already exists or the source is invalid; keep the
        // migration idempotent and continue.
      }
    }
    final activeParticipantCount = await _participantService
        .refreshTournamentParticipantSummary(tournamentId: tournamentId);
    final needsManualOpsMigration =
        tournament.status != TournamentStatus.registration &&
        tournament.currentGroupStageId == null &&
        tournament.currentKnockoutBracketId == null;
    if (tournament.needsManualOpsMigration != needsManualOpsMigration) {
      final updatedTournament = tournament.copyWith(
        needsManualOpsMigration: needsManualOpsMigration,
      );
      await _tournamentsRef
          .doc(tournamentId)
          .update(TournamentModel.fromEntity(updatedTournament).toJson());
    }

    return TournamentOpsMigrationReport(
      tournamentId: tournamentId,
      approvedRegistrationsBackfilled: approvedRegistrationsBackfilled,
      legacyTeamsBackfilled: legacyTeamsBackfilled,
      totalParticipants: activeParticipantCount,
      needsManualOpsMigration: needsManualOpsMigration,
    );
  }

  Future<Tournament> _loadTournament(String tournamentId) async {
    final snapshot = await _tournamentsRef.doc(tournamentId).get();
    if (!snapshot.exists || snapshot.data() == null) {
      throw Exception('تعذر العثور على البطولة المطلوبة للمهاجرة.');
    }
    return TournamentModel.fromJson(snapshot.data()!, snapshot.id).toEntity();
  }

  Future<List<TournamentRegistration>> _loadRegistrations(
    String tournamentId,
  ) async {
    final snapshot = await _registrationsRef
        .where('tournamentId', isEqualTo: tournamentId)
        .get();
    return snapshot.docs
        .map(
          (doc) => TournamentRegistrationModel.fromJson(
            doc.data(),
            doc.id,
          ).toEntity(),
        )
        .toList(growable: false);
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firebase_paths.dart';
import '../../core/enums/tournament_registration_mode.dart';
import '../../core/enums/tournament_registration_status.dart';
import '../../core/enums/tournament_enums.dart';
import '../../data/models/guest_team_model.dart';
import '../../data/models/team_model.dart';
import '../../data/models/tournament_model.dart';
import '../../data/models/tournament_registration_model.dart';
import '../../domain/entities/guest_team.dart';
import '../../domain/entities/team.dart';
import '../../domain/entities/tournament.dart';
import '../../domain/entities/tournament_registration.dart';
import 'tournament_participant_service.dart';

enum TournamentRegistrationOutcome {
  approved,
  pendingApproval,
  alreadyApproved,
  alreadyPending,
  rejected,
  alreadyRejected,
}

class TournamentRegistrationResult {
  final TournamentRegistrationOutcome outcome;
  final TournamentRegistration registration;
  final bool syncedTournamentTeamIds;
  final bool syncedParticipantTournamentIds;

  const TournamentRegistrationResult({
    required this.outcome,
    required this.registration,
    this.syncedTournamentTeamIds = false,
    this.syncedParticipantTournamentIds = false,
  });

  bool get isIdempotent =>
      outcome == TournamentRegistrationOutcome.alreadyApproved ||
      outcome == TournamentRegistrationOutcome.alreadyPending ||
      outcome == TournamentRegistrationOutcome.alreadyRejected;
}

class TournamentRegistrationService {
  final FirebaseFirestore _firestore;
  late final TournamentParticipantService _participantService;

  TournamentRegistrationService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance {
    _participantService = TournamentParticipantService(firestore: _firestore);
  }

  CollectionReference<Map<String, dynamic>> get _tournamentsRef =>
      _firestore.collection(FirebasePaths.tournaments);

  CollectionReference<Map<String, dynamic>> get _teamsRef =>
      _firestore.collection(FirebasePaths.teams);

  CollectionReference<Map<String, dynamic>> get _guestTeamsRef =>
      _firestore.collection(FirebasePaths.guestTeams);

  CollectionReference<Map<String, dynamic>> get _registrationsRef =>
      _firestore.collection(FirebasePaths.tournamentRegistrations);

  Future<TournamentRegistrationResult> registerTeam({
    required String tournamentId,
    required String teamId,
    required String actorId,
    TournamentRegistrationMode mode = TournamentRegistrationMode.hybrid,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final policyRegistrations = await _loadTournamentRegistrationsForPolicy(
      tournamentId,
    );
    final registrationRef = _registrationsRef.doc(
      _teamRegistrationId(tournamentId, teamId),
    );
    final tournamentRef = _tournamentsRef.doc(tournamentId);
    final teamRef = _teamsRef.doc(teamId);

    final result = await _firestore.runTransaction((transaction) async {
      final tournamentSnapshot = await transaction.get(tournamentRef);
      if (!tournamentSnapshot.exists || tournamentSnapshot.data() == null) {
        throw Exception('الدورة المطلوبة غير موجودة.');
      }
      final tournament = TournamentModel.fromJson(
        tournamentSnapshot.data()!,
        tournamentSnapshot.id,
      ).toEntity();

      final teamSnapshot = await transaction.get(teamRef);
      if (!teamSnapshot.exists || teamSnapshot.data() == null) {
        throw Exception('الفريق المسجل المطلوب غير موجود.');
      }
      final team = TeamModel.fromJson(
        teamSnapshot.data()!,
        teamSnapshot.id,
      ).toEntity();

      final isOrganizer = tournament.organizerId == actorId;
      final ownsTeam = team.ownerId == actorId;
      if (!isOrganizer && !ownsTeam) {
        throw Exception('لا تملك صلاحية تسجيل هذا الفريق في الدورة.');
      }
      _ensureRegistrationIsOpen(tournament, currentTime: effectiveNow);

      final registrationSnapshot = await transaction.get(registrationRef);
      final existingRegistration =
          registrationSnapshot.exists && registrationSnapshot.data() != null
          ? TournamentRegistrationModel.fromJson(
              registrationSnapshot.data()!,
              registrationSnapshot.id,
            ).toEntity()
          : null;

      final targetStatus = _resolveRegisteredTeamTargetStatus(
        mode: mode,
        isOrganizer: isOrganizer,
      );
      _assertCapacityAvailable(
        tournament: tournament,
        policyRegistrations: policyRegistrations,
        registrationId: registrationRef.id,
        nextStatus: targetStatus,
      );

      if (existingRegistration != null) {
        final updatedExisting = existingRegistration.copyWith(
          teamId: team.id,
          guestTeamId: null,
          mode: mode,
          status: targetStatus,
          updatedAt: effectiveNow,
        );

        if (existingRegistration.status ==
            TournamentRegistrationStatus.approved) {
          final syncResult = _syncApprovedRegisteredTeam(
            transaction: transaction,
            tournament: tournament,
            team: team,
            tournamentRef: tournamentRef,
            teamRef: teamRef,
          );
          return TournamentRegistrationResult(
            outcome: TournamentRegistrationOutcome.alreadyApproved,
            registration: updatedExisting,
            syncedTournamentTeamIds: syncResult.syncedTournamentTeamIds,
            syncedParticipantTournamentIds:
                syncResult.syncedParticipantTournamentIds,
          );
        }
        if (existingRegistration.status ==
                TournamentRegistrationStatus.pending &&
            targetStatus == TournamentRegistrationStatus.pending) {
          return TournamentRegistrationResult(
            outcome: TournamentRegistrationOutcome.alreadyPending,
            registration: updatedExisting,
          );
        }

        final promotedRegistration = updatedExisting.copyWith(
          verifiedBy: isOrganizer ? actorId : existingRegistration.verifiedBy,
          verifiedAt: isOrganizer
              ? effectiveNow
              : existingRegistration.verifiedAt,
        );
        transaction.update(
          registrationRef,
          TournamentRegistrationModel.fromEntity(promotedRegistration).toJson(),
        );

        if (targetStatus == TournamentRegistrationStatus.pending) {
          return TournamentRegistrationResult(
            outcome: TournamentRegistrationOutcome.pendingApproval,
            registration: promotedRegistration,
          );
        }

        final syncResult = _syncApprovedRegisteredTeam(
          transaction: transaction,
          tournament: tournament,
          team: team,
          tournamentRef: tournamentRef,
          teamRef: teamRef,
        );
        return TournamentRegistrationResult(
          outcome: TournamentRegistrationOutcome.approved,
          registration: promotedRegistration,
          syncedTournamentTeamIds: syncResult.syncedTournamentTeamIds,
          syncedParticipantTournamentIds:
              syncResult.syncedParticipantTournamentIds,
        );
      }

      final registration = TournamentRegistration(
        id: registrationRef.id,
        tournamentId: tournamentId,
        teamId: teamId,
        mode: mode,
        status: targetStatus,
        createdBy: actorId,
        createdAt: effectiveNow,
        updatedAt: effectiveNow,
        verifiedBy: isOrganizer ? actorId : null,
        verifiedAt: isOrganizer ? effectiveNow : null,
      );
      transaction.set(
        registrationRef,
        TournamentRegistrationModel.fromEntity(registration).toJson(),
      );

      if (targetStatus == TournamentRegistrationStatus.pending) {
        return TournamentRegistrationResult(
          outcome: TournamentRegistrationOutcome.pendingApproval,
          registration: registration,
        );
      }

      final syncResult = _syncApprovedRegisteredTeam(
        transaction: transaction,
        tournament: tournament,
        team: team,
        tournamentRef: tournamentRef,
        teamRef: teamRef,
      );
      return TournamentRegistrationResult(
        outcome: TournamentRegistrationOutcome.approved,
        registration: registration,
        syncedTournamentTeamIds: syncResult.syncedTournamentTeamIds,
        syncedParticipantTournamentIds:
            syncResult.syncedParticipantTournamentIds,
      );
    });
    await _syncParticipantForApprovedResult(
      result: result,
      actorId: actorId,
      now: effectiveNow,
    );
    return result;
  }

  Future<TournamentRegistrationResult> registerGuestTeam({
    required String tournamentId,
    required String guestTeamId,
    required String actorId,
    TournamentRegistrationMode mode = TournamentRegistrationMode.hybrid,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final policyRegistrations = await _loadTournamentRegistrationsForPolicy(
      tournamentId,
    );
    final registrationRef = _registrationsRef.doc(
      _guestTeamRegistrationId(tournamentId, guestTeamId),
    );
    final tournamentRef = _tournamentsRef.doc(tournamentId);
    final guestTeamRef = _guestTeamsRef.doc(guestTeamId);

    final result = await _firestore.runTransaction((transaction) async {
      final tournamentSnapshot = await transaction.get(tournamentRef);
      if (!tournamentSnapshot.exists || tournamentSnapshot.data() == null) {
        throw Exception('الدورة المطلوبة غير موجودة.');
      }
      final tournament = TournamentModel.fromJson(
        tournamentSnapshot.data()!,
        tournamentSnapshot.id,
      ).toEntity();

      final guestTeamSnapshot = await transaction.get(guestTeamRef);
      if (!guestTeamSnapshot.exists || guestTeamSnapshot.data() == null) {
        throw Exception('الفريق الضيف المطلوب غير موجود.');
      }
      final guestTeam = GuestTeamModel.fromJson(
        guestTeamSnapshot.data()!,
        guestTeamSnapshot.id,
      ).toEntity();

      final isOrganizer = tournament.organizerId == actorId;
      final ownsGuestTeam = guestTeam.creatorId == actorId;
      if (!isOrganizer && !ownsGuestTeam) {
        throw Exception('لا تملك صلاحية تسجيل هذا الفريق الضيف في الدورة.');
      }
      _ensureRegistrationIsOpen(tournament, currentTime: effectiveNow);
      _ensureGuestTeamModeEligibility(
        guestTeam: guestTeam,
        mode: mode,
        isOrganizer: isOrganizer,
      );

      final targetStatus = _resolveGuestTeamTargetStatus(
        mode: mode,
        isOrganizer: isOrganizer,
      );

      final registrationSnapshot = await transaction.get(registrationRef);
      final existingRegistration =
          registrationSnapshot.exists && registrationSnapshot.data() != null
          ? TournamentRegistrationModel.fromJson(
              registrationSnapshot.data()!,
              registrationSnapshot.id,
            ).toEntity()
          : null;
      _assertCapacityAvailable(
        tournament: tournament,
        policyRegistrations: policyRegistrations,
        registrationId: registrationRef.id,
        nextStatus: targetStatus,
      );

      if (existingRegistration != null) {
        if (existingRegistration.status ==
            TournamentRegistrationStatus.approved) {
          final syncResult = _syncApprovedGuestTeam(
            transaction: transaction,
            guestTeam: guestTeam,
            tournamentId: tournamentId,
            guestTeamRef: guestTeamRef,
          );
          return TournamentRegistrationResult(
            outcome: TournamentRegistrationOutcome.alreadyApproved,
            registration: existingRegistration,
            syncedParticipantTournamentIds:
                syncResult.syncedParticipantTournamentIds,
          );
        }

        if (existingRegistration.status ==
                TournamentRegistrationStatus.rejected &&
            targetStatus == TournamentRegistrationStatus.rejected) {
          return TournamentRegistrationResult(
            outcome: TournamentRegistrationOutcome.alreadyRejected,
            registration: existingRegistration,
          );
        }

        if (existingRegistration.status ==
                TournamentRegistrationStatus.pending &&
            targetStatus == TournamentRegistrationStatus.pending) {
          return TournamentRegistrationResult(
            outcome: TournamentRegistrationOutcome.alreadyPending,
            registration: existingRegistration,
          );
        }

        final updatedRegistration = existingRegistration.copyWith(
          guestTeamId: guestTeam.id,
          teamId: null,
          mode: mode,
          status: targetStatus,
          updatedAt: effectiveNow,
          verifiedBy:
              targetStatus == TournamentRegistrationStatus.approved &&
                  isOrganizer
              ? actorId
              : null,
          verifiedAt:
              targetStatus == TournamentRegistrationStatus.approved &&
                  isOrganizer
              ? effectiveNow
              : null,
        );
        transaction.update(
          registrationRef,
          TournamentRegistrationModel.fromEntity(updatedRegistration).toJson(),
        );

        if (targetStatus == TournamentRegistrationStatus.approved) {
          final syncResult = _syncApprovedGuestTeam(
            transaction: transaction,
            guestTeam: guestTeam,
            tournamentId: tournamentId,
            guestTeamRef: guestTeamRef,
          );
          return TournamentRegistrationResult(
            outcome: TournamentRegistrationOutcome.approved,
            registration: updatedRegistration,
            syncedParticipantTournamentIds:
                syncResult.syncedParticipantTournamentIds,
          );
        }

        return TournamentRegistrationResult(
          outcome: TournamentRegistrationOutcome.pendingApproval,
          registration: updatedRegistration,
        );
      }

      final registration = TournamentRegistration(
        id: registrationRef.id,
        tournamentId: tournamentId,
        guestTeamId: guestTeamId,
        mode: mode,
        status: targetStatus,
        createdBy: actorId,
        createdAt: effectiveNow,
        updatedAt: effectiveNow,
        verifiedBy:
            targetStatus == TournamentRegistrationStatus.approved && isOrganizer
            ? actorId
            : null,
        verifiedAt:
            targetStatus == TournamentRegistrationStatus.approved && isOrganizer
            ? effectiveNow
            : null,
      );
      transaction.set(
        registrationRef,
        TournamentRegistrationModel.fromEntity(registration).toJson(),
      );

      if (targetStatus == TournamentRegistrationStatus.approved) {
        final syncResult = _syncApprovedGuestTeam(
          transaction: transaction,
          guestTeam: guestTeam,
          tournamentId: tournamentId,
          guestTeamRef: guestTeamRef,
        );
        return TournamentRegistrationResult(
          outcome: TournamentRegistrationOutcome.approved,
          registration: registration,
          syncedParticipantTournamentIds:
              syncResult.syncedParticipantTournamentIds,
        );
      }

      return TournamentRegistrationResult(
        outcome: TournamentRegistrationOutcome.pendingApproval,
        registration: registration,
      );
    });
    await _syncParticipantForApprovedResult(
      result: result,
      actorId: actorId,
      now: effectiveNow,
    );
    return result;
  }

  Future<TournamentRegistrationResult> approveRegistration({
    required String registrationId,
    required String actorId,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final preflightRegistration = await _getRegistrationForPolicy(
      registrationId,
    );
    final policyRegistrations = await _loadTournamentRegistrationsForPolicy(
      preflightRegistration.tournamentId,
    );
    final registrationRef = _registrationsRef.doc(registrationId);

    final result = await _firestore.runTransaction((transaction) async {
      final registrationSnapshot = await transaction.get(registrationRef);
      if (!registrationSnapshot.exists || registrationSnapshot.data() == null) {
        throw Exception('سجل التسجيل المطلوب غير موجود.');
      }
      final registration = TournamentRegistrationModel.fromJson(
        registrationSnapshot.data()!,
        registrationSnapshot.id,
      ).toEntity();

      final tournamentRef = _tournamentsRef.doc(registration.tournamentId);
      final tournamentSnapshot = await transaction.get(tournamentRef);
      if (!tournamentSnapshot.exists || tournamentSnapshot.data() == null) {
        throw Exception('الدورة المرتبطة بهذا التسجيل غير موجودة.');
      }
      final tournament = TournamentModel.fromJson(
        tournamentSnapshot.data()!,
        tournamentSnapshot.id,
      ).toEntity();
      if (tournament.organizerId != actorId) {
        throw Exception('لا تملك صلاحية اعتماد هذا التسجيل.');
      }

      if (registration.status == TournamentRegistrationStatus.approved) {
        if (registration.teamId != null) {
          final teamRef = _teamsRef.doc(registration.teamId);
          final teamSnapshot = await transaction.get(teamRef);
          if (!teamSnapshot.exists || teamSnapshot.data() == null) {
            throw Exception('الفريق المسجل المرتبط بالتسجيل غير موجود.');
          }
          final team = TeamModel.fromJson(
            teamSnapshot.data()!,
            teamSnapshot.id,
          ).toEntity();
          final syncResult = _syncApprovedRegisteredTeam(
            transaction: transaction,
            tournament: tournament,
            team: team,
            tournamentRef: tournamentRef,
            teamRef: teamRef,
          );
          return TournamentRegistrationResult(
            outcome: TournamentRegistrationOutcome.alreadyApproved,
            registration: registration,
            syncedTournamentTeamIds: syncResult.syncedTournamentTeamIds,
            syncedParticipantTournamentIds:
                syncResult.syncedParticipantTournamentIds,
          );
        }

        final guestTeamRef = _guestTeamsRef.doc(registration.guestTeamId);
        final guestTeamSnapshot = await transaction.get(guestTeamRef);
        if (!guestTeamSnapshot.exists || guestTeamSnapshot.data() == null) {
          throw Exception('الفريق الضيف المرتبط بالتسجيل غير موجود.');
        }
        final guestTeam = GuestTeamModel.fromJson(
          guestTeamSnapshot.data()!,
          guestTeamSnapshot.id,
        ).toEntity();
        final syncResult = _syncApprovedGuestTeam(
          transaction: transaction,
          guestTeam: guestTeam,
          tournamentId: registration.tournamentId,
          guestTeamRef: guestTeamRef,
        );
        return TournamentRegistrationResult(
          outcome: TournamentRegistrationOutcome.alreadyApproved,
          registration: registration,
          syncedParticipantTournamentIds:
              syncResult.syncedParticipantTournamentIds,
        );
      }

      _ensureRegistrationIsOpen(
        tournament,
        currentTime: effectiveNow,
        errorMessage: 'لا يمكن اعتماد التسجيل بعد إغلاق نافذة التسجيل.',
      );

      _assertCapacityAvailable(
        tournament: tournament,
        policyRegistrations: policyRegistrations,
        registrationId: registration.id,
        nextStatus: TournamentRegistrationStatus.approved,
      );

      final approvedRegistration = registration.copyWith(
        status: TournamentRegistrationStatus.approved,
        verifiedBy: actorId,
        verifiedAt: effectiveNow,
        updatedAt: effectiveNow,
      );

      if (approvedRegistration.teamId != null) {
        final teamRef = _teamsRef.doc(approvedRegistration.teamId);
        final teamSnapshot = await transaction.get(teamRef);
        if (!teamSnapshot.exists || teamSnapshot.data() == null) {
          throw Exception('الفريق المسجل المرتبط بالتسجيل غير موجود.');
        }
        final team = TeamModel.fromJson(
          teamSnapshot.data()!,
          teamSnapshot.id,
        ).toEntity();
        transaction.update(
          registrationRef,
          TournamentRegistrationModel.fromEntity(approvedRegistration).toJson(),
        );
        final syncResult = _syncApprovedRegisteredTeam(
          transaction: transaction,
          tournament: tournament,
          team: team,
          tournamentRef: tournamentRef,
          teamRef: teamRef,
        );
        return TournamentRegistrationResult(
          outcome: TournamentRegistrationOutcome.approved,
          registration: approvedRegistration,
          syncedTournamentTeamIds: syncResult.syncedTournamentTeamIds,
          syncedParticipantTournamentIds:
              syncResult.syncedParticipantTournamentIds,
        );
      }

      final guestTeamRef = _guestTeamsRef.doc(approvedRegistration.guestTeamId);
      final guestTeamSnapshot = await transaction.get(guestTeamRef);
      if (!guestTeamSnapshot.exists || guestTeamSnapshot.data() == null) {
        throw Exception('الفريق الضيف المرتبط بالتسجيل غير موجود.');
      }
      final guestTeam = GuestTeamModel.fromJson(
        guestTeamSnapshot.data()!,
        guestTeamSnapshot.id,
      ).toEntity();
      _ensureGuestTeamModeEligibility(
        guestTeam: guestTeam,
        mode: approvedRegistration.mode,
        isOrganizer: true,
      );
      transaction.update(
        registrationRef,
        TournamentRegistrationModel.fromEntity(approvedRegistration).toJson(),
      );
      final syncResult = _syncApprovedGuestTeam(
        transaction: transaction,
        guestTeam: guestTeam,
        tournamentId: approvedRegistration.tournamentId,
        guestTeamRef: guestTeamRef,
      );
      return TournamentRegistrationResult(
        outcome: TournamentRegistrationOutcome.approved,
        registration: approvedRegistration,
        syncedParticipantTournamentIds:
            syncResult.syncedParticipantTournamentIds,
      );
    });
    await _syncParticipantForApprovedResult(
      result: result,
      actorId: actorId,
      now: effectiveNow,
    );
    return result;
  }

  Future<TournamentRegistrationResult> rejectRegistration({
    required String registrationId,
    required String actorId,
    String? notes,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final registrationRef = _registrationsRef.doc(registrationId);

    return _firestore.runTransaction((transaction) async {
      final registrationSnapshot = await transaction.get(registrationRef);
      if (!registrationSnapshot.exists || registrationSnapshot.data() == null) {
        throw Exception('سجل التسجيل المطلوب غير موجود.');
      }
      final registration = TournamentRegistrationModel.fromJson(
        registrationSnapshot.data()!,
        registrationSnapshot.id,
      ).toEntity();

      final tournamentRef = _tournamentsRef.doc(registration.tournamentId);
      final tournamentSnapshot = await transaction.get(tournamentRef);
      if (!tournamentSnapshot.exists || tournamentSnapshot.data() == null) {
        throw Exception('الدورة المرتبطة بهذا التسجيل غير موجودة.');
      }
      final tournament = TournamentModel.fromJson(
        tournamentSnapshot.data()!,
        tournamentSnapshot.id,
      ).toEntity();
      if (tournament.organizerId != actorId) {
        throw Exception('لا تملك صلاحية رفض هذا التسجيل.');
      }

      if (registration.status == TournamentRegistrationStatus.rejected) {
        return TournamentRegistrationResult(
          outcome: TournamentRegistrationOutcome.alreadyRejected,
          registration: registration,
        );
      }
      if (registration.status == TournamentRegistrationStatus.approved) {
        throw Exception('لا يمكن رفض تسجيل تمت الموافقة عليه بالفعل.');
      }

      final rejectedRegistration = registration.copyWith(
        status: TournamentRegistrationStatus.rejected,
        updatedAt: effectiveNow,
        notes: notes ?? registration.notes,
        verifiedBy: actorId,
        verifiedAt: effectiveNow,
      );
      transaction.update(
        registrationRef,
        TournamentRegistrationModel.fromEntity(rejectedRegistration).toJson(),
      );

      return TournamentRegistrationResult(
        outcome: TournamentRegistrationOutcome.rejected,
        registration: rejectedRegistration,
      );
    });
  }

  Future<void> _syncParticipantForApprovedResult({
    required TournamentRegistrationResult result,
    required String actorId,
    required DateTime now,
  }) async {
    if (result.registration.status != TournamentRegistrationStatus.approved) {
      return;
    }
    await _participantService.syncApprovedRegistration(
      registration: result.registration,
      actorId: actorId,
      now: now,
    );
  }

  String _teamRegistrationId(String tournamentId, String teamId) {
    return 'team::$tournamentId::$teamId';
  }

  String _guestTeamRegistrationId(String tournamentId, String guestTeamId) {
    return 'guest::$tournamentId::$guestTeamId';
  }

  TournamentRegistrationStatus _resolveRegisteredTeamTargetStatus({
    required TournamentRegistrationMode mode,
    required bool isOrganizer,
  }) {
    return switch (mode) {
      TournamentRegistrationMode.quick || TournamentRegistrationMode.hybrid =>
        TournamentRegistrationStatus.approved,
      TournamentRegistrationMode.verified when isOrganizer =>
        TournamentRegistrationStatus.approved,
      TournamentRegistrationMode.verified =>
        TournamentRegistrationStatus.pending,
    };
  }

  TournamentRegistrationStatus _resolveGuestTeamTargetStatus({
    required TournamentRegistrationMode mode,
    required bool isOrganizer,
  }) {
    return switch (mode) {
      TournamentRegistrationMode.quick when isOrganizer =>
        TournamentRegistrationStatus.approved,
      TournamentRegistrationMode.quick => TournamentRegistrationStatus.pending,
      TournamentRegistrationMode.hybrid => TournamentRegistrationStatus.pending,
      TournamentRegistrationMode.verified when isOrganizer =>
        TournamentRegistrationStatus.approved,
      TournamentRegistrationMode.verified =>
        TournamentRegistrationStatus.pending,
    };
  }

  void _ensureRegistrationIsOpen(
    Tournament tournament, {
    required DateTime currentTime,
    String errorMessage = 'التسجيل في هذه الدورة مغلق حاليًا.',
  }) {
    if (tournament.status != TournamentStatus.registration) {
      throw Exception(errorMessage);
    }

    final deadline = tournament.registrationDeadline;
    if (deadline != null && currentTime.isAfter(deadline)) {
      throw Exception(errorMessage);
    }
  }

  void _ensureGuestTeamModeEligibility({
    required GuestTeam guestTeam,
    required TournamentRegistrationMode mode,
    required bool isOrganizer,
  }) {
    if (mode == TournamentRegistrationMode.quick && !isOrganizer) {
      throw Exception('الوضع السريع لإضافة الفرق الضيفة مخصص للمنظم فقط.');
    }

    if (mode != TournamentRegistrationMode.verified) {
      return;
    }

    final hasContactName =
        guestTeam.contactName != null &&
        guestTeam.contactName!.trim().isNotEmpty;
    final hasContactPhone =
        guestTeam.contactPhone != null &&
        guestTeam.contactPhone!.trim().isNotEmpty;
    if (!hasContactName || !hasContactPhone) {
      throw Exception(
        'الوضع الموثق يتطلب اسم مسؤول التواصل ورقم هاتف صالح للفريق الضيف.',
      );
    }
  }

  Future<TournamentRegistration> _getRegistrationForPolicy(
    String registrationId,
  ) async {
    final snapshot = await _registrationsRef.doc(registrationId).get();
    if (!snapshot.exists || snapshot.data() == null) {
      throw Exception('سجل التسجيل المطلوب غير موجود.');
    }
    return TournamentRegistrationModel.fromJson(
      snapshot.data()!,
      snapshot.id,
    ).toEntity();
  }

  Future<List<TournamentRegistration>> _loadTournamentRegistrationsForPolicy(
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

  void _assertCapacityAvailable({
    required Tournament tournament,
    required List<TournamentRegistration> policyRegistrations,
    required String registrationId,
    required TournamentRegistrationStatus nextStatus,
  }) {
    if (!_statusConsumesCapacity(nextStatus)) {
      return;
    }

    final activeRegistrations = policyRegistrations
        .where((registration) => _statusConsumesCapacity(registration.status))
        .toList(growable: false);
    final pendingReservations = activeRegistrations
        .where(
          (registration) =>
              registration.status == TournamentRegistrationStatus.pending,
        )
        .length;
    final approvedRegistrations = activeRegistrations
        .where(
          (registration) =>
              registration.status == TournamentRegistrationStatus.approved,
        )
        .length;

    // Prefer canonical participant summary, then approved registrations,
    // and only fall back to legacy registeredTeamIds when the canonical
    // participant count is not available yet.
    var approvedReservedSlots = approvedRegistrations;
    final canonicalApprovedSlots = tournament.activeParticipantCount;
    if (canonicalApprovedSlots != null &&
        canonicalApprovedSlots > approvedReservedSlots) {
      approvedReservedSlots = canonicalApprovedSlots;
    } else if (canonicalApprovedSlots == null &&
        tournament.registeredTeamIds.length > approvedReservedSlots) {
      approvedReservedSlots = tournament.registeredTeamIds.length;
    }

    final reservedSlots = approvedReservedSlots + pendingReservations;
    final currentRegistrationAlreadyReservesSlot = policyRegistrations.any(
      (registration) =>
          registration.id == registrationId &&
          _statusConsumesCapacity(registration.status),
    );

    if (!currentRegistrationAlreadyReservesSlot &&
        reservedSlots >= tournament.maxTeams) {
      throw Exception('اكتملت سعة التسجيل لهذه الدورة.');
    }
  }

  bool _statusConsumesCapacity(TournamentRegistrationStatus status) {
    return status == TournamentRegistrationStatus.approved ||
        status == TournamentRegistrationStatus.pending;
  }

  _RegistrationSyncResult _syncApprovedRegisteredTeam({
    required Transaction transaction,
    required Tournament tournament,
    required Team team,
    required DocumentReference<Map<String, dynamic>> tournamentRef,
    required DocumentReference<Map<String, dynamic>> teamRef,
  }) {
    var syncedTournamentTeamIds = false;
    var syncedParticipantTournamentIds = false;

    if (!tournament.registeredTeamIds.contains(team.id)) {
      transaction.update(tournamentRef, {
        'registeredTeamIds': [...tournament.registeredTeamIds, team.id],
      });
      syncedTournamentTeamIds = true;
    }

    if (!team.tournamentIds.contains(tournament.id)) {
      transaction.update(teamRef, {
        'tournamentIds': [...team.tournamentIds, tournament.id],
      });
      syncedParticipantTournamentIds = true;
    }

    return _RegistrationSyncResult(
      syncedTournamentTeamIds: syncedTournamentTeamIds,
      syncedParticipantTournamentIds: syncedParticipantTournamentIds,
    );
  }

  _RegistrationSyncResult _syncApprovedGuestTeam({
    required Transaction transaction,
    required GuestTeam guestTeam,
    required String tournamentId,
    required DocumentReference<Map<String, dynamic>> guestTeamRef,
  }) {
    var syncedParticipantTournamentIds = false;
    if (!guestTeam.tournamentIds.contains(tournamentId)) {
      transaction.update(guestTeamRef, {
        'tournamentIds': [...guestTeam.tournamentIds, tournamentId],
      });
      syncedParticipantTournamentIds = true;
    }
    return _RegistrationSyncResult(
      syncedParticipantTournamentIds: syncedParticipantTournamentIds,
    );
  }
}

class _RegistrationSyncResult {
  final bool syncedTournamentTeamIds;
  final bool syncedParticipantTournamentIds;

  const _RegistrationSyncResult({
    this.syncedTournamentTeamIds = false,
    this.syncedParticipantTournamentIds = false,
  });
}

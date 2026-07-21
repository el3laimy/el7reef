import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firebase_paths.dart';
import '../../core/enums/claim_code_status.dart';
import '../../core/enums/claim_merge_conflict_type.dart';
import '../../core/enums/claim_target_type.dart';
import '../../data/models/claim_code_model.dart';
import '../../data/models/guest_player_model.dart';
import '../../data/models/guest_team_model.dart';
import '../../data/models/player_model.dart';
import '../../data/models/team_membership_model.dart';
import '../../data/models/team_model.dart';
import '../../domain/entities/claim_merge_conflict.dart';
import '../../domain/entities/guest_player.dart';
import '../../domain/entities/guest_team.dart';
import '../../domain/entities/player.dart';
import '../../domain/entities/team.dart';
import '../../domain/entities/team_membership.dart';
import 'analytics_service.dart';
import 'guest_claim_completion_reporter.dart';
import 'guest_claim_policy.dart';
import 'team_roster_policy.dart';

enum GuestPlayerClaimOutcome { claimed, alreadyClaimed, conflict }

class GuestPlayerClaimResult {
  final GuestPlayerClaimOutcome outcome;
  final String claimCode;
  final String guestPlayerId;
  final String playerId;
  final List<String> relinkedMembershipIds;
  final List<String> linkedTeamIds;
  final List<String> syncedLegacyTeamIds;
  final ClaimMergeConflict? conflict;

  const GuestPlayerClaimResult({
    required this.outcome,
    required this.claimCode,
    required this.guestPlayerId,
    required this.playerId,
    this.relinkedMembershipIds = const [],
    this.linkedTeamIds = const [],
    this.syncedLegacyTeamIds = const [],
    this.conflict,
  });

  bool get isIdempotent => outcome == GuestPlayerClaimOutcome.alreadyClaimed;
  bool get hasConflict =>
      outcome == GuestPlayerClaimOutcome.conflict && conflict != null;
}

enum GuestTeamClaimOutcome {
  claimed,
  alreadyClaimed,
  approvalRequired,
  conflict,
}

class GuestTeamClaimResult {
  final GuestTeamClaimOutcome outcome;
  final String claimCode;
  final String guestTeamId;
  final String teamId;
  final List<String> mergedTournamentIds;
  final String? requestedByPlayerId;
  final ClaimMergeConflict? conflict;

  const GuestTeamClaimResult({
    required this.outcome,
    required this.claimCode,
    required this.guestTeamId,
    required this.teamId,
    this.mergedTournamentIds = const [],
    this.requestedByPlayerId,
    this.conflict,
  });

  bool get isIdempotent => outcome == GuestTeamClaimOutcome.alreadyClaimed;
  bool get isPendingApproval =>
      outcome == GuestTeamClaimOutcome.approvalRequired;
  bool get hasConflict =>
      outcome == GuestTeamClaimOutcome.conflict && conflict != null;
}

class GuestClaimService {
  final FirebaseFirestore _firestore;
  final TeamRosterPolicy _teamRosterPolicy;
  final GuestClaimCompletionReporter _completionReporter;

  GuestClaimService({
    FirebaseFirestore? firestore,
    TeamRosterPolicy? teamRosterPolicy,
    AnalyticsService? analyticsService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _teamRosterPolicy = teamRosterPolicy ?? const TeamRosterPolicy(),
       _completionReporter = GuestClaimCompletionReporter(
         analyticsService ?? AnalyticsService(),
       );

  CollectionReference<Map<String, dynamic>> get _claimCodesRef =>
      _firestore.collection(FirebasePaths.claimCodes);

  CollectionReference<Map<String, dynamic>> get _guestPlayersRef =>
      _firestore.collection(FirebasePaths.guestPlayers);

  CollectionReference<Map<String, dynamic>> get _playersRef =>
      _firestore.collection(FirebasePaths.players);

  CollectionReference<Map<String, dynamic>> get _guestTeamsRef =>
      _firestore.collection(FirebasePaths.guestTeams);

  CollectionReference<Map<String, dynamic>> get _membershipsRef =>
      _firestore.collection(FirebasePaths.teamMemberships);

  CollectionReference<Map<String, dynamic>> get _teamsRef =>
      _firestore.collection(FirebasePaths.teams);

  Future<GuestPlayerClaimResult> claimGuestPlayer({
    required String claimCode,
    required String playerId,
    String? actorId,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final effectiveActorId = actorId ?? playerId;

    final claimRef = _claimCodesRef.doc(claimCode);
    final initialClaimSnapshot = await claimRef.get();
    if (!initialClaimSnapshot.exists || initialClaimSnapshot.data() == null) {
      throw Exception('رابط الاستلام المطلوب غير موجود.');
    }

    final initialClaim = ClaimCodeModel.fromJson(
      initialClaimSnapshot.data()!,
      initialClaimSnapshot.id,
    ).toEntity();
    GuestClaimTokenPolicy.assertTargetType(
      initialClaim,
      ClaimTargetType.guestPlayer,
    );

    if (GuestClaimTokenPolicy.shouldMarkExpired(initialClaim, effectiveNow)) {
      await claimRef.update({
        'status': ClaimCodeStatus.expired.name,
        'updatedAt': effectiveNow.millisecondsSinceEpoch,
      });
      throw Exception('انتهت صلاحية رابط الاستلام.');
    }

    final guestPlayerId = initialClaim.targetId;
    final initialGuestPlayerSnapshot = await _guestPlayersRef
        .doc(guestPlayerId)
        .get();
    if (!initialGuestPlayerSnapshot.exists ||
        initialGuestPlayerSnapshot.data() == null) {
      throw Exception('اللاعب الضيف المطلوب غير موجود.');
    }
    final initialGuestPlayer = GuestPlayerModel.fromJson(
      initialGuestPlayerSnapshot.data()!,
      initialGuestPlayerSnapshot.id,
    ).toEntity();

    final initialPlayerSnapshot = await _playersRef.doc(playerId).get();
    if (!initialPlayerSnapshot.exists || initialPlayerSnapshot.data() == null) {
      throw Exception('حساب اللاعب المطلوب غير موجود.');
    }

    if (initialGuestPlayer.isClaimed &&
        initialGuestPlayer.linkedPlayerId != null &&
        initialGuestPlayer.linkedPlayerId != playerId) {
      return _guestPlayerConflictResult(
        claimCode: initialClaim.code,
        guestPlayerId: initialGuestPlayer.id,
        playerId: playerId,
        conflict: ClaimMergeConflict(
          type: ClaimMergeConflictType.targetAlreadyLinked,
          message: 'تم استلام هذا اللاعب مسبقًا بواسطة حساب آخر.',
          conflictingEntityId: initialGuestPlayer.linkedPlayerId,
        ),
      );
    }

    final preflightConflict = await _detectGuestPlayerPreflightConflict(
      guestPlayer: initialGuestPlayer,
      targetPlayerId: playerId,
    );
    if (preflightConflict != null) {
      return _guestPlayerConflictResult(
        claimCode: initialClaim.code,
        guestPlayerId: initialGuestPlayer.id,
        playerId: playerId,
        conflict: preflightConflict,
      );
    }

    final guestMembershipSnapshot = await _membershipsRef
        .where('guestPlayerId', isEqualTo: guestPlayerId)
        .get();
    final playerMembershipSnapshot = await _membershipsRef
        .where('playerId', isEqualTo: playerId)
        .get();

    final result = await _firestore.runTransaction((transaction) async {
      final claimSnapshot = await transaction.get(claimRef);
      if (!claimSnapshot.exists || claimSnapshot.data() == null) {
        throw Exception('رابط الاستلام المطلوب غير موجود.');
      }
      final currentClaim = ClaimCodeModel.fromJson(
        claimSnapshot.data()!,
        claimSnapshot.id,
      ).toEntity();
      GuestClaimTokenPolicy.assertTargetType(
        currentClaim,
        ClaimTargetType.guestPlayer,
      );
      GuestClaimTokenPolicy.assertNotExpired(
        currentClaim,
        effectiveNow,
        targetType: ClaimTargetType.guestPlayer,
      );

      final guestPlayerRef = _guestPlayersRef.doc(guestPlayerId);
      final guestPlayerSnapshot = await transaction.get(guestPlayerRef);
      if (!guestPlayerSnapshot.exists || guestPlayerSnapshot.data() == null) {
        throw Exception('اللاعب الضيف المطلوب غير موجود.');
      }
      final guestPlayer = GuestPlayerModel.fromJson(
        guestPlayerSnapshot.data()!,
        guestPlayerSnapshot.id,
      ).toEntity();

      final playerRef = _playersRef.doc(playerId);
      final playerSnapshot = await transaction.get(playerRef);
      if (!playerSnapshot.exists || playerSnapshot.data() == null) {
        throw Exception('حساب اللاعب المطلوب غير موجود.');
      }
      final player = PlayerModel.fromJson(
        playerSnapshot.data()!,
        playerSnapshot.id,
      ).toEntity();

      await _assertClaimAuthorization(
        effectiveActorId: effectiveActorId,
        playerId: playerId,
        guestPlayer: guestPlayer,
        transaction: transaction,
      );

      if (guestPlayer.isClaimed && guestPlayer.linkedPlayerId == playerId) {
        return GuestPlayerClaimResult(
          outcome: GuestPlayerClaimOutcome.alreadyClaimed,
          claimCode: currentClaim.code,
          guestPlayerId: guestPlayer.id,
          playerId: playerId,
          linkedTeamIds: _linkedTeamIdsForResult(
            guestPlayer: guestPlayer,
            player: player,
          ),
        );
      }

      if (guestPlayer.isClaimed &&
          guestPlayer.linkedPlayerId != null &&
          guestPlayer.linkedPlayerId != playerId) {
        return _guestPlayerConflictResult(
          claimCode: currentClaim.code,
          guestPlayerId: guestPlayer.id,
          playerId: playerId,
          conflict: ClaimMergeConflict(
            type: ClaimMergeConflictType.targetAlreadyLinked,
            message: 'تم استلام هذا اللاعب مسبقًا بواسطة حساب آخر.',
            conflictingEntityId: guestPlayer.linkedPlayerId,
          ),
        );
      }

      if (currentClaim.status == ClaimCodeStatus.claimed &&
          currentClaim.claimedByPlayerId == playerId &&
          guestPlayer.linkedPlayerId == playerId) {
        return GuestPlayerClaimResult(
          outcome: GuestPlayerClaimOutcome.alreadyClaimed,
          claimCode: currentClaim.code,
          guestPlayerId: guestPlayer.id,
          playerId: playerId,
          linkedTeamIds: _linkedTeamIdsForResult(
            guestPlayer: guestPlayer,
            player: player,
          ),
        );
      }

      GuestClaimTokenPolicy.assertUsableStatus(
        currentClaim,
        targetType: ClaimTargetType.guestPlayer,
      );

      if (currentClaim.claimedByPlayerId != null &&
          currentClaim.claimedByPlayerId != playerId) {
        return _guestPlayerConflictResult(
          claimCode: currentClaim.code,
          guestPlayerId: guestPlayer.id,
          playerId: playerId,
          conflict: ClaimMergeConflict(
            type: ClaimMergeConflictType.targetAlreadyLinked,
            message: 'تم استخدام رابط الاستلام بواسطة لاعب آخر.',
            conflictingEntityId: currentClaim.claimedByPlayerId,
          ),
        );
      }

      final playerMembershipsByTeam = <String, List<TeamMembership>>{};
      for (final doc in playerMembershipSnapshot.docs) {
        final snapshot = await transaction.get(doc.reference);
        if (!snapshot.exists || snapshot.data() == null) {
          continue;
        }
        final membership = TeamMembershipModel.fromJson(
          snapshot.data()!,
          snapshot.id,
        ).toEntity();
        playerMembershipsByTeam
            .putIfAbsent(membership.teamId, () => [])
            .add(membership);
      }

      final relinkedMembershipIds = <String>[];
      final linkedTeamIds = {...player.teamIds};
      final syncedLegacyTeamIds = <String>{};
      final loadedTeams = <String, Team?>{};

      final guestMemberships = <_ClaimMembershipRef>[];
      for (final doc in guestMembershipSnapshot.docs) {
        final membershipSnapshot = await transaction.get(doc.reference);
        if (!membershipSnapshot.exists || membershipSnapshot.data() == null) {
          continue;
        }

        final membership = TeamMembershipModel.fromJson(
          membershipSnapshot.data()!,
          membershipSnapshot.id,
        ).toEntity();
        if (membership.guestPlayerId == guestPlayerId) {
          guestMemberships.add(
            _ClaimMembershipRef(
              reference: doc.reference,
              membership: membership,
            ),
          );
        }
      }

      final teamIdsToLoad = <String>{
        ...guestMemberships.map((entry) => entry.membership.teamId),
      };
      if (guestPlayer.teamId != null && guestPlayer.teamId!.isNotEmpty) {
        teamIdsToLoad.add(guestPlayer.teamId!);
      }
      for (final teamId in teamIdsToLoad) {
        await _loadTeam(
          teamId: teamId,
          loadedTeams: loadedTeams,
          transaction: transaction,
        );
      }

      final pendingMembershipUpdates = <_ClaimMembershipRef>[];
      final pendingLegacyTeamSyncs = <String>{};

      for (final resolvedMembership in guestMemberships) {
        final membership = resolvedMembership.membership;

        final conflictingMemberships =
            playerMembershipsByTeam[membership.teamId] ??
            const <TeamMembership>[];
        final activeConflict = conflictingMemberships.where(
          (entry) =>
              entry.id != membership.id &&
              entry.playerId == playerId &&
              entry.isActive,
        );
        if (activeConflict.isNotEmpty) {
          return _guestPlayerConflictResult(
            claimCode: currentClaim.code,
            guestPlayerId: guestPlayer.id,
            playerId: playerId,
            conflict: ClaimMergeConflict(
              type: ClaimMergeConflictType.rosterAlreadyContainsPlayer,
              message: 'اللاعب المسجل موجود بالفعل داخل قائمة هذا الفريق.',
              conflictingEntityId: membership.teamId,
            ),
          );
        }

        final updatedMembership = membership.copyWith(
          playerId: playerId,
          guestPlayerId: null,
          claimedFromGuestPlayerId: guestPlayerId,
          updatedAt: effectiveNow,
        );
        pendingMembershipUpdates.add(
          _ClaimMembershipRef(
            reference: resolvedMembership.reference,
            membership: updatedMembership,
          ),
        );
        relinkedMembershipIds.add(updatedMembership.id);
        linkedTeamIds.add(updatedMembership.teamId);
        playerMembershipsByTeam
            .putIfAbsent(updatedMembership.teamId, () => [])
            .add(updatedMembership);

        final team = loadedTeams[updatedMembership.teamId];
        if (team != null &&
            _teamRosterPolicy.canManageRoster(
              team: team,
              actorId: effectiveActorId,
            )) {
          pendingLegacyTeamSyncs.add(team.id);
        }
      }

      if (guestPlayer.teamId != null && guestPlayer.teamId!.isNotEmpty) {
        linkedTeamIds.add(guestPlayer.teamId!);
        final team = loadedTeams[guestPlayer.teamId!];
        if (team != null &&
            _teamRosterPolicy.canManageRoster(
              team: team,
              actorId: effectiveActorId,
            )) {
          pendingLegacyTeamSyncs.add(team.id);
        }
      }

      for (final update in pendingMembershipUpdates) {
        transaction.update(
          update.reference,
          TeamMembershipModel.fromEntity(update.membership).toJson(),
        );
      }

      for (final teamId in pendingLegacyTeamSyncs) {
        final team = loadedTeams[teamId];
        if (team == null) {
          continue;
        }
        final updatedPlayerIds = List<String>.from(team.playerIds);
        if (!updatedPlayerIds.contains(playerId)) {
          updatedPlayerIds.add(playerId);
          transaction.update(_teamsRef.doc(team.id), {
            'playerIds': updatedPlayerIds,
          });
          loadedTeams[team.id] = team.copyWith(playerIds: updatedPlayerIds);
          syncedLegacyTeamIds.add(team.id);
        }
      }

      final updatedPlayer = GuestClaimMergePolicy.mergePlayerIdentity(
        player: player,
        linkedTeamIds: linkedTeamIds,
        now: effectiveNow,
      );
      transaction.update(
        playerRef,
        PlayerModel.fromEntity(updatedPlayer).toJson(),
      );

      final updatedGuestPlayer = GuestClaimMergePolicy.linkGuestPlayer(
        guestPlayer: guestPlayer,
        playerId: playerId,
        now: effectiveNow,
      );
      transaction.update(
        guestPlayerRef,
        GuestPlayerModel.fromEntity(updatedGuestPlayer).toJson(),
      );

      final updatedClaim = currentClaim.copyWith(
        status: ClaimCodeStatus.claimed,
        claimedByPlayerId: playerId,
        claimedAt: effectiveNow,
        updatedAt: effectiveNow,
      );
      transaction.update(
        claimRef,
        ClaimCodeModel.fromEntity(updatedClaim).toJson(),
      );

      return GuestPlayerClaimResult(
        outcome: GuestPlayerClaimOutcome.claimed,
        claimCode: updatedClaim.code,
        guestPlayerId: guestPlayer.id,
        playerId: playerId,
        relinkedMembershipIds: relinkedMembershipIds,
        linkedTeamIds: linkedTeamIds.toList(growable: false),
        syncedLegacyTeamIds: syncedLegacyTeamIds.toList(growable: false),
      );
    });
    if (result.outcome == GuestPlayerClaimOutcome.claimed) {
      _completionReporter.playerClaimed(
        guestPlayerId: result.guestPlayerId,
        actorId: effectiveActorId,
      );
    }
    return result;
  }

  Future<GuestTeamClaimResult> claimGuestTeam({
    required String claimCode,
    required String teamId,
    required String actorId,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();

    final claimRef = _claimCodesRef.doc(claimCode);
    final initialClaimSnapshot = await claimRef.get();
    if (!initialClaimSnapshot.exists || initialClaimSnapshot.data() == null) {
      throw Exception('رابط استلام الفريق المطلوب غير موجود.');
    }

    final initialClaim = ClaimCodeModel.fromJson(
      initialClaimSnapshot.data()!,
      initialClaimSnapshot.id,
    ).toEntity();
    GuestClaimTokenPolicy.assertTargetType(
      initialClaim,
      ClaimTargetType.guestTeam,
    );

    if (GuestClaimTokenPolicy.shouldMarkExpired(initialClaim, effectiveNow)) {
      await claimRef.update({
        'status': ClaimCodeStatus.expired.name,
        'updatedAt': effectiveNow.millisecondsSinceEpoch,
      });
      throw Exception('انتهت صلاحية رابط استلام الفريق.');
    }

    final guestTeamId = initialClaim.targetId;
    final initialGuestTeamSnapshot = await _guestTeamsRef
        .doc(guestTeamId)
        .get();
    if (!initialGuestTeamSnapshot.exists ||
        initialGuestTeamSnapshot.data() == null) {
      throw Exception('الفريق الضيف المطلوب غير موجود.');
    }
    final initialGuestTeam = GuestTeamModel.fromJson(
      initialGuestTeamSnapshot.data()!,
      initialGuestTeamSnapshot.id,
    ).toEntity();

    final initialTeamSnapshot = await _teamsRef.doc(teamId).get();
    if (!initialTeamSnapshot.exists || initialTeamSnapshot.data() == null) {
      throw Exception('الفريق المسجل المطلوب غير موجود.');
    }
    final initialTeam = TeamModel.fromJson(
      initialTeamSnapshot.data()!,
      initialTeamSnapshot.id,
    ).toEntity();

    if (initialGuestTeam.isClaimed &&
        initialGuestTeam.linkedTeamId != null &&
        initialGuestTeam.linkedTeamId != teamId) {
      return _guestTeamConflictResult(
        claimCode: initialClaim.code,
        guestTeamId: initialGuestTeam.id,
        teamId: teamId,
        conflict: ClaimMergeConflict(
          type: ClaimMergeConflictType.targetAlreadyLinked,
          message: 'تم استلام هذا الفريق مسبقًا بواسطة فريق آخر.',
          conflictingEntityId: initialGuestTeam.linkedTeamId,
        ),
      );
    }

    final guestTeamPreflightConflict = await _detectGuestTeamPreflightConflict(
      targetTeam: initialTeam,
      guestTeam: initialGuestTeam,
    );
    if (guestTeamPreflightConflict != null) {
      return _guestTeamConflictResult(
        claimCode: initialClaim.code,
        guestTeamId: initialGuestTeam.id,
        teamId: teamId,
        conflict: guestTeamPreflightConflict,
      );
    }

    final result = await _firestore.runTransaction((transaction) async {
      final claimSnapshot = await transaction.get(claimRef);
      if (!claimSnapshot.exists || claimSnapshot.data() == null) {
        throw Exception('رابط استلام الفريق المطلوب غير موجود.');
      }
      final currentClaim = ClaimCodeModel.fromJson(
        claimSnapshot.data()!,
        claimSnapshot.id,
      ).toEntity();
      GuestClaimTokenPolicy.assertTargetType(
        currentClaim,
        ClaimTargetType.guestTeam,
      );
      GuestClaimTokenPolicy.assertNotExpired(
        currentClaim,
        effectiveNow,
        targetType: ClaimTargetType.guestTeam,
      );
      GuestClaimTokenPolicy.assertUsableStatus(
        currentClaim,
        targetType: ClaimTargetType.guestTeam,
        allowClaimed: true,
      );

      final guestTeamRef = _guestTeamsRef.doc(guestTeamId);
      final guestTeamSnapshot = await transaction.get(guestTeamRef);
      if (!guestTeamSnapshot.exists || guestTeamSnapshot.data() == null) {
        throw Exception('الفريق الضيف المطلوب غير موجود.');
      }
      final guestTeam = GuestTeamModel.fromJson(
        guestTeamSnapshot.data()!,
        guestTeamSnapshot.id,
      ).toEntity();

      final teamRef = _teamsRef.doc(teamId);
      final teamSnapshot = await transaction.get(teamRef);
      if (!teamSnapshot.exists || teamSnapshot.data() == null) {
        throw Exception('الفريق المسجل المطلوب غير موجود.');
      }
      final team = TeamModel.fromJson(
        teamSnapshot.data()!,
        teamSnapshot.id,
      ).toEntity();

      final actorOwnsTeam = team.ownerId == actorId;
      final actorIsGuestCreator = guestTeam.creatorId == actorId;

      if (!actorOwnsTeam && !actorIsGuestCreator) {
        throw Exception('لا تملك صلاحية استلام هذا الفريق.');
      }

      if (guestTeam.isClaimed && guestTeam.linkedTeamId == teamId) {
        return GuestTeamClaimResult(
          outcome: GuestTeamClaimOutcome.alreadyClaimed,
          claimCode: currentClaim.code,
          guestTeamId: guestTeam.id,
          teamId: teamId,
          mergedTournamentIds: GuestClaimMergePolicy.mergeUniqueStrings(
            team.tournamentIds,
            guestTeam.tournamentIds,
          ),
          requestedByPlayerId: currentClaim.claimedByPlayerId,
        );
      }

      if (guestTeam.isClaimed &&
          guestTeam.linkedTeamId != null &&
          guestTeam.linkedTeamId != teamId) {
        return _guestTeamConflictResult(
          claimCode: currentClaim.code,
          guestTeamId: guestTeam.id,
          teamId: teamId,
          conflict: ClaimMergeConflict(
            type: ClaimMergeConflictType.targetAlreadyLinked,
            message: 'تم استلام هذا الفريق مسبقًا بواسطة فريق آخر.',
            conflictingEntityId: guestTeam.linkedTeamId,
          ),
        );
      }

      if (currentClaim.status == ClaimCodeStatus.claimed &&
          currentClaim.teamId != null &&
          currentClaim.teamId!.isNotEmpty &&
          currentClaim.teamId != teamId) {
        return _guestTeamConflictResult(
          claimCode: currentClaim.code,
          guestTeamId: guestTeam.id,
          teamId: teamId,
          conflict: ClaimMergeConflict(
            type: ClaimMergeConflictType.targetAlreadyLinked,
            message: 'تم ربط رابط الاستلام هذا بفريق آخر بالفعل.',
            conflictingEntityId: currentClaim.teamId,
          ),
        );
      }

      final existingRequestedTeamId = currentClaim.teamId;
      if (existingRequestedTeamId != null &&
          existingRequestedTeamId.isNotEmpty &&
          existingRequestedTeamId != teamId) {
        return _guestTeamConflictResult(
          claimCode: currentClaim.code,
          guestTeamId: guestTeam.id,
          teamId: teamId,
          conflict: ClaimMergeConflict(
            type: ClaimMergeConflictType.pendingTargetLink,
            message: 'يوجد طلب claim معلق لهذا الفريق لصالح فريق آخر.',
            conflictingEntityId: existingRequestedTeamId,
          ),
        );
      }

      final mergedTournamentIds = GuestClaimMergePolicy.mergeUniqueStrings(
        team.tournamentIds,
        guestTeam.tournamentIds,
      );

      if (currentClaim.requiresApproval) {
        if (actorIsGuestCreator && !actorOwnsTeam) {
          if (currentClaim.teamId == null || currentClaim.teamId!.isEmpty) {
            throw Exception(
              'لا يوجد طلب claim معلق لهذا الفريق حتى تتم الموافقة عليه.',
            );
          }
          if (currentClaim.claimedByPlayerId == null ||
              currentClaim.claimedByPlayerId!.isEmpty) {
            throw Exception('بيانات طلب claim المعلق غير مكتملة.');
          }

          final updatedGuestTeam = GuestClaimMergePolicy.linkGuestTeam(
            guestTeam: guestTeam,
            teamId: teamId,
            now: effectiveNow,
          );
          transaction.update(
            guestTeamRef,
            GuestTeamModel.fromEntity(updatedGuestTeam).toJson(),
          );

          final updatedClaim = currentClaim.copyWith(
            status: ClaimCodeStatus.claimed,
            claimedAt: effectiveNow,
            updatedAt: effectiveNow,
          );
          transaction.update(
            claimRef,
            ClaimCodeModel.fromEntity(updatedClaim).toJson(),
          );

          return GuestTeamClaimResult(
            outcome: GuestTeamClaimOutcome.claimed,
            claimCode: updatedClaim.code,
            guestTeamId: updatedGuestTeam.id,
            teamId: teamId,
            mergedTournamentIds: mergedTournamentIds,
            requestedByPlayerId: updatedClaim.claimedByPlayerId,
          );
        }

        if (!actorOwnsTeam) {
          throw Exception('هذا الرابط يحتاج إلى موافقة المنظم قبل ربط الفريق.');
        }

        if (!GuestClaimMergePolicy.hasSameStrings(
          team.tournamentIds,
          mergedTournamentIds,
        )) {
          transaction.update(teamRef, {'tournamentIds': mergedTournamentIds});
        }

        if (actorIsGuestCreator) {
          final updatedGuestTeam = GuestClaimMergePolicy.linkGuestTeam(
            guestTeam: guestTeam,
            teamId: teamId,
            now: effectiveNow,
          );
          transaction.update(
            guestTeamRef,
            GuestTeamModel.fromEntity(updatedGuestTeam).toJson(),
          );

          final updatedClaim = currentClaim.copyWith(
            teamId: teamId,
            status: ClaimCodeStatus.claimed,
            claimedByPlayerId: actorId,
            claimedAt: effectiveNow,
            updatedAt: effectiveNow,
          );
          transaction.update(
            claimRef,
            ClaimCodeModel.fromEntity(updatedClaim).toJson(),
          );

          return GuestTeamClaimResult(
            outcome: GuestTeamClaimOutcome.claimed,
            claimCode: updatedClaim.code,
            guestTeamId: updatedGuestTeam.id,
            teamId: teamId,
            mergedTournamentIds: mergedTournamentIds,
            requestedByPlayerId: updatedClaim.claimedByPlayerId,
          );
        }

        if (currentClaim.claimedByPlayerId != null &&
            currentClaim.claimedByPlayerId!.isNotEmpty &&
            currentClaim.claimedByPlayerId != actorId) {
          return _guestTeamConflictResult(
            claimCode: currentClaim.code,
            guestTeamId: guestTeam.id,
            teamId: teamId,
            conflict: ClaimMergeConflict(
              type: ClaimMergeConflictType.pendingTargetLink,
              message: 'يوجد طلب claim معلق لهذا الفريق بواسطة قائد فريق آخر.',
              conflictingEntityId: currentClaim.claimedByPlayerId,
            ),
          );
        }

        if (currentClaim.teamId == teamId &&
            currentClaim.claimedByPlayerId == actorId) {
          return GuestTeamClaimResult(
            outcome: GuestTeamClaimOutcome.approvalRequired,
            claimCode: currentClaim.code,
            guestTeamId: guestTeam.id,
            teamId: teamId,
            mergedTournamentIds: mergedTournamentIds,
            requestedByPlayerId: actorId,
          );
        }

        final updatedClaim = currentClaim.copyWith(
          teamId: teamId,
          claimedByPlayerId: actorId,
          updatedAt: effectiveNow,
        );
        transaction.update(
          claimRef,
          ClaimCodeModel.fromEntity(updatedClaim).toJson(),
        );

        return GuestTeamClaimResult(
          outcome: GuestTeamClaimOutcome.approvalRequired,
          claimCode: updatedClaim.code,
          guestTeamId: guestTeam.id,
          teamId: teamId,
          mergedTournamentIds: mergedTournamentIds,
          requestedByPlayerId: actorId,
        );
      }

      if (!actorOwnsTeam) {
        throw Exception('لا يملك هذا الحساب صلاحية ربط الفريق المسجل.');
      }

      if (currentClaim.claimedByPlayerId != null &&
          currentClaim.claimedByPlayerId!.isNotEmpty &&
          currentClaim.claimedByPlayerId != actorId) {
        return _guestTeamConflictResult(
          claimCode: currentClaim.code,
          guestTeamId: guestTeam.id,
          teamId: teamId,
          conflict: ClaimMergeConflict(
            type: ClaimMergeConflictType.targetAlreadyLinked,
            message: 'تم استخدام رابط الاستلام بواسطة قائد فريق آخر.',
            conflictingEntityId: currentClaim.claimedByPlayerId,
          ),
        );
      }

      if (!GuestClaimMergePolicy.hasSameStrings(
        team.tournamentIds,
        mergedTournamentIds,
      )) {
        transaction.update(teamRef, {'tournamentIds': mergedTournamentIds});
      }

      final updatedGuestTeam = GuestClaimMergePolicy.linkGuestTeam(
        guestTeam: guestTeam,
        teamId: teamId,
        now: effectiveNow,
      );
      transaction.update(
        guestTeamRef,
        GuestTeamModel.fromEntity(updatedGuestTeam).toJson(),
      );

      final updatedClaim = currentClaim.copyWith(
        teamId: teamId,
        status: ClaimCodeStatus.claimed,
        claimedByPlayerId: actorId,
        claimedAt: effectiveNow,
        updatedAt: effectiveNow,
      );
      transaction.update(
        claimRef,
        ClaimCodeModel.fromEntity(updatedClaim).toJson(),
      );

      return GuestTeamClaimResult(
        outcome: GuestTeamClaimOutcome.claimed,
        claimCode: updatedClaim.code,
        guestTeamId: updatedGuestTeam.id,
        teamId: teamId,
        mergedTournamentIds: mergedTournamentIds,
        requestedByPlayerId: actorId,
      );
    });
    if (result.outcome == GuestTeamClaimOutcome.claimed) {
      _completionReporter.teamClaimed(
        guestTeamId: result.guestTeamId,
        actorId: actorId,
      );
    }
    return result;
  }

  Future<void> _assertClaimAuthorization({
    required String effectiveActorId,
    required String playerId,
    required GuestPlayer guestPlayer,
    required Transaction transaction,
  }) async {
    if (effectiveActorId == playerId) {
      return;
    }
    if (guestPlayer.createdBy == effectiveActorId) {
      return;
    }
    final teamId = guestPlayer.teamId;
    if (teamId == null || teamId.isEmpty) {
      throw Exception('لا تملك صلاحية إتمام claim لهذا اللاعب.');
    }
    final teamSnapshot = await transaction.get(_teamsRef.doc(teamId));
    if (!teamSnapshot.exists || teamSnapshot.data() == null) {
      throw Exception('لا تملك صلاحية إتمام claim لهذا اللاعب.');
    }
    final team = TeamModel.fromJson(
      teamSnapshot.data()!,
      teamSnapshot.id,
    ).toEntity();
    if (_teamRosterPolicy.canManageRoster(
      team: team,
      actorId: effectiveActorId,
    )) {
      return;
    }
    throw Exception('لا تملك صلاحية إتمام claim لهذا اللاعب.');
  }

  Future<Team?> _loadTeam({
    required String teamId,
    required Map<String, Team?> loadedTeams,
    required Transaction transaction,
  }) async {
    if (loadedTeams.containsKey(teamId)) {
      return loadedTeams[teamId];
    }
    final snapshot = await transaction.get(_teamsRef.doc(teamId));
    if (!snapshot.exists || snapshot.data() == null) {
      loadedTeams[teamId] = null;
      return null;
    }
    final team = TeamModel.fromJson(snapshot.data()!, snapshot.id).toEntity();
    loadedTeams[teamId] = team;
    return team;
  }

  List<String> _linkedTeamIdsForResult({
    required GuestPlayer guestPlayer,
    required Player player,
  }) {
    final linked = {...player.teamIds};
    if (guestPlayer.teamId != null && guestPlayer.teamId!.isNotEmpty) {
      linked.add(guestPlayer.teamId!);
    }
    return linked.toList(growable: false);
  }

  GuestPlayerClaimResult _guestPlayerConflictResult({
    required String claimCode,
    required String guestPlayerId,
    required String playerId,
    required ClaimMergeConflict conflict,
  }) {
    return GuestPlayerClaimResult(
      outcome: GuestPlayerClaimOutcome.conflict,
      claimCode: claimCode,
      guestPlayerId: guestPlayerId,
      playerId: playerId,
      conflict: conflict,
    );
  }

  GuestTeamClaimResult _guestTeamConflictResult({
    required String claimCode,
    required String guestTeamId,
    required String teamId,
    required ClaimMergeConflict conflict,
  }) {
    return GuestTeamClaimResult(
      outcome: GuestTeamClaimOutcome.conflict,
      claimCode: claimCode,
      guestTeamId: guestTeamId,
      teamId: teamId,
      conflict: conflict,
    );
  }

  Future<ClaimMergeConflict?> _detectGuestPlayerPreflightConflict({
    required GuestPlayer guestPlayer,
    required String targetPlayerId,
  }) async {
    final duplicatePhone = await _findConflictingPlayerByPhone(
      phone: guestPlayer.phoneNumber,
      excludedPlayerId: targetPlayerId,
    );
    if (duplicatePhone != null) {
      return ClaimMergeConflict(
        type: ClaimMergeConflictType.duplicatePhone,
        message: 'يوجد لاعب مسجل آخر يطابق رقم هاتف هذا اللاعب الضيف.',
        conflictingEntityId: duplicatePhone.id,
        conflictingEntityLabel: duplicatePhone.name,
      );
    }

    final duplicateName = await _findConflictingPlayerByNormalizedName(
      normalizedName: guestPlayer.normalizedName,
      excludedPlayerId: targetPlayerId,
    );
    if (duplicateName != null) {
      return ClaimMergeConflict(
        type: ClaimMergeConflictType.duplicateName,
        message: 'يوجد لاعب مسجل آخر يطابق اسم هذا اللاعب الضيف.',
        conflictingEntityId: duplicateName.id,
        conflictingEntityLabel: duplicateName.name,
      );
    }

    return null;
  }

  Future<ClaimMergeConflict?> _detectGuestTeamPreflightConflict({
    required Team targetTeam,
    required GuestTeam guestTeam,
  }) async {
    final duplicateName = await _findConflictingTeamByNormalizedName(
      normalizedName: guestTeam.normalizedName,
      excludedTeamId: targetTeam.id,
    );
    if (duplicateName != null) {
      return ClaimMergeConflict(
        type: ClaimMergeConflictType.duplicateName,
        message: 'يوجد فريق مسجل آخر يطابق اسم هذا الفريق الضيف.',
        conflictingEntityId: duplicateName.id,
        conflictingEntityLabel: duplicateName.name,
      );
    }

    return null;
  }

  Future<Player?> _findConflictingPlayerByPhone({
    required String? phone,
    required String excludedPlayerId,
  }) async {
    if (phone == null || phone.trim().isEmpty) {
      return null;
    }

    final snapshot = await _playersRef
        .where('phone', isEqualTo: phone)
        .limit(3)
        .get();
    for (final doc in snapshot.docs) {
      if (doc.id == excludedPlayerId) {
        continue;
      }
      return PlayerModel.fromJson(doc.data(), doc.id).toEntity();
    }
    return null;
  }

  Future<Player?> _findConflictingPlayerByNormalizedName({
    required String normalizedName,
    required String excludedPlayerId,
  }) async {
    if (normalizedName.trim().isEmpty) {
      return null;
    }

    final snapshot = await _playersRef
        .where('nameLower', isEqualTo: normalizedName)
        .limit(3)
        .get();
    for (final doc in snapshot.docs) {
      if (doc.id == excludedPlayerId) {
        continue;
      }
      return PlayerModel.fromJson(doc.data(), doc.id).toEntity();
    }
    return null;
  }

  Future<Team?> _findConflictingTeamByNormalizedName({
    required String normalizedName,
    required String excludedTeamId,
  }) async {
    if (normalizedName.trim().isEmpty) {
      return null;
    }

    final snapshot = await _teamsRef
        .where('nameLower', isEqualTo: normalizedName)
        .limit(3)
        .get();
    for (final doc in snapshot.docs) {
      if (doc.id == excludedTeamId) {
        continue;
      }
      return TeamModel.fromJson(doc.data(), doc.id).toEntity();
    }
    return null;
  }
}

class _ClaimMembershipRef {
  final DocumentReference<Map<String, dynamic>> reference;
  final TeamMembership membership;

  const _ClaimMembershipRef({
    required this.reference,
    required this.membership,
  });
}

import 'package:uuid/uuid.dart';

import '../../core/enums/guest_claim_status.dart';
import '../../data/repositories/guest_player_repository_impl.dart';
import '../../data/repositories/guest_team_repository_impl.dart';
import '../../data/repositories/tournament_repository_impl.dart';
import '../../domain/entities/guest_player.dart';
import '../../domain/entities/guest_team.dart';
import '../../domain/entities/tournament.dart';
import '../../domain/repositories/guest_player_repository.dart';
import '../../domain/repositories/guest_team_repository.dart';
import '../../domain/repositories/tournament_repository.dart';
import 'tournament_audit_emitter.dart';
import 'tournament_permission_service.dart';

class GuestTeamRosterService {
  final GuestPlayerRepository _guestPlayerRepository;
  final GuestTeamRepository _guestTeamRepository;
  final TournamentRepository _tournamentRepository;
  final TournamentPermissionService _tournamentPermissionService;
  final TournamentAuditEmitter _auditEmitter;
  final Uuid _uuid;

  GuestTeamRosterService({
    GuestPlayerRepository? guestPlayerRepository,
    GuestTeamRepository? guestTeamRepository,
    TournamentRepository? tournamentRepository,
    TournamentPermissionService? tournamentPermissionService,
    TournamentAuditEmitter? auditEmitter,
    Uuid? uuid,
  }) : _guestPlayerRepository =
           guestPlayerRepository ?? GuestPlayerRepositoryImpl(),
       _guestTeamRepository = guestTeamRepository ?? GuestTeamRepositoryImpl(),
       _tournamentRepository =
           tournamentRepository ?? TournamentRepositoryImpl(),
       _tournamentPermissionService =
           tournamentPermissionService ?? TournamentPermissionService(),
       _auditEmitter = auditEmitter ?? TournamentAuditEmitter(),
       _uuid = uuid ?? const Uuid();

  Future<List<GuestPlayer>> getGuestRoster({
    required String tournamentId,
    required String guestTeamId,
    required String actorId,
  }) async {
    await _loadAuthorizedContext(
      tournamentId: tournamentId,
      guestTeamId: guestTeamId,
      actorId: actorId,
    );
    return _guestPlayerRepository.getGuestTeamPlayers(guestTeamId);
  }

  Future<GuestPlayer> createGuestPlayer({
    required String tournamentId,
    required String guestTeamId,
    required String actorId,
    required String displayName,
    String? phoneNumber,
    int? jerseyNumber,
    String? preferredPosition,
    String? notes,
    DateTime? now,
  }) async {
    final context = await _loadAuthorizedContext(
      tournamentId: tournamentId,
      guestTeamId: guestTeamId,
      actorId: actorId,
    );
    final effectiveName = displayName.trim();
    if (effectiveName.isEmpty) {
      throw Exception('اسم اللاعب الضيف مطلوب.');
    }

    final normalizedName = _normalizeName(effectiveName);
    final roster = await _guestPlayerRepository.getGuestTeamPlayers(
      guestTeamId,
    );
    final duplicate = roster.where(
      (guestPlayer) =>
          guestPlayer.claimStatus != GuestClaimStatus.archived &&
          guestPlayer.normalizedName == normalizedName,
    );
    if (duplicate.isNotEmpty) {
      throw Exception('يوجد لاعب ضيف بنفس الاسم داخل هذا الفريق بالفعل.');
    }

    final effectiveNow = now ?? DateTime.now();
    final guestPlayer = GuestPlayer(
      id: _uuid.v4(),
      displayName: effectiveName,
      normalizedName: normalizedName,
      phoneNumber: _emptyToNull(phoneNumber),
      jerseyNumber: jerseyNumber,
      preferredPosition: _emptyToNull(preferredPosition),
      guestTeamId: guestTeamId,
      tournamentId: tournamentId,
      createdBy: actorId,
      createdAt: effectiveNow,
      updatedAt: effectiveNow,
      notes: _emptyToNull(notes),
    );

    await _guestPlayerRepository.createGuestPlayer(guestPlayer);
    await _auditEmitter.guestPlayerCreated(
      tournament: context.tournament,
      guestTeamId: guestTeamId,
      actorId: actorId,
      guestPlayer: guestPlayer,
    );
    return guestPlayer;
  }

  Future<GuestPlayer> updateGuestPlayer({
    required String tournamentId,
    required String guestTeamId,
    required String actorId,
    required String guestPlayerId,
    required String displayName,
    String? phoneNumber,
    int? jerseyNumber,
    String? preferredPosition,
    String? notes,
    DateTime? now,
  }) async {
    final context = await _loadAuthorizedContext(
      tournamentId: tournamentId,
      guestTeamId: guestTeamId,
      actorId: actorId,
    );
    final existing = await _requireGuestPlayer(
      guestPlayerId: guestPlayerId,
      guestTeamId: guestTeamId,
      tournamentId: tournamentId,
    );
    final effectiveName = displayName.trim();
    if (effectiveName.isEmpty) {
      throw Exception('اسم اللاعب الضيف مطلوب.');
    }

    final normalizedName = _normalizeName(effectiveName);
    final roster = await _guestPlayerRepository.getGuestTeamPlayers(
      guestTeamId,
    );
    final duplicate = roster.where(
      (guestPlayer) =>
          guestPlayer.id != existing.id &&
          guestPlayer.claimStatus != GuestClaimStatus.archived &&
          guestPlayer.normalizedName == normalizedName,
    );
    if (duplicate.isNotEmpty) {
      throw Exception('يوجد لاعب ضيف بنفس الاسم داخل هذا الفريق بالفعل.');
    }

    final updated = GuestPlayer(
      id: existing.id,
      displayName: effectiveName,
      normalizedName: normalizedName,
      phoneNumber: _emptyToNull(phoneNumber),
      jerseyNumber: jerseyNumber,
      preferredPosition: _emptyToNull(preferredPosition),
      teamId: existing.teamId,
      guestTeamId: existing.guestTeamId,
      tournamentId: existing.tournamentId,
      createdBy: existing.createdBy,
      createdAt: existing.createdAt,
      updatedAt: now ?? DateTime.now(),
      claimStatus: existing.claimStatus,
      claimCode: existing.claimCode,
      linkedPlayerId: existing.linkedPlayerId,
      notes: _emptyToNull(notes),
    );

    if (_sameGuestPlayer(existing, updated)) {
      return existing;
    }

    await _guestPlayerRepository.updateGuestPlayer(updated);
    await _auditEmitter.guestPlayerUpdated(
      tournament: context.tournament,
      guestTeamId: guestTeamId,
      actorId: actorId,
      before: existing,
      after: updated,
    );
    return updated;
  }

  Future<GuestPlayer> archiveGuestPlayer({
    required String tournamentId,
    required String guestTeamId,
    required String actorId,
    required String guestPlayerId,
    DateTime? now,
  }) async {
    final context = await _loadAuthorizedContext(
      tournamentId: tournamentId,
      guestTeamId: guestTeamId,
      actorId: actorId,
    );
    final existing = await _requireGuestPlayer(
      guestPlayerId: guestPlayerId,
      guestTeamId: guestTeamId,
      tournamentId: tournamentId,
    );

    if (existing.claimStatus == GuestClaimStatus.archived) {
      return existing;
    }

    final effectiveNow = now ?? DateTime.now();
    final archived = existing.copyWith(
      claimStatus: GuestClaimStatus.archived,
      updatedAt: effectiveNow,
    );
    await _guestPlayerRepository.updateGuestPlayer(archived);

    if (context.guestTeam.captainGuestPlayerId == guestPlayerId) {
      final updatedGuestTeam = _updatedGuestTeamCaptain(
        context.guestTeam,
        captainGuestPlayerId: null,
        now: effectiveNow,
      );
      await _guestTeamRepository.updateGuestTeam(updatedGuestTeam);
      await _auditEmitter.guestTeamCaptainUpdated(
        tournament: context.tournament,
        actorId: actorId,
        before: context.guestTeam,
        after: updatedGuestTeam,
      );
    }

    await _auditEmitter.guestPlayerArchived(
      tournament: context.tournament,
      guestTeamId: guestTeamId,
      actorId: actorId,
      before: existing,
      after: archived,
    );
    return archived;
  }

  Future<GuestTeam> setCaptain({
    required String tournamentId,
    required String guestTeamId,
    required String actorId,
    required String guestPlayerId,
    DateTime? now,
  }) async {
    final context = await _loadAuthorizedContext(
      tournamentId: tournamentId,
      guestTeamId: guestTeamId,
      actorId: actorId,
    );
    final guestPlayer = await _requireGuestPlayer(
      guestPlayerId: guestPlayerId,
      guestTeamId: guestTeamId,
      tournamentId: tournamentId,
    );
    if (guestPlayer.claimStatus == GuestClaimStatus.archived) {
      throw Exception('لا يمكن تعيين لاعب ضيف مؤرشف كقائد للفريق.');
    }

    if (context.guestTeam.captainGuestPlayerId == guestPlayerId) {
      return context.guestTeam;
    }

    final updatedGuestTeam = _updatedGuestTeamCaptain(
      context.guestTeam,
      captainGuestPlayerId: guestPlayerId,
      now: now ?? DateTime.now(),
    );
    await _guestTeamRepository.updateGuestTeam(updatedGuestTeam);
    await _auditEmitter.guestTeamCaptainUpdated(
      tournament: context.tournament,
      actorId: actorId,
      before: context.guestTeam,
      after: updatedGuestTeam,
    );
    return updatedGuestTeam;
  }

  Future<_GuestRosterContext> _loadAuthorizedContext({
    required String tournamentId,
    required String guestTeamId,
    required String actorId,
  }) async {
    final tournament = await _tournamentRepository.getTournament(tournamentId);
    if (tournament == null) {
      throw Exception('البطولة المطلوبة غير موجودة.');
    }
    final guestTeam = await _guestTeamRepository.getGuestTeam(guestTeamId);
    if (guestTeam == null) {
      throw Exception('الفريق الضيف المطلوب غير موجود.');
    }
    if (!guestTeam.tournamentIds.contains(tournamentId)) {
      throw Exception('الفريق الضيف لا ينتمي إلى البطولة المطلوبة.');
    }

    final canManage =
        guestTeam.creatorId == actorId ||
        _tournamentPermissionService.canManageGuestRoster(tournament, actorId);
    if (!canManage) {
      throw Exception('لا تملك صلاحية إدارة roster هذا الفريق الضيف.');
    }

    return _GuestRosterContext(tournament: tournament, guestTeam: guestTeam);
  }

  Future<GuestPlayer> _requireGuestPlayer({
    required String guestPlayerId,
    required String guestTeamId,
    required String tournamentId,
  }) async {
    final guestPlayer = await _guestPlayerRepository.getGuestPlayer(
      guestPlayerId,
    );
    if (guestPlayer == null) {
      throw Exception('اللاعب الضيف المطلوب غير موجود.');
    }
    if (guestPlayer.guestTeamId != guestTeamId ||
        guestPlayer.tournamentId != tournamentId) {
      throw Exception('اللاعب الضيف لا ينتمي إلى الفريق أو البطولة المطلوبة.');
    }
    return guestPlayer;
  }

  GuestTeam _updatedGuestTeamCaptain(
    GuestTeam guestTeam, {
    required String? captainGuestPlayerId,
    required DateTime now,
  }) {
    return GuestTeam(
      id: guestTeam.id,
      name: guestTeam.name,
      normalizedName: guestTeam.normalizedName,
      creatorId: guestTeam.creatorId,
      contactName: guestTeam.contactName,
      contactPhone: guestTeam.contactPhone,
      logoUrl: guestTeam.logoUrl,
      tournamentIds: guestTeam.tournamentIds,
      captainGuestPlayerId: captainGuestPlayerId,
      claimStatus: guestTeam.claimStatus,
      claimCode: guestTeam.claimCode,
      linkedTeamId: guestTeam.linkedTeamId,
      createdAt: guestTeam.createdAt,
      updatedAt: now,
    );
  }

  String _normalizeName(String value) {
    return value.trim().toLowerCase();
  }

  String? _emptyToNull(String? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  bool _sameGuestPlayer(GuestPlayer left, GuestPlayer right) {
    return left.displayName == right.displayName &&
        left.normalizedName == right.normalizedName &&
        left.phoneNumber == right.phoneNumber &&
        left.jerseyNumber == right.jerseyNumber &&
        left.preferredPosition == right.preferredPosition &&
        left.notes == right.notes;
  }
}

class _GuestRosterContext {
  final Tournament tournament;
  final GuestTeam guestTeam;

  const _GuestRosterContext({
    required this.tournament,
    required this.guestTeam,
  });
}

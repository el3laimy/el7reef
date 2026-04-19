import '../../core/enums/claim_code_status.dart';
import '../../core/enums/claim_target_type.dart';
import '../../core/enums/team_member_availability.dart';
import '../../core/enums/team_membership_role.dart';
import '../../core/enums/team_membership_status.dart';
import '../../data/repositories/claim_code_repository_impl.dart';
import '../../data/repositories/player_repository_impl.dart';
import '../../data/repositories/team_membership_repository_impl.dart';
import '../../data/repositories/team_repository_impl.dart';
import '../../domain/entities/claim_code.dart';
import '../../domain/entities/player.dart';
import '../../domain/entities/team.dart';
import '../../domain/entities/team_membership.dart';
import '../../domain/repositories/claim_code_repository.dart';
import '../../domain/repositories/player_repository.dart';
import '../../domain/repositories/team_membership_repository.dart';
import '../../domain/repositories/team_repository.dart';
import 'team_roster_policy.dart';

enum TeamInviteAcceptanceOutcome {
  joined,
  alreadyMember,
}

class TeamInvitePreview {
  final ClaimCode claimCode;
  final Team team;

  const TeamInvitePreview({
    required this.claimCode,
    required this.team,
  });
}

class TeamInviteAcceptanceResult {
  final TeamInviteAcceptanceOutcome outcome;
  final Team team;
  final Player player;
  final TeamMembership membership;

  const TeamInviteAcceptanceResult({
    required this.outcome,
    required this.team,
    required this.player,
    required this.membership,
  });
}

class TeamInviteService {
  final ClaimCodeRepository _claimCodeRepository;
  final TeamRepository _teamRepository;
  final TeamMembershipRepository _membershipRepository;
  final PlayerRepository _playerRepository;
  final TeamRosterPolicy _policy;

  TeamInviteService({
    ClaimCodeRepository? claimCodeRepository,
    TeamRepository? teamRepository,
    TeamMembershipRepository? membershipRepository,
    PlayerRepository? playerRepository,
    TeamRosterPolicy? policy,
  })  : _claimCodeRepository =
            claimCodeRepository ?? ClaimCodeRepositoryImpl(),
        _teamRepository = teamRepository ?? TeamRepositoryImpl(),
        _membershipRepository =
            membershipRepository ?? TeamMembershipRepositoryImpl(),
        _playerRepository = playerRepository ?? PlayerRepositoryImpl(),
        _policy = policy ?? const TeamRosterPolicy();

  Future<TeamInvitePreview> resolveInvite({
    required String code,
    required String teamId,
    DateTime? now,
  }) async {
    final claimCode = await _requireActiveInviteCode(
      code: code,
      teamId: teamId,
      now: now,
    );
    final team = await _requireTeam(teamId);
    return TeamInvitePreview(claimCode: claimCode, team: team);
  }

  Future<TeamInviteAcceptanceResult> acceptInvite({
    required String code,
    required String teamId,
    required String playerId,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final preview = await resolveInvite(
      code: code,
      teamId: teamId,
      now: effectiveNow,
    );
    final player = await _requirePlayer(playerId);
    final memberships = await _membershipRepository.getTeamMemberships(
      teamId,
      includeInactive: true,
    );

    final activeMembership = memberships.cast<TeamMembership?>().firstWhere(
          (membership) =>
              membership != null &&
              membership.playerId == playerId &&
              membership.isActive,
          orElse: () => null,
        );

    if (activeMembership != null ||
        preview.team.playerIds.contains(playerId) ||
        player.teamIds.contains(teamId)) {
      final membership = activeMembership ??
          TeamMembership(
            id: 'team-invite::$teamId::$playerId',
            teamId: teamId,
            playerId: playerId,
            role: TeamMembershipRole.player,
            status: TeamMembershipStatus.bench,
            availability: TeamMemberAvailability.available,
            joinedAt: effectiveNow,
            updatedAt: effectiveNow,
            invitedBy: preview.claimCode.createdBy,
          );
      await _syncLegacyMembershipArrays(
        team: preview.team,
        player: player,
        playerId: playerId,
        teamId: teamId,
      );
      return TeamInviteAcceptanceResult(
        outcome: TeamInviteAcceptanceOutcome.alreadyMember,
        team: preview.team,
        player: await _requirePlayer(playerId),
        membership: activeMembership ?? membership,
      );
    }

    final validationError = _policy.validateRegisteredMembership(
      team: preview.team,
      existingMemberships: memberships,
      playerId: playerId,
      role: TeamMembershipRole.player,
    );
    if (validationError != null) {
      throw Exception(validationError);
    }

    final inactiveMembership = memberships.cast<TeamMembership?>().firstWhere(
          (membership) =>
              membership != null &&
              membership.playerId == playerId &&
              membership.status == TeamMembershipStatus.inactive,
          orElse: () => null,
        );

    final membership = inactiveMembership != null
        ? inactiveMembership.copyWith(
            role: TeamMembershipRole.player,
            status: TeamMembershipStatus.bench,
            availability: TeamMemberAvailability.available,
            updatedAt: effectiveNow,
            invitedBy: preview.claimCode.createdBy,
          )
        : TeamMembership(
            id: 'team-invite::$teamId::$playerId',
            teamId: teamId,
            playerId: playerId,
            role: TeamMembershipRole.player,
            status: TeamMembershipStatus.bench,
            availability: TeamMemberAvailability.available,
            joinedAt: effectiveNow,
            updatedAt: effectiveNow,
            invitedBy: preview.claimCode.createdBy,
          );

    if (inactiveMembership != null) {
      await _membershipRepository.updateMembership(membership);
    } else {
      await _membershipRepository.createMembership(membership);
    }

    await _syncLegacyMembershipArrays(
      team: preview.team,
      player: player,
      playerId: playerId,
      teamId: teamId,
    );

    return TeamInviteAcceptanceResult(
      outcome: TeamInviteAcceptanceOutcome.joined,
      team: await _requireTeam(teamId),
      player: await _requirePlayer(playerId),
      membership: membership,
    );
  }

  Future<void> _syncLegacyMembershipArrays({
    required Team team,
    required Player player,
    required String playerId,
    required String teamId,
  }) async {
    if (!team.playerIds.contains(playerId)) {
      await _teamRepository.updateTeam(
        team.copyWith(
          playerIds: [...team.playerIds, playerId],
        ),
      );
    }

    if (!player.teamIds.contains(teamId)) {
      await _playerRepository.updatePlayer(
        player.copyWith(
          teamIds: [...player.teamIds, teamId],
          lastActiveAt: DateTime.now(),
        ),
      );
    }
  }

  Future<ClaimCode> _requireActiveInviteCode({
    required String code,
    required String teamId,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final claimCode = await _claimCodeRepository.getClaimCode(code);
    if (claimCode == null) {
      throw Exception('رابط الدعوة غير صالح.');
    }
    if (claimCode.targetType != ClaimTargetType.teamInvite ||
        claimCode.targetId != teamId) {
      throw Exception('رابط الدعوة لا يخص هذا الفريق.');
    }
    if (claimCode.status == ClaimCodeStatus.active &&
        claimCode.isExpiredAt(effectiveNow)) {
      await _claimCodeRepository.updateClaimCode(
        claimCode.copyWith(
          status: ClaimCodeStatus.expired,
          updatedAt: effectiveNow,
        ),
      );
      throw Exception('انتهت صلاحية رابط الدعوة.');
    }
    if (claimCode.status != ClaimCodeStatus.active) {
      throw Exception('رابط الدعوة لم يعد صالحًا.');
    }
    return claimCode;
  }

  Future<Team> _requireTeam(String teamId) async {
    final team = await _teamRepository.getTeam(teamId);
    if (team == null) {
      throw Exception('الفريق المطلوب لم يعد موجودًا.');
    }
    return team;
  }

  Future<Player> _requirePlayer(String playerId) async {
    final player = await _playerRepository.getPlayer(playerId);
    if (player == null) {
      throw Exception('تعذر العثور على حساب اللاعب الحالي.');
    }
    return player;
  }
}

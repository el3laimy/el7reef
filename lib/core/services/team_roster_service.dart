import 'package:uuid/uuid.dart';

import '../../core/enums/team_member_availability.dart';
import '../../core/enums/team_membership_role.dart';
import '../../core/enums/team_membership_status.dart';
import '../../data/repositories/guest_player_repository_impl.dart';
import '../../data/repositories/team_membership_repository_impl.dart';
import '../../data/repositories/team_repository_impl.dart';
import '../../domain/entities/guest_player.dart';
import '../../domain/entities/team.dart';
import '../../domain/entities/team_membership.dart';
import '../../domain/repositories/guest_player_repository.dart';
import '../../domain/repositories/team_membership_repository.dart';
import '../../domain/repositories/team_repository.dart';
import 'team_roster_policy.dart';

class TeamRosterService {
  final TeamRepository _teamRepository;
  final TeamMembershipRepository _membershipRepository;
  final GuestPlayerRepository _guestPlayerRepository;
  final TeamRosterPolicy _policy;
  final Uuid _uuid;

  TeamRosterService({
    TeamRepository? teamRepository,
    TeamMembershipRepository? membershipRepository,
    GuestPlayerRepository? guestPlayerRepository,
    TeamRosterPolicy? policy,
    Uuid? uuid,
  }) : _teamRepository = teamRepository ?? TeamRepositoryImpl(),
       _membershipRepository =
           membershipRepository ?? TeamMembershipRepositoryImpl(),
       _guestPlayerRepository =
           guestPlayerRepository ?? GuestPlayerRepositoryImpl(),
       _policy = policy ?? const TeamRosterPolicy(),
       _uuid = uuid ?? const Uuid();

  Future<List<TeamMembership>> getTeamRoster(
    String teamId, {
    bool includeInactive = false,
  }) async {
    final team = await _requireTeam(teamId);
    await _bootstrapLegacyMemberships(team);
    return _membershipRepository.getTeamMemberships(
      teamId,
      includeInactive: includeInactive,
    );
  }

  Future<TeamMembership> addRegisteredPlayer({
    required String teamId,
    required String actorId,
    required String playerId,
    TeamMembershipRole role = TeamMembershipRole.player,
    TeamMembershipStatus status = TeamMembershipStatus.bench,
    TeamMemberAvailability availability = TeamMemberAvailability.available,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final team = await _requireTeam(teamId);
    _assertCanManage(team, actorId);
    await _bootstrapLegacyMemberships(team);

    final existingMemberships = await _membershipRepository.getTeamMemberships(
      teamId,
      includeInactive: true,
    );
    final validationError = _policy.validateRegisteredMembership(
      team: team,
      existingMemberships: existingMemberships,
      playerId: playerId,
      role: role,
    );
    if (validationError != null) {
      throw Exception(validationError);
    }

    final inactiveMembership = existingMemberships
        .cast<TeamMembership?>()
        .firstWhere(
          (membership) =>
              membership != null &&
              membership.playerId == playerId &&
              membership.status == TeamMembershipStatus.inactive,
          orElse: () => null,
        );

    final membership = (inactiveMembership != null
        ? inactiveMembership.copyWith(
            role: role,
            status: status,
            availability: availability,
            updatedAt: effectiveNow,
          )
        : TeamMembership(
            id: _uuid.v4(),
            teamId: teamId,
            playerId: playerId,
            role: role,
            status: status,
            availability: availability,
            joinedAt: effectiveNow,
            updatedAt: effectiveNow,
            invitedBy: actorId,
          ));

    if (inactiveMembership != null) {
      await _membershipRepository.updateMembership(membership);
    } else {
      await _membershipRepository.createMembership(membership);
    }

    await _teamRepository.updateTeam(
      _updatedTeamForMembership(team, membership: membership, addPlayer: true),
    );

    return membership;
  }

  Future<TeamMembership> addGuestPlayer({
    required String teamId,
    required String actorId,
    required String guestPlayerId,
    TeamMembershipStatus status = TeamMembershipStatus.bench,
    TeamMemberAvailability availability = TeamMemberAvailability.available,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final team = await _requireTeam(teamId);
    _assertCanManage(team, actorId);
    await _bootstrapLegacyMemberships(team);

    final existingMemberships = await _membershipRepository.getTeamMemberships(
      teamId,
      includeInactive: true,
    );
    final validationError = _policy.validateGuestMembership(
      existingMemberships: existingMemberships,
      guestPlayerId: guestPlayerId,
      role: TeamMembershipRole.player,
    );
    if (validationError != null) {
      throw Exception(validationError);
    }

    final guestPlayer = await _requireGuestPlayer(guestPlayerId);
    if (guestPlayer.teamId != null && guestPlayer.teamId != teamId) {
      throw Exception('اللاعب الضيف مرتبط بفريق آخر بالفعل.');
    }

    final membership = TeamMembership(
      id: _uuid.v4(),
      teamId: teamId,
      guestPlayerId: guestPlayerId,
      role: TeamMembershipRole.player,
      status: status,
      availability: availability,
      joinedAt: effectiveNow,
      updatedAt: effectiveNow,
      invitedBy: actorId,
    );

    await _membershipRepository.createMembership(membership);

    if (guestPlayer.teamId != teamId) {
      await _guestPlayerRepository.updateGuestPlayer(
        guestPlayer.copyWith(teamId: teamId, updatedAt: effectiveNow),
      );
    }

    return membership;
  }

  Future<TeamMembership> updateMembershipStatus({
    required String teamId,
    required String actorId,
    required String membershipId,
    required TeamMembershipStatus status,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final team = await _requireTeam(teamId);
    _assertCanManage(team, actorId);
    final membership = await _requireMembership(membershipId);
    _assertMembershipBelongsToTeam(membership, teamId);

    final updated = membership.copyWith(
      status: status,
      updatedAt: effectiveNow,
    );
    await _membershipRepository.updateMembership(updated);
    return updated;
  }

  Future<TeamMembership> updateAvailability({
    required String teamId,
    required String actorId,
    required String membershipId,
    required TeamMemberAvailability availability,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final team = await _requireTeam(teamId);
    _assertCanManage(team, actorId);
    final membership = await _requireMembership(membershipId);
    _assertMembershipBelongsToTeam(membership, teamId);

    final updated = membership.copyWith(
      availability: availability,
      updatedAt: effectiveNow,
    );
    await _membershipRepository.updateMembership(updated);
    return updated;
  }

  @Deprecated(
    'Guest identity conversion must use the trusted guest-claim callable.',
  )
  Future<TeamMembership> replaceGuestWithRegisteredPlayer({
    required String teamId,
    required String actorId,
    required String guestPlayerId,
    required String playerId,
    DateTime? now,
  }) {
    throw UnsupportedError(
      'لا يمكن تحويل اللاعب الضيف يدويًا؛ استخدم رابط استلام اللاعب الآمن.',
    );
  }

  Future<TeamMembership> updateMembershipRole({
    required String teamId,
    required String actorId,
    required String membershipId,
    required TeamMembershipRole role,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final team = await _requireTeam(teamId);
    _assertCanManage(team, actorId);
    final membership = await _requireMembership(membershipId);
    _assertMembershipBelongsToTeam(membership, teamId);

    final validationError = _policy.validateRoleChange(
      team: team,
      membership: membership,
      newRole: role,
    );
    if (validationError != null) {
      throw Exception(validationError);
    }

    final updatedMembership = membership.copyWith(
      role: role,
      updatedAt: effectiveNow,
    );
    await _membershipRepository.updateMembership(updatedMembership);

    if (membership.playerId != null) {
      await _teamRepository.updateTeam(
        _updatedTeamForRoleChange(
          team,
          previousMembership: membership,
          updatedMembership: updatedMembership,
        ),
      );
    }

    return updatedMembership;
  }

  Future<TeamMembership> removeMembership({
    required String teamId,
    required String actorId,
    required String membershipId,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final team = await _requireTeam(teamId);
    _assertCanManage(team, actorId);
    final membership = await _requireMembership(membershipId);
    _assertMembershipBelongsToTeam(membership, teamId);

    final validationError = _policy.validateRemoval(
      team: team,
      membership: membership,
    );
    if (validationError != null) {
      throw Exception(validationError);
    }

    final updatedMembership = membership.copyWith(
      status: TeamMembershipStatus.inactive,
      availability: TeamMemberAvailability.unavailable,
      updatedAt: effectiveNow,
    );
    await _membershipRepository.updateMembership(updatedMembership);

    if (membership.playerId != null) {
      await _teamRepository.updateTeam(
        _updatedTeamForMembership(
          team,
          membership: membership,
          addPlayer: false,
        ),
      );
    }

    return updatedMembership;
  }

  Future<void> _bootstrapLegacyMemberships(Team team) async {
    final memberships = await _membershipRepository.getTeamMemberships(
      team.id,
      includeInactive: true,
    );
    final existingPlayerIds = memberships
        .where((membership) => membership.playerId != null)
        .map((membership) => membership.playerId!)
        .toSet();

    for (final playerId in team.playerIds) {
      if (existingPlayerIds.contains(playerId)) {
        continue;
      }

      final role = playerId == team.ownerId
          ? TeamMembershipRole.owner
          : team.viceCaptainIds.contains(playerId)
          ? TeamMembershipRole.viceCaptain
          : TeamMembershipRole.player;
      final membership = TeamMembership(
        id: _uuid.v4(),
        teamId: team.id,
        playerId: playerId,
        role: role,
        status: TeamMembershipStatus.inactive,
        availability: TeamMemberAvailability.available,
        joinedAt: team.createdAt,
        updatedAt: team.createdAt,
      );
      await _membershipRepository.createMembership(membership);
    }
  }

  Team _updatedTeamForMembership(
    Team team, {
    required TeamMembership membership,
    required bool addPlayer,
  }) {
    final playerId = membership.playerId;
    if (playerId == null) {
      return team;
    }

    final playerIds = List<String>.from(team.playerIds);
    final viceCaptainIds = List<String>.from(team.viceCaptainIds);

    if (addPlayer) {
      if (!playerIds.contains(playerId)) {
        playerIds.add(playerId);
      }
      if (membership.role == TeamMembershipRole.viceCaptain &&
          !viceCaptainIds.contains(playerId)) {
        viceCaptainIds.add(playerId);
      }
    } else {
      playerIds.remove(playerId);
      viceCaptainIds.remove(playerId);
    }

    return team.copyWith(playerIds: playerIds, viceCaptainIds: viceCaptainIds);
  }

  Team _updatedTeamForRoleChange(
    Team team, {
    required TeamMembership previousMembership,
    required TeamMembership updatedMembership,
  }) {
    final playerId = updatedMembership.playerId;
    if (playerId == null) {
      return team;
    }

    final viceCaptainIds = List<String>.from(team.viceCaptainIds);
    viceCaptainIds.remove(playerId);

    if (updatedMembership.role == TeamMembershipRole.viceCaptain) {
      viceCaptainIds.add(playerId);
    }

    return team.copyWith(viceCaptainIds: viceCaptainIds);
  }

  Future<Team> _requireTeam(String teamId) async {
    final team = await _teamRepository.getTeam(teamId);
    if (team == null) {
      throw Exception('الفريق المطلوب غير موجود.');
    }
    return team;
  }

  Future<GuestPlayer> _requireGuestPlayer(String guestPlayerId) async {
    final guestPlayer = await _guestPlayerRepository.getGuestPlayer(
      guestPlayerId,
    );
    if (guestPlayer == null) {
      throw Exception('اللاعب الضيف المطلوب غير موجود.');
    }
    return guestPlayer;
  }

  Future<TeamMembership> _requireMembership(String membershipId) async {
    final membership = await _membershipRepository.getMembership(membershipId);
    if (membership == null) {
      throw Exception('عضوية الفريق المطلوبة غير موجودة.');
    }
    return membership;
  }

  void _assertCanManage(Team team, String actorId) {
    if (!_policy.canManageRoster(team: team, actorId: actorId)) {
      throw Exception('لا تملك صلاحية إدارة قائمة هذا الفريق.');
    }
  }

  void _assertMembershipBelongsToTeam(
    TeamMembership membership,
    String teamId,
  ) {
    if (membership.teamId != teamId) {
      throw Exception('هذه العضوية لا تنتمي إلى الفريق المطلوب.');
    }
  }
}

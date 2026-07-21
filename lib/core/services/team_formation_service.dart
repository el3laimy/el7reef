import 'package:uuid/uuid.dart';

import '../../core/enums/team_membership_role.dart';
import '../../core/enums/team_membership_status.dart';
import '../../data/repositories/guest_player_repository_impl.dart';
import '../../data/repositories/player_repository_impl.dart';
import '../../data/repositories/team_formation_template_repository_impl.dart';
import '../../data/repositories/team_membership_repository_impl.dart';
import '../../data/repositories/team_repository_impl.dart';
import '../../data/repositories/team_roster_snapshot_repository_impl.dart';
import '../../domain/entities/team.dart';
import '../../domain/entities/team_formation_entry.dart';
import '../../domain/entities/team_formation_template.dart';
import '../../domain/entities/team_membership.dart';
import '../../domain/entities/team_roster_snapshot.dart';
import '../../domain/repositories/guest_player_repository.dart';
import '../../domain/repositories/player_repository.dart';
import '../../domain/repositories/team_formation_template_repository.dart';
import '../../domain/repositories/team_membership_repository.dart';
import '../../domain/repositories/team_repository.dart';
import '../../domain/repositories/team_roster_snapshot_repository.dart';
import 'team_roster_policy.dart';

class ApplyTeamFormationResult {
  final TeamFormationTemplate template;
  final int matchedMembers;
  final int movedToBenchMembers;
  final int missingMembers;

  const ApplyTeamFormationResult({
    required this.template,
    required this.matchedMembers,
    required this.movedToBenchMembers,
    required this.missingMembers,
  });
}

class TeamFormationService {
  final TeamRepository _teamRepository;
  final TeamMembershipRepository _membershipRepository;
  final PlayerRepository _playerRepository;
  final GuestPlayerRepository _guestPlayerRepository;
  final TeamFormationTemplateRepository _templateRepository;
  final TeamRosterSnapshotRepository _snapshotRepository;
  final TeamRosterPolicy _policy;
  final Uuid _uuid;

  TeamFormationService({
    TeamRepository? teamRepository,
    TeamMembershipRepository? membershipRepository,
    PlayerRepository? playerRepository,
    GuestPlayerRepository? guestPlayerRepository,
    TeamFormationTemplateRepository? templateRepository,
    TeamRosterSnapshotRepository? snapshotRepository,
    TeamRosterPolicy? policy,
    Uuid? uuid,
  }) : _teamRepository = teamRepository ?? TeamRepositoryImpl(),
       _membershipRepository =
           membershipRepository ?? TeamMembershipRepositoryImpl(),
       _playerRepository = playerRepository ?? PlayerRepositoryImpl(),
       _guestPlayerRepository =
           guestPlayerRepository ?? GuestPlayerRepositoryImpl(),
       _templateRepository =
           templateRepository ?? TeamFormationTemplateRepositoryImpl(),
       _snapshotRepository =
           snapshotRepository ?? TeamRosterSnapshotRepositoryImpl(),
       _policy = policy ?? const TeamRosterPolicy(),
       _uuid = uuid ?? const Uuid();

  Future<List<TeamFormationTemplate>> getTeamTemplates(String teamId) {
    return _templateRepository
        .getTeamTemplates(teamId)
        .then(
          (templates) => templates
              .where(
                (template) => template.id != _currentLineupTemplateId(teamId),
              )
              .toList(growable: false),
        );
  }

  Future<TeamFormationTemplate?> getCurrentLineupState(String teamId) {
    return _templateRepository.getTemplate(_currentLineupTemplateId(teamId));
  }

  Future<List<TeamRosterSnapshot>> getRecentSnapshots(
    String teamId, {
    int limit = 6,
  }) {
    return _snapshotRepository.getTeamSnapshots(teamId, limit: limit);
  }

  Future<TeamFormationTemplate> saveCurrentAsTemplate({
    required String teamId,
    required String actorId,
    required String name,
    String? formationLabel,
    List<TeamFormationEntry>? entries,
    DateTime? now,
  }) async {
    final effectiveName = name.trim();
    if (effectiveName.isEmpty) {
      throw Exception('اسم القالب مطلوب.');
    }

    final effectiveNow = now ?? DateTime.now();
    final team = await _requireTeam(teamId);
    _assertCanManage(team, actorId);

    final capturedEntries = entries ?? await _captureCurrentEntries(teamId);
    final template = TeamFormationTemplate(
      id: _uuid.v4(),
      teamId: teamId,
      name: effectiveName,
      formationLabel: _normalizeOptionalText(formationLabel),
      entries: capturedEntries,
      createdBy: actorId,
      createdAt: effectiveNow,
      updatedAt: effectiveNow,
    );

    await _templateRepository.createTemplate(template);
    return template;
  }

  Future<TeamFormationTemplate> saveCurrentLineupState({
    required String teamId,
    required String actorId,
    required String formationLabel,
    required List<TeamFormationEntry> entries,
    DateTime? now,
  }) async {
    if (entries.isEmpty) {
      throw Exception('لا يمكن حفظ خطة فريق بلا لاعبين.');
    }

    final effectiveNow = now ?? DateTime.now();
    final team = await _requireTeam(teamId);
    _assertCanManage(team, actorId);

    final id = _currentLineupTemplateId(teamId);
    final existing = await _templateRepository.getTemplate(id);
    final template = TeamFormationTemplate(
      id: id,
      teamId: teamId,
      name: '__current_lineup__',
      formationLabel: _normalizeOptionalText(formationLabel),
      entries: entries,
      createdBy: existing?.createdBy ?? actorId,
      createdAt: existing?.createdAt ?? effectiveNow,
      updatedAt: effectiveNow,
    );

    if (existing == null) {
      await _templateRepository.createTemplate(template);
    } else {
      await _templateRepository.updateTemplate(template);
    }
    return template;
  }

  Future<TeamRosterSnapshot> createRosterSnapshot({
    required String teamId,
    required String actorId,
    required String label,
    String? formationLabel,
    String? sourceTemplateId,
    List<TeamFormationEntry>? entries,
    DateTime? now,
  }) async {
    final effectiveLabel = label.trim();
    if (effectiveLabel.isEmpty) {
      throw Exception('اسم النسخة مطلوب.');
    }

    final effectiveNow = now ?? DateTime.now();
    final team = await _requireTeam(teamId);
    _assertCanManage(team, actorId);

    final capturedEntries = entries ?? await _captureCurrentEntries(teamId);
    final snapshot = TeamRosterSnapshot(
      id: _uuid.v4(),
      teamId: teamId,
      label: effectiveLabel,
      formationLabel: _normalizeOptionalText(formationLabel),
      sourceTemplateId: _normalizeOptionalText(sourceTemplateId),
      entries: capturedEntries,
      createdBy: actorId,
      createdAt: effectiveNow,
    );

    await _snapshotRepository.createSnapshot(snapshot);
    return snapshot;
  }

  Future<ApplyTeamFormationResult> applyTemplate({
    required String teamId,
    required String actorId,
    required String templateId,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final team = await _requireTeam(teamId);
    _assertCanManage(team, actorId);

    final template = await _templateRepository.getTemplate(templateId);
    if (template == null || template.teamId != teamId) {
      throw Exception('القالب المطلوب غير موجود لهذا الفريق.');
    }

    final memberships = await _membershipRepository.getTeamMemberships(
      teamId,
      includeInactive: true,
    );
    final templateEntriesByKey = {
      for (final entry in template.entries) entry.memberKey: entry,
    };
    final currentKeys = memberships.map(_membershipKey).toSet();

    var matchedMembers = 0;
    var movedToBenchMembers = 0;

    for (final membership in memberships) {
      final templateEntry = templateEntriesByKey[_membershipKey(membership)];

      if (templateEntry != null) {
        matchedMembers += 1;
        final updatedMembership = membership.copyWith(
          status: templateEntry.status,
          availability: templateEntry.availability,
          updatedAt: effectiveNow,
        );

        if (_shouldUpdateMembership(membership, updatedMembership)) {
          await _membershipRepository.updateMembership(updatedMembership);
        }
        continue;
      }

      if (membership.status == TeamMembershipStatus.starter) {
        movedToBenchMembers += 1;
        await _membershipRepository.updateMembership(
          membership.copyWith(
            status: TeamMembershipStatus.bench,
            updatedAt: effectiveNow,
          ),
        );
      }
    }

    await saveCurrentLineupState(
      teamId: teamId,
      actorId: actorId,
      formationLabel: template.summaryLabel,
      entries: template.entries,
      now: effectiveNow,
    );

    return ApplyTeamFormationResult(
      template: template,
      matchedMembers: matchedMembers,
      movedToBenchMembers: movedToBenchMembers,
      missingMembers: template.entries
          .where((entry) => !currentKeys.contains(entry.memberKey))
          .length,
    );
  }

  Future<void> deleteTemplate({
    required String teamId,
    required String actorId,
    required String templateId,
  }) async {
    final team = await _requireTeam(teamId);
    _assertCanManage(team, actorId);

    final template = await _templateRepository.getTemplate(templateId);
    if (template == null || template.teamId != teamId) {
      throw Exception('القالب المطلوب غير موجود.');
    }

    await _templateRepository.deleteTemplate(templateId);
  }

  Future<List<TeamFormationEntry>> _captureCurrentEntries(String teamId) async {
    final memberships = await _membershipRepository.getTeamMemberships(
      teamId,
      includeInactive: true,
    );
    if (memberships.isEmpty) {
      throw Exception('لا يمكن حفظ قالب أو نسخة لفريق لا يملك قائمة بعد.');
    }

    final entries = await Future.wait(
      memberships.map(_buildEntryForMembership),
    );
    entries.sort(_compareEntries);
    return entries;
  }

  Future<TeamFormationEntry> _buildEntryForMembership(
    TeamMembership membership,
  ) async {
    if (membership.playerId != null) {
      final player = await _playerRepository.getPlayer(membership.playerId!);
      return TeamFormationEntry(
        playerId: membership.playerId,
        role: membership.role,
        status: membership.status,
        availability: membership.availability,
        displayName: player?.name ?? membership.playerId!,
        position: player?.position,
      );
    }

    final guestPlayer = await _guestPlayerRepository.getGuestPlayer(
      membership.guestPlayerId!,
    );
    return TeamFormationEntry(
      guestPlayerId: membership.guestPlayerId,
      role: TeamMembershipRole.player,
      status: membership.status,
      availability: membership.availability,
      displayName: guestPlayer?.displayName ?? membership.guestPlayerId!,
      position: guestPlayer?.preferredPosition,
    );
  }

  int _compareEntries(TeamFormationEntry a, TeamFormationEntry b) {
    final statusOrder = <TeamMembershipStatus, int>{
      TeamMembershipStatus.starter: 0,
      TeamMembershipStatus.bench: 1,
      TeamMembershipStatus.inactive: 2,
    };
    final roleOrder = <TeamMembershipRole, int>{
      TeamMembershipRole.owner: 0,
      TeamMembershipRole.viceCaptain: 1,
      TeamMembershipRole.manager: 2,
      TeamMembershipRole.assistantManager: 3,
      TeamMembershipRole.player: 4,
    };

    final statusCompare = (statusOrder[a.status] ?? 99).compareTo(
      statusOrder[b.status] ?? 99,
    );
    if (statusCompare != 0) {
      return statusCompare;
    }

    final roleCompare = (roleOrder[a.role] ?? 99).compareTo(
      roleOrder[b.role] ?? 99,
    );
    if (roleCompare != 0) {
      return roleCompare;
    }

    return a.displayName.compareTo(b.displayName);
  }

  String _membershipKey(TeamMembership membership) {
    return membership.playerId != null
        ? 'player:${membership.playerId}'
        : 'guest:${membership.guestPlayerId}';
  }

  bool _shouldUpdateMembership(TeamMembership current, TeamMembership updated) {
    return current.status != updated.status ||
        current.availability != updated.availability;
  }

  Future<Team> _requireTeam(String teamId) async {
    final team = await _teamRepository.getTeam(teamId);
    if (team == null) {
      throw Exception('الفريق المطلوب غير موجود.');
    }
    return team;
  }

  void _assertCanManage(Team team, String actorId) {
    if (!_policy.canManageRoster(team: team, actorId: actorId)) {
      throw Exception('لا تملك صلاحية إدارة قوالب هذا الفريق.');
    }
  }

  String? _normalizeOptionalText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  String _currentLineupTemplateId(String teamId) {
    return '__current_lineup__${teamId.replaceAll('/', '_')}';
  }
}

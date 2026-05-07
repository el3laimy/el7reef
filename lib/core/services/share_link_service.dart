import 'package:uuid/uuid.dart';

import '../../core/enums/claim_code_status.dart';
import '../../core/enums/claim_payload_scope.dart';
import '../../core/enums/claim_target_type.dart';
import '../../core/enums/guest_claim_status.dart';
import '../../data/repositories/claim_code_repository_impl.dart';
import '../../data/repositories/guest_player_repository_impl.dart';
import '../../data/repositories/guest_team_repository_impl.dart';
import '../../data/repositories/team_repository_impl.dart';
import '../../data/repositories/tournament_repository_impl.dart';
import '../../domain/entities/claim_code.dart';
import '../../domain/entities/claim_payload.dart';
import '../../domain/entities/generated_share_link.dart';
import '../../domain/entities/guest_player.dart';
import '../../domain/entities/team.dart';
import '../../domain/repositories/claim_code_repository.dart';
import '../../domain/repositories/guest_player_repository.dart';
import '../../domain/repositories/guest_team_repository.dart';
import '../../domain/repositories/team_repository.dart';
import '../../domain/repositories/tournament_repository.dart';
import 'analytics_service.dart';
import 'team_roster_policy.dart';
import 'tournament_permission_service.dart';

class ShareLinkService {
  final ClaimCodeRepository _claimCodeRepository;
  final GuestPlayerRepository _guestPlayerRepository;
  final GuestTeamRepository _guestTeamRepository;
  final TeamRepository _teamRepository;
  TournamentRepository? _tournamentRepository;
  final TeamRosterPolicy _teamRosterPolicy;
  final TournamentPermissionService _tournamentPermissionService;
  final AnalyticsService _analyticsService;
  final Uuid _uuid;

  static const String appScheme = 'el7reef';
  static const String webHost = 'el7reef.app';

  ShareLinkService({
    ClaimCodeRepository? claimCodeRepository,
    GuestPlayerRepository? guestPlayerRepository,
    GuestTeamRepository? guestTeamRepository,
    TeamRepository? teamRepository,
    TournamentRepository? tournamentRepository,
    TeamRosterPolicy? teamRosterPolicy,
    TournamentPermissionService? tournamentPermissionService,
    AnalyticsService? analyticsService,
    Uuid? uuid,
  }) : _claimCodeRepository = claimCodeRepository ?? ClaimCodeRepositoryImpl(),
       _guestPlayerRepository =
           guestPlayerRepository ?? GuestPlayerRepositoryImpl(),
       _guestTeamRepository = guestTeamRepository ?? GuestTeamRepositoryImpl(),
       _teamRepository = teamRepository ?? TeamRepositoryImpl(),
       _tournamentRepository = tournamentRepository,
       _teamRosterPolicy = teamRosterPolicy ?? const TeamRosterPolicy(),
       _tournamentPermissionService =
           tournamentPermissionService ?? TournamentPermissionService(),
       _analyticsService = analyticsService ?? AnalyticsService(),
       _uuid = uuid ?? const Uuid();

  TournamentRepository get _resolvedTournamentRepository =>
      _tournamentRepository ??= TournamentRepositoryImpl();

  Future<GeneratedShareLink> createGuestPlayerClaimLink({
    required String guestPlayerId,
    required String actorId,
    Duration ttl = const Duration(days: 7),
    bool requiresApproval = false,
  }) async {
    final guestPlayer = await _guestPlayerRepository.getGuestPlayer(
      guestPlayerId,
    );
    if (guestPlayer == null) {
      throw Exception('اللاعب الضيف المطلوب غير موجود.');
    }
    await _assertCanManageGuestPlayer(guestPlayer, actorId);

    final claimCode = await _reuseOrCreateClaimCode(
      targetType: ClaimTargetType.guestPlayer,
      targetId: guestPlayer.id,
      scope: _inferScope(
        teamId: guestPlayer.teamId,
        tournamentId: guestPlayer.tournamentId,
      ),
      teamId: guestPlayer.teamId,
      tournamentId: guestPlayer.tournamentId,
      actorId: actorId,
      ttl: ttl,
      requiresApproval: requiresApproval,
    );

    if (guestPlayer.claimCode != claimCode.code ||
        guestPlayer.claimStatus != GuestClaimStatus.invited) {
      await _guestPlayerRepository.updateGuestPlayer(
        guestPlayer.copyWith(
          claimStatus: GuestClaimStatus.invited,
          claimCode: claimCode.code,
          updatedAt: claimCode.updatedAt,
        ),
      );
    }

    final link = _buildShareLink(
      claimCode: claimCode,
      label: 'استلم مكانك كلاعب داخل EL7REEF',
      subjectName: guestPlayer.displayName,
    );

    _analyticsService.trackInviteSent(
      type: 'guest_player',
      targetId: guestPlayerId,
      actorId: actorId,
    );

    return link;
  }

  Future<GeneratedShareLink> createGuestTeamClaimLink({
    required String guestTeamId,
    required String actorId,
    Duration ttl = const Duration(days: 7),
    bool requiresApproval = true,
  }) async {
    final guestTeam = await _guestTeamRepository.getGuestTeam(guestTeamId);
    if (guestTeam == null) {
      throw Exception('الفريق الضيف المطلوب غير موجود.');
    }
    if (guestTeam.creatorId != actorId) {
      throw Exception('لا تملك صلاحية إصدار رابط claim لهذا الفريق.');
    }

    final claimCode = await _reuseOrCreateClaimCode(
      targetType: ClaimTargetType.guestTeam,
      targetId: guestTeam.id,
      scope: _inferScope(
        teamId: null,
        tournamentId: guestTeam.tournamentIds.isNotEmpty
            ? guestTeam.tournamentIds.first
            : null,
      ),
      tournamentId: guestTeam.tournamentIds.isNotEmpty
          ? guestTeam.tournamentIds.first
          : null,
      actorId: actorId,
      ttl: ttl,
      requiresApproval: requiresApproval,
    );

    if (guestTeam.claimCode != claimCode.code ||
        guestTeam.claimStatus != GuestClaimStatus.invited) {
      await _guestTeamRepository.updateGuestTeam(
        guestTeam.copyWith(
          claimStatus: GuestClaimStatus.invited,
          claimCode: claimCode.code,
          updatedAt: claimCode.updatedAt,
        ),
      );
    }

    final link = _buildShareLink(
      claimCode: claimCode,
      label: 'استلم ملكية الفريق داخل EL7REEF',
      subjectName: guestTeam.name,
    );

    _analyticsService.trackInviteSent(
      type: 'guest_team',
      targetId: guestTeamId,
      actorId: actorId,
    );

    return link;
  }

  Future<GeneratedShareLink> createTeamInviteLink({
    required String teamId,
    required String actorId,
    String? tournamentId,
    Duration ttl = const Duration(days: 5),
  }) async {
    final team = await _requireTeam(teamId);
    _assertCanManageTeam(team, actorId);

    final claimCode = await _reuseOrCreateClaimCode(
      targetType: ClaimTargetType.teamInvite,
      targetId: teamId,
      scope: tournamentId != null && tournamentId.isNotEmpty
          ? ClaimPayloadScope.tournament
          : ClaimPayloadScope.team,
      teamId: teamId,
      tournamentId: tournamentId,
      actorId: actorId,
      ttl: ttl,
      requiresApproval: false,
    );

    final link = _buildShareLink(
      claimCode: claimCode,
      label: 'انضم إلى فريق ${team.name} على EL7REEF',
      subjectName: team.name,
    );

    _analyticsService.trackInviteSent(
      type: 'team_invite',
      targetId: teamId,
      actorId: actorId,
    );

    return link;
  }

  ClaimPayload parsePayloadFromUri(Uri uri) {
    return ClaimPayload.fromUri(uri);
  }

  GeneratedShareLink _buildShareLink({
    required ClaimCode claimCode,
    required String label,
    required String subjectName,
  }) {
    final payload = claimCode.toPayload();
    final routeHost = claimCode.targetType == ClaimTargetType.teamInvite
        ? 'invite'
        : 'claim';
    final appUri = Uri(
      scheme: appScheme,
      host: routeHost,
      queryParameters: payload.toQueryParameters(),
    );
    final webUri = Uri(
      scheme: 'https',
      host: webHost,
      path: '/$routeHost',
      queryParameters: payload.toQueryParameters(),
    );

    final shareText =
        '$label\n$subjectName\n${webUri.toString()}\nينتهي الرابط في ${_formatExpiry(claimCode.expiresAt)}.';
    final whatsappText = '$label عبر EL7REEF\n${webUri.toString()}';

    return GeneratedShareLink(
      claimCode: claimCode,
      payload: payload,
      appUri: appUri,
      webUri: webUri,
      qrData: webUri.toString(),
      shareText: shareText,
      whatsappText: whatsappText,
    );
  }

  Future<ClaimCode> _reuseOrCreateClaimCode({
    required ClaimTargetType targetType,
    required String targetId,
    required ClaimPayloadScope scope,
    String? teamId,
    String? tournamentId,
    required String actorId,
    required Duration ttl,
    required bool requiresApproval,
  }) async {
    final now = DateTime.now();
    final existing = await _claimCodeRepository.getActiveClaimCodeForTarget(
      targetType: targetType,
      targetId: targetId,
      createdBy: actorId,
      tournamentId: tournamentId,
    );

    if (existing != null) {
      if (!existing.isExpiredAt(now)) {
        return existing;
      }

      await _claimCodeRepository.updateClaimCode(
        existing.copyWith(status: ClaimCodeStatus.expired, updatedAt: now),
      );
    }

    final code = await _generateUniqueCode();
    final claimCode = ClaimCode(
      code: code,
      targetType: targetType,
      targetId: targetId,
      scope: scope,
      teamId: teamId,
      tournamentId: tournamentId,
      createdBy: actorId,
      requiresApproval: requiresApproval,
      status: ClaimCodeStatus.active,
      createdAt: now,
      updatedAt: now,
      expiresAt: now.add(ttl),
    );
    await _claimCodeRepository.createClaimCode(claimCode);
    return claimCode;
  }

  Future<String> _generateUniqueCode() async {
    for (var attempt = 0; attempt < 6; attempt += 1) {
      final candidate = _uuid
          .v4()
          .replaceAll('-', '')
          .substring(0, 12)
          .toUpperCase();
      final existing = await _claimCodeRepository.getClaimCode(candidate);
      if (existing == null) {
        return candidate;
      }
    }
    throw Exception('تعذر توليد claim code فريد حالياً.');
  }

  ClaimPayloadScope _inferScope({String? teamId, String? tournamentId}) {
    final hasTeam = teamId != null && teamId.isNotEmpty;
    final hasTournament = tournamentId != null && tournamentId.isNotEmpty;

    if (hasTeam && hasTournament) {
      return ClaimPayloadScope.hybrid;
    }
    if (hasTournament) {
      return ClaimPayloadScope.tournament;
    }
    if (hasTeam) {
      return ClaimPayloadScope.team;
    }
    return ClaimPayloadScope.publicShare;
  }

  Future<void> _assertCanManageGuestPlayer(
    GuestPlayer guestPlayer,
    String actorId,
  ) async {
    if (guestPlayer.createdBy == actorId) {
      return;
    }

    final teamId = guestPlayer.teamId;
    if (teamId != null && teamId.isNotEmpty) {
      final team = await _teamRepository.getTeam(teamId);
      if (team != null &&
          _teamRosterPolicy.canManageRoster(team: team, actorId: actorId)) {
        return;
      }
    }

    final guestTeamId = guestPlayer.guestTeamId;
    if (guestTeamId != null && guestTeamId.isNotEmpty) {
      final guestTeam = await _guestTeamRepository.getGuestTeam(guestTeamId);
      if (guestTeam != null && guestTeam.creatorId == actorId) {
        return;
      }
    }

    final tournamentId = guestPlayer.tournamentId;
    if (tournamentId != null && tournamentId.isNotEmpty) {
      final tournament = await _resolvedTournamentRepository.getTournament(
        tournamentId,
      );
      if (tournament != null &&
          _tournamentPermissionService.canIssueGuestClaims(
            tournament,
            actorId,
          )) {
        return;
      }
    }

    throw Exception('لا تملك صلاحية إصدار رابط claim لهذا اللاعب.');
  }

  Future<Team> _requireTeam(String teamId) async {
    final team = await _teamRepository.getTeam(teamId);
    if (team == null) {
      throw Exception('الفريق المطلوب غير موجود.');
    }
    return team;
  }

  void _assertCanManageTeam(Team team, String actorId) {
    if (!_teamRosterPolicy.canManageRoster(team: team, actorId: actorId)) {
      throw Exception('لا تملك صلاحية إصدار دعوات لهذا الفريق.');
    }
  }

  String _formatExpiry(DateTime expiresAt) {
    final day = expiresAt.day.toString().padLeft(2, '0');
    final month = expiresAt.month.toString().padLeft(2, '0');
    return '$day/$month/${expiresAt.year}';
  }
}

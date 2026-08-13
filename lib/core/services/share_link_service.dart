import 'package:uuid/uuid.dart';

import '../../core/enums/claim_code_status.dart';
import '../../core/enums/claim_payload_scope.dart';
import '../../core/enums/claim_target_type.dart';
import '../../data/repositories/claim_code_repository_impl.dart';
import '../../data/repositories/guest_player_repository_impl.dart';
import '../../data/repositories/guest_team_repository_impl.dart';
import '../../data/repositories/team_repository_impl.dart';
import '../../domain/entities/claim_code.dart';
import '../../domain/entities/claim_payload.dart';
import '../../domain/entities/generated_share_link.dart';
import '../../domain/entities/team.dart';
import '../../domain/repositories/claim_code_repository.dart';
import '../../domain/repositories/guest_player_repository.dart';
import '../../domain/repositories/guest_team_repository.dart';
import '../../domain/repositories/team_repository.dart';
import 'analytics_service.dart';
import 'cloud_sensitive_ops_service.dart';
import 'guest_player_claim_link_issuer.dart';
import 'team_roster_policy.dart';
import '../navigation/app_link_route_parser.dart';

class ShareLinkService implements GuestPlayerClaimLinkIssuer {
  final ClaimCodeRepository _claimCodeRepository;
  final GuestPlayerRepository _guestPlayerRepository;
  final GuestTeamRepository _guestTeamRepository;
  final TeamRepository _teamRepository;
  final TeamRosterPolicy _teamRosterPolicy;
  final AnalyticsService _analyticsService;
  final CloudSensitiveOpsService _cloudOps;
  final Uuid _uuid;

  static const String appScheme = 'el7reef';
  static const String webHost = AppLinkRouteParser.pilotWebHost;

  ShareLinkService({
    ClaimCodeRepository? claimCodeRepository,
    GuestPlayerRepository? guestPlayerRepository,
    GuestTeamRepository? guestTeamRepository,
    TeamRepository? teamRepository,
    TeamRosterPolicy? teamRosterPolicy,
    AnalyticsService? analyticsService,
    CloudSensitiveOpsService? cloudOps,
    Uuid? uuid,
  }) : _claimCodeRepository = claimCodeRepository ?? ClaimCodeRepositoryImpl(),
       _guestPlayerRepository =
           guestPlayerRepository ?? GuestPlayerRepositoryImpl(),
       _guestTeamRepository = guestTeamRepository ?? GuestTeamRepositoryImpl(),
       _teamRepository = teamRepository ?? TeamRepositoryImpl(),
       _teamRosterPolicy = teamRosterPolicy ?? const TeamRosterPolicy(),
       _analyticsService = analyticsService ?? AnalyticsService(),
       _cloudOps = cloudOps ?? CloudSensitiveOpsService(),
       _uuid = uuid ?? const Uuid();

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
    if (guestPlayer.isClaimed) {
      throw Exception('تم استلام هذا اللاعب بالفعل ولا يمكن إصدار رابط جديد.');
    }

    final claimCode = await _issueGuestClaimCode(
      targetType: ClaimTargetType.guestPlayer,
      targetId: guestPlayer.id,
      actorId: actorId,
      ttl: ttl,
      requiresApproval: requiresApproval,
    );

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

  @override
  Future<Uri> createGuestPlayerClaimUrl({
    required String guestPlayerId,
    required String actorId,
    Duration ttl = const Duration(days: 7),
    bool requiresApproval = false,
  }) async {
    final link = await createGuestPlayerClaimLink(
      guestPlayerId: guestPlayerId,
      actorId: actorId,
      ttl: ttl,
      requiresApproval: requiresApproval,
    );
    return link.webUri;
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

    final claimCode = await _issueGuestClaimCode(
      targetType: ClaimTargetType.guestTeam,
      targetId: guestTeam.id,
      actorId: actorId,
      ttl: ttl,
      requiresApproval: requiresApproval,
    );

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

  Future<ClaimCode> _issueGuestClaimCode({
    required ClaimTargetType targetType,
    required String targetId,
    required String actorId,
    required Duration ttl,
    required bool requiresApproval,
  }) async {
    final requestedAt = DateTime.now();
    final response = await _cloudOps.issueGuestClaimCode(
      targetType: targetType.name,
      targetId: targetId,
      requestId: _uuid.v4(),
      ttlMs: ttl.inMilliseconds,
      requiresApproval: requiresApproval,
    );
    final responseType = _enumFromName(
      ClaimTargetType.values,
      response['targetType'],
      'targetType',
    );
    if (responseType != targetType || response['targetId'] != targetId) {
      throw const FormatException(
        'Guest claim issuance response does not match its request.',
      );
    }
    return ClaimCode(
      code: _requiredResponseString(response, 'code'),
      targetType: responseType,
      targetId: targetId,
      scope: _enumFromName(
        ClaimPayloadScope.values,
        response['scope'],
        'scope',
      ),
      teamId: _optionalResponseString(response['teamId']),
      tournamentId: _optionalResponseString(response['tournamentId']),
      createdBy: actorId,
      requiresApproval: response['requiresApproval'] == true,
      status: _enumFromName(
        ClaimCodeStatus.values,
        response['status'],
        'status',
      ),
      createdAt: requestedAt,
      updatedAt: requestedAt,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        _requiredResponseInt(response, 'expiresAt'),
      ),
    );
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

T _enumFromName<T extends Enum>(
  Iterable<T> values,
  Object? candidate,
  String fieldName,
) {
  if (candidate is String) {
    for (final value in values) {
      if (value.name == candidate) return value;
    }
  }
  throw FormatException('Invalid $fieldName in guest claim response.');
}

String _requiredResponseString(
  Map<String, dynamic> response,
  String fieldName,
) {
  final value = _optionalResponseString(response[fieldName]);
  if (value == null) {
    throw FormatException('Missing $fieldName in guest claim response.');
  }
  return value;
}

String? _optionalResponseString(Object? candidate) {
  if (candidate is! String) return null;
  final normalized = candidate.trim();
  return normalized.isEmpty ? null : normalized;
}

int _requiredResponseInt(Map<String, dynamic> response, String fieldName) {
  final value = response[fieldName];
  if (value is num && value.isFinite) return value.toInt();
  throw FormatException('Missing $fieldName in guest claim response.');
}

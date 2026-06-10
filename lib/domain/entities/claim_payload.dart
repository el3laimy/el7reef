import '../../core/enums/claim_code_status.dart';
import '../../core/enums/claim_payload_scope.dart';
import '../../core/enums/claim_target_type.dart';

class ClaimPayload {
  final int version;
  final String code;
  final ClaimTargetType targetType;
  final String targetId;
  final String? subjectName;
  final ClaimPayloadScope scope;
  final String? teamId;
  final String? tournamentId;
  final bool requiresApproval;
  final DateTime expiresAt;
  final ClaimCodeStatus status;

  const ClaimPayload({
    this.version = 1,
    required this.code,
    required this.targetType,
    required this.targetId,
    this.subjectName,
    required this.scope,
    this.teamId,
    this.tournamentId,
    required this.requiresApproval,
    required this.expiresAt,
    required this.status,
  });

  Map<String, String> toQueryParameters() {
    return {
      'v': version.toString(),
      'code': code,
      'type': targetType.name,
      'targetId': targetId,
      if (subjectName != null && subjectName!.isNotEmpty)
        'subjectName': subjectName!,
      'scope': scope.name,
      'requiresApproval': requiresApproval ? '1' : '0',
      'expiresAt': expiresAt.millisecondsSinceEpoch.toString(),
      'status': status.name,
      if (teamId != null && teamId!.isNotEmpty) 'teamId': teamId!,
      if (tournamentId != null && tournamentId!.isNotEmpty)
        'tournamentId': tournamentId!,
    };
  }

  factory ClaimPayload.fromQueryParameters(Map<String, String> params) {
    final targetType = ClaimTargetType.values.firstWhere(
      (value) => value.name == params['type'],
      orElse: () => ClaimTargetType.guestPlayer,
    );
    final scope = ClaimPayloadScope.values.firstWhere(
      (value) => value.name == params['scope'],
      orElse: () => ClaimPayloadScope.team,
    );
    final status = ClaimCodeStatus.values.firstWhere(
      (value) => value.name == params['status'],
      orElse: () => ClaimCodeStatus.active,
    );

    return ClaimPayload(
      version: int.tryParse(params['v'] ?? '') ?? 1,
      code: params['code'] ?? '',
      targetType: targetType,
      targetId: params['targetId'] ?? '',
      subjectName: params['subjectName'],
      scope: scope,
      teamId: params['teamId'],
      tournamentId: params['tournamentId'],
      requiresApproval: params['requiresApproval'] == '1',
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        int.tryParse(params['expiresAt'] ?? '') ?? 0,
      ),
      status: status,
    );
  }

  factory ClaimPayload.fromUri(Uri uri) {
    return ClaimPayload.fromQueryParameters(uri.queryParameters);
  }
}

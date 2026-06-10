import '../../core/enums/claim_code_status.dart';
import '../../core/enums/claim_payload_scope.dart';
import '../../core/enums/claim_target_type.dart';
import 'claim_payload.dart';

class ClaimCode {
  final String code;
  final ClaimTargetType targetType;
  final String targetId;
  final ClaimPayloadScope scope;
  final String? teamId;
  final String? tournamentId;
  final String createdBy;
  final bool requiresApproval;
  final ClaimCodeStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime expiresAt;
  final String? claimedByPlayerId;
  final DateTime? claimedAt;

  const ClaimCode({
    required this.code,
    required this.targetType,
    required this.targetId,
    required this.scope,
    this.teamId,
    this.tournamentId,
    required this.createdBy,
    this.requiresApproval = false,
    this.status = ClaimCodeStatus.active,
    required this.createdAt,
    required this.updatedAt,
    required this.expiresAt,
    this.claimedByPlayerId,
    this.claimedAt,
  });

  bool isExpiredAt(DateTime now) => expiresAt.isBefore(now);

  ClaimPayload toPayload({String? subjectName}) {
    return ClaimPayload(
      code: code,
      targetType: targetType,
      targetId: targetId,
      subjectName: subjectName,
      scope: scope,
      teamId: teamId,
      tournamentId: tournamentId,
      requiresApproval: requiresApproval,
      expiresAt: expiresAt,
      status: status,
    );
  }

  ClaimCode copyWith({
    String? code,
    ClaimTargetType? targetType,
    String? targetId,
    ClaimPayloadScope? scope,
    Object? teamId = _unset,
    Object? tournamentId = _unset,
    String? createdBy,
    bool? requiresApproval,
    ClaimCodeStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? expiresAt,
    Object? claimedByPlayerId = _unset,
    Object? claimedAt = _unset,
  }) {
    return ClaimCode(
      code: code ?? this.code,
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
      scope: scope ?? this.scope,
      teamId: identical(teamId, _unset) ? this.teamId : teamId as String?,
      tournamentId: identical(tournamentId, _unset)
          ? this.tournamentId
          : tournamentId as String?,
      createdBy: createdBy ?? this.createdBy,
      requiresApproval: requiresApproval ?? this.requiresApproval,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      claimedByPlayerId: identical(claimedByPlayerId, _unset)
          ? this.claimedByPlayerId
          : claimedByPlayerId as String?,
      claimedAt: identical(claimedAt, _unset)
          ? this.claimedAt
          : claimedAt as DateTime?,
    );
  }
}

const Object _unset = Object();

import '../../core/enums/claim_code_status.dart';
import '../../core/enums/claim_payload_scope.dart';
import '../../core/enums/claim_target_type.dart';
import '../../domain/entities/claim_code.dart';

class ClaimCodeModel {
  final String code;
  final String targetType;
  final String targetId;
  final String scope;
  final String? teamId;
  final String? tournamentId;
  final String createdBy;
  final bool requiresApproval;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime expiresAt;
  final String? claimedByPlayerId;
  final DateTime? claimedAt;

  const ClaimCodeModel({
    required this.code,
    required this.targetType,
    required this.targetId,
    required this.scope,
    this.teamId,
    this.tournamentId,
    required this.createdBy,
    required this.requiresApproval,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.expiresAt,
    this.claimedByPlayerId,
    this.claimedAt,
  });

  factory ClaimCodeModel.fromJson(Map<String, dynamic> json, String docId) {
    return ClaimCodeModel(
      code: docId,
      targetType: json['targetType'] as String? ?? ClaimTargetType.guestPlayer.name,
      targetId: json['targetId'] as String? ?? '',
      scope: json['scope'] as String? ?? ClaimPayloadScope.team.name,
      teamId: json['teamId'] as String?,
      tournamentId: json['tournamentId'] as String?,
      createdBy: json['createdBy'] as String? ?? '',
      requiresApproval: json['requiresApproval'] as bool? ?? false,
      status: json['status'] as String? ?? ClaimCodeStatus.active.name,
      createdAt: json['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch((json['createdAt'] as num).toInt())
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch((json['updatedAt'] as num).toInt())
          : DateTime.now(),
      expiresAt: json['expiresAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch((json['expiresAt'] as num).toInt())
          : DateTime.now(),
      claimedByPlayerId: json['claimedByPlayerId'] as String?,
      claimedAt: json['claimedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch((json['claimedAt'] as num).toInt())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'targetType': targetType,
      'targetId': targetId,
      'scope': scope,
      'teamId': teamId,
      'tournamentId': tournamentId,
      'createdBy': createdBy,
      'requiresApproval': requiresApproval,
      'status': status,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'expiresAt': expiresAt.millisecondsSinceEpoch,
      'claimedByPlayerId': claimedByPlayerId,
      'claimedAt': claimedAt?.millisecondsSinceEpoch,
    };
  }

  ClaimCode toEntity() {
    return ClaimCode(
      code: code,
      targetType: ClaimTargetType.values.firstWhere(
        (value) => value.name == targetType,
        orElse: () => ClaimTargetType.guestPlayer,
      ),
      targetId: targetId,
      scope: ClaimPayloadScope.values.firstWhere(
        (value) => value.name == scope,
        orElse: () => ClaimPayloadScope.team,
      ),
      teamId: teamId,
      tournamentId: tournamentId,
      createdBy: createdBy,
      requiresApproval: requiresApproval,
      status: ClaimCodeStatus.values.firstWhere(
        (value) => value.name == status,
        orElse: () => ClaimCodeStatus.active,
      ),
      createdAt: createdAt,
      updatedAt: updatedAt,
      expiresAt: expiresAt,
      claimedByPlayerId: claimedByPlayerId,
      claimedAt: claimedAt,
    );
  }

  factory ClaimCodeModel.fromEntity(ClaimCode claimCode) {
    return ClaimCodeModel(
      code: claimCode.code,
      targetType: claimCode.targetType.name,
      targetId: claimCode.targetId,
      scope: claimCode.scope.name,
      teamId: claimCode.teamId,
      tournamentId: claimCode.tournamentId,
      createdBy: claimCode.createdBy,
      requiresApproval: claimCode.requiresApproval,
      status: claimCode.status.name,
      createdAt: claimCode.createdAt,
      updatedAt: claimCode.updatedAt,
      expiresAt: claimCode.expiresAt,
      claimedByPlayerId: claimCode.claimedByPlayerId,
      claimedAt: claimCode.claimedAt,
    );
  }
}

import 'package:cloud_functions/cloud_functions.dart';

import '../../core/enums/claim_code_status.dart';
import '../../core/enums/claim_merge_conflict_type.dart';
import '../../core/enums/claim_payload_scope.dart';
import '../../core/enums/claim_target_type.dart';
import '../../domain/entities/claim_merge_conflict.dart';
import 'cloud_sensitive_ops_service.dart';

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

/// Safe, non-authoritative display metadata resolved from a bearer claim code.
///
/// Route query parameters remain navigation hints only. Any action must still
/// be authorized by the callable using Firebase Auth and current documents.
class GuestClaimInspection {
  final ClaimTargetType targetType;
  final String targetId;
  final String? subjectName;
  final ClaimPayloadScope scope;
  final String? teamId;
  final String? tournamentId;
  final bool requiresApproval;
  final bool pendingApproval;
  final bool canApprovePendingTeamClaim;
  final ClaimCodeStatus status;
  final DateTime expiresAt;

  const GuestClaimInspection({
    required this.targetType,
    required this.targetId,
    this.subjectName,
    required this.scope,
    this.teamId,
    this.tournamentId,
    required this.requiresApproval,
    required this.pendingApproval,
    required this.canApprovePendingTeamClaim,
    required this.status,
    required this.expiresAt,
  });

  bool get isExpired => status == ClaimCodeStatus.expired;
}

/// Callable-only facade for guest identity claim operations.
///
/// This class deliberately owns no Firestore instance and has no local write
/// fallback. Actor identity and every authoritative transition are resolved by
/// Cloud Functions from Firebase Auth and current server data.
class GuestClaimService {
  final CloudSensitiveOpsService _cloudOps;

  GuestClaimService({CloudSensitiveOpsService? cloudOps})
    : _cloudOps = cloudOps ?? CloudSensitiveOpsService();

  Future<GuestClaimInspection> inspectGuestClaim({
    required String claimCode,
  }) async {
    final code = _requiredInput(claimCode, 'claimCode');
    final payload = await _invoke(
      () => _cloudOps.inspectGuestClaim(claimCode: code),
    );
    return GuestClaimInspection(
      targetType: _enumValue(
        ClaimTargetType.values,
        payload['targetType'],
        'targetType',
      ),
      targetId: _requiredString(payload, 'targetId'),
      subjectName: _optionalString(payload['subjectName']),
      scope: _enumValue(ClaimPayloadScope.values, payload['scope'], 'scope'),
      teamId: _optionalString(payload['teamId']),
      tournamentId: _optionalString(payload['tournamentId']),
      requiresApproval: payload['requiresApproval'] == true,
      pendingApproval: payload['pendingApproval'] == true,
      canApprovePendingTeamClaim: payload['canApprovePendingTeamClaim'] == true,
      status: _enumValue(ClaimCodeStatus.values, payload['status'], 'status'),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        _requiredInt(payload, 'expiresAt'),
      ),
    );
  }

  Future<GuestPlayerClaimResult> claimGuestPlayer({
    required String claimCode,
  }) async {
    final code = _requiredInput(claimCode, 'claimCode');
    final payload = await _invoke(
      () => _cloudOps.claimGuestPlayer(claimCode: code),
    );
    _throwIfExpired(payload, ClaimTargetType.guestPlayer);
    final result = GuestPlayerClaimResult(
      outcome: _enumValue(
        GuestPlayerClaimOutcome.values,
        payload['outcome'],
        'outcome',
      ),
      claimCode: code,
      guestPlayerId: _requiredString(payload, 'guestPlayerId'),
      playerId: _requiredString(payload, 'playerId'),
      relinkedMembershipIds: _stringList(payload['relinkedMembershipIds']),
      linkedTeamIds: _stringList(payload['linkedTeamIds']),
      syncedLegacyTeamIds: _stringList(payload['syncedLegacyTeamIds']),
      conflict: _claimConflict(payload['conflict']),
    );
    return result;
  }

  Future<GuestTeamClaimResult> claimGuestTeam({
    required String claimCode,
    required String teamId,
  }) async {
    final code = _requiredInput(claimCode, 'claimCode');
    final selectedTeamId = _requiredInput(teamId, 'teamId');
    final payload = await _invoke(
      () => _cloudOps.claimGuestTeam(claimCode: code, teamId: selectedTeamId),
    );
    _throwIfExpired(payload, ClaimTargetType.guestTeam);
    final result = GuestTeamClaimResult(
      outcome: _enumValue(
        GuestTeamClaimOutcome.values,
        payload['outcome'],
        'outcome',
      ),
      claimCode: code,
      guestTeamId: _requiredString(payload, 'guestTeamId'),
      teamId: _requiredString(payload, 'teamId'),
      mergedTournamentIds: _stringList(payload['mergedTournamentIds']),
      requestedByPlayerId: _optionalString(payload['requestedByPlayerId']),
      conflict: _claimConflict(payload['conflict']),
    );
    return result;
  }

  Future<Map<String, dynamic>> _invoke(
    Future<Map<String, dynamic>> Function() operation,
  ) async {
    try {
      return await operation();
    } on FirebaseFunctionsException catch (error) {
      throw Exception(_localizedFunctionError(error.code));
    } on StateError {
      throw Exception('خدمة الاستلام غير متاحة الآن. حاول مرة أخرى لاحقًا.');
    }
  }

  void _throwIfExpired(
    Map<String, dynamic> payload,
    ClaimTargetType targetType,
  ) {
    if (payload['outcome'] != 'expired') return;
    if (targetType == ClaimTargetType.guestTeam) {
      throw Exception('انتهت صلاحية رابط استلام الفريق.');
    }
    throw Exception('انتهت صلاحية رابط الاستلام.');
  }

  ClaimMergeConflict? _claimConflict(Object? candidate) {
    if (candidate == null) return null;
    if (candidate is! Map) {
      throw const FormatException('Invalid claim conflict response.');
    }
    final payload = candidate.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final type = _enumValue(
      ClaimMergeConflictType.values,
      payload['type'],
      'conflict.type',
    );
    return ClaimMergeConflict(
      type: type,
      message: _conflictMessage(type),
      conflictingEntityId: _optionalString(payload['conflictingEntityId']),
    );
  }

  String _conflictMessage(ClaimMergeConflictType type) => switch (type) {
    ClaimMergeConflictType.duplicatePhone =>
      'توجد هوية أخرى مطابقة لرقم الهاتف وتحتاج إلى مراجعة.',
    ClaimMergeConflictType.duplicateName =>
      'توجد هوية أخرى بالاسم نفسه وتحتاج إلى مراجعة.',
    ClaimMergeConflictType.targetAlreadyLinked =>
      'تم استلام هذا الحساب الضيف مسبقًا.',
    ClaimMergeConflictType.pendingTargetLink =>
      'يوجد طلب استلام معلق لفريق آخر.',
    ClaimMergeConflictType.rosterAlreadyContainsPlayer =>
      'اللاعب موجود بالفعل داخل قائمة هذا الفريق.',
  };

  String _localizedFunctionError(String code) => switch (code) {
    'unauthenticated' => 'يجب تسجيل الدخول لإتمام الاستلام.',
    'permission-denied' => 'لا تملك صلاحية تنفيذ عملية الاستلام هذه.',
    'not-found' => 'رابط الاستلام المطلوب غير موجود.',
    'invalid-argument' => 'بيانات رابط الاستلام غير صالحة.',
    'failed-precondition' => 'لا يمكن تنفيذ الاستلام في حالته الحالية.',
    'resource-exhausted' => 'تعذر إتمام الاستلام بأمان الآن.',
    'unavailable' || 'deadline-exceeded' =>
      'خدمة الاستلام غير متاحة الآن. حاول مرة أخرى لاحقًا.',
    _ => 'حدث خطأ أثناء الاستلام. حاول مرة أخرى.',
  };
}

T _enumValue<T extends Enum>(
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

String _requiredInput(String value, String fieldName) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, fieldName, 'must not be empty');
  }
  return normalized;
}

String _requiredString(Map<String, dynamic> payload, String fieldName) {
  final value = _optionalString(payload[fieldName]);
  if (value == null) {
    throw FormatException('Missing $fieldName in guest claim response.');
  }
  return value;
}

String? _optionalString(Object? value) {
  if (value is! String) return null;
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

int _requiredInt(Map<String, dynamic> payload, String fieldName) {
  final value = payload[fieldName];
  if (value is num && value.isFinite) return value.toInt();
  throw FormatException('Missing $fieldName in guest claim response.');
}

List<String> _stringList(Object? value) {
  if (value == null) return const [];
  if (value is! List) {
    throw const FormatException('Invalid list in guest claim response.');
  }
  final result = <String>[];
  for (final entry in value) {
    final normalized = _optionalString(entry);
    if (normalized == null) {
      throw const FormatException('Invalid list entry in claim response.');
    }
    if (!result.contains(normalized)) result.add(normalized);
  }
  return List.unmodifiable(result);
}

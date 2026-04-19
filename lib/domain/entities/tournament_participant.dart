import '../../core/enums/tournament_ops_enums.dart';

class TournamentParticipant {
  final String id;
  final String tournamentId;
  final TournamentParticipantSourceType sourceType;
  final String sourceEntityId;
  final String displayName;
  final TournamentParticipantStatus status;
  final int? seed;
  final String? groupId;
  final String? sourceRegistrationId;
  final String? replacementForParticipantId;
  final String? replacedByParticipantId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? approvedAt;
  final DateTime? finalizedAt;
  final DateTime? withdrawnAt;
  final DateTime? replacedAt;

  const TournamentParticipant({
    required this.id,
    required this.tournamentId,
    required this.sourceType,
    required this.sourceEntityId,
    required this.displayName,
    this.status = TournamentParticipantStatus.approved,
    this.seed,
    this.groupId,
    this.sourceRegistrationId,
    this.replacementForParticipantId,
    this.replacedByParticipantId,
    required this.createdAt,
    required this.updatedAt,
    this.approvedAt,
    this.finalizedAt,
    this.withdrawnAt,
    this.replacedAt,
  });

  bool get isActive =>
      status == TournamentParticipantStatus.approved ||
      status == TournamentParticipantStatus.finalized;

  bool get isFinalized => status == TournamentParticipantStatus.finalized;

  TournamentParticipant copyWith({
    String? id,
    String? tournamentId,
    TournamentParticipantSourceType? sourceType,
    String? sourceEntityId,
    String? displayName,
    TournamentParticipantStatus? status,
    Object? seed = _unset,
    Object? groupId = _unset,
    Object? sourceRegistrationId = _unset,
    Object? replacementForParticipantId = _unset,
    Object? replacedByParticipantId = _unset,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? approvedAt = _unset,
    Object? finalizedAt = _unset,
    Object? withdrawnAt = _unset,
    Object? replacedAt = _unset,
  }) {
    return TournamentParticipant(
      id: id ?? this.id,
      tournamentId: tournamentId ?? this.tournamentId,
      sourceType: sourceType ?? this.sourceType,
      sourceEntityId: sourceEntityId ?? this.sourceEntityId,
      displayName: displayName ?? this.displayName,
      status: status ?? this.status,
      seed: identical(seed, _unset) ? this.seed : seed as int?,
      groupId: identical(groupId, _unset) ? this.groupId : groupId as String?,
      sourceRegistrationId: identical(sourceRegistrationId, _unset)
          ? this.sourceRegistrationId
          : sourceRegistrationId as String?,
      replacementForParticipantId:
          identical(replacementForParticipantId, _unset)
          ? this.replacementForParticipantId
          : replacementForParticipantId as String?,
      replacedByParticipantId: identical(replacedByParticipantId, _unset)
          ? this.replacedByParticipantId
          : replacedByParticipantId as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      approvedAt: identical(approvedAt, _unset)
          ? this.approvedAt
          : approvedAt as DateTime?,
      finalizedAt: identical(finalizedAt, _unset)
          ? this.finalizedAt
          : finalizedAt as DateTime?,
      withdrawnAt: identical(withdrawnAt, _unset)
          ? this.withdrawnAt
          : withdrawnAt as DateTime?,
      replacedAt: identical(replacedAt, _unset)
          ? this.replacedAt
          : replacedAt as DateTime?,
    );
  }
}

const Object _unset = Object();

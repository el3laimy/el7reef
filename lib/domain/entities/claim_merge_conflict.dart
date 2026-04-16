import '../../core/enums/claim_merge_conflict_type.dart';

class ClaimMergeConflict {
  final ClaimMergeConflictType type;
  final String message;
  final String? conflictingEntityId;
  final String? conflictingEntityLabel;

  const ClaimMergeConflict({
    required this.type,
    required this.message,
    this.conflictingEntityId,
    this.conflictingEntityLabel,
  });

  bool get isAmbiguousIdentity =>
      type == ClaimMergeConflictType.duplicatePhone ||
      type == ClaimMergeConflictType.duplicateName;
}

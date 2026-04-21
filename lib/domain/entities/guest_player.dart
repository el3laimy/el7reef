import '../../core/enums/guest_claim_status.dart';

/// Represents a player known to a team or tournament before app account claim.
class GuestPlayer {
  final String id;
  final String displayName;
  final String normalizedName;
  final String? phoneNumber;
  final int? jerseyNumber;
  final String? preferredPosition;
  final String? teamId;
  final String? guestTeamId;
  final String? tournamentId;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final GuestClaimStatus claimStatus;
  final String? claimCode;
  final String? linkedPlayerId;
  final String? notes;

  const GuestPlayer({
    required this.id,
    required this.displayName,
    required this.normalizedName,
    this.phoneNumber,
    this.jerseyNumber,
    this.preferredPosition,
    this.teamId,
    this.guestTeamId,
    this.tournamentId,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.claimStatus = GuestClaimStatus.guest,
    this.claimCode,
    this.linkedPlayerId,
    this.notes,
  });

  bool get isClaimed => claimStatus == GuestClaimStatus.claimed;
  bool get isArchived => claimStatus == GuestClaimStatus.archived;
  bool get hasClaimCode => claimCode != null && claimCode!.isNotEmpty;
  bool get hasLinkedPlayer =>
      linkedPlayerId != null && linkedPlayerId!.isNotEmpty;

  GuestPlayer copyWith({
    String? id,
    String? displayName,
    String? normalizedName,
    String? phoneNumber,
    int? jerseyNumber,
    String? preferredPosition,
    String? teamId,
    String? guestTeamId,
    String? tournamentId,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    GuestClaimStatus? claimStatus,
    String? claimCode,
    String? linkedPlayerId,
    String? notes,
  }) {
    return GuestPlayer(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      normalizedName: normalizedName ?? this.normalizedName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      jerseyNumber: jerseyNumber ?? this.jerseyNumber,
      preferredPosition: preferredPosition ?? this.preferredPosition,
      teamId: teamId ?? this.teamId,
      guestTeamId: guestTeamId ?? this.guestTeamId,
      tournamentId: tournamentId ?? this.tournamentId,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      claimStatus: claimStatus ?? this.claimStatus,
      claimCode: claimCode ?? this.claimCode,
      linkedPlayerId: linkedPlayerId ?? this.linkedPlayerId,
      notes: notes ?? this.notes,
    );
  }
}

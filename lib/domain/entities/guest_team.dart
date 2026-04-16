import '../../core/enums/guest_claim_status.dart';

/// Represents a team entered manually before it is claimed by a registered
/// captain or fully digitized inside the app.
class GuestTeam {
  final String id;
  final String name;
  final String normalizedName;
  final String creatorId;
  final String? contactName;
  final String? contactPhone;
  final String? logoUrl;
  final List<String> tournamentIds;
  final String? captainGuestPlayerId;
  final GuestClaimStatus claimStatus;
  final String? claimCode;
  final String? linkedTeamId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GuestTeam({
    required this.id,
    required this.name,
    required this.normalizedName,
    required this.creatorId,
    this.contactName,
    this.contactPhone,
    this.logoUrl,
    this.tournamentIds = const [],
    this.captainGuestPlayerId,
    this.claimStatus = GuestClaimStatus.guest,
    this.claimCode,
    this.linkedTeamId,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isClaimed => claimStatus == GuestClaimStatus.claimed;
  bool get isArchived => claimStatus == GuestClaimStatus.archived;
  bool get hasClaimCode => claimCode != null && claimCode!.isNotEmpty;
  bool get hasLinkedTeam => linkedTeamId != null && linkedTeamId!.isNotEmpty;

  GuestTeam copyWith({
    String? id,
    String? name,
    String? normalizedName,
    String? creatorId,
    String? contactName,
    String? contactPhone,
    String? logoUrl,
    List<String>? tournamentIds,
    String? captainGuestPlayerId,
    GuestClaimStatus? claimStatus,
    String? claimCode,
    String? linkedTeamId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GuestTeam(
      id: id ?? this.id,
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
      creatorId: creatorId ?? this.creatorId,
      contactName: contactName ?? this.contactName,
      contactPhone: contactPhone ?? this.contactPhone,
      logoUrl: logoUrl ?? this.logoUrl,
      tournamentIds: tournamentIds ?? this.tournamentIds,
      captainGuestPlayerId: captainGuestPlayerId ?? this.captainGuestPlayerId,
      claimStatus: claimStatus ?? this.claimStatus,
      claimCode: claimCode ?? this.claimCode,
      linkedTeamId: linkedTeamId ?? this.linkedTeamId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

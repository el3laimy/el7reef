import '../../core/enums/guest_claim_status.dart';
import '../../domain/entities/guest_team.dart';

class GuestTeamModel {
  final String id;
  final String name;
  final String normalizedName;
  final String creatorId;
  final String? contactName;
  final String? contactPhone;
  final String? logoUrl;
  final List<String> tournamentIds;
  final String? captainGuestPlayerId;
  final String claimStatus;
  final String? claimCode;
  final String? linkedTeamId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GuestTeamModel({
    required this.id,
    required this.name,
    required this.normalizedName,
    required this.creatorId,
    this.contactName,
    this.contactPhone,
    this.logoUrl,
    this.tournamentIds = const [],
    this.captainGuestPlayerId,
    this.claimStatus = 'guest',
    this.claimCode,
    this.linkedTeamId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GuestTeamModel.fromJson(Map<String, dynamic> json, String docId) {
    return GuestTeamModel(
      id: docId,
      name: json['name'] as String? ?? '',
      normalizedName: json['normalizedName'] as String? ?? '',
      creatorId: json['creatorId'] as String? ?? '',
      contactName: json['contactName'] as String?,
      contactPhone: json['contactPhone'] as String?,
      logoUrl: json['logoUrl'] as String?,
      tournamentIds: (json['tournamentIds'] as List<dynamic>?)
              ?.map((value) => value as String)
              .toList() ??
          const [],
      captainGuestPlayerId: json['captainGuestPlayerId'] as String?,
      claimStatus: json['claimStatus'] as String? ?? 'guest',
      claimCode: json['claimCode'] as String?,
      linkedTeamId: json['linkedTeamId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['createdAt'] as num).toInt(),
            )
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['updatedAt'] as num).toInt(),
            )
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'normalizedName': normalizedName,
      'creatorId': creatorId,
      'contactName': contactName,
      'contactPhone': contactPhone,
      'logoUrl': logoUrl,
      'tournamentIds': tournamentIds,
      'captainGuestPlayerId': captainGuestPlayerId,
      'claimStatus': claimStatus,
      'claimCode': claimCode,
      'linkedTeamId': linkedTeamId,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  GuestTeam toEntity() {
    return GuestTeam(
      id: id,
      name: name,
      normalizedName: normalizedName,
      creatorId: creatorId,
      contactName: contactName,
      contactPhone: contactPhone,
      logoUrl: logoUrl,
      tournamentIds: tournamentIds,
      captainGuestPlayerId: captainGuestPlayerId,
      claimStatus: _parseClaimStatus(claimStatus),
      claimCode: claimCode,
      linkedTeamId: linkedTeamId,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory GuestTeamModel.fromEntity(GuestTeam guestTeam) {
    return GuestTeamModel(
      id: guestTeam.id,
      name: guestTeam.name,
      normalizedName: guestTeam.normalizedName,
      creatorId: guestTeam.creatorId,
      contactName: guestTeam.contactName,
      contactPhone: guestTeam.contactPhone,
      logoUrl: guestTeam.logoUrl,
      tournamentIds: guestTeam.tournamentIds,
      captainGuestPlayerId: guestTeam.captainGuestPlayerId,
      claimStatus: guestTeam.claimStatus.name,
      claimCode: guestTeam.claimCode,
      linkedTeamId: guestTeam.linkedTeamId,
      createdAt: guestTeam.createdAt,
      updatedAt: guestTeam.updatedAt,
    );
  }

  static GuestClaimStatus _parseClaimStatus(String value) {
    return GuestClaimStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => GuestClaimStatus.guest,
    );
  }
}

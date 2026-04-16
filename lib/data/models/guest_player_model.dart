import '../../core/enums/guest_claim_status.dart';
import '../../domain/entities/guest_player.dart';

class GuestPlayerModel {
  final String id;
  final String displayName;
  final String normalizedName;
  final String? phoneNumber;
  final int? jerseyNumber;
  final String? preferredPosition;
  final String? teamId;
  final String? tournamentId;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String claimStatus;
  final String? claimCode;
  final String? linkedPlayerId;
  final String? notes;

  const GuestPlayerModel({
    required this.id,
    required this.displayName,
    required this.normalizedName,
    this.phoneNumber,
    this.jerseyNumber,
    this.preferredPosition,
    this.teamId,
    this.tournamentId,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.claimStatus = 'guest',
    this.claimCode,
    this.linkedPlayerId,
    this.notes,
  });

  factory GuestPlayerModel.fromJson(Map<String, dynamic> json, String docId) {
    return GuestPlayerModel(
      id: docId,
      displayName: json['displayName'] as String? ?? '',
      normalizedName: json['normalizedName'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String?,
      jerseyNumber: (json['jerseyNumber'] as num?)?.toInt(),
      preferredPosition: json['preferredPosition'] as String?,
      teamId: json['teamId'] as String?,
      tournamentId: json['tournamentId'] as String?,
      createdBy: json['createdBy'] as String? ?? '',
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
      claimStatus: json['claimStatus'] as String? ?? 'guest',
      claimCode: json['claimCode'] as String?,
      linkedPlayerId: json['linkedPlayerId'] as String?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'displayName': displayName,
      'normalizedName': normalizedName,
      'phoneNumber': phoneNumber,
      'jerseyNumber': jerseyNumber,
      'preferredPosition': preferredPosition,
      'teamId': teamId,
      'tournamentId': tournamentId,
      'createdBy': createdBy,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'claimStatus': claimStatus,
      'claimCode': claimCode,
      'linkedPlayerId': linkedPlayerId,
      'notes': notes,
    };
  }

  GuestPlayer toEntity() {
    return GuestPlayer(
      id: id,
      displayName: displayName,
      normalizedName: normalizedName,
      phoneNumber: phoneNumber,
      jerseyNumber: jerseyNumber,
      preferredPosition: preferredPosition,
      teamId: teamId,
      tournamentId: tournamentId,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
      claimStatus: _parseClaimStatus(claimStatus),
      claimCode: claimCode,
      linkedPlayerId: linkedPlayerId,
      notes: notes,
    );
  }

  factory GuestPlayerModel.fromEntity(GuestPlayer guestPlayer) {
    return GuestPlayerModel(
      id: guestPlayer.id,
      displayName: guestPlayer.displayName,
      normalizedName: guestPlayer.normalizedName,
      phoneNumber: guestPlayer.phoneNumber,
      jerseyNumber: guestPlayer.jerseyNumber,
      preferredPosition: guestPlayer.preferredPosition,
      teamId: guestPlayer.teamId,
      tournamentId: guestPlayer.tournamentId,
      createdBy: guestPlayer.createdBy,
      createdAt: guestPlayer.createdAt,
      updatedAt: guestPlayer.updatedAt,
      claimStatus: guestPlayer.claimStatus.name,
      claimCode: guestPlayer.claimCode,
      linkedPlayerId: guestPlayer.linkedPlayerId,
      notes: guestPlayer.notes,
    );
  }

  static GuestClaimStatus _parseClaimStatus(String value) {
    return GuestClaimStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => GuestClaimStatus.guest,
    );
  }
}

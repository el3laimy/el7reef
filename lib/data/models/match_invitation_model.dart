import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/match_invitation.dart';

class MatchInvitationModel extends MatchInvitation {
  const MatchInvitationModel({
    required super.id,
    required super.matchId,
    required super.senderId,
    required super.receiverId,
    required super.side,
    super.status = InvitationStatus.pending,
    required super.createdAt,
    super.respondedAt,
  });

  factory MatchInvitationModel.fromJson(Map<String, dynamic> json, String id) {
    return MatchInvitationModel(
      id: id,
      matchId: json['matchId'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      receiverId: json['receiverId'] as String? ?? '',
      side: json['side'] as String? ?? 'A',
      status: InvitationStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => InvitationStatus.pending,
      ),
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      respondedAt: json['respondedAt'] != null
          ? (json['respondedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'matchId': matchId,
      'senderId': senderId,
      'receiverId': receiverId,
      'side': side,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'respondedAt': respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
    };
  }
}

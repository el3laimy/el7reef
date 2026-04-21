enum InvitationStatus { pending, accepted, declined, cancelled }

class MatchInvitation {
  final String id;
  final String matchId;
  final String senderId;
  final String receiverId;
  final String side; // 'A' or 'B'
  final InvitationStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;

  const MatchInvitation({
    required this.id,
    required this.matchId,
    required this.senderId,
    required this.receiverId,
    required this.side,
    this.status = InvitationStatus.pending,
    required this.createdAt,
    this.respondedAt,
  });

  MatchInvitation copyWith({
    String? id,
    String? matchId,
    String? senderId,
    String? receiverId,
    String? side,
    InvitationStatus? status,
    DateTime? createdAt,
    DateTime? respondedAt,
  }) {
    return MatchInvitation(
      id: id ?? this.id,
      matchId: matchId ?? this.matchId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      side: side ?? this.side,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
    );
  }
}

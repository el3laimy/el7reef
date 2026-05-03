enum ParticipantRefKind { player, guestPlayer, matchSidePlayer }

class ParticipantRef {
  final ParticipantRefKind kind;
  final String id;
  final String displayName;
  final String? linkedPlayerId;

  const ParticipantRef({
    required this.kind,
    required this.id,
    required this.displayName,
    this.linkedPlayerId,
  });

  ParticipantRef copyWith({
    ParticipantRefKind? kind,
    String? id,
    String? displayName,
    Object? linkedPlayerId = _unset,
  }) {
    return ParticipantRef(
      kind: kind ?? this.kind,
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      linkedPlayerId: identical(linkedPlayerId, _unset)
          ? this.linkedPlayerId
          : linkedPlayerId as String?,
    );
  }
}

const Object _unset = Object();

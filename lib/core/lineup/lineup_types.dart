enum SlotRole { gk, def, mid, att }

extension SlotRoleX on SlotRole {
  String get code {
    return switch (this) {
      SlotRole.gk => 'GK',
      SlotRole.def => 'DEF',
      SlotRole.mid => 'MID',
      SlotRole.att => 'ATT',
    };
  }

  String get arabicLabel {
    return switch (this) {
      SlotRole.gk => 'حارس',
      SlotRole.def => 'دفاع',
      SlotRole.mid => 'وسط',
      SlotRole.att => 'هجوم',
    };
  }

  bool matchesPosition(String? rawPosition) {
    final normalized = (rawPosition ?? '').trim().toUpperCase();
    if (normalized.isEmpty) {
      return false;
    }
    return switch (this) {
      SlotRole.gk => normalized == 'GK' || normalized.contains('حارس'),
      SlotRole.def =>
        normalized == 'DEF' ||
            normalized == 'CB' ||
            normalized == 'LB' ||
            normalized == 'RB' ||
            normalized.contains('دفاع'),
      SlotRole.mid =>
        normalized == 'MID' ||
            normalized == 'CM' ||
            normalized == 'CAM' ||
            normalized == 'CDM' ||
            normalized.contains('وسط'),
      SlotRole.att =>
        normalized == 'ATT' ||
            normalized == 'FWD' ||
            normalized == 'ST' ||
            normalized == 'LW' ||
            normalized == 'RW' ||
            normalized.contains('هجوم'),
    };
  }
}

enum LineupOrientation { attackUp, attackDown }

enum TeamLineupStatus { draft, confirmed, locked }

enum LineupInviteStatus { notInvited, invited, accepted }

class FormationSlot {
  final String id;
  final SlotRole role;
  final int lineIndex;
  final int slotIndex;
  final double x;
  final double y;
  final String? playerId;
  final String? guestPlayerId;
  final String? matchSidePlayerId;
  final bool isCaptain;
  final bool isLocked;

  const FormationSlot({
    required this.id,
    required this.role,
    required this.lineIndex,
    required this.slotIndex,
    required this.x,
    required this.y,
    this.playerId,
    this.guestPlayerId,
    this.matchSidePlayerId,
    this.isCaptain = false,
    this.isLocked = false,
  }) : assert(
         (playerId == null ? 0 : 1) +
                 (guestPlayerId == null ? 0 : 1) +
                 (matchSidePlayerId == null ? 0 : 1) <=
             1,
         'A lineup slot can hold only one occupant.',
       );

  bool get isEmpty =>
      playerId == null && guestPlayerId == null && matchSidePlayerId == null;

  String? get occupantKey {
    if (playerId != null) {
      return LineupPlayer.registeredKey(playerId!);
    }
    if (guestPlayerId != null) {
      return LineupPlayer.guestKey(guestPlayerId!);
    }
    if (matchSidePlayerId != null) {
      return LineupPlayer.matchSidePlayerKey(matchSidePlayerId!);
    }
    return null;
  }

  FormationSlot copyWith({
    String? id,
    SlotRole? role,
    int? lineIndex,
    int? slotIndex,
    double? x,
    double? y,
    Object? playerId = _unset,
    Object? guestPlayerId = _unset,
    Object? matchSidePlayerId = _unset,
    bool? isCaptain,
    bool? isLocked,
  }) {
    return FormationSlot(
      id: id ?? this.id,
      role: role ?? this.role,
      lineIndex: lineIndex ?? this.lineIndex,
      slotIndex: slotIndex ?? this.slotIndex,
      x: x ?? this.x,
      y: y ?? this.y,
      playerId: identical(playerId, _unset)
          ? this.playerId
          : playerId as String?,
      guestPlayerId: identical(guestPlayerId, _unset)
          ? this.guestPlayerId
          : guestPlayerId as String?,
      matchSidePlayerId: identical(matchSidePlayerId, _unset)
          ? this.matchSidePlayerId
          : matchSidePlayerId as String?,
      isCaptain: isCaptain ?? this.isCaptain,
      isLocked: isLocked ?? this.isLocked,
    );
  }

  FormationSlot clearPlayer() {
    return copyWith(
      playerId: null,
      guestPlayerId: null,
      matchSidePlayerId: null,
      isCaptain: false,
    );
  }

  FormationSlot assignPlayer(LineupPlayer player) {
    return copyWith(
      playerId: player.isRegistered ? player.id : null,
      guestPlayerId: player.isGuest ? player.id : null,
      matchSidePlayerId: player.isTemporary ? player.id : null,
      isCaptain: player.isCaptain,
    );
  }
}

class LineupPlayer {
  final String id;
  final String name;
  final String? username;
  final String? photoUrl;
  final int? number;
  final String? preferredPosition;
  final bool isRegistered;
  final bool isTemporary;
  final LineupInviteStatus? inviteStatus;
  final bool isCaptain;

  const LineupPlayer({
    required this.id,
    required this.name,
    this.username,
    this.photoUrl,
    this.number,
    this.preferredPosition,
    required this.isRegistered,
    this.isTemporary = false,
    this.inviteStatus,
    this.isCaptain = false,
  }) : assert(
         !(isRegistered && isTemporary),
         'A lineup player cannot be both registered and temporary.',
       );

  bool get isGuest => !isRegistered && !isTemporary;

  String get key {
    if (isRegistered) return registeredKey(id);
    if (isTemporary) return matchSidePlayerKey(id);
    return guestKey(id);
  }

  static String registeredKey(String id) => 'player:$id';
  static String guestKey(String id) => 'guest:$id';
  static String matchSidePlayerKey(String id) => 'sidePlayer:$id';
}

class LineupDragPayload {
  final LineupPlayer player;
  final String? sourceSlotId;

  const LineupDragPayload({required this.player, this.sourceSlotId});

  bool get fromBench => sourceSlotId == null;
}

class LineupGuestPlayer {
  final String id;
  final String name;
  final int? number;
  final String? photoUrl;

  const LineupGuestPlayer({
    required this.id,
    required this.name,
    this.number,
    this.photoUrl,
  });
}

class TeamLineup {
  final String id;
  final String matchId;
  final String teamId;
  final int playerCount;
  final String formationCode;
  final LineupOrientation orientation;
  final TeamLineupStatus status;
  final List<FormationSlot> slots;
  final List<String> benchPlayerIds;
  final List<LineupGuestPlayer> guestPlayers;
  final DateTime updatedAt;

  const TeamLineup({
    required this.id,
    required this.matchId,
    required this.teamId,
    required this.playerCount,
    required this.formationCode,
    this.orientation = LineupOrientation.attackUp,
    this.status = TeamLineupStatus.draft,
    required this.slots,
    this.benchPlayerIds = const [],
    this.guestPlayers = const [],
    required this.updatedAt,
  });
}

/// Maps a roster member to an exact position on the formation pitch.
///
/// [membershipId] is always a [TeamMembership.id] — never a raw playerId or
/// guestPlayerId.  The actual player/guest identity is resolved via the
/// membership record when building [MatchLineupEntry] instances.
class SlotAssignment {
  final String membershipId;
  final String slotId;
  final String slotRole; // 'gk', 'def', 'mid', 'att'
  final int lineIndex;
  final int slotIndex;
  final double slotX;
  final double slotY;

  const SlotAssignment({
    required this.membershipId,
    required this.slotId,
    required this.slotRole,
    required this.lineIndex,
    required this.slotIndex,
    required this.slotX,
    required this.slotY,
  });
}

const Object _unset = Object();

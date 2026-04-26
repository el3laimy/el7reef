class MatchSide {
  final String id;
  final String matchId;
  final String sideKey;
  final String type;
  final String displayName;
  final String? officialTeamId;
  final String? captainUserId;
  final List<String> managedByUserIds;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MatchSide({
    required this.id,
    required this.matchId,
    required this.sideKey,
    required this.type,
    required this.displayName,
    this.officialTeamId,
    this.captainUserId,
    this.managedByUserIds = const [],
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isOfficialTeam => type == 'officialTeam';
  bool get isTemporary => type == 'temporary';

  MatchSide copyWith({
    String? id,
    String? matchId,
    String? sideKey,
    String? type,
    String? displayName,
    Object? officialTeamId = _unset,
    Object? captainUserId = _unset,
    List<String>? managedByUserIds,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MatchSide(
      id: id ?? this.id,
      matchId: matchId ?? this.matchId,
      sideKey: sideKey ?? this.sideKey,
      type: type ?? this.type,
      displayName: displayName ?? this.displayName,
      officialTeamId: identical(officialTeamId, _unset)
          ? this.officialTeamId
          : officialTeamId as String?,
      captainUserId: identical(captainUserId, _unset)
          ? this.captainUserId
          : captainUserId as String?,
      managedByUserIds: managedByUserIds ?? this.managedByUserIds,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

const Object _unset = Object();

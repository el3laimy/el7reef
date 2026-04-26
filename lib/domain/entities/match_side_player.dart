class MatchSidePlayer {
  final String id;
  final String matchId;
  final String sideKey;
  final String sideId;
  final String kind;
  final String? playerId;
  final String displayName;
  final String? position;
  final int? shirtNumber;
  final bool ratingEligible;
  final String addedBy;
  final DateTime createdAt;

  const MatchSidePlayer({
    required this.id,
    required this.matchId,
    required this.sideKey,
    required this.sideId,
    required this.kind,
    this.playerId,
    required this.displayName,
    this.position,
    this.shirtNumber,
    required this.ratingEligible,
    required this.addedBy,
    required this.createdAt,
  });

  bool get isTemporary => kind == 'temporary';
  bool get isRegistered => kind == 'registered';
}
